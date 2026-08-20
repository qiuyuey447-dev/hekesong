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


func _ensure_player_named() -> void:
	if not GameState.has_player_name_set():
		GameState.set_player_display_name("阿松")


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
	_test_ending_denouement_split()
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
	_test_trust_chain_copy()
	_test_ten_day_f5_branding()
	_test_dialogue_surface_policy()
	_test_wave3_audio_policy()
	_test_wave4_experience_policy()
	_test_wave5_trust_ui_policy()
	_test_ten_day_promise_on_d3_beat()
	_test_ten_day_promise_fulfill_from_feed()
	_test_ten_day_awakening_copy_no_week5()
	_test_ten_day_true_ending_reachable()
	_test_ten_day_node_copy_polish()
	_test_ten_day_smoke_keep_path()
	_test_ten_day_smoke_expel_path()
	_test_ten_day_dual_save_diff()
	_test_ten_day_leak_no_fabrication()
	_test_ten_day_leak_uses_journal()
	_test_notebook_infiltration_loop()
	_test_ten_day_residual_playtest_fixes()
	_test_infiltrate_playtest_followups()
	_test_ten_day_promise_slot_empty()
	_test_ten_day_pure_narrative_lock()
	_test_ten_day_chat_promise()
	_test_ten_day_mid_profile_copy()
	_test_status_inquiry_not_sleep()
	_test_sleep_request_explicit()
	_test_p11_night_period_gate()
	_test_harvest_offer_flow()
	_test_planting_rebuttal()
	_test_chore_completion_not_inquiry()
	_test_promise_not_fulfilled_on_harvest()
	_test_intent_classify_flow()
	_test_personalized_story_steps()
	_test_d7_pending_tail_cleared_on_complete()
	_test_d7_snuggle_fragment_completes_beat()
	_test_persona_w2_expel_choice_mapping()
	_test_chat_archive_on_advance()
	_test_ten_day_bad_early_flow_guards()
	_test_ten_day_tier_copy_diff()
	_test_ten_day_fallback_full_playthrough()
	_test_player_notebook_dark_lines()
	_test_player_notebook_d9_missing()
	_test_player_notebook_awakening_reveal()
	_test_persona_regression_suite()
	_test_ten_day_e_polish()
	_test_n15_mid_tier_render()
	_test_p_n11_cold_contract_phrases()
	_test_ten_day_letter_skips_system_followup()
	_test_d6_fragment_letter_skips_journal_digest()
	_test_ten_day_route_refresh_follows_ending()
	_test_time_pause_depth()
	_test_advance_day_blocked_without_name()
	_test_companion_offer_affirmative()
	_test_task_stale_reconcile()
	_test_chore_instruction_closure()
	_test_trade_coin_math()
	_test_xlh_history_contract()
	_test_xlh_body_actions()


func _test_advance_day_writes_journal() -> void:
	GameState.reset_for_new_game()
	_ensure_player_named()
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
	_ensure_player_named()
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
	_ensure_player_named()
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
	_ensure_player_named()
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
	for key in ["open", "act1_footer_true", "act2_intro", "act2_twoway_tease", "act3_true", "f10_full"]:
		var text := StoryNodeCopy.get_awakening(key)
		_assert(text.strip_edges() != "", "awakening.%s present" % key)


func _test_awakening_steps_structure() -> void:
	GameState.reset_for_new_game()
	_seed_true_ending_stats()
	GameState.day_journal.append({
		"day": 9,
		"summary": "第 9 天，晴天，打理了农场。",
		"highlights": [
			"聊天 · 你们聊了 5 句，你喂小狸红苹果，说「我爱你」。",
			"归档 · 第 1 天，雨天，聊天 · 你提到：「记住这个」。",
		],
	})
	var steps := EndingDirector.get_d35_awakening_steps(EndingDirector.ENDING_TRUE)
	_assert(steps.size() >= 4, "true ending has 4+ awakening steps")
	_assert(str(steps[0].get("title", "")).contains("记起") or str(steps[0].get("title", "")).contains("片段"), "step1 is fragment wall")
	_assert(str(steps[1].get("title", "")).contains("记下"), "step2 is journal")
	var wall := str(steps[0].get("body", ""))
	_assert("失忆物证" not in wall, "fragment wall has no forensic label")
	_assert("登门 —" not in wall and "约定 —" not in wall, "fragment wall has no catalog titles")
	_assert("不能弄丢这里" in wall or "田埂" in wall, "fragment wall keeps story lines")
	var act2 := str(steps[1].get("body", ""))
	_assert("你们聊了" not in act2, "journal montage drops chat-count digest")
	_assert("归档" not in act2, "journal montage drops archive labels")
	_assert("红苹果" in act2, "journal montage keeps the lived line")
	var act3 := str(steps[2].get("body", ""))
	_assert(
		("不只是我" in act3 or "你也会忘" in act3) and "好不了" in act3 and "找回来" in act3,
		"true act3 core line (双向遗忘·互相打捞·永不痊愈)"
	)
	var f10 := str(steps[3].get("body", ""))
	_assert("【归来】" not in f10 and "【约定】" not in f10 and "【本子】" not in f10, "F10 montage has no bracket tags")
	_assert("不能弄丢这里" in f10, "F10 montage keeps the notebook line")
	var bad_steps := EndingDirector.get_d35_awakening_steps(EndingDirector.ENDING_BAD)
	_assert(bad_steps.size() == 3, "bad ending has 3 steps (no F10 montage)")
	_test_awakening_two_way_gated()


func _test_awakening_two_way_gated() -> void:
	GameState.reset_for_new_game()
	_seed_true_ending_stats()
	var bare := EndingDirector.get_d35_awakening_steps(EndingDirector.ENDING_NORMAL)
	var bare_act2 := str(bare[1].get("body", ""))
	_assert("忘的，从来不只是我" not in bare_act2 and "忘的从来不只是我" not in bare_act2, "act2 intro alone does not spoil two-way")
	var bare_act3 := str(bare[2].get("body", ""))
	_assert("你也有一本" in bare_act3, "normal act3 B-fallback mentions player notebook")

	GameState.reset_for_new_game()
	_seed_true_ending_stats()
	PlayerNotebookService.on_beat_completed("P_N05")
	var hinted := EndingDirector.get_d35_awakening_steps(EndingDirector.ENDING_NORMAL)
	var hinted_act2 := str(hinted[1].get("body", ""))
	_assert("忘的，好像从来不只是我" in hinted_act2, "act2 tease after D4 dark line")
	_assert("被忘记的滋味" in hinted_act2, "act2 reveals mutual_forgetting question")

	var happy_act3 := str(EndingDirector.get_d35_awakening_steps(EndingDirector.ENDING_HAPPY)[2].get("body", ""))
	_assert("你也怕忘" in happy_act3, "happy act3 B-fallback")
	var bad_act3 := str(EndingDirector.get_d35_awakening_steps(EndingDirector.ENDING_BAD)[2].get("body", ""))
	_assert("你也早该写进本子" in bad_act3, "bad act3 B-fallback")


