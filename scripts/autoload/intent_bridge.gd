extends Node
## API 语义意图兜底：本地规则未命中或置信度低时，请求大模型做 intent 分类。

signal classify_finished(text: String, intent: Dictionary, success: bool)

const ALLOWED_INTENTS := [
	IntentParser.INTENT_CHAT,
	IntentParser.INTENT_WATER,
	IntentParser.INTENT_WATER_ALL,
	IntentParser.INTENT_HARVEST,
	IntentParser.INTENT_HARVEST_ALL,
	IntentParser.INTENT_PLANT,
	IntentParser.INTENT_PLANT_ALL,
	IntentParser.INTENT_OPEN_MARKET,
	IntentParser.INTENT_OPEN_SHOP,
	IntentParser.INTENT_OPEN_MEMORY,
	IntentParser.INTENT_CHECK_STATUS,
	IntentParser.INTENT_HELP,
	IntentParser.INTENT_SLEEP,
	IntentParser.INTENT_REFUSE,
]

var _http: HTTPRequest
var _pending_classify: Dictionary = {}
var _classify_in_flight: bool = false
var _classify_waiters: Array = []


func _ready() -> void:
	_http = HTTPRequest.new()
	add_child(_http)
	_http.request_completed.connect(_on_http_completed)


func is_enabled() -> bool:
	if not NpcBridge.is_api_enabled():
		return false
	return bool(NpcBridge.get_config_value("intent_fallback_enabled", true))


func should_fallback(local_intent: Dictionary) -> bool:
	if not is_enabled():
		return false
	if str(local_intent.get("intent", "")) == IntentParser.INTENT_REFUSE:
		return false
	if str(local_intent.get("intent", "")) == IntentParser.INTENT_SLEEP:
		return false
	var raw_for_sleep := str(local_intent.get("raw_text", "")).strip_edges()
	if IntentParser.is_explicit_sleep_utterance(raw_for_sleep):
		return false
	if IntentParser.looks_like_sleep_nudge(raw_for_sleep):
		return false
	if IntentParser.looks_like_status_inquiry(raw_for_sleep):
		return false
	if IntentParser.looks_like_stop_farm_chore(raw_for_sleep):
		return false
	if IntentParser.is_action_intent(local_intent):
		if float(local_intent.get("confidence", 0.0)) >= IntentParser.API_SKIP_CONFIDENCE:
			return false
		return true
	var raw := str(local_intent.get("raw_text", "")).strip_edges()
	if raw.is_empty():
		return false
	return IntentParser.looks_like_ambiguous_command(raw)


func _looks_like_hidden_command(text: String) -> bool:
	for cue in IntentParser.DELEGATE_CUES:
		if cue in text:
			return true
	for keyword in ["集市", "大盘", "商店", "记忆", "睡觉", "休息", "状态", "帮忙", "浇水", "浇田", "收萝卜", "收", "摘", "买", "种", "播"]:
		if keyword in text:
			return true
	return false


func classify_message(text: String) -> Dictionary:
	if not is_enabled() or text.strip_edges().is_empty():
		return {}

	var request_key := str(Time.get_ticks_msec()) + ":" + str(randi())
	_pending_classify[request_key] = {"text": text, "done": false, "intent": {}, "success": false}
	_classify_waiters.append(request_key)
	_pump_classify_queue()

	while not bool(_pending_classify.get(request_key, {}).get("done", false)):
		await get_tree().process_frame
		if not is_inside_tree():
			_pending_classify.erase(request_key)
			_classify_waiters.erase(request_key)
			return {}

	var entry: Dictionary = _pending_classify.get(request_key, {})
	_pending_classify.erase(request_key)
	if not bool(entry.get("success", false)):
		return {}
	if entry.get("intent") is Dictionary:
		return entry["intent"]
	return {}


func _pump_classify_queue() -> void:
	if _classify_in_flight or _classify_waiters.is_empty():
		return
	var request_key := str(_classify_waiters[0])
	if not _pending_classify.has(request_key):
		_classify_waiters.pop_front()
		call_deferred("_pump_classify_queue")
		return
	var text := str(_pending_classify[request_key].get("text", "")).strip_edges()
	if text.is_empty():
		_pending_classify[request_key]["done"] = true
		_classify_waiters.pop_front()
		call_deferred("_pump_classify_queue")
		return

	var url := _get_classify_url()
	var headers := _build_headers()
	var body := JSON.stringify(_build_classify_payload(text))
	var timeout_sec := float(NpcBridge.get_config_value("intent_timeout_sec", 8.0))
	_http.timeout = timeout_sec
	_classify_in_flight = true

	var err := _http.request(url, headers, HTTPClient.METHOD_POST, body)
	if err != OK:
		_classify_in_flight = false
		_pending_classify[request_key]["done"] = true
		_classify_waiters.pop_front()
		call_deferred("_pump_classify_queue")


