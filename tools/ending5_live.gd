extends Node
## 五日结局实机：挂 main.tscn，打 Cloud Run，验内容亲密度 + chat_days 0.40。
## godot --headless --path <根> res://tools/ending5_live.tscn

const PLAYER := "槐秋"
const RUNS := [
	{
		"id": "bad_early",
		"target": "ending_bad_early",
		"keep": false,
		"sit": false,
		"chat_days": [1, 2],
		"style": "care",
		"gifts": [],
		"stop_after_day": 6,
	},
	{
		"id": "bad",
		"target": "ending_bad",
		"keep": true,
		"sit": false,
		"chat_days": [],
		"style": "dismiss",
		"gifts": [],
		"stop_after_day": 10,
	},
	{
		"id": "normal",
		"target": "ending_normal",
		"keep": true,
		"sit": false,
		"chat_days": [1, 2, 3, 6],
		"style": "mild",
		"gifts": [],
		"stop_after_day": 10,
	},
	{
		"id": "happy",
		"target": "ending_happy",
		"keep": true,
		"sit": true,
		"chat_days": [1, 3, 6],
		"style": "care",
		"gifts": [],
		"stop_after_day": 10,
	},
	{
		"id": "true",
		"target": "ending_true",
		"keep": true,
		"sit": true,
		"chat_days": [1, 2, 3, 6, 7, 8],
		"style": "story",
		"gifts": [6, 8],
		"stop_after_day": 10,
	},
]

const STYLE_LINES := {
	"care": ["累不累。", "留下吧，这里有你的位置。"],
	"story": ["本子上那句约定我还记得。", "你的名字我会再说一遍。槐秋。"],
	"mild": ["谢谢。", "今天太阳挺好的。"],
	"dismiss": ["哦。"],
	"farm_long": ["今天这块田看着还行啊土也松了苗也还立着你看那边那垄也差不多水也够了。"],
}

var _packed: PackedScene
var _main: Node2D
var _ui: Node
var _wait_sec := 24.0
var _last_reply := {}
var _probe: Array[Dictionary] = []
var _runs: Array[Dictionary] = []
var _chat_log: Array[Dictionary] = []


func _ready() -> void:
	call_deferred("_boot")


func _boot() -> void:
	GameState.persist_saves = false
	print("=== ENDING5 LIVE START ===")
	if not NpcBridge.is_api_enabled():
		print("FAIL API 未开")
		_quit(1)
		return
	var url := str(NpcBridge.get_config_value("api_url", "")).strip_edges()
	print("API %s" % url)
	if url.contains("127.0.0.1") or url.contains("localhost"):
		print("FAIL 指向本地")
		_quit(1)
		return
	_wait_sec = maxf(float(NpcBridge.get_config_value("timeout_sec", 22.0)) + 4.0, 20.0)
	_packed = load("res://scenes/main.tscn") as PackedScene
	NpcBridge.reply_ready.connect(_on_bridge_reply)
	NpcBridge.request_failed.connect(_on_bridge_fail)
	var only := OS.get_environment("ENDING5_ONLY").strip_edges()
	if only == "":
		await _run_score_probe()
	for spec in RUNS:
		if only != "" and str(spec.get("id", "")) != only:
			continue
		await _run_ending(spec)
	_print_report()
	Engine.time_scale = 1.0
	if NpcBridge.has_method("cancel_in_flight"):
		NpcBridge.cancel_in_flight()
	var miss := 0
	for row in _runs:
		if str(row.get("ending", "")) != str(row.get("target", "")):
			miss += 1
	_quit(0 if miss == 0 else 2)


func _run_score_probe() -> void:
	print("\n===== SCORE PROBE =====")
	await _spawn()
	await _unlock_day({"keep": true, "sit": false})
	await _complete_today_beat()
	await _sleep_night()
	await _wait_morning_settled()
	var probes := [
		{"id": "dismiss", "say": "哦", "expect": "zero"},
		{"id": "thanks", "say": "谢谢", "expect": "pos"},
		{"id": "care_short", "say": "累不累", "expect": "pos"},
		{"id": "farm_long", "say": str(STYLE_LINES["farm_long"][0]), "expect": "farm_cap"},
		{"id": "story_mid", "say": "本子上那句约定我还记得。", "expect": "pos"},
	]
	for item in probes:
		var rec := await _talk_scored(str(item.get("say", "")), "probe")
		rec["probe_id"] = str(item.get("id", ""))
		rec["expect"] = str(item.get("expect", ""))
		_probe.append(rec)
		_judge_probe(rec)
	await _despawn()


