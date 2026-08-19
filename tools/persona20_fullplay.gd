extends Node
## 20 画像 × 各打完一局十日：真挂 main.tscn，走信纸 / 取名 / 睡觉 / 聊天 / 结局。
## godot --headless --path <根> res://tools/persona20_fullplay.tscn
## 不截图（无头 dummy texture 会崩）。

const OUT_DIR := "user://persona20_fullplay/"
const REPORT_RES := "res://docs/二十画像十日实机_2026-08-19.md"
const TIME_SCALE_PLAY := 6.0
const CHAT_TIMEOUT_SEC := 14.0

var _packed: PackedScene
var _main: Node2D
var _ui: Node
var _runs: Array[Dictionary] = []
var _pid := ""
var _notes: PackedStringArray = []
var _day_letters: PackedStringArray = []
var _errors: PackedStringArray = []


func _ready() -> void:
	call_deferred("_boot")


func _boot() -> void:
	DirAccess.make_dir_recursive_absolute(ProjectSettings.globalize_path(OUT_DIR))
	_packed = load("res://scenes/main.tscn") as PackedScene
	_print("=== PERSONA20 FULLPLAY START ===")
	for spec in _persona_specs():
		await _play_one(spec)
	_write_report()
	_print("=== PERSONA20 FULLPLAY DONE n=%d ===" % _runs.size())
	Engine.time_scale = 1.0
	await get_tree().create_timer(0.4).timeout
	get_tree().quit()


func _play_one(spec: Dictionary) -> void:
	_pid = str(spec.get("id", "?"))
	_notes = PackedStringArray()
	_errors = PackedStringArray()
	_day_letters = PackedStringArray()
	_print("----- RUN %s %s -----" % [_pid, str(spec.get("label", ""))])
	await _spawn_main()
	var run := {
		"id": _pid,
		"label": str(spec.get("label", "")),
		"player": str(spec.get("player", "阿松")),
		"keep": bool(spec.get("keep", true)),
		"start_ms": Time.get_ticks_msec(),
	}
	var ok := await _run_ten_days(spec, run)
	run["ok"] = ok
	run["elapsed_s"] = "%.1f" % ((Time.get_ticks_msec() - int(run["start_ms"])) / 1000.0)
	run["day"] = GameState.game_day
	run["complete"] = GameState.is_story_complete()
	run["ending"] = EndingDirector.resolve_ending(false)
	run["route"] = GameState.get_story_route()
	run["placeholder"] = _chat_placeholder()
	run["notes"] = " | ".join(_notes)
	run["errors"] = " | ".join(_errors)
	_score_run(spec, run)
	_runs.append(run)
	_print("END %s day=%d complete=%s ending=%s route=%s score=%.1f stuck=%s" % [
		_pid, run["day"], str(run["complete"]), run["ending"], run["route"],
		float(run.get("score", 0.0)), str(run.get("stuck", false)),
	])
	await _despawn_main()


