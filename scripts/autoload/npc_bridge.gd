extends Node
## GameNPC 通信桥（B3～B7）。
## 本地 fallback / 本地亲密度判定：仅当 API 未配置（未连接大模型）时使用。

signal reply_ready(request_id: int, event: String, text: String, used_fallback: bool)
signal request_failed(request_id: int, event: String, error: String)

const CONFIG_RES_PATH := "res://config/npc_config.json"
const CONFIG_USER_PATH := "user://npc_config.json"
const PERSONA_PATH := "res://config/xiaoli_persona.json"
const LLM_FAILURE_REPLY := "……我刚才没听清，你再说一遍好吗？"
const SILENT_FAILURE_EVENTS := ["day_journal_summarize", "companion_react", "story_beat", "story_step_render"]

var _http: HTTPRequest
var _persona: Dictionary = {}
var _config: Dictionary = {}
var _next_request_id: int = 1
var _pending: Dictionary = {}
var _chat_intents: Dictionary = {}
var _relationship_deltas: Dictionary = {}
var _cited_memory_ids: Dictionary = {}
var _reply_contracts: Dictionary = {}
var _response_meta: Dictionary = {}
var _api_queue: Array[Dictionary] = []
var _in_flight_request_id: int = -1


func _ready() -> void:
	_http = HTTPRequest.new()
	add_child(_http)
	_http.request_completed.connect(_on_http_completed)
	_load_persona()
	_load_config()


func is_api_enabled() -> bool:
	return bool(_config.get("enabled", false)) and str(_config.get("api_url", "")).strip_edges() != ""


func get_persona() -> Dictionary:
	return _persona.duplicate(true)


func get_config_value(key: String, default: Variant = null) -> Variant:
	return _config.get(key, default)


func take_chat_intent(request_id: int) -> Dictionary:
	if not _chat_intents.has(request_id):
		return {}
	var intent: Dictionary = _chat_intents[request_id]
	_chat_intents.erase(request_id)
	return intent.duplicate(true)


func take_relationship_delta(request_id: int) -> Dictionary:
	if not _relationship_deltas.has(request_id):
		return {}
	var delta: Dictionary = _relationship_deltas[request_id]
	_relationship_deltas.erase(request_id)
	return delta.duplicate(true)


func take_cited_memory_ids(request_id: int) -> Array[String]:
	if not _cited_memory_ids.has(request_id):
		return []
	var ids: Array = _cited_memory_ids[request_id]
	_cited_memory_ids.erase(request_id)
	var result: Array[String] = []
	for item in ids:
		var mem_id := str(item).strip_edges()
		if mem_id != "":
			result.append(mem_id)
	return result


func take_reply_contract(request_id: int) -> Dictionary:
	if not _reply_contracts.has(request_id):
		return {}
	var contract: Dictionary = _reply_contracts[request_id]
	_reply_contracts.erase(request_id)
	return contract.duplicate(true)


func take_response_meta(request_id: int) -> Dictionary:
	if not _response_meta.has(request_id):
		return {}
	var meta: Dictionary = _response_meta[request_id]
	_response_meta.erase(request_id)
	return meta.duplicate(true)


func request_event(event: String, extra: Dictionary = {}) -> int:
	var request_id := _next_request_id
	_next_request_id += 1

	var scripted := ""
	if not is_api_enabled():
		scripted = _get_demo_override(event, extra)
	if scripted != "":
		_pending[request_id] = {"event": event}
		call_deferred("_emit_fallback", request_id, event, scripted)
		return request_id

	var payload := _build_payload(event, extra)
	_pending[request_id] = {
		"event": event,
		"payload": payload,
		"extra": extra,
	}

	if not is_api_enabled():
		var text := _fallback_for_event(event, extra)
		call_deferred("_emit_fallback", request_id, event, text)
		return request_id

	_api_queue.append({"request_id": request_id})
	_pump_api_queue()
	return request_id


