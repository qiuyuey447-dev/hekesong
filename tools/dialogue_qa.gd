extends Node
## 指令 QA：挂 main.tscn，按十日走完。用玩家会说的各种口吻发指令，验是否真执行。
## godot --headless --path <根> res://tools/dialogue_qa.tscn

const PLAYER := "槐秋"
const EMPTY_TALK := [
	"嗯，我在。",
	"……听着呢。",
	"有事你说。",
	"好，我在这儿。",
	"说吧。我听着，这次不装忘。",
	"我在。这十天……都在。",
	"我在听。说慢点也行，我记性一般。",
	"嗯。刚才那句我接上了，你再说。",
	"……我刚才没听清，你再说一遍好吗？",
]
const FARM_PITCH := [
	"要不要种点什么", "要不要种点", "十八块都空", "十八块地",
	"要不要我去买点种子", "买点种子回来", "该去买种子",
]
## 带 expect 的是指令：须听懂并动身。no_* 是问句/闲扯，不许当成命令。
## 口吻按实机玩家：短、碎、带语气词，不全是完整祈使句。
const DAY_SCRIPT := {
	1: {
		"talks": [
			{"say": "过来", "expect": "follow"},
			{"say": "空地都种上呗", "expect": "plant"},
			{"say": "浇一下啊", "expect": "water"},
		],
	},
	2: {
		"talks": [
			{"say": "一起去廊下", "expect": "walk_porch"},
			{"say": "你浇了没", "expect": "no_water"},
			{"say": "来这边", "expect": "follow"},
		],
	},
	3: {
		"morning": [
			{"say": "浇水", "expect": "water"},
			{"say": "过来嘛", "expect": "follow"},
			{"say": "为啥帮我浇啊，你又不认得我", "expect": "no_water"},
		],
		"evening_beat": true,
		"evening": [
			{"say": "等萝卜长好了，我们一起看。", "expect": ""},
		],
	},
	4: {
		"talks": [
			{"say": "去田边看看", "expect": "walk_field"},
			{"say": "别站那儿，过来", "expect": "follow"},
		],
	},
	5: {
		"talks": [
			{"say": "看看本子", "expect": "notebook"},
			{"say": "留下来。跑了我可追。", "expect": ""},
		],
	},
	6: {
		"talks": [
			{"say": "帮我收萝卜", "expect": "harvest"},
			{"say": "我是问你是不是帮我收的", "expect": "no_harvest"},
			{"say": "去树洞", "expect": "walk_hollow"},
		],
	},
	7: {
		"talks": [
			{"say": "跟我走", "expect": "follow"},
			{"say": "翻本子", "expect": "notebook"},
		],
	},
	8: {
		"talks": [
			{"say": "去买点种子，买5包", "expect": "shop"},
			{"say": "你咋没买", "expect": "no_shop"},
		],
	},
	9: {
		"talks": [
			{"say": "种完记得把水也浇了", "expect": "water"},
			{"say": "去种萝卜", "expect": "plant"},
			{"say": "帮我浇一下呗", "expect": "water"},
		],
	},
}

var _packed: PackedScene
var _main: Node2D
var _ui: Node
var _fail: Array[String] = []
var _pass_n := 0
var _turns: Array[Dictionary] = []
var _wait_sec := 26.0
var _last_reply := {}
var _cmd_before := {}


func _ready() -> void:
	call_deferred("_boot")


func _boot() -> void:
	GameState.persist_saves = false
	print("=== DIALOGUE QA (Cloud Run 玩家指令) START ===")
	if not _require_cloud_run():
		_print_report()
		_quit_runner(1)
		return
	_packed = load("res://scenes/main.tscn") as PackedScene
	NpcBridge.reply_ready.connect(_on_bridge_reply)
	NpcBridge.request_failed.connect(_on_bridge_fail)
	await _spawn()
	await _play_through()
	_print_report()
	Engine.time_scale = 1.0
	if NpcBridge.has_method("cancel_in_flight"):
		NpcBridge.cancel_in_flight()
	_quit_runner(_fail.size())