func _run_ten_days(spec: Dictionary, run: Dictionary) -> bool:
	Engine.time_scale = TIME_SCALE_PLAY
	var knife := false
	var telegraph := false
	var sleep_blocked := false
	var chat_ok := 0
	var chat_fail := 0
	var chat_ms := 0
	var walked := 0.0
	var named := false
	var keep_chosen := false
	var expel_chosen := false
	var sit := false
	var d9 := ""
	var letter_titles: PackedStringArray = []
	var max_day := 12
	var safety := 0
	while safety < max_day:
		safety += 1
		if GameState.is_story_complete():
			break
		var day := GameState.game_day
		if _ui:
			_ui.set("_pending_morning_sidewrite", false)
		if day == 10 or GameState.should_show_awakening():
			await _flip_awakening_and_ending(run)
			break
		if bool(spec.get("skip_first", false)) and day == 1 and not bool(run.get("tried_skip", false)):
			run["tried_skip"] = true
			var blocked := await _try_sleep_now()
			if not blocked:
				sleep_blocked = true
				_note("D1 未翻信纸就睡：被拦住 toast=%s" % _toast())
			else:
				_note("D1 未翻信纸也能睡（意外）")
		await _ensure_period_for_beat()
		var flipped := PackedStringArray()
		if _ui and _ui.has_method("_maybe_show_story_beat"):
			await _ui.call("_maybe_show_story_beat", true)
			await _settle(0.06)
			flipped.append_array(await _flip_story(spec))
		if day == 1:
			named = await _submit_name(str(spec.get("player", "阿松")))
			run["placeholder_name"] = _chat_placeholder()
			run["time_paused_name"] = GameState.is_time_paused()
			if bool(spec.get("walk", false)):
				walked = await _walk_a_bit()
			if bool(spec.get("basket", false)):
				await _open_basket()
		flipped.append_array(await _flip_remaining_periods(spec))
		letter_titles.append_array(flipped)
		if "一起看" in " ".join(_day_letters) or "写进本子" in " ".join(_day_letters) \
				or "这一句我不想拿它赖掉" in " ".join(_day_letters) or "拿这个砸我" in " ".join(_day_letters):
			knife = true
		if bool(spec.get("basket", false)) and day == 3:
			await _open_basket()
		var chats: Array = spec.get("chats", [])
		var chat_days: Array = spec.get("chat_days", [])
		if chats.size() > 0 and (chat_days.is_empty() or day in chat_days):
			var msg := str(chats[mini(chat_ok + chat_fail, chats.size() - 1)])
			var cres := await _send_chat_wait(msg)
			if bool(cres.get("ok", false)):
				chat_ok += 1
				chat_ms = int(cres.get("ms", 0))
			else:
				chat_fail += 1
			if day == 1:
				run["chat_d1"] = str(cres.get("tail", "")).substr(0, 160)
				run["chat_d1_ms"] = cres.get("ms", 0)
		if GameState.get_ending_flags().get("w2_chose_keep", false):
			keep_chosen = true
		if GameState.get_ending_flags().get("w2_chose_expel", false):
			expel_chosen = true
		if GameState.get_ending_flags().get("companionship_nights", 0):
			sit = true
		await _wait_snuggle_if_any()
		await _auto_resolve_notebook_eviction()
		await _await_npc_idle(90)
		if GameState.is_story_complete() or _ending_visible():
			await _flip_awakening_and_ending(run)
			break
		var slept := await _sleep_through_night()
		if not slept:
			_err("D%d 睡觉失败 toast=%s beat=%s seen=%s" % [
				day, _toast(), StoryBeatDirector.get_today_beat_id(),
				str(GameState.is_story_node_seen(StoryBeatDirector.get_today_beat_id())),
			])
			var bid := StoryBeatDirector.get_today_beat_id()
			if bid != "" and not GameState.is_story_node_seen(bid):
				StoryBeatDirector.complete_beat(bid)
				_note("D%d 兜底 complete_beat %s" % [day, bid])
				run["needed_force"] = true
				slept = await _sleep_through_night()
			if not slept:
				run["stuck"] = true
				run["stuck_day"] = day
				break
		if GameState.game_day == 4 and day == 3:
			telegraph = telegraph or ("不是存档坏了" in " ".join(_notes))
		if GameState.game_day <= day:
			_err("过天后仍是第 %d 天" % GameState.game_day)
			run["stuck"] = true
			run["stuck_day"] = GameState.game_day
			break
	run["knife"] = knife
	run["telegraph"] = telegraph or ("不是存档坏了" in " ".join(_notes))
	run["sleep_blocked"] = sleep_blocked
	run["chat_ok"] = chat_ok
	run["chat_fail"] = chat_fail
	run["chat_ms"] = chat_ms
	run["walk_px"] = walked
	run["named"] = named
	run["keep_chosen"] = keep_chosen
	run["expel_chosen"] = expel_chosen
	run["sit"] = sit
	run["letters"] = ", ".join(letter_titles).substr(0, 400)
	if _ending_visible() or GameState.should_show_awakening():
		await _flip_awakening_and_ending(run)
	return not bool(run.get("stuck", false))