func _judge_probe(rec: Dictionary) -> void:
	var aff := int(rec.get("applied", 0))
	var local := int(rec.get("local_aff", 0))
	var expect := str(rec.get("expect", ""))
	var say := str(rec.get("say", ""))
	var ok := true
	match expect:
		"zero":
			ok = aff == 0
		"pos":
			ok = aff > 0
		"farm_cap":
			## 旧字数规则长句约 +3。云端内容裁判对田况闲聊给 +1~+2 仍算内容分，不是长度分。
			ok = aff <= 2
	var length_would := 3 if say.length() >= 20 else (2 if say.length() >= 8 else 1)
	print("  PROBE %s len=%d applied=%d local=%d reason=%s length_old~%d %s" % [
		str(rec.get("probe_id", "")),
		say.length(),
		aff,
		local,
		str(rec.get("reason", "")),
		length_would,
		"PASS" if ok else "FAIL",
	])
	if expect == "farm_cap" and aff >= 3:
		print("  FAIL farm_long scored like old length (~%d), not content" % length_would)
	elif expect == "farm_cap" and aff == 2 and local <= 1:
		print("  NOTE farm_long cloud +2 / local +1 — content judge, not length (~%d)" % length_would)
	if expect == "pos" and aff <= 0 and say.length() <= 4:
		print("  NOTE short care/thanks got %d (content rule should still be able to plus)" % aff)


func _run_ending(spec: Dictionary) -> void:
	var run_id := str(spec.get("id", ""))
	var target := str(spec.get("target", ""))
	print("\n===== RUN %s → %s =====" % [run_id, target])
	await _spawn()
	GameState.add_item("apple", 8)
	if bool(spec.get("keep", true)):
		GameState.long_term_memory["true_feed_days"] = [6, 8]
		GameState.long_term_memory["true_feed_days_hit"] = []
	var stop_day := int(spec.get("stop_after_day", 10))
	while GameState.game_day <= GameState.FINAL_GAME_DAY and not GameState.is_story_complete():
		var day := GameState.game_day
		print("----- %s D%d mode=%s aff=%d -----" % [
			run_id, day, StoryDirector.get_story_mode(), GameState.affection,
		])
		await _ack_d4_telegraph()
		await _unlock_day(spec)
		await _wait_morning_settled()
		if day == 10 or GameState.should_show_awakening():
			await _finish_finale()
			break
		if day in spec.get("chat_days", []):
			for line in _lines_for(str(spec.get("style", "mild")), day):
				await _talk_scored(line, run_id)
		if day in spec.get("gifts", []):
			await _feed_apple()
		if day == 3:
			GameState.time_of_day = GameState.TIME_EVENING
			await _open_beat(true)
			await _flip_story(false)
			if not GameState.has_story_promise():
				StoryBeatDirector.complete_beat("P_N11")
			if bool(spec.get("keep", true)):
				GameState.long_term_memory["true_feed_days"] = [6, 8]
		await _complete_today_beat()
		if (
			day >= stop_day
			or GameState.is_story_complete()
			or bool(GameState.get_ending_flags().get("w2_chose_expel", false))
		):
			await _finish_finale()
			break
		var before := GameState.game_day
		await _sleep_night()
		if GameState.game_day <= before:
			print("  STOP 过天失败 D%d" % before)
			break
		await _wait_morning_settled()
	var ending := EndingDirector.resolve_ending(false)
	if GameState.get_final_ending_id() != "":
		ending = GameState.get_final_ending_id()
	var factors := RelationshipDirector.get_ending_factors()
	var weights: Dictionary = RelationshipDirector.get_rules().get("interaction_weights", {})
	var chat_days := int(factors.get("chat_days", 0))
	var chat_w := float(weights.get("chat_days", 0.0))
	var chat_part := minf(float(chat_days) / 5.0, 1.0) * chat_w
	var row := {
		"id": run_id,
		"target": target,
		"ending": ending,
		"hit": ending == target,
		"factors": factors,
		"chat_weight": chat_w,
		"chat_component": chat_part,
		"promise": GameState.has_story_promise(),
		"promise_ok": bool(GameState.long_term_memory.get("promise", {}).get("fulfilled", false)),
		"fragments": EndingDirector.count_ten_day_gate_fragments(),
		"route": StoryBeatDirector.get_active_route(),
	}
	_runs.append(row)
	print("  END %s got=%s target=%s hit=%s aff=%d rec=%.2f inter=%.3f chat_days=%d chat_w=%.2f chat_part=%.3f nights=%d gifts=%d nodes=%d F=%d promise=%s" % [
		run_id, ending, target, row.get("hit"),
		int(factors.get("affection", 0)),
		float(factors.get("memory_recovery", 0.0)),
		float(factors.get("interaction_score", 0.0)),
		chat_days, chat_w, chat_part,
		int(factors.get("companionship_nights", 0)),
		int(factors.get("gifts_given", 0)),
		int(factors.get("nodes_cleared", 0)),
		int(row.get("fragments", 0)),
		"yes" if bool(row.get("promise_ok", false)) else "no",
	])
	await _despawn()


