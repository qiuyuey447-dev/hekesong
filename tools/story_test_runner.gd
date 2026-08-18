extends Node
## 剧情自动化测试入口（需在项目内运行以加载 autoload）
## godot --headless --path <项目根> res://tools/story_test_runner.tscn

const WeekWrapPanelScript := preload("res://scripts/ui/week_wrap_panel.gd")

var _failures: Array[String] = []


func _ready() -> void:
	call_deferred("_run_all")


func _run_all() -> void:
	print("=== Story automated tests ===")
	_run_core_tests()
	_run_finale_tests()
	if GameState.IS_TEN_DAY_EDITION:
		_run_ten_day_tests()
	_print_report()
	get_tree().quit(_failures.size())


func _run_core_tests() -> void:
	print("-- Core --")
	_test_advance_day_writes_journal()
	_test_weather_aligns_with_story_days()
	_test_empty_chat_no_digest()
	_test_week1_feel_no_recovery_language()
	if not GameState.IS_TEN_DAY_EDITION:
		_test_week_wrap_includes_day7_preview()
		_test_week_archive_after_day7_advance()
	else:
		_test_ten_day_no_week_wrap()
		_test_ten_day_day7_advance_keeps_journal()


func _run_finale_tests() -> void:
	print("-- Finale --")
	_test_awakening_json_keys()
	_test_awakening_steps_structure()
	_test_fragment_wall_lists_unlocked()
	_test_act2_has_intro()
	_test_debug_jump_to_finale()
	if not GameState.IS_TEN_DAY_EDITION:
		_test_week_wrap_no_preview()


func _run_ten_day_tests() -> void:
	print("-- Ten-day --")
	_test_ten_day_calendar_bounds()
	_test_ten_day_story_modes()
	_test_ten_day_d4_morning_telegraph()
	_test_ten_day_promise_on_d3_beat()
	_test_ten_day_awakening_copy_no_week5()
	_test_ten_day_true_ending_reachable()
	_test_ten_day_node_copy_polish()
	_test_ten_day_smoke_keep_path()
	_test_ten_day_smoke_expel_path()
	_test_ten_day_dual_save_diff()
	_test_ten_day_leak_no_fabrication()
	_test_ten_day_leak_uses_journal()
	_test_ten_day_promise_slot_empty()
	_test_ten_day_pure_narrative_lock()
	_test_ten_day_chat_promise()
	_test_ten_day_mid_profile_copy()
	_test_status_inquiry_not_sleep()
	_test_intent_classify_flow()
	_test_personalized_story_steps()
	_test_d7_pending_tail_cleared_on_complete()
	_test_chat_archive_on_advance()
	_test_ten_day_bad_early_flow_guards()
	_test_ten_day_tier_copy_diff()
	_test_ten_day_fallback_full_playthrough()
	_test_player_notebook_dark_lines()
	_test_player_notebook_d9_missing()
	_test_player_notebook_awakening_reveal()
	_test_persona_regression_suite()
	_test_ten_day_e_polish()


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


func _test_weather_aligns_with_story_days() -> void:
	GameState.reset_for_new_game()
	_assert(
		GameState.weather_tomorrow_hint == GameState.WEATHER_RAIN,
		"day 2 preview is rainy for P_N02"
	)
	GameState.advance_day()
	_assert(GameState.game_day == 2, "advanced to day 2")
	_assert(
		GameState.weather_today == GameState.WEATHER_RAIN,
		"day 2 weather matches rain porch beat P_N02"
	)
	if not GameState.IS_TEN_DAY_EDITION:
		GameState.game_day = 16
		GameState._ensure_runtime_defaults()
		_assert(
			GameState.weather_today == GameState.WEATHER_RAIN,
			"day 16 weather matches rain porch beat N02p/F01"
		)
	var seed_a := GameState.weather_seed
	var day5_a := GameState.resolve_weather_for_day(5)
	var varied := false
	for offset in range(1, 24):
		GameState.weather_seed = seed_a + offset * 7919
		if GameState.resolve_weather_for_day(5) != day5_a:
			varied = true
			break
	GameState.weather_seed = seed_a
	_assert(varied, "non-story weather varies by seed")


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
	if not ("萝卜" in archive_text or "收获" in archive_text):
		var last_summary := GameState.last_day_summary
		_assert("萝卜" in last_summary or "收获" in last_summary, "week archive retains day 7 harvest (via last_day_summary)")
	else:
		_assert(true, "week archive retains day 7 harvest")


func _test_ten_day_no_week_wrap() -> void:
	GameState.reset_for_new_game()
	GameState.game_day = 7
	_assert(not GameState.should_show_week_wrap(), "ten-day edition disables week wrap panel")


func _test_ten_day_day7_advance_keeps_journal() -> void:
	GameState.reset_for_new_game()
	GameState.game_day = 7
	GameState.day_journal.append({
		"day": 6,
		"week_index": 1,
		"loop_day": 6,
		"summary": "第 6 天摘要",
		"highlights": ["浇田"],
	})
	GameState.advance_day()
	_assert(GameState.game_day == 8, "ten-day: day 7 advances to day 8")
	_assert(GameState.day_journal.size() >= 2, "ten-day: journal not wiped on day 7→8")


func _test_awakening_json_keys() -> void:
	for key in ["open", "act1_footer_true", "act2_intro", "act3_true", "f10_full"]:
		var text := StoryNodeCopy.get_awakening(key)
		_assert(text.strip_edges() != "", "awakening.%s present" % key)


func _test_awakening_steps_structure() -> void:
	GameState.reset_for_new_game()
	_seed_true_ending_stats()
	var steps := EndingDirector.get_d35_awakening_steps(EndingDirector.ENDING_TRUE)
	_assert(steps.size() >= 4, "true ending has 4+ awakening steps")
	_assert(str(steps[0].get("title", "")).contains("记起") or str(steps[0].get("title", "")).contains("片段"), "step1 is fragment wall")
	_assert(str(steps[1].get("title", "")).contains("记下"), "step2 is journal")
	var act3 := str(steps[2].get("body", ""))
	_assert(
		("不只是我" in act3 or "你也会忘" in act3) and "好不了" in act3 and "找回来" in act3,
		"true act3 core line (双向遗忘·互相打捞·永不痊愈)"
	)
	var bad_steps := EndingDirector.get_d35_awakening_steps(EndingDirector.ENDING_BAD)
	_assert(bad_steps.size() == 3, "bad ending has 3 steps (no F10 montage)")


