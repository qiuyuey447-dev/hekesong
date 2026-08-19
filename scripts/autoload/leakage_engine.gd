extends Node
## 记忆渗漏引擎（XL-D7 / XL-F3 / XL-F4）：锚点与节点台词 resurfacing。

const MIN_WEEK := 3
const FEED_LEAK_MIN_WEEK := 2

const NODE_N07 := "N07"
const NODE_N11 := "N11"
const NODE_N14 := "N14"

const FAV_LEAK_TREATS := {
	"carrot": true,
	"pumpkin_snack": true,
}


func try_daily_leak() -> String:
	## 未点名渗漏：十日版仅 D6–D8；一句真记忆，不编造。
	var ctx := peek_leak_context()
	if ctx.is_empty():
		return ""
	var line := str(ctx.get("fallback_line", "")).strip_edges()
	commit_leak_from_context(ctx)
	if line != "":
		GameState.record_initiation("leak_session", {
			"node": str(ctx.get("node_id", "")),
		}, line)
	return line


func peek_leak_context() -> Dictionary:
	## 只读：给大模型用这个玩家的真锚点，不消耗漏句。
	if GameState.IS_TEN_DAY_EDITION:
		if GameState.game_day < 6 or GameState.game_day > 8:
			return {}
	if not _can_leak():
		return {}
	if GameState.IS_TEN_DAY_EDITION:
		for nid in [NODE_N11, NODE_N14, NODE_N07]:
			if GameState.has_leak_seen(nid):
				continue
			var node_anchor := _pick_anchor_for_node(nid)
			if not node_anchor.is_empty():
				return _pack_leak_context(node_anchor, nid)
		var general := _pick_anchor()
		if not general.is_empty():
			return _pack_leak_context(general, "")
		return {}

	var week := GameState.get_week_index()
	var day := GameState.get_loop_day()
	if week == 3 and day >= 3 and not GameState.has_leak_seen(NODE_N11):
		var n11 := _pick_anchor_for_node(NODE_N11)
		if not n11.is_empty():
			return _pack_leak_context(n11, NODE_N11)
	if week >= 4 and day >= 2 and not GameState.has_leak_seen(NODE_N14):
		var n14 := _pick_anchor_for_node(NODE_N14)
		if not n14.is_empty():
			return _pack_leak_context(n14, NODE_N14)
	var anchor := _pick_anchor()
	if not anchor.is_empty():
		return _pack_leak_context(anchor, "")
	return _pack_prefs_context()


func commit_leak_from_context(ctx: Dictionary) -> void:
	if ctx.is_empty():
		return
	var node_id := str(ctx.get("node_id", "")).strip_edges()
	if node_id != "" and not GameState.has_leak_seen(node_id):
		GameState.mark_leak_seen(node_id)


func _pack_leak_context(anchor: Dictionary, node_id: String) -> Dictionary:
	var summary := str(anchor.get("summary", "")).strip_edges()
	if summary == "" and node_id != "" and not GameState.IS_TEN_DAY_EDITION:
		summary = _demo_leak_fallback(node_id)
	if summary == "":
		return {}
	return {
		"available": true,
		"node_id": node_id,
		"anchor_id": str(anchor.get("id", "")),
		"anchor_summary": summary,
		"anchor_kind": str(anchor.get("kind", "")),
		"fallback_line": _format_anchor_leak(anchor, node_id, "session") if node_id != "" else _wrap_anchor_summary(summary, "session"),
	}


func _pack_prefs_context() -> Dictionary:
	if GameState.IS_TEN_DAY_EDITION:
		return {}
	var prefs: Dictionary = GameState.long_term_memory.get("prefs", {})
	var rhythm := str(prefs.get("time_rhythm", "")).strip_edges()
	var fav := str(prefs.get("fav_crop", "")).strip_edges()
	var summary := _fallback_from_prefs(GameState.get_week_index()).strip_edges()
	if summary == "" and rhythm == "" and fav == "":
		return {}
	return {
		"available": true,
		"node_id": "",
		"anchor_id": "",
		"anchor_summary": summary,
		"anchor_kind": "pref",
		"time_rhythm": rhythm,
		"fav_crop": fav,
		"fallback_line": summary,
	}


func try_session_leak() -> String:
	if not _can_leak():
		return ""
	if GameState.IS_TEN_DAY_EDITION:
		return try_leak_line("session")
	var week := GameState.get_week_index()
	var day := GameState.get_loop_day()
	if week == 3 and day >= 3:
		var n11 := try_node_leak(NODE_N11, "session")
		if n11 != "":
			return n11
	if week >= 4 and day >= 2:
		var n14 := try_node_leak(NODE_N14, "session")
		if n14 != "":
			return n14
	return try_leak_line("session")


