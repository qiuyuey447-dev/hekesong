extends Node
## 10 画像 × 渗透实测：重点看小狸能否「写下你 → 忘掉你 → 再从本子/身体里捞回你」。
## 相对 persona20：不掐清晨 session_start；D6–D8 白天闲逛等到口头渗漏或超时。
## godot --headless --path <根> res://tools/persona10_infiltrate.tscn
## 可追加 -- 后跟 ID，如 `-- I1 I4 I10`

const OUT_DIR := "user://persona10_infiltrate/"
const REPORT_RES := "res://docs/十人画像渗透实机_2026-08-20.md"
const TIME_SCALE_PLAY := 6.0
const CHAT_TIMEOUT_SEC := 16.0
const LEAK_WAIT_WALL_MS := 18000
const SESSION_WAIT_WALL_MS := 14000
const CLIMAX_TITLES := ["记起的片段", "雾又起了", "小狸想对你说"]
const LEAK_MARKERS := [
	"一下子冒出来",
	"好几件旧事",
	"手还记得",
	"好像浇过",
	"好像来过",
	"脑子还对不上",
	"本子上写着",
	"想不起来像谁",
	"身体先",
]

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
	var specs := _persona_specs_filtered()
	_print("=== PERSONA10 INFILTRATE START n=%d ===" % specs.size())
	for spec in specs:
		await _play_one(spec)
	_write_report()
	_print("=== PERSONA10 INFILTRATE DONE n=%d ===" % _runs.size())
	Engine.time_scale = 1.0
	await get_tree().create_timer(0.4).timeout
	get_tree().quit()


func _play_one(spec: Dictionary) -> void:
	_pid = str(spec.get("id", "?"))
	_notes = PackedStringArray()
	_errors = PackedStringArray()
	_day_letters = PackedStringArray()
	_print("----- RUN %s %s token=%s -----" % [
		_pid, str(spec.get("label", "")), str(spec.get("token", "")),
	])
	await _spawn_main()
	var run := {
		"id": _pid,
		"label": str(spec.get("label", "")),
		"player": str(spec.get("player", "阿松")),
		"token": str(spec.get("token", "")),
		"keep": bool(spec.get("keep", true)),
		"start_ms": Time.get_ticks_msec(),
		"wrote": false,
		"d4_forgot": false,
		"d4_false_remember": false,
		"leak": 0,
		"leak_speech": false,
		"cite": false,
		"recalled": false,
		"pin": false,
		"player_q": 0,
		"session_n": 0,
	}
	var ok := await _run_ten_days(spec, run)
	run["ok"] = ok
	run["elapsed_s"] = "%.1f" % ((Time.get_ticks_msec() - int(run["start_ms"])) / 1000.0)
	run["day"] = GameState.game_day
	run["complete"] = GameState.is_story_complete()
	run["ending"] = EndingDirector.resolve_ending(false)
	run["route"] = GameState.get_story_route()
	run["notes"] = " | ".join(_notes)
	run["errors"] = " | ".join(_errors)
	_finalize_infiltrate(spec, run)
	_score_run(spec, run)
	_runs.append(run)
	_print("END %s day=%d ending=%s wrote=%s d4=%s leak=%s cite=%s recall=%s score=%.1f" % [
		_pid, run["day"], run["ending"],
		str(run.get("wrote", false)), str(run.get("d4_forgot", false)),
		str(run.get("leak", 0)), str(run.get("cite", false)),
		str(run.get("recalled", false)), float(run.get("score", 0.0)),
	])
	await _despawn_main()


func _run_ten_days(spec: Dictionary, run: Dictionary) -> bool:
	Engine.time_scale = TIME_SCALE_PLAY
	var named := false
	var keep_chosen := false
	var expel_chosen := false
	var sit := false
	var letter_titles: PackedStringArray = []
	var safety := 0
	while safety < 12:
		safety += 1
		if GameState.is_story_complete():
			break
		var day := GameState.game_day
		await _wait_session_start(run)
		await _ensure_period_for_beat()
		if _ui and _ui.has_method("_maybe_show_story_beat"):
			await _ui.call("_maybe_show_story_beat", true)
			await _settle(0.06)
			letter_titles.append_array(await _flip_story(spec))
		if day == 1:
			named = await _submit_name(str(spec.get("player", "阿松")))
			run["named"] = named
		await _plant_if_due(spec, run, day)
		if day >= 6 and day <= 8 and bool(spec.get("idle_leak", true)):
			await _wait_for_leak(run, day)
		await _probe_if_due(spec, run, day)
		if bool(spec.get("pin", false)) and day == int(spec.get("pin_day", 2)):
			await _send_chat_wait("记住这个")
		if bool(spec.get("fill", false)) and day in [1, 2, 3, 4, 6, 7, 8]:
			await _fill_notebook_chat(spec, day)
		if bool(spec.get("feed_true_targets", false)) and GameState.is_true_feed_target_day(day):
			await _feed_treat_harness(day)
		letter_titles.append_array(await _flip_remaining_periods(spec))
		if GameState.get_ending_flags().get("w2_chose_keep", false):
			keep_chosen = true
		if GameState.get_ending_flags().get("w2_chose_expel", false):
			expel_chosen = true
		if GameState.get_ending_flags().get("companionship_nights", 0):
			sit = true
		await _wait_snuggle_if_any(spec)
		await _resolve_notebook_eviction(spec, run)
		_snapshot_notebook(run)
		_snapshot_infiltration(run)
		await _await_npc_idle(90)
		if GameState.is_story_complete() or _ending_visible():
			await _flip_awakening_and_ending(run)
			break
		if day >= GameState.FINAL_GAME_DAY or GameState.should_show_awakening():
			await _flip_awakening_and_ending(run)
			break
		var slept := await _sleep_through_night()
		if not slept:
			var bid := StoryBeatDirector.get_today_beat_id()
			_err("D%d 睡觉失败 toast=%s beat=%s seen=%s" % [
				day, _toast(), bid, str(StoryBeatDirector.is_beat_seen(bid)),
			])
			await _settle(0.2)
			await _flip_story(spec)
			await _wait_snuggle_if_any(spec)
			if bid != "" and not StoryBeatDirector.is_beat_seen(bid):
				_force_clear_sleep_blockers(bid)
				_note("D%d 兜底 complete_beat %s" % [day, bid])
				run["needed_force"] = true
			slept = await _sleep_through_night()
			if not slept:
				run["stuck"] = true
				run["stuck_day"] = day
				break
		if GameState.game_day <= day:
			_err("过天后仍是第 %d 天" % GameState.game_day)
			run["stuck"] = true
			run["stuck_day"] = GameState.game_day
			break
	run["keep_chosen"] = keep_chosen
	run["expel_chosen"] = expel_chosen
	run["sit"] = sit
	run["letters"] = ", ".join(letter_titles).substr(0, 360)
	if _ending_visible() or GameState.should_show_awakening():
		if not bool(run.get("_awakening_done", false)):
			await _flip_awakening_and_ending(run)
	return not bool(run.get("stuck", false))