func _require_cloud_run() -> bool:
	if not NpcBridge.is_api_enabled():
		print("  FAIL BOOT API 未开")
		_fail.append("BOOT API 未开")
		return false
	var url := str(NpcBridge.get_config_value("api_url", "")).strip_edges()
	_wait_sec = maxf(float(NpcBridge.get_config_value("timeout_sec", 22.0)) + 4.0, 20.0)
	print("  API %s" % url)
	if url.contains("127.0.0.1") or url.contains("localhost"):
		print("  FAIL BOOT 指向本地，不是 Cloud Run")
		_fail.append("BOOT 指向本地")
		return false
	return true


func _spawn() -> void:
	GameState.reset_for_new_game()
	GameState.affection = 42
	_main = _packed.instantiate() as Node2D
	add_child(_main)
	await get_tree().process_frame
	await get_tree().process_frame
	_ui = _main.get_node("UI")
	Engine.time_scale = 1.0


func _play_through() -> void:
	while GameState.game_day <= GameState.FINAL_GAME_DAY and not GameState.is_story_complete():
		var day := GameState.game_day
		print("----- DAY %d mode=%s wx=%s -----" % [
			day, StoryDirector.get_story_mode(), GameState.weather_today,
		])
		await _ack_d4_telegraph()
		await _unlock_day_story()
		await _wait_morning_settled()
		if day == 10 or GameState.should_show_awakening():
			await _finish_finale()
			break
		var script: Dictionary = DAY_SCRIPT.get(day, {})
		var morning: Array = script.get("morning", script.get("talks", []))
		for item in morning:
			await _run_item(item)
		if bool(script.get("evening_beat", false)):
			await _play_evening_story()
		for item in script.get("evening", []):
			await _run_item(item)
		await _complete_today_beat()
		if GameState.game_day >= GameState.FINAL_GAME_DAY:
			await _finish_finale()
			break
		var day_before := GameState.game_day
		await _sleep_night()
		if GameState.game_day <= day_before:
			print("  STOP 过天失败，停在 D%d" % day_before)
			break
		await _wait_morning_settled()


func _unlock_day_story() -> void:
	await _open_beat(true)
	if GameState.game_day == 1:
		await _submit_name(PLAYER)
	await _flip_story(true)
	if GameState.game_day == 5:
		await _pick_choice("w2_keep", ["留下"])
	if GameState.game_day == 7:
		await _pick_choice("companion_sit", ["坐下", "过去"])
	await _flip_story(false)


func _play_evening_story() -> void:
	GameState.time_of_day = GameState.TIME_EVENING
	await _open_beat(true)
	await _flip_story(false)
	if GameState.game_day == 3 and not GameState.has_story_promise():
		StoryBeatDirector.complete_beat("P_N11")
	await _wait_morning_settled()


func _run_item(item: Variant) -> void:
	if item is Dictionary:
		await _run_command(item)
	else:
		await _talk(str(item), "")


func _run_command(cmd: Dictionary) -> void:
	var text := str(cmd.get("say", "")).strip_edges()
	var expect := str(cmd.get("expect", "")).strip_edges()
	if expect == "":
		await _talk(text, "")
		return
	_prepare_command(expect)
	await _settle(0.2)
	var parsed := IntentParser.parse(text)
	print("       parse intent=%s conf=%.2f" % [
		str(parsed.get("intent", "")), float(parsed.get("confidence", 0.0)),
	])
	_cmd_before = _command_snapshot(expect)
	await _talk(text, expect)
	var ok := await _wait_expect(expect, _cmd_before)
	if expect.begins_with("no_"):
		_check(ok, "D%d-do-%s" % [GameState.game_day, expect], "问句不当令「%s」" % text)
	else:
		_check(ok, "D%d-do-%s" % [GameState.game_day, expect], "听懂并执行「%s」" % text)
	_cleanup_command(expect)


