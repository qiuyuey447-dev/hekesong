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
	## D10 觉醒日：不再挂日历/补播节点，整天只走觉醒演出。
	if GameState.should_show_awakening():
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
	var base := ""
	match _invite_copy_key(beat_id):
		"d2":
			if GameState.weather_today == GameState.WEATHER_RAIN:
				base = "雨天。廊下有干处，红薯还热。想让对方过来坐。可以俏皮一句，不要把信纸里的话提前说完。"
			else:
				base = "廊下有干处，红薯还热。想让对方过来坐。可以俏皮一句，不要把信纸里的话提前说完；今日非雨，勿提下雨或等雨停。"
		"d3":
			base = "苗齐了。你有个笨主意，想等对方忙完再讲。轻松开口，不要替对方做决定，不要剧透约定内容。"
		"d4":
			base = "陌生化：困惑水壶为什么在自己手里。礼貌、拘谨，不叫名字，不提红薯，不开玩笑。"
		"d5":
			base = "收拾了一点行李。想听对方决定自己能不能留下。不要剧透选项。"
		"d6":
			base = "田埂上忽然有熟悉感。想让对方过来一下。可带一点身体先记得的违和，不要点破。"
		"d7":
			base = "好像想起什么。想等对方忙完听你说一句。不要把名字或本子的结论说死。"
		"d7_night":
			base = "树洞那边。想让对方过来坐一会儿。不要提前讲夜里才会展开的内容。"
		"d8":
			base = "找到了本子，日期有点乱。想让对方一起看。不要把本子里的句子整段背出来。"
		"d9":
			base = "明天想告诉对方一件事。今晚只想先一起把田收一收。不要剧透终章。"
		_:
			base = "有句话想说，想让对方过来听。不要代替信纸正文。"
	var hint := _variant_invite_hint(beat_id, resolve_beat_variant(beat_id))
	if hint.strip_edges() != "":
		return "%s %s" % [base, hint]
	return base


func build_scheduled_invite(beat_id: String) -> Dictionary:
	## 随机时段到点：先让小狸 LLM 开口邀请，再开信纸（非 auto_open 节点）。
	if beat_id == "" or is_beat_seen(beat_id) or should_auto_open_beat(beat_id):
		return {}
	if GameState.was_invite_spoken_for(beat_id):
		return {}
	var is_night := _is_night_beat(beat_id)
	var payload := _invite_payload(beat_id, false, is_night)
	if payload.is_empty():
		return {}
	payload["invite_goal"] = get_invite_goal(beat_id, false)
	payload["beat_context"] = get_beat_context_for_llm(beat_id)
	return payload


func get_beat_context_for_llm(beat_id: String = "") -> Dictionary:
	if GameState.should_show_awakening() or GameState.is_pure_narrative_day():
		return {}
	if beat_id == "":
		beat_id = _resolve_schedulable_beat_id()
	if beat_id == "":
		return {}
	var variant := resolve_beat_variant(beat_id)
	var def := StoryRouteData.get_beat_def(beat_id)
	var sched := _load_schedule()
	return {
		"beat_id": beat_id,
		"variant_id": str(variant.get("variant_id", beat_id)),
		"affection_tier": str(variant.get("tier", GameState.get_affection_tier())),
		"profile": str(variant.get("profile", "")),
		"chat_track": bool(variant.get("chat_track", false)),
		"night_warm": bool(variant.get("night_warm", false)),
		"journal_max_lines": int(variant.get("journal_max_lines", 0)),
		"node_label": str(def.get("node_label", "")),
		"emotion": str(def.get("emotion", "")),
		"invite_tone": _variant_invite_hint(beat_id, variant),
		"invite_goal": get_invite_goal(beat_id, false),
		"scheduled_period": str(sched.get("period", "")),
		"chatted_today": GameState.chatted_today(),
	}


func get_daily_schedule_snapshot() -> Dictionary:
	var sched := _load_schedule()
	if sched.is_empty():
		return {}
	return sched.duplicate(true)


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
	if GameState.get_pending_story_beat_tail_id() == beat_id:
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
	var variant := resolve_beat_variant(beat_id)
	var beat := def.duplicate(true)
	beat["id"] = beat_id
	beat["variant_id"] = str(variant.get("variant_id", beat_id))
	beat["route"] = get_active_route()
	beat["steps"] = _append_followup_step(
		beat_id,
		_inject_opening_steps(
			beat_id,
			include_yesterday_echo,
			_resolve_steps(
				beat_id,
				_apply_variant_steps(beat_id, variant, beat.get("steps", []))
			)
		)
	)
	return beat