func _test_fragment_wall_lists_unlocked() -> void:
	GameState.reset_for_new_game()
	GameState.unlock_fragment("F01", "test")
	GameState.unlock_fragment("F02", "test")
	var steps := EndingDirector.get_d35_awakening_steps(EndingDirector.ENDING_NORMAL)
	var body := str(steps[0].get("body", ""))
	_assert("登门" in body, "fragment wall lists F01 title")
	_assert("约定" in body or "第一粒种" in body or "一起种" in body, "fragment wall lists F02")
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


func _test_debug_jump_to_finale() -> void:
	GameState.reset_for_new_game()
	GameState.debug_jump_to_d35()
	_assert(GameState.game_day == GameState.FINAL_GAME_DAY, "debug jump sets finale day")
	_assert(GameState.is_awakening_day(), "finale day is awakening day")
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


func _test_ten_day_calendar_bounds() -> void:
	GameState.reset_for_new_game()
	_assert(GameState.FINAL_GAME_DAY == 10, "FINAL_GAME_DAY is 10")
	_assert(GameState.IS_TEN_DAY_EDITION, "ten-day flag on")
	for day in range(1, 11):
		var beat_id := ""
		if day <= 5:
			beat_id = StoryRouteData.get_beat_id_for_day(StoryRouteData.ROUTE_PROLOGUE, day)
		else:
			beat_id = StoryRouteData.get_beat_id_for_day(StoryRouteData.ROUTE_NORMAL, day)
		if day < 10:
			_assert(beat_id.strip_edges() != "", "day %d has calendar beat" % day)
		else:
			_assert(beat_id.strip_edges() == "", "day 10 has no calendar beat (awakening)")


func _test_ten_day_story_modes() -> void:
	GameState.reset_for_new_game()
	GameState.game_day = 4
	_assert(StoryDirector.get_story_mode() == "stranger", "D4 stranger mode")
	GameState.game_day = 5
	_assert(StoryDirector.get_story_mode() == "stranger", "D5 stranger mode")
	GameState.game_day = 6
	_assert(StoryDirector.get_story_mode() == "leak", "D6 leak mode")
	GameState.game_day = 9
	_assert(StoryDirector.get_story_mode() == "awaken", "D9 awaken mode")
	GameState.game_day = 10
	_assert(StoryDirector.get_story_mode() == "awaken", "D10 awaken mode")


func _test_ten_day_d4_morning_telegraph() -> void:
	GameState.reset_for_new_game()
	GameState.game_day = 4
	_assert(StoryRouteData.should_inject_morning_opening("P_N05"), "D4 injects morning telegraph")
	var text := StoryRouteData.render_morning_opening(false, "P_N05")
	_assert("弄丢" in text, "D4 morning telegraphs lost name")
	_assert("不是存档" in text or "失忆" in text, "D4 morning frames amnesia not save bug")
	_assert(StoryNodeCopy.get_system("d4_amnesia_hint").strip_edges() != "", "D4 amnesia hint copy present")


func _test_ten_day_promise_on_d3_beat() -> void:
	GameState.reset_for_new_game()
	GameState.game_day = 3
	StoryBeatDirector.complete_beat("P_N11")
	var promise: Dictionary = GameState.long_term_memory.get("promise", {})
	_assert(not promise.is_empty(), "D3 P_N11 sets promise")
	_assert(str(promise.get("summary", "")).strip_edges() != "", "promise summary non-empty")
	_assert(GameState.get_fragment_count() >= 1, "D3 unlocks F02 fragment")


func _test_ten_day_awakening_copy_no_week5() -> void:
	var open := StoryNodeCopy.get_awakening("open")
	_assert("第五周" not in open, "awakening open has no 第五周")
	GameState.reset_for_new_game()
	_seed_true_ending_stats()
	var steps := EndingDirector.get_epilogue_steps(EndingDirector.ENDING_NORMAL)
	var blob := ""
	for step in steps:
		blob += str(step.get("body", ""))
	_assert("第五周" not in blob, "normal epilogue has no 第五周")


func _test_ten_day_true_ending_reachable() -> void:
	GameState.reset_for_new_game()
	_seed_true_ending_stats()
	var ending := EndingDirector.resolve_ending(false)
	_assert(ending == EndingDirector.ENDING_TRUE, "seeded stats reach True ending")


