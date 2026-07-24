extends Node


func _ready() -> void:
	add_to_group("demo_script")


func get_event_override(event: String, extra: Dictionary = {}) -> String:
	var week := GameState.get_week_index()
	var day := GameState.get_loop_day()
	match event:
		"session_start":
			return _session_start_override(week, day)
		"task_complete":
			return _task_complete_override(week, day, extra.get("game_facts", {}))
		"player_chat":
			return _player_chat_override(week, day, str(extra.get("player_message", "")))
		"companion_react":
			return _companion_react_override(week, day, str(extra.get("react_type", "")))
		_:
			return ""


func _session_start_override(week: int, day: int) -> String:
	if week == 1 and day == 1:
		return (
			"你好，我是小狸。我在外头漂泊很久了……"
			+ "听说这片萝卜田需要人帮手。我能留下吗？帮你干活，换一口安定就好。"
		)
	if week == 2 and day == 1 and not GameState.has_revealed_memory():
		GameState.mark_w2_stranger_seen()
		return "……你是谁？抱歉，我不记得了。我怎么会在这里？……这是你的农场吗？"
	if week == 2 and day == 2 and not GameState.has_revealed_memory():
		return "对不起……你的本子上好像记过我会来帮工。可我脑子里对不上。你能再告诉我一次吗？"
	if week == 5 and day == 1 and not GameState.has_revealed_memory():
		return "第五周了……我有时会梦见这片田，像是很久很久以前，又像是昨天。"
	if week == 5 and day == 7 and GameState.has_revealed_memory():
		return "我还记得那天。谢谢你一直没有赶我走。"
	if day == 7 and not GameState.has_revealed_memory() and week < 5:
		return "今天是这周的最后一天了。等忙完萝卜田，我们一起把这一周的事再看一遍吧。"
	return ""


func _task_complete_override(week: int, day: int, game_facts: Dictionary) -> String:
	var task := str(game_facts.get("task", ""))
	if week == 1 and day == 5 and task == "water" and GameState.long_term_memory.get("promise", {}).is_empty():
		GameState.set_promise("turnip_field", "等萝卜田长起来了，一起看看。")
		return "我想和你约好，等这片萝卜田长起来了，我们一起站在这里看看成果。"
	if week == 1 and day == 6 and task == "water":
		var promise: Dictionary = GameState.long_term_memory.get("promise", {})
		if not promise.is_empty() and not bool(promise.get("fulfilled", false)):
			GameState.fulfill_promise("我记得我们的约定，萝卜田快要长成了。")
			return "我记得我们的约定。再照看一天，萝卜田就能像你希望的那样长起来。"
	return ""


func _player_chat_override(week: int, day: int, text: String) -> String:
	if week == 2 and day == 1 and not GameState.has_revealed_memory():
		if "我是谁" in text or "不认识" in text or "记得我" in text:
			return "……你说我们见过？对不起，我脑子里有些画面，但拼不起来。"
		if "小狸" in text and ("认识" in text or "记得" in text or "一起" in text):
			return "你叫我的名字……好像是对的。可我还是想不起来，在这里做过什么。"
		if "农场" in text or "田" in text or "留下" in text:
			return "这片田……看着是熟悉的。好像有人让我在这帮过忙。但你说的是谁，我记不清了。"
	if week == 5 and day == 7 and not GameState.has_revealed_memory():
		if "记得" in text or "忘记" in text or "循环" in text:
			return "……嗯。好像有很重要的东西正在慢慢浮上来。谢谢你愿意等我。"
	return ""


func _companion_react_override(week: int, day: int, react_type: String) -> String:
	if week == 2 and day == 1 and react_type == "world_idle_long":
		return "……抱歉，我还在适应。你要是需要帮手，直接跟我说就好。"
	if react_type != "story_nudge":
		return ""
	if week == 1 and day == 7:
		return "今天是这周的最后一天了。等忙完萝卜田，我们一起把这一周的事再看一遍吧。"
	return ""


func get_leak_fallback(node_id: String) -> String:
	match node_id:
		"N07":
			return "这颜色……好像在哪里见过。等过很久，又像是昨天。"
		"N11":
			return "那个关于萝卜田的约定……我记不清是谁先说的，但听起来很熟。"
		"N14":
			return "你递萝卜给我的那个下午，好像发生过不止一次。"
		_:
			return ""