func split_steps_by_period_gate(raw_steps: Array) -> Dictionary:
	var now_steps: Array = []
	var later_steps: Array = []
	var period := GameState.time_of_day
	for raw in raw_steps:
		if not raw is Dictionary:
			continue
		var step: Dictionary = raw.duplicate(true)
		if _step_has_period_gate(step) and not _period_gate_allows(step, period):
			if _should_drop_unrecoverable_period_step(step, period):
				continue
			later_steps.append(step)
		else:
			now_steps.append(step)
	return {"now": now_steps, "later": later_steps}


func _should_drop_unrecoverable_period_step(step: Dictionary, period: String) -> bool:
	if period != GameState.TIME_NIGHT:
		return false
	var gate: Variant = step.get("period_gate", "")
	if gate is Array:
		return gate.size() == 1 and str(gate[0]) == GameState.TIME_EVENING
	var gate_text := str(gate).strip_edges()
	return gate_text == GameState.TIME_EVENING


func _step_has_period_gate(step: Dictionary) -> bool:
	var gate: Variant = step.get("period_gate", "")
	if gate is Array:
		return not gate.is_empty()
	return str(gate).strip_edges() != ""


func _period_gate_allows(step: Dictionary, period: String) -> bool:
	var gate: Variant = step.get("period_gate", "")
	if gate is Array:
		if gate.is_empty():
			return true
		return period in gate
	var gate_text := str(gate).strip_edges()
	if gate_text == "":
		return true
	return gate_text == period


func take_displayable_beat(beat: Dictionary) -> Dictionary:
	if beat.is_empty():
		return {}
	var beat_id := str(beat.get("id", "")).strip_edges()
	var split := split_steps_by_period_gate(beat.get("steps", []))
	var now_steps: Array = split.get("now", [])
	var later_steps: Array = split.get("later", [])
	if later_steps.is_empty():
		if GameState.get_pending_story_beat_tail_id() == beat_id:
			GameState.clear_pending_story_beat_tail()
	else:
		GameState.set_pending_story_beat_tail(beat_id, later_steps)
	if now_steps.is_empty():
		return {}
	beat["steps"] = now_steps
	beat["has_pending_tail"] = not later_steps.is_empty()
	return beat


func build_beat_tail_resume() -> Dictionary:
	var beat_id := GameState.get_pending_story_beat_tail_id()
	if beat_id == "":
		return {}
	var stored := GameState.get_pending_story_beat_tail_steps()
	if stored.is_empty():
		GameState.clear_pending_story_beat_tail()
		return {}
	var split := split_steps_by_period_gate(stored)
	var now_steps: Array = split.get("now", [])
	var later_steps: Array = split.get("later", [])
	if now_steps.is_empty():
		return {}
	if later_steps.is_empty():
		GameState.set_pending_story_beat_tail(beat_id, [])
	else:
		GameState.set_pending_story_beat_tail(beat_id, later_steps)
	_refresh_n16_night_choice_copy(now_steps, beat_id)
	var def := StoryRouteData.get_beat_def(beat_id)
	return {
		"id": beat_id,
		"tail_resume": true,
		"has_pending_tail": not later_steps.is_empty(),
		"steps": now_steps,
		"node_label": str(def.get("node_label", "")),
		"emotion": str(def.get("emotion", "")),
	}


func should_complete_beat_after_panel(beat_id: String) -> bool:
	if GameState.get_pending_story_beat_tail_id() != beat_id:
		return true
	return GameState.get_pending_story_beat_tail_steps().is_empty()


func prepare_beat_for_display(beat: Dictionary) -> Dictionary:
	if beat.is_empty():
		return beat
	var beat_id := str(beat.get("id", "")).strip_edges()
	var steps: Array = beat.get("steps", [])
	for i in range(steps.size()):
		if not steps[i] is Dictionary:
			continue
		var step: Dictionary = steps[i]
		if str(step.get("llm_render", "")).strip_edges() != "chat_digest":
			continue
		var rendered := await _render_personalized_step(beat_id, step)
		if rendered.strip_edges() != "":
			step["body"] = rendered
			steps[i] = step
	beat["steps"] = steps
	return beat


func _render_personalized_step(beat_id: String, step: Dictionary) -> String:
	var snippet := StoryRouteData.extract_chat_snippet_for_beat(beat_id)
	var extra := {
		"beat_id": beat_id,
		"render_kind": "chat_digest",
		"personal_snippet": snippet,
		"step_template": str(step.get("template", "")),
		"beat_context": get_beat_context_for_llm(beat_id),
	}
	if not NpcBridge.is_api_enabled():
		return NpcFallback.story_step_render(extra)
	var request_id := NpcBridge.request_event("story_step_render", extra)
	var text := await _await_npc_text(request_id, 8.0)
	if text.strip_edges() == "":
		return NpcFallback.story_step_render(extra)
	return text.strip_edges()