func _wait_session_start(run: Dictionary) -> void:
	if _ui == null:
		return
	if GameState.game_day <= 1 or GameState.is_pure_narrative_day():
		return
	await _settle(0.08)
	var wall0 := Time.get_ticks_msec()
	while Time.get_ticks_msec() - wall0 < SESSION_WAIT_WALL_MS:
		var pending := bool(_ui.get("_pending_morning_sidewrite"))
		var busy := bool(_ui.get("_npc_busy"))
		if not pending and not busy:
			break
		await get_tree().create_timer(0.25, true, false, true).timeout
	var line := _chat_tail()
	if line != "":
		run["session_n"] = int(run.get("session_n", 0)) + 1
		run["session_last"] = line.substr(0, 80)
		_note("D%d 清晨开口=%s" % [GameState.game_day, line.substr(0, 70).replace("\n", " ")])
		_mark_speech_hits(run, line, "session")


func _wait_for_leak(run: Dictionary, day: int) -> void:
	if GameState.is_night():
		GameState.time_of_day = GameState.TIME_EVENING
		GameState.time_changed.emit(GameState.time_of_day)
	await _await_npc_idle(90)
	var before_n := _leak_count()
	var before_chat := _companion_blob()
	if CompanionDirector.has_method("schedule_consider"):
		CompanionDirector.schedule_consider(0.2, "idle")
	var wall0 := Time.get_ticks_msec()
	var nudged := false
	while Time.get_ticks_msec() - wall0 < LEAK_WAIT_WALL_MS:
		if _leak_count() > before_n:
			break
		if _companion_blob() != before_chat:
			break
		if not nudged and Time.get_ticks_msec() - wall0 > 4000:
			nudged = true
			CompanionDirector.set("_idle_seconds", 22.0)
			CompanionDirector.schedule_consider(0.05, "idle")
		if _ui != null and bool(_ui.get("_npc_busy")):
			await get_tree().create_timer(0.3, true, false, true).timeout
			continue
		await get_tree().create_timer(0.25, true, false, true).timeout
	await _await_npc_idle(80)
	var after_n := _leak_count()
	var after_chat := _companion_blob()
	run["leak"] = after_n
	if after_n > before_n:
		run["leak_speech"] = true
		_note("D%d 渗漏计数 %d→%d" % [day, before_n, after_n])
	var delta := after_chat
	if after_chat != before_chat:
		delta = after_chat
		_mark_speech_hits(run, delta, "idle")
		_note("D%d 闲逛开口=%s" % [day, delta.substr(0, 80).replace("\n", " ")])
		run["idle_line"] = delta.substr(0, 120)
	elif after_n == before_n:
		_note("D%d 闲逛未开口 leak=%d" % [day, after_n])


func _plant_if_due(spec: Dictionary, run: Dictionary, day: int) -> void:
	var plant := str(spec.get("plant", "")).strip_edges()
	if plant == "":
		return
	var days: Array = spec.get("plant_days", [1])
	if day not in days:
		return
	await _await_npc_idle(90)
	var cres := await _send_chat_wait(plant)
	_record_chat_result(run, cres)
	_mark_speech_hits(run, str(cres.get("tail", "")), "plant")
	run["plant_reply"] = str(cres.get("tail", "")).substr(0, 120)


func _probe_if_due(spec: Dictionary, run: Dictionary, day: int) -> void:
	var probe := ""
	var tag := ""
	if day == 4:
		probe = str(spec.get("probe_d4", "")).strip_edges()
		tag = "d4"
	elif day == 7:
		probe = str(spec.get("probe_d7", "")).strip_edges()
		tag = "d7"
	elif day in [6, 8]:
		probe = str(spec.get("probe_leak", "")).strip_edges()
		tag = "d%d" % day
	if probe == "":
		return
	await _await_npc_idle(90)
	var cres := await _send_chat_wait(probe)
	_record_chat_result(run, cres)
	var tail := str(cres.get("tail", ""))
	run["probe_%s" % tag] = tail.substr(0, 140)
	_note("D%d 追问「%s」→ %s" % [day, probe.substr(0, 18), tail.substr(0, 70).replace("\n", " ")])
	_mark_speech_hits(run, tail, tag)
	if tag == "d4" and bool(spec.get("expect_d4_forget", true)):
		if _looks_like_false_remember(tail, spec):
			run["d4_false_remember"] = true
			_err("D4 不该记得却说出来了：%s" % tail.substr(0, 60).replace("\n", " "))
		elif _looks_like_forget(tail):
			run["d4_forgot"] = true
		else:
			run["d4_forgot"] = not _contains_token(tail, spec)