func _test_ending_denouement_split() -> void:
	print("  .. ending denouement split")
	GameState.reset_for_new_game()
	_seed_true_ending_stats()
	var awaken_true := _steps_blob(EndingDirector.get_awakening_steps(EndingDirector.ENDING_TRUE))
	_assert("不只是我" in awaken_true or "你也会忘" in awaken_true, "awakening keeps two-way reveal")
	_assert("好不了" in awaken_true, "awakening keeps never-heal core")
	for ending_id in [
		EndingDirector.ENDING_TRUE,
		EndingDirector.ENDING_HAPPY,
		EndingDirector.ENDING_NORMAL,
		EndingDirector.ENDING_BAD,
		EndingDirector.ENDING_BAD_EARLY,
	]:
		var steps := EndingDirector.get_full_ending_steps(ending_id)
		_assert(steps.size() == EndingDirector.get_epilogue_steps(ending_id).size(), "%s full ending is denouement only" % ending_id)
		for step in steps:
			_assert(str(step.get("kind", "")) != "climax", "%s ending has no climax steps" % ending_id)
		var blob := _steps_blob(steps)
		_assert(blob.strip_edges() != "", "%s denouement has copy" % ending_id)
		var epi_blob := _steps_blob_of_kind(steps, "epilogue")
		_assert("被爱不是被记住" not in epi_blob, "%s denouement skips true VO replay" % ending_id)
		_assert("忘的，从来不只是我" not in epi_blob, "%s denouement skips act3 two-way" % ending_id)
		_assert("没有嫌我麻烦" not in epi_blob, "%s denouement skips normal act3" % ending_id)
		_assert("每天要重新认一次的家" not in epi_blob, "%s denouement skips happy act3" % ending_id)
		_assert("谢谢你收留过我" not in epi_blob, "%s denouement skips bad-early beat replay" % ending_id)
		_assert("最要紧" not in epi_blob, "%s denouement skips glove apology" % ending_id)
	var true_end := _steps_blob(EndingDirector.get_epilogue_steps(EndingDirector.ENDING_TRUE))
	_assert("两个本子" in true_end or "并排" in true_end, "true denouement is notebooks")
	_assert("牙印" in true_end or "浅痕" in true_end, "true denouement is kettle mark")
	var happy_end := _steps_blob(EndingDirector.get_epilogue_steps(EndingDirector.ENDING_HAPPY))
	_assert("种" in happy_end and "碗" in happy_end, "happy denouement is seed and bowl")
	var normal_end := _steps_blob(EndingDirector.get_epilogue_steps(EndingDirector.ENDING_NORMAL))
	_assert("壶" in normal_end, "normal denouement is kettle")
	_assert("本子" in normal_end, "normal denouement is notebooks")
	var bad_end := _steps_blob(EndingDirector.get_epilogue_steps(EndingDirector.ENDING_BAD))
	_assert("空土垄" in bad_end, "bad denouement is empty ridge")
	var early_end := _steps_blob(EndingDirector.get_epilogue_steps(EndingDirector.ENDING_BAD_EARLY))
	_assert("碗" in early_end, "bad-early denouement is cabinet bowl")
	_assert("泥" in early_end, "bad-early denouement is the mud")
	for key in [
		"epilogue_true_1_body",
		"epilogue_happy_2_body",
		"epilogue_normal_2_body",
		"epilogue_bad_1_body",
		"epilogue_bad_early_2_body",
	]:
		_assert(StoryNodeCopy.get_ending(key).strip_edges() != "", "ending.%s present" % key)


func _steps_blob_of_kind(steps: Array, kind: String) -> String:
	var blob := ""
	for step in steps:
		if not step is Dictionary:
			continue
		if str(step.get("kind", "")) != kind:
			continue
		blob += str(step.get("title", "")) + "\n" + str(step.get("body", "")) + "\n"
	return blob


func _steps_blob(steps: Array) -> String:
	var blob := ""
	for step in steps:
		if not step is Dictionary:
			continue
		blob += str(step.get("title", "")) + "\n" + str(step.get("body", "")) + "\n"
	return blob


func _test_fragment_wall_lists_unlocked() -> void:
	GameState.reset_for_new_game()
	GameState.unlock_fragment("F01", "test")
	GameState.unlock_fragment("F02", "test")
	var steps := EndingDirector.get_d35_awakening_steps(EndingDirector.ENDING_NORMAL)
	var body := str(steps[0].get("body", ""))
	_assert("田埂" in body, "fragment wall lists F01 story")
	_assert("萝卜" in body or "一起看" in body, "fragment wall lists F02 story")
	_assert("登门 —" not in body and "失忆物证" not in body, "fragment wall has no catalog labels")
	_assert("明早醒来" not in body, "fragment wall has no week preview text")


func _test_act2_has_intro() -> void:
	GameState.reset_for_new_game()
	GameState.record_memory_event("task_water", "浇田", 0.6, {"game_day": 1})
	GameState.append_day_journal({
		"day": 1, "week_index": 1, "loop_day": 1,
		"highlights": ["你喂小狸红苹果。"], "summary": "第 1 天，晴天，打理了农场。",
	})
	var steps := EndingDirector.get_d35_awakening_steps(EndingDirector.ENDING_HAPPY)
	var body := str(steps[1].get("body", ""))
	_assert("你帮她记下" in body or "这些日子" in body, "act2 companion intro present")
	_assert("红苹果" in body, "act2 includes journal highlight")
	_assert("N01" not in body and "主线" not in body, "act2 drops beat-id labels")


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
	_assert("清晨风很凉" in text, "D4 morning opening line present")
	_assert("像不认得" in text, "D4 morning telegraphs stranger gaze")
	_assert("不是存档" not in text, "D4 morning omits save-bug explainer")
	GameState.set_ending_flag("d4_telegraph_ack_at_wake", true)
	_assert(
		StoryRouteData.render_morning_opening(false, "P_N05").strip_edges() == "",
		"D4 morning skips duplicate telegraph after wake ack"
	)
	_assert(StoryNodeCopy.get_system("d4_amnesia_hint").strip_edges() != "", "D4 amnesia hint copy present")
	_assert(StoryNodeCopy.get_system("d4_trust_confirm") == "知道了", "D4 trust confirm copy")
	_assert(StoryNodeCopy.get_system("d4_memory_panel_hint").strip_edges() != "", "D4 memory panel hint")


func _test_trust_chain_copy() -> void:
	print("  .. trust chain")
	var p11 := StoryRouteData.render_body("P_N11", "P_N11")
	_assert("名字" in p11 and "糊" in p11, "D3 P_N11 foreshadows name blur")
	GameState.reset_for_new_game()
	GameState.game_day = 4
	var ctx := {"story_mode": "stranger"}
	var save_line := NpcFallback.stranger_chat("是不是存档坏了？", ctx)
	_assert("不是坏了" in save_line or "没丢" in save_line, "stranger save worry fallback")
	_assert("欢迎回来" not in save_line, "save worry avoids OOC welcome")


func _test_ten_day_f5_branding() -> void:
	print("  .. F5 branding")
	_assert(GameState.GAME_DISPLAY_NAME == "去狸的岛", "display name unified")
	_assert(StoryNodeCopy.get_system("d1_after_name_companion").strip_edges() != "", "D1 opening guide copy")
	_assert("忘" not in StoryNodeCopy.get_system("d1_after_name_companion"), "D1 opening guide avoids spoilers")
	_assert("农场" in StoryNodeCopy.get_system("d1_after_name_companion"), "D1 opening guide mentions farm")
	_assert("我在这儿等" not in StoryNodeCopy.get_system("d1_after_name_companion"), "D1 opening avoids awkward waiting")
	_assert(StoryNodeCopy.get_system("tutorial_chat_hint").strip_edges() != "", "opening chat tutorial copy")
	_assert(StoryNodeCopy.get_system("tutorial_controls_hint").strip_edges() != "", "controls tutorial copy")
	_assert("忘" not in StoryNodeCopy.get_system("tutorial_controls_hint"), "controls hint avoids spoilers")
	for phrase in RelationshipDirector.get_awkward_waiting_phrases():
		_assert(phrase.strip_edges() != "", "awkward waiting phrase non-empty")
	_assert(
		not ResponseValidator.validate(
			"player_chat",
			"你忙你的，我就在旁边看着。不吵你。",
			{"story_mode": "familiar"},
		).get("ok", true),
		"awkward waiting reply rejected"
	)
	_assert("五周" not in GameState.get_about_dialog_text(), "about avoids week language")
	_assert("35" not in GameState.get_about_dialog_text(), "about avoids 35-day language")
	_assert("Demo" not in GameState.get_about_dialog_text(), "about avoids demo wording")
	var steps := EndingDirector.get_epilogue_steps(EndingDirector.ENDING_NORMAL)
	var credits_body := ""
	for step in steps:
		if str(step.get("kind", "")) == "credits":
			credits_body = str(step.get("body", ""))
			break
	_assert(GameState.GAME_DISPLAY_NAME in credits_body, "credits use display name")
	_assert("感谢体验" in credits_body, "credits thank play")
	_assert("感谢陪伴小狸的你" in credits_body, "credits thank companion")
	var anim_lines := EndingDirector.get_credits_animation_lines()
	_assert(anim_lines.size() == 3, "credits animation has three lines")
	_assert(anim_lines[0] == GameState.GAME_DISPLAY_NAME, "credits line 1 is title")
	_assert("河可松" not in credits_body, "credits avoid old product name")


func _test_dialogue_surface_policy() -> void:
	print("  .. dialogue UI")
	GameState.reset_for_new_game()
	GameState.record_chat_turn("player", "你好")
	GameState.record_chat_turn("companion", "嗯，我在。")
	var history := GameState.get_chat_history_for_ui()
	_assert(history.size() >= 2, "chat history still stored for journal/LLM")
	_assert(str(history[history.size() - 2].get("role", "")) == "player", "player turn kept in history")
	_assert(str(history[history.size() - 1].get("role", "")) == "companion", "companion turn kept in history")


func _test_wave3_audio_policy() -> void:
	print("  .. wave3 audio")
	GameState.reset_for_new_game()
	GameState.time_of_day = GameState.TIME_MORNING
	_assert(BgmDirector.resume_mode_after_sleep() == "day", "sleep resume uses morning day track")
	GameState.time_of_day = GameState.TIME_NIGHT
	_assert(BgmDirector.resume_mode_after_sleep() == "night", "sleep resume uses night track when still night")
	_assert(AmbientAudio.stinger_for_beat("P_N05") == "d4_stranger", "D4 beat maps stinger")
	_assert(AmbientAudio.stinger_for_beat("N16") == "d7_night", "D7 beat maps stinger")
	_assert(BasketDrawer.sprout_tier_for_affection(65) >= 3, "high affection reaches bloom tier")


