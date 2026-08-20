extends Node
## 聊天意图解析（XL-B2+）：评分式自然语言 → 结构化指令。

const INTENT_CHAT := "chat"
const INTENT_WATER := "water"
const INTENT_WATER_ALL := "water_all"
const INTENT_OPEN_MARKET := "open_market"
const INTENT_OPEN_SHOP := "open_shop"
const INTENT_OPEN_MEMORY := "open_memory"
const INTENT_CHECK_STATUS := "check_status"
const INTENT_HELP := "help"
const INTENT_SLEEP := "sleep"
const INTENT_HARVEST := "harvest"
const INTENT_HARVEST_ALL := "harvest_all"
const INTENT_PLANT := "plant"
const INTENT_PLANT_ALL := "plant_all"
const INTENT_REFUSE := "refuse"

const SCORE_THRESHOLD := 5
const API_SKIP_CONFIDENCE := 0.5

const ACTION_INTENTS := [
	INTENT_WATER,
	INTENT_WATER_ALL,
	INTENT_OPEN_MARKET,
	INTENT_OPEN_SHOP,
	INTENT_OPEN_MEMORY,
	INTENT_CHECK_STATUS,
	INTENT_HELP,
	INTENT_SLEEP,
	INTENT_HARVEST,
	INTENT_HARVEST_ALL,
	INTENT_PLANT,
	INTENT_PLANT_ALL,
]

## 出现这些词且像在下指令时，给意图加分。
const DELEGATE_CUES := [
	"帮", "请", "麻烦", "能不能", "可不可以", "可以", "去", "让", "派",
	"吩咐", "委托", "需要你", "帮忙", "劳驾", "替", "给我", "帮忙去",
	"帮我去", "请你", "麻烦你", "去帮我", "你去", "帮我",
]

const CN_NUMBERS := {
	"一": 1, "二": 2, "两": 2, "三": 3, "四": 4, "五": 5,
	"六": 6, "七": 7, "八": 8, "九": 9, "十": 10,
}


func parse(text: String) -> Dictionary:
	var trimmed := text.strip_edges()
	var normalized := _normalize(trimmed)
	var lower := normalized.to_lower()
	var result := {
		"intent": INTENT_CHAT,
		"refuse_kind": "",
		"plot_id": -1,
		"confidence": 0.0,
		"raw_text": trimmed,
		"matched_terms": [],
	}

	if trimmed.is_empty():
		return result

	if looks_like_stop_farm_chore(trimmed):
		result["intent"] = INTENT_CHAT
		result["confidence"] = 0.95
		result["matched_terms"] = ["stop_chore"]
		return result

	if looks_like_status_inquiry(trimmed):
		result["intent"] = INTENT_CHECK_STATUS
		result["confidence"] = 0.92
		result["matched_terms"] = ["status_inquiry"]
		return result

	if looks_like_shop_purchase(trimmed):
		result["intent"] = INTENT_OPEN_SHOP
		result["confidence"] = 0.95
		result["matched_terms"] = ["shop_purchase"]
		return _attach_shop_flags(result, trimmed)

	if is_explicit_sleep_utterance(trimmed):
		result["intent"] = INTENT_SLEEP
		result["confidence"] = 0.95
		result["matched_terms"] = ["sleep"]
		return result

	result["plot_id"] = _extract_plot_id(trimmed, normalized)

	var scores := _score_all_intents(normalized, lower)
	var best_intent := INTENT_CHAT
	var best_score := 0
	var best_terms: Array[String] = []

	for intent_key in scores.keys():
		var entry: Dictionary = scores[intent_key]
		var score := int(entry.get("score", 0))
		if score > best_score:
			best_score = score
			best_intent = str(intent_key)
			best_terms = entry.get("terms", [])

	# 明确的 action 指令优先于 refuse 误判（如「去买点种子」含「种」字）
	if best_score >= SCORE_THRESHOLD and best_intent in ACTION_INTENTS:
		result["intent"] = best_intent
		result["confidence"] = clampf(float(best_score) / 20.0, 0.0, 1.0)
		result["matched_terms"] = best_terms
		return _attach_shop_flags(result, trimmed)

	var refuse_kind := _detect_refuse_kind(normalized)
	if refuse_kind != "":
		return resolve_misclassified_refuse(_refuse(refuse_kind, trimmed))

	if best_score < SCORE_THRESHOLD:
		return result

	result["intent"] = best_intent
	result["confidence"] = clampf(float(best_score) / 20.0, 0.0, 1.0)
	result["matched_terms"] = best_terms
	return result


func is_action_intent(intent: Dictionary) -> bool:
	return str(intent.get("intent", INTENT_CHAT)) in ACTION_INTENTS


func is_explicit_sleep_utterance(text: String) -> bool:
	var normalized := _compact(_normalize(text))
	if normalized == "":
		return false
	if _looks_like_sleep_nudge_text(normalized):
		return true
	if _looks_like_sleep_refusal(normalized):
		return false
	for phrase in [
		"睡觉吧", "去睡觉", "该睡觉了", "该睡了", "收工睡觉", "进入下一天",
		"下一天吧", "下一天", "今天结束了", "结束今天", "睡觉哦", "睡啦", "睡咯",
	]:
		if phrase in normalized:
			return true
	return normalized in ["睡觉", "睡吧", "晚安", "休息吧", "困了", "去睡", "休息", "睡了"]