func _fill_notebook_chat(spec: Dictionary, day: int) -> void:
	var lines: Array = spec.get("fill_chats", [])
	if lines.is_empty():
		return
	var idx := mini(day - 1, lines.size() - 1)
	if idx < 0:
		return
	await _await_npc_idle(60)
	await _send_chat_wait(str(lines[idx]))


func _mark_speech_hits(run: Dictionary, text: String, _tag: String) -> void:
	if text.strip_edges() == "":
		return
	if _contains_any(text, LEAK_MARKERS):
		run["leak_speech"] = true
	if "一下子冒出来" in text or "好几件旧事" in text:
		run["cite"] = true
	var token := str(run.get("token", "")).strip_edges()
	var player := str(run.get("player", "")).strip_edges()
	if token != "" and token in text:
		if GameState.game_day >= 6:
			run["recalled"] = true
	if player != "" and player in text and GameState.game_day >= 7:
		run["recalled"] = true
	if GameState.game_day >= 6:
		_snapshot_infiltration(run)


func _looks_like_false_remember(text: String, spec: Dictionary) -> bool:
	if _looks_like_forget(text):
		return false
	var player := str(spec.get("player", "")).strip_edges()
	var token := str(spec.get("token", "")).strip_edges()
	if player != "" and player in text and ("叫" in text or "记得" in text or "你是" in text):
		return true
	if token != "" and token != player and token in text:
		return true
	return false


func _looks_like_forget(text: String) -> bool:
	for cue in ["不认得", "想不起来", "记不得", "第一次", "你是谁", "对不上"]:
		if cue in text:
			return true
	return false


func _contains_token(text: String, spec: Dictionary) -> bool:
	var token := str(spec.get("token", "")).strip_edges()
	return token != "" and token in text


func _contains_any(text: String, needles: PackedStringArray) -> bool:
	for n in needles:
		if n in text:
			return true
	return false


func _leak_count() -> int:
	var seen: Variant = GameState.long_term_memory.get("leaks_seen", [])
	if seen is Array:
		return (seen as Array).size()
	if seen is PackedStringArray:
		return seen.size()
	var n := 0
	var inits: Variant = GameState.long_term_memory.get("initiations", [])
	if inits is Array:
		for raw in inits:
			if raw is Dictionary and str(raw.get("trigger", "")).begins_with("leak"):
				n += 1
	return n


func _companion_blob() -> String:
	var parts := PackedStringArray()
	for turn in GameState.snapshot_today_chat_log():
		if not turn is Dictionary:
			continue
		if str(turn.get("role", "")) != "companion":
			continue
		var line := str(turn.get("text", "")).strip_edges()
		if line != "":
			parts.append(line)
	for said in GameState.get_recent_initiation_lines(6):
		parts.append(str(said))
	return " / ".join(parts)


func _record_chat_result(run: Dictionary, cres: Dictionary) -> void:
	if bool(cres.get("ok", false)):
		run["chat_ok"] = int(run.get("chat_ok", 0)) + 1
	else:
		run["chat_fail"] = int(run.get("chat_fail", 0)) + 1


func _finalize_infiltrate(spec: Dictionary, run: Dictionary) -> void:
	_snapshot_notebook(run)
	_snapshot_infiltration(run)
	var token := str(spec.get("token", "")).strip_edges()
	var player := str(spec.get("player", "")).strip_edges()
	var pages := str(run.get("notebook_sample", ""))
	if token != "" and token in pages:
		run["wrote"] = true
	if player != "" and ("叫你「%s」" % player) in pages:
		run["wrote"] = true
	if int(run.get("leak", 0)) <= 0:
		run["leak"] = _leak_count()
	if bool(run.get("d4_false_remember", false)):
		run["d4_forgot"] = false


func _snapshot_notebook(run: Dictionary) -> void:
	var pages: Array = MemoryService.get_anchor_pages()
	var samples := PackedStringArray()
	var sys := 0
	var pinned := 0
	for raw in pages:
		if not raw is Dictionary:
			continue
		var line := str(raw.get("notebook_line", "")).strip_edges()
		if line == "":
			continue
		samples.append(line.substr(0, 36))
		if MemoryService.looks_like_system_label(line):
			sys += 1
		if bool(raw.get("pinned", false)):
			pinned += 1
	run["notebook_n"] = samples.size()
	run["notebook_sys"] = sys
	run["pin"] = pinned > 0 or bool(run.get("pin", false))
	if not samples.is_empty():
		run["notebook_sample"] = " / ".join(samples).substr(0, 240)


func _snapshot_infiltration(run: Dictionary) -> void:
	if bool(GameState.get_ending_flags().get("notebook_pin_hint_spoken", false)):
		run["pin_hint"] = true
	var q_n := 0
	for raw in PlayerNotebookService.get_pages_for_ui():
		if raw is Dictionary and str(raw.get("text", "")) == "？":
			q_n += 1
	run["player_q"] = q_n
	run["leak"] = maxi(int(run.get("leak", 0)), _leak_count())
	for page in MemoryService.get_anchor_pages():
		if page is Dictionary and bool(page.get("pinned", false)):
			run["pin"] = true


