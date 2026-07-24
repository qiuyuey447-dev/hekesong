extends Node
## 日末 journal：规则底座 + LLM 聊天摘要（XL-C6+）。
## 原则：只存语义摘要，不存聊天原文；anchor 高 salience 才入库，防膨胀。

signal journal_enriched(day: int, used_fallback: bool)

const KIND_PRIORITY := {
	"story_beat": 100,
	"promise": 92,
	"promise_done": 90,
	"absence": 88,
	"harvest": 75,
	"gift": 70,
	"task_water": 65,
	"trade_sell": 60,
	"trade_buy": 45,
	"plant": 40,
	"chat": 25,
	"day_end": 0,
}

const MAX_CHAT_SUMMARY_LEN := 120
const MAX_COMPANION_FEEL_LEN := 80
const MAX_HIGHLIGHTS := 4
const ANCHOR_SALIENCE_MIN := 0.72
const MAX_CHAT_TURNS_FOR_LLM := 12

var _pending_journal_days: Dictionary = {}


func _ready() -> void:
	NpcBridge.reply_ready.connect(_on_npc_reply_ready)
	NpcBridge.request_failed.connect(_on_npc_request_failed)


func _on_npc_request_failed(request_id: int, event: String, _error: String) -> void:
	if event != "day_journal_summarize":
		return
	if not _pending_journal_days.has(request_id):
		return
	_pending_journal_days.erase(request_id)


func build_entry(weather: String) -> Dictionary:
	var day := GameState.game_day
	var events := _collect_today_events(day)
	var chat_log := GameState.snapshot_today_chat_log()
	var highlights := _build_highlights(events)
	var chat_digest_rule := _rule_chat_digest(chat_log)
	if chat_digest_rule.strip_edges() != "":
		highlights = _append_unique_highlight(highlights, "聊天 · %s" % chat_digest_rule)
	var tags := _build_tags(events, weather, chat_log)
	var summary := _compose_summary(weather, highlights, tags)
	return {
		"day": day,
		"week_index": GameState.get_week_index(),
		"loop_day": GameState.get_loop_day(),
		"weather": weather,
		"summary": summary,
		"highlights": highlights,
		"tags": tags,
		"facts": _build_facts(events, weather, chat_log),
		"chat_turns": chat_log.size(),
		"chat_digest_rule": chat_digest_rule,
		"chat_enriched": false,
	}


func request_llm_enrich(entry: Dictionary, chat_log: Array) -> void:
	var day := int(entry.get("day", -1))
	if day < 0 or chat_log.is_empty():
		return
	if StoryDirector.is_stranger_mode():
		_apply_rule_enrichment(day, str(entry.get("chat_digest_rule", "")))
		return
	if not NpcBridge.is_api_enabled():
		_apply_rule_enrichment(day, str(entry.get("chat_digest_rule", "")))
		return
	var request_id := NpcBridge.request_event("day_journal_summarize", {
		"journal_entry": entry.duplicate(true),
		"today_chat_log": _trim_chat_log(chat_log),
		"game_day": day,
	})
	_pending_journal_days[request_id] = day


func apply_enrichment(day: int, data: Dictionary, used_fallback: bool = false) -> void:
	var chat_summary := _sanitize_text(str(data.get("chat_summary", "")), MAX_CHAT_SUMMARY_LEN)
	var companion_feel := _sanitize_text(str(data.get("companion_feel", "")), MAX_COMPANION_FEEL_LEN)
	var salience := clampf(float(data.get("salience", 0.55)), 0.0, 1.0)

	if chat_summary == "" and companion_feel == "":
		var entry := GameState.get_day_journal_entry(day)
		var fallback := str(entry.get("chat_digest_rule", "")).strip_edges()
		if fallback != "":
			chat_summary = fallback
			salience = 0.55
		else:
			return

	var entry := GameState.get_day_journal_entry(day)
	if entry.is_empty():
		return

	var highlights: Array = entry.get("highlights", [])
	if highlights is not Array:
		highlights = []
	highlights = highlights.duplicate()
	var cleaned_highlights: Array = []
	for raw in highlights:
		var line := str(raw).strip_edges()
		if line.begins_with("聊天 ·"):
			continue
		cleaned_highlights.append(line)
	highlights = cleaned_highlights
	if chat_summary != "":
		highlights = _append_unique_highlight(highlights, "聊天 · %s" % chat_summary)
	while highlights.size() > MAX_HIGHLIGHTS:
		highlights.pop_back()

	var weather := str(entry.get("weather", GameState.weather_today))
	var tags: Array = entry.get("tags", [])
	if tags is not Array:
		tags = []
	if "chat" not in tags:
		tags.append("chat")

	var patch := {
		"highlights": highlights,
		"summary": _compose_summary(weather, highlights, tags),
		"tags": tags,
		"chat_summary": chat_summary,
		"chat_enriched": true,
		"chat_salience": salience,
		"chat_enriched_fallback": used_fallback,
	}
	if companion_feel != "":
		patch["companion_feel"] = companion_feel

	GameState.patch_day_journal_entry(day, patch)

	if (
		not used_fallback
		and not StoryDirector.is_stranger_mode()
		and salience >= ANCHOR_SALIENCE_MIN
		and chat_summary != ""
	):
		GameState.record_memory_event(
			"journal_chat",
			chat_summary,
			salience,
			{
				"game_day": day,
				"week_index": int(entry.get("week_index", GameState.get_week_index())),
				"loop_day": int(entry.get("loop_day", GameState.get_loop_day())),
				"source": "llm_journal",
				"companion_feel": companion_feel,
			}
		)

	if day == GameState.game_day - 1:
		GameState.last_day_summary = str(patch.get("summary", GameState.last_day_summary))

	GameState.save_game()
	journal_enriched.emit(day, used_fallback)