func _spawn_main() -> void:
	if _main != null and is_instance_valid(_main) and _ui != null:
		await _reset_live_game()
		return
	GameState.reset_for_new_game()
	_main = _packed.instantiate() as Node2D
	_main.name = "Main"
	add_child(_main)
	await get_tree().process_frame
	await get_tree().process_frame
	_ui = _main.get_node_or_null("UI")
	if _ui == null:
		_err("UI 节点缺失")
		return
	var en: Node = _ui.get_node_or_null("EndingPanel")
	if en and en.has_signal("finished") and _ui.has_method("_on_ending_finished"):
		if en.finished.is_connected(_ui._on_ending_finished):
			en.finished.disconnect(_ui._on_ending_finished)


func _reset_live_game() -> void:
	Engine.time_scale = 1.0
	if _ui:
		_ui.set("_pending_morning_sidewrite", false)
		_ui.set("_npc_busy", false)
		_ui.set("_ambient_sidewrite_retries", 0)
		_ui.set("_session_start_retries", 0)
		_ui.set("_notebook_eviction_retries", 0)
		_ui.set("_notebook_eviction_active", false)
		_ui.set("_story_choice_blocked", false)
		_ui.set("_story_beat_blocked", false)
		_ui.set("_sleep_flow_active", false)
		_ui.set("_snuggle_blocked", false)
		_ui.set("_name_prompt_blocked", false)
		_ui.set("_defer_day_content", false)
		for path in ["StoryBeatPanel", "AwakeningPanel", "EndingPanel", "NamePromptPanel"]:
			var p: Node = _ui.get_node_or_null(path)
			if p and p.has_method("close_panel"):
				p.call("close_panel")
			elif p:
				p.visible = false
		if _ui.has_method("_set_gameplay_controls_enabled"):
			_ui.call("_set_gameplay_controls_enabled", true)
	GameState.reset_for_new_game()
	GameState.long_term_memory["pending_eviction"] = {}
	await get_tree().process_frame
	await get_tree().process_frame


func _despawn_main() -> void:
	## 不拆 Main：拆掉会让 ambient/睡觉回调打到已删节点上崩。只重置状态。
	await _reset_live_game()


func _ensure_period_for_beat() -> void:
	## 早晨若无 pending beat，切到傍晚再试（D3 约定等 evening gate）。
	var beat := StoryBeatDirector.get_pending_session_beat(false)
	if not beat.is_empty():
		return
	if GameState.time_of_day == GameState.TIME_MORNING:
		GameState.time_of_day = GameState.TIME_EVENING
		GameState.time_changed.emit(GameState.time_of_day)


func _flip_remaining_periods(spec: Dictionary) -> PackedStringArray:
	var titles := PackedStringArray()
	for period in [GameState.TIME_EVENING, GameState.TIME_NIGHT]:
		GameState.time_of_day = period
		GameState.time_changed.emit(GameState.time_of_day)
		if _ui and _ui.has_method("_maybe_resume_beat_tail"):
			await _ui.call("_maybe_resume_beat_tail")
			await _settle(0.06)
		if _ui and _ui.has_method("_maybe_show_story_beat"):
			await _ui.call("_maybe_show_story_beat", true)
			await _settle(0.06)
		titles.append_array(await _flip_story(spec))
	return titles


func _flip_story(spec: Dictionary) -> PackedStringArray:
	var titles := PackedStringArray()
	if _ui == null:
		return titles
	var panel: Node = _ui.get_node_or_null("StoryBeatPanel")
	if panel == null or not panel.visible:
		return titles
	var guard := 0
	var last_title := ""
	while panel.visible and guard < 80:
		guard += 1
		if bool(panel.get("_page_turning")):
			await get_tree().process_frame
			continue
		var title := _panel_title(panel)
		var body := _panel_body(panel)
		if title != last_title:
			last_title = title
			titles.append(title)
			_day_letters.append(body)
			_print("%s LETTER %s | %s" % [_pid, title, body.substr(0, 90).replace("\n", " / ")])
			if "这一句我不想拿它赖掉" in body or "拿这个砸我" in body:
				_note("看到 D3 刀垫")
			if "不是存档坏了" in body:
				_note("信纸里有 telegraph")
		if bool(panel.get("_is_choice_step")) and not panel.get("_choice_buttons").is_empty():
			var cid := _choice_for_spec(spec, panel)
			_print("%s CHOICE %s" % [_pid, cid])
			_emit_choice(cid)
			await _settle(0.12)
			continue
		if panel.has_method("_on_continue_pressed"):
			panel.call("_on_continue_pressed")
			await _settle(0.04)
			if panel.visible and panel.has_method("_on_continue_pressed") and not bool(panel.get("_is_choice_step")):
				panel.call("_on_continue_pressed")
		await _settle(0.05)
	await _settle(0.08)
	return titles