func _await_npc_text(request_id: int, timeout_sec: float) -> String:
	var state := {"done": false, "text": ""}
	var on_ready := func(rid: int, _event: String, reply: String, _fallback: bool) -> void:
		if rid == request_id:
			state["done"] = true
			state["text"] = reply
	NpcBridge.reply_ready.connect(on_ready)
	var elapsed := 0.0
	while not bool(state["done"]) and elapsed < timeout_sec:
		await get_tree().process_frame
		elapsed += get_process_delta_time()
	if NpcBridge.reply_ready.is_connected(on_ready):
		NpcBridge.reply_ready.disconnect(on_ready)
	return str(state.get("text", ""))


func _refresh_n16_night_choice_copy(steps: Array, beat_id: String) -> void:
	if not beat_id.ends_with("_N16"):
		return
	var hint := _n16_night_choice_hint(str(resolve_beat_variant(beat_id).get("profile", "mid")))
	for step in steps:
		if step is Dictionary and str(step.get("kind", "")) == "choice":
			step["body"] = hint


func complete_beat(beat_id: String) -> void:
	if GameState.has_pending_absence():
		GameState.mark_absence_shown()
	var variant := resolve_beat_variant(beat_id)
	var variant_id := str(variant.get("variant_id", beat_id))
	GameState.mark_story_node_seen(beat_id)
	if variant_id != beat_id:
		GameState.mark_story_node_seen(variant_id)
	if GameState.get_pending_invite_beat() == beat_id:
		GameState.clear_pending_invite_beat()
	if GameState.get_deferred_story_beat() == beat_id:
		GameState.clear_deferred_story_beat()
	if GameState.get_pending_story_beat_tail_id() == beat_id:
		GameState.clear_pending_story_beat_tail()
	mark_schedule_fired()
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
	if beat_id in ["P_N12", "BE_N12"] and not GameState.IS_TEN_DAY_EDITION:
		var promise: Dictionary = GameState.long_term_memory.get("promise", {})
		if not promise.is_empty() and not bool(promise.get("fulfilled", false)):
			GameState.fulfill_promise("萝卜快熟了。她按约定照看着这片田。")
	var node_label := str(def.get("node_label", beat_id))
	GameState.record_memory_event(
		"story_beat",
		"%s · %s" % [GameState.get_day_period_label(), str(def.get("emotion", node_label))],
		0.8,
		{"node": node_label, "beat_id": beat_id, "route": get_active_route(), "game_day": GameState.game_day}
	)
	PlayerNotebookService.on_beat_completed(beat_id)


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
				lines.append("· %s — %s" % [title, subtitle])
			else:
				lines.append("· %s" % title)
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
		if str(copy.get("body", "")).strip_edges() == "":
			continue
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
	if not GameState.IS_TEN_DAY_EDITION and StoryRouteData.should_inject_proactive_nudge(beat_id):
		var nudge := StorySlotService.apply(
			StoryRouteData.render_proactive_nudge(),
			StorySlotService.build_context({"beat_id": beat_id})
		)
		if nudge.strip_edges() != "":
			result.append({"title": "小狸想说", "body": nudge})
	result.append_array(steps)
	return result


func _append_followup_step(beat_id: String, steps: Array[Dictionary]) -> Array[Dictionary]:
	if GameState.IS_TEN_DAY_EDITION:
		return steps
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


## —— 随机时段自动触发（不依赖玩家输入）——

signal scheduled_beat_due(beat_id: String)

const TRIGGER_MEMORY_KEY := "daily_story_trigger"

## 须走 LLM 且携带 beat_context 的剧情/搭话 event（与 cloudrun local_llm_server 保持一致 · 策划 §4.5.5）
const STORY_LLM_SPEECH_EVENTS := [
	"player_chat",
	"session_start",
	"companion_proactive",
	"companion_casual",
	"morning_sidewrite",
	"story_beat",
	"companion_react",
	"story_step_render",
]

const PERIOD_ORDER := [
	GameState.TIME_MORNING,
	GameState.TIME_EVENING,
	GameState.TIME_NIGHT,
]


func _ready() -> void:
	GameState.day_advanced.connect(_on_schedule_day_advanced)
	call_deferred("refresh_daily_schedule")


func _on_schedule_day_advanced() -> void:
	refresh_daily_schedule()


func refresh_daily_schedule() -> void:
	if GameState.should_show_awakening():
		_clear_schedule()
		return
	var beat_id := _resolve_schedulable_beat_id()
	if beat_id == "" or is_beat_seen(beat_id):
		_clear_schedule()
		return
	if should_auto_open_beat(beat_id):
		_clear_schedule()
		return
	var variant := resolve_beat_variant(beat_id)
	var variant_id := str(variant.get("variant_id", beat_id))
	var existing := _load_schedule()
	if (
		int(existing.get("game_day", -1)) == GameState.game_day
		and str(existing.get("beat_id", "")) == beat_id
		and str(existing.get("variant_id", "")) == variant_id
	):
		return
	var periods := _allowed_trigger_periods(beat_id, variant)
	if periods.is_empty():
		_clear_schedule()
		return
	var rng := RandomNumberGenerator.new()
	rng.seed = _schedule_seed(beat_id, variant_id)
	var period: String = _pick_weighted_period(periods, variant, rng)
	var period_sec := GameState.get_period_seconds(period)
	var elapsed_range := _elapsed_range_for_variant(beat_id, variant, period)
	var elapsed_target := rng.randf_range(period_sec * elapsed_range.x, period_sec * elapsed_range.y)
	_save_schedule({
		"game_day": GameState.game_day,
		"beat_id": beat_id,
		"variant_id": variant_id,
		"period": period,
		"elapsed_target": elapsed_target,
		"fired": false,
	})


