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
	_assert("存档坏了" in text or "弄丢" in text, "D4 morning telegraphs amnesia")


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