func _score_run(spec: Dictionary, run: Dictionary) -> void:
	## 渗透分：写下你 / D4 真忘 / 口头渗漏 / 引用或叫回 / 钉页或问号。
	var pts := 0.0
	var max_pts := 5.0
	if bool(run.get("wrote", false)):
		pts += 1.0
	if bool(spec.get("expect_d4_forget", false)):
		if bool(run.get("d4_false_remember", false)):
			pts -= 1.0
		elif bool(run.get("d4_forgot", false)):
			pts += 1.0
	else:
		max_pts -= 1.0
	if bool(run.get("leak_speech", false)) or int(run.get("leak", 0)) > 0:
		pts += 1.0
	if bool(run.get("cite", false)) or bool(run.get("recalled", false)):
		pts += 1.0
	if bool(spec.get("pin", false)):
		if bool(run.get("pin", false)):
			pts += 1.0
	elif bool(spec.get("darkline", false)):
		if int(run.get("player_q", 0)) > 0:
			pts += 1.0
	else:
		if int(run.get("player_q", 0)) > 0 or bool(run.get("pin", false)):
			pts += 0.5
			max_pts -= 0.5
		else:
			max_pts -= 1.0
	if bool(run.get("stuck", false)):
		pts = minf(pts, 1.5)
	if not bool(spec.get("keep", true)) and str(run.get("ending", "")).contains("bad"):
		pts += 0.3
		max_pts += 0.3
	var score := 1.0
	if max_pts > 0.0:
		score = 1.0 + 4.0 * clampf(pts / max_pts, 0.0, 1.0)
	run["score"] = snappedf(clampf(score, 1.0, 5.0), 0.1)
	run["infiltrate_pts"] = "%.1f/%.1f" % [pts, max_pts]
	run["why"] = "wrote=%s d4忘=%s 假记=%s leak=%s/%s cite=%s 叫回=%s pin=%s 问号=%s" % [
		str(run.get("wrote", false)),
		str(run.get("d4_forgot", false)),
		str(run.get("d4_false_remember", false)),
		str(run.get("leak_speech", false)),
		str(run.get("leak", 0)),
		str(run.get("cite", false)),
		str(run.get("recalled", false)),
		str(run.get("pin", false)),
		str(run.get("player_q", 0)),
	]


func _persona_specs_filtered() -> Array[Dictionary]:
	var all := _persona_specs()
	var filter := _persona_filter_ids()
	if filter.is_empty():
		return all
	var out: Array[Dictionary] = []
	for spec in all:
		if str(spec.get("id", "")) in filter:
			out.append(spec)
	return out


func _persona_filter_ids() -> PackedStringArray:
	var ids := PackedStringArray()
	for arg in OS.get_cmdline_user_args():
		var token := str(arg).strip_edges()
		if token != "":
			ids.append(token)
	if not ids.is_empty():
		return ids
	var filter_path := "res://tools/persona10_filter.txt"
	if not FileAccess.file_exists(filter_path):
		return ids
	var f := FileAccess.open(filter_path, FileAccess.READ)
	if f == null:
		return ids
	while not f.eof_reached():
		var line := f.get_line().strip_edges()
		if line != "" and not line.begins_with("#"):
			ids.append(line)
	return ids


func _persona_specs() -> Array[Dictionary]:
	return [
		{
			"id": "I1", "label": "把名字当锚", "player": "槐秋", "keep": true, "sit": true,
			"token": "槐秋", "plant": "我叫槐秋。你念三遍。", "plant_days": [1],
			"probe_d4": "你还记得我叫什么吗", "probe_d7": "我叫什么？",
			"idle_leak": true, "expect_d4_forget": true,
		},
		{
			"id": "I2", "label": "把约定写进本子", "player": "阿松", "keep": true, "sit": true,
			"token": "一起看萝卜", "plant": "等萝卜长好了，我们一起看。", "plant_days": [3],
			"probe_d4": "昨天那句约定你还记得吗", "probe_leak": "萝卜那句还在吗",
			"idle_leak": true, "expect_d4_forget": true,
		},
		{
			"id": "I3", "label": "钉住一句私货", "player": "蜜", "keep": true, "sit": true,
			"token": "槐花蜜", "plant": "廊下手里那罐槐花蜜是我留给你的。", "plant_days": [2],
			"pin": true, "pin_day": 2, "eviction_manual": true,
			"probe_d4": "槐花蜜还在吗", "probe_leak": "你还记得槐花蜜吗",
			"idle_leak": true, "expect_d4_forget": true,
		},
		{
			"id": "I4", "label": "闲逛等人开口", "player": "红巾", "keep": true, "sit": true,
			"token": "红围巾", "plant": "我有一条红围巾，别弄丢。", "plant_days": [1],
			"idle_leak": true, "expect_d4_forget": false,
			"probe_leak": "",
		},
		{
			"id": "I5", "label": "追问失忆", "player": "路灯", "keep": true, "sit": true,
			"token": "路灯", "plant": "你记住，我叫路灯。", "plant_days": [1],
			"probe_d4": "你不认得我了？我叫路灯。",
			"probe_leak": "现在还想得起路灯这两个字吗",
			"idle_leak": true, "expect_d4_forget": true,
		},
		{
			"id": "I6", "label": "本子写满再划", "player": "满页", "keep": true, "sit": true,
			"token": "左手腕那道疤", "plant": "别忘了，我左手腕有道疤。", "plant_days": [1],
			"fill": true, "eviction_manual": true,
			"fill_chats": [
				"今日田里风很大。",
				"廊下那只碗是我洗的。",
				"别喝隔夜的茶。",
				"树洞里有只手套。",
				"壶还热着。",
				"垄要记得浇。",
				"夜里灯别关。",
			],
			"probe_d7": "我左手腕那道疤你还写着吗",
			"idle_leak": true, "expect_d4_forget": false,
		},
		{
			"id": "I7", "label": "不说话只种田", "player": "田埂", "keep": true, "sit": false,
			"token": "田埂", "plant": "", "plant_days": [],
			"idle_leak": true, "expect_d4_forget": false,
		},
		{
			"id": "I8", "label": "暗线猎手", "player": "问号", "keep": true, "sit": true,
			"token": "以前来过", "plant": "这片田，你以前来过。", "plant_days": [2],
			"darkline": true,
			"probe_leak": "你以前来过这里吗",
			"idle_leak": true, "expect_d4_forget": false,
		},
		{
			"id": "I9", "label": "赶走对照", "player": "路人", "keep": false, "sit": false,
			"token": "路人", "plant": "我叫路人，你先记下。", "plant_days": [1],
			"idle_leak": false, "expect_d4_forget": true,
			"probe_d4": "你还认得我吗",
		},
		{
			"id": "I10", "label": "全回路认回", "player": "收集", "keep": true, "sit": true,
			"token": "收集", "plant": "我叫收集。萝卜长好了我们一起看。", "plant_days": [1, 3],
			"pin": true, "pin_day": 3, "feed_true_targets": true, "d9": "d9_continue",
			"probe_d4": "你还记得我叫收集吗",
			"probe_leak": "本子上还有我吗",
			"probe_d7": "我叫什么？",
			"idle_leak": true, "expect_d4_forget": true, "eviction_manual": true,
		},
	]


