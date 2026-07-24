extends Node
## 主线导演：按周/日给出 story beat 与主动推进提示。

const WORLDVIEW_PATH := "res://config/worldview_setting.json"

var _worldview: Dictionary = {}


func _ready() -> void:
	_load_worldview()


func _load_worldview() -> void:
	if not FileAccess.file_exists(WORLDVIEW_PATH):
		return
	var file := FileAccess.open(WORLDVIEW_PATH, FileAccess.READ)
	if not file:
		return
	var parsed: Variant = JSON.parse_string(file.get_as_text())
	file.close()
	if typeof(parsed) == TYPE_DICTIONARY:
		_worldview = parsed


func get_worldview() -> Dictionary:
	return _worldview.duplicate(true)


func get_worldview_brief(mode: String = "") -> String:
	if _worldview.is_empty():
		return ""
	var briefs: Variant = _worldview.get("llm_brief", {})
	if typeof(briefs) != TYPE_DICTIONARY:
		return ""
	var lines: PackedStringArray = []
	var always := str(briefs.get("always", "")).strip_edges()
	if always != "":
		lines.append(always)
	if mode.is_empty():
		mode = get_story_mode()
	var mode_line := str(briefs.get(mode, "")).strip_edges()
	if mode_line != "":
		lines.append(mode_line)
	return "\n".join(lines)


func get_beat() -> Dictionary:
	var week := GameState.get_week_index()
	var day := GameState.get_loop_day()
	var beat_id := "w%d_d%d" % [week, day]
	var hint := ""
	var goal := ""
	var proactive := false
	var mode := get_story_mode()

	match week:
		1:
			match day:
				1:
					hint = "【不速之客】小狸刚出现，记忆完整；请求留下帮工，语气礼貌小心。"
					goal = "收留"
				2:
					hint = "【日常】雨天廊下；有屋顶、有田，像找到了该留下的地方。"
					goal = "建立日常"
				3:
					hint = "【日常】黄昏看玩家的田，学浇水的节奏；可主动搭话。"
					goal = "建立日常"
				4:
					hint = "【伏笔】小狸记错昨天是否浇过某块田；玩家可留意，不必点破。"
					goal = "失忆伏笔"
				5:
					hint = "【约定】傍晚可提萝卜将熟、一起看；写入本子；不要抢 task_complete 固定台词。"
					goal = "建立约定"
				6, 7:
					hint = "【两个人的家园】约定进行中、萝卜近熟；D7 预告 W2 可能不一样。"
					goal = "兑现约定"
		2:
			if day == 1:
				hint = "【陌生化】像不认识玩家，礼貌疏远；但对田与旧屋仍有说不清的安全感（隐藏记忆层，不可点破）。"
				goal = "W2 情感落差"
			else:
				hint = "【似曾相识】从陌生中慢慢浮出熟悉感；可隐约觉得「在这干过活」；仍不可直呼玩家名字。"
				goal = "隐藏记忆渗漏"
				proactive = day == 4
		3, 4:
			hint = "【两个人的家园】会突然断片、问「刚才说到哪」；引用玩家说过的话；玩家会耐心重新介绍。"
			goal = "记忆与偏好"
			proactive = day == 1
		5:
			hint = "【真相/觉醒】记忆连贯；温柔认出玩家与为何留下；主题「从未离开」；固定演出由 demo 保底，日常台词补充即可。"
			goal = "觉醒"
		_:
			if GameState.is_story_complete():
				hint = "五周的故事已经落幕。"
				goal = "完结"
			else:
				hint = "继续打理萝卜田和家园。"
				goal = "日常"

	return {
		"beat_id": beat_id,
		"week_index": week,
		"loop_day": day,
		"hint": hint,
		"goal": goal,
		"proactive": proactive,
		"revealed": GameState.has_revealed_memory(),
		"story_mode": mode,
	}


func get_story_mode() -> String:
	if GameState.has_revealed_memory():
		return "awaken"
	if GameState.is_awakening_day() and not GameState.has_seen_awakening():
		return "awaken"
	if GameState.get_week_index() == 2 and GameState.get_loop_day() == 1:
		return "stranger"
	if GameState.get_week_index() >= 3 and GameState.get_week_index() <= GameState.STORY_WEEKS:
		return "leak"
	return "normal"


func is_stranger_mode() -> bool:
	return get_story_mode() == "stranger"


func get_effective_stage() -> String:
	if get_story_mode() == "awaken":
		return "awaken"
	if is_stranger_mode():
		return GameState.STAGE_STRANGER
	return GameState.get_stage()


func get_story_hint() -> String:
	return str(get_beat().get("hint", ""))