func _test_ten_day_node_copy_polish() -> void:
	GameState.reset_for_new_game()
	GameState.set_player_display_name("阿松")
	GameState.set_promise("turnip_field", "等萝卜长好了，我们一起看看吧。")
	var p05 := StoryRouteData.render_body("P_N05", "P_N05")
	_assert("新的一周" not in p05, "P_N05 has no week language")
	_assert("你是谁" in p05, "P_N05 keeps stranger beat")
	var p11 := StoryRouteData.render_body("P_N11", "P_N11")
	_assert("本子" in p11, "P_N11 mentions notebook")
	var p06b := StoryRouteData.render_body("P_N06p", "P_N06_b")
	_assert("{" not in p06b, "D5 notebook slots filled")
	_assert("不能弄丢" in p06b, "D5 notebook shows the repeated line")
	var n16 := StoryRouteData.render_body("NM_N16", "NM_N16")
	_assert("阿松" in n16, "N16 speaks player name")
	_assert("萝卜" in n16 or "一起" in n16, "N16 echoes promise")
	var n15 := StoryRouteData.render_body("NM_N15", "NM_N15")
	_assert("第三周" not in n15 and "周结算" not in n15, "N15 has no week language")
	var night := StoryRouteData.render_companion_night_after("NM_N16", "companion_sit")
	_assert(night.strip_edges() != "", "D7 N16 night sit has response line")
	var p06p_def := StoryRouteData.get_beat_def("P_N06p")
	var p06p_steps: Array = p06p_def.get("steps", [])
	var p06p_titles: Array[String] = []
	for step in p06p_steps:
		if step is Dictionary:
			p06p_titles.append(str(step.get("title", "")))
	_assert("发现本子" in p06p_titles, "D5 includes notebook discovery")
	_assert("抉择" in p06p_titles, "P_N06p still has 抉择")
	var p05_def := StoryRouteData.get_beat_def("P_N05")
	_assert(p05_def.get("steps", []).size() >= 2, "D4 has two letter pages")
	var p05b := StoryRouteData.render_body("P_N05", "P_N05_b")
	_assert("浇" in p05b, "D4 second page stays on the field")
	var n02p_def := StoryRouteData.get_beat_def("NM_N02p")
	_assert(n02p_def.get("steps", []).size() >= 2, "D6 has extra lived page")
	var n02pb := StoryRouteData.render_body("NM_N02p", "NM_N02p_b")
	_assert(n02pb.strip_edges() != "", "D6 second page renders")
	var n20c_def := StoryRouteData.get_beat_def("NM_N20c")
	_assert(n20c_def.get("steps", []).size() >= 2, "D9 has extra night page")
	var n20cb := StoryRouteData.render_body("NM_N20c", "NM_N20c_b")
	_assert("明天" in n20cb, "D9 second page stays in these ten days")


func _test_ten_day_smoke_keep_path() -> void:
	print("  .. smoke keep path")
	GameState.reset_for_new_game()
	GameState.set_player_display_name("阿松")
	var prologue := ["P_N01", "P_N02", "P_N11", "P_N05", "P_N06p"]
	for i in range(prologue.size()):
		var day := i + 1
		GameState.game_day = day
		var expected: String = prologue[i]
		var today := StoryBeatDirector.get_today_beat_id()
		_assert(today == expected, "keep D%d today beat is %s" % [day, expected])
		var body := StoryRouteData.render_body(expected, expected)
		_assert(body.strip_edges() != "", "keep D%d body non-empty" % day)
		if expected == "P_N02":
			_assert(GameState.resolve_weather_for_day(2) == GameState.WEATHER_RAIN, "keep D2 rain")
		if expected == "P_N05":
			_assert(StoryDirector.get_story_mode() == "stranger", "keep D4 stranger")
		StoryBeatDirector.complete_beat(expected)
		if expected == "P_N06p":
			GameState.mark_w2_keep_choice()
			StoryBeatDirector.refresh_story_route()
			_assert(bool(GameState.get_ending_flags().get("w2_chose_keep", false)), "keep flag set")
	## 中等互动：避免雾中线，确保 D7 能叫名
	GameState.affection = 40
	GameState.bond = 28
	GameState.long_term_memory["memory_recovery"] = 0.55
	GameState.set_ending_flag("companionship_nights", 1)
	GameState.long_term_memory["relationship_signals"] = {
		"chat_turns": 20,
		"chat_days": 5,
		"last_chat_day": 5,
		"gifts_given": 1,
		"nodes_cleared": 6,
		"tasks_together": 4,
		"llm_affection_net": 4,
		"llm_bond_net": 3,
		"beat_chats": 3,
		"chat_aff_today": 0,
		"chat_aff_day": -1,
	}
	GameState.fulfill_promise("萝卜熟了。约定还在。")
	StoryBeatDirector.refresh_story_route()
	for day in range(6, 10):
		GameState.game_day = day
		StoryBeatDirector.ensure_story_route_locked()
		var beat_id := StoryBeatDirector.get_today_beat_id()
		_assert(beat_id.strip_edges() != "", "keep D%d has pending beat" % day)
		if day == 7:
			_assert(beat_id.ends_with("_N16"), "keep D7 is N16 spine")
			_assert(not StoryBeatDirector._is_rib_beat(beat_id), "keep D7 N16 is not rib-gated")
			var line := StoryRouteData.render_body(beat_id, beat_id)
			_assert("阿松" in line, "keep D7 calls player name")
			GameState.mark_companion_choice(true)
		if day == 8:
			_assert(beat_id.ends_with("_N15"), "keep D8 is notebook")
			var notebook_body := StoryRouteData.render_body(beat_id, beat_id)
			_assert("本子" in notebook_body, "keep D8 notebook body")
			_assert("{" not in notebook_body, "keep D8 slots filled")
		StoryBeatDirector.complete_beat(beat_id)
		GameState.append_day_journal({
			"day": day,
			"week_index": 1,
			"loop_day": day,
			"summary": "第 %d 天：阿松和小狸一起浇了田" % day,
			"highlights": ["主线 · %s" % beat_id, "聊天 · 廊下听雨"],
		})
	GameState.game_day = 10
	_assert(GameState.is_awakening_day(), "keep D10 is awakening day")
	_assert(GameState.should_show_awakening(), "keep D10 shows awakening")
	var ending := EndingDirector.resolve_ending(false)
	_assert(ending != EndingDirector.ENDING_BAD_EARLY, "keep path not bad early")
	var steps := EndingDirector.get_d35_awakening_steps(ending)
	_assert(steps.size() >= 3, "keep D10 awakening has steps")
	EndingDirector.finalize_ending(ending)
	_assert(GameState.is_story_complete(), "keep path story complete")
	_assert(not GameState.can_advance_day(), "finished ten days cannot open next loop")


