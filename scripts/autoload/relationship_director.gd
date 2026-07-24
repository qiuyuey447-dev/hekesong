extends Node
## 玩家行为 → 亲密度/默契/结局权重（对话 · 礼物 · 互动 · 节点）。

signal relationship_updated(summary: Dictionary)

const RULES_PATH := "res://config/relationship_rules.json"

var _rules: Dictionary = {}


func _ready() -> void:
	_load_rules()


func _load_rules() -> void:
	if not FileAccess.file_exists(RULES_PATH):
		_rules = _default_rules()
		return
	var file := FileAccess.open(RULES_PATH, FileAccess.READ)
	if not file:
		_rules = _default_rules()
		return
	var parsed: Variant = JSON.parse_string(file.get_as_text())
	file.close()
	if typeof(parsed) == TYPE_DICTIONARY:
		_rules = parsed
	else:
		_rules = _default_rules()


func _default_rules() -> Dictionary:
	return {
		"affection_min": -2,
		"affection_max": 3,
		"bond_min": 0,
		"bond_max": 2,
		"memory_recovery_max": 0.05,
		"daily_chat_affection_cap": 12,
		"base_chat_affection": 1,
		"long_message_chars": 12,
		"long_message_bonus": 1,
		"warm_words": ["谢谢", "辛苦", "记住", "留下", "陪", "慢慢来", "没关系", "对不起", "抱歉"],
		"cold_words": ["滚", "赶走", "烦", "笨", "没用"],
		"memory_words": ["记得", "约定", "忘记", "想起", "回忆"],
		"dismissive_exact": ["哦", "嗯", "行", "好", "ok", "OK", "算了", "随便"],
		"stranger_patience_words": ["我是", "认识", "农场", "留下", "帮工", "没关系", "慢慢"],
		"stranger_impatience_words": ["怎么还不", "又忘了", "烦"],
		"stranger_ooc_phrases": [
			"又见面了", "还记得", "上次你说", "我们约", "一起看过", "欢迎回来", "你来了", "好久不见",
			"上次", "以前我们", "那时候", "我们的约定", "我们的家", "一起浇", "一起种", "一起收",
			"你喂过", "不是第一次", "像家人", "像朋友", "一直在一起", "我记得你", "我们以前",
		],
		"stranger_intimate_phrases": ["想你了", "亲爱的", "宝贝", "乖", "抱抱", "爱你", "好想你"],
		"action_intent_affection_cap": 1,
		"interaction_weights": {
			"chat_days": 0.30, "nodes": 0.28, "affection": 0.12,
			"gifts": 0.12, "nights": 0.10, "tasks": 0.08,
		},
		"interaction_targets": {
			"chat_days": 12, "gifts": 6, "nodes": 18, "nights": 2, "tasks": 10,
		},
	}


func get_rules() -> Dictionary:
	return _rules.duplicate(true)


func get_stranger_ooc_phrases() -> Array[String]:
	return _string_array_rule("stranger_ooc_phrases", _default_stranger_ooc_phrases())


func get_stranger_intimate_phrases() -> Array[String]:
	return _string_array_rule("stranger_intimate_phrases", _default_stranger_intimate_phrases())


func _string_array_rule(key: String, fallback: Array[String]) -> Array[String]:
	var raw: Variant = _rules.get(key, [])
	if raw is Array and not raw.is_empty():
		var result: Array[String] = []
		for item in raw:
			var cleaned := str(item).strip_edges()
			if cleaned != "":
				result.append(cleaned)
		if not result.is_empty():
			return result
	return fallback


func _default_stranger_ooc_phrases() -> Array[String]:
	return [
		"又见面了", "还记得", "上次你说", "我们约", "一起看过", "欢迎回来", "你来了", "好久不见",
		"上次", "以前我们", "那时候", "之前你说", "我们的约定", "我们的家", "一起浇", "一起种",
		"一起收", "你喂过", "你总", "不是第一次", "老朋友", "像家人", "像朋友", "一直在一起",
		"记起来了", "想起来了", "我记得你", "你说过", "我们以前", "约好了",
	]


func _default_stranger_intimate_phrases() -> Array[String]:
	return [
		"想你了", "亲爱的", "宝贝", "乖", "抱抱", "摸摸", "爱你", "好想你", "别走", "一直陪",
	]


func _default_signals() -> Dictionary:
	return {
		"chat_turns": 0,
		"chat_days": 0,
		"last_chat_day": 0,
		"gifts_given": 0,
		"nodes_cleared": 0,
		"tasks_together": 0,
		"llm_affection_net": 0,
		"llm_bond_net": 0,
		"beat_chats": 0,
		"chat_aff_today": 0,
		"chat_aff_day": -1,
	}


