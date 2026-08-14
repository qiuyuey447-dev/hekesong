extends Node
## 按结局路线调度独立 P 节点（§十二 · 五线分轨）。
## 脊柱节点阻塞过天；肋骨节点按行为门槛触发，可顺延。

const FRAGMENTS: Dictionary = {
	"F01": {"title": "登门", "subtitle": "她请求留下帮工", "unlock_node": "N02p"},
	"F02": {"title": "约定", "subtitle": "等萝卜长好了，一起看看", "unlock_node": "N11"},
	"F03": {"title": "小狸的本子", "subtitle": "日期乱了——失忆物证", "unlock_node": "N15"},
	"F04": {"title": "名字", "subtitle": "让我留下来的那个人", "unlock_node": "N16"},
	"F05": {"title": "完整的家", "subtitle": "你的农场，她的安顿", "unlock_node": "N20"},
	## 以下保留解锁键以兼容旧存档；十日版主流程以 F01–F05 / F07 为主
	"F06": {"title": "你没有赶她走", "subtitle": "明知会忘，仍留她在农场", "unlock_node": "N18p"},
	"F07": {"title": "名字", "subtitle": "让我留下来的那个人", "unlock_node": "N16"},
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
	if bool(GameState.get_ending_flags().get("w2_chose_expel", false)):
		return false
	if GameState.IS_TEN_DAY_EDITION:
		if GameState.game_day <= 4:
			return true
		if GameState.game_day == 5:
			return not GameState.is_story_node_seen("P_N06p") and not GameState.is_story_node_seen("N06p")
		return false
	if GameState.game_day > 10:
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


func should_auto_open_beat(beat_id: String = "") -> bool:
	## 登门 / 赶走短终章仍直接开信纸，不先在聊天里邀请。
	if beat_id == "":
		beat_id = get_today_beat_id()
	if beat_id == "" or is_beat_seen(beat_id):
		return false
	return beat_id in ["P_N01", "BE_N01", "BE_N07"]


func try_invite(as_remind: bool = false) -> Dictionary:
	## 她走过来找你：1～2 句邀请，不代替信纸正文。
	var night_id := get_pending_night_beat_id()
	if night_id != "" and GameState.time_of_day in [GameState.TIME_EVENING, GameState.TIME_NIGHT]:
		return _invite_payload(night_id, as_remind, true)

	var beat_id := get_today_beat_id()
	if beat_id == "" or is_beat_seen(beat_id):
		return {}
	if should_auto_open_beat(beat_id):
		return {}
	if not _invite_time_ok(beat_id):
		return {}
	return _invite_payload(beat_id, as_remind, false)


func render_invite_line(beat_id: String, as_remind: bool = false) -> String:
	if as_remind:
		var remind := StoryNodeCopy.get_invite("remind").strip_edges()
		if remind != "":
			return remind
	var key := _invite_copy_key(beat_id)
	var raw := StoryNodeCopy.get_invite(key).strip_edges()
	if raw == "":
		raw = StoryNodeCopy.get_invite("generic").strip_edges()
	if raw == "":
		raw = "……你过来一下。我有句话想说。"
	return StorySlotService.apply(raw, StorySlotService.build_context({"beat_id": beat_id}))


func get_invite_goal(beat_id: String, as_remind: bool = false) -> String:
	if as_remind:
		return "对方今天还没来听你说话。再轻轻提一次，不要催，不要复述信纸正文。"
	match _invite_copy_key(beat_id):
		"d2":
			return "雨天。廊下有干处，红薯还热。想让对方过来坐。可以俏皮一句，不要把信纸里的话提前说完。"
		"d3":
			return "苗齐了。你有个笨主意，想等对方忙完再讲。轻松开口，不要替对方做决定，不要剧透约定内容。"
		"d4":
			return "陌生化：困惑水壶为什么在自己手里。礼貌、拘谨，不叫名字，不提红薯，不开玩笑。"
		"d5":
			return "收拾了一点行李。想听对方决定自己能不能留下。不要剧透选项。"
		"d6":
			return "田埂上忽然有熟悉感。想让对方过来一下。可带一点身体先记得的违和，不要点破。"
		"d7":
			return "好像想起什么。想等对方忙完听你说一句。不要把名字或本子的结论说死。"
		"d7_night":
			return "树洞那边。想让对方过来坐一会儿。不要提前讲夜里才会展开的内容。"
		"d8":
			return "找到了本子，日期有点乱。想让对方一起看。不要把本子里的句子整段背出来。"
		"d9":
			return "明天想告诉对方一件事。今晚只想先一起把田收一收。不要剧透终章。"
		_:
			return "有句话想说，想让对方过来听。不要代替信纸正文。"


func _invite_payload(beat_id: String, as_remind: bool, is_night: bool) -> Dictionary:
	var spoken := GameState.was_invite_spoken_for(beat_id)
	if as_remind:
		if not spoken or GameState.was_invite_reminded_for(beat_id):
			return {}
		if not has_blocking_today_beat() and not is_night:
			return {}
		if GameState.time_of_day != GameState.TIME_EVENING:
			return {}
	elif spoken:
		return {}

	var line := ""
	var used_leak := false
	var leak_context := {}
	if not as_remind and beat_id.ends_with("_N02p"):
		leak_context = LeakageEngine.peek_leak_context()
		used_leak = not leak_context.is_empty()
	return {
		"channel": "invite",
		"line": line,
		"beat_id": beat_id,
		"remind": as_remind,
		"night": is_night,
		"also_leak": used_leak,
		"leak_context": leak_context,
		"invite_goal": get_invite_goal(beat_id, as_remind),
	}


func _invite_time_ok(beat_id: String) -> bool:
	var tod := GameState.time_of_day
	if _is_night_beat(beat_id):
		return tod in [GameState.TIME_EVENING, GameState.TIME_NIGHT]
	if tod == GameState.TIME_NIGHT:
		return false
	## D3 约定：傍晚才开口。
	if beat_id == "P_N11" or beat_id == "BE_N11":
		return tod == GameState.TIME_EVENING
	## D9 前夜：清晨或傍晚都可以，但只说一次（spoken 旗标管）。
	return true


func _invite_copy_key(beat_id: String) -> String:
	if beat_id in ["P_N02", "BE_N02"]:
		return "d2"
	if beat_id in ["P_N11", "BE_N11"]:
		return "d3"
	if beat_id in ["P_N05", "BE_N05"]:
		return "d4"
	if beat_id in ["P_N06p"]:
		return "d5"
	if beat_id.ends_with("_N02p"):
		return "d6"
	if _is_night_beat(beat_id):
		return "d7_night"
	if beat_id.ends_with("_N16"):
		return "d7"
	if beat_id.ends_with("_N15"):
		return "d8"
	if beat_id.ends_with("_N20c"):
		return "d9"
	return "generic"


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
	## 十日版取消 D11 投喂肋骨节点。
	if GameState.IS_TEN_DAY_EDITION:
		return {}
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
	if GameState.get_pending_invite_beat() == beat_id:
		GameState.clear_pending_invite_beat()
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
	if beat_id in ["P_N11", "BE_N11"]:
		var promise: Dictionary = GameState.long_term_memory.get("promise", {})
		if promise.is_empty() or str(promise.get("summary", "")).strip_edges() == "":
			GameState.set_promise("turnip_field", "等萝卜长好了，我们一起看看吧。")
		GameState.unlock_fragment("F02", beat_id)
	var node_label := str(def.get("node_label", beat_id))
	GameState.record_memory_event(
		"story_beat",
		"%s · %s" % [GameState.get_day_period_label(), str(def.get("emotion", node_label))],
		0.8,
		{"node": node_label, "beat_id": beat_id, "route": get_active_route(), "game_day": GameState.game_day}
	)


func refresh_story_route() -> void:
	if bool(GameState.get_ending_flags().get("w2_chose_expel", false)):
		GameState.lock_story_route(StoryRouteData.ROUTE_BAD_EARLY)
		return
	var lock_from_day := 5 if GameState.IS_TEN_DAY_EDITION else 10
	if GameState.game_day < lock_from_day:
		return
	if not bool(GameState.get_ending_flags().get("w2_choice_made", false)):
		return
	var old_route := GameState.get_story_route()
	var projected := EndingDirector.resolve_ending(false)
	var route := StoryRouteData.get_route_for_ending(projected)
	GameState.lock_story_route(route)
	if old_route != "" and old_route != route:
		story_route_changed.emit(old_route, route)


func ensure_story_route_locked() -> void:
	var lock_from_day := 5 if GameState.IS_TEN_DAY_EDITION else 10
	if GameState.game_day < lock_from_day:
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
	## 十日版 D7 回响（N16）是定稿主节点，不可按亲密度门控藏起
	if GameState.IS_TEN_DAY_EDITION and beat_id.ends_with("_N16"):
		return false
	## BE_N07 是赶走短终章脊柱，不能当成投喂肋骨 N07
	if beat_id == "BE_N07" or beat_id.begins_with("BE_"):
		return false
	return _rib_suffix(beat_id) != ""


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
		if not beat_id.ends_with(suffix):
			continue
		var prefix := beat_id.substr(0, beat_id.length() - suffix.length()).trim_suffix("_")
		## 仅路线前缀肋骨（NM/HP/TR/BL）；排除 BE_N07 等
		if prefix in ["NM", "HP", "TR", "BL", "P"]:
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