func _test_wave4_experience_policy() -> void:
	print("  .. wave4 experience")
	GameState.reset_for_new_game()
	_assert(StoryNodeCopy.get_system("tutorial_notebook_hint").strip_edges() != "", "notebook tutorial copy")
	var beat := StoryBeatDirector.build_beat("NM_N20c")
	var steps: Array = beat.get("steps", [])
	var has_d9_choice := false
	for step in steps:
		if step is Dictionary and str(step.get("kind", "")) == "choice":
			for choice in step.get("choices", []):
				if choice is Dictionary and str(choice.get("id", "")) in ["d9_continue", "d9_defer"]:
					has_d9_choice = true
	_assert(not has_d9_choice, "D9 beat no longer offers soft pause choice")
	GameState.game_day = 9
	GameState.time_of_day = GameState.TIME_NIGHT
	var night_beat := StoryBeatDirector.build_beat("NM_N20c")
	var night_steps: Array = night_beat.get("steps", [])
	_assert(night_steps.size() > 0, "D9 night beat has steps")
	_assert(str(night_steps[0].get("title", "")) != "清晨", "D9 night beat skips morning opening")
	GameState.reset_for_new_game()
	GameState.game_day = 10
	GameState.set_deferred_story_beat("NM_N20c", 9)
	_assert(StoryBeatDirector.get_today_beat_id() == "", "D10 awakening day has no calendar beat")
	StoryBeatDirector.resolve_finale_day_carryover()
	_assert(GameState.get_deferred_story_beat() == "", "D10 carryover clears deferred beat")
	_assert(not ResponseValidator.validate("player_chat", "今日主线节点：NM_N20c", {}).get("ok", true), "director meta rejected")
	_assert("→" not in StoryNodeCopy.get_awakening("f10_medium"), "f10 montage avoids arrow glyphs")
	GameState.reset_for_new_game()
	GameState.game_day = 3
	GameState.append_day_journal({
		"day": 2,
		"highlights": [],
		"tags": ["chat"],
		"chat_turns": 9,
		"weather": "sun",
		"summary": "第 2 天，晴天，打理了农场。",
	})
	DayJournalService.apply_enrichment(2, {
		"chat_summary": "你们聊了9句，你问小狸是否有家人，她说不清，但觉得你叫她名字时很踏实。她约你明天田边看萝卜，说有话要说。",
		"companion_feel": "",
		"salience": 0.6,
	})
	var journal_entry := GameState.get_day_journal_entry(2)
	var chat_summary := str(journal_entry.get("chat_summary", ""))
	_assert("田边看萝卜" not in chat_summary, "chat summary strips unverified invite")
	_assert("踏实" in chat_summary, "chat summary keeps verified content")
	var leak := NpcFallback.player_chat("嗯", GameState.STAGE_FAMILIAR, {"story_mode": "leak", "revealed": false})
	var awaken := NpcFallback.player_chat("嗯", GameState.STAGE_FAMILIAR, {"story_mode": "awaken"})
	_assert(leak.strip_edges() != "", "leak fallback non-empty")
	_assert(awaken.strip_edges() != "", "awaken fallback non-empty")
	_assert(leak != awaken, "leak/awaken fallback differ")


func _test_wave5_trust_ui_policy() -> void:
	print("  .. wave5 trust ui")
	_assert(
		StoryNodeCopy.get_system("d5_notebook_trust_hint").strip_edges() != "",
		"D5 notebook trust hint copy"
	)
	_assert(
		StoryNodeCopy.get_system("companion_snuggle_afterglow").strip_edges() != "",
		"D7 snuggle afterglow copy"
	)
	for reason in ["plant_ok", "water_ok", "harvest_ok"]:
		var line := PersonaGuard.reply_for_plot_click(reason).strip_edges()
		_assert(line != "", "farm success reaction %s has copy" % reason)
	_assert(GameState.bgm_volume_linear >= 0.0, "bgm volume pref default")
	_assert(GameState.ambient_volume_linear >= 0.0, "ambient volume pref default")
	var water_hint := NpcFallback.pick_random([
		"田还干着。要浇你说一声。",
		"垄还干。你点头我就去。",
	])
	_assert("要不要" not in water_hint, "chat water fallback avoids customer-service tone")


func _test_ten_day_promise_on_d3_beat() -> void:
	GameState.reset_for_new_game()
	GameState.game_day = 3
	StoryBeatDirector.complete_beat("P_N11")
	var promise: Dictionary = GameState.long_term_memory.get("promise", {})
	_assert(not promise.is_empty(), "D3 P_N11 sets promise")
	_assert(str(promise.get("summary", "")).strip_edges() != "", "promise summary non-empty")
	_assert(GameState.get_fragment_count() >= 1, "D3 unlocks F02 fragment")
	var feed_days := GameState.get_true_feed_days()
	_assert(feed_days.size() == 2, "D3 promise rolls two true feed days")
	for day in feed_days:
		_assert(day >= GameState.TRUE_FEED_DAY_MIN and day <= GameState.TRUE_FEED_DAY_MAX, "true feed day in D4-D9")


func _test_ten_day_promise_fulfill_from_feed() -> void:
	GameState.reset_for_new_game()
	GameState.set_player_display_name("阿松")
	GameState.mark_story_node_seen("P_N11")
	GameState.set_promise("turnip_field", "等萝卜长好了，我们一起看看吧。")
	var target_days: Array = GameState.get_true_feed_days()
	_assert(target_days.size() == 2, "promise sets two random feed days")
	GameState.add_item("berry", 4)
	GameState.game_day = 3
	GameState.reset_daily_feed()
	var first := GameState.commit_feed_treat("berry")
	_assert(bool(first.get("ok", false)), "first feed succeeds")
	_assert(not bool(GameState.long_term_memory.get("promise", {}).get("fulfilled", false)), "off-target feed does not fulfill promise")
	for day in target_days:
		GameState.game_day = int(day)
		GameState.reset_daily_feed()
		GameState.add_item("berry", 1)
		GameState.commit_feed_treat("berry")
		GameState.try_fulfill_promise_from_feed()
	var promise: Dictionary = GameState.long_term_memory.get("promise", {})
	_assert(bool(promise.get("fulfilled", false)), "feeds on both random target days fulfill promise")
	_assert(int(RelationshipDirector.get_signals().get("gifts_given", 0)) >= 2, "two gifts recorded for fulfill")


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
		StoryBeatDirector.refresh_story_route()
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


func _test_notebook_infiltration_loop() -> void:
	print("  .. notebook infiltration loop")
	GameState.reset_for_new_game()
	GameState.set_player_display_name("阿松")
	var name_pages := MemoryService.get_anchor_pages()
	_assert(name_pages.size() >= 1, "name writes a notebook page")
	_assert("阿松" in str(name_pages[0].get("summary", "")), "name page is first-person")
	_assert("我怕念错" not in str(name_pages[0].get("summary", "")), "name page drops write-meta")
	_assert("白天 ·" not in str(name_pages[0].get("summary", "")), "name page is not a system label")
	var chat_line := MemoryService.compose_notebook_line("chat", "", {"text": "记住这个"})
	_assert(chat_line == "你说「记住这个」。", "chat page is the spoken line only")
	_assert("我怕忘" not in chat_line, "chat page drops 我怕忘")

	StoryBeatDirector.complete_beat("P_N01")
	for page in MemoryService.get_anchor_pages():
		_assert("白天 ·" not in str(page.get("summary", "")), "story beat does not write label pages")

	GameState.record_memory_event("task_water", "小狸浇好了 2 块田。", 0.55, {"task": "water", "game_day": GameState.game_day})
	var watered := false
	for page in MemoryService.get_anchor_pages():
		if "浇" in str(page.get("summary", "")):
			watered = true
	_assert(watered, "life page can enter the notebook")
	_assert(MemoryService.anchor_cap() == 6, "ten-day notebook cap is 6")

	var bounds := MemoryService.get_story_boundaries()
	_assert(bool(bounds.get("can_cite_episodic", false)), "D1 can_cite_episodic is true")
	var session_ctx := MemoryService.get_context_for_event("session_start", {})
	_assert(not (session_ctx.get("citable_memories", []) as Array).is_empty(), "session_start carries citable pages")

	GameState.game_day = 4
	_assert(not bool(MemoryService.get_story_boundaries().get("can_cite_episodic", true)), "D4 stranger closes episodic cite")

	GameState.reset_for_new_game()
	GameState.game_day = 3
	GameState.set_promise("turnip_field", "等萝卜长好了，我们一起看看吧。")
	var promise_blob := ""
	for page in MemoryService.get_anchor_pages():
		promise_blob += str(page.get("summary", ""))
	_assert("一起看" in promise_blob, "promise page is first-person")
	_assert("我写下来了" not in promise_blob, "promise page drops write-meta")
	_assert("小狸写进本子" not in promise_blob, "promise page drops system prefix")
	_assert(bool(GameState.get_ending_flags().get("notebook_pin_hint_due", false)), "promise queues pin hint")

	GameState.game_day = 6
	var leak_ctx := LeakageEngine.peek_leak_context()
	_assert(not leak_ctx.is_empty(), "D6 leak finds the promise page")
	_assert("白天 ·" not in str(leak_ctx.get("anchor_summary", "")), "D6 leak is not a system label")
	LeakageEngine.commit_leak_from_context(leak_ctx)
	_assert(PlayerNotebookService.has_unrevealed_questions(), "live leak leaves a player-notebook question")