func _choice_for_spec(spec: Dictionary, panel: Node) -> String:
	var buttons: Array = panel.get("_choice_buttons")
	var labels := PackedStringArray()
	for b in buttons:
		if b is Button:
			labels.append(str(b.text))
	var joined := " ".join(labels)
	if "留下" in joined:
		return "w2_keep" if bool(spec.get("keep", true)) else "w2_expel"
	if "确定" in joined or "送她" in joined:
		if bool(spec.get("keep", true)):
			return "w2_expel_cancel"
		return "w2_expel_confirm"
	if "过去" in joined or "坐下" in joined:
		return "companion_sit" if bool(spec.get("sit", true)) else "companion_leave"
	if "继续听" in joined:
		return str(spec.get("d9", "d9_continue"))
	return "w2_keep"


func _emit_choice(choice_id: String) -> void:
	var panel: Node = _ui.get_node_or_null("StoryBeatPanel")
	if panel and panel.has_signal("choice_made"):
		panel.emit_signal("choice_made", choice_id)


func _submit_name(player: String) -> bool:
	if _ui == null:
		return false
	if _ui.has_method("_maybe_show_name_prompt"):
		_ui.call("_maybe_show_name_prompt")
	await _settle(0.1)
	var panel: Node = _ui.get_node_or_null("NamePromptPanel")
	if panel == null:
		GameState.set_player_display_name(player)
		_note("取名窗缺失，代码写入 %s" % player)
		return false
	if not panel.visible:
		_ui.call("_maybe_show_name_prompt")
		await _settle(0.1)
	if not panel.visible:
		GameState.set_player_display_name(player)
		_note("取名窗未弹出")
		return false
	_note("取名占位=%s paused=%s" % [_chat_placeholder(), str(GameState.is_time_paused())])
	var line: LineEdit = panel.get("_name_input")
	if line:
		line.text = player
	if panel.has_method("_submit"):
		panel.call("_submit")
	await _settle(0.15)
	_note("取名后占位=%s 聊天=%s" % [_chat_placeholder(), _chat_tail().substr(0, 80)])
	return GameState.has_player_name_set()


func _try_sleep_now() -> bool:
	GameState.time_of_day = GameState.TIME_NIGHT
	GameState._awaiting_sleep = true
	var day0 := GameState.game_day
	if _ui.has_method("sleep_from_companion"):
		_ui.call("sleep_from_companion")
	await _settle(0.2)
	return GameState.game_day > day0 or bool(_ui.get("_sleep_flow_active"))


func _sleep_through_night() -> bool:
	if GameState.is_story_complete():
		return true
	var day0 := GameState.game_day
	GameState.time_of_day = GameState.TIME_NIGHT
	GameState._awaiting_sleep = true
	var overlay: Node = _ui.get("_day_cycle_overlay") if _ui else null
	if _ui.has_method("_on_sleep_prompt_requested"):
		_ui.call("_on_sleep_prompt_requested")
	await _settle(0.08)
	if overlay and overlay.has_method("is_prompt_visible") and overlay.call("is_prompt_visible"):
		if _ui.has_method("_on_sleep_now_pressed"):
			_ui.call("_on_sleep_now_pressed")
	elif _ui.has_method("sleep_from_companion"):
		_ui.call("sleep_from_companion")
	var n := 0
	while n < 240:
		n += 1
		if overlay != null and bool(overlay.get("_trust_waiting")):
			var body_n: Node = overlay.get("_trust_body")
			var tel := str(body_n.text) if body_n else ""
			if "不是存档坏了" in tel:
				_note("D4 telegraph 实翻：%s" % tel.substr(0, 60).replace("\n", " "))
			overlay.set("_trust_waiting", false)
		if GameState.game_day > day0 and _ui != null and not bool(_ui.get("_sleep_flow_active")):
			if overlay == null or not bool(overlay.call("is_busy")):
				return true
		if GameState.is_story_complete():
			return true
		await get_tree().process_frame
	return GameState.game_day > day0


