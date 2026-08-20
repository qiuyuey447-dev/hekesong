extends Node
## 回复校验：事实锁 + 记忆引用 + story_mode 边界（XL-C2～C3）。

const STORY_MODE_EVENTS := [
	"player_chat",
	"session_start",
	"task_complete",
	"story_beat",
	"companion_proactive",
	"companion_casual",
	"companion_react",
	"morning_sidewrite",
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

const RAIN_SUNNY_PHRASES := [
	"天晴",
	"出太阳",
	"晒太阳",
	"大晴天",
	"艳阳",
	"天气很好",
	"天气不错",
	"天气真好",
	"今天不下雨",
	"没下雨",
	"不会下雨",
	"水汽还没干",
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
	"心里发紧",
	"行情",
	"大盘",
	"售价",
]

const STRANGER_ALLOWED_FOG_PHRASES := [
	"隔着雾",
	"模模糊糊",
	"毛玻璃",
	"像隔着",
	"隔着一层",
	"模糊的画面",
	"隔着雨",
	"薄雾",
	"脑子里的雾",
	"雾里的灯",
]

var debug_disable_fact_lock := false


func strip_stage_directions(text: String) -> String:
	## 聊天框只显示「说出口的话」，去掉 LLM 误写的括号舞台说明。
	var cleaned := text.strip_edges()
	if cleaned == "":
		return cleaned
	var re := RegEx.new()
	if re.compile("\\([^\\)]{2,120}\\)") == OK:
		cleaned = re.sub(cleaned, "", true)
	re = RegEx.new()
	if re.compile("（[^）]{2,120}）") == OK:
		cleaned = re.sub(cleaned, "", true)
	while "\n\n\n" in cleaned:
		cleaned = cleaned.replace("\n\n\n", "\n\n")
	while "  " in cleaned:
		cleaned = cleaned.replace("  ", " ")
	return cleaned.strip_edges()


func validate(event: String, text: String, payload: Dictionary, cited_ids: Array = []) -> Dictionary:
	var cleaned := strip_stage_directions(text.strip_edges())
	if cleaned == "":
		return {"ok": false, "reason": "empty"}

	if event != "companion_feed" and _mentions_forbidden_crop(cleaned):
		return {"ok": false, "reason": "wrong_crop"}

	if event in CHAT_LIKE_EVENTS and _is_literary_reply(cleaned, payload):
		return {"ok": false, "reason": "literary"}

	if event in CHAT_LIKE_EVENTS and _is_awkward_waiting_reply(cleaned):
		return {"ok": false, "reason": "awkward_waiting"}

	if event in CHAT_LIKE_EVENTS and _violates_weather_facts(cleaned, payload):
		return {"ok": false, "reason": "weather_mismatch"}

	if event in CHAT_LIKE_EVENTS and _violates_chat_timing(cleaned, payload):
		return {"ok": false, "reason": "chat_timing"}

	if event in CHAT_LIKE_EVENTS and _is_repetitive_chat_reply(cleaned, payload):
		return {"ok": false, "reason": "repetitive"}

	if event in CHAT_LIKE_EVENTS and _violates_harvest_capability(cleaned, payload):
		return {"ok": false, "reason": "harvest_capability"}

	if event in CHAT_LIKE_EVENTS and _mentions_premature_promise(cleaned):
		return {"ok": false, "reason": "premature_promise"}

	if event in CHAT_LIKE_EVENTS and _leaks_director_meta(cleaned):
		return {"ok": false, "reason": "director_meta"}

	if event in ["companion_proactive", "companion_casual", "morning_sidewrite", "player_chat"] and _is_action_mismatch_reply(cleaned, payload):
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


func looks_repetitive_companion_line(text: String) -> bool:
	return _is_repetitive_chat_reply(text.strip_edges(), {})


func _collect_recent_companion_lines(_payload: Dictionary, limit: int = 6) -> Array:
	var out: Array = []
	var seen := {}
	for turn in GameState.get_recent_chat_turns(12):
		if not turn is Dictionary:
			continue
		if str(turn.get("role", "")) != "companion":
			continue
		var line := str(turn.get("text", "")).strip_edges()
		if line == "" or seen.has(line):
			continue
		seen[line] = true
		out.append(line)
	for turn in GameState.today_chat_log:
		if not turn is Dictionary:
			continue
		if str(turn.get("role", "")) != "companion":
			continue
		var line := str(turn.get("text", "")).strip_edges()
		if line == "" or seen.has(line):
			continue
		seen[line] = true
		out.append(line)
	if out.size() <= limit:
		return out
	return out.slice(out.size() - limit, out.size())


func _chat_opener(text: String) -> String:
	var compact := text.strip_edges().replace(" ", "").replace("　", "")
	if compact == "":
		return ""
	var end := compact.length()
	for sep in ["。", "，", ",", "！", "!", "？", "?", "…", "—"]:
		var idx := compact.find(sep)
		if idx > 0:
			end = mini(end, idx)
	return compact.substr(0, mini(end, 20))


func _is_repetitive_chat_reply(text: String, _payload: Dictionary) -> bool:
	var cleaned := text.strip_edges()
	if cleaned == "":
		return false
	var recent := _collect_recent_companion_lines(_payload, 6)
	if recent.is_empty():
		return false
	var opener := _chat_opener(cleaned)
	for line in recent:
		var prev := str(line).strip_edges()
		if prev == cleaned:
			return true
		if opener.length() >= 6 and _chat_opener(prev) == opener:
			return true
	for marker in ["雨下得密", "雨下得挺密", "雨下得", "廊下倒是干爽", "廊下那块干"]:
		if marker in cleaned:
			for line in recent:
				if marker in str(line):
					return true
	return false


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
		var stored_name := _stored_player_name(payload)
		if stored_name != "" and stored_name in text:
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


func _stored_player_name(payload: Dictionary) -> String:
	var name := str(payload.get("player_name", "")).strip_edges()
	if name != "" and name != "你":
		return name
	var ctx: Dictionary = payload.get("player_name_context", {})
	var stored := str(ctx.get("stored_name", "")).strip_edges()
	if stored != "":
		return stored
	return GameState.player_name.strip_edges()


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
	var code := _weather_code(payload)
	if code == GameState.WEATHER_SUN:
		for phrase in SUNNY_RAIN_PHRASES:
			if phrase in text:
				return true
		if "雨停" in text and ("这" in text or "等" in text or "还没" in text):
			return true
		return false
	if code == GameState.WEATHER_RAIN:
		for phrase in RAIN_SUNNY_PHRASES:
			if phrase in text:
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


func _is_literary_reply(text: String, payload: Dictionary = {}) -> bool:
	for phrase in LITERARY_PHRASES:
		if phrase in text:
			return true
	var story_mode := str(payload.get("story_mode", ""))
	if story_mode == "":
		var memory_context: Dictionary = payload.get("memory_context", {})
		story_mode = str(memory_context.get("story_mode", ""))
	if story_mode == "stranger":
		return false
	for phrase in STRANGER_ALLOWED_FOG_PHRASES:
		if phrase in text:
			return true
	return false


func _is_awkward_waiting_reply(text: String) -> bool:
	for phrase in RelationshipDirector.get_awkward_waiting_phrases():
		if phrase in text:
			return true
	return false


func _mentions_premature_promise(text: String) -> bool:
	if GameState.has_story_promise():
		return false
	for phrase in [
		"等萝卜长好", "长好了，我们一起", "长好了我们一起", "一起看看吧",
		"我们约", "你说过等", "你说的等", "有个约定", "本子上写着",
		"你说等",
	]:
		if phrase in text:
			return true
	if "约定" in text and ("萝卜" in text or "看看" in text):
		return true
	return false


func _leaks_director_meta(text: String) -> bool:
	for phrase in [
		"主线节点",
		"今日主线",
		"导演·勿复述",
		"导演勿复述",
		"分支 profile",
		"节点情绪：",
		"亲密度档：",
	]:
		if phrase in text:
			return true
	if "变体" in text and ("_" in text or "N20" in text or "N16" in text):
		return true
	return false


func _violates_harvest_capability(text: String, payload: Dictionary) -> bool:
	var snapshot: Variant = payload.get("world_snapshot", {})
	if not snapshot is Dictionary:
		return false
	if bool(snapshot.get("can_harvest", true)):
		return false
	if not ShopDelegate.looks_like_harvest_offer(text):
		return false
	return true


func _is_action_mismatch_reply(text: String, payload: Dictionary) -> bool:
	for phrase in ["包种子", "手头有", "要种几", "种几块", "第二片叶", "第几片叶"]:
		if phrase in text:
			return true
	var snap: Dictionary = payload.get("world_snapshot", {})
	var companion: Dictionary = snap.get("companion", {}) if snap is Dictionary else {}
	var loc := str(companion.get("location_name", "")).strip_edges()
	var activity := str(companion.get("activity", "")).strip_edges()
	var player_msg := str(payload.get("player_message", "")).strip_edges()
	var places := ["商店", "萝卜田", "廊下", "旧屋门口", "树洞", "田埂", "空土垄", "河边", "小径"]
	for place in places:
		if loc != "" and place == loc:
			continue
		if player_msg != "" and place in player_msg:
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