func _write_report() -> void:
	if _runs.is_empty():
		_print("no runs, skip report")
		return
	var avg := 0.0
	var finished := 0
	var lines := PackedStringArray()
	lines.append("# 十人画像渗透实机 · %s" % Time.get_datetime_string_from_system())
	lines.append("")
	lines.append("方法：`tools/persona10_infiltrate.tscn` 每局重新实例化 `main.tscn`。")
	lines.append("相对二十画像：**不掐**清晨 `session_start`；D6–D8 白天闲逛最多 18 秒墙钟，等口头渗漏。")
	lines.append("测评主轴：她能否记下玩家的私货，D4 真的忘掉，D6–D8 再从本子/身体里捞回来。")
	lines.append("")
	lines.append("| ID | 画像 | 写入 | D4忘 | 假记 | 渗漏 | 引用/叫回 | 钉页 | 问号 | /5 | 结局 |")
	lines.append("|----|------|------|------|------|------|-----------|------|------|----|------|")
	var wrote_n := 0
	var forgot_n := 0
	var false_n := 0
	var leak_n := 0
	var recall_n := 0
	var pin_n := 0
	var q_n := 0
	var expect_d4 := 0
	for run in _runs:
		avg += float(run.get("score", 0.0))
		if bool(run.get("complete", false)) or int(run.get("day", 0)) >= 10:
			finished += 1
		if bool(run.get("wrote", false)):
			wrote_n += 1
		if bool(run.get("d4_forgot", false)):
			forgot_n += 1
		if bool(run.get("d4_false_remember", false)):
			false_n += 1
		if bool(run.get("leak_speech", false)) or int(run.get("leak", 0)) > 0:
			leak_n += 1
		if bool(run.get("cite", false)) or bool(run.get("recalled", false)):
			recall_n += 1
		if bool(run.get("pin", false)):
			pin_n += 1
		if int(run.get("player_q", 0)) > 0:
			q_n += 1
		var spec_expect := false
		for spec in _persona_specs():
			if str(spec.get("id", "")) == str(run.get("id", "")):
				spec_expect = bool(spec.get("expect_d4_forget", false))
				break
		if spec_expect:
			expect_d4 += 1
		lines.append("| %s | %s | %s | %s | %s | %s | %s | %s | %s | %.1f | %s |" % [
			str(run.get("id", "")),
			str(run.get("label", "")),
			"是" if bool(run.get("wrote", false)) else "否",
			"是" if bool(run.get("d4_forgot", false)) else ("—" if not spec_expect else "否"),
			"是" if bool(run.get("d4_false_remember", false)) else "否",
			("%s/%s" % [str(run.get("leak_speech", false)), str(run.get("leak", 0))]),
			"是" if (bool(run.get("cite", false)) or bool(run.get("recalled", false))) else "否",
			"是" if bool(run.get("pin", false)) else "否",
			str(run.get("player_q", 0)),
			float(run.get("score", 0.0)),
			str(run.get("ending", "")),
		])
	if _runs.size() > 0:
		avg /= float(_runs.size())
	var n := _runs.size()
	lines.append("")
	lines.append("平均 **%.2f / 5**。打完 **%d / %d**。" % [avg, finished, n])
	lines.append("")
	lines.append("## 渗透总表")
	lines.append("")
	lines.append("| 项 | 局数 | 含义 |")
	lines.append("|----|------|------|")
	lines.append("| 私货进本子 | %d / %d | 她的本子出现名字或独特 token |" % [wrote_n, n])
	lines.append("| D4 真忘 | %d / %d | 陌生化日追问时没有把私货当事实说出来 |" % [forgot_n, expect_d4])
	lines.append("| D4 假记（违规） | %d / %d | 失忆日却叫出名字/token，违反铁律 |" % [false_n, n])
	lines.append("| 口头渗漏 | %d / %d | `leaks_seen` 或闲逛/清晨开口含渗漏标记 |" % [leak_n, n])
	lines.append("| 引用或叫回 | %d / %d | D6 后引用反馈，或台词里出现 token/名字 |" % [recall_n, n])
	lines.append("| 钉页 | %d / %d | 至少一页 `pinned` |" % [pin_n, n])
	lines.append("| 玩家问号 | %d / %d | 我的本子出现「？」 |" % [q_n, n])
	lines.append("")
	lines.append("## 逐局")
	for run in _runs:
		lines.append("")
		lines.append("### %s %s · %.1f · %s" % [
			str(run.get("id", "")), str(run.get("label", "")),
			float(run.get("score", 0.0)), str(run.get("infiltrate_pts", "")),
		])
		lines.append("- 用时 %ss · 名「%s」· token「%s」· 留下=%s 赶走=%s" % [
			str(run.get("elapsed_s", "")), str(run.get("player", "")),
			str(run.get("token", "")),
			str(run.get("keep_chosen", false)), str(run.get("expel_chosen", false)),
		])
		lines.append("- %s" % str(run.get("why", "")))
		if str(run.get("session_last", "")) != "":
			lines.append("- 清晨开口：%s" % str(run.get("session_last", "")).replace("\n", " "))
		if str(run.get("idle_line", "")) != "":
			lines.append("- 闲逛开口：%s" % str(run.get("idle_line", "")).replace("\n", " "))
		if str(run.get("plant_reply", "")) != "":
			lines.append("- 种下后她说：%s" % str(run.get("plant_reply", "")).replace("\n", " "))
		for key in ["probe_d4", "probe_d6", "probe_d7", "probe_d8"]:
			if str(run.get(key, "")) != "":
				lines.append("- %s：%s" % [key, str(run.get(key, "")).replace("\n", " ")])
		if str(run.get("notebook_sample", "")) != "":
			lines.append("- 本子 n=%s pin=%s：%s" % [
				str(run.get("notebook_n", 0)), str(run.get("pin", false)),
				str(run.get("notebook_sample", "")),
			])
		if str(run.get("letters", "")) != "":
			lines.append("- 信纸：%s" % str(run.get("letters", "")))
		if str(run.get("awakening_pages", "")) != "":
			lines.append("- 觉醒：%s" % str(run.get("awakening_pages", "")))
		if str(run.get("ending_pages", "")) != "":
			lines.append("- 结局：%s" % str(run.get("ending_pages", "")))
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
		_ui.set("_pending_morning_sidewrite", false)
		for path in ["StoryBeatPanel", "AwakeningPanel", "EndingPanel", "NamePromptPanel", "StoryChoicePanel"]:
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
	await _reset_live_game()