func _test_ten_day_smoke_expel_path() -> void:
	print("  .. smoke expel path")
	GameState.reset_for_new_game()
	GameState.set_player_display_name("路人")
	for day in range(1, 5):
		GameState.game_day = day
		var beat_id := StoryBeatDirector.get_today_beat_id()
		_assert(beat_id.strip_edges() != "", "expel D%d has beat" % day)
		StoryBeatDirector.complete_beat(beat_id)
	GameState.game_day = 5
	var choice_beat := StoryBeatDirector.get_today_beat_id()
	_assert(choice_beat == "P_N06p", "expel D5 is choice beat")
	StoryBeatDirector.complete_beat("P_N06p")
	GameState.mark_w2_expel_choice()
	GameState.lock_story_route(StoryRouteData.ROUTE_BAD_EARLY)
	_assert(EndingDirector.resolve_ending(false) == EndingDirector.ENDING_BAD_EARLY, "expel resolves bad early")
	GameState.game_day = 6
	var be_beat := StoryBeatDirector.get_today_beat_id()
	_assert(be_beat == "BE_N07", "expel D6 is BE_N07")
	var be_body := StoryRouteData.render_body("BE_N07", "BE_N07")
	_assert("离开" in be_body or "走" in be_body, "expel D6 leaving copy")
	StoryBeatDirector.complete_beat("BE_N07")
	var epi := EndingDirector.get_epilogue_steps(EndingDirector.ENDING_BAD_EARLY)
	_assert(epi.size() >= 2, "expel epilogue present")
	EndingDirector.finalize_ending(EndingDirector.ENDING_BAD_EARLY)
	_assert(GameState.is_story_complete(), "expel path story complete")


func _test_ten_day_dual_save_diff() -> void:
	print("  .. dual-save diff")
	## 档 A：取名 + 约定 + 丰富日记
	GameState.reset_for_new_game()
	GameState.set_player_display_name("阿松")
	GameState.set_promise("turnip_field", "等萝卜长好了，我们一起看看吧。")
	GameState.mark_w2_keep_choice()
	GameState.lock_story_route(StoryRouteData.ROUTE_HAPPY)
	GameState.game_day = 7
	for i in range(1, 7):
		GameState.append_day_journal({
			"day": i,
			"week_index": 1,
			"loop_day": i,
			"summary": "阿松专属·第%d天廊下闲聊" % i,
			"highlights": ["阿松投喂了南瓜", "阿松说想一起看萝卜"],
		})
	var d7_a := StoryRouteData.render_body("HP_N16", "HP_N16")
	var montage_a := ""
	for step in EndingDirector.get_d35_awakening_steps(EndingDirector.ENDING_HAPPY):
		montage_a += str(step.get("body", "")) + "\n"
	_assert("阿松" in d7_a, "dual A D7 has player name")
	_assert("萝卜" in d7_a or "一起" in d7_a, "dual A D7 has promise")
	_assert("阿松专属" in montage_a or "南瓜" in montage_a or "廊下闲聊" in montage_a, "dual A D10 montage uses journal")

	## 档 B：无取名、无约定、几乎无日记
	GameState.reset_for_new_game()
	GameState.mark_w2_keep_choice()
	GameState.lock_story_route(StoryRouteData.ROUTE_NORMAL)
	GameState.game_day = 7
	var d7_b := StoryRouteData.render_body("NM_N16", "NM_N16")
	var montage_b := ""
	for step in EndingDirector.get_d35_awakening_steps(EndingDirector.ENDING_NORMAL):
		montage_b += str(step.get("body", "")) + "\n"
	_assert("阿松" not in d7_b, "dual B D7 lacks A name")
	_assert(d7_a != d7_b, "dual D7 lines differ across saves")
	_assert("阿松专属" not in montage_b and "南瓜" not in montage_b, "dual B montage lacks A journal")
	_assert(montage_a != montage_b, "dual D10 montage differs across saves")


func _test_ten_day_leak_no_fabrication() -> void:
	GameState.reset_for_new_game()
	GameState.game_day = 6
	GameState.long_term_memory["anchors"] = []
	GameState.short_term_memory.clear()
	GameState.day_journal.clear()
	_assert(LeakageEngine.peek_leak_context().is_empty(), "D6 leak empty without real memory")
	_assert(LeakageEngine.try_leak_line("session") == "", "D6 leak line empty without anchors")


func _test_ten_day_leak_uses_journal() -> void:
	GameState.reset_for_new_game()
	GameState.game_day = 6
	GameState.append_day_journal({
		"day": 3,
		"summary": "一起浇了萝卜田",
		"highlights": ["聊天 · 廊下听雨"],
	})
	var ctx := LeakageEngine.peek_leak_context()
	_assert(not ctx.is_empty(), "D6 leak picks journal highlight")
	_assert("廊下听雨" in str(ctx.get("anchor_summary", "")), "D6 leak journal text preserved")


func _test_ten_day_promise_slot_empty() -> void:
	GameState.reset_for_new_game()
	var ctx := StorySlotService.build_context()
	_assert(str(ctx.get("promise.summary", "")) == "", "empty promise slot stays empty")


func _test_ten_day_pure_narrative_lock() -> void:
	GameState.reset_for_new_game()
	GameState.game_day = 10
	_assert(GameState.is_pure_narrative_day(), "D10 pre-awakening is pure narrative")
	_assert(not TaskSystem.start_water_all_task(), "D10 blocks water task before awakening")


func _test_ten_day_chat_promise() -> void:
	GameState.reset_for_new_game()
	GameState.record_player_chat("我们约定，等萝卜长好了就一起看。")
	var promise: Dictionary = GameState.long_term_memory.get("promise", {})
	_assert(str(promise.get("id", "")) == "chat_promise", "chat sets chat_promise id")
	_assert("萝卜" in str(promise.get("summary", "")), "chat promise uses player words")
	GameState.set_promise("turnip_field", "D3 约定句")
	GameState.record_player_chat("约定别的事")
	var kept: Dictionary = GameState.long_term_memory.get("promise", {})
	_assert(str(kept.get("summary", "")) == "D3 约定句", "chat does not overwrite D3 promise")