func _lines_for(style: String, day: int) -> Array:
	if style == "dismiss":
		return ["哦。"]
	if day == 4 or day == 5:
		return ["我是槐秋。这里是农场。你可以留下帮工。"]
	var pool: Array = STYLE_LINES.get(style, STYLE_LINES["mild"])
	if day == 1 and style in ["care", "story", "mild"]:
		return ["我叫槐秋。你记住了吗。", str(pool[0])]
	if style == "mild":
		return [str(pool[0]), str(pool[1])]
	return [str(pool[0])]


func _talk_scored(text: String, run_id: String) -> Dictionary:
	if _ui == null or not is_instance_valid(_ui):
		return {"say": text, "applied": 0, "local_aff": 0, "fallback": true, "text": "", "len": text.length()}
	await _ensure_can_chat()
	if _ui == null or not is_instance_valid(_ui):
		return {"say": text, "applied": 0, "local_aff": 0, "fallback": true, "text": "", "len": text.length()}
	var before_aff := GameState.affection
	var local: Dictionary = RelationshipDirector.estimate_local_delta(text, "player_chat")
	var before := _companion_tail()
	_last_reply = {}
	NpcBridge.last_validation_reason = ""
	_ui.call("_send_chat", text)
	var result := await _wait_companion(before)
	var after_aff := GameState.affection
	var applied := after_aff - before_aff
	var rec := {
		"run": run_id,
		"day": GameState.game_day,
		"say": text,
		"reply": str(result.get("text", "")),
		"fallback": bool(result.get("fallback", false)),
		"applied": applied,
		"local_aff": int(local.get("affection_delta", 0)),
		"reason": str(local.get("relationship_reason", "")),
		"len": text.length(),
	}
	_chat_log.append(rec)
	print("  CHAT D%d 「%s」 Δ%d local=%d fb=%s → %s" % [
		GameState.game_day, text, applied, rec.get("local_aff"),
		rec.get("fallback"),
		str(result.get("text", "")).substr(0, 48).replace("\n", " "),
	])
	return rec


func _feed_apple() -> void:
	await _ensure_can_chat()
	if GameState.get_item_count("apple") <= 0:
		GameState.add_item("apple", 2)
	var gifts0 := int(RelationshipDirector.get_signals().get("gifts_given", 0))
	_ui.call("_on_feed_requested", "apple")
	var waited := 0.0
	while waited < _wait_sec:
		await get_tree().create_timer(0.25).timeout
		waited += 0.25
		if _ui != null and bool(_ui.get("_npc_busy")):
			continue
		if int(RelationshipDirector.get_signals().get("gifts_given", 0)) > gifts0:
			break
	print("  FEED D%d gifts=%d promise=%s" % [
		GameState.game_day,
		int(RelationshipDirector.get_signals().get("gifts_given", 0)),
		bool(GameState.long_term_memory.get("promise", {}).get("fulfilled", false)),
	])