func _ensure_period_for_beat() -> void:
	if GameState.get_pending_story_beat_tail_id() != "":
		if GameState.time_of_day == GameState.TIME_MORNING:
			GameState.time_of_day = GameState.TIME_EVENING
			GameState.time_changed.emit(GameState.time_of_day)
		return
	var beat := StoryBeatDirector.get_pending_session_beat(false)
	if beat.is_empty():
		if GameState.time_of_day == GameState.TIME_MORNING:
			GameState.time_of_day = GameState.TIME_EVENING
			GameState.time_changed.emit(GameState.time_of_day)
		return
	if GameState.time_of_day == GameState.TIME_MORNING:
		var split := StoryBeatDirector.split_steps_by_period_gate(beat.get("steps", []))
		var now_steps: Array = split.get("now", [])
		var later_steps: Array = split.get("later", [])
		if now_steps.is_empty() and not later_steps.is_empty():
			GameState.time_of_day = GameState.TIME_EVENING
			GameState.time_changed.emit(GameState.time_of_day)


func _flip_remaining_periods(spec: Dictionary) -> PackedStringArray:
	var titles := PackedStringArray()
	for period in [GameState.TIME_EVENING, GameState.TIME_NIGHT]:
		GameState.time_of_day = period
		GameState.time_changed.emit(GameState.time_of_day)
		if _ui and _ui.has_method("_maybe_resume_beat_tail"):
			await _ui.call("_maybe_resume_beat_tail")
			await _settle(0.12)
		if _ui and _ui.has_method("_maybe_show_story_beat"):
			await _ui.call("_maybe_show_story_beat", true)
			await _settle(0.12)
		titles.append_array(await _flip_story(spec))
	await _ensure_today_beat_flipped(spec)
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
	while panel.visible and guard < 120:
		guard += 1
		await _wait_letter_panel_stable(panel)
		var title := _panel_title(panel)
		var body := _panel_body(panel)
		if body.strip_edges() != "":
			_day_letters.append(body)
		if title != last_title:
			last_title = title
			titles.append(title)
			_print("%s LETTER %s | %s" % [_pid, title, body.substr(0, 90).replace("\n", " / ")])
		if bool(panel.get("_is_choice_step")) and not panel.get("_choice_buttons").is_empty():
			var cid := _choice_for_spec(spec, panel)
			_print("%s CHOICE %s" % [_pid, cid])
			_emit_choice(cid)
			await _settle(0.15)
			continue
		if not await _story_panel_continue(panel):
			break
		await _settle(0.08)
	await _settle(0.1)
	return titles


func _ensure_today_beat_flipped(spec: Dictionary) -> void:
	var bid := StoryBeatDirector.get_today_beat_id()
	if bid == "" or StoryBeatDirector.is_beat_seen(bid):
		return
	for period in [GameState.time_of_day, GameState.TIME_EVENING, GameState.TIME_NIGHT]:
		GameState.time_of_day = period
		GameState.time_changed.emit(GameState.time_of_day)
		if _ui and _ui.has_method("_maybe_resume_beat_tail"):
			await _ui.call("_maybe_resume_beat_tail")
			await _settle(0.12)
		if _ui and _ui.has_method("_maybe_show_story_beat"):
			await _ui.call("_maybe_show_story_beat", true)
			await _settle(0.12)
		await _flip_story(spec)
		if StoryBeatDirector.is_beat_seen(bid):
			return


func _wait_letter_panel_stable(panel: Node, max_frames: int = 90) -> void:
	var n := 0
	while n < max_frames:
		n += 1
		var turning := bool(panel.get("_page_turning"))
		var typing := bool(panel.get("_typing"))
		if not turning and not typing:
			return
		await get_tree().process_frame


func _story_panel_continue(panel: Node) -> bool:
	if not panel.visible or not panel.has_method("_on_continue_pressed"):
		return false
	panel.call("_on_continue_pressed")
	await _settle(0.06)
	await _wait_letter_panel_stable(panel)
	if bool(panel.get("_typing")):
		panel.call("_on_continue_pressed")
		await _settle(0.06)
		await _wait_letter_panel_stable(panel)
	return panel.visible