func _test_ten_day_mid_profile_copy() -> void:
	GameState.reset_for_new_game()
	GameState.set_player_display_name("阿松")
	GameState.set_promise("turnip_field", "等萝卜长好了，我们一起看看吧。")
	GameState.affection = 40
	GameState.mark_w2_keep_choice()
	GameState.lock_story_route(StoryRouteData.ROUTE_NORMAL)
	GameState.game_day = 2
	var d2_variant := StoryBeatDirector.resolve_beat_variant("P_N02")
	var d2_mid := StoryRouteData.render_body("P_N02", str(d2_variant.get("variant_id", "P_N02")))
	var d2_warm := StoryRouteData.render_body("P_N02", "P_N02_warm")
	var d2_cold := StoryRouteData.render_body("P_N02", "P_N02_cold")
	_assert("够两个人" in d2_mid, "D2 mid has shared-space line")
	_assert(d2_mid != d2_warm and d2_mid != d2_cold, "D2 mid differs from warm/cold")
	GameState.game_day = 7
	var d7_mid := StoryRouteData.render_body("NM_N16", "NM_N16")
	_assert("想不起是哪天的" in d7_mid or "没敢靠太近" in d7_mid, "D7 mid has hesitant recall")
	GameState.affection = 70
	var d7_warm := StoryRouteData.render_body("NM_N16", "NM_N16")
	_assert(d7_mid != d7_warm, "D7 mid differs from warm at high affection")


func _test_status_inquiry_not_sleep() -> void:
	_assert(not IntentParser.looks_like_sleep_request("熟了没"), "熟了没 is not sleep")
	_assert(IntentParser.looks_like_status_inquiry("田怎么样"), "田怎么样 is status")
	var parsed := IntentParser.parse("能收了吗")
	_assert(str(parsed.get("intent", "")) == IntentParser.INTENT_CHECK_STATUS, "能收了吗 → check_status")
	_assert(IntentParser.looks_like_stop_farm_chore("别浇了"), "别浇了 is stop chore")
	var stop := IntentParser.parse("雨停再种")
	_assert(str(stop.get("intent", "")) == IntentParser.INTENT_CHAT, "雨停再种 stays chat")


func _test_intent_classify_flow() -> void:
	var local := IntentParser.parse("帮我浇水")
	var chat_api := {
		"intent": IntentParser.INTENT_CHAT,
		"plot_id": -1,
		"confidence": 0.8,
		"raw_text": "帮我浇水",
	}
	var merged := IntentParser.merge_intents(local, chat_api, "帮我浇水", true)
	_assert(str(merged.get("intent", "")) == IntentParser.INTENT_CHAT, "API chat wins over local water")
	var failed := IntentParser.merge_intents(local, {}, "帮我浇水", true)
	_assert(str(failed.get("source", "")) == "classify_failed", "classify fail degrades to chat")
	_assert(str(failed.get("intent", "")) == IntentParser.INTENT_CHAT, "classify fail intent is chat")
	var classified := IntentParser.from_api_classify_response({
		"intent": "chat",
		"confidence": 0.9,
		"reply": "我去浇水",
	}, "田看起来怎样")
	_assert(str(classified.get("intent", "")) == IntentParser.INTENT_CHAT, "classify parser ignores reply action")


func _test_personalized_story_steps() -> void:
	GameState.reset_for_new_game()
	GameState.set_player_display_name("阿松")
	GameState.append_day_journal({
		"day": 5,
		"summary": "廊下听雨",
		"chat_summary": "萝卜熟了再看",
		"highlights": ["聊天 · 萝卜熟了再看"],
	})
	var snippet := StoryRouteData.extract_chat_snippet_for_beat("NM_N02p")
	_assert("萝卜" in snippet, "N02p snippet uses chat digest")
	var fallback := NpcFallback.story_step_render({
		"beat_id": "NM_N02p",
		"personal_snippet": snippet,
	})
	_assert("本子" in fallback and "萝卜" in fallback, "N02p fallback weaves snippet")
	GameState.affection = 40
	GameState.mark_w2_keep_choice()
	GameState.lock_story_route(StoryRouteData.ROUTE_NORMAL)
	GameState.game_day = 6
	var signals: Dictionary = GameState.long_term_memory.get("relationship_signals", {})
	signals["chat_days"] = 2
	GameState.long_term_memory["relationship_signals"] = signals
	var beat := StoryBeatDirector.build_beat("NM_N02p")
	var has_llm := false
	for step in beat.get("steps", []):
		if step is Dictionary and str(step.get("llm_render", "")) == "chat_digest":
			has_llm = true
	_assert(has_llm, "N02p chat track marks llm_render")


func _test_d7_pending_tail_cleared_on_complete() -> void:
	GameState.reset_for_new_game()
	GameState.set_player_display_name("阿松")
	GameState.set_promise("turnip_field", "等萝卜长好了，我们一起看看吧。")
	GameState.mark_w2_keep_choice()
	GameState.lock_story_route(StoryRouteData.ROUTE_NORMAL)
	GameState.game_day = 7
	GameState.time_of_day = GameState.TIME_MORNING
	var beat := StoryBeatDirector.build_beat("NM_N16")
	beat = StoryBeatDirector.take_displayable_beat(beat)
	_assert(GameState.has_pending_story_beat_tail(), "D7 morning stashes night tail")
	_assert(not StoryBeatDirector.should_complete_beat_after_panel("NM_N16"), "D7 daytime does not complete beat")
	GameState.time_of_day = GameState.TIME_NIGHT
	var tail := StoryBeatDirector.build_beat_tail_resume()
	_assert(not tail.is_empty(), "D7 night resumes tail")
	_assert(StoryBeatDirector.should_complete_beat_after_panel("NM_N16"), "D7 night tail can complete")
	StoryBeatDirector.complete_beat("NM_N16")
	_assert(not GameState.has_pending_story_beat_tail(), "complete clears pending tail")


func _test_chat_archive_on_advance() -> void:
	GameState.reset_for_new_game()
	GameState.record_chat_turn("player", "今天有点累")
	GameState.record_chat_turn("companion", "那先歇一会儿")
	GameState.advance_day()
	var archive: Variant = GameState.long_term_memory.get("chat_archive", [])
	_assert(archive is Array and archive.size() == 1, "advance archives yesterday chat")
	var history := GameState.get_chat_history_for_ui()
	var found := false
	for turn in history:
		if turn is Dictionary and str(turn.get("text", "")).contains("今天有点累"):
			found = true
	_assert(found, "UI history includes archived player line")