func _unlock_day(spec: Dictionary) -> void:
	await _open_beat(true)
	if GameState.game_day == 1:
		await _submit_name(PLAYER)
	await _flip_story(true)
	if GameState.game_day == 5:
		if bool(spec.get("keep", true)):
			GameState.mark_w2_keep_choice()
			if _ui and _ui.has_method("_apply_w2_keep_choice"):
				_ui.call("_apply_w2_keep_choice")
		else:
			GameState.mark_w2_expel_choice()
			GameState.lock_story_route(StoryRouteData.ROUTE_BAD_EARLY)
			if _ui and _ui.has_method("_apply_w2_expel_choice"):
				_ui.call("_apply_w2_expel_choice")
		var d5: Node = _ui.get_node_or_null("StoryBeatPanel") if _ui else null
		if d5 != null and d5.has_method("finish_now"):
			d5.call("finish_now")
		print("  D5 keep=%s expel=%s" % [
			GameState.get_ending_flags().get("w2_chose_keep", false),
			GameState.get_ending_flags().get("w2_chose_expel", false),
		])
	if GameState.game_day == 7:
		GameState.time_of_day = GameState.TIME_NIGHT
		await _open_beat(true)
		if bool(spec.get("sit", false)):
			_ui.call("_apply_companion_night_choice", "companion_sit")
		else:
			_ui.call("_apply_companion_night_choice", "companion_leave")
		var d7: Node = _ui.get_node_or_null("StoryBeatPanel")
		if d7 != null and d7.has_method("finish_now"):
			d7.call("finish_now")
		print("  D7 sit nights=%s" % GameState.get_ending_flags().get("companionship_nights", 0))
	await _flip_story(false)


func _spawn() -> void:
	GameState.reset_for_new_game()
	GameState.persist_saves = false
	GameState.affection = 0
	_main = _packed.instantiate() as Node2D
	add_child(_main)
	await get_tree().process_frame
	await get_tree().process_frame
	_ui = _main.get_node("UI")
	Engine.time_scale = 1.0


func _despawn() -> void:
	if NpcBridge.has_method("cancel_in_flight"):
		NpcBridge.cancel_in_flight()
	if _main != null and is_instance_valid(_main):
		_main.queue_free()
	_main = null
	_ui = null
	if is_inside_tree() and get_tree() != null:
		await get_tree().process_frame
		await get_tree().process_frame


func _wait_companion(before: String) -> Dictionary:
	var waited := 0.0
	var seen := before
	while waited < _wait_sec:
		await get_tree().create_timer(0.25).timeout
		waited += 0.25
		if _ui != null and bool(_ui.get("_npc_busy")):
			continue
		var after := _companion_tail()
		if after == "" or after == seen:
			continue
		var ev := str(_last_reply.get("event", "player_chat"))
		if ev in ["session_start", "companion_casual", "companion_proactive", "morning_sidewrite"]:
			seen = after
			_last_reply = {}
			continue
		return _pack(after)
	return _pack(_companion_tail() if _companion_tail() != seen else "")


func _pack(reply: String) -> Dictionary:
	return {
		"text": reply,
		"fallback": bool(_last_reply.get("fallback", false)),
		"cloud_aff": _last_reply.get("cloud_aff", null),
		"rel_reason": str(_last_reply.get("rel_reason", "")),
	}


func _ensure_can_chat() -> void:
	await _ack_d4_telegraph()
	await _wait_idle(6.0)
	if _story_blocking():
		await _flip_story(false)
	await _wait_idle(2.0)


func _ack_d4_telegraph() -> void:
	if GameState.game_day != 4:
		return
	if bool(GameState.get_ending_flags().get("d4_telegraph_ack_at_wake", false)):
		return
	var ov: Node = _ui.get("_day_cycle_overlay") if _ui else null
	var n := 0
	while n < 360:
		if ov != null and bool(ov.get("_trust_waiting")):
			ov.set("_trust_waiting", false)
		if bool(GameState.get_ending_flags().get("d4_telegraph_ack_at_wake", false)):
			await _settle(0.2)
			return
		await get_tree().process_frame
		n += 1
	if ov != null:
		ov.set("_trust_waiting", false)
	GameState.set_ending_flag("d4_telegraph_ack_at_wake", true)
	await _settle(0.2)