func _build_classify_payload(text: String) -> Dictionary:
	var time_ctx := GameState.get_time_context_for_llm()
	return {
		"event": "intent_classify",
		"companion_id": str(NpcBridge.get_config_value("npc_id", "xiaoli")),
		"player_message": text,
		"allowed_intents": ALLOWED_INTENTS,
		"response_format": "json",
		"intent_instruction": _intent_instruction(),
		"time_of_day": GameState.time_of_day,
		"time_label": GameState.get_time_label(),
		"day_period_label": GameState.get_day_period_label(),
		"time_context": time_ctx,
		"world_snapshot": WorldSnapshot.capture({"react_type": "intent_classify"}),
		"story_hint": StoryDirector.get_story_hint(),
		"story_context": StoryDirector.get_story_context_for_llm(),
	}


func _intent_instruction() -> String:
	return (
		"你是意图分类器。根据玩家消息，只输出 JSON，不要 markdown。"
		+ "字段：intent(枚举)、plot_id(整数，无则-1)、confidence(0~1)、refuse_kind(仅 intent=refuse 时：sell)、"
		+ "steps(字符串数组或对象数组，可选；多步委托时按顺序填 harvest_all/sell_turnips/shop_buy_seeds/plant_all/water_all；"
		+ "shop_buy_seeds 可带 max_gold:true 表示用剩余金币尽量买种子)。"
		+ "字段也可含 max_gold(布尔，单步 open_shop 且要「剩下的钱全买」时用)。"
		+ "intent 只能从 allowed_intents 中选。"
		+ "玩家在委托做事时用 action intent；多步委托（然后/再/顺便）必须填 steps 且 intent=chat。"
		+ "小狸可代做：浇水 water/water_all、种萝卜 plant/plant_all、收萝卜 harvest/harvest_all、去商店 open_shop、出售萝卜 open_market 等；"
		+ "卖萝卜用 open_market/sell_turnips，不是 harvest。"
		+ "仅帮卖 sell 用 refuse；种萝卜用 plant，不要 refuse plant。"
		+ "讨论浇田、商店、熟没熟，只要还没明确委托，必须是 chat 且 steps=[]。"
		+ "明确让小狸去浇/种/收/买/睡觉才用对应 action 或 steps。"
		+ "参考 world_snapshot.companion 的位置、状态与 capabilities。"
		+ "示例单步：{\"intent\":\"harvest_all\",\"plot_id\":-1,\"confidence\":0.92,\"refuse_kind\":\"\",\"steps\":[]}"
		+ "示例多步：{\"intent\":\"chat\",\"plot_id\":-1,\"confidence\":0.9,\"steps\":[\"harvest_all\",\"sell_turnips\",\"shop_buy_seeds\"]}"
	)


func _get_classify_url() -> String:
	var custom := str(NpcBridge.get_config_value("intent_classify_url", "")).strip_edges()
	if custom != "":
		return custom
	return str(NpcBridge.get_config_value("api_url", "")).strip_edges()


func _build_headers() -> PackedStringArray:
	var headers := PackedStringArray(["Content-Type: application/json"])
	var api_key := str(NpcBridge.get_config_value("api_key", "")).strip_edges()
	if api_key != "":
		headers.append("Authorization: Bearer %s" % api_key)
	return headers


func _on_http_completed(
	result: int,
	response_code: int,
	_headers: PackedStringArray,
	body: PackedByteArray
) -> void:
	_classify_in_flight = false
	var request_key := ""
	if not _classify_waiters.is_empty():
		request_key = str(_classify_waiters[0])
	if request_key == "" or not _pending_classify.has(request_key):
		call_deferred("_pump_classify_queue")
		return

	var text: String = _pending_classify[request_key].get("text", "")
	var intent := {}
	var success := false

	if result == HTTPRequest.RESULT_SUCCESS and response_code >= 200 and response_code < 300:
		var parsed: Variant = JSON.parse_string(body.get_string_from_utf8())
		intent = IntentParser.from_api_classify_response(parsed, text)
		success = not intent.is_empty()

	_pending_classify[request_key] = {
		"text": text,
		"done": true,
		"success": success,
		"intent": intent,
	}
	classify_finished.emit(text, intent, success)
	_classify_waiters.pop_front()
	call_deferred("_pump_classify_queue")