func _test_ten_day_bad_early_flow_guards() -> void:
	GameState.reset_for_new_game()
	GameState.mark_w2_expel_choice()
	GameState.lock_story_route(StoryRouteData.ROUTE_BAD_EARLY)
	_assert(GameState.is_bad_early_path(), "expel flag marks bad early path")
	GameState.game_day = 5
	_assert(GameState.can_advance_day(), "D5 expel can still sleep to D6")
	GameState.game_day = 6
	_assert(not GameState.can_advance_day(), "D6+ expel cannot advance day")
	_assert(not GameState.should_show_awakening(), "bad early never shows awakening")
	_assert(not GameState.should_force_story_finale(), "finale waits until BE_N07")
	GameState.mark_story_node_seen("BE_N07")
	_assert(GameState.should_force_story_finale(), "BE_N07 seen forces bad early finale")


func _test_ten_day_tier_copy_diff() -> void:
	GameState.reset_for_new_game()
	GameState.set_player_display_name("阿松")
	GameState.set_promise("turnip_field", "等萝卜长好了，我们一起看看吧。")
	var warm := StoryRouteData.render_body("P_N02", "P_N02_warm")
	var mid := StoryRouteData.render_body("P_N02", "P_N02_mid")
	var cold := StoryRouteData.render_body("P_N02", "P_N02_cold")
	_assert(warm != mid and mid != cold and warm != cold, "D2 three-tier copy differs")
	var n11_warm := StoryRouteData.render_body("P_N11", "P_N11_warm")
	var n11_mid := StoryRouteData.render_body("P_N11", "P_N11_mid")
	_assert(n11_warm != n11_mid, "D3 warm/mid copy differs")


func _test_ten_day_fallback_full_playthrough() -> void:
	print("  .. fallback full playthrough")
	_test_fallback_speech_matrix()
	_test_fallback_keep_path_d1_d10()
	_test_fallback_expel_path_d1_d6()


func _test_fallback_speech_matrix() -> void:
	GameState.reset_for_new_game()
	GameState.game_day = 1
	var mem1 := MemoryService.get_context_for_event("session_start", {})
	var greet1 := NpcFallback.greet(
		GameState.get_stage(),
		1,
		0,
		GameState.get_weather_label(),
		mem1
	)
	_assert_fallback_line(greet1, "D1 session greet")

	GameState.game_day = 4
	var mem4 := MemoryService.get_context_for_event("player_chat", {})
	var chat4 := NpcFallback.player_chat("你是谁", GameState.get_stage(), mem4, {})
	_assert(
		"想不起来" in chat4 or "不记得" in chat4 or "对不起" in chat4,
		"D4 fallback stays amnesiac"
	)
	_assert_stranger_fallback_safe(chat4, "D4 chat")

	var greet4 := NpcFallback.greet(
		GameState.get_stage(),
		4,
		GameState.affection,
		GameState.get_weather_label(),
		mem4,
		"清晨"
	)
	_assert_fallback_line(greet4, "D4 session greet")
	_assert_stranger_fallback_safe(greet4, "D4 greet")

	GameState.game_day = 6
	GameState.long_term_memory["anchors"] = [{
		"id": "test_anchor",
		"summary": "廊下听雨",
		"game_day": 2,
		"importance": 0.8,
	}]
	var mem6 := MemoryService.get_context_for_event("player_chat", {})
	var chat6 := NpcFallback.player_chat("今天怎么样", GameState.get_stage(), mem6, {})
	_assert_fallback_line(chat6, "D6 leak chat")

	var plant := NpcFallback.task_complete({"task": "plant", "plot_count": 2}, {})
	_assert("种" in plant, "fallback plant complete has copy")
	var harvest := NpcFallback.task_complete({"task": "harvest", "plot_count": 1}, {})
	_assert("收" in harvest, "fallback harvest complete has copy")
	var water := NpcFallback.task_complete({"task": "water", "plot_count": 3}, {})
	_assert("浇" in water, "fallback water complete has copy")

	var snapshot := WorldSnapshot.capture({})
	for react_type in [
		"world_weather_change",
		"world_crop_ready",
		"world_evening",
		"story_nudge",
		"persona_shift",
	]:
		var react := NpcFallback.companion_react(
			react_type,
			snapshot,
			StoryDirector.get_story_hint(),
			GameState.get_stage(),
			mem6
		)
		_assert_fallback_line(react, "fallback react %s" % react_type)

	var step := NpcFallback.story_step_render({
		"personal_snippet": "廊下那刻很静",
		"beat_id": "NM_N02p",
	})
	_assert("廊下" in step or step.strip_edges() != "", "fallback story_step_render")

	var casual := NpcFallback.proactive_line({
		"time_of_day": "morning",
		"story_mode": str(mem4.get("story_mode", "stranger")),
	})
	_assert_fallback_line(casual, "fallback proactive stranger morning")

	var feed := NpcFallback.companion_feed(
		{"id": "turnip", "name": "萝卜"},
		[],
		false,
		0
	)
	_assert_fallback_line(feed, "fallback companion_feed")

	_assert(EndingDirector.get_awakening_steps(EndingDirector.ENDING_TRUE).size() >= 3, "awakening alias returns steps")