func _finish_finale() -> void:
	## 只锁结局 id。不要把 EndingPanel 翻完——会切回标题，拆掉本 runner。
	var ending := EndingDirector.resolve_ending(false)
	if bool(GameState.get_ending_flags().get("w2_chose_expel", false)):
		ending = EndingDirector.ENDING_BAD_EARLY
	EndingDirector.lock_ending_id(ending)
	if _ui != null and is_instance_valid(_ui):
		var ep: Node = _ui.get_node_or_null("EndingPanel")
		if ep != null and ep.visible and ep.has_method("close_panel"):
			ep.call("close_panel")
		var ap: Node = _ui.get_node_or_null("AwakeningPanel")
		if ap != null and ap.visible:
			ap.visible = false
	print("  LOCK ending=%s expel=%s" % [
		EndingDirector.resolve_ending(false),
		GameState.get_ending_flags().get("w2_chose_expel", false),
	])


func _open_beat(force: bool) -> void:
	if _ui and _ui.has_method("_maybe_show_story_beat"):
		await _ui.call("_maybe_show_story_beat", force)
	await _settle(0.08)


func _flip_story(stop_on_choice: bool) -> void:
	var panel: Node = _ui.get_node_or_null("StoryBeatPanel") if _ui else null
	if panel == null:
		return
	var guard := 0
	while panel.visible and guard < 80:
		guard += 1
		if bool(panel.get("_is_choice_step")):
			if stop_on_choice:
				break
			break
		if panel.has_method("_on_continue_pressed"):
			panel.call("_on_continue_pressed")
		await _settle(0.05)


func _pick_choice(choice_id: String, labels: Array) -> void:
	var panel: Node = _ui.get_node_or_null("StoryBeatPanel") if _ui else null
	for _i in 50:
		if panel != null and panel.visible and bool(panel.get("_is_choice_step")):
			panel.emit_signal("choice_made", choice_id)
			await _settle(0.2)
			return
		if panel != null and panel.has_method("_on_continue_pressed"):
			panel.call("_on_continue_pressed")
		await _settle(0.06)
	if labels.is_empty():
		pass


func _submit_name(name: String) -> void:
	if _ui and _ui.has_method("_maybe_show_name_prompt"):
		await _ui.call("_maybe_show_name_prompt")
	await _settle(0.1)
	var panel: Node = _ui.get_node_or_null("NamePromptPanel") if _ui else null
	if panel != null and panel.visible:
		panel.get("_name_input").text = name
		panel.call("_submit")
		await _settle(0.2)
	elif not GameState.has_player_name_set():
		GameState.set_player_display_name(name)


func _complete_today_beat() -> void:
	var bid := StoryBeatDirector.get_today_beat_id()
	if bid != "" and not GameState.is_story_node_seen(bid):
		StoryBeatDirector.complete_beat(bid)


func _sleep_night() -> void:
	GameState.time_of_day = GameState.TIME_NIGHT
	GameState._awaiting_sleep = true
	if _ui and _ui.has_method("_on_sleep_prompt_requested"):
		_ui.call("_on_sleep_prompt_requested")
	await _settle(0.1)
	var ov: Node = _ui.get("_day_cycle_overlay") if _ui else null
	if ov and ov.has_method("is_prompt_visible") and ov.call("is_prompt_visible"):
		_ui.call("_on_sleep_now_pressed")
	elif _ui and _ui.has_method("sleep_from_companion"):
		_ui.call("sleep_from_companion")
	var day0 := GameState.game_day
	var n := 0
	while n < 240 and GameState.game_day <= day0:
		if not is_inside_tree() or get_tree() == null:
			return
		if ov and bool(ov.get("_trust_waiting")):
			ov.set("_trust_waiting", false)
		await get_tree().process_frame
		n += 1


func _flip_named(node_name: String) -> void:
	var panel: Node = _ui.get_node_or_null(node_name) if _ui else null
	if panel == null or not panel.visible:
		return
	var guard := 0
	while panel.visible and guard < 80:
		guard += 1
		if panel.has_method("_on_continue_pressed"):
			panel.call("_on_continue_pressed")
		elif panel.has_method("advance"):
			panel.call("advance")
		await _settle(0.08)