func get_signals() -> Dictionary:
	var raw: Variant = GameState.long_term_memory.get("relationship_signals", {})
	if raw is Dictionary:
		return raw.duplicate(true)
	return _default_signals()


func _save_signals(signals: Dictionary) -> void:
	GameState.long_term_memory["relationship_signals"] = signals
	GameState.save_game()
	relationship_updated.emit(get_ending_factors())


func record_player_chat_turn(_player_text: String) -> void:
	var signals := get_signals()
	signals["chat_turns"] = int(signals.get("chat_turns", 0)) + 1
	if GameState.game_day != int(signals.get("last_chat_day", 0)):
		signals["chat_days"] = int(signals.get("chat_days", 0)) + 1
		signals["last_chat_day"] = GameState.game_day
	_save_signals(signals)


func apply_llm_relationship_delta(delta: Dictionary, source: String = "chat") -> void:
	var aff := int(delta.get("affection_delta", 0))
	var bon := int(delta.get("bond_delta", 0))
	var rec := float(delta.get("memory_recovery_delta", 0.0))
	var signals := get_signals()

	if source == "player_chat" and aff > 0:
		aff = _apply_daily_affection_cap(signals, aff)

	if aff != 0:
		GameState.add_affection(aff)
	if bon != 0:
		GameState.add_bond(bon)
	if rec > 0.0:
		GameState.add_memory_recovery(rec)

	if aff == 0 and bon == 0 and rec <= 0.0:
		_save_signals(signals)
		return

	signals["llm_affection_net"] = int(signals.get("llm_affection_net", 0)) + aff
	signals["llm_bond_net"] = int(signals.get("llm_bond_net", 0)) + bon
	if source == "story_beat":
		signals["beat_chats"] = int(signals.get("beat_chats", 0)) + 1
	_save_signals(signals)


func _apply_daily_affection_cap(signals: Dictionary, aff: int) -> int:
	var cap := int(_rules.get("daily_chat_affection_cap", 12))
	var day := GameState.game_day
	if int(signals.get("chat_aff_day", -1)) != day:
		signals["chat_aff_day"] = day
		signals["chat_aff_today"] = 0
	var used := int(signals.get("chat_aff_today", 0))
	var room := cap - used
	if room <= 0:
		return 0
	var applied := mini(aff, room)
	signals["chat_aff_today"] = used + applied
	return applied


func record_gift(_item_id: String) -> void:
	var signals := get_signals()
	signals["gifts_given"] = int(signals.get("gifts_given", 0)) + 1
	_save_signals(signals)
	GameState.add_memory_recovery(0.02)


func record_story_node(_beat_id: String) -> void:
	var signals := get_signals()
	signals["nodes_cleared"] = int(signals.get("nodes_cleared", 0)) + 1
	_save_signals(signals)


func record_task_together() -> void:
	var signals := get_signals()
	signals["tasks_together"] = int(signals.get("tasks_together", 0)) + 1
	_save_signals(signals)


func estimate_local_delta(player_text: String, event: String = "player_chat") -> Dictionary:
	return score_player_message(
		player_text,
		event,
		StoryDirector.get_story_mode(),
		IntentParser.parse(player_text)
	)


func score_player_message(
	text: String,
	event: String,
	story_mode: String,
	parsed_intent: Dictionary = {}
) -> Dictionary:
	var cleaned := text.strip_edges()
	var aff_min := int(_rules.get("affection_min", -2))
	var aff_max := int(_rules.get("affection_max", 3))
	var bon_min := int(_rules.get("bond_min", 0))
	var bon_max := int(_rules.get("bond_max", 2))
	var rec_max := float(_rules.get("memory_recovery_max", 0.05))

	if event == "story_beat":
		return {
			"affection_delta": 0,
			"bond_delta": 0,
			"memory_recovery_delta": 0.0,
			"relationship_reason": "节点搭话，等玩家回应后再计分",
		}

	if cleaned.is_empty():
		return {
			"affection_delta": 0,
			"bond_delta": 0,
			"memory_recovery_delta": 0.0,
			"relationship_reason": "空消息",
		}

	if _is_dismissive(cleaned):
		return {
			"affection_delta": 0,
			"bond_delta": 0,
			"memory_recovery_delta": 0.0,
			"relationship_reason": "敷衍回应",
		}

	var aff := int(_rules.get("base_chat_affection", 1))
	var bon := 0
	var rec := 0.0
	var reason := "普通聊天"

	if cleaned.length() >= int(_rules.get("long_message_chars", 12)):
		aff += int(_rules.get("long_message_bonus", 1))
		reason = "认真回应"

	var warm_hit := _first_word_hit(cleaned, _rules.get("warm_words", []))
	if warm_hit != "":
		aff += 1
		rec += 0.01
		reason = "暖语：%s" % warm_hit

	var cold_hit := _first_word_hit(cleaned, _rules.get("cold_words", []))
	if cold_hit != "":
		aff -= 2
		reason = "冷语：%s" % cold_hit

	var mem_hit := _first_word_hit(cleaned, _rules.get("memory_words", []))
	if mem_hit != "":
		rec += 0.01
		if mem_hit in ["记得", "约定"]:
			aff += 1
		reason = "记忆/承诺：%s" % mem_hit

	if story_mode == "stranger":
		if _any_word_in(cleaned, _rules.get("stranger_patience_words", [])):
			aff = maxi(aff, 2)
			rec += 0.01
			reason = "W2 耐心重新介绍"
		if _any_word_in(cleaned, _rules.get("stranger_impatience_words", [])):
			aff = mini(aff, -1)
			reason = "W2 不耐烦"

	if "？" in cleaned or "?" in cleaned:
		bon += 1

	if IntentParser.is_action_intent(parsed_intent):
		var cap := int(_rules.get("action_intent_affection_cap", 1))
		aff = mini(aff, cap)
		reason = "事务指令"

	aff = clampi(aff, aff_min, aff_max)
	bon = clampi(bon, bon_min, bon_max)
	rec = clampf(rec, 0.0, rec_max)

	return {
		"affection_delta": aff,
		"bond_delta": bon,
		"memory_recovery_delta": rec,
		"relationship_reason": reason,
	}


