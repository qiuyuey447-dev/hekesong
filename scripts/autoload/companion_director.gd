extends Node
## 小狸主动发言：只决定「这时该不该开口」。
## 说什么一律交给大模型，按该玩家的节点、渗漏锚点、亲密度现写。

const CONSIDER_DELAY := 1.7
const IDLE_CONSIDER_SECONDS := 22.0
const MAX_DAY := 2

var _idle_seconds: float = 0.0
var _consider_tween: Tween = null
var _consider_reason: String = "idle"


func _ready() -> void:
	GameState.time_changed.connect(_on_time_changed)
	GameState.day_advanced.connect(_on_day_advanced)
	GameState.companion_world_event.connect(_on_world_event)


func _process(delta: float) -> void:
	if GameState.is_story_complete():
		return
	if TaskSystem.is_busy() or GameState.is_night():
		return
	_idle_seconds += delta
	if _idle_seconds >= IDLE_CONSIDER_SECONDS:
		_idle_seconds = 0.0
		schedule_consider(0.2, "idle")


func notify_player_active() -> void:
	_idle_seconds = 0.0


func schedule_consider(delay: float = CONSIDER_DELAY, reason: String = "idle") -> void:
	if GameState.is_story_complete():
		return
	_consider_reason = reason
	if _consider_tween != null and _consider_tween.is_valid():
		_consider_tween.kill()
	_consider_tween = create_tween()
	_consider_tween.tween_interval(maxf(delay, 0.05))
	_consider_tween.tween_callback(_emit_consider)


func _emit_consider() -> void:
	var tree := get_tree()
	if tree == null:
		return
	tree.call_group("main_ui", "deliver_companion_proactive")


func pick_speech() -> Dictionary:
	if GameState.is_story_complete():
		return {}
	if TaskSystem.is_busy():
		return {}

	if GameState.proactive_period_used():
		return {}
	if GameState.proactive_count_today() >= MAX_DAY:
		return {}

	if GameState.can_proactive_speech("leak"):
		var leak_ctx := LeakageEngine.peek_leak_context()
		if not leak_ctx.is_empty():
			return {
				"channel": "leak",
				"line": "",
				"beat_id": "",
				"leak_context": leak_ctx,
			}

	if _should_offer_casual(_consider_reason):
		return {
			"channel": "casual",
			"line": "",
			"beat_id": "",
			"leak_context": LeakageEngine.peek_leak_context(),
		}
	return {}


func collect_llm_extra(speech: Dictionary) -> Dictionary:
	var channel := str(speech.get("channel", "casual")).strip_edges()
	var beat_id := str(speech.get("beat_id", "")).strip_edges()
	var leak_raw: Variant = speech.get("leak_context", {})
	var leak_ctx: Dictionary = leak_raw if leak_raw is Dictionary else {}
	if leak_ctx.is_empty():
		leak_ctx = LeakageEngine.peek_leak_context()
	var beat_def := StoryRouteData.get_beat_def(beat_id) if beat_id != "" else {}
	var beat_ctx: Dictionary = speech.get("beat_context", {})
	if beat_ctx.is_empty():
		if beat_id == "":
			beat_id = str(StoryBeatDirector.get_today_beat_id()).strip_edges()
		beat_ctx = StoryBeatDirector.get_beat_context_for_llm(beat_id)
	elif beat_id == "":
		beat_id = str(beat_ctx.get("beat_id", "")).strip_edges()
	if beat_id != "" and beat_def.is_empty():
		beat_def = StoryRouteData.get_beat_def(beat_id)
	var previous: Array = GameState.get_recent_initiation_lines(8)
	for turn in GameState.get_recent_chat_turns(12):
		if not turn is Dictionary:
			continue
		if str(turn.get("role", "")) != "companion":
			continue
		var line := str(turn.get("text", "")).strip_edges()
		if line != "":
			previous.append(line)
	var memories: Array = []
	if not StoryDirector.is_stranger_mode():
		for raw in GameState.get_recent_memories(6):
			if raw is not Dictionary:
				continue
			var summary := str(raw.get("summary", "")).strip_edges()
			if summary != "":
				memories.append({
					"id": str(raw.get("id", "")),
					"kind": str(raw.get("kind", "")),
					"summary": summary,
				})
	return {
		"proactive_intent": channel,
		"proactive_goal": _goal_for(speech, beat_id),
		"invite_remind": bool(speech.get("remind", false)),
		"beat_id": beat_id,
		"beat_label": str(beat_def.get("node_label", "")),
		"beat_emotion": str(beat_def.get("emotion", "")),
		"beat_context": beat_ctx,
		"beat_variant_id": str(beat_ctx.get("variant_id", beat_id)),
		"affection_tier": str(beat_ctx.get("affection_tier", GameState.get_affection_tier())),
		"beat_profile": str(beat_ctx.get("profile", "")),
		"invite_tone": str(beat_ctx.get("invite_tone", "")),
		"invite_goal": str(beat_ctx.get("invite_goal", _goal_for(speech, beat_id))),
		"leak_context": leak_ctx,
		"seen_nodes": GameState.get_story_nodes_seen(),
		"previous_proactive": previous,
		"player_memories": memories,
		"sprout_tier": _sprout_tier(),
		"sprout_word": "",
		"relationship_stage": GameState.get_stage(),
		"story_mode": StoryDirector.get_story_mode(),
		"time_of_day": GameState.time_of_day,
		"time_label": GameState.get_time_label(),
		"day_period_label": GameState.get_day_period_label(),
		"awaiting_sleep": GameState.is_awaiting_sleep(),
		"time_context": GameState.get_time_context_for_llm(),
		"weather": GameState.weather_today,
		"recent_chat_turns": GameState.get_recent_chat_turns(12),
		"companion_location": str(CompanionAgent.get_snapshot().get("location_name", "")),
		"companion_activity": str(CompanionAgent.get_snapshot().get("activity", "")),
	}