func looks_like_sleep_nudge(text: String) -> bool:
	return _looks_like_sleep_nudge_text(_compact(_normalize(text)))


func looks_like_sleep_request(text: String) -> bool:
	if looks_like_status_inquiry(text):
		return false
	if is_explicit_sleep_utterance(text):
		return true
	if looks_like_sleep_nudge(text):
		return true
	var normalized := _compact(_normalize(text))
	if normalized == "":
		return false
	if _looks_like_sleep_refusal(normalized):
		return false
	for phrase in [
		"该睡了", "睡啦", "睡咯", "睡觉哦", "去睡吧", "去歇息", "该歇息",
		"睡觉", "晚安", "休息了", "休息吧", "困了", "入眠",
	]:
		if phrase in normalized:
			return true
	return false


func _looks_like_sleep_nudge_text(compact: String) -> bool:
	if compact == "":
		return false
	for phrase in [
		"还不睡觉吗", "还不睡吗", "还不睡啊", "怎么还不睡", "还不去睡吗",
		"还不去睡觉", "你还不睡", "还没睡吗", "还没睡觉吗", "该睡了吧",
		"还不歇息吗", "还不睡嘛",
	]:
		if phrase in compact:
			return true
	if ("睡" in compact) and (compact.ends_with("吗") or compact.ends_with("么") or compact.ends_with("嘛")):
		for cue in ["还不", "怎么还", "还没", "该睡"]:
			if cue in compact:
				return true
	return false


func _looks_like_sleep_refusal(compact: String) -> bool:
	if _looks_like_sleep_nudge_text(compact):
		return false
	for phrase in ["不要睡", "别去睡", "不能睡", "不想睡", "睡什么", "别睡"]:
		if phrase in compact:
			return true
	if compact.begins_with("不睡"):
		return true
	if "没睡" in compact and not compact.ends_with("吗") and not compact.ends_with("么"):
		return true
	return false


func looks_like_planting_rebuttal(text: String) -> bool:
	var compact := _compact(_normalize(text))
	if compact == "":
		return false
	for phrase in [
		"不是你帮我种的", "不是我帮你种的", "不是你帮种", "你帮我种的",
		"帮我种的不是你", "明明是你种", "是你帮我种", "不是你种的",
		"种的不是我吗", "种的不是我", "不是我种的吗",
	]:
		if phrase in compact:
			return true
	if compact.contains("帮我种") and (compact.ends_with("吗") or compact.ends_with("么") or compact.ends_with("嘛")):
		return true
	return false


func looks_like_chore_completion_statement(text: String) -> bool:
	var compact := _compact(_normalize(text))
	if compact == "":
		return false
	if compact.ends_with("吗") or compact.ends_with("么") or compact.ends_with("嘛") or compact.ends_with("?"):
		return false
	for phrase in [
		"收完了", "种完了", "浇完了", "买好了", "都收好了", "刚收完", "已经收完",
		"都种好了", "刚种完", "都浇好了", "刚浇完", "种子买好了",
	]:
		if phrase in compact:
			return true
	return ShopDelegate.looks_like_completed_harvest_claim(text) \
		or ShopDelegate.looks_like_completed_plant_claim(text) \
		or ShopDelegate.looks_like_completed_water_claim(text) \
		or ShopDelegate.looks_like_completed_shop_claim(text)


func looks_like_status_inquiry(text: String) -> bool:
	if looks_like_chore_completion_statement(text):
		return false
	var compact := _compact(_normalize(text))
	if compact == "":
		return false
	for phrase in [
		"熟了没", "熟了吗", "能收了吗", "能收吗", "可以收了吗", "收了没",
		"田怎么样", "田里怎么样", "田里怎样", "长好了没", "长好了吗",
		"看看田", "田况", "能收了没",
		"种好了吗", "种了吗", "种上了吗", "你种完",
		"浇好了吗", "浇了吗", "你浇完",
		"收好了吗", "收了吗", "你收完",
		"买好了吗", "买到了吗", "买完了吗", "种子买了吗",
	]:
		if phrase in compact:
			return true
	if ("田" in compact or "苗" in compact or "萝卜" in compact) and ("怎么样" in compact or "怎样了" in compact):
		return true
	return false


func looks_like_stop_farm_chore(text: String) -> bool:
	var compact := _compact(_normalize(text))
	if compact == "":
		return false
	for phrase in [
		"别浇", "不用浇", "先别浇", "不要浇", "别去浇",
		"别种", "不用种", "先别种", "不要种", "雨停再种",
		"别收", "不用收", "先别收", "不要收",
		"别买", "不用买", "先别买", "不要买", "别买了", "不用买了",
	]:
		if phrase in compact:
			return true
	return false


func looks_like_shop_purchase(text: String) -> bool:
	var normalized := _normalize(text)
	var compact := _compact(normalized)
	if _looks_like_shop_seed_purchase(normalized) or _looks_like_shop_seed_purchase(compact):
		return true
	if compact.contains("买") and compact.contains("种子"):
		return true
	if compact.contains("商店") and _has_delegate_cue(normalized):
		return true
	return false