func _is_dismissive(text: String) -> bool:
	if text.length() <= 2:
		return true
	var lower := text.to_lower()
	for word in _rules.get("dismissive_exact", []):
		var w := str(word).strip_edges()
		if w == "":
			continue
		if text == w or lower == w.to_lower():
			return true
		if text == w + "。" or text == w + "..." or text == w + "…":
			return true
	return false


func _first_word_hit(text: String, words: Variant) -> String:
	if not words is Array:
		return ""
	for word in words:
		var w := str(word)
		if w != "" and w in text:
			return w
	return ""


func _any_word_in(text: String, words: Variant) -> bool:
	return _first_word_hit(text, words) != ""


func get_interaction_score() -> float:
	var s := get_signals()
	var weights: Dictionary = _rules.get("interaction_weights", {})
	var targets: Dictionary = _rules.get("interaction_targets", {})
	var chat_days := int(s.get("chat_days", 0))
	var gifts := int(s.get("gifts_given", 0))
	var nodes := maxi(int(s.get("nodes_cleared", 0)), GameState.get_story_nodes_seen().size())
	var nights := int(GameState.get_ending_flags().get("companionship_nights", 0))
	var tasks := int(s.get("tasks_together", 0))
	var score := 0.0
	score += _weighted_ratio(chat_days, int(targets.get("chat_days", 12)), float(weights.get("chat_days", 0.30)))
	score += _weighted_ratio(gifts, int(targets.get("gifts", 6)), float(weights.get("gifts", 0.12)))
	score += _weighted_ratio(nodes, int(targets.get("nodes", 18)), float(weights.get("nodes", 0.28)))
	score += _weighted_ratio(nights, int(targets.get("nights", 2)), float(weights.get("nights", 0.10)))
	score += _weighted_ratio(tasks, int(targets.get("tasks", 10)), float(weights.get("tasks", 0.08)))
	score += _weighted_ratio(GameState.affection, 100, float(weights.get("affection", 0.12)))
	return clampf(score, 0.0, 1.0)


func _weighted_ratio(value: int, target: int, weight: float) -> float:
	if target <= 0:
		return 0.0
	return clampf(float(value) / float(target), 0.0, 1.0) * weight


func get_ending_factors() -> Dictionary:
	var flags := GameState.get_ending_flags()
	var signals := get_signals()
	return {
		"interaction_score": get_interaction_score(),
		"chat_days": int(signals.get("chat_days", 0)),
		"chat_turns": int(signals.get("chat_turns", 0)),
		"gifts_given": int(signals.get("gifts_given", 0)),
		"nodes_cleared": maxi(
			int(signals.get("nodes_cleared", 0)),
			GameState.get_story_nodes_seen().size()
		),
		"tasks_together": int(signals.get("tasks_together", 0)),
		"companionship_nights": int(flags.get("companionship_nights", 0)),
		"affection": GameState.affection,
		"bond": GameState.bond,
		"memory_recovery": GameState.get_memory_recovery(),
		"fragments": GameState.get_fragment_count(),
		"llm_affection_net": int(signals.get("llm_affection_net", 0)),
		"chat_aff_today": int(signals.get("chat_aff_today", 0)),
		"daily_chat_affection_cap": int(_rules.get("daily_chat_affection_cap", 12)),
	}