func mark_delivered(speech: Dictionary) -> void:
	var channel := str(speech.get("channel", "")).strip_edges()
	if channel == "":
		return
	var extra := {}
	var beat_id := str(speech.get("beat_id", "")).strip_edges()
	if beat_id != "":
		extra["invite_beat"] = beat_id
		extra["pending_invite"] = beat_id
	if bool(speech.get("remind", false)):
		extra["remind"] = true
		if beat_id != "":
			extra["pending_invite"] = beat_id
	if bool(speech.get("also_leak", false)):
		extra["extra_channel"] = "leak"
	GameState.consume_proactive_speech(channel, extra)
	var leak_raw: Variant = speech.get("leak_context", {})
	var leak_ctx: Dictionary = leak_raw if leak_raw is Dictionary else {}
	if channel == "leak" or bool(speech.get("also_leak", false)):
		LeakageEngine.commit_leak_from_context(leak_ctx)
	var line := str(speech.get("line", "")).strip_edges()
	if line != "":
		GameState.record_initiation(channel, {"beat_id": beat_id}, line)


func should_offer_ambient() -> bool:
	return _should_offer_casual("period") and GameState.time_of_day == GameState.TIME_MORNING


func _goal_for(speech: Dictionary, beat_id: String) -> String:
	var written := str(speech.get("invite_goal", "")).strip_edges()
	if written != "":
		return written
	var channel := str(speech.get("channel", ""))
	match channel:
		"invite":
			return StoryBeatDirector.get_invite_goal(beat_id, bool(speech.get("remind", false)))
		"leak":
			return "用这个玩家真实发生过的记忆，写一句身体先记得、脑子还对不上的话。禁止编造锚点里没有的事，禁止念信纸。"
		_:
			return "闲聊。只说你此刻所在的位置和正在做的事。不要报售价、行情、背包、种子包数、叶片或田块数字。不要推销种田。"


func _sprout_tier() -> int:
	var aff := GameState.affection
	if aff >= 60:
		return 3
	if aff >= 40:
		return 2
	if aff >= 20:
		return 1
	return 0


func _should_offer_casual(reason: String) -> bool:
	if not GameState.can_proactive_speech("casual"):
		return false
	if GameState.is_night():
		return false
	var day := GameState.game_day
	if day >= 10:
		return false
	if day == 1 and GameState.time_of_day == GameState.TIME_MORNING:
		return false
	if reason == "period":
		if GameState.time_of_day == GameState.TIME_MORNING:
			return true
		if GameState.time_of_day == GameState.TIME_EVENING:
			return randf() < minf(_casual_chance() + 0.18, 0.95)
		return randf() < _casual_chance()
	return randf() < _casual_chance() * 0.52


func _casual_chance() -> float:
	if StoryDirector.is_stranger_mode():
		return 0.34
	var aff := GameState.affection
	if aff >= 60:
		return 0.88
	if aff >= 40:
		return 0.72
	if aff >= 20:
		return 0.56
	return 0.38


func _on_world_event(_event_type: String, _facts: Dictionary) -> void:
	notify_player_active()


func _on_time_changed(_time_of_day: String) -> void:
	_idle_seconds = 0.0
	schedule_consider(CONSIDER_DELAY, "period")


func _on_day_advanced() -> void:
	_idle_seconds = 0.0
	schedule_consider(CONSIDER_DELAY, "period")