func get_story_context_for_llm() -> Dictionary:
	var beat := get_beat()
	var route := StoryBeatDirector.get_active_route()
	var pending := StoryBeatDirector.get_pending_session_beat()
	var pending_brief := ""
	var pending_id := ""
	if not pending.is_empty():
		pending_id = str(pending.get("id", ""))
		var def := StoryRouteData.get_beat_def(pending_id)
		var node_label := str(def.get("node_label", pending_id))
		var emotion := str(def.get("emotion", ""))
		pending_brief = "%s（%s）" % [node_label, emotion] if emotion != "" else node_label

	var recent_story: Array[String] = []
	for raw in GameState.get_recent_memories(10):
		if not raw is Dictionary:
			continue
		if str(raw.get("kind", "")) != "story_beat":
			continue
		var line := str(raw.get("summary", "")).strip_edges()
		if line != "":
			recent_story.append(line)
		if recent_story.size() >= 3:
			break

	return {
		"game_day": GameState.game_day,
		"week_index": int(beat.get("week_index", GameState.get_week_index())),
		"loop_day": int(beat.get("loop_day", GameState.get_loop_day())),
		"beat_id": str(beat.get("beat_id", "")),
		"story_mode": str(beat.get("story_mode", get_story_mode())),
		"weekly_hint": str(beat.get("hint", "")),
		"weekly_goal": str(beat.get("goal", "")),
		"active_route": route,
		"route_label": StoryBeatDirector.get_route_label(route),
		"pending_beat_id": pending_id,
		"pending_beat_brief": pending_brief,
		"has_pending_beat": StoryBeatDirector.has_pending_today_beat(),
		"recent_story_beats": recent_story,
		"memory_revealed": GameState.has_revealed_memory(),
		"story_route_locked": GameState.get_story_route(),
		"player_name_context": GameState.get_player_name_context(),
		"narrative_constraints": _narrative_constraints(),
	}


func _narrative_constraints() -> Array[String]:
	var constraints: Array[String] = []
	var week := GameState.get_week_index()
	var mode := get_story_mode()
	var loop := GameState.get_loop_day()

	constraints.append("回复须符合当前周目与 story_mode，不可自相矛盾或提前剧透未解锁内容")

	if mode == "stranger":
		constraints.append("W2 陌生化：像不认识玩家，不说「又见面了」或具体共同回忆，不亲昵")
	elif mode == "leak":
		constraints.append("W3～W4：可隐约熟悉但仍会断片；引用记忆须克制，仍会问「刚才说到哪」")
	elif mode == "awaken":
		constraints.append("觉醒前后：记忆较连贯，可温柔认出玩家，主题「从未离开」，仍克制不油")
	elif week == 1:
		constraints.append("W1 序章：小狸记忆完整，礼貌请求留下帮工，对田与旧屋有归属感")

	if week == 2 and loop > 1 and mode != "stranger":
		constraints.append("W2 中后期：从陌生中渐生熟悉，仍不可过早直呼玩家名字")

	if not GameState.has_revealed_memory() and week < 5:
		constraints.append("D35 前禁止直说转世/灵魂/死去宠物/你是 AI")

	if not GameState.has_player_name_set():
		constraints.append("尚未向小狸告知称呼；被问起时不要编造名字或默认「玩家」")
	elif not GameState.companion_knows_player_name():
		constraints.append("W2 陌生化：你暂时想不起玩家叫什么；不要直呼其名，不要编造")
	elif not GameState.companion_can_say_player_name():
		constraints.append(
			"你记得玩家曾告诉过称呼，但此刻还叫不出口；不要直接喊名字，可说「你」"
		)
	elif GameState.companion_can_say_player_name():
		constraints.append("可自然称呼「%s」" % GameState.player_name)

	if bool(GameState.get_ending_flags().get("w2_chose_expel", false)):
		constraints.append("玩家曾选择赶她走：语气更疏，仍保留复杂情感，勿假装无事发生")

	constraints.append("禁止提及未实现的作物（本游戏仅萝卜田）")

	return constraints


func should_proactive_nudge() -> bool:
	return bool(get_beat().get("proactive", false))


func get_milestone_hint(milestone_id: String, facts: Dictionary = {}) -> String:
	match milestone_id:
		"affection_familiar":
			return "亲密度刚到「熟悉」阶段：更像一起过日子的伙伴，可主动分担田事，仍克制。"
		"affection_bond":
			return "亲密度刚到「羁绊」阶段：羁绊越深越愿为你多做一点；可引用共同经历，像家人。"
		_:
			if milestone_id.begins_with("trade_big_win"):
				return "玩家刚高价卖出萝卜（大赚）：替对方高兴，可提行情难得，不要像系统播报。"
			if milestone_id.begins_with("trade_big_loss"):
				return "玩家刚大手笔买种子后手头很紧（大亏/冒险）：安慰并鼓励，建议先把田照顾好，不要责备。"
	return get_story_hint()


func get_absence_hint(facts: Dictionary) -> String:
	var gap_hours := int(facts.get("gap_hours", facts.get("gap_days", 0) * 24))
	if gap_hours >= 168:
		return "玩家离开较久后回归：像重逢，表达惦记与安心，不要责备。"
	if gap_hours >= 48:
		return "玩家离开数天后回归：温和欢迎，可提你帮忙看了田，1～2 句。"
	if gap_hours >= 12:
		return "玩家离开半天以上后回归：简短欢迎，可提你帮忙看了院子。"
	return "玩家离开几小时后回归：像刚出去一趟回来，温暖自然，1～2 句。"