func resolve_misclassified_refuse(intent: Dictionary) -> Dictionary:
	if str(intent.get("intent", "")) != INTENT_REFUSE:
		return intent
	if str(intent.get("refuse_kind", "")) != "plant":
		return intent
	var raw := str(intent.get("raw_text", ""))
	if looks_like_shop_purchase(raw):
		var shop_fixed := intent.duplicate(true)
		shop_fixed["intent"] = INTENT_OPEN_SHOP
		shop_fixed["refuse_kind"] = ""
		shop_fixed["confidence"] = maxf(float(shop_fixed.get("confidence", 0.0)), 0.9)
		shop_fixed["matched_terms"] = ["shop_fix"]
		return shop_fixed
	var fixed := intent.duplicate(true)
	fixed["intent"] = INTENT_PLANT_ALL if _looks_like_plant_all(_normalize(raw)) else INTENT_PLANT
	fixed["refuse_kind"] = ""
	fixed["confidence"] = maxf(float(fixed.get("confidence", 0.0)), 0.9)
	fixed["matched_terms"] = ["plant_fix"]
	return fixed


func merge_intents(
	local_intent: Dictionary,
	api_intent: Dictionary,
	raw_text: String,
	classified_by_api: bool = false
) -> Dictionary:
	if looks_like_stop_farm_chore(raw_text):
		return {
			"intent": INTENT_CHAT,
			"refuse_kind": "",
			"plot_id": -1,
			"confidence": 0.95,
			"raw_text": raw_text,
			"matched_terms": ["stop_chore"],
			"source": "local",
		}
	if looks_like_status_inquiry(raw_text):
		return {
			"intent": INTENT_CHECK_STATUS,
			"refuse_kind": "",
			"plot_id": -1,
			"confidence": 0.92,
			"raw_text": raw_text,
			"matched_terms": ["status_inquiry"],
			"source": "local",
		}
	if looks_like_sleep_request(raw_text):
		return {
			"intent": INTENT_SLEEP,
			"refuse_kind": "",
			"plot_id": -1,
			"confidence": 0.95,
			"raw_text": raw_text,
			"matched_terms": ["sleep_guard"],
			"source": "local",
		}

	if classified_by_api:
		if api_intent.is_empty():
			if is_action_intent(local_intent) or looks_like_ambiguous_command(raw_text):
				return {
					"intent": INTENT_CHAT,
					"refuse_kind": "",
					"plot_id": -1,
					"confidence": 0.4,
					"raw_text": raw_text,
					"matched_terms": ["classify_failed"],
					"source": "classify_failed",
				}
		elif str(api_intent.get("intent", "")) == INTENT_CHAT:
			var api_plan_early: Variant = api_intent.get("plan", [])
			if api_plan_early is Array and not api_plan_early.is_empty():
				var planned_chat := api_intent.duplicate(true)
				planned_chat["raw_text"] = raw_text
				planned_chat["source"] = "api"
				planned_chat["plan"] = ChorePreprocessor.normalize_plan_steps(api_plan_early, raw_text)
				return planned_chat
			var chat_from_api := api_intent.duplicate(true)
			chat_from_api["raw_text"] = raw_text
			chat_from_api["source"] = "api"
			return chat_from_api

	if str(local_intent.get("intent", "")) == INTENT_REFUSE:
		if is_action_intent(api_intent):
			var from_api := api_intent.duplicate(true)
			from_api["raw_text"] = raw_text
			from_api["source"] = "api"
			return resolve_misclassified_refuse(from_api)
		return resolve_misclassified_refuse(local_intent.duplicate(true))

	if _should_prefer_local(local_intent):
		var kept := local_intent.duplicate(true)
		kept["source"] = "local"
		return resolve_misclassified_refuse(kept)

	if api_intent.is_empty():
		var chat_only := local_intent.duplicate(true)
		chat_only["source"] = "local"
		return chat_only

	if str(api_intent.get("intent", "")) == INTENT_REFUSE:
		var refused := api_intent.duplicate(true)
		refused["source"] = "api"
		refused["raw_text"] = raw_text
		return resolve_misclassified_refuse(refused)

	if is_action_intent(api_intent):
		var merged := api_intent.duplicate(true)
		merged["raw_text"] = raw_text
		merged["source"] = "api"
		if int(merged.get("plot_id", -1)) < 0:
			merged["plot_id"] = int(local_intent.get("plot_id", -1))
		return merged

	var api_plan: Variant = api_intent.get("plan", [])
	if api_plan is Array and not api_plan.is_empty():
		var planned := {
			"intent": INTENT_CHAT,
			"refuse_kind": "",
			"plot_id": -1,
			"confidence": float(api_intent.get("confidence", 0.75)),
			"raw_text": raw_text,
			"plan": ChorePreprocessor.normalize_plan_steps(api_plan, raw_text),
			"matched_terms": ["api:plan"],
			"source": "api",
		}
		return planned

	var fallback := local_intent.duplicate(true)
	fallback["source"] = "local"
	return resolve_misclassified_refuse(fallback)


