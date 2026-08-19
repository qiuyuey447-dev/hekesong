extends Node
## 回复校验：事实锁 + 记忆引用 + story_mode 边界（XL-C2～C3）。

const STORY_MODE_EVENTS := [
	"player_chat",
	"session_start",
	"task_complete",
	"story_beat",
]

const CHAT_LIKE_EVENTS := [
	"player_chat",
	"session_start",
	"companion_proactive",
	"companion_casual",
	"companion_react",
	"morning_sidewrite",
	"story_beat",
	"task_complete",
]

const L3_EPISODIC_PHRASES := [
	"上周",
	"上回",
	"那天",
	"记得那次",
	"我们以前",
	"你第一次",
	"还记得那次",
	"以前你",
]

const SUNNY_RAIN_PHRASES := [
	"等雨停",
	"等雨小",
	"雨还没停",
	"雨小了",
	"这雨停",
	"这雨下",
	"还在下雨",
	"正在下雨",
	"下雨了",
	"下起雨",
	"雨下得",
	"雨声",
	"雨打",
	"淋湿",
	"淋雨",
]

const LITERARY_PHRASES := [
	"雨帘",
	"隔着雾",
	"心里发紧",
	"模模糊糊",
	"毛玻璃",
	"像隔着",
	"隔着一层",
	"模糊的画面",
	"隔着雨",
	"薄雾",
	"脑子里的雾",
	"雾里的灯",
	"行情",
	"大盘",
	"售价",
]

var debug_disable_fact_lock := false


func validate(event: String, text: String, payload: Dictionary, cited_ids: Array = []) -> Dictionary:
	var cleaned := text.strip_edges()
	if cleaned == "":
		return {"ok": false, "reason": "empty"}

	if event != "companion_feed" and _mentions_forbidden_crop(cleaned):
		return {"ok": false, "reason": "wrong_crop"}

	if event in CHAT_LIKE_EVENTS and _is_literary_reply(cleaned):
		return {"ok": false, "reason": "literary"}

	if event in CHAT_LIKE_EVENTS and _is_awkward_waiting_reply(cleaned):
		return {"ok": false, "reason": "awkward_waiting"}

	if event in CHAT_LIKE_EVENTS and _violates_weather_facts(cleaned, payload):
		return {"ok": false, "reason": "weather_mismatch"}

	if event in CHAT_LIKE_EVENTS and _violates_chat_timing(cleaned, payload):
		return {"ok": false, "reason": "chat_timing"}

	if event in ["companion_proactive", "companion_casual", "morning_sidewrite"] and _is_action_mismatch_reply(cleaned, payload):
		return {"ok": false, "reason": "action_mismatch"}

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
		if _violates_l3_episodic_claim(cleaned, cited_ids, payload):
			return {"ok": false, "reason": "l3_episodic"}
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


func _violates_l3_episodic_claim(text: String, cited_ids: Array, payload: Dictionary) -> bool:
	if not cited_ids.is_empty():
		return false
	var memory_context: Dictionary = payload.get("memory_context", {})
	var story_mode := str(memory_context.get("story_mode", payload.get("story_mode", "")))
	if story_mode == "stranger":
		return false
	for phrase in L3_EPISODIC_PHRASES:
		if phrase in text:
			return true
	return _mentions_pref_as_fact(text, memory_context)


func _mentions_pref_as_fact(text: String, memory_context: Dictionary) -> bool:
	var prefs: Variant = memory_context.get("long_term_prefs", {})
	if prefs is not Dictionary or prefs.is_empty():
		return false
	if str(prefs.get("time_rhythm", "")) == "dusk":
		if ("傍晚" in text or "黄昏" in text) and ("总" in text or "习惯" in text or "一向" in text):
			return true
	if str(prefs.get("pace", "")) == "slow":
		if "慢慢来" in text and ("总" in text or "一直" in text or "老是" in text):
			return true
	if "最喜欢" in text and "萝卜" in text:
		return true
	return false


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


func _weather_code(payload: Dictionary) -> String:
	var code := str(payload.get("weather_today", "")).strip_edges()
	if code != "":
		return code
	var snap: Dictionary = payload.get("world_snapshot", {})
	if snap is Dictionary and snap.has("weather_today"):
		return str(snap.get("weather_today", "")).strip_edges()
	return GameState.weather_today


func _violates_weather_facts(text: String, payload: Dictionary) -> bool:
	if _weather_code(payload) != GameState.WEATHER_SUN:
		return false
	for phrase in SUNNY_RAIN_PHRASES:
		if phrase in text:
			return true
	if "雨停" in text and ("这" in text or "等" in text or "还没" in text):
		return true
	return false


func _game_day_from_payload(payload: Dictionary) -> int:
	var rel: Dictionary = payload.get("relationship", {})
	if rel is Dictionary and rel.has("game_day"):
		return int(rel.get("game_day", GameState.game_day))
	var timing: Dictionary = payload.get("chat_timing", {})
	if timing is Dictionary and timing.has("game_day"):
		return int(timing.get("game_day", GameState.game_day))
	return GameState.game_day


func _violates_chat_timing(text: String, payload: Dictionary) -> bool:
	var day := _game_day_from_payload(payload)
	if day <= 1 and "昨天" in text:
		return true
	if "昨天" not in text:
		return false
	var timing: Dictionary = payload.get("chat_timing", {})
	if not timing is Dictionary:
		timing = GameState.get_chat_timing_context_for_llm()
	var today_lines: Variant = timing.get("today_player_lines", [])
	if not today_lines is Array:
		return false
	for raw in today_lines:
		var line := str(raw).strip_edges()
		if line == "":
			continue
		if line in text:
			return true
		if line.length() >= 2 and line in text.replace("昨天", ""):
			return true
		for token in ["拜拜", "再见", "回见"]:
			if token in line and token in text:
				return true
	return false


func _is_literary_reply(text: String) -> bool:
	for phrase in LITERARY_PHRASES:
		if phrase in text:
			return true
	return false


func _is_awkward_waiting_reply(text: String) -> bool:
	for phrase in RelationshipDirector.get_awkward_waiting_phrases():
		if phrase in text:
			return true
	return false


func _is_action_mismatch_reply(text: String, payload: Dictionary) -> bool:
	for phrase in ["包种子", "手头有", "要种几", "种几块", "第二片叶", "第几片叶"]:
		if phrase in text:
			return true
	var snap: Dictionary = payload.get("world_snapshot", {})
	var companion: Dictionary = snap.get("companion", {}) if snap is Dictionary else {}
	var loc := str(companion.get("location_name", "")).strip_edges()
	var activity := str(companion.get("activity", "")).strip_edges()
	var places := ["商店", "萝卜田", "廊下", "旧屋门口", "树洞", "田埂", "空土垄", "河边", "小径"]
	for place in places:
		if loc != "" and place == loc:
			continue
		if loc == "旧屋门口" and place == "小径":
			continue
		if loc == "廊下" and place in ["旧屋门口", "小径"]:
			continue
		if ("我在" + place) in text or ("在" + place + "上") in text or ("在" + place + "边") in text:
			return true
	if activity in ["闲逛", "发呆", "待命"] and ("我去浇" in text or "我去种" in text or "我去收" in text):
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
