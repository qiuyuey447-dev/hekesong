extends Node
## 按结局路线调度独立 P 节点（§十二 · 五线分轨）。
## 脊柱节点阻塞过天；肋骨节点按行为门槛触发，可顺延。

const FRAGMENTS: Dictionary = {
	"F01": {"title": "登门", "subtitle": "她请求留下帮工", "unlock_node": "N02p"},
	"F02": {"title": "第一粒种", "subtitle": "在你的田上一起种", "unlock_node": "N14"},
	"F03": {"title": "小狸的本子", "subtitle": "日期乱了——失忆物证", "unlock_node": "N15"},
	"F04": {"title": "傍晚的约定", "subtitle": "你的田，我们一起照看", "unlock_node": "N11p"},
	"F05": {"title": "弄丢的东西", "subtitle": "怕弄丢刚找到的安定", "unlock_node": "N17"},
	"F06": {"title": "你没有赶她走", "subtitle": "明知会忘，仍留她在农场", "unlock_node": "N18p"},
	"F07": {"title": "名字", "subtitle": "让我留下来的那个人", "unlock_node": "N20a"},
	"F08": {"title": "信的第一页", "subtitle": "要对农场主好一点", "unlock_node": "N20b"},
	"F09": {"title": "信的后半", "subtitle": "谢谢你收留我、替我记得", "unlock_node": "N20b"},
	"F10": {"title": "完整的家", "subtitle": "你的农场，她的安顿", "unlock_node": "N20"},
}

const RIB_BEAT_SUFFIXES := ["_N07", "_N16", "_N33"]
const NIGHT_BEAT_SUFFIXES := ["_N14n", "_N17"]
const RIB_DEFER_FORCE_DAYS := {
	"_N07": 2,
	"_N16": 2,
	"_N33": 1,
}

signal story_route_changed(old_route: String, new_route: String)


func get_active_route() -> String:
	if bool(GameState.get_ending_flags().get("w2_chose_expel", false)):
		return StoryRouteData.ROUTE_BAD_EARLY
	if _should_use_prologue_route():
		return StoryRouteData.ROUTE_PROLOGUE
	var locked := GameState.get_story_route()
	if locked != "":
		return locked
	var projected := EndingDirector.resolve_ending(false)
	return StoryRouteData.get_route_for_ending(projected)


func _should_use_prologue_route() -> bool:
	if GameState.game_day > 10:
		return false
	if bool(GameState.get_ending_flags().get("w2_chose_expel", false)):
		return false
	if GameState.game_day <= 9:
		return true
	return not GameState.is_story_node_seen("P_N06p") and not GameState.is_story_node_seen("N06p")


func get_route_label(route: String = "") -> String:
	if route == "":
		route = get_active_route()
	return str(StoryRouteData.ROUTE_LABELS.get(route, route))


func get_today_beat_id() -> String:
	if GameState.is_story_complete():
		return ""
	var route := get_active_route()
	var calendar := StoryRouteData.get_beat_id_for_day(route, GameState.game_day)
	var deferred := GameState.get_deferred_story_beat()
	if deferred != "" and not is_beat_seen(deferred):
		if _beat_gate_satisfied(deferred) or _should_force_deferred(deferred):
			if _calendar_spine_ready(calendar):
				return calendar
			return deferred
	if _calendar_spine_ready(calendar):
		return calendar
	if calendar == "" or is_beat_seen(calendar):
		return ""
	if _is_rib_beat(calendar):
		if _beat_gate_satisfied(calendar) or _should_force_deferred(calendar):
			return calendar
		return ""
	if _is_night_beat(calendar):
		return ""
	return calendar


func get_pending_night_beat_id() -> String:
	var route := get_active_route()
	var calendar := StoryRouteData.get_beat_id_for_day(route, GameState.game_day)
	if calendar == "" or is_beat_seen(calendar) or not _is_night_beat(calendar):
		return ""
	return calendar


func has_pending_night_beat() -> bool:
	return get_pending_night_beat_id() != ""


func can_trigger_night_beat_at_hollow() -> bool:
	if get_pending_night_beat_id() == "":
		return false
	return GameState.time_of_day in [GameState.TIME_EVENING, GameState.TIME_NIGHT]


func get_pending_night_beat(include_yesterday_echo: bool = false) -> Dictionary:
	if not can_trigger_night_beat_at_hollow():
		return {}
	var beat_id := get_pending_night_beat_id()
	if beat_id == "":
		return {}
	return build_beat(beat_id, include_yesterday_echo)


func has_unseen_weekend_night_beat() -> bool:
	if not GameState.is_week_last_day():
		return false
	return has_pending_night_beat()


func has_pending_today_beat() -> bool:
	var beat_id := get_today_beat_id()
	return beat_id != "" and not is_beat_seen(beat_id)


func has_blocking_today_beat() -> bool:
	var beat_id := get_today_beat_id()
	if beat_id == "" or is_beat_seen(beat_id):
		return false
	return not _is_rib_beat(beat_id)