func from_api_response(parsed: Variant, raw_text: String) -> Dictionary:
	if typeof(parsed) == TYPE_STRING:
		var as_string := str(parsed).strip_edges()
		if as_string.begins_with("{"):
			parsed = JSON.parse_string(as_string)

	var data: Dictionary = {}
	if typeof(parsed) == TYPE_DICTIONARY:
		data = _unwrap_response_dict(parsed)
	elif typeof(parsed) == TYPE_STRING:
		return {}

	if data.is_empty():
		return {}

	var intent_key := _normalize_intent_key(
		str(data.get("intent", data.get("action", INTENT_CHAT)))
	)
	var result := {
		"intent": intent_key,
		"refuse_kind": str(data.get("refuse_kind", "")),
		"plot_id": int(data.get("plot_id", -1)),
		"confidence": clampf(float(data.get("confidence", 0.75)), 0.0, 1.0),
		"raw_text": raw_text,
		"matched_terms": ["api:%s" % intent_key],
		"source": "api",
	}

	if intent_key == INTENT_REFUSE and result["refuse_kind"] == "":
		result["refuse_kind"] = str(data.get("kind", "sell"))

	if result["plot_id"] < 0:
		result["plot_id"] = _extract_plot_id(raw_text, _normalize(raw_text))

	var plan_steps := _extract_plan_from_data(data, raw_text)
	if not plan_steps.is_empty():
		result["plan"] = plan_steps
		if not is_action_intent(result):
			result["intent"] = INTENT_CHAT

	if bool(data.get("max_gold", false)):
		result["max_gold"] = true

	return _sanitize_intent(_attach_shop_flags(result, raw_text))


func from_api_classify_response(parsed: Variant, raw_text: String) -> Dictionary:
	## /classify 只认 intent 字段，不把 chat reply 当指令。
	if typeof(parsed) == TYPE_STRING:
		var as_string := str(parsed).strip_edges()
		if as_string.begins_with("{"):
			parsed = JSON.parse_string(as_string)
	if typeof(parsed) != TYPE_DICTIONARY:
		return {}
	var data: Dictionary = parsed
	if data.has("intent") or data.has("action"):
		pass
	elif data.has("data") and data["data"] is Dictionary:
		data = data["data"]
	var intent_key := _normalize_intent_key(str(data.get("intent", data.get("action", ""))))
	if intent_key == "":
		intent_key = INTENT_CHAT
	var plan_steps := _extract_plan_from_data(data, raw_text)
	var result := {
		"intent": intent_key if intent_key in ACTION_INTENTS or intent_key == INTENT_CHAT or intent_key == INTENT_REFUSE else INTENT_CHAT,
		"refuse_kind": str(data.get("refuse_kind", "")),
		"plot_id": int(data.get("plot_id", -1)),
		"confidence": clampf(float(data.get("confidence", 0.75)), 0.0, 1.0),
		"raw_text": raw_text,
		"matched_terms": ["classify:%s" % intent_key],
		"source": "api",
	}
	if not plan_steps.is_empty():
		result["plan"] = plan_steps
		result["intent"] = INTENT_CHAT
		result["matched_terms"] = ["classify:plan"]
	if bool(data.get("max_gold", false)):
		result["max_gold"] = true
	return _attach_shop_flags(result, raw_text)


func looks_like_ambiguous_command(text: String) -> bool:
	var compact := _compact(_normalize(text))
	if compact == "" or looks_like_stop_farm_chore(text):
		return false
	if not _has_delegate_cue(text) and not _has_delegate_cue(compact):
		return false
	for keyword in ["浇水", "浇田", "收萝卜", "去商店", "买种子", "种萝卜", "睡觉", "去睡"]:
		if keyword in compact:
			return true
	return false


func _should_prefer_local(local_intent: Dictionary) -> bool:
	if not is_action_intent(local_intent):
		return false
	return float(local_intent.get("confidence", 0.0)) >= API_SKIP_CONFIDENCE


func _unwrap_response_dict(parsed: Dictionary) -> Dictionary:
	if parsed.has("action") and parsed["action"] is Dictionary:
		var action: Dictionary = parsed["action"]
		var merged := action.duplicate(true)
		if parsed.has("reply") and not merged.has("reply"):
			merged["reply"] = parsed["reply"]
		return merged
	if parsed.has("data") and parsed["data"] is Dictionary:
		return _unwrap_response_dict(parsed["data"])
	return parsed