func try_feed_leak(item_id: String) -> String:
	if StoryDirector.is_stranger_mode() or GameState.has_revealed_memory():
		return ""
	if GameState.get_week_index() < FEED_LEAK_MIN_WEEK:
		return ""
	if GameState.has_leak_seen(NODE_N07):
		return ""
	if not _treat_triggers_fav_leak(item_id):
		return ""

	var anchor := _pick_anchor_for_node(NODE_N07)
	var line := ""
	if not anchor.is_empty():
		line = _format_anchor_leak(anchor, NODE_N07, "react")
	if line == "" and not GameState.IS_TEN_DAY_EDITION:
		line = _demo_leak_fallback(NODE_N07)
		if line == "":
			line = "这颜色……好像在哪里见过。等过很久，又像是昨天。"
	if line == "":
		return ""

	GameState.mark_leak_seen(NODE_N07)
	GameState.record_initiation("leak_feed", {"node": NODE_N07, "item_id": item_id}, line)
	return line


func try_node_leak(node_id: String, context: String = "session") -> String:
	if not _can_leak():
		return ""
	if GameState.has_leak_seen(node_id):
		return ""

	var anchor := _pick_anchor_for_node(node_id)
	var line := ""
	if not anchor.is_empty():
		line = _format_anchor_leak(anchor, node_id, context)
	if line == "" and not GameState.IS_TEN_DAY_EDITION:
		line = _demo_leak_fallback(node_id)
	if line == "":
		return ""

	GameState.mark_leak_seen(node_id)
	GameState.record_initiation("leak_node", {"node": node_id, "context": context}, line)
	return line


func try_leak_line(context: String = "session") -> String:
	if not _can_leak():
		return ""

	var anchor := _pick_anchor()
	if anchor.is_empty():
		if GameState.IS_TEN_DAY_EDITION:
			return ""
		return _fallback_from_prefs(GameState.get_week_index())

	var summary := str(anchor.get("summary", "")).strip_edges()
	if summary == "":
		return ""

	return _wrap_anchor_summary(summary, context)


func try_leak_for_react(react_type: String) -> String:
	if react_type not in ["story_nudge", "world_evening", "world_idle_long"]:
		return ""
	if randf() > _leak_chance():
		return ""
	if GameState.IS_TEN_DAY_EDITION:
		return try_leak_line("react")
	var week := GameState.get_week_index()
	if week >= 4 and randf() < 0.5:
		var n14 := try_node_leak(NODE_N14, "react")
		if n14 != "":
			return n14
	if week >= 3 and randf() < 0.45:
		var n11 := try_node_leak(NODE_N11, "react")
		if n11 != "":
			return n11
	return try_leak_line("react")


func _can_leak() -> bool:
	if GameState.IS_TEN_DAY_EDITION:
		if GameState.game_day < 6:
			return false
	elif GameState.get_week_index() < MIN_WEEK:
		return false
	if GameState.has_revealed_memory():
		return false
	if StoryDirector.is_stranger_mode():
		return false
	return true


func _treat_triggers_fav_leak(item_id: String) -> bool:
	if not bool(FAV_LEAK_TREATS.get(item_id, false)):
		return false
	var fav := str(GameState.long_term_memory.get("prefs", {}).get("fav_crop", ""))
	return fav == "" or fav == GameState.CROP_TURNIP


func _pick_anchor_for_node(node_id: String) -> Dictionary:
	var best: Dictionary = {}
	var best_score := -1.0
	for entry in _all_memory_entries():
		if not entry is Dictionary:
			continue
		var item: Dictionary = entry
		if str(item.get("kind", "")) == "promise_done":
			continue
		var score := _node_match_score(item, node_id)
		if score > best_score:
			best_score = score
			best = item
	if best_score <= 0.0:
		return {}
	return best


func _all_memory_entries() -> Array:
	var combined: Array = []
	combined.append_array(GameState.long_term_memory.get("anchors", []))
	for entry in GameState.short_term_memory:
		combined.append(entry)
	if GameState.IS_TEN_DAY_EDITION:
		combined.append_array(_journal_memory_entries())
		var promise := _promise_memory_entry()
		if not promise.is_empty():
			combined.append(promise)
	return combined