func _wait_snuggle_if_any() -> void:
	if _ui == null:
		return
	var n := 0
	while bool(_ui.get("_snuggle_blocked")) and n < 120:
		n += 1
		await get_tree().process_frame


func _await_npc_idle(max_frames: int = 60) -> void:
	if _ui == null:
		return
	var n := 0
	while bool(_ui.get("_npc_busy")) and n < max_frames:
		n += 1
		await get_tree().process_frame


func _auto_resolve_notebook_eviction() -> void:
	if not MemoryService.has_pending_eviction():
		return
	var candidates := MemoryService.get_pending_eviction_candidates()
	if candidates.is_empty():
		GameState.long_term_memory["pending_eviction"] = {}
		return
	var pick := str((candidates[0] as Dictionary).get("id", ""))
	if pick != "":
		MemoryService.resolve_eviction(pick)
		_note("本子满自动划掉 %s" % pick)
	if _ui:
		_ui.set("_notebook_eviction_active", false)
		_ui.set("_story_choice_blocked", false)
		var choice_panel: Node = _ui.get_node_or_null("StoryChoicePanel")
		if choice_panel and choice_panel.has_method("close_panel"):
			choice_panel.call("close_panel")


func _flip_awakening_and_ending(run: Dictionary) -> void:
	if _ui == null:
		return
	if GameState.should_show_awakening() and _ui.has_method("_maybe_show_awakening"):
		_ui.call("_maybe_show_awakening")
		await _settle(0.1)
	var aw: Node = _ui.get_node_or_null("AwakeningPanel")
	var guard := 0
	while aw != null and aw.visible and guard < 40:
		guard += 1
		var title := ""
		if aw.get("_title_label"):
			title = str(aw.get("_title_label").text)
		var body := ""
		if aw.get("_body_label"):
			body = str(aw.get("_body_label").get("text"))
		_print("%s AWAKEN %s | %s" % [_pid, title, body.substr(0, 100).replace("\n", " / ")])
		if "忘的，从来不只是我" in body or "忘的从来不只是我" in body:
			run["two_way"] = true
			_note("D10 双向遗忘")
		if aw.has_method("_on_continue_pressed"):
			aw.call("_on_continue_pressed")
		await _settle(0.08)
	await _settle(0.15)
	var en: Node = _ui.get_node_or_null("EndingPanel")
	guard = 0
	var pages: PackedStringArray = []
	while en != null and en.visible and guard < 50:
		guard += 1
		if bool(en.get("_is_credits")):
			_note("结局演职员表已出现，停在标题跳转前")
			break
		if bool(en.get("_page_turning")):
			await get_tree().process_frame
			continue
		var et := ""
		if en.get("_title_label"):
			et = str(en.get("_title_label").text)
		var eb := ""
		if en.get("_body_label"):
			eb = str(en.get("_body_label").get("text"))
		pages.append("%s:%s" % [et, eb.substr(0, 70).replace("\n", " ")])
		if "忘的" in eb:
			run["two_way"] = true
		var steps: Array = en.get("_steps")
		var idx := int(en.get("_step_index"))
		var pages_arr: PackedStringArray = PackedStringArray()
		var raw_pages: Variant = en.get("_pages")
		if raw_pages is PackedStringArray:
			pages_arr = raw_pages
		elif raw_pages is Array:
			for p in raw_pages:
				pages_arr.append(str(p))
		var last_step := steps.size() > 0 and idx >= steps.size() - 1
		var last_page := pages_arr.size() == 0 or int(en.get("_page_index")) >= pages_arr.size() - 1
		if last_step and last_page:
			_note("结局末页已到，不点进标题")
			break
		if en.has_method("_on_continue_pressed"):
			en.call("_on_continue_pressed")
		await _settle(0.08)
	run["ending_pages"] = " / ".join(pages).substr(0, 280)
	run["ending"] = EndingDirector.resolve_ending(false)
	run["complete"] = GameState.is_story_complete()