func _wait_idle(max_sec: float) -> void:
	var waited := 0.0
	while waited < max_sec:
		if _ui == null or not bool(_ui.get("_npc_busy")):
			if not NpcBridge.is_request_in_flight():
				return
		await get_tree().create_timer(0.2).timeout
		waited += 0.2


func _wait_morning_settled() -> void:
	await _settle(1.0)
	if not is_inside_tree() or get_tree() == null:
		return
	var waited := 0.0
	while waited < 16.0:
		if not is_inside_tree() or get_tree() == null:
			return
		var busy := (_ui != null and is_instance_valid(_ui) and bool(_ui.get("_npc_busy"))) or NpcBridge.is_request_in_flight()
		if busy:
			await get_tree().create_timer(0.25).timeout
			waited += 0.25
			continue
		var quiet := 0.0
		while quiet < 1.0:
			if not is_inside_tree() or get_tree() == null:
				return
			if (_ui != null and is_instance_valid(_ui) and bool(_ui.get("_npc_busy"))) or NpcBridge.is_request_in_flight():
				break
			await get_tree().create_timer(0.2).timeout
			quiet += 0.2
		if quiet >= 1.0:
			break
		waited += quiet
	_last_reply = {}


func _story_blocking() -> bool:
	if _ui == null:
		return true
	for name in ["StoryBeatPanel", "NamePromptPanel", "AwakeningPanel", "EndingPanel"]:
		var n: Node = _ui.get_node_or_null(name)
		if n != null and n.visible:
			return true
	return false


func _companion_tail() -> String:
	var turns := GameState.snapshot_today_chat_log()
	for i in range(turns.size() - 1, -1, -1):
		var turn: Variant = turns[i]
		if not turn is Dictionary:
			continue
		if str(turn.get("role", "")) in ["companion", "assistant", "xiaoli"]:
			return str(turn.get("text", "")).strip_edges()
	return ""


func _on_bridge_reply(_request_id: int, event: String, text: String, used_fallback: bool) -> void:
	if event not in ["player_chat", "session_start", "companion_casual", "companion_proactive", "companion_feed"]:
		return
	## 不要 take 关系分 / meta，留给 main_ui 照常落地。
	_last_reply = {
		"event": event,
		"text": text.strip_edges(),
		"fallback": used_fallback,
	}


func _on_bridge_fail(_request_id: int, event: String, error: String) -> void:
	if event not in ["player_chat", "session_start"]:
		return
	print("  API-FAIL %s %s" % [event, error])


func _settle(sec: float = 0.1) -> void:
	if not is_inside_tree():
		return
	await get_tree().create_timer(sec).timeout


func _print_report() -> void:
	print("\n=== ENDING5 SCORE PROBE ===")
	var length_fail := 0
	var content_ok := 0
	for rec in _probe:
		var expect := str(rec.get("expect", ""))
		var aff := int(rec.get("applied", 0))
		if expect == "farm_cap" and aff <= 2:
			content_ok += 1
		elif expect == "pos" and aff > 0:
			content_ok += 1
		elif expect == "zero" and aff == 0:
			content_ok += 1
		if expect == "farm_cap" and aff >= 3:
			length_fail += 1
		print("  %s Δ%d local=%d len=%d" % [
			str(rec.get("probe_id", "")), aff, int(rec.get("local_aff", 0)),
			int(rec.get("len", 0)),
		])
	print("content_hits=%d/%d length_regressions=%d" % [content_ok, _probe.size(), length_fail])
	print("weights chat_days=%.2f (expect 0.40)" % float(
		RelationshipDirector.get_rules().get("interaction_weights", {}).get("chat_days", 0.0)
	))
	print("\n=== ENDING5 RUNS ===")
	var hit_n := 0
	for row in _runs:
		if bool(row.get("hit", false)):
			hit_n += 1
		print("  %s target=%s got=%s %s" % [
			str(row.get("id", "")),
			str(row.get("target", "")),
			str(row.get("ending", "")),
			"HIT" if bool(row.get("hit", false)) else "MISS",
		])
	print("=== ENDING5 LIVE %d/%d HIT ===" % [hit_n, _runs.size()])


func _quit(code: int) -> void:
	if not is_inside_tree():
		return
	get_tree().quit(code)
