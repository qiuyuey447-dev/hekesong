extends Node
## 小狸主动发言：只决定「这时该不该开口」。
## 说什么一律交给大模型，按该玩家的节点、渗漏锚点、亲密度现写。

const CONSIDER_DELAY := 1.7
const IDLE_CONSIDER_SECONDS := 22.0

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
	if GameState.is_pure_narrative_day():
		return {}
	if TaskSystem.is_busy():
		return {}
	## 当日信纸邀请还没开口：别让渗漏/闲聊抢在前面。邀请说过之后可以回响。
	if StoryBeatDirector.has_unfired_schedule_today():
		var today_id := StoryBeatDirector.get_today_beat_id()
		if today_id == "" or not GameState.was_invite_spoken_for(today_id):
			return {}

	## 主动口先走闲聊。D6–D8 随机把渗漏夹进同一句，不再单独开一场「念本子」。
	var mix_leak := _should_mix_leak()
	var today_beat := StoryBeatDirector.get_today_beat_id()
	if (
		today_beat != ""
		and not StoryBeatDirector.is_beat_seen(today_beat)
		and _should_offer_casual(_consider_reason)
	):
		return _pack_casual_speech(today_beat, mix_leak)

	if _should_offer_casual(_consider_reason):
		return _pack_casual_speech("", mix_leak)

	## 闲聊名额用尽、渗漏还在：仍用闲聊口吻夹半句，不宣读锚点。
	if (
		not GameState.can_proactive_speech("casual")
		and GameState.can_proactive_speech("leak")
		and not LeakageEngine.peek_leak_context().is_empty()
	):
		return _pack_casual_speech("", true)
	return {}


func collect_llm_extra(speech: Dictionary) -> Dictionary:
	var channel := str(speech.get("channel", "casual")).strip_edges()
	var beat_id := str(speech.get("beat_id", "")).strip_edges()
	var also_leak := bool(speech.get("also_leak", false))
	var leak_raw: Variant = speech.get("leak_context", {})
	var leak_ctx: Dictionary = leak_raw if leak_raw is Dictionary else {}
	if channel != "leak" and not also_leak:
		leak_ctx = {}
	elif leak_ctx.is_empty():
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
		"also_leak": also_leak,
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
		"player_quiet": RelationshipDirector.get_player_quiet_context(),
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
	if not GameState.can_proactive_speech("ambient"):
		return false
	if GameState.time_of_day != GameState.TIME_MORNING:
		return false
	if GameState.weather_today != GameState.WEATHER_RAIN:
		return false
	if StoryDirector.is_stranger_mode() or GameState.is_pure_narrative_day():
		return false
	return true


func _goal_for(speech: Dictionary, beat_id: String) -> String:
	var written := str(speech.get("invite_goal", "")).strip_edges()
	if written != "":
		return written
	var channel := str(speech.get("channel", ""))
	var base := ""
	match channel:
		"invite":
			base = StoryBeatDirector.get_invite_goal(beat_id, bool(speech.get("remind", false)))
		"leak":
			base = _leak_slip_goal()
		_:
			base = _casual_talk_goal(beat_id)
			if bool(speech.get("also_leak", false)):
				base += " " + _leak_slip_goal()
	if channel == "invite":
		return base
	return base + _quiet_goal_suffix()


func _casual_talk_goal(beat_id: String) -> String:
	var base := (
		"闲聊：像在场的人随口 1～2 句。话题从眼前生活里挑，不要只会种田——"
		+ "廊下、树洞、河声、水壶、手套、灯、尾巴、发呆、你站那儿的样子都可以。"
		+ "位置只当背景，不必汇报正在种/浇/收。禁止报背包数字，禁止主动问要不要种/浇/收/买种子。"
		+ "禁止念本子、禁止整句复述日记。"
	)
	if beat_id != "" and not StoryBeatDirector.is_beat_seen(beat_id):
		return "轻轻点到今日气氛，但仍是闲聊，不要念信纸。" + base
	return base


func _leak_slip_goal() -> String:
	return (
		"渗漏须夹在闲聊里：把锚点化成感觉、动作、气味或半句口误。"
		+ "禁止宣读本子（本子上写着／我翻到那页／写着「…」），禁止念锚点原文，禁止编造锚点没有的事。"
	)


func _pack_casual_speech(beat_id: String, mix_leak: bool) -> Dictionary:
	var leak_ctx := {}
	var mix := mix_leak
	if mix:
		leak_ctx = LeakageEngine.peek_leak_context()
		if leak_ctx.is_empty() or not GameState.can_proactive_speech("leak"):
			mix = false
			leak_ctx = {}
	var speech := {
		"channel": "casual",
		"line": "",
		"beat_id": beat_id,
		"also_leak": mix,
		"leak_context": leak_ctx,
	}
	if beat_id != "":
		speech["beat_context"] = StoryBeatDirector.get_beat_context_for_llm(beat_id)
	return speech


func _should_mix_leak() -> bool:
	if StoryDirector.get_story_mode() != "leak":
		return false
	if GameState.game_day < 6 or GameState.game_day > 8:
		return false
	if not GameState.can_proactive_speech("leak"):
		return false
	if LeakageEngine.peek_leak_context().is_empty():
		return false
	if _consider_reason == "period":
		if GameState.time_of_day == GameState.TIME_EVENING:
			return randf() < 0.72
		if GameState.time_of_day == GameState.TIME_MORNING:
			return randf() < 0.38
		return randf() < 0.50
	return randf() < 0.45


func _quiet_goal_suffix() -> String:
	var quiet: Dictionary = RelationshipDirector.get_player_quiet_context()
	if not bool(quiet.get("should_nudge", false)):
		return ""
	if StoryDirector.is_stranger_mode():
		return "玩家此刻不说话。轻轻点一句他不吭声，只说眼前，不要提这几天的交往，不要责备。"
	if str(quiet.get("nudge_kind", "")) == "today":
		return "玩家今天还没跟你说过话。可以轻轻点一句，不要催任务，不要责备。"
	return "玩家这几天没主动跟你聊天。可以轻轻说他不怎么开口，像在意不是责怪。"


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