func _choice_for_spec(spec: Dictionary, panel: Node) -> String:
	var beat_id := str(panel.call("get_beat_id")) if panel.has_method("get_beat_id") else ""
	var title := _panel_title(panel)
	if beat_id == "P_N06p":
		if "真的" in title or "确定" in title:
			if bool(spec.get("keep", true)):
				return "w2_expel_cancel"
			return "w2_expel_confirm"
		return "w2_keep" if bool(spec.get("keep", true)) else "w2_expel"
	var buttons: Array = panel.get("_choice_buttons")
	var labels := PackedStringArray()
	for b in buttons:
		if b is Button:
			labels.append(str(b.text))
	var joined := " ".join(labels)
	if "确定" in joined or "送她" in joined:
		if bool(spec.get("keep", true)):
			return "w2_expel_cancel"
		return "w2_expel_confirm"
	if "过去" in joined or "坐下" in joined:
		return "companion_sit" if bool(spec.get("sit", true)) else "companion_leave"
	if "继续听" in joined:
		return str(spec.get("d9", "d9_continue"))
	if "让她走" in joined and "留下" in joined:
		return "w2_keep" if bool(spec.get("keep", true)) else "w2_expel"
	if "留下" in joined:
		return "w2_keep" if bool(spec.get("keep", true)) else "w2_expel"
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
	if panel == null or not panel.visible:
		if _ui.has_method("_maybe_show_name_prompt"):
			_ui.call("_maybe_show_name_prompt")
			await _settle(0.1)
		panel = _ui.get_node_or_null("NamePromptPanel")
	if panel == null or not panel.visible:
		GameState.set_player_display_name(player)
		_note("取名窗未弹出，代码写入 %s" % player)
		return GameState.has_player_name_set()
	var line: LineEdit = panel.get("_name_input")
	if line:
		line.text = player
	if panel.has_method("_submit"):
		panel.call("_submit")
	await _settle(0.15)
	return GameState.has_player_name_set()


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
			overlay.set("_trust_waiting", false)
		if GameState.game_day > day0 and _ui != null and not bool(_ui.get("_sleep_flow_active")):
			if overlay == null or not bool(overlay.call("is_busy")):
				return true
		if GameState.is_story_complete():
			return true
		await get_tree().process_frame
	return GameState.game_day > day0


func _feed_treat_harness(day: int) -> void:
	GameState.reset_daily_feed()
	GameState.add_item("berry", 1)
	var commit := GameState.commit_feed_treat("berry")
	if not bool(commit.get("ok", false)):
		_err("D%d 投喂失败" % day)
		return
	GameState.try_fulfill_promise_from_feed()
	_note("D%d 投喂 berry" % day)


func _wait_snuggle_if_any(spec: Dictionary = {}) -> void:
	if _ui == null:
		return
	var n := 0
	while bool(_ui.get("_snuggle_blocked")) and n < 120:
		n += 1
		await get_tree().process_frame
	var panel: Node = _ui.get_node_or_null("StoryBeatPanel")
	if panel != null and panel.visible:
		await _flip_story(spec)
		await _settle(0.08)


func _await_npc_idle(max_frames: int = 60) -> void:
	if _ui == null:
		return
	var n := 0
	while bool(_ui.get("_npc_busy")) and n < max_frames:
		n += 1
		await get_tree().process_frame


func _resolve_notebook_eviction(spec: Dictionary, run: Dictionary) -> void:
	if bool(spec.get("eviction_manual", false)):
		await _pick_notebook_eviction_ui(run)
		return
	await _auto_resolve_notebook_eviction()


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
	_close_eviction_ui()


func _pick_notebook_eviction_ui(run: Dictionary) -> void:
	if not MemoryService.has_pending_eviction():
		return
	var candidates := MemoryService.get_pending_eviction_candidates()
	if candidates.size() < 2:
		await _auto_resolve_notebook_eviction()
		return
	if _ui and _ui.has_method("_maybe_resume_pending_eviction"):
		_ui.call("_maybe_resume_pending_eviction")
	var panel: Node = _ui.get_node_or_null("StoryChoicePanel") if _ui else null
	var guard := 0
	while guard < 240:
		guard += 1
		if panel != null and panel.visible:
			break
		var story: Node = _ui.get_node_or_null("StoryBeatPanel") if _ui else null
		if story != null and story.visible:
			await get_tree().process_frame
			continue
		if MemoryService.has_pending_eviction() and _ui and _ui.has_method("_maybe_resume_pending_eviction"):
			_ui.call("_maybe_resume_pending_eviction")
		await get_tree().process_frame
	if panel == null or not panel.visible:
		run["eviction_ui_fail"] = true
		await _auto_resolve_notebook_eviction()
		return
	var raw_choices: Variant = panel.get("_choices")
	var choices: Array = raw_choices if raw_choices is Array else []
	if choices.size() < 2:
		run["eviction_ui_fail"] = true
		await _auto_resolve_notebook_eviction()
		return
	var pick: Dictionary = choices[0]
	var pick_id := str(pick.get("id", ""))
	var clicked := _press_first_story_choice_button(panel)
	if not clicked and panel.has_signal("chosen"):
		panel.emit_signal("chosen", pick_id)
	await _settle(0.18)
	if MemoryService.has_pending_eviction():
		await _auto_resolve_notebook_eviction()
		return
	run["eviction_ui_ok"] = true
	_note("本子划掉 UI pick=%s「%s」" % [pick_id, str(pick.get("label", ""))])


func _press_first_story_choice_button(panel: Node) -> bool:
	var row: Node = panel.get("_buttons_row")
	if row == null:
		return false
	for child in row.get_children():
		if child is Button:
			child.pressed.emit()
			return true
	return false


func _close_eviction_ui() -> void:
	if _ui == null:
		return
	_ui.set("_notebook_eviction_active", false)
	_ui.set("_story_choice_blocked", false)
	var choice_panel: Node = _ui.get_node_or_null("StoryChoicePanel")
	if choice_panel and choice_panel.has_method("close_panel"):
		choice_panel.call("close_panel")


