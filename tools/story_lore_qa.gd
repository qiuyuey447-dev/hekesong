extends Node
## 剧情一致性 QA：挂 main.tscn，按十日主线问她，查与剧情/设定/局内事实是否打架。
## godot --headless --path <根> res://tools/story_lore_qa.tscn

const PLAYER := "槐秋"
const EMPTY_TALK := [
	"我在听。说慢点也行，我记性一般。",
	"嗯。刚才那句我接上了，你再说。",
	"……我刚才没听清，你再说一遍好吗？",
]
const FARM_PITCH := [
	"要不要种点什么", "要不要种点", "十八块都空", "十八块地",
	"要不要我去买点种子", "买点种子回来",
]
const META_LEAK := [
	"第五周", "第35", "三十五日", "第几周", "第三十五",
	"主线节点", "导演·勿复述", "信纸",
]
const THIRD_CAST := ["阿嬷", "病房", "医生", "奶奶", "上一任主人"]
const FAKE_MEMORY := ["其实我一直记得", "我只是装忘", "其实没忘", "我装不认得"]
const HEALING := ["再也不忘了", "我全想起来了", "永远记得你", "治好了", "不会再忘"]
const WRONG_CROP := ["向日葵", "番茄", "蓝莓", "小麦", "玉米", "南瓜"]
const DAY_SCRIPT := {
	1: {
		"talks": [
			"我叫槐秋。你记住了吗。",
			"昨天我们是不是见过？",
		],
	},
	2: {
		"talks": [
			"廊下这块干的，你又占上了？",
			"雨还在下吗。",
		],
	},
	3: {
		"morning": [
			"我们是不是已经约好了？",
		],
		"evening_beat": true,
		"evening": [
			"那句「等萝卜长好了」，你写进本子了吗。",
		],
	},
	4: {
		"talks": [
			"你不认得我了？",
			"我叫槐秋。你还记得吗。",
		],
	},
	5: {
		"talks": [
			"本子上那句「不能弄丢这里」，是你写的吗。",
			"留下吧。",
		],
	},
	6: {
		"talks": [
			"这片田你是不是浇过？",
			"我叫什么。",
		],
	},
	7: {
		"talks": [
			"你还认得我一点吗。",
			"我们那句约定还在吗。",
		],
	},
	8: {
		"talks": [
			"两个本子你都翻过了？",
			"日期对不上，你怕吗。",
		],
	},
	9: {
		"talks": [
			"我还在。明天有要紧的话。",
			"这几天你还记得哪些。",
		],
	},
}

var _packed: PackedScene
var _main: Node2D
var _ui: Node
var _fail: Array[String] = []
var _pass_n := 0
var _turns: Array[Dictionary] = []
var _wait_sec := 26.0
var _last_reply := {}
var _promise_ready := false


func _ready() -> void:
	call_deferred("_boot")


func _boot() -> void:
	GameState.persist_saves = false
	print("=== STORY LORE QA (Cloud Run 剧情一致性) START ===")
	if not _require_cloud_run():
		_print_report()
		_quit_runner(1)
		return
	_packed = load("res://scenes/main.tscn") as PackedScene
	NpcBridge.reply_ready.connect(_on_bridge_reply)
	NpcBridge.request_failed.connect(_on_bridge_fail)
	await _spawn()
	await _play_through()
	_print_report()
	Engine.time_scale = 1.0
	if NpcBridge.has_method("cancel_in_flight"):
		NpcBridge.cancel_in_flight()
	_quit_runner(_fail.size())


func _require_cloud_run() -> bool:
	if not NpcBridge.is_api_enabled():
		_fail.append("BOOT API 未开")
		print("  FAIL BOOT API 未开")
		return false
	var url := str(NpcBridge.get_config_value("api_url", "")).strip_edges()
	_wait_sec = maxf(float(NpcBridge.get_config_value("timeout_sec", 22.0)) + 4.0, 20.0)
	print("  API %s" % url)
	if url.contains("127.0.0.1") or url.contains("localhost"):
		_fail.append("BOOT 指向本地")
		print("  FAIL BOOT 指向本地")
		return false
	return true


func _spawn() -> void:
	GameState.reset_for_new_game()
	GameState.affection = 42
	_main = _packed.instantiate() as Node2D
	add_child(_main)
	await get_tree().process_frame
	await get_tree().process_frame
	_ui = _main.get_node("UI")
	Engine.time_scale = 1.0