func check_schedule() -> void:
	if GameState.is_story_complete() or GameState.should_show_awakening():
		if GameState.should_show_awakening():
			_clear_schedule()
		return
	var expected := _resolve_schedulable_beat_id()
	var sched := _load_schedule()
	if expected != "" and not sched.is_empty() and str(sched.get("beat_id", "")) != expected:
		refresh_daily_schedule()
		sched = _load_schedule()
	if sched.is_empty() or bool(sched.get("fired", false)):
		return
	var beat_id := str(sched.get("beat_id", ""))
	if beat_id == "" or beat_id != _resolve_schedulable_beat_id() or is_beat_seen(beat_id):
		_clear_schedule()
		return
	if should_auto_open_beat(beat_id):
		return
	if _is_trigger_due(sched) or _is_past_schedule(sched):
		_mark_schedule_fired()
		scheduled_beat_due.emit(beat_id)


func mark_schedule_fired() -> void:
	_mark_schedule_fired()


func has_unfired_schedule_today() -> bool:
	if not has_blocking_today_beat() and get_pending_night_beat_id() == "":
		return false
	var sched := _load_schedule()
	if sched.is_empty() or bool(sched.get("fired", false)):
		return false
	var beat_id := str(sched.get("beat_id", ""))
	return beat_id != "" and not is_beat_seen(beat_id)


func should_force_schedule_now() -> bool:
	var beat_id := _resolve_schedulable_beat_id()
	if beat_id == "" or is_beat_seen(beat_id):
		return false
	var sched := _load_schedule()
	if not sched.is_empty() and not bool(sched.get("fired", false)):
		if _is_trigger_due(sched) or _is_past_schedule(sched):
			return true
	return GameState.is_awaiting_sleep()


func _resolve_schedulable_beat_id() -> String:
	var day_beat := get_today_beat_id()
	if day_beat != "" and not is_beat_seen(day_beat):
		return day_beat
	var night_id := get_pending_night_beat_id()
	if night_id != "":
		return night_id
	return ""


func _allowed_trigger_periods(beat_id: String, variant: Dictionary = {}) -> Array[String]:
	if _is_night_beat(beat_id):
		return [GameState.TIME_EVENING, GameState.TIME_NIGHT]
	if beat_id in ["P_N11", "BE_N11"]:
		return [GameState.TIME_EVENING]
	if beat_id.ends_with("_N02p") and GameState.IS_TEN_DAY_EDITION:
		if not bool(variant.get("chat_track", true)):
			return [GameState.TIME_EVENING]
		return [GameState.TIME_MORNING, GameState.TIME_EVENING]
	if beat_id.ends_with("_N20c") and GameState.IS_TEN_DAY_EDITION:
		if str(variant.get("tier", "")) == GameState.AFFECTION_TIER_WARM:
			return [GameState.TIME_EVENING, GameState.TIME_NIGHT]
		return [GameState.TIME_MORNING, GameState.TIME_EVENING]
	return [GameState.TIME_MORNING, GameState.TIME_EVENING]


func _is_trigger_due(sched: Dictionary) -> bool:
	return (
		GameState.time_of_day == str(sched.get("period", ""))
		and GameState.get_period_elapsed() >= float(sched.get("elapsed_target", 99999.0))
	)


func _is_past_schedule(sched: Dictionary) -> bool:
	var cur := PERIOD_ORDER.find(GameState.time_of_day)
	var scheduled := PERIOD_ORDER.find(str(sched.get("period", "")))
	if cur < 0 or scheduled < 0:
		return false
	return cur > scheduled


func _schedule_seed(beat_id: String, variant_id: String = "") -> int:
	if variant_id == "":
		variant_id = beat_id
	return int(hash("%d_%s_%d" % [GameState.game_day, variant_id, GameState.weather_seed]))


## —— 亲密度分支（Phase 1+2：D2/D3/D6/D7/D8/D9）——