func prepare_day_end() -> void:
	var pending := get_today_beat_id()
	if pending == "" or is_beat_seen(pending):
		return
	if not _is_rib_beat(pending):
		return
	var was_already := GameState.get_deferred_story_beat() == pending
	var from_day := GameState.get_deferred_story_beat_from_day()
	if not was_already or from_day <= 0:
		from_day = _calendar_day_for_beat(pending)
	if from_day <= 0:
		from_day = GameState.game_day
	GameState.set_deferred_story_beat(pending, from_day)
	if was_already:
		return
	var hint := StoryRouteData.render_deferred_journal_hint(pending)
	if hint.strip_edges() != "":
		GameState.record_memory_event(
			"story_hint",
			hint,
			0.55,
			{"beat_id": pending, "game_day": GameState.game_day, "deferred": true}
		)


func get_pending_session_beat(include_yesterday_echo: bool = false) -> Dictionary:
	if GameState.is_story_complete():
		return {}
	var beat_id := get_today_beat_id()
	if beat_id == "" or is_beat_seen(beat_id):
		return {}
	return build_beat(beat_id, include_yesterday_echo)


func get_pending_feed_beat() -> Dictionary:
	if GameState.game_day != 11:
		return {}
	var route := get_active_route()
	if route == StoryRouteData.ROUTE_BAD_EARLY:
		return {}
	var beat_id := StoryRouteData.get_beat_id_for_day(route, 11)
	if beat_id == "" or is_beat_seen(beat_id):
		return {}
	if not _beat_gate_satisfied(beat_id) and not _should_force_deferred(beat_id):
		return {}
	return build_beat(beat_id)


func build_beat(beat_id: String, include_yesterday_echo: bool = false) -> Dictionary:
	var def := StoryRouteData.get_beat_def(beat_id)
	if def.is_empty():
		return {}
	var beat := def.duplicate(true)
	beat["id"] = beat_id
	beat["route"] = get_active_route()
	beat["steps"] = _append_followup_step(
		beat_id,
		_inject_opening_steps(
			beat_id,
			include_yesterday_echo,
			_resolve_steps(beat_id, beat.get("steps", []))
		)
	)
	return beat


func complete_beat(beat_id: String) -> void:
	if GameState.has_pending_absence():
		GameState.mark_absence_shown()
	GameState.mark_story_node_seen(beat_id)
	if GameState.get_deferred_story_beat() == beat_id:
		GameState.clear_deferred_story_beat()
	RelationshipDirector.record_story_node(beat_id)
	var def := StoryRouteData.get_beat_def(beat_id)
	var recovery := float(def.get("recovery", 0.0))
	if recovery > 0.0:
		GameState.add_memory_recovery(recovery)
	var fragment_id := str(def.get("fragment", ""))
	if fragment_id != "":
		GameState.unlock_fragment(fragment_id, beat_id)
	if beat_id.ends_with("_N20b"):
		if get_active_route() != StoryRouteData.ROUTE_BAD:
			GameState.unlock_fragment("F09", beat_id)
	var node_label := str(def.get("node_label", beat_id))
	GameState.record_memory_event(
		"story_beat",
		"[%s] %s · %s" % [get_route_label(), node_label, str(def.get("emotion", ""))],
		0.8,
		{"node": node_label, "beat_id": beat_id, "route": get_active_route(), "game_day": GameState.game_day}
	)


func refresh_story_route() -> void:
	if bool(GameState.get_ending_flags().get("w2_chose_expel", false)):
		GameState.lock_story_route(StoryRouteData.ROUTE_BAD_EARLY)
		return
	if GameState.game_day < 10:
		return
	var old_route := GameState.get_story_route()
	var projected := EndingDirector.resolve_ending(false)
	var route := StoryRouteData.get_route_for_ending(projected)
	GameState.lock_story_route(route)
	if old_route != "" and old_route != route:
		story_route_changed.emit(old_route, route)


func ensure_story_route_locked() -> void:
	if GameState.game_day < 10:
		return
	if not bool(GameState.get_ending_flags().get("w2_choice_made", false)):
		return
	if GameState.get_story_route() != "":
		return
	refresh_story_route()


func is_beat_seen(beat_id: String) -> bool:
	return GameState.is_story_node_seen(beat_id)


func get_fragment_meta(fragment_id: String) -> Dictionary:
	var meta: Variant = FRAGMENTS.get(fragment_id, {})
	if meta is Dictionary:
		return meta.duplicate(true)
	return {}


func get_fragment_display_lines() -> Array[String]:
	var lines: Array[String] = []
	for fid in FRAGMENTS.keys():
		var meta: Dictionary = FRAGMENTS[fid]
		var title := str(meta.get("title", fid))
		var subtitle := str(meta.get("subtitle", "")).strip_edges()
		if GameState.has_fragment(fid):
			if subtitle != "":
				lines.append("✦ %s — %s" % [title, subtitle])
			else:
				lines.append("✦ %s" % title)
		else:
			lines.append("? %s" % title)
	return lines