func _pump_api_queue() -> void:
	if _in_flight_request_id >= 0 or _api_queue.is_empty():
		return

	while not _api_queue.is_empty():
		var head: Dictionary = _api_queue[0]
		var request_id := int(head.get("request_id", -1))
		if request_id < 0 or not _pending.has(request_id):
			_api_queue.remove_at(0)
			continue
		break

	if _api_queue.is_empty():
		return

	var queue_head: Dictionary = _api_queue[0]
	var request_id := int(queue_head.get("request_id", -1))
	var pending_entry: Dictionary = _pending[request_id]
	var payload: Dictionary = pending_entry.get("payload", {})

	var url := str(_config.get("api_url", "")).strip_edges()
	var headers := _build_headers()
	var body := JSON.stringify(payload)
	var timeout_sec := float(_config.get("timeout_sec", 15.0))
	_http.timeout = timeout_sec

	var err := _http.request(url, headers, HTTPClient.METHOD_POST, body)
	if err != OK:
		_api_queue.remove_at(0)
		var event_name := str(pending_entry.get("event", ""))
		var start_extra: Dictionary = pending_entry.get("extra", {})
		if is_api_enabled():
			_emit_llm_failure(request_id, event_name, "HTTP 请求启动失败: %d" % err, start_extra)
		else:
			_pending.erase(request_id)
			var fallback_text := _fallback_for_event(event_name, start_extra)
			reply_ready.emit(request_id, event_name, fallback_text, true)
		call_deferred("_pump_api_queue")
		return

	_in_flight_request_id = request_id


func _build_payload(event: String, extra: Dictionary) -> Dictionary:
	var stage := StoryDirector.get_effective_stage()
	var memory_context := MemoryService.get_context_for_event(event, extra)
	var relationship := {
		"affection": GameState.affection,
		"bond": GameState.bond,
		"mood": GameState.mood,
		"stage": stage,
		"actual_stage": GameState.get_stage(),
		"game_day": GameState.game_day,
		"loop_day": GameState.get_loop_day(),
		"week_index": GameState.get_week_index(),
	}

	var beat_ctx: Dictionary = extra.get("beat_context", {})
	if beat_ctx.is_empty():
		var ctx_beat_id := str(extra.get("beat_id", "")).strip_edges()
		if ctx_beat_id == "":
			ctx_beat_id = StoryBeatDirector.get_today_beat_id()
		beat_ctx = StoryBeatDirector.get_beat_context_for_llm(ctx_beat_id)
	var payload_beat_id := str(extra.get("beat_id", beat_ctx.get("beat_id", ""))).strip_edges()
	var payload_invite_goal := str(extra.get("proactive_goal", beat_ctx.get("invite_goal", ""))).strip_edges()

	return {
		"event": event,
		"companion_id": str(_config.get("npc_id", "xiaoli")),
		"player_name": GameState.get_player_name_for_llm(),
		"player_name_context": GameState.get_player_name_context(),
		"companion_name": GameState.companion_name,
		"relationship": relationship,
		"persona_card": str(_persona.get("persona_card", "")),
		"stage_tone": _get_stage_tone(stage),
		"story_mode": StoryDirector.get_story_mode(),
		"game_facts": extra.get("game_facts", {}),
		"player_message": str(extra.get("player_message", "")),
		"last_task_summary": GameState.last_task_summary,
		"last_day_summary": GameState.last_day_summary,
		"yesterday_journal": GameState.get_yesterday_journal_entry(),
		"include_yesterday_echo": bool(extra.get("include_yesterday_echo", false)),
		"absence_facts": extra.get("absence_facts", GameState.get_pending_absence_facts()),
		"include_absence_comeback": bool(extra.get("include_absence_comeback", false)),
		"player_quiet": extra.get("player_quiet", RelationshipDirector.get_player_quiet_context()),
		"market": GameState.get_market_snapshot(),
		"weather_today": GameState.weather_today,
		"weather_label": GameState.get_weather_label(),
		"weather_tomorrow_hint": GameState.weather_tomorrow_hint,
		"weather_tomorrow_label": GameState.get_weather_label(GameState.weather_tomorrow_hint),
		"time_of_day": GameState.time_of_day,
		"time_label": GameState.get_time_label(),
		"day_period_label": GameState.get_day_period_label(),
		"awaiting_sleep": GameState.is_awaiting_sleep(),
		"time_context": GameState.get_time_context_for_llm(),
		"memory_context": memory_context,
		"recent_chat_turns": extra.get("recent_chat_turns", GameState.get_recent_chat_turns(8)),
		"chat_timing": GameState.get_chat_timing_context_for_llm(),
		"world_snapshot": extra.get("world_snapshot", WorldSnapshot.capture(extra)),
		"chore_facts": ChoreOrchestrator.get_chore_facts(),
		"companion_profile": WorldSnapshot.get_companion_profile(),
		"story_hint": _resolve_story_hint(event, extra),
		"story_context": StoryDirector.get_story_context_for_llm(),
		"worldview_brief": StoryDirector.get_worldview_brief(),
		"story_beat": extra.get("story_beat", {}),
		"react_type": str(extra.get("react_type", "")),
		"react_facts": extra.get("react_facts", {}),
		"local_parsed_intent": extra.get("parsed_intent", {}),
		"needs_intent_fallback": bool(extra.get("needs_intent_fallback", false)),
		"allowed_intents": _allowed_intent_names(),
		"intent_instruction": _player_chat_intent_instruction(),
		"response_format": "json",
		"journal_entry": extra.get("journal_entry", {}),
		"today_chat_log": extra.get("today_chat_log", []),
		"journal_game_day": int(extra.get("game_day", GameState.game_day)),
		"feed_item": extra.get("feed_item", {}),
		"refused": bool(extra.get("refused", false)),
		"previous_feed_replies": extra.get("previous_replies", []),
		"feed_pester_count": int(extra.get("pester_count", 0)),
		"personal_snippet": str(extra.get("personal_snippet", "")),
		"render_kind": str(extra.get("render_kind", "")),
		"step_template": str(extra.get("step_template", "")),
		"sprout_tier": int(extra.get("sprout_tier", 0)),
		"sprout_word": str(extra.get("sprout_word", "")),
		"proactive_intent": str(extra.get("proactive_intent", "")),
		"proactive_goal": str(extra.get("proactive_goal", "")),
		"invite_remind": bool(extra.get("invite_remind", false)),
		"beat_id": payload_beat_id,
		"beat_label": str(extra.get("beat_label", beat_ctx.get("node_label", ""))),
		"beat_emotion": str(extra.get("beat_emotion", beat_ctx.get("emotion", ""))),
		"beat_context": beat_ctx,
		"affection_tier": str(beat_ctx.get("affection_tier", GameState.get_affection_tier())),
		"invite_tone": str(beat_ctx.get("invite_tone", "")),
		"invite_goal": payload_invite_goal,
		"leak_context": extra.get("leak_context", {}),
		"seen_nodes": extra.get("seen_nodes", []),
		"previous_proactive": extra.get("previous_proactive", extra.get("previous_lines", [])),
		"player_memories": extra.get("player_memories", []),
	}