func _normalize_intent_key(raw: String) -> String:
	var key := raw.strip_edges().to_lower()
	key = key.replace(" ", "_").replace("-", "_")
	match key:
		"water_all", "waterall", "water_all_plots", "all_water":
			return INTENT_WATER_ALL
		"water", "watering", "water_plot":
			return INTENT_WATER
		"open_market", "market", "check_market", "price", "prices":
			return INTENT_OPEN_MARKET
		"open_shop", "shop", "buy_seed", "buy_seeds":
			return INTENT_OPEN_SHOP
		"open_memory", "memory", "journal", "diary":
			return INTENT_OPEN_MEMORY
		"check_status", "status", "plot_status", "check_plots":
			return INTENT_CHECK_STATUS
		"help", "commands", "what_can_you_do":
			return INTENT_HELP
		"sleep", "next_day", "rest", "good_night":
			return INTENT_SLEEP
		"harvest_all", "harvestall", "harvest_all_plots", "all_harvest":
			return INTENT_HARVEST_ALL
		"harvest", "pick", "collect", "gather":
			return INTENT_HARVEST
		"plant_all", "plantall", "plant_all_plots", "all_plant":
			return INTENT_PLANT_ALL
		"plant", "sow", "seed_plot":
			return INTENT_PLANT
		"refuse", "deny", "reject":
			return INTENT_REFUSE
		"chat", "talk", "none", "":
			return INTENT_CHAT
		_:
			if key in ACTION_INTENTS or key == INTENT_CHAT or key == INTENT_REFUSE:
				return key
			return INTENT_CHAT


func _sanitize_intent(intent: Dictionary) -> Dictionary:
	var key := str(intent.get("intent", INTENT_CHAT))
	if key == INTENT_REFUSE:
		var kind := str(intent.get("refuse_kind", ""))
		if kind not in ["sell"]:
			return {}
		return intent

	if key == INTENT_CHAT:
		return {}

	if key not in ACTION_INTENTS:
		return {}

	if key in [INTENT_WATER, INTENT_WATER_ALL] and int(intent.get("plot_id", -1)) < 0:
		intent["plot_id"] = -1
	return intent


func get_intent_label(intent_key: String) -> String:
	match intent_key:
		INTENT_WATER:
			return "浇水"
		INTENT_WATER_ALL:
			return "浇全部田"
		INTENT_OPEN_MARKET:
			return "出售萝卜"
		INTENT_OPEN_SHOP:
			return "打开商店"
		INTENT_OPEN_MEMORY:
			return "翻本子"
		INTENT_CHECK_STATUS:
			return "查看田况"
		INTENT_HELP:
			return "能力说明"
		INTENT_SLEEP:
			return "睡觉/下一天"
		INTENT_HARVEST:
			return "收萝卜"
		INTENT_HARVEST_ALL:
			return "收全部萝卜"
		INTENT_PLANT:
			return "种萝卜"
		INTENT_PLANT_ALL:
			return "种全部空田"
		_:
			return "聊天"


func _normalize(text: String) -> String:
	var s := text.strip_edges()
	s = s.replace("，", " ").replace("。", " ").replace("！", " ")
	s = s.replace("？", " ").replace("、", " ").replace("～", " ")
	s = s.replace("！", " ").replace("?", " ").replace("!", " ")
	while "  " in s:
		s = s.replace("  ", " ")
	return s.strip_edges()


func _compact(text: String) -> String:
	return text.replace(" ", "").replace("　", "")


func _refuse(kind: String, raw_text: String) -> Dictionary:
	return {
		"intent": INTENT_REFUSE,
		"refuse_kind": kind,
		"plot_id": -1,
		"confidence": 1.0,
		"raw_text": raw_text,
		"matched_terms": ["refuse_%s" % kind],
	}


func _score_all_intents(normalized: String, lower: String) -> Dictionary:
	var scores := {}
	_add_score(scores, INTENT_WATER_ALL, _score_water_all(normalized))
	_add_score(scores, INTENT_WATER, _score_water(normalized))
	_add_score(scores, INTENT_HARVEST_ALL, _score_harvest_all(normalized))
	_add_score(scores, INTENT_HARVEST, _score_harvest(normalized))
	_add_score(scores, INTENT_PLANT_ALL, _score_plant_all(normalized))
	_add_score(scores, INTENT_PLANT, _score_plant(normalized))
	_add_score(scores, INTENT_OPEN_MARKET, _score_market(normalized, lower))
	_add_score(scores, INTENT_OPEN_SHOP, _score_shop(normalized))
	_add_score(scores, INTENT_OPEN_MEMORY, _score_memory(normalized))
	_add_score(scores, INTENT_CHECK_STATUS, _score_status(normalized))
	_add_score(scores, INTENT_SLEEP, _score_sleep(normalized))
	_add_score(scores, INTENT_HELP, _score_help(normalized, lower))

	if scores.has(INTENT_WATER_ALL) and int(scores[INTENT_WATER_ALL].get("score", 0)) >= SCORE_THRESHOLD:
		if scores.has(INTENT_WATER):
			scores.erase(INTENT_WATER)
	if scores.has(INTENT_HARVEST_ALL) and int(scores[INTENT_HARVEST_ALL].get("score", 0)) >= SCORE_THRESHOLD:
		if scores.has(INTENT_HARVEST):
			scores.erase(INTENT_HARVEST)
	if scores.has(INTENT_PLANT_ALL) and int(scores[INTENT_PLANT_ALL].get("score", 0)) >= SCORE_THRESHOLD:
		if scores.has(INTENT_PLANT):
			scores.erase(INTENT_PLANT)
	return scores


func _add_score(scores: Dictionary, intent_key: String, scored: Dictionary) -> void:
	if int(scored.get("score", 0)) <= 0:
		return
	scores[intent_key] = scored