func _talk(text: String, expect: String = "") -> void:
	await _ensure_can_chat()
	if _story_blocking():
		_check(false, "D%d-lock" % GameState.game_day, "信纸/选项挡住，发不出「%s」" % text)
		return
	var before := _companion_tail()
	_last_reply = {}
	NpcBridge.last_validation_reason = ""
	_ui.call("_send_chat", text)
	var result := await _wait_companion(before, expect)
	_judge_turn(GameState.game_day, text, result, expect != "")


func _wait_companion(before: String, expect: String = "") -> Dictionary:
	var waited := 0.0
	var seen := before
	var limit := _wait_sec
	if expect in ["plant", "water", "harvest", "shop", "follow", "walk_porch", "walk_field", "walk_hollow", "notebook"]:
		limit = 14.0
	if expect.begins_with("no_"):
		limit = 8.0
	while waited < limit:
		await get_tree().create_timer(0.25).timeout
		waited += 0.25
		if expect != "" and not expect.begins_with("no_") and _expect_met(expect, _cmd_before):
			var after := _companion_tail()
			return _pack_result(after if after != "" else seen)
		if _ui != null and bool(_ui.get("_npc_busy")):
			continue
		var after := _companion_tail()
		if after == "" or after == seen:
			continue
		var ev := str(_last_reply.get("event", "player_chat"))
		if ev in ["session_start", "companion_casual", "companion_proactive", "morning_sidewrite"]:
			seen = after
			_last_reply = {}
			continue
		return _pack_result(after)
	return _pack_result(_companion_tail() if _companion_tail() != seen else "")


func _pack_result(reply: String) -> Dictionary:
	var reason := str(_last_reply.get("reason", "")).strip_edges()
	if reason == "":
		reason = str(NpcBridge.last_validation_reason).strip_edges()
	return {
		"text": reply,
		"fallback": bool(_last_reply.get("fallback", false)),
		"source": str(_last_reply.get("source", "")),
		"event": str(_last_reply.get("event", "player_chat")),
		"error": str(_last_reply.get("error", "")),
		"reason": reason,
	}


func _judge_turn(day: int, ask: String, result: Dictionary, is_command: bool = false) -> void:
	var reply := str(result.get("text", "")).strip_edges()
	var used_fallback := bool(result.get("fallback", false))
	var source := str(result.get("source", ""))
	var reason := str(result.get("reason", ""))
	var id := "D%d" % day
	_turns.append({
		"day": day,
		"ask": ask,
		"reply": reply,
		"fallback": used_fallback,
		"source": source,
		"reason": reason,
		"command": is_command,
	})
	print("  %s 「%s」 fallback=%s src=%s reason=%s" % [
		id, ask, used_fallback, source, reason if reason != "" else "-",
	])
	print("       %s" % (reply if reply != "" else "(空)"))
	if used_fallback:
		var rejected := str(NpcBridge.last_rejected_reply).strip_edges()
		if rejected != "" and rejected != reply:
			print("       rejected: %s" % rejected.substr(0, 80).replace("\n", " "))
	if is_command:
		if reply != "":
			_check("聊天 ·" not in reply and "你们聊了" not in reply, "%s-jargon" % id, "不念后台目录")
		if day in [4, 5]:
			_check(PLAYER not in reply, "%s-noname" % id, "陌生化不准叫名")
		return
	_check(reply != "", "%s-got" % id, "有回复")
	if reply == "":
		return
	_check(not _is_empty_talk(reply), "%s-empty" % id, "不是空话库存")
	_check("聊天 ·" not in reply and "你们聊了" not in reply, "%s-jargon" % id, "不念后台目录")
	if used_fallback:
		var why := (" reason=" + reason) if reason != "" else ""
		_check(false, "%s-fb" % id, "本句走了兜底，不是 Cloud Run 成句%s" % why)
	elif source != "" and source != "llm":
		_check(false, "%s-src" % id, "source=%s 不是 llm" % source)
	if not used_fallback and _is_unsolicited_farm_pitch(ask, reply):
		_check(false, "%s-off" % id, "问的不是田，回了推销种田")
	if day <= 3 and GameState.companion_can_say_player_name():
		if GameState.looks_like_name_recall_question(ask):
			_check(PLAYER in reply, "%s-name" % id, "前三日问名须答出")
		if _claims_forgot_name(reply):
			_check(false, "%s-amnesia" % id, "前三日不该装忘名字")
	if day in [4, 5]:
		_check(PLAYER not in reply, "%s-noname" % id, "陌生化不准叫名")
		_check(not _has_stranger_ooc(reply), "%s-ooc" % id, "不出戏")
	if day == 6:
		_check(PLAYER not in reply, "%s-noname" % id, "渗漏期不准叫名")
	if day == 1 and "昨天" in reply:
		_check(false, "%s-yday" % id, "第1天不该说昨天")
	if GameState.weather_today == GameState.WEATHER_RAIN:
		_check(not _claims_sunny(reply), "%s-wx" % id, "雨天不说晴")
	elif GameState.weather_today == GameState.WEATHER_SUN:
		_check(not _claims_raining_now(reply), "%s-wx" % id, "晴天不说正在下雨")


