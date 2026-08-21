extends SceneTree
## D35 觉醒 headless 自测
## godot --headless --path <项目根> -s tools/d35_self_test.gd

var _failures: Array[String] = []


func _initialize() -> void:
	call_deferred("_run")


func _run() -> void:
	print("=== D35 self-test ===")
	_test_awakening_json_keys()
	_test_d35_steps_structure()
	_test_fragment_wall_lists_unlocked()
	_test_act2_has_intro()
	_test_debug_jump_to_d35()
	_test_week_wrap_no_preview()
	_print_report()
	quit(_failures.size())


func _test_awakening_json_keys() -> void:
	for key in [
		"act1_footer_true", "act2_intro", "act3_true", "f10_full",
	]:
		var text := StoryNodeCopy.get_awakening(key)
		_assert(text.strip_edges() != "", "awakening.%s present" % key)


func _test_d35_steps_structure() -> void:
	GameState.reset_for_new_game()
	_seed_true_ending_stats()
	var steps := EndingDirector.get_d35_awakening_steps(EndingDirector.ENDING_TRUE)
	_assert(steps.size() >= 4, "true ending has 4+ awakening steps")
	_assert(str(steps[0].get("title", "")).contains("碎片"), "step1 is fragment wall")
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
	var panel := preload("res://scripts/ui/week_wrap_panel.gd").new()
	var hint := panel.call("_preview_hint")
	panel.free()
	_assert("明早醒来" not in hint, "week wrap hint has no W1 preview")
	_assert("忘了" not in hint or "日子" in hint, "week wrap hint avoids amnesia tease")


func _seed_true_ending_stats() -> void:
	GameState.set_player_display_name("测试者")
	for fid in ["F01", "F02", "F03", "F04", "F05", "F06", "F07", "F08", "F09", "F10"]:
		GameState.unlock_fragment(fid, "test")
	GameState.long_term_memory["memory_recovery"] = 0.9
	GameState.affection = 60
	GameState.bond = 50
	GameState.set_ending_flag("companionship_nights", 3)
	var promise := {"summary": "一起看萝卜", "fulfilled": true}
	GameState.long_term_memory["promise"] = promise


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