func _score_with_terms(normalized: String, keyword_scores: Dictionary, extra: int = 0) -> Dictionary:
	var score := extra
	var terms: Array[String] = []
	for keyword in keyword_scores.keys():
		if keyword in normalized:
			score += int(keyword_scores[keyword])
			terms.append(keyword)
	score += _delegate_boost(normalized, terms)
	return {"score": score, "terms": terms}


func _delegate_boost(normalized: String, terms: Array[String]) -> int:
	for cue in DELEGATE_CUES:
		if cue in normalized:
			terms.append("delegate:%s" % cue)
			return 4
	if normalized.ends_with("吗") or normalized.ends_with("么"):
		return 2
	return 0


func _detect_refuse_kind(_normalized: String) -> String:
	return ""


func _looks_like_shop_seed_purchase(normalized: String) -> bool:
	return _match_any(normalized, [
		"买种子", "买点种子", "买点儿种子", "去买种子", "去买点种子",
		"买萝卜种子", "去商店", "打开商店", "进货", "采购", "买东西",
		"没种子", "缺种子", "种子不够", "帮我买", "帮我去商店",
	])


func _looks_like_plant_all(normalized: String) -> bool:
	return _match_any(normalized, [
		"都种", "全种", "全部种", "统统种", "一并种", "所有空田", "每块空田",
		"空田都种", "把空田都种", "能种的都种", "有种子都种",
	]) or (
		("种" in normalized or "播" in normalized)
		and _match_any(normalized, ["都", "全", "所有", "全部", "统统", "每一", "每个"])
	)


func _looks_like_plant_delegate(normalized: String) -> bool:
	if _looks_like_shop_seed_purchase(normalized):
		return false
	if _match_any(normalized, ["种什么", "哪种", "怎么种"]):
		return false
	if _match_any(normalized, ["种子价", "种子价格", "买种子", "买点种子"]):
		return false
	return _match_any(normalized, [
		"去种", "帮忙种", "帮我种", "替我种", "帮种", "代种", "你去种",
		"种下", "种下去", "播种", "栽种", "种萝卜", "帮忙种下", "帮我播", "帮我栽",
	]) or (
		_has_delegate_cue(normalized)
		and normalized.contains("种")
		and not normalized.contains("种子")
	)


func _has_delegate_cue(normalized: String) -> bool:
	for cue in DELEGATE_CUES:
		if cue in normalized:
			return true
	return false


func _match_any(text: String, phrases: Array) -> bool:
	for phrase in phrases:
		if str(phrase) in text:
			return true
	return false


func _score_water_all(normalized: String) -> Dictionary:
	var keywords := {
		"都浇": 10, "全浇": 10, "全部浇": 10, "统统浇": 10, "一并浇": 9,
		"所有田": 10, "每块田": 9, "整块田": 9, "整片田": 9, "每一塊": 9,
		"所有地": 9, "每块地": 9, "整块地": 9,
		"浇所有": 10, "浇全部": 10, "浇一遍": 8, "都浇一遍": 10,
		"把田都浇": 10, "把地都浇": 10, "田都浇": 10, "地都浇": 10,
		"还没浇的": 8, "没浇的": 8, "没浇水的": 8,
		"还没浇水": 10, "还没浇": 9, "尚未浇": 9, "今天还没浇": 10,
		"没浇水": 9, "尚未浇水": 9, "还没给田浇": 10,
	}
	var scored := _score_with_terms(normalized, keywords)
	if ("浇" in normalized) and _match_any(normalized, ["都", "全", "所有", "全部", "统统", "每一", "每个", "整块"]):
		scored["score"] = int(scored.get("score", 0)) + 6
		scored["terms"].append("water_all_combo")
	if "浇" in normalized and _match_any(normalized, ["还没", "尚未", "没浇", "今天"]):
		scored["score"] = int(scored.get("score", 0)) + 5
		scored["terms"].append("water_all_pending")
	return scored


func _score_water(normalized: String) -> Dictionary:
	var keywords := {
		"浇水": 9, "浇田": 9, "浇地": 9, "浇一下": 8, "浇点水": 8,
		"浇萝卜": 9, "浇萝卜田": 9, "给田浇水": 10, "给地浇水": 10,
		"帮忙浇水": 10, "帮我浇水": 10, "帮忙浇田": 10, "帮我浇田": 10,
		"去浇水": 9, "去浇田": 9, "去浇地": 9,
		"补水": 7, "灌水": 7, "润一润": 6, "湿润": 6, "浇透": 7,
		"浇个水": 8, "浇浇水": 8, "浇一浇": 8, "浇一遍水": 8,
		"派你去浇": 10, "派你浇": 10, "叫你去浇": 10,
		"田里浇水": 8, "农田浇水": 8, "萝卜田浇水": 9,
	}
	var scored := _score_with_terms(normalized, keywords)
	if "浇" in normalized and not _looks_like_water_all(normalized):
		scored["score"] = int(scored.get("score", 0)) + 3
		scored["terms"].append("浇")
	var compact := normalized.strip_edges().replace(" ", "")
	if compact in ["浇", "浇水", "去浇", "去浇水", "浇田", "浇一下"]:
		scored["score"] = 8
		scored["terms"].append("bare_water")
	return scored


