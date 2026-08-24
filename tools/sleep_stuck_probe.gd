extends Node
## 局内验证：第 1–10 天夜里点睡觉会不会空反应。
## godot --headless --path <根> res://tools/sleep_stuck_probe.tscn

var _packed: PackedScene
var _main: Node2D
var _ui: Node
var _fails: Array[String] = []
var _pass_n := 0


func _ready() -> void:
	GameState.persist_saves = false
	call_deferred("_run")


func _run() -> void:
	_packed = load("res://scenes/main.tscn") as PackedScene
	print("=== SLEEP STUCK PROBE ===")
	for day in range(1, 10):
		for affection in _affections_for(day):
			await _probe_keep_day(day, affection)
	await _probe_d10()
	await _probe_d7_morning_tail()
	await _probe_expel_d6()
	print("=== SLEEP STUCK DONE %d pass, %d fail ===" % [_pass_n, _fails.size()])
	for line in _fails:
		print("FAIL: %s" % line)
	get_tree().quit(_fails.size())


func _affections_for(day: int) -> Array[int]:
	if day in [8, 9]:
		return [40, 80]
	if day == 7:
		return [0, 80]
	return [40]


func _probe_keep_day(day: int, affection: int) -> void:
	var tag := "D%d/aff%d" % [day, affection]
	await _spawn_keep(day, affection, false)
	var beat_id := StoryBeatDirector.get_today_beat_id()
	await _settle(0.35)
	var day0 := GameState.game_day
	_ui.call("sleep_from_companion")
	await _settle(0.55)
	var unseen := _snap()
	var unseen_reacted: bool = unseen.panel or unseen.toast != "" or unseen.prompt or unseen.awakening
	if GameState.game_day != day0:
		_fail(tag, "unseen sleep advanced the day", unseen)
	elif unseen.sleep:
		_fail(tag, "unseen sleep started the night skip", unseen)
	elif not unseen_reacted:
		_fail(tag, "unseen sleep click did nothing", unseen)
	else:
		_ok("%s unseen → %s" % [tag, unseen.summary])
	_force_close_letter()
	if beat_id != "" and not StoryBeatDirector.is_beat_seen(beat_id):
		StoryBeatDirector.complete_beat(beat_id)
	GameState.time_of_day = GameState.TIME_NIGHT
	GameState._awaiting_sleep = true
	await _settle(0.12)
	_ui.call("sleep_from_companion")
	await _settle(0.35)
	var after := _snap()
	if after.sleep or after.prompt:
		_ok("%s after letter → %s" % [tag, after.summary])
	else:
		_fail(tag, "after letter, sleep click did nothing", after)
	await _reset()


func _probe_d10() -> void:
	await _spawn_keep(10, 40, false)
	await _settle(0.45)
	_ui.call("sleep_from_companion")
	await _settle(0.45)
	var snap := _snap()
	if snap.awakening or "终" in snap.toast or snap.panel:
		_ok("D10 sleep → %s" % snap.summary)
	else:
		_fail("D10", "sleep click did not open awakening", snap)
	await _reset()


func _probe_d7_morning_tail() -> void:
	## 早上翻过 N16、夜里还剩选项页：点睡觉必须能把剩下的页翻出来，不能空点。
	GameState.reset_for_new_game()
	GameState.persist_saves = false
	GameState.set_player_display_name("验证")
	GameState.affection = 40
	GameState.mark_w2_keep_choice()
	GameState.lock_story_route(StoryRouteData.ROUTE_HAPPY)
	GameState.game_day = 7
	GameState.time_of_day = GameState.TIME_MORNING
	StoryBeatDirector.refresh_story_route()
	StoryBeatDirector.refresh_daily_schedule()
	var morning := StoryBeatDirector.take_displayable_beat(StoryBeatDirector.build_beat("HP_N16"))
	if morning.is_empty() or not GameState.has_pending_story_beat_tail():
		_fail("D7 tail", "morning did not stash night tail", {"summary": "no-tail"})
		return
	GameState.time_of_day = GameState.TIME_NIGHT
	GameState._awaiting_sleep = true
	await _spawn_current()
	await _settle(0.35)
	_ui.call("sleep_from_companion")
	await _settle(0.55)
	var snap := _snap()
	if snap.panel or snap.toast != "":
		_ok("D7 morning-tail night sleep → %s" % snap.summary)
	else:
		_fail("D7 tail", "night sleep click did not resume leftover pages", snap)
	await _reset()