## 策划 gate 索引（`docs/十日版策划定稿.md` §4.5）；逻辑以 resolve_* 为准。
const BEAT_VARIANT_GATES := {
	"P_N02": {
		"day": 2,
		"variants": ["warm", "mid", "cold"],
		"l1": "affection_tier",
		"l2": [],
		"l3_periods": [GameState.TIME_MORNING, GameState.TIME_EVENING],
		"templates": ["P_N02_warm", "P_N02_mid", "P_N02_cold", "P_N02_b_warm", "P_N02_b_mid", "P_N02_b_cold"],
	},
	"P_N11": {
		"day": 3,
		"variants": ["warm", "mid", "cold"],
		"l1": "affection_tier",
		"l2": [],
		"l3_periods": [GameState.TIME_EVENING],
		"templates": ["P_N03", "P_N11_warm", "P_N11_mid", "P_N11_cold"],
	},
	"_N02p": {
		"day": 6,
		"variants": ["chat", "nochat"],
		"l1": "affection_tier",
		"l2": ["relationship_signals.chat_days >= 1"],
		"l3_periods_chat": [GameState.TIME_MORNING, GameState.TIME_EVENING],
		"l3_periods_nochat": [GameState.TIME_EVENING],
		"templates": ["_N02p_a", "_N02p_b", "_N02p_a_nochat", "_N02p_b_nochat", "_N02p_chat"],
	},
	"_N16": {
		"day": 7,
		"variants": ["warm", "mid", "cold"],
		"l1": "affection_tier",
		"l2": ["has_player_name_set", "promise.summary", "companionship_nights", "chat_days >= 3"],
		"l3_periods": [GameState.TIME_MORNING, GameState.TIME_EVENING],
		"templates": ["_N16", "_N14n_sit", "_N14n_leave"],
	},
	"_N20c": {
		"day": 9,
		"variants": ["warm", "mid", "cold"],
		"l1": "affection_tier",
		"l2": [],
		"l3_periods_warm": [GameState.TIME_EVENING, GameState.TIME_NIGHT],
		"l3_periods_default": [GameState.TIME_MORNING, GameState.TIME_EVENING],
		"templates": ["_N20c", "_N20c_b", "_N20c_warm", "_N20c_cold"],
	},
	"_N15": {
		"day": 8,
		"variants": ["warm", "mid", "cold"],
		"l1": "affection_tier",
		"l2": ["relationship_signals.chat_days", "day_journal.length", "get_affection_tier"],
		"l3_periods": [GameState.TIME_MORNING, GameState.TIME_EVENING],
		"templates": ["_N15", "_N15_warm", "_N15_cold", "_N15_journal"],
	},
}


func resolve_beat_variant(beat_id: String) -> Dictionary:
	if not GameState.IS_TEN_DAY_EDITION:
		return {"variant_id": beat_id, "tier": GameState.get_affection_tier()}
	var tier := GameState.get_affection_tier()
	if beat_id in ["P_N02", "BE_N02"]:
		var suffix := _tier_label(tier)
		return {
			"variant_id": "%s_%s" % [beat_id, suffix],
			"tier": tier,
			"profile": suffix,
		}
	if beat_id in ["P_N11", "BE_N11"]:
		var suffix := _tier_label(tier)
		return {
			"variant_id": "%s_%s" % [beat_id, suffix],
			"tier": tier,
			"profile": suffix,
		}
	if beat_id.ends_with("_N02p"):
		var chat_track := _d6_has_chat_track()
		return {
			"variant_id": "%s_%s" % [beat_id, "chat" if chat_track else "nochat"],
			"tier": tier,
			"chat_track": chat_track,
		}
	if beat_id.ends_with("_N16"):
		return _resolve_n16_variant(beat_id, tier)
	if beat_id.ends_with("_N15"):
		return _resolve_n15_variant(beat_id, tier)
	if beat_id.ends_with("_N20c"):
		var suffix := _tier_label(tier)
		return {
			"variant_id": "%s_%s" % [beat_id, suffix],
			"tier": tier,
			"profile": suffix,
		}
	return {"variant_id": beat_id, "tier": tier}


func get_n16_profile(beat_id: String = "") -> String:
	if beat_id == "":
		beat_id = get_today_beat_id()
	if not beat_id.ends_with("_N16"):
		return "mid"
	return str(resolve_beat_variant(beat_id).get("profile", "mid"))


func get_n15_profile(beat_id: String = "") -> String:
	if beat_id == "":
		beat_id = get_today_beat_id()
	if not beat_id.ends_with("_N15"):
		return "mid"
	return str(resolve_beat_variant(beat_id).get("profile", "mid"))


func get_n15_journal_max_lines(beat_id: String = "") -> int:
	if beat_id == "":
		beat_id = get_today_beat_id()
	if not beat_id.ends_with("_N15"):
		return 3
	return int(resolve_beat_variant(beat_id).get("journal_max_lines", 3))