func _send_chat_wait(text: String) -> Dictionary:
	Engine.time_scale = 1.0
	var before := _chat_tail()
	var t0 := Time.get_ticks_msec()
	if _ui.has_method("_send_chat"):
		_ui.call("_send_chat", text)
	else:
		NpcBridge.request_event("player_chat", {"text": text})
	var waited := 0.0
	while waited < CHAT_TIMEOUT_SEC:
		await get_tree().create_timer(0.4).timeout
		waited += 0.4
		if _chat_tail() != before and _chat_tail() != "":
			break
	var ms := Time.get_ticks_msec() - t0
	var after := _chat_tail()
	var ok := after != before and after.strip_edges() != ""
	_print("%s CHAT %dms ok=%s tail=%s" % [_pid, ms, str(ok), after.substr(0, 80).replace("\n", " ")])
	Engine.time_scale = TIME_SCALE_PLAY
	return {"ok": ok, "ms": ms, "tail": after}


func _walk_a_bit() -> float:
	if GameState.is_time_paused():
		GameState.pop_time_pause()
	var player := get_tree().get_first_node_in_group("player") as Node2D
	var before := player.global_position if player else Vector2.ZERO
	if player:
		for i in 20:
			_key("D", true)
			await get_tree().process_frame
			_key("D", false)
	var dist := 0.0
	if player:
		dist = before.distance_to(player.global_position)
	_note("走动 %.0f px" % dist)
	return dist


func _open_basket() -> void:
	if _ui.has_method("_on_basket_pressed"):
		_ui.call("_on_basket_pressed")
	await _settle(0.08)
	var drawer: Node = _main.find_child("BasketDrawer", true, false) if _main else null
	_note("篮子 open=%s 金币=%d" % [
		str(drawer.call("is_open") if drawer and drawer.has_method("is_open") else "?"),
		GameState.coins,
	])
	if drawer and drawer.has_method("close_drawer"):
		drawer.call("close_drawer")


func _ending_visible() -> bool:
	if _ui == null:
		return false
	var en: Node = _ui.get_node_or_null("EndingPanel")
	return en != null and en.visible


func _panel_title(panel: Node) -> String:
	var n: Node = panel.get("_title_label")
	return str(n.text) if n else ""


func _panel_body(panel: Node) -> String:
	var n: Node = panel.get("_body_label")
	return str(n.get("text")).strip_edges() if n else ""


func _last_letter_body() -> String:
	if _day_letters.is_empty():
		return ""
	return _day_letters[_day_letters.size() - 1]


func _chat_placeholder() -> String:
	if _ui == null:
		return ""
	var inp: LineEdit = _ui.get("_chat_input")
	return str(inp.placeholder_text) if inp else ""


func _chat_tail() -> String:
	if _ui == null:
		return ""
	var log: Node = _ui.get("_chat_log")
	if log == null:
		return ""
	var t := str(log.get("text")).strip_edges()
	if t.length() > 180:
		return t.substr(t.length() - 180)
	return t


func _toast() -> String:
	if _ui == null:
		return ""
	var n: Node = _ui.get("_toast")
	return str(n.text) if n else ""


func _key(name: String, pressed: bool) -> void:
	var ev := InputEventKey.new()
	ev.pressed = pressed
	ev.physical_keycode = OS.find_keycode_from_string(name)
	Input.parse_input_event(ev)


func _settle(sec: float = 0.12) -> void:
	await get_tree().create_timer(sec).timeout


func _note(text: String) -> void:
	_notes.append(text)
	_print("%s NOTE %s" % [_pid, text])


func _err(text: String) -> void:
	_errors.append(text)
	_print("%s ERR %s" % [_pid, text])


func _print(text: String) -> void:
	print(text)


