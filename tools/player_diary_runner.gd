extends Node

const PLAYER_NAME := "阿松"


func _ready() -> void:
	call_deferred("_run")


func _run() -> void:
	print("=== PLAYER DIARY (keep path · 阿松 · 会聊天会种田) ===\n")
	GameState.reset_for_new_game()
	GameState.set_player_display_name(PLAYER_NAME)
	_play_day(1)
	_add_day_engagement(1)
	_sleep_to(2)
	_play_day(2)
	_add_day_engagement(2)
	_sleep_to(3)
	_play_day(3)
	_add_day_engagement(3)
	_sleep_to(4)
	_play_day(4)
	_add_day_engagement(4)
	_sleep_to(5)
	_play_day(5)
	_mark_keep()
	_add_day_engagement(5)
	_sleep_to(6)
	_play_day(6)
	_add_day_engagement(6)
	_sleep_to(7)
	_play_day(7)
	GameState.mark_companion_choice(true)
	_add_day_engagement(7)
	_sleep_to(8)
	_play_day(8)
	_add_day_engagement(8)
	_sleep_to(9)
	_play_day(9)
	_add_day_engagement(9)
	_sleep_to(10)
	_play_day(10)
	print("\n=== END DIARY ===")
	get_tree().quit(0)


func _sleep_to(day: int) -> void:
	while GameState.game_day < day:
		print("\n--- [玩家] 说「先睡吧」，进下一天 ---")
		if GameState.game_day == 4:
			print("[系统] D4 过天：应出现「知道了」信任确认屏（day_cycle_overlay）")
		GameState.advance_day()


func _play_day(day: int) -> void:
	GameState.game_day = day
	print("\n######## 第 %d 天 ########" % day)
	print("[HUD] %s · %s" % [GameState.get_weather_label(), GameState.get_time_label()])
	var beat_id := StoryBeatDirector.get_today_beat_id()
	if beat_id == "" and day == 10:
		beat_id = "AWAKENING"
	if beat_id == "":
		print("[今日] 无日历主节点（纯日常 / 终章入口）")
		return
	print("[今日主节点] %s" % beat_id)
	var morning := StoryRouteData.render_morning_opening(false, beat_id)
	if morning.strip_edges() != "":
		print("\n《清晨》\n%s" % morning.strip_edges())
	var body := StoryRouteData.render_body(beat_id, beat_id)
	if body.strip_edges() != "":
		print("\n《信纸》\n%s" % body.strip_edges())
	if day <= 3:
		print("\n[玩家] 在底下输入框聊了几句，小狸回得挺像人。")
	if day == 2:
		print("[玩家] 下雨，没浇田。在廊下躲雨，地图东头主街很好认。")
	if day == 3:
		print("[玩家] 跟着她浇了会儿田。约定写进本子了。")
	if day == 4:
		print("[玩家] 读完「你是谁」愣了。想起 D3 她说会糊掉名字——不是 bug。")
	if day == 5:
		print("[玩家] 翻开树洞边的本子，选「留下她，再教一遍」。")
		return
	if day == 7:
		print("[玩家] 夜选：过去坐下（树洞）。")
	if day == 10:
		var ending := EndingDirector.resolve_ending(false)
		print("\n[终章] 结局倾向: %s" % ending)
		var steps := EndingDirector.get_awakening_steps(ending)
		for i in range(mini(steps.size(), 2)):
			var s: Dictionary = steps[i]
			print("《觉醒·%s》\n%s" % [str(s.get("title", "")), str(s.get("body", "")).substr(0, 400)])
	if beat_id != "AWAKENING":
		StoryBeatDirector.complete_beat(beat_id)


func _add_day_engagement(day: int) -> void:
	GameState.add_affection(12)
	GameState.bond = mini(GameState.bond + 8, 100)
	GameState.record_memory_event(
		"player_chat",
		"第 %d 天聊过几句" % day,
		0.72,
		{"game_day": day}
	)
	if day >= 3:
		GameState.long_term_memory["memory_recovery"] = clampf(
			float(GameState.long_term_memory.get("memory_recovery", 0.0)) + 0.08,
			0.0, 1.0
		)
	StoryBeatDirector.refresh_story_route()


func _mark_keep() -> void:
	var beat_id := StoryBeatDirector.get_today_beat_id()
	if beat_id != "":
		StoryBeatDirector.complete_beat(beat_id)
	GameState.mark_w2_keep_choice()
	StoryBeatDirector.refresh_story_route()
	GameState.set_promise("turnip_field", "等萝卜长好了，一起看看。")