func _looks_like_water_all(normalized: String) -> bool:
	if _match_any(normalized, ["都", "全", "所有", "全部", "统统", "每一", "每个", "整块", "整片"]):
		return true
	return _match_any(normalized, ["还没", "尚未", "没浇", "今天还没"])


func _score_harvest_all(normalized: String) -> Dictionary:
	var keywords := {
		"都收": 10, "全收": 10, "全部收": 10, "统统收": 10, "一并收": 9,
		"所有萝卜": 10, "每块田": 8, "所有田": 9, "整块田": 9,
		"收所有": 10, "收全部": 10, "收一遍": 8, "都收一遍": 10,
		"把萝卜都收": 10, "把田都收": 10, "萝卜都收": 10,
		"还没收的": 8, "能收的": 8, "可以收的": 8,
	}
	var scored := _score_with_terms(normalized, keywords)
	if ("收" in normalized or "摘" in normalized or "拔" in normalized) and _match_any(
		normalized, ["都", "全", "所有", "全部", "统统", "每一", "每个", "整块"]
	):
		scored["score"] = int(scored.get("score", 0)) + 6
		scored["terms"].append("harvest_all_combo")
	return scored


func _score_harvest(normalized: String) -> Dictionary:
	var keywords := {
		"收萝卜": 10, "收一下萝卜": 10, "帮忙收": 9, "帮我收": 10, "帮我摘": 10,
		"帮我拔": 10, "去收萝卜": 10, "去收吧": 10, "去收": 8, "收萝卜田": 10, "收获": 8,
		"帮忙收获": 10, "帮我收获": 10, "摘萝卜": 10, "拔萝卜": 10,
		"派你去收": 10, "叫你去收": 10, "代收": 9, "帮收": 9,
	}
	var scored := _score_with_terms(normalized, keywords)
	if ("收" in normalized or "摘" in normalized) and not _looks_like_harvest_all(normalized):
		if _match_any(normalized, ["萝卜", "田", "地", "成熟", "好了"]):
			scored["score"] = int(scored.get("score", 0)) + 4
			scored["terms"].append("收")
	return scored


func _looks_like_harvest_all(normalized: String) -> bool:
	return _match_any(normalized, ["都", "全", "所有", "全部", "统统", "每一", "每个", "整块", "整片"])


func _score_plant_all(normalized: String) -> Dictionary:
	if _looks_like_shop_seed_purchase(normalized):
		return {"score": 0, "terms": []}
	var keywords := {
		"都种": 10, "全种": 10, "全部种": 10, "统统种": 10, "一并种": 9,
		"所有空田": 10, "每块空田": 9, "空田都种": 10, "把空田都种": 10,
		"能种的都种": 10, "有种子都种": 10, "种所有": 10, "种全部": 10,
	}
	var scored := _score_with_terms(normalized, keywords)
	if _looks_like_plant_all(normalized):
		scored["score"] = int(scored.get("score", 0)) + 6
		scored["terms"].append("plant_all_combo")
	return scored


func _score_plant(normalized: String) -> Dictionary:
	if _looks_like_shop_seed_purchase(normalized):
		return {"score": 0, "terms": []}
	var keywords := {
		"帮我种": 10, "替我种": 10, "帮种": 10, "代种": 9, "你去种": 10, "帮忙种": 10,
		"帮我播": 10, "帮我栽": 10, "帮忙种下": 10, "种下去": 9, "种下": 8,
		"去种萝卜": 10, "种萝卜": 9, "帮忙种萝卜": 10, "帮我种萝卜": 10,
		"现在种": 10, "这就种": 10, "马上去种": 10, "去田里种": 10, "种上": 8,
		"派你去种": 10, "叫你去种": 10, "播种": 8, "栽种": 8,
		"帮我把种子种": 10, "替我把种子种": 10,
	}
	var scored := _score_with_terms(normalized, keywords)
	if _looks_like_plant_delegate(normalized) and not _looks_like_plant_all(normalized):
		scored["score"] = int(scored.get("score", 0)) + 5
		scored["terms"].append("plant_delegate")
	return scored


func _score_market(normalized: String, lower: String) -> Dictionary:
	if _detect_refuse_kind(normalized) == "sell":
		return {"score": 0, "terms": []}

	var keywords := {
		"卖掉": 12, "卖光": 12, "出售": 11, "都卖": 11, "全部卖": 12,
		"卖萝卜": 11, "帮我卖": 11, "替我卖": 11, "代卖": 10,
		"大盘": 8, "看大盘": 8,
	}
	var scored := _score_with_terms(normalized, keywords)
	if "卖" in normalized and _match_any(normalized, ["看看", "查", "多少", "价", "行情", "大盘"]):
		scored["score"] = int(scored.get("score", 0)) + 5
		scored["terms"].append("卖+查询")
	if lower in ["market", "price", "stock"]:
		scored["score"] = int(scored.get("score", 0)) + 10
		scored["terms"].append(lower)
	return scored