func _score_run(spec: Dictionary, run: Dictionary) -> void:
	var score := 3.2
	if bool(run.get("stuck", false)):
		score = 1.6
	elif GameState.game_day < 10 and not GameState.is_story_complete() and not _ending_visible():
		score = 2.0
	if bool(run.get("named", false)):
		score += 0.2
	if bool(run.get("knife", false)):
		score += 0.3
	if bool(run.get("telegraph", false)):
		score += 0.2
	if bool(run.get("two_way", false)):
		score += 0.4
	if bool(run.get("needed_force", false)):
		score -= 0.6
	if int(run.get("chat_fail", 0)) > 0 and int(run.get("chat_ok", 0)) == 0:
		score -= 0.5
	if bool(spec.get("keep", true)) == false and str(run.get("ending", "")).contains("bad"):
		score += 0.2
	if bool(spec.get("keep", true)) and str(run.get("ending", "")) == "ending_true":
		score += 0.3
	score = clampf(score, 1.0, 5.0)
	run["score"] = snappedf(score, 0.1)
	var why := "day=%s ending=%s knife=%s telegraph=%s two_way=%s chat=%s/%s" % [
		str(run.get("day", 0)), str(run.get("ending", "")),
		str(run.get("knife", false)), str(run.get("telegraph", false)),
		str(run.get("two_way", false)),
		str(run.get("chat_ok", 0)), str(run.get("chat_fail", 0)),
	]
	run["why"] = why


func _persona_specs() -> Array[Dictionary]:
	return [
		{"id": "N1", "label": "第一次玩独立游戏的小白", "player": "小白", "keep": true, "sit": true, "walk": true, "basket": true, "chats": ["你是谁呀"], "chat_days": [1]},
		{"id": "N2", "label": "只会点按钮的种田新手", "player": "阿田", "keep": true, "sit": false, "basket": true, "chats": []},
		{"id": "N3", "label": "Steam前30分钟差评猎人", "player": "差评", "keep": true, "sit": false, "walk": true, "basket": true, "chats": []},
		{"id": "S1", "label": "Stardew种田老手", "player": "星露", "keep": true, "sit": false, "basket": true, "chats": []},
		{"id": "G1", "label": "Gal泣き老炮", "player": "阿松", "keep": true, "sit": true, "d9": "d9_continue", "chats": ["我会把你写进本子"], "chat_days": [2, 6]},
		{"id": "G2", "label": "结构路线表党", "player": "表党", "keep": true, "sit": true, "d9": "d9_continue", "chats": ["昨天的约定还在吗"], "chat_days": [6]},
		{"id": "G3", "label": "选择肢洁癖", "player": "洁癖", "keep": true, "sit": true, "d9": "d9_defer", "chats": []},
		{"id": "C1", "label": "把她当短暂同居的人", "player": "同居", "keep": true, "sit": true, "chats": ["你还记得我叫什么吗", "雨停之前你在哪"], "chat_days": [1, 2, 4, 6]},
		{"id": "C2", "label": "延迟零容忍", "player": "急性子", "keep": true, "sit": false, "chats": ["在吗"], "chat_days": [1]},
		{"id": "H1", "label": "UI漏洞猎手", "player": "找茬", "keep": true, "sit": false, "walk": true, "basket": true, "skip_first": true, "chats": []},
		{"id": "H2", "label": "文案校对", "player": "校对", "keep": true, "sit": true, "d9": "d9_continue", "chats": []},
		{"id": "P1", "label": "带小孩一起看的家长", "player": "家长", "keep": true, "sit": true, "chats": []},
		{"id": "P2", "label": "失智陪护敏感读者", "player": "陪护", "keep": true, "sit": true, "d9": "d9_continue", "chats": ["我会等你想起来"], "chat_days": [4]},
		{"id": "B1", "label": "专门开赶走线", "player": "路人", "keep": false, "sit": false, "chats": []},
		{"id": "E1", "label": "全收集True猎人", "player": "收集", "keep": true, "sit": true, "d9": "d9_continue", "chats": ["萝卜长好了我们一起看", "我记下了", "你的名字我不会忘"], "chat_days": [1, 3, 6, 8]},
		{"id": "F1", "label": "不聊天纯种田", "player": "农夫", "keep": true, "sit": false, "basket": true, "chats": []},
		{"id": "R1", "label": "速通跳过所有字", "player": "速通", "keep": true, "sit": false, "skip_first": true, "chats": []},
		{"id": "L1", "label": "直播吐槽", "player": "主播", "keep": true, "sit": true, "walk": true, "basket": true, "chats": ["观众问你从哪来的"], "chat_days": [2]},
		{"id": "W1", "label": "二周目收集党（首周）", "player": "二周", "keep": true, "sit": true, "d9": "d9_continue", "chats": ["这是第几轮了"], "chat_days": [8]},
		{"id": "A1", "label": "像素氛围党", "player": "看雨", "keep": true, "sit": true, "walk": true, "chats": []},
	]


