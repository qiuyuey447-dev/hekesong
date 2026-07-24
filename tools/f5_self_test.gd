extends SceneTree
## F5 自测：跨天 journal 写入 + 周结算 highlights（headless）
## 运行：godot --headless --path <项目根> -s tools/f5_self_test.gd

const WeekWrapPanelScript := preload("res://scripts/ui/week_wrap_panel.gd")

var _failures: Array[String] = []


func _initialize() -> void:
	call_deferred("_run")


func _run() -> void:
	print("=== F5 self-test ===")
	_test_advance_day_writes_journal()
	_test_empty_chat_no_digest()
	_test_week1_feel_no_recovery_language()
	_test_week_wrap_includes_day7_preview()
	_test_week_archive_after_day7_advance()
	_print_report()
	quit(_failures.size())


func _test_advance_day_writes_journal() -> void:
	GameState.reset_for_new_game()
	var day_before := GameState.game_day
	GameState.advance_day()
	_assert(GameState.game_day == day_before + 1, "advance_day increments game_day")
	_assert(not GameState.day_journal.is_empty(), "journal non-empty after advance")
	var entry: Dictionary = GameState.day_journal[GameState.day_journal.size() - 1]
	_assert(int(entry.get("day", -1)) == day_before, "journal entry day matches slept day")
	var highlights: Variant = entry.get("highlights", [])
	_assert(highlights is Array, "journal highlights is array")
	for raw in highlights:
		_assert(not str(raw).begins_with("聊天 ·"), "no chat highlight without chatting")
	_assert(str(entry.get("summary", "")).strip_edges() != "", "journal summary populated")


func _test_empty_chat_no_digest() -> void:
	GameState.reset_for_new_game()
	GameState.record_memory_event(
		"task_water",
		"小狸帮你浇完了两块田",
		0.65,
		{"game_day": GameState.game_day}
	)
	var entry := DayJournalService.build_entry(GameState.weather_today)
	var digest := str(entry.get("chat_digest_rule", "")).strip_edges()
	_assert(digest == "", "chat digest empty when no chat log")
	var highlights: Variant = entry.get("highlights", [])
	if highlights is Array:
		for raw in highlights:
			_assert(not str(raw).begins_with("聊天 ·"), "build_entry skips chat highlight without chat")


func _test_week1_feel_no_recovery_language() -> void:
	GameState.reset_for_new_game()
	GameState.game_day = 7
	var feel := StoryRouteData.render_week_relationship_feel()
	_assert("记起" not in feel and "守住" not in feel, "week 1 feel avoids memory-recovery wording")


func _test_week_wrap_includes_day7_preview() -> void:
	GameState.reset_for_new_game()
	GameState.game_day = 7
	for loop_day in range(1, 7):
		GameState.day_journal.append({
			"day": loop_day,
			"week_index": 1,
			"loop_day": loop_day,
			"summary": "第 %d 天摘要" % loop_day,
			"highlights": ["第 %d 天亮点" % loop_day],
		})
	GameState.record_memory_event(
		"story_beat",
		"第一周周末，小狸说：「明天可能会有一点不一样。」",
		0.85,
		{"game_day": 7, "node": "P_N04"}
	)
	var panel := WeekWrapPanelScript.new()
	var text := panel.build_summary_text()
	panel.free()
	_assert("第 7 天" in text, "week wrap preview includes day 7 before advance")
	_assert("第一周周末" in text or "明天可能会有一点不一样" in text, "day 7 story highlight visible")


func _test_week_archive_after_day7_advance() -> void:
	GameState.reset_for_new_game()
	GameState.game_day = 7
	for loop_day in range(1, 7):
		GameState.day_journal.append({
			"day": loop_day,
			"week_index": 1,
			"loop_day": loop_day,
			"summary": "第 %d 天摘要" % loop_day,
			"highlights": ["第 %d 天亮点" % loop_day],
		})
	GameState.record_memory_event(
		"harvest",
		"萝卜收成了",
		0.75,
		{"game_day": 7}
	)
	GameState.advance_day()
	_assert(GameState.game_day == 8, "week 1 day 7 advance moves to day 8")
	var archived := MemoryService.get_week_summary(1)
	_assert(not archived.is_empty(), "week 1 archived after day 7 advance")
	var merged: Variant = archived.get("merged_highlights", [])
	var highlights: Variant = archived.get("highlights", [])
	var has_day7 := false
	for bucket in [merged, highlights]:
		if bucket is Array:
			for raw in bucket:
				if "萝卜" in str(raw):
					has_day7 = true
	_assert(has_day7, "week archive retains day 7 highlight")


func _assert(condition: bool, message: String) -> void:
	if condition:
		print("  PASS: %s" % message)
	else:
		print("  FAIL: %s" % message)
		_failures.append(message)


func _print_report() -> void:
	if _failures.is_empty():
		print("=== ALL PASS ===")
	else:
		print("=== FAILED (%d) ===" % _failures.size())
		for item in _failures:
			print(" - %s" % item)
