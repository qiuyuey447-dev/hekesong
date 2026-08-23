extends Node
## 用和信纸同一套代码走一遍留下线，把玩家会读到的正文打出来。
## godot --headless --path <项目根> res://tools/gal_playthrough_dump.tscn


func _ready() -> void:
	call_deferred("_run")


func _run() -> void:
	print("=== GAL PLAYTHROUGH DUMP (keep / 留下) ===")
	GameState.reset_for_new_game()
	GameState.set_player_display_name("阿松")
	var prologue := ["P_N01", "P_N02", "P_N11", "P_N05", "P_N06p"]
	for i in range(prologue.size()):
		var day := i + 1
		GameState.game_day = day
		GameState.time_of_day = GameState.TIME_MORNING
		if day == 4:
			_print_block("D4 醒来 telegraph", StoryNodeCopy.get_morning("t10_d4_telegraph"))
		if day == 3:
			GameState.affection = 0
			GameState.time_of_day = GameState.TIME_EVENING
			var cold := StoryRouteData.render_body("P_N11", "P_N11_cold")
			print("FIX_COLD knife=%s smash=%s busy=%s aff=%d" % [
				"这一句我不想拿它赖掉" in cold,
				"拿这个砸我" in cold,
				"你忙你的" in cold,
				GameState.affection,
			])
			_print_block("D3 cold 模板", cold)
		await _dump_today("D%d 序章" % day)
		var beat_id: String = prologue[i]
		StoryBeatDirector.complete_beat(beat_id)
		if beat_id == "P_N06p":
			GameState.mark_w2_keep_choice()
			StoryBeatDirector.refresh_story_route()
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
		GameState.time_of_day = GameState.TIME_MORNING
		StoryBeatDirector.refresh_story_route()
		StoryBeatDirector.ensure_story_route_locked()
		var beat_id := StoryBeatDirector.get_today_beat_id()
		await _dump_today("D%d 留下线" % day)
		if day == 7:
			GameState.mark_companion_choice(true)
			PlayerNotebookService.on_first_write_d7()
		StoryBeatDirector.complete_beat(beat_id)
		GameState.append_day_journal({
			"day": day,
			"week_index": 1,
			"loop_day": day,
			"summary": "第 %d 天：阿松和小狸一起浇了田" % day,
			"highlights": ["主线 · %s" % beat_id, "聊天 · 廊下听雨"],
		})
	GameState.game_day = 10
	var ending := EndingDirector.resolve_ending(false)
	print("\n===== D10 觉醒 ending=%s =====" % ending)
	var steps := EndingDirector.get_d35_awakening_steps(ending)
	for i in range(steps.size()):
		var step: Dictionary = steps[i]
		_print_block("觉醒 %d · %s" % [i + 1, str(step.get("title", ""))], str(step.get("body", "")))
	print("\n=== DUMP DONE ===")
	get_tree().quit(0)


func _dump_today(tag: String) -> void:
	var beat := StoryBeatDirector.get_pending_session_beat(false)
	if beat.is_empty():
		print("\n===== %s (无 pending beat) =====" % tag)
		return
	beat = StoryBeatDirector.take_displayable_beat(beat)
	if beat.is_empty():
		print("\n===== %s (period_gate 把清晨切空了) =====" % tag)
		return
	beat = await StoryBeatDirector.prepare_beat_for_display(beat)
	_print_beat(tag + " · 清晨", beat)
	GameState.time_of_day = GameState.TIME_NIGHT
	var tail := StoryBeatDirector.build_beat_tail_resume()
	if not tail.is_empty():
		tail = await StoryBeatDirector.prepare_beat_for_display(tail)
		_print_beat(tag + " · 夜里续", tail)


func _print_beat(tag: String, beat: Dictionary) -> void:
	print("\n===== %s | id=%s variant=%s =====" % [
		tag,
		str(beat.get("id", "")),
		str(beat.get("variant_id", "")),
	])
	var steps: Array = beat.get("steps", [])
	for i in range(steps.size()):
		if not steps[i] is Dictionary:
			continue
		var step: Dictionary = steps[i]
		var title := str(step.get("title", "")).strip_edges()
		var body := str(step.get("body", "")).strip_edges()
		var kind := str(step.get("kind", "")).strip_edges()
		var head := "页%d" % (i + 1)
		if title != "":
			head += " · " + title
		if kind != "":
			head += " [%s]" % kind
		_print_block(head, body)
		var choices: Variant = step.get("choices", [])
		if choices is Array and not choices.is_empty():
			for raw in choices:
				if raw is Dictionary:
					print("  选项 %s：%s" % [str(raw.get("id", "")), str(raw.get("label", ""))])


func _print_block(head: String, body: String) -> void:
	print("--- %s ---" % head)
	if body.strip_edges() == "":
		print("(空)")
		return
	print(body)
