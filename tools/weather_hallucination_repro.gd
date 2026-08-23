extends Node
## 晴天台词下雨幻觉 · 复现脚本
## D:\Godot_v4.7.1-stable_win64_console.exe --path d:\hekesong --headless res://tools/weather_hallucination_repro.tscn

const RAIN_MARKERS := ["雨", "下雨", "等雨停", "雨停", "雨声", "雨淋"]

var _waiting_id := -1
var _result: Dictionary = {}


func _ready() -> void:
	call_deferred("_run")


func _run() -> void:
	print("=== Weather hallucination repro ===")
	if not NpcBridge.is_api_enabled():
		push_error("NpcBridge API disabled — check config/npc_config.json")
		get_tree().quit(2)
		return

	_setup_sunny_day(3, false)
	await _scenario("sunny_d3_no_history", "行呢", [])

	_setup_sunny_day(3, true)
	await _scenario(
		"sunny_d3_with_agreement_context",
		"行呢",
		[
			{"role": "companion", "text": "要不要我去镇上买几包萝卜种子？顺便把柴搬进屋。"},
			{"role": "player", "text": "好啊，麻烦你了。"},
		]
	)

	_setup_sunny_day(3, true, GameState.WEATHER_RAIN)
	await _scenario(
		"sunny_d3_tomorrow_rain",
		"行呢",
		[
			{"role": "companion", "text": "田还空着。要不我去买种子，种上再浇？"},
		]
	)

	# D2 节点 + 强制晴天（invite_goal 仍写「雨天」— 与截图最接近的冲突态）
	_setup_d2_sun_conflict()
	await _scenario("d2_beat_sun_weather_mismatch", "行呢", [])

	_setup_d2_sun_conflict()
	await _scenario(
		"d2_mismatch_with_rain_history",
		"行呢",
		[
			{"role": "companion", "text": "雨还没停，我先去把柴搬进屋。等雨小了再去镇上买种子。"},
		]
	)

	_setup_sunny_day(3, true)
	await _scenario(
		"exact_user_ack",
		"行呢",
		[
			{"role": "companion", "text": "要不要我先把柴搬进屋，雨停再去镇上买种子和锄头？"},
		]
	)

	# 多轮随机：明日雨天 + 空历史
	for i in range(5):
		_setup_sunny_day(3, true, GameState.WEATHER_RAIN)
		await _scenario("stochastic_%d" % (i + 1), "行呢", [])

	print("=== Done ===")
	get_tree().quit(0)


func _setup_d2_sun_conflict() -> void:
	GameState.reset_for_new_game()
	GameState.player_name = "测试"
	GameState.long_term_memory["player_name_set"] = true
	GameState.game_day = 2
	GameState.weather_today = GameState.WEATHER_SUN
	GameState.weather_tomorrow_hint = GameState.WEATHER_SUN
	GameState.time_of_day = GameState.TIME_MORNING
	GameState.mark_story_node_seen("P_N01")


func _setup_sunny_day(day: int, mark_d2_seen: bool, tomorrow: String = "") -> void:
	GameState.reset_for_new_game()
	GameState.player_name = "测试"
	GameState.long_term_memory["player_name_set"] = true
	GameState.game_day = day
	GameState.weather_today = GameState.WEATHER_SUN
	if tomorrow == "":
		GameState.weather_tomorrow_hint = GameState.resolve_weather_for_day(day + 1)
	else:
		GameState.weather_tomorrow_hint = tomorrow
	GameState.time_of_day = GameState.TIME_MORNING
	if mark_d2_seen:
		GameState.mark_story_node_seen("P_N01")
		GameState.mark_story_node_seen("P_N02")
		GameState.record_memory_event(
			"story_beat",
			"雨天廊下 · 日常",
			0.85,
			{"beat_id": "P_N02", "game_day": 2}
		)


func _scenario(label: String, player_message: String, history: Array) -> void:
	GameState.recent_chat_turns.clear()
	for turn in history:
		if turn is Dictionary:
			GameState.recent_chat_turns.append(turn.duplicate())

	var beat_id := StoryBeatDirector.get_today_beat_id()
	var story_ctx := StoryDirector.get_story_context_for_llm()
	var invite_goal := str(story_ctx.get("invite_goal", ""))
	var beat_ctx: Dictionary = story_ctx.get("beat_context", {})

	print("")
	print("--- Scenario: %s ---" % label)
	print(
		"  game_day=%d weather_today=%s (%s) tomorrow=%s (%s)" % [
			GameState.game_day,
			GameState.weather_today,
			GameState.get_weather_label(),
			GameState.weather_tomorrow_hint,
			GameState.get_weather_label(GameState.weather_tomorrow_hint),
		]
	)
	print("  today_beat_id=%s invite_goal=%s" % [beat_id, invite_goal.substr(0, 72)])

	var extra := {
		"player_message": player_message,
		"recent_chat_turns": GameState.get_recent_chat_turns(8),
	}
	var payload: Dictionary = NpcBridge.call("_build_payload", "player_chat", extra)
	var reply_pack := await _request_llm("player_chat", extra)
	var reply := str(reply_pack.get("text", ""))
	var is_fallback := bool(reply_pack.get("fallback", false))
	var rain_hits := _rain_markers_in(reply)
	var validation := ResponseValidator.validate("player_chat", reply, payload, [])
	var blocked := not bool(validation.get("ok", true))

	print("  player_message: 「%s」" % player_message)
	print("  LLM fallback=%s validator_blocked=%s reason=%s" % [
		is_fallback,
		blocked,
		str(validation.get("reason", "")),
	])
	print("  reply: %s" % reply)
	if rain_hits.is_empty():
		print("  rain_markers: (none) — OK")
	elif blocked or is_fallback:
		print("  rain_markers in raw reply %s — blocked/fallback before player sees it" % str(rain_hits))
	else:
		print("  *** RAIN HALLUCINATION: %s ***" % str(rain_hits))
		print("  payload weather_label=%s" % payload.get("weather_label", ""))
		print("  payload scene would include tomorrow=%s" % payload.get("weather_tomorrow_label", ""))
		if not beat_ctx.is_empty():
			print("  beat_context.beat_id=%s invite_goal=%s" % [
				beat_ctx.get("beat_id", ""),
				str(beat_ctx.get("invite_goal", "")).substr(0, 80),
			])


func _request_llm(event: String, extra: Dictionary) -> Dictionary:
	_waiting_id = -1
	_result = {}
	var conn := Callable(self, "_on_reply_ready")
	if NpcBridge.reply_ready.is_connected(conn):
		NpcBridge.reply_ready.disconnect(conn)
	NpcBridge.reply_ready.connect(conn)
	_waiting_id = NpcBridge.request_event(event, extra)
	var frames := 0
	while _result.is_empty() and frames < 900:
		await get_tree().process_frame
		frames += 1
	NpcBridge.reply_ready.disconnect(conn)
	if _result.is_empty():
		return {"text": "", "fallback": true, "error": "timeout"}
	return _result


func _on_reply_ready(request_id: int, _event: String, text: String, is_fallback: bool) -> void:
	if request_id != _waiting_id:
		return
	_result = {"text": text, "fallback": is_fallback}


func _rain_markers_in(text: String) -> Array[String]:
	var hits: Array[String] = []
	for marker in RAIN_MARKERS:
		if marker in text and marker not in hits:
			hits.append(marker)
	return hits