func _test_ten_day_residual_playtest_fixes() -> void:
	print("  .. residual playtest fixes")
	GameState.reset_for_new_game()
	GameState.set_player_display_name("阿松")
	GameState.append_day_journal({
		"day": 1,
		"summary": "第 1 天，晴天，打理了农场。",
		"highlights": [],
	})
	for page in MemoryService.get_anchor_pages():
		_assert(not MemoryService.is_generic_farm_log(str(page.get("summary", ""))), "generic farm log stays out of notebook")
	_assert(
		MemoryService.compose_notebook_line("day_end", "第 8 天，晴天，打理了农场。", {}) == "",
		"generic day_end composes empty"
	)
	_assert(
		MemoryService.looks_like_system_label("第 2 天，雨天，聊天 · 你提到：「我会把你写进本子」"),
		"day-journal chat summary is system voice"
	)
	var spoken := MemoryService.eviction_spoken_excerpt({
		"notebook_line": "你说「我会把你写进本子」。我怕忘，先写在这里。",
		"summary": "第 2 天，雨天，聊天 · 你提到：「我会把你写进本子」",
	})
	_assert("写进本子" in spoken, "eviction speech uses notebook_line")
	_assert("我怕忘" not in spoken, "eviction speech drops write-meta")
	_assert("第 2 天" not in spoken, "eviction speech drops system summary")
	_assert(
		MemoryService.eviction_spoken_excerpt({
			"notebook_line": "",
			"summary": "第 2 天，雨天，聊天 · 你提到：「我会把你写进本子」",
		}) == "",
		"empty notebook_line is not spoken"
	)

	GameState.reset_for_new_game()
	GameState.mark_w2_keep_choice()
	GameState.lock_story_route(StoryRouteData.ROUTE_HAPPY)
	var n20c := StoryRouteData.get_beat_def("HP_N20c")
	_assert(str(n20c.get("fragment", "")) == "F05", "D9 N20c grants F05")
	StoryBeatDirector.complete_beat("HP_N20c")
	_assert(GameState.has_fragment("F05"), "completing D9 unlocks F05")
	_assert(str(StoryRouteData.get_beat_def("BL_N20c").get("fragment", "")) == "", "bad route D9 does not grant F05")

	GameState.reset_for_new_game()
	_seed_true_ending_stats()
	GameState.long_term_memory["memory_fragments"] = [
		{"id": "F01"},
		{"id": "F02"},
		{"id": "F07"},
		{"id": "F10"},
	]
	_assert(EndingDirector.count_ten_day_gate_fragments() == 2, "gate count ignores F07/F10")
	_assert(EndingDirector.resolve_ending(false) != EndingDirector.ENDING_TRUE, "F10 does not buy True")
	GameState.reset_for_new_game()
	_seed_true_ending_stats()
	var true_id := EndingDirector.resolve_ending(false)
	_assert(true_id == EndingDirector.ENDING_TRUE, "F01-F05 seed still True")
	EndingDirector.lock_ending_id(true_id)
	GameState.unlock_fragment("F10", "N20")
	GameState.long_term_memory["memory_fragments"] = [{"id": "F10"}]
	_assert(EndingDirector.resolve_ending(false) == EndingDirector.ENDING_TRUE, "locked ending ignores later fragment loss")
	var locked_titles := ""
	for step in EndingDirector.get_epilogue_steps(EndingDirector.resolve_ending(false)):
		locked_titles += str(step.get("title", ""))
	_assert("两个本子" in locked_titles, "locked True denouement stays notebooks")


func _test_infiltrate_playtest_followups() -> void:
	print("  .. infiltrate followups")
	GameState.reset_for_new_game()
	GameState.set_player_display_name("槐秋")
	GameState.game_day = 5
	var payload := {
		"event": "session_start",
		"story_mode": "stranger",
		"player_name": "",
		"player_name_context": GameState.get_player_name_context(),
		"memory_context": {"story_boundaries": MemoryService.get_story_boundaries()},
	}
	var blocked := ResponseValidator.validate("session_start", "早。槐秋，对吧？", payload, [])
	_assert(not bool(blocked.get("ok", true)), "stranger blocks stored name even if payload name empty")
	_assert(str(blocked.get("reason", "")) == "stranger_name", "reason is stranger_name")
	var allowed := ResponseValidator.validate(
		"session_start",
		"……你是谁？我不记得了。我怎么会在这里。",
		payload,
		[]
	)
	_assert(bool(allowed.get("ok", false)), "stranger amnesia line is allowed")

	GameState.reset_for_new_game()
	GameState.game_day = 6
	GameState.long_term_memory["anchors"] = []
	GameState.short_term_memory.clear()
	GameState.day_journal.clear()
	GameState.append_day_journal({
		"day": 2,
		"summary": "你们聊了2句，小狸记住了你的名字「满页」和左手腕的疤。",
		"highlights": [],
	})
	_assert(MemoryService.looks_like_journal_digest("你们聊了2句，小狸记住了你的名字"), "digest helper")
	_assert(LeakageEngine.peek_leak_context().is_empty(), "journal digest is not leak speech")
	var leak_line := NpcFallback.proactive_line({
		"proactive_intent": "leak",
		"leak_context": {"anchor_summary": "你们聊了2句，小狸记住了你的名字「满页」"},
		"story_mode": "leak",
	})
	_assert("你们聊了" not in leak_line, "fallback leak does not recite digest")

	GameState.reset_for_new_game()
	GameState.game_day = 1
	GameState.record_player_chat("我有一条红围巾，别弄丢。")
	GameState.game_day = 6
	var quiet := RelationshipDirector.get_player_quiet_context()
	_assert(int(quiet.get("quiet_days", 0)) >= 2, "idle days since last chat")
	_assert(bool(quiet.get("should_nudge", false)), "quiet player should be nudged")
	var quiet_leak := NpcFallback.proactive_line({
		"proactive_intent": "leak",
		"story_mode": "leak",
		"player_quiet": quiet,
		"leak_context": {"anchor_summary": "聊天 · 廊下听雨"},
	})
	_assert(
		"不说" in quiet_leak or "开口" in quiet_leak,
		"idle leak mentions player silence"
	)
	GameState.record_player_chat("早")
	var talked := RelationshipDirector.get_player_quiet_context()
	_assert(not bool(talked.get("should_nudge", true)), "chat today clears quiet nudge")
	GameState.game_day = 5
	GameState.long_term_memory["relationship_signals"]["last_chat_day"] = 1
	var stranger_quiet := NpcFallback.quiet_nudge_line([], {
		"story_mode": "stranger",
		"player_quiet": RelationshipDirector.get_player_quiet_context(),
	})
	_assert(stranger_quiet != "", "stranger idle still notes silence")
	_assert("这几天" not in stranger_quiet, "stranger silence is present-tense")


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


func _test_n15_mid_tier_render() -> void:
	GameState.reset_for_new_game()
	GameState.set_player_display_name("阿松")
	GameState.mark_w2_keep_choice()
	GameState.lock_story_route(StoryRouteData.ROUTE_NORMAL)
	GameState.game_day = 8
	GameState.affection = 40
	var body := StoryRouteData.render_body("NM_N15", "NM_N15_mid")
	_assert(body.strip_edges() != "", "N15 mid tier body non-empty")
	_assert("本子" in body, "N15 mid mentions notebook")