func _is_rib_beat(beat_id: String) -> bool:
	for suffix in RIB_BEAT_SUFFIXES:
		if beat_id.ends_with(suffix):
			return true
	return false


func _is_night_beat(beat_id: String) -> bool:
	for suffix in NIGHT_BEAT_SUFFIXES:
		if beat_id.ends_with(suffix):
			return true
	return false


func _calendar_spine_ready(calendar: String) -> bool:
	if calendar == "" or is_beat_seen(calendar):
		return false
	if _is_night_beat(calendar):
		return false
	if _is_rib_beat(calendar):
		return false
	return true


func _rib_suffix(beat_id: String) -> String:
	for suffix in RIB_BEAT_SUFFIXES:
		if beat_id.ends_with(suffix):
			return suffix
	return ""


func _should_force_deferred(beat_id: String) -> bool:
	var suffix := _rib_suffix(beat_id)
	if suffix == "":
		return false
	var from_day := GameState.get_deferred_story_beat_from_day()
	if from_day <= 0:
		from_day = _calendar_day_for_beat(beat_id)
	if from_day <= 0:
		return false
	var max_days := int(RIB_DEFER_FORCE_DAYS.get(suffix, 2))
	return GameState.game_day - from_day >= max_days


func _calendar_day_for_beat(beat_id: String) -> int:
	var route := get_active_route()
	for day_key in StoryRouteData.get_day_beats(route).keys():
		if str(StoryRouteData.get_day_beats(route).get(day_key, "")) == beat_id:
			return int(day_key)
	return 0


func _beat_gate_satisfied(beat_id: String) -> bool:
	var signals := RelationshipDirector.get_signals()
	var flags := GameState.get_ending_flags()
	if beat_id.ends_with("_N07"):
		var chat_days := int(signals.get("chat_days", 0))
		var gifts := int(signals.get("gifts_given", 0))
		return chat_days >= 2 or gifts >= 1 or int(signals.get("chat_turns", 0)) >= 4
	if beat_id.ends_with("_N16"):
		var nights := int(flags.get("companionship_nights", 0))
		return GameState.affection >= 30 or nights >= 1 or GameState.bond >= 25
	if beat_id.ends_with("_N33"):
		return true
	return true


func _resolve_steps(beat_id: String, raw_steps: Array) -> Array[Dictionary]:
	var resolved: Array[Dictionary] = []
	for step in raw_steps:
		if not step is Dictionary:
			continue
		var copy: Dictionary = step.duplicate(true)
		if str(copy.get("kind", "")) == "choice":
			resolved.append(copy)
			continue
		var template_key := str(copy.get("template", beat_id))
		copy["body"] = StoryRouteData.render_body(beat_id, template_key)
		if copy.get("kind", "") == "fragment":
			var fid := template_key
			var meta: Dictionary = FRAGMENTS.get(fid, {})
			copy["title"] = str(meta.get("title", fid))
		resolved.append(copy)
	return resolved


func _inject_opening_steps(
	beat_id: String,
	include_yesterday_echo: bool,
	steps: Array[Dictionary]
) -> Array[Dictionary]:
	var result: Array[Dictionary] = []
	if StoryRouteData.should_inject_evening_opening(beat_id):
		var evening := StorySlotService.apply(
			StoryRouteData.render_evening_opening(beat_id),
			StorySlotService.build_context({"beat_id": beat_id})
		)
		if evening.strip_edges() != "":
			result.append({"title": "傍晚", "body": evening})
	elif StoryRouteData.should_inject_morning_opening(beat_id):
		var morning := StorySlotService.apply(
			StoryRouteData.render_morning_opening(include_yesterday_echo, beat_id),
			StorySlotService.build_context({"beat_id": beat_id})
		)
		if morning.strip_edges() != "":
			result.append({"title": "清晨", "body": morning})
	if StoryRouteData.should_inject_proactive_nudge(beat_id):
		var nudge := StorySlotService.apply(
			StoryRouteData.render_proactive_nudge(),
			StorySlotService.build_context({"beat_id": beat_id})
		)
		if nudge.strip_edges() != "":
			result.append({"title": "小狸想说", "body": nudge})
	result.append_array(steps)
	return result


func _append_followup_step(beat_id: String, steps: Array[Dictionary]) -> Array[Dictionary]:
	for step in steps:
		if str(step.get("kind", "")) == "choice":
			return steps
	if not steps.is_empty() and str(steps[-1].get("title", "")) == "小狸想说":
		return steps
	var body := StorySlotService.apply(
		StoryRouteData.render_beat_followup(beat_id),
		StorySlotService.build_context({"beat_id": beat_id})
	)
	if body.strip_edges() == "":
		return steps
	var result := steps.duplicate()
	result.append({"title": "小狸想说", "body": body})
	return result