func _resolve_n15_variant(beat_id: String, tier: String) -> Dictionary:
	var signals := RelationshipDirector.get_signals()
	var chat_days := int(signals.get("chat_days", 0))
	var journal_count := GameState.day_journal.size()
	var profile := "cold"
	if tier == GameState.AFFECTION_TIER_WARM and (chat_days >= 2 or journal_count >= 4):
		profile = "warm"
	elif tier == GameState.AFFECTION_TIER_MID or chat_days >= 1 or journal_count >= 2:
		profile = "mid"
	elif chat_days >= 2:
		profile = "mid"
	var journal_max_lines := 3
	match profile:
		"warm":
			journal_max_lines = 3
		"cold":
			journal_max_lines = 1
		"mid":
			journal_max_lines = 2
		_:
			journal_max_lines = 2
	return {
		"variant_id": "%s_%s" % [beat_id, profile],
		"tier": tier,
		"profile": profile,
		"journal_max_lines": journal_max_lines,
	}


func _resolve_n16_variant(beat_id: String, tier: String) -> Dictionary:
	var signals := RelationshipDirector.get_signals()
	var nights := int(GameState.get_ending_flags().get("companionship_nights", 0))
	var promise: Dictionary = GameState.long_term_memory.get("promise", {})
	var has_promise := str(promise.get("summary", "")).strip_edges() != ""
	var profile := "cold"
	if tier == GameState.AFFECTION_TIER_WARM and GameState.has_player_name_set():
		profile = "warm"
	elif tier == GameState.AFFECTION_TIER_MID or has_promise or nights >= 1:
		profile = "mid"
	elif int(signals.get("chat_days", 0)) >= 3:
		profile = "mid"
	return {
		"variant_id": "%s_%s" % [beat_id, profile],
		"tier": tier,
		"profile": profile,
		"night_warm": nights >= 1 or profile == "warm",
	}


func _d6_has_chat_track() -> bool:
	var signals := RelationshipDirector.get_signals()
	return int(signals.get("chat_days", 0)) >= 1


func _tier_label(tier: String) -> String:
	match tier:
		GameState.AFFECTION_TIER_WARM:
			return "warm"
		GameState.AFFECTION_TIER_MID:
			return "mid"
		_:
			return "cold"


func _apply_variant_steps(beat_id: String, variant: Dictionary, raw_steps: Array) -> Array:
	var steps: Array = []
	for step in raw_steps:
		if step is Dictionary:
			steps.append(step.duplicate(true))
		else:
			steps.append(step)
	if not GameState.IS_TEN_DAY_EDITION:
		return steps
	if beat_id in ["P_N02", "BE_N02"]:
		var profile := str(variant.get("profile", "mid"))
		for step in steps:
			var tpl := str(step.get("template", ""))
			if tpl in ["P_N02", "BE_N02"]:
				step["template"] = "P_N02_%s" % profile
			elif tpl == "P_N02_b":
				step["template"] = "P_N02_b_%s" % profile
	elif beat_id in ["P_N11", "BE_N11"]:
		var profile := str(variant.get("profile", "mid"))
		for step in steps:
			var tpl := str(step.get("template", ""))
			if tpl == "P_N03":
				step["period_gate"] = [GameState.TIME_EVENING]
			if tpl in ["P_N11", "BE_N11"]:
				step["template"] = "P_N11_%s" % profile
				step["period_gate"] = [GameState.TIME_EVENING, GameState.TIME_NIGHT]
	elif beat_id.ends_with("_N02p"):
		if not bool(variant.get("chat_track", true)):
			for step in steps:
				var tpl := str(step.get("template", ""))
				if tpl.ends_with("_a"):
					step["template"] = "%s_nochat" % tpl
				elif tpl.ends_with("_b"):
					step["template"] = "%s_nochat" % tpl
		elif _d6_has_chat_track() and not GameState.IS_TEN_DAY_EDITION:
			var insert_idx := -1
			for i in range(steps.size()):
				if str(steps[i].get("template", "")).ends_with("_b"):
					insert_idx = i + 1
					break
			if insert_idx >= 0:
				steps.insert(insert_idx, {
					"title": "聊过的字",
					"template": "%s_chat" % beat_id,
					"llm_render": "chat_digest",
				})
	elif beat_id.ends_with("_N16"):
		var profile := str(variant.get("profile", "mid"))
		var night_hint := _n16_night_choice_hint(profile)
		if night_hint != "":
			for step in steps:
				if str(step.get("kind", "")) == "choice":
					step["body"] = night_hint
					step["period_gate"] = [GameState.TIME_EVENING, GameState.TIME_NIGHT]
				elif str(step.get("kind", "")) == "fragment":
					step["period_gate"] = [GameState.TIME_EVENING, GameState.TIME_NIGHT]
	elif beat_id.ends_with("_N15"):
		var profile := str(variant.get("profile", "mid"))
		if profile == "warm":
			for step in steps:
				var tpl := str(step.get("template", ""))
				if tpl == beat_id:
					step["template"] = "%s_warm" % beat_id
			var insert_idx := -1
			for i in range(steps.size()):
				if str(steps[i].get("kind", "")) == "fragment":
					insert_idx = i
					break
			if insert_idx < 0:
				insert_idx = steps.size()
			steps.insert(insert_idx, {
				"title": "写满的页",
				"template": "_N15_journal",
			})
		elif profile == "mid":
			for step in steps:
				var tpl := str(step.get("template", ""))
				if tpl == beat_id:
					step["template"] = "%s_mid" % beat_id
		elif profile == "cold":
			for step in steps:
				var tpl := str(step.get("template", ""))
				if tpl == beat_id:
					step["template"] = "%s_cold" % beat_id
	elif beat_id.ends_with("_N20c"):
		var profile := str(variant.get("profile", "mid"))
		if profile != "mid":
			for step in steps:
				var tpl := str(step.get("template", ""))
				if tpl == beat_id:
					step["template"] = "%s_%s" % [beat_id, profile]
				elif tpl == "%s_b" % beat_id:
					step["template"] = "%s_b_%s" % [beat_id, profile]
	return steps