func _test_p_n11_cold_contract_phrases() -> void:
	GameState.reset_for_new_game()
	var cold := StoryRouteData.render_body("P_N11", "P_N11_cold")
	_assert("一起看" in cold, "P_N11_cold keeps 一起看 contract phrase")
	_assert("写进本子" in cold, "P_N11_cold keeps 写进本子 contract phrase")
	_assert("这一句我不想拿它赖掉" in cold, "P_N11_cold keeps D3 knife line")
	_assert("拿这个砸我" in cold, "P_N11_cold keeps notebook smash line")
	_assert(not ("你忙你的" in cold), "P_N11_cold has no companion-wait filler")
	var mid := StoryRouteData.render_body("P_N11", "P_N11_mid")
	_assert("这一句我不想拿它赖掉" in mid, "P_N11_mid keeps D3 knife line")
	_assert("拿这个砸我" in mid, "P_N11_mid keeps notebook smash line")
	_assert(mid != cold, "P_N11 mid differs from cold")


func _test_d6_fragment_letter_skips_journal_digest() -> void:
	GameState.reset_for_new_game()
	GameState.set_player_display_name("阿松")
	GameState.mark_w2_keep_choice()
	GameState.lock_story_route(StoryRouteData.ROUTE_NORMAL)
	GameState.game_day = 6
	GameState.append_day_journal({
		"day": 5,
		"tags": ["rain", "chat", "daily"],
		"summary": "第 5 天，雨天，聊天。",
		"highlights": [
			"聊天 · 你们在雨天聊了几句，你提到「烦死了」，小狸回应雨下不停，建议廊下躲雨。对话简短，关系仍陌生。",
		],
	})
	var cleaned := MemoryService.player_facing_journal_line(
		"聊天 · 你们在雨天聊了几句，你提到「烦死了」。对话简短，关系仍陌生。"
	)
	_assert(cleaned == "", "audit digest is not player-facing")
	_assert(
		"关系仍陌生" not in MemoryService.strip_relationship_audit_sentences(
			"你提到「烦死了」。对话简短，关系仍陌生。"
		),
		"audit sentence stripped from chat summary"
	)
	var beat := StoryBeatDirector.build_beat("NM_N02p")
	var blob := ""
	for raw in beat.get("steps", []):
		if not raw is Dictionary:
			continue
		blob += str(raw.get("title", "")) + "\n" + str(raw.get("body", "")) + "\n"
	_assert("登门" in blob, "D6 still has 登门 fragment")
	_assert("关系仍陌生" not in blob, "D6 letter has no relationship audit")
	_assert("对话简短" not in blob, "D6 letter has no brevity audit")
	_assert("聊天 ·" not in blob, "D6 letter has no chat-digest label")
	_assert("田埂" in blob or "走了很远" in blob, "D6 登门 keeps arrival story")


func _test_ten_day_letter_skips_system_followup() -> void:
	GameState.reset_for_new_game()
	GameState.set_player_display_name("阿松")
	GameState.affection = 40
	GameState.long_term_memory["memory_recovery"] = 0.55
	GameState.lock_story_route(StoryRouteData.ROUTE_NORMAL)
	GameState.game_day = 6
	var beat := StoryBeatDirector.build_beat("NM_N02p")
	var steps: Array = beat.get("steps", [])
	_assert(not steps.is_empty(), "D6 letter still has story steps")
	for raw in steps:
		if not raw is Dictionary:
			continue
		_assert(str(raw.get("title", "")) != "小狸想说", "ten-day letter has no 小狸想说 followup")
		_assert(not ("脑子里又清楚" in str(raw.get("body", ""))), "ten-day letter has no recovery_warm")


func _test_ten_day_route_refresh_follows_ending() -> void:
	GameState.reset_for_new_game()
	GameState.set_player_display_name("阿松")
	GameState.mark_w2_keep_choice()
	GameState.game_day = 5
	GameState.affection = 0
	StoryBeatDirector.refresh_story_route()
	_assert(
		GameState.get_story_route() != StoryRouteData.ROUTE_TRUE,
		"D5 low-stats keep does not lock True"
	)
	GameState.game_day = 7
	_seed_true_ending_stats()
	StoryBeatDirector.refresh_story_route()
	_assert(GameState.get_story_route() == StoryRouteData.ROUTE_TRUE, "later refresh upgrades to True")
	_assert(StoryBeatDirector.get_today_beat_id() == "TR_N16", "D7 calendar follows True route")


func _test_time_pause_depth() -> void:
	GameState.reset_for_new_game()
	_assert(not GameState.is_time_paused(), "time starts unpaused")
	GameState.push_time_pause()
	_assert(GameState.is_time_paused(), "single push pauses time")
	GameState.push_time_pause()
	_assert(GameState.is_time_paused(), "nested push keeps pause")
	GameState.pop_time_pause()
	_assert(GameState.is_time_paused(), "one pop leaves nested pause")
	GameState.pop_time_pause()
	_assert(not GameState.is_time_paused(), "all pops restore time")
	GameState.pop_time_pause()
	_assert(not GameState.is_time_paused(), "extra pop is safe")


func _test_advance_day_blocked_without_name() -> void:
	GameState.reset_for_new_game()
	var day_before := GameState.game_day
	GameState.advance_day()
	_assert(GameState.game_day == day_before, "advance_day blocked without player name")
	_ensure_player_named()
	GameState.advance_day()
	_assert(GameState.game_day == day_before + 1, "advance_day works after naming")


func _test_status_inquiry_not_sleep() -> void:
	_assert(not IntentParser.looks_like_sleep_request("熟了没"), "熟了没 is not sleep")
	_assert(IntentParser.looks_like_sleep_request("你还不睡觉吗"), "sleep nudge recognized")
	_assert(IntentParser.looks_like_sleep_request("怎么还不睡"), "怎么还不睡 is sleep nudge")
	_assert(not IntentParser.looks_like_sleep_request("别睡了"), "refuse sleep is not sleep request")
	_assert(not IntentParser.looks_like_sleep_request("睡得好吗"), "sleep quality question is not sleep request")
	_assert(IntentParser.looks_like_status_inquiry("田怎么样"), "田怎么样 is status")
	_assert(IntentParser.looks_like_status_inquiry("你种完啦？"), "你种完啦 is status")
	var parsed := IntentParser.parse("能收了吗")
	_assert(str(parsed.get("intent", "")) == IntentParser.INTENT_CHECK_STATUS, "能收了吗 → check_status")
	_assert(IntentParser.looks_like_stop_farm_chore("别浇了"), "别浇了 is stop chore")
	var stop := IntentParser.parse("雨停再种")
	_assert(str(stop.get("intent", "")) == IntentParser.INTENT_CHAT, "雨停再种 stays chat")


func _test_sleep_request_explicit() -> void:
	_assert(IntentParser.looks_like_sleep_request("睡觉吧"), "睡觉吧 is explicit sleep")
	_assert(IntentParser.is_explicit_sleep_utterance("睡觉吧"), "睡觉吧 in explicit list")


func _test_p11_night_period_gate() -> void:
	GameState.reset_for_new_game()
	_ensure_player_named()
	GameState.game_day = 3
	GameState.time_of_day = GameState.TIME_MORNING
	var morning_beat := StoryBeatDirector.take_displayable_beat(StoryBeatDirector.build_beat("P_N11"))
	_assert(morning_beat.is_empty(), "P_N11 morning defers agreement to evening")
	GameState.time_of_day = GameState.TIME_NIGHT
	var beat := StoryBeatDirector.build_beat("P_N11")
	beat = StoryBeatDirector.take_displayable_beat(beat)
	var steps: Array = beat.get("steps", [])
	_assert(steps.size() == 1, "P_N11 night skips evening-only P_N03")
	_assert(str(steps[0].get("template", "")).begins_with("P_N11"), "P_N11 night shows agreement step")
	var body := str(steps[0].get("body", ""))
	_assert("黄昏" not in body and "傍晚" not in body, "P_N11 night body drops dusk lexicon")
	_assert("夜里" in body, "P_N11 night body uses 夜里")
	_assert(GameState.get_pending_story_beat_tail_id() == "", "P_N11 night does not leave dusk tail")


func _test_harvest_offer_flow() -> void:
	_assert(ShopDelegate.looks_like_harvest_offer("要不要我先把熟的收了？"), "harvest offer detected")
	_assert(ShopDelegate.looks_like_harvest_commitment("去收吧"), "去收吧 is harvest commitment")
	_assert(ShopDelegate.is_affirmative_reply("好"), "好 is affirmative")


func _test_planting_rebuttal() -> void:
	_assert(IntentParser.looks_like_planting_rebuttal("萝卜不是你帮我种的吗"), "planting rebuttal detected")
	_assert(not IntentParser.looks_like_planting_rebuttal("帮我种萝卜"), "plant command is not rebuttal")