func _play_through() -> void:
	while GameState.game_day <= GameState.FINAL_GAME_DAY and not GameState.is_story_complete():
		var day := GameState.game_day
		print("----- DAY %d mode=%s wx=%s promise=%s -----" % [
			day, StoryDirector.get_story_mode(), GameState.weather_today,
			GameState.has_story_promise(),
		])
		await _ack_d4_telegraph()
		await _unlock_day_story()
		await _wait_morning_settled()
		if day == 10 or GameState.should_show_awakening():
			await _finish_finale()
			break
		var script: Dictionary = DAY_SCRIPT.get(day, {})
		for item in script.get("morning", script.get("talks", [])):
			await _talk(str(item))
		if bool(script.get("evening_beat", false)):
			await _play_evening_story()
			_promise_ready = GameState.has_story_promise()
		for item in script.get("evening", []):
			await _talk(str(item))
		await _complete_today_beat()
		if GameState.has_story_promise():
			_promise_ready = true
		if GameState.game_day >= GameState.FINAL_GAME_DAY:
			await _finish_finale()
			break
		var day_before := GameState.game_day
		await _sleep_night()
		if GameState.game_day <= day_before:
			print("  STOP 过天失败，停在 D%d" % day_before)
			break
		await _wait_morning_settled()


func _unlock_day_story() -> void:
	await _open_beat(true)
	if GameState.game_day == 1:
		await _submit_name(PLAYER)
	await _flip_story(true)
	if GameState.game_day == 5:
		await _pick_choice("w2_keep", ["留下"])
	if GameState.game_day == 7:
		await _pick_choice("companion_sit", ["坐下", "过去"])
	await _flip_story(false)


func _play_evening_story() -> void:
	GameState.time_of_day = GameState.TIME_EVENING
	await _open_beat(true)
	await _flip_story(false)
	if GameState.game_day == 3 and not GameState.has_story_promise():
		StoryBeatDirector.complete_beat("P_N11")
	await _wait_morning_settled()


func _talk(text: String) -> void:
	await _ensure_can_chat()
	if _story_blocking():
		_check(false, "D%d-lock" % GameState.game_day, "信纸挡住「%s」" % text)
		return
	var before := _companion_tail()
	_last_reply = {}
	NpcBridge.last_validation_reason = ""
	_ui.call("_send_chat", text)
	var result := await _wait_companion(before)
	_judge(GameState.game_day, text, result)


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
	var reason := str(_last_reply.get("reason", "")).strip_edges()
	if reason == "":
		reason = str(NpcBridge.last_validation_reason).strip_edges()
	return {
		"text": reply,
		"fallback": bool(_last_reply.get("fallback", false)),
		"source": str(_last_reply.get("source", "")),
		"reason": reason,
	}


func _judge(day: int, ask: String, result: Dictionary) -> void:
	var reply := str(result.get("text", "")).strip_edges()
	var used_fallback := bool(result.get("fallback", false))
	var reason := str(result.get("reason", ""))
	var id := "D%d" % day
	_turns.append({"day": day, "ask": ask, "reply": reply, "fallback": used_fallback, "reason": reason})
	print("  %s 「%s」 fb=%s reason=%s" % [id, ask, used_fallback, reason if reason != "" else "-"])
	print("       %s" % (reply if reply != "" else "(空)"))
	if used_fallback:
		var rejected := str(NpcBridge.last_rejected_reply).strip_edges()
		if rejected != "" and rejected != reply:
			print("       rejected: %s" % rejected.substr(0, 80).replace("\n", " "))
	_check(reply != "", "%s-got" % id, "有回复")
	if reply == "":
		return
	_check(not _is_empty_talk(reply), "%s-empty" % id, "不是空话库存")
	if used_fallback:
		_check(false, "%s-fb" % id, "走了兜底%s" % ((" " + reason) if reason != "" else ""))
	_check(not _has_any(reply, META_LEAK), "%s-meta" % id, "不漏系统/五周话术")
	_check(not _has_any(reply, THIRD_CAST), "%s-cast" % id, "不引入第三人")
	_check(not _has_any(reply, FAKE_MEMORY), "%s-fake" % id, "失忆是真的")
	_check(not _has_any(reply, HEALING), "%s-heal" % id, "不写成治愈")
	_check(not _has_any(reply, WRONG_CROP), "%s-crop" % id, "不提没有的作物")
	_check("聊天 ·" not in reply and "你们聊了" not in reply, "%s-jargon" % id, "不念后台目录")
	if day == 1 and "昨天" in reply:
		_check(false, "%s-yday" % id, "第1天不该说昨天")
	if GameState.weather_today == GameState.WEATHER_RAIN:
		_check(not _has_any(reply, ["天晴", "出太阳", "晒太阳", "今天不下雨"]), "%s-wx" % id, "雨天不说晴")
	elif GameState.weather_today == GameState.WEATHER_SUN:
		_check(not _has_any(reply, ["正在下雨", "还在下雨", "雨下得", "等雨停"]), "%s-wx" % id, "晴天不说正在下雨")
	_judge_name(day, ask, reply, id)
	_judge_promise(day, ask, reply, id)
	_judge_stranger(day, reply, id)
	if _is_story_ask(ask) and _has_any(reply, FARM_PITCH):
		_check(false, "%s-off" % id, "问剧情却推销种田")
	if "留下" in ask and _has_any(reply, ["我这就去浇", "这就去浇", "去浇水"]):
		_check(false, "%s-stay" % id, "留下不该改口去浇")
	if "写进本子" in ask and _has_any(reply, ["你记住了吗", "我叫%s" % PLAYER]):
		_check(false, "%s-quote" % id, "约定本子不该写成名字")