func _test_fallback_keep_path_d1_d10() -> void:
	GameState.reset_for_new_game()
	GameState.set_player_display_name("阿松")
	var prologue := ["P_N01", "P_N02", "P_N11", "P_N05", "P_N06p"]
	for i in range(prologue.size()):
		var day := i + 1
		GameState.game_day = day
		var beat_id: String = prologue[i]
		_assert(StoryBeatDirector.get_today_beat_id() == beat_id, "fallback keep D%d beat" % day)
		var body := StoryRouteData.render_body(beat_id, beat_id)
		_assert(body.strip_edges() != "", "fallback keep D%d body" % day)
		var mem := MemoryService.get_context_for_event("player_chat", {})
		if day == 4:
			_assert_stranger_fallback_safe(
				NpcFallback.player_chat("你好", GameState.get_stage(), mem, {}),
				"fallback keep D4 chat"
			)
		StoryBeatDirector.complete_beat(beat_id)
		if beat_id == "P_N06p":
			GameState.mark_w2_keep_choice()
			StoryBeatDirector.refresh_story_route()

	GameState.affection = 40
	GameState.bond = 28
	GameState.long_term_memory["memory_recovery"] = 0.55
	GameState.fulfill_promise("萝卜熟了。约定还在。")
	StoryBeatDirector.refresh_story_route()
	for day in range(6, 10):
		GameState.game_day = day
		StoryBeatDirector.ensure_story_route_locked()
		var beat_id := StoryBeatDirector.get_today_beat_id()
		_assert(beat_id.strip_edges() != "", "fallback keep D%d spine" % day)
		_assert_fallback_beat_playable(beat_id, "fallback keep D%d spine" % day)
		StoryBeatDirector.complete_beat(beat_id)
		if day == 7:
			PlayerNotebookService.on_first_write_d7()

	GameState.game_day = 10
	_assert(GameState.should_show_awakening(), "fallback keep D10 awakening")
	var ending := EndingDirector.resolve_ending(false)
	_assert(ending != EndingDirector.ENDING_BAD_EARLY, "fallback keep not bad early")
	EndingDirector.finalize_ending(ending)
	_assert(GameState.is_story_complete(), "fallback keep D1-D10 completable")


func _test_fallback_expel_path_d1_d6() -> void:
	GameState.reset_for_new_game()
	for day in range(1, 5):
		GameState.game_day = day
		var beat_id := StoryBeatDirector.get_today_beat_id()
		_assert(beat_id.strip_edges() != "", "fallback expel D%d beat" % day)
		StoryBeatDirector.complete_beat(beat_id)
	GameState.game_day = 5
	StoryBeatDirector.complete_beat("P_N06p")
	GameState.mark_w2_expel_choice()
	GameState.lock_story_route(StoryRouteData.ROUTE_BAD_EARLY)
	GameState.game_day = 6
	var be_beat := StoryBeatDirector.get_today_beat_id()
	_assert(be_beat == "BE_N07", "fallback expel D6 BE_N07")
	_assert(
		StoryRouteData.render_body("BE_N07", "BE_N07").strip_edges() != "",
		"fallback expel D6 body"
	)
	StoryBeatDirector.complete_beat("BE_N07")
	EndingDirector.finalize_ending(EndingDirector.ENDING_BAD_EARLY)
	_assert(GameState.is_story_complete(), "fallback expel D1-D6 completable")


func _assert_fallback_line(line: String, label: String) -> void:
	_assert(line.strip_edges() != "", "%s non-empty" % label)


func _assert_fallback_beat_playable(beat_id: String, label: String) -> void:
	var beat := StoryBeatDirector.build_beat(beat_id)
	var steps: Array = beat.get("steps", [])
	_assert(not steps.is_empty(), "%s has steps" % label)
	for step in steps:
		if not step is Dictionary:
			continue
		var body := str(step.get("body", "")).strip_edges()
		if body != "":
			_assert(true, "%s has copy" % label)
			return
		var tpl := str(step.get("template", "")).strip_edges()
		if tpl == "":
			continue
		var rendered := StoryRouteData.render_body(beat_id, tpl)
		if rendered.strip_edges() != "":
			_assert(true, "%s has copy" % label)
			return
	_assert(false, "%s has playable copy" % label)


func _assert_stranger_fallback_safe(text: String, label: String) -> void:
	for phrase in RelationshipDirector.get_stranger_ooc_phrases():
		if phrase != "" and phrase in text:
			_assert(false, "%s avoids stranger OOC (%s)" % [label, phrase])
			return
	for phrase in RelationshipDirector.get_stranger_intimate_phrases():
		if phrase != "" and phrase in text:
			_assert(false, "%s avoids stranger intimate (%s)" % [label, phrase])
			return
	_assert(true, "%s stranger-safe" % label)


func _test_player_notebook_dark_lines() -> void:
	GameState.reset_for_new_game()
	PlayerNotebookService.on_beat_completed("P_N01")
	var pages := PlayerNotebookService.get_pages_for_ui()
	_assert(pages.size() >= 1, "D1 dark line adds question page")
	_assert(str(pages[0].get("status", "")) == "question", "D1 page is question mark")
	GameState.game_day = 2
	PlayerNotebookService.on_beat_completed("P_N02")
	var visible_count := 0
	for page in PlayerNotebookService.get_pages_for_ui():
		if str(page.get("status", "")) == "visible":
			visible_count += 1
	_assert(visible_count >= 1, "D2 adds visible rain page")
	var excerpt := StorySlotService.slot("my_notebook_excerpt", StorySlotService.build_context())
	_assert(excerpt != "", "my_notebook slot uses player notebook excerpt")


func _test_player_notebook_d9_missing() -> void:
	GameState.reset_for_new_game()
	PlayerNotebookService.add_visible_page("第一页", 1, "deja_vu_d1")
	PlayerNotebookService.add_visible_page("第二页", 2, "rain_moment_d2")
	PlayerNotebookService.add_visible_page("第三页", 7, "first_write_d7")
	PlayerNotebookService.on_day_advanced(9)
	var missing_count := 0
	for page in PlayerNotebookService.get_pages_for_ui():
		if str(page.get("status", "")) == "missing":
			missing_count += 1
	_assert(missing_count >= 2, "D9+ marks earliest visible pages missing")
	var kept := false
	for page in PlayerNotebookService.get_pages_for_ui():
		if str(page.get("text", "")).contains("第三页"):
			kept = true
	_assert(kept, "D7 first write page survives D9 missing")


func _test_player_notebook_awakening_reveal() -> void:
	GameState.reset_for_new_game()
	PlayerNotebookService.on_beat_completed("P_N01")
	var steps := EndingDirector.get_awakening_steps(EndingDirector.ENDING_TRUE)
	var act2_body := str(steps[1].get("body", "")) if steps.size() > 1 else ""
	_assert("眼熟" in act2_body, "awakening act2 includes player notebook reveal")
	var again := PlayerNotebookService.reveal_for_awakening()
	_assert(again.is_empty(), "awakening reveal only once via ending director")