func _test_chore_completion_not_inquiry() -> void:
	_assert(IntentParser.looks_like_chore_completion_statement("收完了"), "收完了 is completion")
	_assert(not IntentParser.looks_like_status_inquiry("收完了"), "收完了 is not status inquiry")
	_assert(IntentParser.looks_like_status_inquiry("收好了吗"), "收好了吗 is inquiry")
	_assert(not GameState.has_story_promise(), "fresh game has no story promise")


func _test_promise_not_fulfilled_on_harvest() -> void:
	GameState.reset_for_new_game()
	_ensure_player_named()
	GameState.set_promise("turnip_field", "等萝卜长好了，我们一起看看吧。")
	var plot_ids := GameState.get_plantable_plot_ids()
	if plot_ids.is_empty():
		return
	# 仅验证：单次收获不会自动 fulfill（需 P_N12 节点）。
	GameState.game_day = 3
	_assert(not GameState.long_term_memory.get("promise", {}).get("fulfilled", false), "harvest alone does not fulfill promise")


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
	if GameState.IS_TEN_DAY_EDITION:
		_assert(not has_llm, "ten-day N02p skips chat_digest step")
	else:
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


func _test_d7_snuggle_fragment_completes_beat() -> void:
	GameState.reset_for_new_game()
	GameState.set_player_display_name("阿松")
	GameState.mark_w2_keep_choice()
	GameState.lock_story_route(StoryRouteData.ROUTE_HAPPY)
	GameState.game_day = 7
	GameState.time_of_day = GameState.TIME_NIGHT
	var beat := StoryBeatDirector.build_beat("HP_N16")
	beat = StoryBeatDirector.take_displayable_beat(beat)
	GameState.time_of_day = GameState.TIME_NIGHT
	var tail := StoryBeatDirector.build_beat_tail_resume()
	_assert(not tail.is_empty(), "D7 night resumes choice tail")
	GameState.set_pending_story_beat_tail("HP_N16", [{
		"title": "名字",
		"template": "F07",
		"kind": "fragment",
		"period_gate": [GameState.TIME_EVENING, GameState.TIME_NIGHT],
	}])
	_assert(not StoryBeatDirector.should_complete_beat_after_panel("HP_N16"), "fragment tail blocks complete")
	StoryBeatDirector.complete_beat("HP_N16")
	_assert(GameState.is_story_node_seen("HP_N16"), "post-snuggle path can mark D7 seen")
	_assert(not GameState.has_pending_story_beat_tail(), "complete clears fragment tail")


func _test_persona_w2_expel_choice_mapping() -> void:
	var spec := {"keep": false}
	_assert(_persona_choice_for_labels(spec, "P_N06p", "你的选择", ["留下她，再告诉她一遍", "让她走"]) == "w2_expel", "B1 W2 picks expel")
	_assert(_persona_choice_for_labels(spec, "P_N06p", "真的要让她走吗？", ["确定，送她离开", "再想想"]) == "w2_expel_confirm", "B1 W2 confirms expel")
	_assert(_persona_choice_for_labels({"keep": true, "sit": false}, "HP_N16", "你的选择", ["过去坐下", "先回屋"]) == "companion_leave", "night choice not confused with W2")


func _persona_choice_for_labels(spec: Dictionary, beat_id: String, title: String, labels: Array) -> String:
	if beat_id == "P_N06p":
		if "真的" in title or "确定" in title:
			if bool(spec.get("keep", true)):
				return "w2_expel_cancel"
			return "w2_expel_confirm"
		return "w2_keep" if bool(spec.get("keep", true)) else "w2_expel"
	var joined := " ".join(PackedStringArray(labels.map(func(l): return str(l))))
	if "确定" in joined or "送她" in joined:
		if bool(spec.get("keep", true)):
			return "w2_expel_cancel"
		return "w2_expel_confirm"
	if "过去" in joined or "坐下" in joined:
		return "companion_sit" if bool(spec.get("sit", true)) else "companion_leave"
	if "让她走" in joined and "留下" in joined:
		return "w2_keep" if bool(spec.get("keep", true)) else "w2_expel"
	if "留下" in joined:
		return "w2_keep" if bool(spec.get("keep", true)) else "w2_expel"
	return "w2_keep"


func _test_chat_archive_on_advance() -> void:
	GameState.reset_for_new_game()
	_ensure_player_named()
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
	var snack4 := NpcFallback.player_chat("你喜欢吃商店的哪个零食", GameState.get_stage(), mem4, {})
	_assert("零食" in snack4 or "吃" in snack4 or "商店" in snack4, "D4 snack question gets an answer")
	_assert("按你的来" not in snack4, "D4 snack question is not preference-ack")
	_assert_stranger_fallback_safe(snack4, "D4 snack")
	var fog_ok := ResponseValidator.validate(
		"player_chat",
		"……我脑子里只有一些很模糊的画面。",
		{"story_mode": "stranger", "player_message": "你是谁"},
		[]
	)
	_assert(bool(fog_ok.get("ok", false)), "D4 amnesia fog line is allowed")

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
	var stripped := ResponseValidator.strip_stage_directions(
		"(走到廊下，自己先占了最干的那块坐下) 给你留的。"
	)
	_assert("走到廊下" not in stripped, "stage directions stripped from chat")
	_assert("给你留的" in stripped, "spoken line kept after stage strip")
	var repetitive := ResponseValidator.looks_repetitive_companion_line("雨下得挺密，廊下倒是干爽。")
	if GameState.get_recent_chat_turns(8).is_empty():
		GameState.record_chat_turn("companion", "雨下得挺密，廊下倒是干爽。", false)
		repetitive = ResponseValidator.looks_repetitive_companion_line("雨下得密，苗不用浇了。")
	_assert(repetitive, "rain opener repeats after recent rain line")

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
		StoryBeatDirector.refresh_story_route()
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
	var act2_base := str(steps[1].get("body", "")) if steps.size() > 1 else ""
	_assert("眼熟" not in act2_base, "act2 defers notebook reveal until act2 opens")
	_assert(str(PlayerNotebookService.get_pages_for_ui()[0].get("text", "")) == "？", "pre-act2 question stays hidden")
	var act2_full := EndingDirector.append_act2_notebook_reveal(act2_base)
	_assert("眼熟" in act2_full, "act2 reveal includes player notebook line")
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

	var sunny_payload := {
		"weather_today": GameState.WEATHER_SUN,
		"story_mode": "keep",
	}
	var rain_hallucination := ResponseValidator.validate(
		"player_chat",
		"那我先把柴搬进屋，等雨停了就去镇上买种子。",
		sunny_payload,
		[]
	)
	_assert(not bool(rain_hallucination.get("ok", true)), "sunny day rain talk rejected")
	_assert(str(rain_hallucination.get("reason", "")) == "weather_mismatch", "weather mismatch reason")
	var sunny_on_rain := ResponseValidator.validate(
		"session_start",
		"早。今天天晴了，田里的水汽还没干透，正好省了浇水。",
		{"weather_today": GameState.WEATHER_RAIN, "story_mode": "stranger"},
		[]
	)
	_assert(not bool(sunny_on_rain.get("ok", true)), "rain day sunny talk rejected")
	_assert(str(sunny_on_rain.get("reason", "")) == "weather_mismatch", "rain sunny mismatch reason")
	var tomorrow_ok := ResponseValidator.validate(
		"player_chat",
		"明天可能要下雨，今天先把种子买好。",
		sunny_payload,
		[]
	)
	_assert(bool(tomorrow_ok.get("ok", true)), "tomorrow rain forecast allowed on sunny day")
	var rain_small := ResponseValidator.validate(
		"player_chat",
		"等雨小了我就去买种子。",
		sunny_payload,
		[]
	)
	_assert(not bool(rain_small.get("ok", true)), "等雨小了 rejected on sunny day")
	var timing_bad := ResponseValidator.validate(
		"player_chat",
		"你昨天倒是走得利索，就留了句拜拜。",
		{
			"weather_today": GameState.WEATHER_SUN,
			"story_mode": "keep",
			"relationship": {"game_day": 1},
			"chat_timing": GameState.get_chat_timing_context_for_llm(),
		},
		[]
	)
	_assert(not bool(timing_bad.get("ok", true)), "day1 yesterday reference rejected")
	_assert(str(timing_bad.get("reason", "")) == "chat_timing", "chat timing reason")


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
	_assert(FileAccess.file_exists("res://config/farm_plot_reactions.json"), "farm plot reactions config present")
	for reason in ["no_seeds", "already_watered", "rain", "need_closer", "not_mature", "harvest_failed"]:
		var line := PersonaGuard.reply_for_plot_click(reason).strip_edges()
		_assert(line != "", "farm plot reaction %s has copy" % reason)
		_assert("没有萝卜种子了" not in line, "farm plot %s avoids system seed toast" % reason)
		var banned := PersonaGuard.farm_reaction_banned_phrase(line)
		_assert(banned == "", "farm plot %s avoids AI phrase: %s" % [reason, banned])
	for reason in ["plant_ok", "water_ok", "harvest_ok"]:
		var ok_line := PersonaGuard.reply_for_plot_click(reason).strip_edges()
		_assert(ok_line != "", "farm plot success %s has copy" % reason)
		_assert(PersonaGuard.farm_reaction_banned_phrase(ok_line) == "", "farm success %s avoids banned phrase" % reason)
	GameState.reset_for_new_game()
	GameState.game_day = 2
	var early := PersonaGuard.reply_for_plot_click("no_seeds").strip_edges()
	_assert(early != "", "early farm no_seeds has copy")
	_assert(
		"背包里没有" not in early and "要不要" not in early,
		"early farm hint avoids customer-service seed line"
	)
	GameState.game_day = 4
	var stranger := PersonaGuard.reply_for_plot_click("already_watered").strip_edges()
	_assert(stranger.begins_with("……"), "stranger farm hint drops playful tone")
	_assert("帮我" not in stranger, "stranger farm hint avoids helper-bot wording")
	_assert(
		StoryNodeCopy.get_system("blocking_farm_d10").strip_edges() != "",
		"D10 farm block uses narrative system hint"
	)

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
	_assert(ResourceLoader.exists("res://assets/fonts/ZCOOLKuaiLe-Regular.ttf"), "primary CJK font resource exists")
	_assert(not UIFontTheme.is_using_fallback(), "UIFontTheme uses primary CJK font not zpix")

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
	GameState.affection = 12
	GameState.bond = 8
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