func resolve_soft_paused_beats_before_advance() -> void:
	var paused := str(GameState.get_ending_flags().get("d9_soft_pause_beat", "")).strip_edges()
	if paused == "":
		return
	if not is_beat_seen(paused):
		GameState.mark_story_node_seen(paused)
	GameState.set_ending_flag("d9_soft_pause_beat", "")


func resolve_finale_day_carryover() -> void:
	if not GameState.IS_TEN_DAY_EDITION:
		return
	if GameState.game_day != GameState.FINAL_GAME_DAY:
		return
	var deferred := GameState.get_deferred_story_beat()
	if deferred != "" and not is_beat_seen(deferred):
		GameState.mark_story_node_seen(deferred)
	GameState.clear_deferred_story_beat()
	GameState.clear_pending_story_beat_tail()
	GameState.clear_pending_invite_beat()
	_clear_schedule()


func _n16_night_choice_hint(profile: String) -> String:
	var evening := GameState.time_of_day == GameState.TIME_EVENING
	match profile:
		"warm":
			if evening:
				return "傍晚，树洞那边灯亮了。你可以过去坐一会儿，也可以先回屋。"
			return "夜里，树洞那边灯还亮着。你可以过去坐一会儿，也可以先回屋。"
		"cold":
			if evening:
				return "天色暗了。树洞那边有风。你可以过去坐一会儿，也可以先回屋。"
			return "夜深了。树洞那边有风。你可以过去坐一会儿，也可以先回屋。"
		_:
			if evening:
				return "傍晚，树洞那边有光。你可以过去坐一会儿，也可以先回屋。"
			return "夜深了。树洞那边有光。你可以过去坐一会儿，也可以先回屋。"


func _period_weights_for_tier(tier: String) -> Dictionary:
	match tier:
		GameState.AFFECTION_TIER_WARM:
			return {
				GameState.TIME_MORNING: 0.20,
				GameState.TIME_EVENING: 0.40,
				GameState.TIME_NIGHT: 0.40,
			}
		GameState.AFFECTION_TIER_MID:
			return {
				GameState.TIME_MORNING: 0.35,
				GameState.TIME_EVENING: 0.45,
				GameState.TIME_NIGHT: 0.20,
			}
		_:
			return {
				GameState.TIME_MORNING: 0.60,
				GameState.TIME_EVENING: 0.30,
				GameState.TIME_NIGHT: 0.10,
			}


func _pick_weighted_period(periods: Array[String], variant: Dictionary, rng: RandomNumberGenerator) -> String:
	if periods.size() == 1:
		return periods[0]
	var tier := str(variant.get("tier", GameState.get_affection_tier()))
	var weights := _period_weights_for_tier(tier)
	var beat_id := str(variant.get("variant_id", ""))
	if beat_id.ends_with("_N02p_chat"):
		weights[GameState.TIME_MORNING] = weights.get(GameState.TIME_MORNING, 0.35) + 0.25
		weights[GameState.TIME_EVENING] = maxf(float(weights.get(GameState.TIME_EVENING, 0.35)) - 0.15, 0.05)
	if beat_id.ends_with("_N20c_warm"):
		weights[GameState.TIME_NIGHT] = weights.get(GameState.TIME_NIGHT, 0.40) + 0.20
		weights[GameState.TIME_MORNING] = maxf(float(weights.get(GameState.TIME_MORNING, 0.20)) - 0.10, 0.05)
	var total := 0.0
	for period in periods:
		total += float(weights.get(period, 0.1))
	if total <= 0.0:
		return periods[rng.randi() % periods.size()]
	var roll := rng.randf() * total
	var acc := 0.0
	for period in periods:
		acc += float(weights.get(period, 0.1))
		if roll <= acc:
			return period
	return periods[periods.size() - 1]