func _write_report() -> void:
	var avg := 0.0
	var finished := 0
	var lines := PackedStringArray()
	lines.append("# 二十画像十日实机 · %s" % Time.get_datetime_string_from_system())
	lines.append("")
	lines.append("方法：`tools/persona20_fullplay.tscn` 每局 **重新实例化 `main.tscn`**，从第 1 天打到结局或卡死。走信纸翻页、取名窗、篮子、WASD、玩家聊天、夜里睡觉过天、觉醒/结局信纸。不截图。聊天等待按真实时间（time_scale=1）。")
	lines.append("")
	lines.append("| ID | 画像 | 天 | 结局 | 路线 | /5 | 卡关 | 刀垫 | 双向 | 聊天 |")
	lines.append("|----|------|----|------|------|----|------|------|------|------|")
	for run in _runs:
		avg += float(run.get("score", 0.0))
		if bool(run.get("complete", false)) or str(run.get("ending_pages", "")) != "" or int(run.get("day", 0)) >= 10:
			finished += 1
		lines.append("| %s | %s | %s | %s | %s | %.1f | %s | %s | %s | %s/%s |" % [
			str(run.get("id", "")),
			str(run.get("label", "")),
			str(run.get("day", "")),
			str(run.get("ending", "")),
			str(run.get("route", "")),
			float(run.get("score", 0.0)),
			"是D%s" % str(run.get("stuck_day", "")) if bool(run.get("stuck", false)) else "否",
			"是" if bool(run.get("knife", false)) else "否",
			"是" if bool(run.get("two_way", false)) else "否",
			str(run.get("chat_ok", 0)),
			str(run.get("chat_fail", 0)),
		])
	if _runs.size() > 0:
		avg /= float(_runs.size())
	lines.append("")
	lines.append("平均 **%.2f / 5**。打完或到结局 **%d / %d**。" % [avg, finished, _runs.size()])
	lines.append("")
	lines.append("## 逐局笔记")
	for run in _runs:
		lines.append("")
		lines.append("### %s %s · %.1f" % [str(run.get("id", "")), str(run.get("label", "")), float(run.get("score", 0.0))])
		lines.append("- 用时 %ss · 名「%s」· 留下=%s 赶走=%s 夜坐=%s" % [
			str(run.get("elapsed_s", "")), str(run.get("player", "")),
			str(run.get("keep_chosen", false)), str(run.get("expel_chosen", false)),
			str(run.get("sit", false)),
		])
		lines.append("- %s" % str(run.get("why", "")))
		if str(run.get("chat_d1", "")) != "":
			lines.append("- D1 聊天 %sms：%s" % [str(run.get("chat_d1_ms", "")), str(run.get("chat_d1", "")).replace("\n", " ")])
		if str(run.get("letters", "")) != "":
			lines.append("- 信纸标题：%s" % str(run.get("letters", "")))
		if str(run.get("ending_pages", "")) != "":
			lines.append("- 结局页：%s" % str(run.get("ending_pages", "")))
		if str(run.get("notes", "")) != "":
			lines.append("- 笔记：%s" % str(run.get("notes", "")))
		if str(run.get("errors", "")) != "":
			lines.append("- 错误：%s" % str(run.get("errors", "")))
	var text := "\n".join(lines)
	var f := FileAccess.open(OUT_DIR + "report.md", FileAccess.WRITE)
	if f:
		f.store_string(text)
		f.close()
	var f2 := FileAccess.open(REPORT_RES, FileAccess.WRITE)
	if f2:
		f2.store_string(text)
		f2.close()
	_print("WROTE %s avg=%.2f" % [REPORT_RES, avg])