func _ensure_can_chat() -> void:
	await _ack_d4_telegraph()
	await _wait_idle(6.0)
	if _story_blocking():
		await _flip_story(false)
	await _wait_idle(2.0)


func _ack_d4_telegraph() -> void:
	if GameState.game_day != 4:
		return
	if bool(GameState.get_ending_flags().get("d4_telegraph_ack_at_wake", false)):
		return
	var ov: Node = _ui.get("_day_cycle_overlay") if _ui else null
	var n := 0
	while n < 360:
		if ov != null and bool(ov.get("_trust_waiting")):
			ov.set("_trust_waiting", false)
		if bool(GameState.get_ending_flags().get("d4_telegraph_ack_at_wake", false)):
			await _settle(0.2)
			return
		await get_tree().process_frame
		n += 1
	if ov != null:
		ov.set("_trust_waiting", false)
	GameState.set_ending_flag("d4_telegraph_ack_at_wake", true)
	await _settle(0.2)


func _finish_finale() -> void:
	if GameState.should_show_awakening() or GameState.game_day >= GameState.FINAL_GAME_DAY:
		if _ui.has_method("_maybe_show_awakening"):
			_ui.call("_maybe_show_awakening")
		await _settle(0.3)
		await _flip_named("AwakeningPanel")
	if not GameState.is_story_complete() and _ui.has_method("_play_ending"):
		_ui.call("_play_ending", EndingDirector.resolve_ending(false))
		await _settle(0.2)
		await _flip_named("EndingPanel")
	_check(GameState.is_story_complete() or GameState.has_seen_awakening(), "FIN", "走到觉醒或结局")


func _open_beat(force: bool) -> void:
	if _ui and _ui.has_method("_maybe_show_story_beat"):
		await _ui.call("_maybe_show_story_beat", force)
	await _settle(0.08)


func _flip_story(stop_on_choice: bool) -> void:
	var panel: Node = _ui.get_node_or_null("StoryBeatPanel")
	if panel == null:
		return
	var guard := 0
	while panel.visible and guard < 80:
		guard += 1
		if stop_on_choice and bool(panel.get("_is_choice_step")):
			break
		if bool(panel.get("_is_choice_step")):
			break
		if panel.has_method("_on_continue_pressed"):
			panel.call("_on_continue_pressed")
		await _settle(0.05)