func _probe_expel_d6() -> void:
	GameState.reset_for_new_game()
	GameState.persist_saves = false
	GameState.set_player_display_name("验证")
	GameState.mark_w2_expel_choice()
	GameState.lock_story_route(StoryRouteData.ROUTE_BAD_EARLY)
	GameState.game_day = 6
	GameState.time_of_day = GameState.TIME_NIGHT
	GameState._awaiting_sleep = true
	await _spawn_current()
	await _settle(0.45)
	var auto_letter := _panel_open()
	if not auto_letter:
		_ui.call("sleep_from_companion")
		await _settle(0.45)
	var snap := _snap()
	if snap.panel or snap.ending or auto_letter:
		_ok("expel D6 → %s" % snap.summary)
	else:
		_fail("expel D6", "short ending did not open", snap)
	await _reset()


func _spawn_keep(day: int, affection: int, seen: bool) -> void:
	GameState.reset_for_new_game()
	GameState.persist_saves = false
	GameState.set_player_display_name("验证")
	GameState.affection = affection
	if day >= 5:
		GameState.mark_w2_keep_choice()
	if day >= 6:
		GameState.lock_story_route(StoryRouteData.ROUTE_HAPPY)
	GameState.game_day = day
	GameState.time_of_day = GameState.TIME_NIGHT
	GameState._awaiting_sleep = true
	StoryBeatDirector.refresh_story_route()
	StoryBeatDirector.refresh_daily_schedule()
	if seen:
		var beat_id := StoryBeatDirector.get_today_beat_id()
		if beat_id != "":
			StoryBeatDirector.complete_beat(beat_id)
	await _spawn_current()


func _spawn_current() -> void:
	_main = _packed.instantiate() as Node2D
	add_child(_main)
	await get_tree().process_frame
	await get_tree().process_frame
	_ui = _main.get_node("UI")
	Engine.time_scale = 1.0


func _reset() -> void:
	Engine.time_scale = 1.0
	if is_instance_valid(_main):
		_main.queue_free()
		_main = null
		_ui = null
	await get_tree().process_frame
	await get_tree().process_frame
	GameState.reset_for_new_game()
	GameState.persist_saves = false


func _force_close_letter() -> void:
	if _ui == null:
		return
	var panel: Node = _ui.get_node_or_null("StoryBeatPanel")
	if panel != null and bool(panel.visible):
		panel.visible = false
	_ui.set("_story_beat_blocked", false)
	while GameState.is_time_paused():
		GameState.pop_time_pause()


func _panel_open() -> bool:
	if _ui == null:
		return false
	var panel: Node = _ui.get_node_or_null("StoryBeatPanel")
	return panel != null and bool(panel.visible)


func _snap() -> Dictionary:
	var panel := _panel_open()
	var toast := ""
	var toast_n: Node = _ui.get("_toast") if _ui else null
	if toast_n:
		toast = str(toast_n.get("text")).strip_edges()
	var ov: Node = _ui.get("_day_cycle_overlay") if _ui else null
	var prompt := false
	if ov != null and ov.has_method("is_prompt_visible"):
		prompt = bool(ov.call("is_prompt_visible"))
	var sleep := bool(_ui.get("_sleep_flow_active")) if _ui else false
	var awakening := false
	var ending := false
	if _ui:
		var ap: Node = _ui.get_node_or_null("AwakeningPanel")
		awakening = ap != null and bool(ap.visible)
		var ep: Node = _ui.get_node_or_null("EndingPanel")
		ending = ep != null and bool(ep.visible)
	var bits: Array[String] = []
	if panel:
		bits.append("letter")
	if toast != "":
		bits.append("toast:%s" % toast)
	if prompt:
		bits.append("prompt")
	if sleep:
		bits.append("sleep-flow")
	if awakening:
		bits.append("awakening")
	if ending:
		bits.append("ending")
	if bits.is_empty():
		bits.append("none")
	return {
		"panel": panel,
		"toast": toast,
		"prompt": prompt,
		"sleep": sleep,
		"awakening": awakening,
		"ending": ending,
		"summary": " ".join(bits),
	}


func _ok(line: String) -> void:
	_pass_n += 1
	print("  PASS: %s" % line)


func _fail(tag: String, why: String, snap: Dictionary) -> void:
	var line := "%s: %s (%s)" % [tag, why, snap.get("summary", "")]
	_fails.append(line)
	print("  FAIL: %s" % line)


func _settle(sec: float) -> void:
	## 忽略 time_scale / pause，按真实秒等，避免信纸 deferred 还没开完就判定没反应。
	await get_tree().create_timer(sec, true, true, true).timeout