func _judge_name(day: int, ask: String, reply: String, id: String) -> void:
	var can_say := GameState.companion_can_say_player_name()
	if day in [4, 5, 6]:
		_check(PLAYER not in reply, "%s-noname" % id, "陌生/渗漏期不准叫名")
		return
	if GameState.looks_like_name_recall_question(ask) and can_say:
		_check(PLAYER in reply, "%s-name" % id, "可叫名时问名须答出")
	if can_say and day <= 3 and _claims_forgot_name(reply):
		_check(false, "%s-amnesia" % id, "前三日不该装忘名字")


func _judge_promise(day: int, ask: String, reply: String, id: String) -> void:
	var claims := _claims_stored_promise(reply)
	if day <= 2 or (day == 3 and not _promise_ready):
		if claims:
			_check(false, "%s-premature" % id, "约定未写入前不该当已有约定")
		return
	if day in [4, 5] and claims:
		_check(false, "%s-stranger-p" % id, "陌生化不准复述约定原文")


func _judge_stranger(day: int, reply: String, id: String) -> void:
	if day not in [4, 5]:
		return
	_check(not _has_any(reply, ["又见面了", "欢迎回来", "还记得我们", "想你了"]), "%s-ooc" % id, "陌生化不出戏")


func _is_story_ask(ask: String) -> bool:
	return _has_any(ask, ["本子", "认得", "记得", "约定", "叫什么", "留下", "浇过", "日期"])


func _claims_stored_promise(text: String) -> bool:
	for phrase in ["本子上写着", "有个约定", "我们约过", "你说过等", "等萝卜长好了，我们一起"]:
		if phrase in text:
			return true
	return false


func _claims_forgot_name(text: String) -> bool:
	return _has_any(text, ["叫什么来着", "忘了你叫", "想不起你叫", "记不清你叫", "忘了你的名字"])


func _has_any(text: String, phrases: Array) -> bool:
	for phrase in phrases:
		if str(phrase) in text:
			return true
	return false


func _is_empty_talk(text: String) -> bool:
	var cleaned := text.strip_edges()
	if cleaned == "":
		return true
	for line in EMPTY_TALK:
		if cleaned == line or cleaned.begins_with(line):
			return true
	return false


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
	if GameState.should_show_awakening() or GameState.game_day >= GameState.FINAL_GAME_DAY:
		if _ui.has_method("_maybe_show_awakening"):
			_ui.call("_maybe_show_awakening")
		await _settle(0.3)
		await _flip_named("AwakeningPanel")
	if not GameState.is_story_complete() and _ui.has_method("_play_ending"):
		_ui.call("_play_ending", EndingDirector.resolve_ending(false))
		await _settle(0.2)
		await _flip_named("EndingPanel")
	_check(GameState.is_story_complete() or GameState.has_seen_awakening(), "FIN", "走到觉醒或结局")


func _open_beat(force: bool) -> void:
	if _ui and _ui.has_method("_maybe_show_story_beat"):
		await _ui.call("_maybe_show_story_beat", force)
	await _settle(0.08)


func _flip_story(stop_on_choice: bool) -> void:
	var panel: Node = _ui.get_node_or_null("StoryBeatPanel")
	if panel == null:
		return
	var guard := 0
	while panel.visible and guard < 80:
		guard += 1
		if stop_on_choice and bool(panel.get("_is_choice_step")):
			break
		if bool(panel.get("_is_choice_step")):
			break
		if panel.has_method("_on_continue_pressed"):
			panel.call("_on_continue_pressed")
		await _settle(0.05)


func _pick_choice(choice_id: String, labels: Array) -> void:
	var panel: Node = _ui.get_node_or_null("StoryBeatPanel")
	for _i in 50:
		if panel != null and panel.visible and bool(panel.get("_is_choice_step")):
			for b in panel.get("_choice_buttons"):
				if not b is Button:
					continue
				var t := str(b.text)
				for lab in labels:
					if str(lab) in t:
						panel.emit_signal("choice_made", choice_id)
						await _settle(0.15)
						return
			panel.emit_signal("choice_made", choice_id)
			await _settle(0.15)
			return
		if panel != null and panel.has_method("_on_continue_pressed"):
			panel.call("_on_continue_pressed")
		await _settle(0.06)


