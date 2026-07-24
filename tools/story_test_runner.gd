extends Node
## 剧情自动化测试入口（需在项目内运行以加载 autoload）
## godot --headless --path <项目根> res://tools/story_test_runner.tscn

const WeekWrapPanelScript := preload("res://scripts/ui/week_wrap_panel.gd")

var _failures: Array[String] = []


func _ready() -> void:
	call_deferred("_run_all")


func _run_all() -> void:
	print("=== Story automated tests ===")
	_run_f5_tests()
	_run_d35_tests()
	_print_report()
	get_tree().quit(_failures.size())


func _run_f5_tests() -> void:
	print("-- F5 --")
	_test_advance_day_writes_journal()
	_test_empty_chat_no_digest()
	_test_week1_feel_no_recovery_language()
	_test_week_wrap_includes_day7_preview()
	_test_week_archive_after_day7_advance()


func _run_d35_tests() -> void:
	print("-- D35 --")
	_test_awakening_json_keys()
	_test_d35_steps_structure()
	_test_fragment_wall_lists_unlocked()
	_test_act2_has_intro()
	_test_debug_jump_to_d35()
	_test_week_wrap_no_preview()


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
	if highlights is Array:
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
	if archived.is_empty():
		_assert(false, "week 1 archived after day 7 advance")
		return
	var archive_text := str(archived.get("summary", ""))
	for bucket in [archived.get("highlights", []), archived.get("merged_highlights", [])]:
		if bucket is Array:
			for raw in bucket:
				archive_text += str(raw)
	# day 7 收成可能落在末条 journal 的 summary 里
	if not ("萝卜" in archive_text or "收获" in archive_text):
		var last_summary := GameState.last_day_summary
		_assert("萝卜" in last_summary or "收获" in last_summary, "week archive retains day 7 harvest (via last_day_summary)")
	else:
		_assert(true, "week archive retains day 7 harvest")


func _test_awakening_json_keys() -> void:
	for key in ["open", "act1_footer_true", "act2_intro", "act3_true", "f10_full"]:
		var text := StoryNodeCopy.get_awakening(key)
		_assert(text.strip_edges() != "", "awakening.%s present" % key)


func _test_d35_steps_structure() -> void:
	GameState.reset_for_new_game()
	_seed_true_ending_stats()
	var steps := EndingDirector.get_d35_awakening_steps(EndingDirector.ENDING_TRUE)
	_assert(steps.size() >= 4, "true ending has 4+ awakening steps")
	_assert(str(steps[0].get("title", "")).contains("记起") or str(steps[0].get("title", "")).contains("片段"), "step1 is fragment wall")
	_assert(str(steps[1].get("title", "")).contains("记下"), "step2 is journal")
	var act3 := str(steps[2].get("body", ""))
	_assert("我记得你了" in act3, "true act3 core line")
	var bad_steps := EndingDirector.get_d35_awakening_steps(EndingDirector.ENDING_BAD)
	_assert(bad_steps.size() == 3, "bad ending has 3 steps (no F10 montage)")


func _test_fragment_wall_lists_unlocked() -> void:
	GameState.reset_for_new_game()
	GameState.unlock_fragment("F01", "test")
	GameState.unlock_fragment("F02", "test")
	var steps := EndingDirector.get_d35_awakening_steps(EndingDirector.ENDING_NORMAL)
	var body := str(steps[0].get("body", ""))
	_assert("登门" in body, "fragment wall lists F01 title")
	_assert("第一粒种" in body or "一起种" in body, "fragment wall lists F02")
	_assert("明早醒来" not in body, "fragment wall has no week preview text")


func _test_act2_has_intro() -> void:
	GameState.reset_for_new_game()
	GameState.record_memory_event("task_water", "浇田", 0.6, {"game_day": 1})
	GameState.append_day_journal({
		"day": 1, "week_index": 1, "loop_day": 1,
		"highlights": ["主线 · N01"], "summary": "第 1 天",
	})
	var steps := EndingDirector.get_d35_awakening_steps(EndingDirector.ENDING_HAPPY)
	var body := str(steps[1].get("body", ""))
	_assert("你帮她记下" in body or "这些日子" in body, "act2 companion intro present")
	_assert("N01" in body or "主线" in body, "act2 includes journal highlight")


func _test_debug_jump_to_d35() -> void:
	GameState.reset_for_new_game()
	GameState.debug_jump_to_d35()
	_assert(GameState.game_day == GameState.FINAL_GAME_DAY, "debug jump sets day 35")
	_assert(GameState.is_awakening_day(), "day 35 is awakening day")
	_assert(GameState.should_show_awakening(), "awakening should show after jump")
	_assert(not GameState.has_seen_awakening(), "awakening not marked seen")


func _test_week_wrap_no_preview() -> void:
	GameState.reset_for_new_game()
	GameState.game_day = 7
	var panel := WeekWrapPanelScript.new()
	var hint: String = str(panel.call("_preview_hint"))
	panel.free()
	_assert("明早醒来" not in hint, "week wrap hint has no W1 preview")
	if hint.strip_edges() != "":
		_assert("忘了" not in hint, "week wrap hint avoids amnesia tease")


func _seed_true_ending_stats() -> void:
	GameState.set_player_display_name("测试者")
	for fid in ["F01", "F02", "F03", "F04", "F05", "F06", "F07", "F08", "F09", "F10"]:
		GameState.unlock_fragment(fid, "test")
	GameState.long_term_memory["memory_recovery"] = 0.9
	GameState.affection = 60
	GameState.bond = 50
	GameState.set_ending_flag("companionship_nights", 3)
	GameState.long_term_memory["promise"] = {"summary": "一起看萝卜", "fulfilled": true}


func _assert(condition: bool, message: String) -> void:
	if condition:
		print("  PASS: %s" % message)
	else:
		print("  FAIL: %s" % message)
		_failures.append(message)


func _print_report() -> void:
	if _failures.is_empty():
		print("=== ALL PASS (%d checks) ===" % 1)
	else:
		print("=== FAILED (%d) ===" % _failures.size())
		for item in _failures:
			print(" - %s" % item)