func _score_shop(normalized: String) -> Dictionary:
	var compact := _compact(normalized)
	var keywords := {
		"商店": 9, "打开商店": 10, "去商店": 9, "买种子": 9, "买点种子": 9,
		"去买点种子": 10, "去买种子": 10, "买点儿种子": 10,
		"帮我去商店": 10, "帮我去商店买": 10, "去商店买": 10, "买东西": 8,
		"种子不够": 8, "没种子": 8, "缺种子": 8, "买萝卜种子": 10,
		"进货": 7, "采购": 7, "买点东西": 7,
		"帮我买": 8, "金币": 4,
	}
	var scored := _score_with_terms(normalized, keywords)
	if compact != normalized:
		for keyword in keywords.keys():
			if str(keyword) in compact and not str(keyword) in normalized:
				scored["score"] = int(scored.get("score", 0)) + int(keywords[keyword])
				scored["terms"].append("%s(compact)" % keyword)
	if compact.contains("买") and compact.contains("种子"):
		scored["score"] = int(scored.get("score", 0)) + 8
		scored["terms"].append("买+种子")
	return scored


func _score_memory(normalized: String) -> Dictionary:
	var keywords := {
		"记忆": 9, "我们的记忆": 10, "看看记忆": 10, "打开记忆": 10,
		"日记": 9, "我们的故事": 10, "回忆": 8,
		"共同经历": 9, "记忆面板": 10, "记忆墙": 9,
		"翻记忆": 10, "看记忆": 10,
	}
	var scored := _score_with_terms(normalized, keywords)
	if "故事" in normalized and _match_any(normalized, ["看", "讲", "我们的", "打开"]):
		scored["score"] = int(scored.get("score", 0)) + 5
		scored["terms"].append("故事+查看")
	return scored


func _score_status(normalized: String) -> Dictionary:
	var keywords := {
		"田怎么样": 10, "田况": 9, "长好了吗": 9, "熟了吗": 9, "能收了吗": 9,
		"可以收了吗": 9, "还要浇吗": 9, "浇过了吗": 8, "什么情况": 7,
		"看看田": 9, "看看地": 9, "看看萝卜": 8, "萝卜怎么样了": 10,
		"几块田": 8, "多少田": 8, "还剩": 6, "进度": 6, "状态": 6,
		"今天忙什么": 7, "接下来": 5, "现在要做什么": 8,
	}
	return _score_with_terms(normalized, keywords)


func _score_sleep(normalized: String) -> Dictionary:
	if _looks_like_sleep_nudge_text(normalized):
		return {"score": 14, "terms": ["sleep_nudge"]}
	var keywords := {
		"还不睡觉吗": 14, "还不睡吗": 14, "怎么还不睡": 13,
		"睡觉吧": 12, "睡觉": 9, "睡吧": 9, "去睡觉": 9, "下一天": 10, "进入下一天": 10,
		"下一天吧": 10, "明天吧": 8, "休息吧": 7, "困了": 7, "晚安": 8,
		"结束今天": 8, "今天结束了": 8, "收工睡觉": 9,
	}
	return _score_with_terms(normalized, keywords)


func _score_help(normalized: String, lower: String) -> Dictionary:
	var keywords := {
		"你能做什么": 10, "你会什么": 10, "你能帮": 9, "可以帮你": 8,
		"怎么玩": 9, "怎么操作": 9, "教我": 8, "指令": 8, "命令": 8,
		"有什么功能": 9, "帮帮我": 7, "我该怎么做": 8, "做什么好": 7,
	}
	var scored := _score_with_terms(normalized, keywords)
	if lower in ["help", "?"]:
		scored["score"] = int(scored.get("score", 0)) + 10
	return scored


func _extract_plot_id(raw_text: String, normalized: String) -> int:
	var regex := RegEx.new()

	regex.compile("第\\s*(\\d+)\\s*块")
	var match_result := regex.search(raw_text)
	if match_result:
		return int(match_result.get_string(1))

	regex.compile("第\\s*([一二两三四五六七八九十])\\s*块")
	match_result = regex.search(raw_text)
	if match_result:
		var cn := match_result.get_string(1)
		if CN_NUMBERS.has(cn):
			return int(CN_NUMBERS[cn])

	regex.compile("(\\d+)\\s*号?田")
	match_result = regex.search(raw_text)
	if match_result:
		return int(match_result.get_string(1))

	regex.compile("第\\s*([一二两三四五六七八九十])\\s*块田")
	match_result = regex.search(raw_text)
	if match_result:
		var cn2 := match_result.get_string(1)
		if CN_NUMBERS.has(cn2):
			return int(CN_NUMBERS[cn2])

	if "第一块" in normalized or "第一块田" in normalized:
		return 1
	if "第二块" in normalized or "第二块田" in normalized:
		return 2
	if "第三块" in normalized or "第三块田" in normalized:
		return 3

	return -1


func _extract_plan_from_data(data: Dictionary, raw_text: String = "") -> Array:
	var raw_plan: Variant = data.get("plan", data.get("steps", []))
	return ChorePreprocessor.normalize_plan_steps(raw_plan, raw_text)


func _attach_shop_flags(result: Dictionary, raw_text: String) -> Dictionary:
	if str(result.get("intent", "")) != INTENT_OPEN_SHOP:
		return result
	if bool(result.get("max_gold", false)):
		return result
	if ChorePreprocessor.looks_like_max_gold_seed_buy(raw_text):
		result["max_gold"] = true
	return result