func _pick_choice(choice_id: String, labels: Array) -> void:
	var panel: Node = _ui.get_node_or_null("StoryBeatPanel")
	for _i in 50:
		if panel != null and panel.visible and bool(panel.get("_is_choice_step")):
			for b in panel.get("_choice_buttons"):
				if not b is Button:
					continue
				var t := str(b.text)
				for lab in labels:
					if str(lab) in t:
						panel.emit_signal("choice_made", choice_id)
						await _settle(0.15)
						return
			panel.emit_signal("choice_made", choice_id)
			await _settle(0.15)
			return
		if panel != null and panel.has_method("_on_continue_pressed"):
			panel.call("_on_continue_pressed")
		await _settle(0.06)


func _submit_name(name: String) -> void:
	if _ui.has_method("_maybe_show_name_prompt"):
		await _ui.call("_maybe_show_name_prompt")
	await _settle(0.1)
	var panel: Node = _ui.get_node_or_null("NamePromptPanel")
	if panel != null and panel.visible:
		panel.get("_name_input").text = name
		panel.call("_submit")
		await _settle(0.2)
	elif not GameState.has_player_name_set():
		GameState.set_player_display_name(name)


func _complete_today_beat() -> void:
	var bid := StoryBeatDirector.get_today_beat_id()
	if bid != "" and not GameState.is_story_node_seen(bid):
		StoryBeatDirector.complete_beat(bid)


func _sleep_night() -> void:
	TaskSystem.cancel_task()
	if CompanionAgent.is_proactive_active():
		CompanionAgent.end_proactive_approach()
	await _settle(0.2)
	GameState.time_of_day = GameState.TIME_NIGHT
	GameState._awaiting_sleep = true
	if _ui.has_method("_on_sleep_prompt_requested"):
		_ui.call("_on_sleep_prompt_requested")
	await _settle(0.1)
	var ov: Node = _ui.get("_day_cycle_overlay")
	if ov and ov.has_method("is_prompt_visible") and ov.call("is_prompt_visible"):
		_ui.call("_on_sleep_now_pressed")
	elif _ui.has_method("sleep_from_companion"):
		_ui.call("sleep_from_companion")
	var day0 := GameState.game_day
	var n := 0
	while n < 240 and GameState.game_day <= day0:
		if ov and bool(ov.get("_trust_waiting")):
			ov.set("_trust_waiting", false)
		await get_tree().process_frame
		n += 1
	_check(GameState.game_day > day0, "SLEEP-D%d" % day0, "过天 D%d→D%d" % [day0, GameState.game_day])


func _flip_named(node_name: String) -> void:
	var panel: Node = _ui.get_node_or_null(node_name)
	if panel == null or not panel.visible:
		return
	var guard := 0
	while panel.visible and guard < 80:
		guard += 1
		if panel.has_method("_on_continue_pressed"):
			panel.call("_on_continue_pressed")
		elif panel.has_method("advance"):
			panel.call("advance")
		await _settle(0.08)


func _wait_idle(max_sec: float) -> void:
	var waited := 0.0
	while waited < max_sec:
		if _ui == null or not bool(_ui.get("_npc_busy")):
			if not NpcBridge.is_request_in_flight():
				return
		await get_tree().create_timer(0.2).timeout
		waited += 0.2


func _wait_morning_settled() -> void:
	await _settle(1.2)
	var waited := 0.0
	while waited < 18.0:
		var busy := (_ui != null and bool(_ui.get("_npc_busy"))) or NpcBridge.is_request_in_flight()
		if busy:
			await get_tree().create_timer(0.25).timeout
			waited += 0.25
			continue
		var quiet := 0.0
		while quiet < 1.2:
			if (_ui != null and bool(_ui.get("_npc_busy"))) or NpcBridge.is_request_in_flight():
				break
			await get_tree().create_timer(0.2).timeout
			quiet += 0.2
		if quiet >= 1.2:
			break
		waited += quiet
	_last_reply = {}