func _test_persona_regression_suite() -> void:
	GameState.reset_for_new_game()
	GameState.game_day = 6
	var payload := {
		"memory_context": MemoryService.get_context_for_event("player_chat", {}),
		"story_mode": "leak",
	}
	var l3_bad := ResponseValidator.validate("player_chat", "上周我们一起浇过田。", payload, [])
	_assert(not bool(l3_bad.get("ok", true)), "L3 episodic claim rejected without citation")
	_assert(str(l3_bad.get("reason", "")) == "l3_episodic", "L3 rejection reason tagged")

	GameState.game_day = 4
	var stranger_payload := {
		"memory_context": MemoryService.get_context_for_event("player_chat", {}),
		"story_mode": "stranger",
		"player_name": "",
	}
	var ooc := ResponseValidator.validate("player_chat", "我们以前一起浇过田。", stranger_payload, [])
	_assert(not bool(ooc.get("ok", true)), "stranger OOC phrase rejected")
	var intimate := ResponseValidator.validate("player_chat", "想你了，别走。", stranger_payload, [])
	_assert(not bool(intimate.get("ok", true)), "stranger intimate phrase rejected")

	GameState.long_term_memory["persona"] = {
		"warm": 0.9, "strict": 0.5, "active": 0.5, "optimistic": 0.5, "dependent": 0.5,
	}
	GameState.regress_persona_toward_baseline(0.02)
	var warm := float(GameState.get_persona_vector().get("warm", 0.5))
	_assert(warm < 0.9, "persona regresses toward baseline")

	GameState.game_day = 7
	GameState.long_term_memory["persona"] = {
		"warm": 0.65, "strict": 0.5, "active": 0.5, "optimistic": 0.5, "dependent": 0.5,
	}
	GameState.long_term_memory["persona_shift_announced"] = []
	var shift := GameState.peek_persona_shift()
	_assert(not shift.is_empty(), "persona shift detected when delta >= 0.12")
	_assert(str(shift.get("dimension", "")) == "warm", "persona shift picks warm dimension")

	var literary := ResponseValidator.validate("player_chat", "雨帘后面，心里发紧。", payload, [])
	_assert(not bool(literary.get("ok", true)), "literary phrase rejected in chat")


func _test_ten_day_e_polish() -> void:
	print("  .. E polish")
	_assert(
		StoryNodeCopy.get_system("blocking_story_beat").strip_edges() != "",
		"blocking hint uses narrative copy"
	)
	_assert(
		"任务" not in StoryNodeCopy.get_system("blocking_story_beat"),
		"blocking hint avoids task wording"
	)
	_assert(StoryNodeCopy.get_system("sleep_prompt_title") == "夜深了", "sleep prompt narrative title")

	GameState.reset_for_new_game()
	GameState.game_day = 2
	GameState.weather_today = GameState.WEATHER_RAIN
	_assert(GameState.can_proactive_speech("ambient"), "rain morning allows one ambient")
	GameState.consume_proactive_speech("ambient")
	_assert(not GameState.can_proactive_speech("ambient"), "ambient capped at one per day")
	var ambient := NpcFallback.ambient_sidewrite(GameState.WEATHER_RAIN)
	_assert("廊" in ambient or "雨" in ambient, "rain ambient mentions porch or rain")

	var font := UIFontTheme.get_font()
	_assert(font != null, "UIFontTheme font loaded for Web/Desktop")
	_assert(FileAccess.file_exists("res://assets/fonts/ZCOOLKuaiLe-Regular.ttf"), "primary CJK font file present")

	GameState.reset_for_new_game()
	GameState.register_farm_plots(4)
	_assert(GameState.plant_turnip(1), "farm plant regression")
	GameState.mark_plot_watered(1)
	var plot: Dictionary = GameState.get_plot(1)
	_assert(bool(plot.get("watered", false)), "farm water regression")

	for day in range(1, 11):
		GameState.game_day = day
		var weather := GameState.resolve_weather_for_day(day)
		_assert(weather in [GameState.WEATHER_RAIN, GameState.WEATHER_SUN], "D%d weather resolves" % day)

	for day in [4, 5]:
		GameState.reset_for_new_game()
		GameState.game_day = day
		if day == 5:
			GameState.set_player_display_name("阿松")
		var payload := {
			"memory_context": MemoryService.get_context_for_event("player_chat", {}),
			"story_mode": StoryDirector.get_story_mode(),
			"player_name": GameState.get_player_display_name(),
		}
		_assert(str(payload.get("story_mode", "")) == "stranger", "D%d API guard stranger mode" % day)
		for phrase in ["又见面了", "还记得", "欢迎回来"]:
			var sample := "嗯，%s。" % phrase
			var check := ResponseValidator.validate("player_chat", sample, payload, [])
			_assert(not bool(check.get("ok", true)), "D%d rejects OOC phrase: %s" % [day, phrase])
		if day == 5 and GameState.get_player_display_name() != "":
			var name_check := ResponseValidator.validate(
				"player_chat",
				"阿松，又见面了。",
				payload,
				[]
			)
			_assert(not bool(name_check.get("ok", true)), "D5 stranger rejects player name in chat")


func _seed_true_ending_stats() -> void:
	GameState.set_player_display_name("测试者")
	for fid in ["F01", "F02", "F03", "F04", "F05", "F06", "F07", "F08", "F09", "F10"]:
		GameState.unlock_fragment(fid, "test")
	GameState.long_term_memory["memory_recovery"] = 0.9
	GameState.affection = 60
	GameState.bond = 50
	GameState.set_ending_flag("companionship_nights", 3)
	GameState.long_term_memory["promise"] = {"summary": "一起看萝卜", "fulfilled": true}
	GameState.long_term_memory["relationship_signals"] = {
		"chat_turns": 40,
		"chat_days": 8,
		"last_chat_day": GameState.game_day,
		"gifts_given": 3,
		"nodes_cleared": 12,
		"tasks_together": 8,
		"llm_affection_net": 10,
		"llm_bond_net": 8,
		"beat_chats": 6,
		"chat_aff_today": 0,
		"chat_aff_day": -1,
	}


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