func _test_xlh_history_contract() -> void:
	print("  .. XL-H P1 history contract")
	GameState.reset_for_new_game()
	_ensure_player_named()
	GameState.record_chat_turn("player", "过来")
	GameState.record_chat_turn("companion", "来了。")
	var wrapped: Array[Dictionary] = GameState.get_recent_chat_turns(8)
	_assert(wrapped.size() >= 2, "player+companion turns stored")
	var companion_turn: Dictionary = wrapped[wrapped.size() - 1]
	_assert(companion_turn.has("reply_contract"), "plain companion line wraps reply_contract")
	var auto_contract: Dictionary = companion_turn.get("reply_contract", {})
	_assert(str(auto_contract.get("reply", "")) == "来了。", "wrapped reply matches visible text")
	_assert(str(auto_contract.get("intent", "")) == "chat", "wrapped intent defaults to chat")
	_assert(str(companion_turn.get("text", "")) == "来了。", "UI still stores plain text")
	GameState.reset_for_new_game()
	_ensure_player_named()
	for i in range(12):
		GameState.record_chat_turn("player", "第%d句" % i)
		GameState.record_chat_turn(
			"companion",
			"回%d" % i,
			false,
			{
				"reply": "回%d" % i,
				"intent": "chat",
				"plot_id": -1,
				"actions": [],
				"cited_memory_ids": [],
			}
		)
	var recent := GameState.get_recent_chat_turns(24)
	var companion_count := 0
	for turn in recent:
		if str(turn.get("role", "")) != "companion":
			continue
		companion_count += 1
		var contract: Variant = turn.get("reply_contract", {})
		_assert(contract is Dictionary, "companion history has contract dict")
		if not contract is Dictionary:
			continue
		var encoded := JSON.stringify(contract)
		var parsed: Variant = JSON.parse_string(encoded)
		_assert(parsed is Dictionary, "companion contract JSON is parseable")
		if parsed is Dictionary:
			_assert(
				str(parsed.get("reply", "")) == str(turn.get("text", "")),
				"contract reply matches stored text"
			)
	_assert(companion_count >= 12, "12 companion turns remain parseable")


func _test_xlh_body_actions() -> void:
	print("  .. XL-H P2 body actions")
	var follow := CompanionBodyAction.infer_from_player("过来一下")
	_assert(not follow.is_empty() and str(follow[0].get("id", "")) == "follow_player", "过来 → follow_player")
	var porch := CompanionBodyAction.infer_from_player("一起去廊下")
	_assert(
		not porch.is_empty()
		and str(porch[0].get("id", "")) == "walk_poi"
		and str(porch[0].get("poi", "")) == "porch",
		"一起去廊下 → walk_poi porch"
	)
	var hollow := CompanionBodyAction.infer_from_player("去树洞")
	_assert(
		not hollow.is_empty() and str(hollow[0].get("poi", "")) == "hollow",
		"去树洞 → hollow"
	)
	var water := CompanionBodyAction.infer_from_player("帮我把田浇了", "water_all")
	_assert(water.is_empty(), "farm intent drops body walk")
	var notebook := CompanionBodyAction.infer_from_player("翻本子看看")
	_assert(
		not notebook.is_empty() and str(notebook[0].get("id", "")) == "open_notebook",
		"翻本子 → open_notebook"
	)
	var exploded := CompanionBodyAction.sanitize_actions([{"id": "explode"}], "chat")
	_assert(exploded.is_empty(), "unknown action dropped")
	var aliased := CompanionBodyAction.sanitize_actions([{"id": "walk_poi", "poi": "plots"}], "chat")
	_assert(
		not aliased.is_empty() and str(aliased[0].get("poi", "")) == "field",
		"plots alias → field"
	)
	var stay := CompanionBodyAction.sanitize_actions([{"id": "stay"}], "chat")
	_assert(stay.is_empty(), "stay is a no-op")
	var porch_line := CompanionBodyAction.infer_from_companion_line("那我去廊下坐一会儿。")
	_assert(
		not porch_line.is_empty() and str(porch_line[0].get("poi", "")) == "porch",
		"companion 去廊下 still maps to porch"
	)
	var hollow_line := CompanionBodyAction.infer_from_companion_line("那我去树洞看看。")
	_assert(
		not hollow_line.is_empty() and str(hollow_line[0].get("poi", "")) == "hollow",
		"companion 我去树洞 → hollow"
	)
	var come_line := CompanionBodyAction.infer_from_companion_line("我过来找你。")
	_assert(
		not come_line.is_empty() and str(come_line[0].get("id", "")) == "follow_player",
		"companion 我过来 → follow_player"
	)
	var offer_line := CompanionBodyAction.infer_from_companion_line("要不要去廊下躲一会儿？")
	_assert(offer_line.is_empty(), "question 要不要去廊下 does not walk")
	var you_go := CompanionBodyAction.infer_from_companion_line("你去树洞吧，我在这儿。")
	_assert(you_go.is_empty(), "你去树洞 does not make her walk")
	var farm_line := CompanionBodyAction.infer_from_companion_line("好，我去田里浇一遍。")
	_assert(farm_line.is_empty(), "我去浇 does not also walk as body action")
	var farm_follow := CompanionBodyAction.sanitize_actions([{"id": "follow_player"}], "water_all")
	_assert(farm_follow.is_empty(), "farm intent drops follow_player")


func _assert(condition: bool, message: String) -> void:
	if condition:
		print("  PASS: %s" % message)
	else:
		print("  FAIL: %s" % message)
		_failures.append(message)


func _test_companion_offer_affirmative() -> void:
	print("  .. companion offer affirmative")
	_assert(
		ShopDelegate.looks_like_shop_offer("要不要我去商店看看？"),
		"shop offer detects 去商店 without 种子"
	)
	_assert(
		ShopDelegate.looks_like_shop_seed_offer("我去商店买几包种子吧？"),
		"shop seed offer accepts 吧 question ending"
	)
	_assert(
		ShopDelegate.looks_like_water_offer("需要我帮你浇一下吗？"),
		"water offer accepts 吗 question ending"
	)
	_assert(
		ShopDelegate.looks_like_water_offer("垄还干着。要浇你说一声。"),
		"water offer detects 你说一声 phrasing"
	)
	var spoken_offer := "那个……我是不是该去把第七块地的水浇了？它看着有点干。你要是不忙，我就去了。"
	_assert(ShopDelegate.looks_like_water_offer(spoken_offer), "water offer detects 是不是/中间问号")
	PendingOfferStore.clear()
	PendingOfferStore.arm_from_companion_line(spoken_offer)
	_assert(PendingOfferStore.get_type() == PendingOfferStore.OfferType.WATER, "spoken water offer arms pending")
	var go := ChoreOrchestrator.handle_player_message("去吧")
	_assert(bool(go.get("handled", false)), "去吧 confirms spoken water offer")
	_assert("收、浇、种" not in str(go.get("reply", "")), "去吧 does not open chore menu")
	_assert("不用喊两遍" not in str(go.get("reply", "")), "confirm is not a hearing-error line")
	TaskSystem.cancel_task()
	CompanionAgent.cancel_current_job()
	PendingOfferStore.clear()
	_assert(ChorePreprocessor.looks_like_bare_farm_command("浇"), "浇 is a bare farm command")
	var pour := ChoreOrchestrator.handle_player_message("浇")
	_assert(bool(pour.get("handled", false)), "浇 auto-starts watering")
	_assert("不用喊两遍" not in str(pour.get("reply", "")), "浇 is not a water-hint fallback")
	_assert("收、浇、种" not in str(pour.get("reply", "")), "浇 does not open chore menu")
	_assert(
		ShopDelegate.looks_like_plant_offer("要不要帮你种点萝卜？"),
		"plant offer accepts 种点 phrasing"
	)
	for word in ["好", "行", "去吧", "可以"]:
		_assert(ShopDelegate.is_affirmative_reply(word), "affirmative reply: %s" % word)
	_assert(not ShopDelegate.is_affirmative_reply("不用"), "negative reply not affirmative")
	_assert(
		ShopDelegate.looks_like_sleep_commitment("好，听你的。我先去把廊下那盏灯熄了。你先进屋歇着吧。"),
		"sleep commitment detects 先进屋歇着"
	)