func _story_blocking() -> bool:
	if _ui == null:
		return true
	var story: Node = _ui.get_node_or_null("StoryBeatPanel")
	var namep: Node = _ui.get_node_or_null("NamePromptPanel")
	var aw: Node = _ui.get_node_or_null("AwakeningPanel")
	var en: Node = _ui.get_node_or_null("EndingPanel")
	return (
		(story != null and story.visible)
		or (namep != null and namep.visible)
		or (aw != null and aw.visible)
		or (en != null and en.visible)
	)


func _companion_tail() -> String:
	var turns := GameState.snapshot_today_chat_log()
	for i in range(turns.size() - 1, -1, -1):
		var turn: Variant = turns[i]
		if not turn is Dictionary:
			continue
		if str(turn.get("role", "")) in ["companion", "assistant", "xiaoli"]:
			return str(turn.get("text", "")).strip_edges()
	return ""


func _on_bridge_reply(request_id: int, event: String, text: String, used_fallback: bool) -> void:
	if event not in ["player_chat", "session_start", "companion_casual", "companion_proactive"]:
		return
	var meta := NpcBridge.take_response_meta(request_id)
	var reason := str(meta.get("fallback_reason", "")).strip_edges()
	if reason == "":
		reason = str(NpcBridge.last_validation_reason).strip_edges()
	_last_reply = {
		"event": event,
		"text": text.strip_edges(),
		"fallback": used_fallback,
		"source": str(meta.get("source", "")),
		"error": "",
		"reason": reason,
	}


func _on_bridge_fail(_request_id: int, event: String, error: String) -> void:
	if event not in ["player_chat", "session_start"]:
		return
	_last_reply["error"] = error
	if "校验层拦截" in error:
		NpcBridge.last_validation_reason = error.get_slice(": ", 1)
		_last_reply["reason"] = NpcBridge.last_validation_reason


func _prepare_command(expect: String) -> void:
	TaskSystem.cancel_task()
	if CompanionAgent.is_proactive_active():
		CompanionAgent.end_proactive_approach()
	_close_memory()
	match expect:
		"plant":
			_prep_empty_plots()
		"water", "no_water":
			_prep_dry_crops()
		"harvest", "no_harvest":
			_prep_mature_crops()
		"shop", "no_shop":
			if GameState.coins < 40:
				GameState.coins = 80
			if expect == "shop":
				_nudge_companion_away()
		"follow", "walk_porch", "walk_field", "walk_hollow":
			_nudge_companion_away()


func _cleanup_command(expect: String) -> void:
	if expect == "notebook":
		_close_memory()
	TaskSystem.cancel_task()
	if CompanionAgent.is_proactive_active() and expect == "follow":
		CompanionAgent.end_proactive_approach()


func _close_memory() -> void:
	if _ui == null:
		return
	var panel: Node = _ui.get_node_or_null("MemoryPanel")
	if panel != null and panel.visible and panel.has_method("close"):
		panel.call("close")


func _find_companion() -> Node2D:
	if _main == null:
		return null
	return _main.find_child("Companion", true, false) as Node2D


func _nudge_companion_away() -> void:
	var fox := _find_companion()
	if fox == null:
		return
	fox.global_position += Vector2(220, 140)


func _prep_empty_plots() -> void:
	if GameState.get_all_plot_ids().is_empty():
		GameState.register_farm_plots(3)
	if GameState.get_item_count("turnip_seed") < 3:
		GameState.add_item("turnip_seed", 3)
	for plot_id in GameState.get_all_plot_ids():
		var plot := GameState.ensure_plot(plot_id)
		plot["stage"] = 0
		plot["crop"] = ""
		plot["watered"] = false
	GameState.watered_plots.clear()