func _submit_name(name: String) -> void:
	if _ui.has_method("_maybe_show_name_prompt"):
		await _ui.call("_maybe_show_name_prompt")
	await _settle(0.1)
	var panel: Node = _ui.get_node_or_null("NamePromptPanel")
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
	if _ui.has_method("_on_sleep_prompt_requested"):
		_ui.call("_on_sleep_prompt_requested")
	await _settle(0.1)
	var ov: Node = _ui.get("_day_cycle_overlay")
	if ov and ov.has_method("is_prompt_visible") and ov.call("is_prompt_visible"):
		_ui.call("_on_sleep_now_pressed")
	elif _ui.has_method("sleep_from_companion"):
		_ui.call("sleep_from_companion")
	var day0 := GameState.game_day
	var n := 0
	while n < 240 and GameState.game_day <= day0:
		if ov and bool(ov.get("_trust_waiting")):
			ov.set("_trust_waiting", false)
		await get_tree().process_frame
		n += 1
	_check(GameState.game_day > day0, "SLEEP-D%d" % day0, "过天 D%d→D%d" % [day0, GameState.game_day])


func _flip_named(node_name: String) -> void:
	var panel: Node = _ui.get_node_or_null(node_name)
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
	await _settle(1.2)
	var waited := 0.0
	while waited < 18.0:
		var busy := (_ui != null and bool(_ui.get("_npc_busy"))) or NpcBridge.is_request_in_flight()
		if busy:
			await get_tree().create_timer(0.25).timeout
			waited += 0.25
			continue
		var quiet := 0.0
		while quiet < 1.2:
			if (_ui != null and bool(_ui.get("_npc_busy"))) or NpcBridge.is_request_in_flight():
				break
			await get_tree().create_timer(0.2).timeout
			quiet += 0.2
		if quiet >= 1.2:
			break
		waited += quiet
	_last_reply = {}


func _story_blocking() -> bool:
	if _ui == null:
		return true
	var story: Node = _ui.get_node_or_null("StoryBeatPanel")
	var namep: Node = _ui.get_node_or_null("NamePromptPanel")
	var aw: Node = _ui.get_node_or_null("AwakeningPanel")
	var en: Node = _ui.get_node_or_null("EndingPanel")
	return (
		(story != null and story.visible)
		or (namep != null and namep.visible)
		or (aw != null and aw.visible)
		or (en != null and en.visible)
	)


func _companion_tail() -> String:
	var turns := GameState.snapshot_today_chat_log()
	for i in range(turns.size() - 1, -1, -1):
		var turn: Variant = turns[i]
		if not turn is Dictionary:
			continue
		if str(turn.get("role", "")) in ["companion", "assistant", "xiaoli"]:
			return str(turn.get("text", "")).strip_edges()
	return ""


func _on_bridge_reply(request_id: int, event: String, text: String, used_fallback: bool) -> void:
	if event not in ["player_chat", "session_start", "companion_casual", "companion_proactive"]:
		return
	var meta := NpcBridge.take_response_meta(request_id)
	var reason := str(meta.get("fallback_reason", "")).strip_edges()
	if reason == "":
		reason = str(NpcBridge.last_validation_reason).strip_edges()
	_last_reply = {
		"event": event,
		"text": text.strip_edges(),
		"fallback": used_fallback,
		"source": str(meta.get("source", "")),
		"reason": reason,
	}


func _on_bridge_fail(_request_id: int, event: String, error: String) -> void:
	if event not in ["player_chat", "session_start"]:
		return
	if "校验层拦截" in error:
		NpcBridge.last_validation_reason = error.get_slice(": ", 1)
		_last_reply["reason"] = NpcBridge.last_validation_reason


func _settle(sec: float = 0.1) -> void:
	if not is_inside_tree():
		return
	var tree := get_tree()
	if tree == null:
		return
	await tree.create_timer(sec).timeout


func _check(ok: bool, id: String, detail: String) -> void:
	if ok:
		_pass_n += 1
		print("  PASS %s %s" % [id, detail])
	else:
		_fail.append("%s %s" % [id, detail])
		print("  FAIL %s %s" % [id, detail])


func _print_report() -> void:
	print("=== TURNS %d ===" % _turns.size())
	for turn in _turns:
		print("  D%d %s → %s" % [
			int(turn.get("day", 0)),
			str(turn.get("ask", "")),
			str(turn.get("reply", "")).substr(0, 70).replace("\n", " "),
		])
	print("=== STORY LORE QA %d PASS / %d FAIL ===" % [_pass_n, _fail.size()])
	for line in _fail:
		print(" - %s" % line)
	if _fail.is_empty():
		print("=== STORY LORE QA ALL PASS ===")
	else:
		print("=== STORY LORE QA NOT READY ===")


func _quit_runner(code: int) -> void:
	if not is_inside_tree():
		return
	var tree := get_tree()
	if tree == null:
		return
	tree.quit(code)