func _journal_memory_entries() -> Array[Dictionary]:
	var entries: Array[Dictionary] = []
	for entry in GameState.day_journal:
		if not entry is Dictionary:
			continue
		var highlights: Variant = entry.get("highlights", [])
		if highlights is Array:
			for highlight in highlights:
				var summary := str(highlight).strip_edges()
				if summary == "":
					continue
				entries.append({
					"id": "journal_%d_%d" % [int(entry.get("day", 0)), entries.size()],
					"kind": "journal_chat",
					"summary": summary,
					"importance": 0.72,
					"facts": {"source": "day_journal"},
				})
		var summary := str(entry.get("summary", "")).strip_edges()
		if summary != "":
			entries.append({
				"id": "journal_summary_%d" % int(entry.get("day", 0)),
				"kind": "day_end",
				"summary": summary,
				"importance": 0.68,
				"facts": {"source": "day_journal"},
			})
	return entries


func _promise_memory_entry() -> Dictionary:
	if not GameState.has_story_promise():
		return {}
	var promise: Dictionary = GameState.long_term_memory.get("promise", {})
	var summary := str(promise.get("summary", "")).strip_edges()
	if summary == "":
		return {}
	return {
		"id": "promise",
		"kind": "promise",
		"summary": summary,
		"importance": 0.95,
		"facts": {"promise_id": str(promise.get("id", ""))},
	}


func _node_match_score(entry: Dictionary, node_id: String) -> float:
	var facts: Dictionary = entry.get("facts", {})
	if str(facts.get("node", "")) == node_id:
		return float(entry.get("importance", 0.5)) + 0.35
	var kind := str(entry.get("kind", ""))
	match node_id:
		NODE_N11:
			if kind in ["promise", "promise_done"]:
				return float(entry.get("importance", 0.5)) + 0.2
		NODE_N14:
			if kind in ["harvest", "gift", "journal_chat", "day_end"]:
				return float(entry.get("importance", 0.5)) + 0.15
		NODE_N07:
			if kind in ["gift", "journal_chat"]:
				return float(entry.get("importance", 0.5)) + 0.1
	return -1.0


func _format_anchor_leak(anchor: Dictionary, node_id: String, context: String) -> String:
	var summary := str(anchor.get("summary", "")).strip_edges()
	if summary == "":
		if GameState.IS_TEN_DAY_EDITION:
			return ""
		return _demo_leak_fallback(node_id)
	match node_id:
		NODE_N11:
			return "关于「%s」……我记不清全部细节，但觉得很熟。" % summary
		NODE_N14:
			return "看着现在的田，我想起%s。" % summary
		NODE_N07:
			return "这颜色……让我想起%s。" % summary
		_:
			return _wrap_anchor_summary(summary, context)


func _wrap_anchor_summary(summary: String, context: String) -> String:
	match context:
		"session":
			return "不知道为什么，%s 这个画面突然冒了出来。" % summary
		"chat":
			return "你刚才说的，让我想起了：%s" % summary
		"react":
			return "看着现在的田，我想起%s。" % summary
		_:
			return "我记得%s。" % summary


func _leak_chance() -> float:
	var week := GameState.get_week_index()
	if week >= 5:
		return 0.45
	if week >= 4:
		return 0.35
	return 0.25


func _pick_anchor() -> Dictionary:
	var best: Dictionary = {}
	var best_score := -1.0
	for entry in _all_memory_entries():
		if not entry is Dictionary:
			continue
		var item: Dictionary = entry
		if str(item.get("kind", "")) == "promise_done":
			continue
		var summary := str(item.get("summary", "")).strip_edges()
		if summary == "":
			continue
		var score := float(item.get("importance", 0.5))
		if score > best_score:
			best_score = score
			best = item
	return best


func _fallback_from_prefs(week: int) -> String:
	var prefs: Dictionary = GameState.long_term_memory.get("prefs", {})
	var rhythm := str(prefs.get("time_rhythm", ""))
	if week >= 3 and rhythm == "dusk":
		return "你总是在傍晚来，我慢慢也习惯在这个点等你了。"
	var fav := str(prefs.get("fav_crop", ""))
	if week >= 4 and fav == GameState.CROP_TURNIP:
		return "你总盯着萝卜田看，好像那不只是作物，更像某种安心。"
	return ""


func _demo_leak_fallback(node_id: String) -> String:
	var tree := Engine.get_main_loop()
	if tree is SceneTree:
		var demo := (tree as SceneTree).get_first_node_in_group("demo_script")
		if demo != null and demo.has_method("get_leak_fallback"):
			return str(demo.get_leak_fallback(node_id)).strip_edges()
	match node_id:
		NODE_N07:
			return "这颜色……好像在哪里见过。等过很久，又像是昨天。"
		NODE_N11:
			return "那个关于萝卜田的约定……我记不清是谁先说的，但听起来很熟。"
		NODE_N14:
			return "你把萝卜递给我的那个下午，好像发生过不止一次。"
		_:
			return ""