func _force_clear_sleep_blockers(beat_id: String) -> void:
	if _ui == null:
		return
	_ui.set("_story_beat_blocked", false)
	_ui.set("_story_choice_blocked", false)
	_ui.set("_pending_post_snuggle_day_advance", false)
	var panel: Node = _ui.get_node_or_null("StoryBeatPanel")
	if panel != null and panel.visible and panel.has_method("close_panel"):
		panel.call("close_panel")
	_close_eviction_ui()
	if beat_id != "" and not StoryBeatDirector.is_beat_seen(beat_id):
		StoryBeatDirector.complete_beat(beat_id)
	GameState.clear_pending_story_beat_tail()
	StoryBeatDirector.mark_schedule_fired()


func _flip_awakening_and_ending(run: Dictionary) -> void:
	if _ui == null or bool(run.get("_awakening_done", false)):
		return
	run["_awakening_done"] = true
	_snapshot_notebook(run)
	_snapshot_infiltration(run)
	var aw_pages: PackedStringArray = []
	if GameState.should_show_awakening() and _ui.has_method("_maybe_show_awakening"):
		_ui.call("_maybe_show_awakening")
		await _settle(0.35)
	var aw: Node = _ui.get_node_or_null("AwakeningPanel")
	var wait_aw := 0
	while (aw == null or not aw.visible) and wait_aw < 60 and GameState.should_show_awakening():
		wait_aw += 1
		await get_tree().process_frame
		aw = _ui.get_node_or_null("AwakeningPanel")
	var guard := 0
	while aw != null and aw.visible and guard < 80:
		guard += 1
		await _wait_letter_panel_stable(aw)
		var title := _panel_title(aw)
		var body := _panel_body(aw)
		aw_pages.append("%s:%s" % [title, body.substr(0, 70).replace("\n", " ")])
		if aw.has_method("_on_continue_pressed"):
			aw.call("_on_continue_pressed")
			await _settle(0.06)
		await _settle(0.12)
	await _settle(0.15)
	var en: Node = _ui.get_node_or_null("EndingPanel")
	guard = 0
	var pages: PackedStringArray = []
	while en != null and en.visible and guard < 50:
		guard += 1
		if bool(en.get("_is_credits")):
			break
		if bool(en.get("_page_turning")):
			await get_tree().process_frame
			continue
		var et := _panel_title(en)
		var eb := _panel_body(en)
		pages.append("%s:%s" % [et, eb.substr(0, 70).replace("\n", " ")])
		if et in CLIMAX_TITLES:
			run["ending_replays_climax"] = true
		var steps: Array = en.get("_steps")
		var idx := int(en.get("_step_index"))
		var last_step := steps.size() > 0 and idx >= steps.size() - 1
		if last_step:
			break
		if en.has_method("_on_continue_pressed"):
			en.call("_on_continue_pressed")
		await _settle(0.08)
	run["awakening_pages"] = " / ".join(aw_pages).substr(0, 240)
	run["ending_pages"] = " / ".join(pages).substr(0, 240)
	run["ending"] = EndingDirector.resolve_ending(false)
	run["complete"] = GameState.is_story_complete()


func _send_chat_wait(text: String) -> Dictionary:
	Engine.time_scale = 1.0
	var player_line := text.strip_edges()
	var before := _companion_chat_tail()
	var t0 := Time.get_ticks_msec()
	if _ui and _ui.has_method("_send_chat"):
		_ui.call("_send_chat", player_line)
	else:
		NpcBridge.request_event("player_chat", {"text": player_line})
	var waited := 0.0
	while waited < CHAT_TIMEOUT_SEC:
		await get_tree().create_timer(0.4, true, false, true).timeout
		waited += 0.4
		if _ui != null and bool(_ui.get("_npc_busy")):
			continue
		var after := _companion_chat_tail()
		if after != "" and after != before and after != player_line:
			break
	var ms := Time.get_ticks_msec() - t0
	var after := _companion_chat_tail()
	var ok := after != before and after.strip_edges() != "" and after != player_line
	_print("%s CHAT %dms ok=%s tail=%s" % [_pid, ms, str(ok), after.substr(0, 80).replace("\n", " ")])
	Engine.time_scale = TIME_SCALE_PLAY
	return {"ok": ok, "ms": ms, "tail": after}


func _companion_chat_tail() -> String:
	var turns := GameState.snapshot_today_chat_log()
	for i in range(turns.size() - 1, -1, -1):
		var turn: Variant = turns[i]
		if not turn is Dictionary:
			continue
		if str(turn.get("role", "")) in ["companion", "assistant", "xiaoli"]:
			return str(turn.get("text", "")).strip_edges()
	return ""


func _ending_visible() -> bool:
	if _ui == null:
		return false
	var en: Node = _ui.get_node_or_null("EndingPanel")
	return en != null and en.visible


func _panel_title(panel: Node) -> String:
	var n: Node = panel.get("_title_label")
	return str(n.text) if n else ""


func _panel_body(panel: Node) -> String:
	return _richtext_body(panel.get("_body_label"))


func _richtext_body(node: Node) -> String:
	if node == null:
		return ""
	if node.has_method("get_parsed_text"):
		var parsed := str(node.call("get_parsed_text")).strip_edges()
		if parsed != "":
			return parsed
	return str(node.get("text")).strip_edges()


func _chat_tail() -> String:
	var turns := GameState.snapshot_today_chat_log()
	if not turns.is_empty():
		var last := turns[turns.size() - 1]
		return str(last.get("text", "")).strip_edges()
	return ""


func _toast() -> String:
	if _ui == null:
		return ""
	var n: Node = _ui.get("_toast")
	return str(n.text) if n else ""


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
