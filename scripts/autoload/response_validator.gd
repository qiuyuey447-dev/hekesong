extends Node
## 回复校验：事实锁 + 记忆引用 + story_mode 边界（XL-C2～C3）。

const STORY_MODE_EVENTS := [
	"player_chat",
	"session_start",
	"task_complete",
	"story_beat",
]

var debug_disable_fact_lock := false


func validate(event: String, text: String, payload: Dictionary, cited_ids: Array = []) -> Dictionary:
	var cleaned := text.strip_edges()
	if cleaned == "":
		return {"ok": false, "reason": "empty"}

	if event != "companion_feed" and _mentions_forbidden_crop(cleaned):
		return {"ok": false, "reason": "wrong_crop"}

	if debug_disable_fact_lock:
		return {"ok": true, "text": cleaned}

	var facts: Dictionary = payload.get("game_facts", {})
	if event == "task_complete" and not _passes_task_fact_lock(cleaned, facts):
		return {"ok": false, "reason": "fact_lock"}

	if event == "companion_feed":
		if _is_bland_feed_reply(cleaned):
			return {"ok": false, "reason": "bland_feed"}
		if _is_off_topic_feed_reply(cleaned, payload):
			return {"ok": false, "reason": "off_topic_feed"}
		var previous: Array = payload.get("previous_feed_replies", [])
		for line in previous:
			if str(line).strip_edges() == cleaned:
				return {"ok": false, "reason": "duplicate_feed"}
		if bool(payload.get("refused", false)):
			for phrase in ["好好吃", "真好吃", "太好吃"]:
				if phrase in cleaned:
					return {"ok": false, "reason": "refuse_tone_mismatch"}

	if event == "player_chat":
		var citation := _validate_chat_citations(cited_ids, payload)
		if not bool(citation.get("ok", true)):
			return citation
		if _is_internal_metadata_reply(cleaned):
			return {"ok": false, "reason": "metadata_leak"}

	if event in STORY_MODE_EVENTS:
		var mode_check := _validate_story_mode_reply(cleaned, payload)
		if not bool(mode_check.get("ok", true)):
			return mode_check

	return {"ok": true, "text": cleaned}


func is_stranger_ooc_reply(text: String, payload: Dictionary) -> bool:
	var memory_context: Dictionary = payload.get("memory_context", {})
	var boundaries: Dictionary = memory_context.get("story_boundaries", {})
	if boundaries.is_empty():
		boundaries = MemoryService.get_story_boundaries()
	var story_mode := str(boundaries.get("story_mode", payload.get("story_mode", "")))
	if story_mode != "stranger":
		return false
	return not bool(_validate_story_mode_reply(text, payload).get("ok", true))


func _validate_chat_citations(cited_ids: Array, payload: Dictionary) -> Dictionary:
	if cited_ids.is_empty():
		return {"ok": true, "text": ""}
	var memory_context: Dictionary = payload.get("memory_context", {})
	var story_mode := str(memory_context.get("story_mode", payload.get("story_mode", "")))
	var result := MemoryService.validate_citations(cited_ids, story_mode)
	if bool(result.get("ok", false)):
		return {"ok": true, "text": ""}
	return {"ok": false, "reason": "bad_citation", "invalid_ids": result.get("invalid_ids", [])}


func _validate_story_mode_reply(text: String, payload: Dictionary) -> Dictionary:
	var memory_context: Dictionary = payload.get("memory_context", {})
	var boundaries: Dictionary = memory_context.get("story_boundaries", {})
	if boundaries.is_empty():
		boundaries = MemoryService.get_story_boundaries()
	var story_mode := str(boundaries.get("story_mode", payload.get("story_mode", "")))
	var player_name := str(payload.get("player_name", "")).strip_edges()

	if story_mode == "stranger":
		if player_name != "" and player_name in text:
			return {"ok": false, "reason": "stranger_name"}
		for phrase in RelationshipDirector.get_stranger_ooc_phrases():
			if phrase in text:
				return {"ok": false, "reason": "stranger_ooc"}
		for phrase in RelationshipDirector.get_stranger_intimate_phrases():
			if phrase in text:
				return {"ok": false, "reason": "stranger_intimate"}

	if not bool(boundaries.get("can_use_player_name", true)) and player_name != "" and player_name in text:
		return {"ok": false, "reason": "name_locked"}

	return {"ok": true, "text": ""}


func _mentions_forbidden_crop(text: String) -> bool:
	for crop_name in ["向日葵", "番茄", "蓝莓", "小麦", "玉米", "南瓜"]:
		if crop_name in text:
			return true
	return false


func _is_internal_metadata_reply(text: String) -> bool:
	var lower := text.to_lower()
	var markers := ["intent:", "plot_id:", "confidence:"]
	var hits := 0
	for marker in markers:
		if marker in lower:
			hits += 1
	return hits >= 2


func _passes_task_fact_lock(text: String, facts: Dictionary) -> bool:
	var task := str(facts.get("task", ""))
	match task:
		"water":
			return ("浇" in text) or ("田" in text)
		_:
			return true


func _is_bland_feed_reply(text: String) -> bool:
	if text.length() < 4:
		return true
	var bland := [
		"可以", "好的", "好", "嗯", "好好吃", "谢谢你", "谢谢", "收到", "知道了",
	]
	for phrase in bland:
		if text == phrase or text == phrase + "。" or text == phrase + "～":
			return true
	return false


func _is_off_topic_feed_reply(text: String, payload: Dictionary) -> bool:
	var refused := bool(payload.get("refused", false))
	var off_topic := [
		"我叫", "住下", "要试试看", "帮手", "刚上线", "打招呼", "你来了", "欢迎回来",
		"浇水", "看田", "田里", "跑腿", "旧屋", "清晨的阳光", "帮你看看田",
		"要不要我帮", "萝卜田", "行情", "种子", "熟悉", "初次见面",
	]
	for phrase in off_topic:
		if phrase in text:
			return true
	if refused:
		return not is_valid_feed_refuse_reply(text)
	var feed_item: Dictionary = payload.get("feed_item", {})
	var item_name := str(feed_item.get("name", "")).strip_edges()
	if item_name != "" and item_name in text:
		return false
	var food_markers := [
		"吃", "咬", "嚼", "舔", "尝", "味", "香", "甜", "酸", "脆", "软", "糯", "嘴", "零嘴", "零食", "满足",
	]
	for marker in food_markers:
		if marker in text:
			return false
	return true


func is_valid_feed_refuse_reply(text: String) -> bool:
	if text.length() < 4:
		return false
	var accept_markers := ["好好吃", "真好吃", "太好吃", "咬下去", "收下了", "谢谢你"]
	for phrase in accept_markers:
		if phrase in text:
			return false
	var refuse_markers := [
		"饱", "够", "吃不下", "明天", "留", "上限", "心意", "先收", "不能再",
		"打饱嗝", "刚吃过", "已经吃", "一份", "到限", "放过",
	]
	for phrase in refuse_markers:
		if phrase in text:
			return true
	return false


func is_off_topic_feed_reply(text: String, payload: Dictionary) -> bool:
	return _is_off_topic_feed_reply(text, payload)


func set_debug_disable_fact_lock(disabled: bool) -> void:
	debug_disable_fact_lock = disabled