func _allowed_intent_names() -> Array[String]:
	return [
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


func _player_chat_intent_instruction() -> String:
	return (
		"请同时返回自然语言 reply 与结构化字段。"
		+ "reply 必须先正面回应玩家刚才说的话，不要无视原话去报田况/行情。"
		+ "JSON：reply(字符串)、intent(枚举)、plot_id(整数，默认-1)、confidence(0~1)、"
		+ "affection_delta(整数 -2~3)、bond_delta(整数 0~2)、memory_recovery_delta(0~0.03)、"
		+ "cited_memory_ids(字符串数组，可选；仅可引用系统提供的 #id，无引用则 [])、"
		+ "actions(数组，每轮最多1条：follow_player / walk_poi / open_notebook；农事仍用 intent)、"
		+ "relationship_reason(字符串)。"
		+ "玩家委托做事时返回对应 action intent：浇水 water/water_all，种萝卜 plant/plant_all，收萝卜 harvest/harvest_all，"
		+ "去商店 open_shop，出售萝卜 open_market 等。"
		+ "卖萝卜可以代做；种萝卜可以 plant，不要 refuse plant。"
		+ "world_snapshot 含 shop/inventory/plot_details 与 time_context（局内第几天、白天/傍晚/夜晚），请据此回答；不要编造购买、种植、浇水、收获等未在 game_facts 中发生的事。"
		+ "回复须符合 time_context.day_period_label 所示局内时段，勿把夜晚说成清晨，勿把傍晚说成深夜。"
		+ "代买种子时游戏会另问数量并自动执行，reply 不要声称已购买、已花费金币、已种好或已浇完。"
		+ "若口头答应去浇/种/收/买种子/出售/睡觉，请同时返回对应 action intent 或 plan 数组，便于游戏执行。"
		+ "多步委托（收然后卖再买）必须 plan:[\"harvest_all\",\"sell_turnips\",\"shop_buy_seeds\"] 且 intent=chat。"
		+ "「剩下的钱全买/尽量多买种子」时 open_shop 或 plan 中 shop_buy_seeds 须 max_gold:true。"
		+ "「所有萝卜全卖/都卖掉」须 open_market 或 plan 含 sell_turnips。"
		+ "卖萝卜必须 open_market/plan 含 sell_turnips，禁止误判为 harvest。"
		+ "禁止在 reply 中陈述 chore_facts 里没有的：卖了多少、金币数、种子位置。"
		+ "玩家说睡觉/晚安/休息/下一天：必须 intent=sleep，先答应休息，禁止转去报田况或推销浇水。"
		+ "玩家问田况/熟了没/能不能收：必须 intent=check_status，禁止误判为 sleep。"
		+ "讨论浇田或商店、尚未明确委托时用 chat；明确让你去浇/种/收/买才用 action。"
		+ "禁止在 reply 中提及「点击」「点农田」「派活」等 UI 操作；用「要不要我帮你浇/种/收」自然询问。"
		+ "主动说话必须符合你现在的位置和正在做的事，禁止报行情。"
		+ "玩家说来/过来/跟我走：intent=chat 且 actions=[{\"id\":\"follow_player\"}]。"
		+ "玩家说去廊下/树洞/田边/门口：intent=chat 且 actions=[{\"id\":\"walk_poi\",\"poi\":\"porch|hollow|field|home\"}]。"
		+ "浇种收买睡不要再叠走路 actions。"
	)


func _resolve_story_hint(event: String, extra: Dictionary) -> String:
	if extra.has("story_hint"):
		return str(extra.get("story_hint", ""))
	if event == "session_start" and bool(extra.get("include_absence_comeback", false)):
		var absence_facts: Variant = extra.get("absence_facts", {})
		if absence_facts is Dictionary:
			return StoryDirector.get_absence_hint(absence_facts)
	return StoryDirector.get_story_hint()


func _get_stage_tone(stage: String) -> String:
	var base := ""
	var stages: Variant = _persona.get("stages", {})
	if stages is Dictionary and stages.has(stage):
		var stage_data: Dictionary = stages[stage]
		base = str(stage_data.get("tone", ""))
	elif stage == "awaken" and stages is Dictionary and stages.has("bond"):
		base = str(stages["bond"].get("tone", ""))
	var phase := _get_phase_tone()
	if phase == "":
		return base
	if base == "":
		return phase
	return "%s · %s" % [base, phase]


## D1～D3 亲密度还低，关系阶段会给出「拘谨」调，会把前期该有的贫嘴压没。
## 这里按叙事相位覆盖：D4 起交回 story_mode（陌生化 / 渗漏 / 觉醒）。
func _get_phase_tone() -> String:
	if not GameState.IS_TEN_DAY_EDITION:
		return ""
	if StoryDirector.get_story_mode() != "normal" or GameState.game_day > 3:
		return ""
	return "前期基调：贫嘴，带点小腹黑——占廊下干处还说是给他留的、蹭吃的先夸再要、被戳穿就拿「我记性不好」耍赖，占完自己先心虚地笑一下。玩笑短、冷、一句就收，不油不梗。她是真的会忘，不许演成装傻。"


func _build_headers() -> PackedStringArray:
	var headers := PackedStringArray(["Content-Type: application/json"])
	var api_key := str(_config.get("api_key", "")).strip_edges()
	if api_key != "":
		headers.append("Authorization: Bearer %s" % api_key)
	return headers


func _run_fallback_async(request_id: int, event: String, extra: Dictionary) -> void:
	var delay := float(_config.get("mock_delay_sec", 0.4))
	var text := _fallback_for_event(event, extra)
	if delay <= 0.0:
		call_deferred("_emit_fallback", request_id, event, text)
		return
	_fallback_after_delay(request_id, event, text, delay)


func _fallback_after_delay(request_id: int, event: String, text: String, delay: float) -> void:
	await get_tree().create_timer(delay).timeout
	if not _pending.has(request_id):
		return
	_pending.erase(request_id)
	reply_ready.emit(request_id, event, text, true)


func _emit_local_fallback(request_id: int, event: String, text: String) -> void:
	if not _pending.has(request_id):
		return
	_pending.erase(request_id)
	reply_ready.emit(request_id, event, text, true)


func _emit_llm_failure(request_id: int, event: String, error: String, extra: Dictionary = {}) -> void:
	_pending.erase(request_id)
	request_failed.emit(request_id, event, error)
	if event in SILENT_FAILURE_EVENTS:
		return
	var reply := _fallback_for_event(event, extra).strip_edges()
	if reply == "" and event in ["player_chat", "session_start", "task_complete", "day_end"]:
		reply = LLM_FAILURE_REPLY
	if reply != "":
		reply_ready.emit(request_id, event, reply, true)


func _emit_fallback(request_id: int, event: String, text: String) -> void:
	_emit_local_fallback(request_id, event, text)


func _fallback_for_event(event: String, extra: Dictionary) -> String:
	var stage := GameState.get_stage()
	var memory_context := MemoryService.get_context_for_event(event, extra)
	match event:
		"session_start":
			return NpcFallback.greet(
				stage,
				GameState.game_day,
				GameState.affection,
				GameState.get_weather_label(),
				memory_context,
				GameState.get_time_label(),
				GameState.get_yesterday_journal_summary(),
				bool(extra.get("include_yesterday_echo", false)),
				bool(extra.get("include_absence_comeback", false)),
				extra.get("absence_facts", {})
			)
		"task_complete":
			var facts: Dictionary = extra.get("game_facts", {})
			return NpcFallback.task_complete(facts, GameState.get_market_snapshot())
		"player_chat":
			var parsed_intent: Dictionary = extra.get("parsed_intent", {})
			return NpcFallback.player_chat(
				str(extra.get("player_message", "")),
				stage,
				memory_context,
				parsed_intent
			)
		"companion_react":
			var snapshot: Dictionary = extra.get("world_snapshot", WorldSnapshot.capture(extra))
			return NpcFallback.companion_react(
				str(extra.get("react_type", "")),
				snapshot,
				str(extra.get("story_hint", StoryDirector.get_story_hint())),
				stage,
				memory_context
			)
		"story_beat":
			var beat: Dictionary = extra.get("story_beat", {})
			return NpcFallback.story_beat_followup(
				str(beat.get("beat_id", "")),
				str(beat.get("emotion", "")),
				str(beat.get("node_label", "")),
				stage
			)
		"day_end":
			return "今天先到这里，明天见。"
		"morning_sidewrite":
			return _fallback_companion_casual(extra)
		"companion_casual":
			return _fallback_companion_casual(extra)
		"companion_proactive":
			return _fallback_companion_casual(extra)
		"day_journal_summarize":
			return _fallback_day_journal_summarize(extra)
		"companion_feed":
			var feed_item: Dictionary = extra.get("feed_item", {})
			return NpcFallback.companion_feed(
				feed_item,
				extra.get("previous_replies", []),
				bool(extra.get("refused", false)),
				int(extra.get("pester_count", 0))
			)
		"story_step_render":
			return NpcFallback.story_step_render(extra)
		_:
			return "嗯，我在。"


func _fallback_morning_sidewrite(extra: Dictionary) -> String:
	return NpcFallback.ambient_sidewrite(str(extra.get("weather", GameState.weather_today)))


func _fallback_companion_casual(extra: Dictionary) -> String:
	return NpcFallback.proactive_line(extra)


func _fallback_day_journal_summarize(extra: Dictionary) -> String:
	var chat_log: Array = extra.get("today_chat_log", [])
	var journal_entry: Dictionary = extra.get("journal_entry", {})
	var digest := str(journal_entry.get("chat_digest_rule", "")).strip_edges()
	if digest == "":
		digest = _rule_chat_digest_fallback(chat_log)
	return JSON.stringify({
		"chat_summary": digest,
		"companion_feel": "",
		"salience": 0.55,
	})


func _rule_chat_digest_fallback(chat_log: Array) -> String:
	var player_lines: Array[String] = []
	for item in chat_log:
		if not item is Dictionary:
			continue
		if str(item.get("role", "")) != "player":
			continue
		var line := str(item.get("text", "")).strip_edges()
		if line != "":
			player_lines.append(line)
	if player_lines.is_empty():
		return "和小狸聊了几句。"
	if player_lines.size() == 1:
		return "你提到：「%s」" % player_lines[0].substr(0, 42)
	return "你们聊了 %d 句，最后提到：「%s」" % [
		player_lines.size(),
		player_lines[player_lines.size() - 1].substr(0, 36),
	]


func _on_http_completed(
	result: int,
	response_code: int,
	_headers: PackedStringArray,
	body: PackedByteArray
) -> void:
	var request_id := _in_flight_request_id
	_in_flight_request_id = -1

	if not _api_queue.is_empty() and int(_api_queue[0].get("request_id", -1)) == request_id:
		_api_queue.remove_at(0)

	if request_id < 0 or not _pending.has(request_id):
		call_deferred("_pump_api_queue")
		return

	var pending_entry: Dictionary = _pending[request_id]
	var event: String = pending_entry.get("event", "")
	var extra: Dictionary = pending_entry.get("extra", {})
	_pending.erase(request_id)

	if result != HTTPRequest.RESULT_SUCCESS or response_code < 200 or response_code >= 300:
		var err_msg := "API 响应异常 (code=%d, result=%d)" % [response_code, result]
		_emit_llm_failure(request_id, event, err_msg, extra)
		call_deferred("_pump_api_queue")
		return

	var parsed: Variant = JSON.parse_string(body.get_string_from_utf8())
	var player_message := str(extra.get("player_message", ""))
	var api_intent := IntentParser.from_api_response(parsed, player_message)
	if not api_intent.is_empty():
		_chat_intents[request_id] = api_intent
	var rel_delta := _extract_relationship_delta(parsed)
	if not rel_delta.is_empty():
		_relationship_deltas[request_id] = rel_delta
	elif _requires_relationship_delta(event) and _relationship_delta_required():
		push_warning(
			"NpcBridge: API 成功但未返回 affection_delta (event=%s, request=%d)" % [event, request_id]
		)
	_store_response_meta(request_id, parsed)

	if event == "day_journal_summarize":
		var journal_payload := _extract_journal_summary_payload(parsed)
		if journal_payload == "":
			_emit_llm_failure(request_id, event, "日末摘要 JSON 无效", extra)
			call_deferred("_pump_api_queue")
			return
		reply_ready.emit(request_id, event, journal_payload, false)
		call_deferred("_pump_api_queue")
		return

	var reply_text := _extract_reply_text(parsed)
	if reply_text == "" and typeof(parsed) == TYPE_DICTIONARY:
		var data: Dictionary = parsed
		if data.has("reply"):
			reply_text = str(data["reply"]).strip_edges()
	if reply_text.begins_with("{") and reply_text.ends_with("}"):
		var embedded: Variant = JSON.parse_string(reply_text)
		if api_intent.is_empty():
			api_intent = IntentParser.from_api_response(embedded, player_message)
			if not api_intent.is_empty():
				_chat_intents[request_id] = api_intent
		var embedded_reply := _extract_reply_text(embedded)
		if embedded_reply != "":
			reply_text = embedded_reply
		if rel_delta.is_empty():
			rel_delta = _extract_relationship_delta(embedded)
			if not rel_delta.is_empty():
				_relationship_deltas[request_id] = rel_delta

	var pre_sanitize := reply_text.strip_edges()
	reply_text = _finalize_reply_text(parsed, reply_text, event, extra)
	var used_metadata_fallback := _is_internal_metadata_text(pre_sanitize)

	if reply_text == "":
		_emit_llm_failure(request_id, event, "API 返回空回复", extra)
		call_deferred("_pump_api_queue")
		return

	var payload: Dictionary = pending_entry.get("payload", {})
	var cited_ids := _extract_cited_memory_ids(parsed)
	if cited_ids.is_empty() and typeof(parsed) == TYPE_DICTIONARY:
		var embedded: Variant = JSON.parse_string(reply_text) if reply_text.begins_with("{") else null
		if typeof(embedded) == TYPE_DICTIONARY:
			cited_ids = _extract_cited_memory_ids(embedded)
	var validation := ResponseValidator.validate(event, reply_text, payload, cited_ids)
	if not bool(validation.get("ok", false)):
		if event == "companion_feed":
			var fallback_text := _fallback_for_event(event, extra)
			reply_ready.emit(request_id, event, fallback_text, true)
			call_deferred("_pump_api_queue")
			return
		var reason := str(validation.get("reason", ""))
		if reason in ["literary", "action_mismatch", "l3_episodic", "awkward_waiting", "weather_mismatch", "chat_timing", "repetitive"]:
			var literary_fallback := _fallback_for_event(event, extra)
			reply_ready.emit(request_id, event, literary_fallback, true)
			call_deferred("_pump_api_queue")
			return
		if reason in ["stranger_ooc", "stranger_name", "stranger_intimate", "bad_citation", "name_locked"]:
			if event in ResponseValidator.STORY_MODE_EVENTS:
				var stranger_fallback := _fallback_for_event(event, extra)
				reply_ready.emit(request_id, event, stranger_fallback, true)
				call_deferred("_pump_api_queue")
				return
		_emit_llm_failure(request_id, event, "响应被校验层拦截: %s" % reason, extra)
		call_deferred("_pump_api_queue")
		return

	if event == "player_chat" and not cited_ids.is_empty():
		var citation := MemoryService.validate_citations(cited_ids, str(payload.get("story_mode", "")))
		var allowed: Array = citation.get("allowed_ids", [])
		if not allowed.is_empty():
			_cited_memory_ids[request_id] = allowed.duplicate()

	if event == "player_chat":
		_store_reply_contract(request_id, parsed, str(validation.get("text", reply_text)), cited_ids)

	reply_ready.emit(request_id, event, str(validation.get("text", reply_text)), used_metadata_fallback)
	call_deferred("_pump_api_queue")


func is_request_in_flight() -> bool:
	return _in_flight_request_id >= 0 or not _api_queue.is_empty()


func _requires_relationship_delta(event: String) -> bool:
	return event in ["player_chat", "story_beat"]


func _relationship_delta_required() -> bool:
	return bool(_config.get("require_relationship_delta", true))


func _store_response_meta(request_id: int, parsed: Variant) -> void:
	if typeof(parsed) != TYPE_DICTIONARY:
		return
	var data: Dictionary = parsed
	if data.has("data") and data["data"] is Dictionary:
		data = data["data"]
	var source := str(data.get("_source", "")).strip_edges()
	if source.is_empty():
		return
	var meta := {"source": source}
	if data.has("_fallback_reason"):
		meta["fallback_reason"] = str(data.get("_fallback_reason", ""))
	_response_meta[request_id] = meta


func _extract_journal_summary_payload(parsed: Variant) -> String:
	var source: Dictionary = {}
	if typeof(parsed) == TYPE_DICTIONARY:
		source = parsed
		if source.has("data") and source["data"] is Dictionary:
			source = source["data"]
	if source.has("chat_summary") or source.has("companion_feel") or source.has("salience"):
		return JSON.stringify({
			"chat_summary": str(source.get("chat_summary", "")).strip_edges(),
			"companion_feel": str(source.get("companion_feel", "")).strip_edges(),
			"salience": clampf(float(source.get("salience", 0.55)), 0.0, 1.0),
		})
	var reply := _extract_reply_text(parsed)
	if reply.begins_with("{") and reply.ends_with("}"):
		var embedded: Variant = JSON.parse_string(reply)
		if embedded is Dictionary:
			var data: Dictionary = embedded
			if data.has("chat_summary") or data.has("companion_feel") or data.has("salience"):
				return JSON.stringify({
					"chat_summary": str(data.get("chat_summary", "")).strip_edges(),
					"companion_feel": str(data.get("companion_feel", "")).strip_edges(),
					"salience": clampf(float(data.get("salience", 0.55)), 0.0, 1.0),
				})
	return ""


func _extract_reply_text(parsed: Variant) -> String:
	if typeof(parsed) == TYPE_DICTIONARY:
		var data: Dictionary = parsed
		for key in ["reply", "message", "content", "text"]:
			if data.has(key):
				var candidate := str(data[key]).strip_edges()
				if candidate != "" and not _is_internal_metadata_text(candidate):
					return candidate
		if data.has("data") and data["data"] is Dictionary:
			var inner: Dictionary = data["data"]
			for key in ["reply", "message", "content", "text"]:
				if inner.has(key):
					var candidate := str(inner[key]).strip_edges()
					if candidate != "" and not _is_internal_metadata_text(candidate):
						return candidate
	return ""


func _is_internal_metadata_text(text: String) -> bool:
	var cleaned := text.strip_edges()
	if cleaned == "":
		return false
	var lower := cleaned.to_lower()
	var metadata_markers := [
		"intent:",
		"plot_id:",
		"confidence:",
		"affection_delta:",
		"bond_delta:",
		"memory_recovery_delta:",
		"cited_memory_ids:",
		"relationship_reason:",
	]
	var hits := 0
	for marker in metadata_markers:
		if marker in lower:
			hits += 1
	if hits >= 2:
		return true
	if hits >= 1:
		var has_cjk := false
		for i in range(cleaned.length()):
			var code := cleaned.unicode_at(i)
			if code >= 0x4E00 and code <= 0x9FFF:
				has_cjk = true
				break
		if not has_cjk and cleaned.length() <= 180:
			return true
	return false


func _finalize_reply_text(
	parsed: Variant,
	reply_text: String,
	event: String,
	extra: Dictionary
) -> String:
	var text := reply_text.strip_edges()
	if text != "" and not _is_internal_metadata_text(text):
		return text
	var recovered := _extract_reply_text(parsed).strip_edges()
	if recovered != "" and not _is_internal_metadata_text(recovered):
		return recovered
	if event in ["player_chat", "session_start", "task_complete", "story_beat", "companion_feed"]:
		return _fallback_for_event(event, extra)
	return ""


func _extract_relationship_delta(parsed: Variant) -> Dictionary:
	var source: Dictionary = {}
	if typeof(parsed) == TYPE_DICTIONARY:
		source = parsed
		if source.has("data") and source["data"] is Dictionary:
			source = source["data"]
	var has_delta := (
		source.has("affection_delta")
		or source.has("affectionDelta")
		or source.has("bond_delta")
		or source.has("bondDelta")
		or source.has("memory_recovery_delta")
		or source.has("memoryRecoveryDelta")
	)
	if not has_delta:
		return {}
	var aff := int(source.get("affection_delta", source.get("affectionDelta", 0)))
	var bon := int(source.get("bond_delta", source.get("bondDelta", 0)))
	var rec := float(source.get("memory_recovery_delta", source.get("memoryRecoveryDelta", 0.0)))
	return {
		"affection_delta": clampi(aff, -2, 3),
		"bond_delta": clampi(bon, 0, 2),
		"memory_recovery_delta": clampf(rec, 0.0, 0.05),
		"relationship_reason": str(source.get("relationship_reason", source.get("relationshipReason", ""))),
	}


func _extract_cited_memory_ids(parsed: Variant) -> Array:
	var ids: Array = []
	if typeof(parsed) != TYPE_DICTIONARY:
		return ids
	var source: Dictionary = parsed
	if source.has("data") and source["data"] is Dictionary:
		source = source["data"]
	var raw: Variant = source.get("cited_memory_ids", source.get("citedMemoryIds", []))
	if raw is Array:
		for item in raw:
			var mem_id := str(item).strip_edges()
			if mem_id != "":
				ids.append(mem_id)
	return ids


func _unwrap_response_dict(parsed: Variant) -> Dictionary:
	if typeof(parsed) != TYPE_DICTIONARY:
		return {}
	var source: Dictionary = parsed
	if source.has("data") and source["data"] is Dictionary:
		source = source["data"]
	return source


func _store_reply_contract(request_id: int, parsed: Variant, reply_text: String, cited_ids: Array) -> void:
	var source := _unwrap_response_dict(parsed)
	var intent_key := str(source.get("intent", "chat"))
	var actions := CompanionBodyAction.sanitize_actions(
		source.get("actions", source.get("action", [])),
		intent_key
	)
	_reply_contracts[request_id] = GameState.make_reply_contract(reply_text, {
		"intent": intent_key,
		"plot_id": int(source.get("plot_id", -1)),
		"actions": actions,
		"cited_memory_ids": cited_ids,
	})


func _load_persona() -> void:
	_persona = _load_json_file(PERSONA_PATH)
	if _persona.is_empty():
		push_warning("NpcBridge: 无法加载 persona 文件 %s" % PERSONA_PATH)


func _load_config() -> void:
	if FileAccess.file_exists(CONFIG_USER_PATH):
		_config = _load_json_file(CONFIG_USER_PATH)
	else:
		_config = _load_json_file(CONFIG_RES_PATH)

	if _config.is_empty():
		_config = {
			"enabled": false,
			"api_url": "",
			"api_key": "",
			"npc_id": "xiaoli",
			"timeout_sec": 15.0,
			"mock_delay_sec": 0.4,
			"intent_fallback_enabled": true,
			"intent_classify_url": "",
			"intent_timeout_sec": 8.0,
			"require_relationship_delta": true,
		}


func _load_json_file(path: String) -> Dictionary:
	if not FileAccess.file_exists(path):
		return {}

	var file := FileAccess.open(path, FileAccess.READ)
	if not file:
		return {}

	var parsed: Variant = JSON.parse_string(file.get_as_text())
	file.close()
	if typeof(parsed) == TYPE_DICTIONARY:
		return parsed
	return {}


func _get_demo_override(event: String, extra: Dictionary) -> String:
	var tree := get_tree()
	if tree == null:
		return ""
	var demo := tree.get_first_node_in_group("demo_script")
	if demo == null or not demo.has_method("get_event_override"):
		return ""
	return str(demo.get_event_override(event, extra))