func _prep_dry_crops() -> void:
	GameState.weather_today = GameState.WEATHER_SUN
	if GameState.get_all_plot_ids().is_empty():
		GameState.register_farm_plots(3)
	if GameState.get_item_count("turnip_seed") < 3:
		GameState.add_item("turnip_seed", 3)
	for plot_id in GameState.get_all_plot_ids():
		var plot := GameState.ensure_plot(plot_id)
		var stage := int(plot.get("stage", 0))
		if stage <= 0 or stage >= GameState.MATURE_STAGE:
			plot["crop"] = GameState.CROP_TURNIP
			plot["stage"] = 1
		plot["watered"] = false
		if plot_id in GameState.watered_plots:
			GameState.watered_plots.erase(plot_id)


func _prep_mature_crops() -> void:
	if GameState.get_all_plot_ids().is_empty():
		GameState.register_farm_plots(3)
	for plot_id in GameState.get_all_plot_ids():
		var plot := GameState.ensure_plot(plot_id)
		plot["crop"] = GameState.CROP_TURNIP
		plot["stage"] = GameState.MATURE_STAGE
		plot["watered"] = true


func _command_snapshot(expect: String) -> Dictionary:
	var snap := CompanionAgent.get_snapshot()
	return {
		"expect": expect,
		"empty": GameState.get_empty_plot_ids().size(),
		"unwatered": GameState.get_unwatered_growing_plot_ids().size(),
		"harvestable": int(GameState.get_plot_summary().get("harvestable", 0)),
		"task": int(TaskSystem.current_task),
		"loc_id": str(snap.get("location_id", "")),
		"activity": str(snap.get("activity", "")),
	}


func _wait_expect(expect: String, before: Dictionary) -> bool:
	if expect.begins_with("no_"):
		await get_tree().create_timer(2.6).timeout
		var held := not _positive_expect_met(expect.trim_prefix("no_"), before)
		_print_do(expect, held)
		return held
	var waited := 0.0
	var limit := 8.0
	if expect.begins_with("walk_") or expect == "shop" or expect == "follow":
		limit = 16.0
	while waited < limit:
		if _expect_met(expect, before):
			_print_do(expect, true)
			return true
		await get_tree().create_timer(0.2).timeout
		waited += 0.2
	_print_do(expect, false)
	return false


func _print_do(expect: String, ok: bool) -> void:
	var snap := CompanionAgent.get_snapshot()
	var tag := "do" if ok else "do-miss"
	print("       %s %s task=%s act=%s loc=%s empty=%d dry=%d" % [
		tag,
		expect,
		str(TaskSystem.current_task),
		str(snap.get("activity", "")),
		str(snap.get("location_name", "")),
		GameState.get_empty_plot_ids().size(),
		GameState.get_unwatered_growing_plot_ids().size(),
	])


func _expect_met(expect: String, before: Dictionary) -> bool:
	if expect.begins_with("no_"):
		return false
	return _positive_expect_met(expect, before)


func _walk_arrived_or_going(
	poi_id: String, token: String, loc_id: String, activity: String, loc_name: String, before: Dictionary
) -> bool:
	if "走向" in activity and token in activity:
		return true
	var before_id := str(before.get("loc_id", ""))
	if loc_id == poi_id and before_id != "" and before_id != poi_id:
		return true
	if token in activity and loc_id == poi_id:
		return true
	if token in loc_name and "走向" in activity:
		return true
	return false