func _apply_rule_enrichment(day: int, chat_digest_rule: String) -> void:
	if chat_digest_rule.strip_edges() == "":
		return
	apply_enrichment(day, {
		"chat_summary": chat_digest_rule,
		"companion_feel": "",
		"salience": 0.55,
	}, true)


func _on_npc_reply_ready(request_id: int, event: String, text: String, used_fallback: bool) -> void:
	if event != "day_journal_summarize":
		return
	if not _pending_journal_days.has(request_id):
		return
	var day := int(_pending_journal_days[request_id])
	_pending_journal_days.erase(request_id)

	var data := _parse_enrichment_payload(text)
	if data.is_empty():
		if not NpcBridge.is_api_enabled():
			var entry := GameState.get_day_journal_entry(day)
			_apply_rule_enrichment(day, str(entry.get("chat_digest_rule", "")))
		return
	apply_enrichment(day, data, used_fallback and not NpcBridge.is_api_enabled())


func _parse_enrichment_payload(text: String) -> Dictionary:
	var cleaned := text.strip_edges()
	if cleaned == "":
		return {}
	var parsed: Variant = JSON.parse_string(cleaned)
	if parsed is Dictionary:
		return parsed
	var start := cleaned.find("{")
	var end := cleaned.rfind("}")
	if start >= 0 and end > start:
		parsed = JSON.parse_string(cleaned.substr(start, end - start + 1))
		if parsed is Dictionary:
			return parsed
	return {}


func _trim_chat_log(chat_log: Array) -> Array[Dictionary]:
	var result: Array[Dictionary] = []
	var start := maxi(0, chat_log.size() - MAX_CHAT_TURNS_FOR_LLM)
	for i in range(start, chat_log.size()):
		var item: Variant = chat_log[i]
		if not item is Dictionary:
			continue
		var role := str(item.get("role", "player"))
		var line := str(item.get("text", "")).strip_edges()
		if line == "":
			continue
		result.append({"role": role, "text": line.substr(0, 120)})
	return result


func _rule_chat_digest(chat_log: Array) -> String:
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
		return ""
	if player_lines.size() == 1:
		return "你提到：「%s」" % _truncate(player_lines[0], 42)
	return "你们聊了 %d 句，最后提到：「%s」" % [
		player_lines.size(),
		_truncate(player_lines[player_lines.size() - 1], 36),
	]


func _collect_today_events(game_day: int) -> Array[Dictionary]:
	var week := GameState.get_week_index()
	var loop := GameState.get_loop_day()
	var events: Array[Dictionary] = []
	for raw in GameState.short_term_memory:
		if not raw is Dictionary:
			continue
		var event: Dictionary = raw
		if str(event.get("kind", "")) == "day_end":
			continue
		var event_day := int(event.get("game_day", -1))
		if event_day == game_day:
			events.append(event.duplicate(true))
			continue
		if event_day < 0 and int(event.get("week_index", -1)) == week and int(event.get("loop_day", -1)) == loop:
			events.append(event.duplicate(true))
	return events


func _build_highlights(events: Array[Dictionary]) -> Array[String]:
	var sorted := events.duplicate()
	sorted.sort_custom(func(a: Dictionary, b: Dictionary) -> bool:
		var pa := int(KIND_PRIORITY.get(str(a.get("kind", "")), 10))
		var pb := int(KIND_PRIORITY.get(str(b.get("kind", "")), 10))
		if pa != pb:
			return pa > pb
		return float(a.get("importance", 0.0)) > float(b.get("importance", 0.0))
	)
	var highlights: Array[String] = []
	var used_kinds: Dictionary = {}
	for event in sorted:
		var kind := str(event.get("kind", ""))
		if kind in used_kinds:
			continue
		var line := _highlight_line(event)
		if line.strip_edges() == "":
			continue
		highlights.append(line)
		used_kinds[kind] = true
		if highlights.size() >= 3:
			break
	if highlights.is_empty() and GameState.last_task_summary.strip_edges() != "":
		highlights.append(GameState.last_task_summary.strip_edges())
	return highlights