func _elapsed_range_for_variant(beat_id: String, variant: Dictionary, period: String) -> Vector2:
	var tier := str(variant.get("tier", GameState.get_affection_tier()))
	var min_ratio := 0.40
	var max_ratio := 0.70
	match tier:
		GameState.AFFECTION_TIER_WARM:
			min_ratio = 0.15
			max_ratio = 0.40
		GameState.AFFECTION_TIER_MID:
			min_ratio = 0.40
			max_ratio = 0.70
		_:
			min_ratio = 0.70
			max_ratio = 0.85
	if GameState.chatted_today():
		min_ratio = maxf(min_ratio - 0.10, 0.10)
		max_ratio = maxf(max_ratio - 0.10, min_ratio + 0.05)
	elif not GameState.chatted_today():
		min_ratio = minf(min_ratio + 0.10, 0.80)
		max_ratio = minf(max_ratio + 0.05, 0.90)
	if beat_id in ["P_N11", "BE_N11"] and period == GameState.TIME_EVENING:
		pass
	elif beat_id.ends_with("_N02p") and not bool(variant.get("chat_track", true)):
		min_ratio = 0.65
		max_ratio = 0.85
	return Vector2(min_ratio, max_ratio)


func _variant_invite_hint(beat_id: String, variant: Dictionary) -> String:
	var tier := str(variant.get("tier", GameState.get_affection_tier()))
	var profile := str(variant.get("profile", ""))
	if beat_id in ["P_N11", "BE_N11"]:
		match profile:
			"warm":
				return "【亲密度·贴】敢提约定、敢提写进本子；仍不要整段念信纸。"
			"cold":
				return "【亲密度·远】短句、客气，像完成交代，不要撒娇。"
			"mid":
				return "【亲密度·中】写半句、念一半；怕忘所以落字，但不把本子推过来。"
			_:
				return "【亲密度·近】有约定的心意，留一点余地。"
	if beat_id in ["P_N02", "BE_N02"]:
		match profile:
			"warm":
				return "【廊下·贴】敢分担干处、敢提「现在有你」；仍不要整段念信纸。"
			"cold":
				return "【廊下·远】短句、留距离，不主动靠近。"
			"mid":
				return "【廊下·中】让半块干处、红薯推回来；留一步距离，不贴不赶。"
			_:
				return "【廊下·常】让干处、红薯照旧；留一点余地。"
	if beat_id.ends_with("_N02p"):
		if bool(variant.get("chat_track", false)):
			return "【有聊天】可隐约提聊过的字，身体先记得；不要整段背日记。"
		return "【少互动】公事公办、隔一步，像试探。"
	if beat_id.ends_with("_N16"):
		match profile:
			"warm":
				return "【叫名·暖】敢叫名字、敢提约定；像等对方忙完。"
			"cold":
				return "【叫名·冷】叫不出名，试探道歉；夜戏更疏。"
			"mid":
				return "【叫名·中】名字或约定念得出来，却会停顿、留一步；勿写满 warm 的亲密。"
			_:
				return "【叫名·中】记得约定或名字之一；不剧透夜选。"
	if beat_id.ends_with("_N15"):
		match profile:
			"warm":
				return "【本子·满】页多、字多；可提记下的字，不要整段背信纸。"
			"cold":
				return "【本子·薄】少页、短句；不要逼近。"
			"mid":
				return "【本子·中】几页新字、日期仍乱；描粗的那行在，但不掏你的本子。"
			_:
				return "【本子·常】本子还在，日期仍乱。"
	if beat_id.ends_with("_N20c"):
		match profile:
			"warm":
				return "【前夜·贴】明天有话要说，今晚想靠近；偏私密时段。"
			"cold":
				return "【前夜·远】明天 maybe，今晚不要逼太近。"
			"mid":
				return "【前夜·中】明天有事想说，今晚收工；留灯、不逼近。"
			_:
				return "【前夜·常】明天有事想说，今晚收工就好。"
	match tier:
		GameState.AFFECTION_TIER_WARM:
			return "【关系·贴】更敢打断、更私密。"
		GameState.AFFECTION_TIER_COLD:
			return "【关系·远】更晚开口、更短。"
		_:
			return ""


func _load_schedule() -> Dictionary:
	var raw: Variant = GameState.long_term_memory.get(TRIGGER_MEMORY_KEY, {})
	if raw is Dictionary:
		return raw
	return {}


func _save_schedule(data: Dictionary) -> void:
	GameState.long_term_memory[TRIGGER_MEMORY_KEY] = data.duplicate(true)


func _clear_schedule() -> void:
	GameState.long_term_memory.erase(TRIGGER_MEMORY_KEY)


func _mark_schedule_fired() -> void:
	var sched := _load_schedule()
	if sched.is_empty():
		return
	sched["fired"] = true
	_save_schedule(sched)