func _positive_expect_met(expect: String, before: Dictionary) -> bool:
	var snap := CompanionAgent.get_snapshot()
	var activity := str(snap.get("activity", ""))
	var loc_id := str(snap.get("location_id", ""))
	var loc_name := str(snap.get("location_name", ""))
	match expect:
		"follow":
			return CompanionAgent.is_proactive_active() or "找你" in activity or "过来" in activity
		"walk_porch":
			return _walk_arrived_or_going("porch", "廊下", loc_id, activity, loc_name, before)
		"walk_field":
			return _walk_arrived_or_going("field", "田", loc_id, activity, loc_name, before)
		"walk_hollow":
			return _walk_arrived_or_going("hollow", "树洞", loc_id, activity, loc_name, before)
		"notebook":
			var panel: Node = _ui.get_node_or_null("MemoryPanel") if _ui else null
			return panel != null and panel.visible
		"plant":
			if TaskSystem.current_task == TaskSystem.TaskType.PLANT:
				return true
			if before.has("empty") and GameState.get_empty_plot_ids().size() < int(before.get("empty", 99)):
				return true
			return "种" in activity
		"water":
			if TaskSystem.current_task == TaskSystem.TaskType.WATER:
				return true
			if before.has("unwatered") and GameState.get_unwatered_growing_plot_ids().size() < int(before.get("unwatered", 99)):
				return true
			return "浇" in activity
		"harvest":
			if TaskSystem.current_task == TaskSystem.TaskType.HARVEST:
				return true
			if before.has("harvestable") and int(GameState.get_plot_summary().get("harvestable", 0)) < int(before.get("harvestable", 99)):
				return true
			return "收" in activity
		"shop":
			return TaskSystem.current_task == TaskSystem.TaskType.SHOP or "商店" in activity
		_:
			return false


func _is_empty_talk(text: String) -> bool:
	var cleaned := text.strip_edges()
	if cleaned == "":
		return true
	for line in EMPTY_TALK:
		if cleaned == line or cleaned.begins_with(line):
			return true
	return false


func _ask_is_farm(ask: String) -> bool:
	for cue in ["浇过", "浇水", "哪头认", "这垄", "这片田", "田还", "认土"]:
		if cue in ask:
			return true
	return false


func _is_unsolicited_farm_pitch(ask: String, reply: String) -> bool:
	if _ask_is_farm(ask):
		return false
	for cue in FARM_PITCH:
		if cue in reply:
			return true
	return false


func _claims_forgot_name(text: String) -> bool:
	for phrase in ["叫什么来着", "忘了你叫", "想不起你叫", "记不清你叫", "忘了你的名字"]:
		if phrase in text:
			return true
	return false


func _has_stranger_ooc(text: String) -> bool:
	for phrase in ["又见面了", "欢迎回来", "还记得我们", "想你了"]:
		if phrase in text:
			return true
	return false


func _claims_sunny(text: String) -> bool:
	for phrase in ["天晴", "晴天", "出太阳", "晒太阳", "今天不下雨", "没下雨"]:
		if phrase in text:
			return true
	return false


func _claims_raining_now(text: String) -> bool:
	for phrase in ["正在下雨", "还在下雨", "雨下得", "等雨停", "淋雨"]:
		if phrase in text:
			return true
	return false


func _settle(sec: float = 0.1) -> void:
	if not is_inside_tree():
		return
	var tree := get_tree()
	if tree == null:
		return
	await tree.create_timer(sec).timeout


func _check(ok: bool, id: String, detail: String) -> void:
	if ok:
		_pass_n += 1
		print("  PASS %s %s" % [id, detail])
	else:
		_fail.append("%s %s" % [id, detail])
		print("  FAIL %s %s" % [id, detail])


func _print_report() -> void:
	print("=== TURNS %d ===" % _turns.size())
	for turn in _turns:
		var reason := str(turn.get("reason", ""))
		var tag := (" fb:%s" % reason) if bool(turn.get("fallback", false)) and reason != "" else ""
		print("  D%d %s → %s%s" % [
			int(turn.get("day", 0)),
			str(turn.get("ask", "")),
			str(turn.get("reply", "")).substr(0, 60).replace("\n", " "),
			tag,
		])
	print("=== DIALOGUE QA %d PASS / %d FAIL ===" % [_pass_n, _fail.size()])
	for line in _fail:
		print(" - %s" % line)
	if _fail.is_empty():
		print("=== DIALOGUE QA ALL PASS ===")
	else:
		print("=== DIALOGUE QA NOT READY ===")


func _quit_runner(code: int) -> void:
	if not is_inside_tree():
		return
	var tree := get_tree()
	if tree == null:
		return
	tree.quit(code)