func _append_unique_highlight(highlights: Array, line: String) -> Array:
	var result: Array = highlights.duplicate()
	var cleaned := line.strip_edges()
	if cleaned == "":
		return result
	for existing in result:
		if str(existing) == cleaned:
			return result
	result.insert(0, cleaned)
	while result.size() > MAX_HIGHLIGHTS:
		result.pop_back()
	return result


func _highlight_line(event: Dictionary) -> String:
	var kind := str(event.get("kind", ""))
	var summary := str(event.get("summary", "")).strip_edges()
	var facts: Dictionary = event.get("facts", {}) if event.get("facts", {}) is Dictionary else {}
	match kind:
		"story_beat":
			var node := str(facts.get("node", ""))
			var emotion := ""
			if " · " in summary:
				var tail := summary.split(" · ")
				if tail.size() >= 2:
					emotion = str(tail[tail.size() - 1])
			if node != "" and emotion != "":
				return "主线 · %s（%s）" % [node, emotion]
			return _strip_brackets(summary)
		"promise":
			return "立下约定：%s" % _after_colon(summary, "约定：")
		"promise_done":
			return "兑现约定：%s" % summary.strip_edges().trim_prefix("我记得").strip_edges()
		"harvest":
			return "收获了萝卜"
		"plant":
			return "在田里种下萝卜"
		"task_water":
			return summary if summary != "" else "和小狸一起浇了田"
		"gift":
			return summary if summary != "" else "给小狸投喂了零食"
		"trade_sell":
			return summary if summary != "" else "去集市卖了萝卜"
		"trade_buy":
			return summary if summary != "" else "补买了种子"
		"absence":
			return summary
		"chat":
			if float(event.get("importance", 0.0)) >= 0.75:
				return "聊到了重要的事"
			return ""
		_:
			return summary


func _compose_summary(weather: String, highlights: Array, tags: Array) -> String:
	var weather_label := GameState.get_weather_label(weather)
	if highlights.is_empty():
		return "第 %d 天，%s，打理了农场。" % [GameState.game_day, weather_label]
	var body := "；".join(highlights)
	return "第 %d 天，%s，%s。" % [GameState.game_day, weather_label, body]


func _build_tags(events: Array[Dictionary], weather: String, chat_log: Array) -> Array[String]:
	var tags: Array[String] = []
	if weather == GameState.WEATHER_RAIN:
		tags.append("rain")
	if not chat_log.is_empty() and "chat" not in tags:
		tags.append("chat")
	for event in events:
		var kind := str(event.get("kind", ""))
		match kind:
			"story_beat":
				if "story" not in tags:
					tags.append("story")
			"promise", "promise_done":
				if "promise" not in tags:
					tags.append("promise")
			"harvest":
				if "harvest" not in tags:
					tags.append("harvest")
			"plant":
				if "farm" not in tags:
					tags.append("farm")
			"task_water":
				if "water" not in tags:
					tags.append("water")
			"gift":
				if "gift" not in tags:
					tags.append("gift")
			"trade_sell", "trade_buy":
				if "trade" not in tags:
					tags.append("trade")
	if tags.is_empty():
		tags.append("daily")
	return tags


func _build_facts(events: Array[Dictionary], weather: String, chat_log: Array) -> Dictionary:
	var facts := {
		"weather": weather,
		"affection": GameState.affection,
		"bond": GameState.bond,
		"turnip_count": GameState.get_item_count("turnip"),
		"chat_turns_today": chat_log.size(),
	}
	for event in events:
		var kind := str(event.get("kind", ""))
		if kind == "story_beat":
			var payload: Dictionary = event.get("facts", {}) if event.get("facts", {}) is Dictionary else {}
			facts["story_node"] = str(payload.get("node", ""))
			facts["beat_id"] = str(payload.get("beat_id", ""))
			break
	return facts


func _sanitize_text(text: String, max_len: int) -> String:
	var cleaned := text.strip_edges()
	if cleaned.length() <= max_len:
		return cleaned
	return cleaned.substr(0, max_len).strip_edges() + "…"


func _truncate(text: String, max_len: int) -> String:
	if text.length() <= max_len:
		return text
	return text.substr(0, max_len).strip_edges() + "…"


func _strip_brackets(text: String) -> String:
	var cleaned := text.strip_edges()
	if cleaned.begins_with("[") and "]" in cleaned:
		var end := cleaned.find("]")
		if end >= 0 and end + 1 < cleaned.length():
			cleaned = cleaned.substr(end + 1).strip_edges()
	return cleaned


func _after_colon(text: String, marker: String) -> String:
	var idx := text.find(marker)
	if idx >= 0:
		return text.substr(idx + marker.length()).strip_edges()
	return text.strip_edges()