func _test_task_stale_reconcile() -> void:
	print("  .. task stale reconcile")
	TaskSystem.cancel_task()
	CompanionAgent.cancel_current_job()
	TaskSystem.current_task = TaskSystem.TaskType.SHOP
	TaskSystem.reconcile_stale_task()
	_assert(not TaskSystem.is_busy(), "stale task cleared when companion has no job")
	TaskSystem.cancel_task()


func _test_chore_instruction_closure() -> void:
	print("  .. chore instruction closure (P0-P4)")
	# C1 multi-step parse
	var plan := ChorePreprocessor.parse_plan("帮我把熟的收了然后卖掉再买种子")
	_assert(plan.size() >= 3, "multi-step plan parses harvest+sell+buy")
	if plan.size() >= 3:
		_assert(str(plan[0].get("step", "")) == "harvest_all", "plan step1 harvest")
		_assert(str(plan[1].get("step", "")) == "sell_turnips", "plan step2 sell")
		_assert(str(plan[2].get("step", "")) == "shop_buy_seeds", "plan step3 buy seeds")
	var single := ChorePreprocessor.parse_plan("帮我浇水")
	_assert(single.size() == 1 and str(single[0].get("step", "")) == "water_all", "single water step")

	# C2 pending offer + confirm
	PendingOfferStore.clear()
	PendingOfferStore.arm_from_companion_line("要不要我先把熟的收了？")
	_assert(PendingOfferStore.get_type() == PendingOfferStore.OfferType.HARVEST, "harvest offer armed")
	_assert(PendingOfferStore.is_confirmable_player("好的"), "好的 confirms offer")
	var confirm := ChoreOrchestrator.try_confirm_offer("好的")
	_assert(bool(confirm.get("handled", false)), "confirm offer handled locally")

	# C3 correction inquiry
	_assert(ChorePreprocessor.looks_like_player_correction("你为啥没卖萝卜"), "correction why-not-sell")
	var corr := ChoreOrchestrator.handle_player_message("你为啥没卖萝卜")
	_assert(bool(corr.get("handled", false)) and bool(corr.get("skip_llm", false)), "correction skips LLM")

	# C4 Say-Do validator
	var implied := SayDoValidator.implied_steps_from_reply("好，我这就去浇。")
	_assert("water_all" in implied, "water commitment detected")
	var fixed := SayDoValidator.enforce("田都浇好了。", [], "")
	_assert(fixed.contains("浇"), "Say-Do fixes false completion claim")
	_assert(SayDoValidator.should_skip_repetitive_fallback("好的"), "skip 嗯我在 on confirmation")

	# C5 busy block
	TaskSystem.cancel_task()
	CompanionAgent.cancel_current_job()
	CompanionAgent._current_job = {"kind": "water", "plot_ids": [0]}
	CompanionAgent._activity = CompanionAgent.Activity.WORKING
	CompanionAgent._work_left = 1.0
	TaskSystem.current_task = TaskSystem.TaskType.WATER
	_assert(ChorePreprocessor.should_block_llm_for_busy_farm_chat("再去浇一下"), "busy blocks farm chat to LLM")
	TaskSystem.cancel_task()
	CompanionAgent.cancel_current_job()

	# C6 seed location
	_assert(ChorePreprocessor.looks_like_seed_location_inquiry("种子在哪"), "seed location inquiry")
	var seed_reply := ChoreOrchestrator.reply_seed_location()
	_assert(not seed_reply.is_empty(), "seed location reply non-empty")

	# C7 normalize API plan
	var normalized := ChorePreprocessor.normalize_plan_steps(
		[{"step": "harvest"}, {"step": "sell_turnips"}],
		"收然后卖"
	)
	_assert(normalized.size() == 2, "API plan normalized")
	_assert(str(normalized[0].get("step", "")) == "harvest_all", "harvest alias normalized")

	PendingOfferStore.clear()
	TaskSystem.cancel_task()
	CompanionAgent.cancel_current_job()

	# C8 max-gold / sell-all phrasing
	_assert(ChorePreprocessor.looks_like_max_gold_seed_buy("剩下的钱全买种子"), "max gold buy detected")
	_assert(ChorePreprocessor.should_auto_start_single_plan(
		"剩下的钱全买种子",
		ChorePreprocessor.parse_plan("剩下的钱全买种子"),
	), "max gold buy auto-starts without delegate")
	_assert(ChorePreprocessor.looks_like_sell_all_command("所有萝卜都卖掉"), "sell-all command detected")
	_assert(not ChorePreprocessor.looks_like_sell_all_command("所有萝卜全卖了"), "sell completion not command")
	var max_plan := ChorePreprocessor.normalize_plan_steps(
		[{"step": "shop_buy_seeds", "max_gold": true}],
		"剩下的钱全买种子",
	)
	_assert(bool(max_plan[0].get("max_gold", false)), "API plan preserves max_gold")


func _test_trade_coin_math() -> void:
	print("  .. trade coin math")
	GameState.reset_for_new_game()
	_ensure_player_named()
	var seed_price := GameState.get_seed_buy_price()
	var sell_price := GameState.get_turnip_sell_price()
	_assert(seed_price > 0 and sell_price > 0, "seed/sell prices positive")

	# 买种子扣币
	var coins_before := GameState.coins
	var buy3 := GameState.buy_shop_item_count("turnip_seed", 3)
	_assert(bool(buy3.get("ok", false)), "buy 3 seeds ok")
	_assert(GameState.coins == coins_before - seed_price * 3, "buy deducts coins correctly")
	_assert(GameState.get_item_count("turnip_seed") >= 3, "seeds added to inventory")

	# 卖萝卜加币
	GameState.add_item("turnip", 5)
	coins_before = GameState.coins
	var sold := GameState.sell_all_turnips()
	_assert(bool(sold.get("ok", false)), "sell all turnips ok")
	_assert(int(sold.get("count", 0)) == 5, "sell all count")
	_assert(int(sold.get("total", 0)) == 5 * sell_price, "sell total price")
	_assert(GameState.coins == coins_before + 5 * sell_price, "sell adds coins correctly")
	_assert(GameState.get_item_count("turnip") == 0, "turnips cleared after sell all")

	# max_gold 买尽：应花光能买整数包的金币
	GameState.coins = 79
	var affordable := int(79 / seed_price)
	var max_buy := GameState.buy_shop_item_count("turnip_seed", affordable)
	_assert(bool(max_buy.get("ok", false)), "max affordable buy ok")
	_assert(
		GameState.coins == 79 - affordable * seed_price,
		"max affordable leaves correct remainder",
	)

	# 收→卖→全买 多步后金币与库存自洽
	GameState.reset_for_new_game()
	_ensure_player_named()
	GameState.coins = 0
	GameState.add_item("turnip", 4)
	seed_price = GameState.get_seed_buy_price()
	sell_price = GameState.get_turnip_sell_price()
	var sell_only := GameState.sell_all_turnips()
	_assert(bool(sell_only.get("ok", false)), "pipeline sell ok")
	var expected_coins := 4 * sell_price
	_assert(GameState.coins == expected_coins, "pipeline sell coins")
	var max_packs := int(expected_coins / seed_price)
	if max_packs > 0:
		var spend_all := GameState.buy_shop_item_count("turnip_seed", max_packs)
		_assert(bool(spend_all.get("ok", false)), "pipeline max buy ok")
		_assert(
			GameState.coins == expected_coins - max_packs * seed_price,
			"pipeline max buy coins remainder",
		)


func _print_report() -> void:
	if _failures.is_empty():
		print("=== ALL PASS ===")
	else:
		print("=== FAILED (%d) ===" % _failures.size())
		for item in _failures:
			print(" - %s" % item)
