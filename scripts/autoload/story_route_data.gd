extends Node
## 五条结局路线 · 独立节点表与台词（互不共用 beat_id）。

const ROUTE_PROLOGUE := "prologue"
const ROUTE_NORMAL := "ending_normal"
const ROUTE_HAPPY := "ending_happy"
const ROUTE_TRUE := "ending_true"
const ROUTE_BAD := "ending_bad"
const ROUTE_BAD_EARLY := "ending_bad_early"

const ROUTE_LABELS := {
	ROUTE_PROLOGUE: "序章",
	ROUTE_NORMAL: "安顿",
	ROUTE_HAPPY: "共处",
	ROUTE_TRUE: "归来",
	ROUTE_BAD: "雾中",
	ROUTE_BAD_EARLY: "放手",
}

# 十日版日程：D1–D5 序章 → D5 抉择 → D6–D9 路线节点 → D10 觉醒（无日历 beat）
const DAY_BEATS := {
	ROUTE_PROLOGUE: {
		1: "P_N01", 2: "P_N02", 3: "P_N11", 4: "P_N05", 5: "P_N06p",
	},
	ROUTE_BAD_EARLY: {
		6: "BE_N07",
	},
	ROUTE_NORMAL: {
		6: "NM_N02p", 7: "NM_N16", 8: "NM_N15", 9: "NM_N20c",
	},
	ROUTE_HAPPY: {
		6: "HP_N02p", 7: "HP_N16", 8: "HP_N15", 9: "HP_N20c",
	},
	ROUTE_TRUE: {
		6: "TR_N02p", 7: "TR_N16", 8: "TR_N15", 9: "TR_N20c",
	},
	ROUTE_BAD: {
		6: "BL_N02p", 7: "BL_N16", 8: "BL_N15", 9: "BL_N20c",
	},
}

# 由其它 UI 触发的节点（选择 / 周结算 / 终章 / 投喂）
const EXTERNAL_BEATS := ["N04", "N08", "N08p", "N20"]

# 节点正文已自带开场时，不再注入「清晨 / 小狸想说」
const COMPANION_NIGHT_CHOICE_STEP := {
	"title": "你的选择",
	"kind": "choice",
	"choices": [],
}


func companion_night_choice_step(hint: String = "") -> Dictionary:
	var step: Dictionary = {
		"title": "你的选择",
		"kind": "choice",
		"choices": [
			{"id": "companion_sit", "label": StoryNodeCopy.get_choice("companion_sit")},
			{"id": "companion_leave", "label": StoryNodeCopy.get_choice("companion_leave")},
		],
	}
	if hint.strip_edges() != "":
		step["body"] = hint
	return step


const PROLOGUE_SELF_CONTAINED := [
	"P_N01", "P_N02", "P_N03", "P_N01p", "P_N04", "P_N05", "P_N06", "P_N06p", "P_N11", "P_N12",
]


func get_day_beats(route: String) -> Dictionary:
	var beats: Variant = DAY_BEATS.get(route, {})
	if beats is Dictionary:
		return beats
	return {}


func get_beat_id_for_day(route: String, game_day: int) -> String:
	return str(get_day_beats(route).get(game_day, ""))


func should_inject_morning_opening(beat_id: String) -> bool:
	if is_night_beat(beat_id):
		return false
	if GameState.has_pending_absence() and not StoryDirector.is_stranger_mode():
		return true
	## 十日版 D4：陌生化需 telegraph 清晨，即使节点正文自洽也要注入
	if GameState.IS_TEN_DAY_EDITION and beat_id == "P_N05":
		return true
	if beat_id in PROLOGUE_SELF_CONTAINED:
		return false
	return true


func should_inject_evening_opening(beat_id: String) -> bool:
	return is_night_beat(beat_id)


func is_night_beat(beat_id: String) -> bool:
	return beat_id.ends_with("_N14n") or beat_id.ends_with("_N17")


func should_inject_proactive_nudge(beat_id: String) -> bool:
	if is_night_beat(beat_id):
		return false
	if beat_id in PROLOGUE_SELF_CONTAINED:
		return false
	return StoryDirector.should_proactive_nudge()


func get_beat_def(beat_id: String) -> Dictionary:
	var base := _base_def(beat_id)
	if base.is_empty():
		return {}
	var template_key := str(base.get("template", beat_id))
	base["template_key"] = template_key
	return base


func render_body(beat_id: String, template_key: String = "") -> String:
	if template_key == "":
		template_key = beat_id
	var ctx_extra := {
		"beat_id": beat_id,
		"template_key": template_key,
	}
	if beat_id.ends_with("_N15") and GameState.IS_TEN_DAY_EDITION:
		ctx_extra["journal_max_lines"] = StoryBeatDirector.get_n15_journal_max_lines(beat_id)
	var raw := _render_template(beat_id, template_key)
	return StorySlotService.apply(raw, StorySlotService.build_context(ctx_extra))


func get_route_for_ending(ending_id: String) -> String:
	match ending_id:
		EndingDirector.ENDING_NORMAL:
			return ROUTE_NORMAL
		EndingDirector.ENDING_HAPPY:
			return ROUTE_HAPPY
		EndingDirector.ENDING_TRUE:
			return ROUTE_TRUE
		EndingDirector.ENDING_BAD:
			return ROUTE_BAD
		EndingDirector.ENDING_BAD_EARLY:
			return ROUTE_BAD_EARLY
		_:
			return ROUTE_NORMAL


func _base_def(beat_id: String) -> Dictionary:
	if beat_id == "BE_N07":
		return {
			"node_label": "BE_N07",
			"emotion": "最后一餐",
			"recovery": 0.0,
			"fragment": "",
			"template": "BE_N07",
			"steps": [{"title": "离开前", "template": "BE_N07"}],
		}
	if beat_id.begins_with("P_"):
		return _prologue_def(beat_id)
	if beat_id in ["BE_N01", "BE_N11", "BE_N12", "BE_N05", "BE_N06"]:
		return _prologue_def("P_%s" % beat_id.substr(3))
	var prefix := beat_id.split("_")[0] if "_" in beat_id else ""
	var suffix := beat_id.substr(beat_id.find("_") + 1) if "_" in beat_id else beat_id
	return _route_def(prefix, suffix, beat_id)


func _prologue_def(beat_id: String) -> Dictionary:
	match beat_id:
		"P_N01":
			return {"node_label": "N01", "emotion": "登门", "recovery": 0.06, "fragment": "", "template": "P_N01",
				"steps": [{"title": "登门", "template": "P_N01"}]}
		"P_N02":
			return {"node_label": "N02", "emotion": "日常", "recovery": 0.04, "fragment": "", "template": "P_N02",
				"steps": [
					{"title": "雨天廊下", "template": "P_N02"},
					{"title": "这块干的", "template": "P_N02_b"},
				]}
		"P_N03":
			return {"node_label": "N03", "emotion": "日常", "recovery": 0.04, "fragment": "", "template": "P_N03",
				"steps": [
					{"title": "黄昏看田", "template": "P_N03"},
					{"title": "小狸想说", "template": "P_N03_nudge"},
				]}
		"P_N01p":
			return {"node_label": "N01′", "emotion": "伏笔", "recovery": 0.03, "fragment": "", "template": "P_N01p",
				"steps": [{"title": "记错浇水", "template": "P_N01p"}]}
		"P_N04":
			return {"node_label": "N04", "emotion": "第一周末", "recovery": 0.05, "fragment": "", "template": "P_N04",
				"steps": [{"title": "第一周末", "template": "P_N04"}]}
		"P_N11":
			return {"node_label": "N11", "emotion": "约定", "recovery": 0.08, "fragment": "", "template": "P_N11",
				"steps": [
					{"title": "跟浇", "template": "P_N03"},
					{"title": "约定", "template": "P_N11"},
				]}
		"P_N12":
			return {"node_label": "N12", "emotion": "兑现", "recovery": 0.05, "fragment": "", "template": "P_N12",
				"steps": [{"title": "约定进行中", "template": "P_N12"}]}
		"P_N05":
			return {"node_label": "N05", "emotion": "失去", "recovery": 0.06, "fragment": "", "template": "P_N05",
				"steps": [
					{"title": "失去", "template": "P_N05"},
					{"title": "垄还认得", "template": "P_N05_b"},
				]}
		"P_N06":
			return {"node_label": "N06", "emotion": "确认", "recovery": 0.08, "fragment": "", "template": "P_N06",
				"steps": [
					{"title": "发现本子", "template": "P_N06_a"},
					{"title": "对不上的日期", "template": "P_N06_b"},
				]}
		"P_N06p":
			return {"node_label": "N06′", "emotion": "选择", "recovery": 0.05, "fragment": "", "template": "P_N06p",
				"steps": [
					{"title": "发现本子", "template": "P_N06_a"},
					{"title": "对不上的日期", "template": "P_N06_b"},
					{"title": "抉择", "template": "P_N06p"},
					{"title": "你的选择", "kind": "choice", "choices": [
						{"id": "w2_keep", "label": StoryNodeCopy.get_choice("w2_keep")},
						{"id": "w2_expel", "label": StoryNodeCopy.get_choice("w2_expel")},
					]},
				]}
		_:
			return {}


func _route_def(prefix: String, suffix: String, beat_id: String) -> Dictionary:
	var fragment := ""
	var steps: Array = []
	var emotion := ""
	var recovery := 0.06
	match suffix:
		"N07":
			emotion = "碎光预兆" if prefix != "BL" else "疏远"
			recovery = 0.06 if prefix != "BL" else 0.02
			steps = [{"title": "投喂", "template": beat_id}]
		"N09":
			emotion = "回转" if prefix != "BL" else "隔雾"
			steps = [{"title": "帮工来过？", "template": beat_id}]
		"N02p":
			emotion = "似曾相识" if GameState.IS_TEN_DAY_EDITION else "场景"
			recovery = 0.08
			fragment = "F01" if prefix != "BL" else ""
			var n02p_title := "似曾相识" if GameState.IS_TEN_DAY_EDITION else "雨天廊下"
			steps = [{"title": n02p_title, "template": "%s_a" % beat_id}]
			if GameState.IS_TEN_DAY_EDITION:
				steps.append({"title": "手还记得", "template": "%s_b" % beat_id})
			if fragment != "":
				steps.append({"title": "登门", "template": "F01", "kind": "fragment"})
		"N13":
			emotion = "渗漏"
			steps = [{"title": "约定半句", "template": beat_id}]
		"N14":
			emotion = "场景"
			recovery = 0.08
			fragment = "F02"
			steps = [
				{"title": "收获时", "template": beat_id},
				{"title": "第一粒种", "template": "F02", "kind": "fragment"},
			]
		"N15":
			emotion = "本子" if GameState.IS_TEN_DAY_EDITION else "周末"
			recovery = 0.08
			fragment = "F03"
			steps = [
				{"title": "树洞的本子", "template": beat_id},
				{"title": "小狸的本子", "template": "F03", "kind": "fragment"},
			]
		"N16":
			emotion = "回响" if GameState.IS_TEN_DAY_EDITION else ("名字" if prefix != "BL" else "几乎叫出")
			recovery = 0.10 if prefix != "BL" else 0.04
			fragment = "F07" if prefix != "BL" and GameState.IS_TEN_DAY_EDITION else ""
			var n16_title := "名字与约定" if GameState.IS_TEN_DAY_EDITION else "叫出名字"
			steps = [{"title": n16_title, "template": beat_id}]
			if GameState.IS_TEN_DAY_EDITION:
				var night_step := companion_night_choice_step("夜深了。你可以过去坐下，也可以先回屋。")
				night_step["period_gate"] = [GameState.TIME_EVENING, GameState.TIME_NIGHT]
				steps.append(night_step)
				if fragment != "":
					steps.append({"title": "名字", "template": "F07", "kind": "fragment"})
		"N11p":
			emotion = "约定"
			recovery = 0.08
			fragment = "F04"
			steps = [
				{"title": "复述约定", "template": beat_id},
				{"title": "傍晚的约定", "template": "F04", "kind": "fragment"},
			]
		"N14n":
			emotion = "夜"
			recovery = 0.04
			steps = [
				{"title": "夜 · 树洞", "template": beat_id},
				companion_night_choice_step(),
			]
		"N17":
			emotion = "起雾" if prefix != "BL" else "独自夜坐"
			recovery = 0.08
			fragment = "F05" if prefix != "BL" else ""
			steps = [{"title": "夜 · 树洞", "template": beat_id}]
			steps.append(companion_night_choice_step("这个选择可能会影响后来的故事。"))
			if fragment != "":
				steps.append({"title": "弄丢的东西", "template": "F05", "kind": "fragment"})
		"N18p":
			emotion = "坚持" if prefix != "BL" else "未能坚持"
			recovery = 0.10 if prefix != "BL" else 0.03
			fragment = "F06" if prefix != "BL" else ""
			steps = [{"title": "坚持", "template": beat_id}]
			if fragment != "":
				steps.append({"title": "你没有赶她走", "template": "F06", "kind": "fragment"})
		"N19":
			var n19_recovery := 0.12 if prefix == "TR" else (0.10 if prefix == "HP" else (0.08 if prefix == "NM" else 0.04))
			emotion = "连续" if prefix in ["TR", "HP"] else ("断续" if prefix == "BL" else "回忆有限")
			recovery = n19_recovery
			steps = [
				{"title": "回忆 · 登门", "template": "%s_a" % beat_id},
				{"title": "回忆 · 约定", "template": "%s_b" % beat_id},
				{"title": "回忆 · 本子", "template": "%s_c" % beat_id},
				{"title": "连成一线", "template": beat_id},
			]
		"N20a":
			emotion = "名字"
			recovery = 0.08
			fragment = "F07" if prefix != "BL" else ""
			steps = [{"title": "稳定叫名", "template": beat_id}]
			if fragment != "":
				steps.append({"title": "名字", "template": "F07", "kind": "fragment"})
		"N20b":
			emotion = "信"
			recovery = 0.10
			fragment = "F08" if prefix != "BL" else ""
			steps = [{"title": "写给自己的信", "template": "%s_a" % beat_id}]
			if fragment != "":
				steps.append({"title": "信的第一页", "template": "F08", "kind": "fragment"})
				steps.append({"title": "信的后半", "template": "%s_b" % beat_id})
				steps.append({"title": "信的后半", "template": "F09", "kind": "fragment"})
			else:
				steps.append({"title": "信", "template": "%s_b" % beat_id})
		"N20c":
			emotion = "前夜" if GameState.IS_TEN_DAY_EDITION else ("前夕" if prefix != "BL" else "雾夜")
			var n20c_title := "前夜" if GameState.IS_TEN_DAY_EDITION else "明天"
			steps = [{"title": n20c_title, "template": beat_id}]
			if GameState.IS_TEN_DAY_EDITION:
				steps.append({"title": "灯还亮着", "template": "%s_b" % beat_id})
		"N08p":
			emotion = "周末"
			recovery = 0.05
			steps = [{"title": "第四周末", "template": beat_id}]
		"N33":
			emotion = "宁静"
			recovery = 0.04
			steps = [{"title": "宁静的一天", "template": beat_id}]
		_:
			return {}
	return {
		"node_label": beat_id,
		"emotion": emotion,
		"recovery": recovery,
		"fragment": fragment,
		"template": beat_id,
		"steps": steps,
	}


func _render_template(beat_id: String, key: String) -> String:
	var companion := StorySlotService.slot("companion_name")
	var crop := StorySlotService.slot("crop_label")
	var nights := int(GameState.get_ending_flags().get("companionship_nights", 0))

	if StoryNodeCopy.has_template(key):
		return _format_node_text(StoryNodeCopy.get_template(key), companion, crop)

	if key.begins_with("F"):
		return _fragment_body(key, _fragment_fallback(key))

	var route_tone := _route_tone(beat_id)
	if route_tone == "bad_early":
		route_tone = "bad"

	if key.ends_with("_N07"):
		return StorySlotService.render_gift_deja_vu(_route_tone(beat_id))

	if key.ends_with("_N13") or key.ends_with("_N11p"):
		var suffix_key := "_N13" if key.ends_with("_N13") else "_N11p"
		var routed := StoryNodeCopy.get_route(suffix_key, route_tone)
		if routed.strip_edges() != "":
			return StorySlotService.apply(
				routed,
				StorySlotService.build_context({"beat_id": beat_id})
			)
		return StorySlotService.render_promise_line(route_tone)

	if key.ends_with("_N16"):
		return _render_n16_line(beat_id, route_tone)

	if key.ends_with("_N02p_chat"):
		return _render_n02p_chat_line(beat_id)

	if "_N02p_a_nochat" in key or "_N02p_b_nochat" in key:
		var nochat_suffix := "_N02p_a_nochat" if "_N02p_a_nochat" in key else "_N02p_b_nochat"
		var routed := StoryNodeCopy.get_route(nochat_suffix, route_tone)
		if routed.strip_edges() == "":
			routed = StoryNodeCopy.get_route(nochat_suffix, route_tone, "default")
		return _format_node_text(routed, companion, crop)

	if _is_n20c_tier_key(key):
		return _render_n20c_tier_line(beat_id, key, route_tone)

	if _is_n15_tier_key(key):
		return _render_n15_tier_line(beat_id, key, route_tone)

	if key == "_N15_journal":
		var journal := StoryNodeCopy.get_template("_N15_journal")
		if "{" in journal:
			journal = StorySlotService.apply(
				journal,
				StorySlotService.build_context({
					"beat_id": beat_id,
					"journal_max_lines": StoryBeatDirector.get_n15_journal_max_lines(beat_id),
				})
			)
		return journal

	if key.ends_with("_N20a"):
		return _render_n20a_line(beat_id, route_tone)

	if key.ends_with("_N19_a") or key.ends_with("_N19_b") or key.ends_with("_N19_c"):
		return _render_n19_part(beat_id, key, route_tone)

	for suffix in [
		"_N02p_a", "_N02p_b", "_N14", "_N15", "_N14n", "_N18p", "_N19", "_N20b_a", "_N20b_b", "_N20c", "_N20c_b", "_N08p", "_N33",
	]:
		if key.ends_with(suffix):
			if suffix in ["_N20b_a", "_N20b_b"]:
				return _render_n20b_part(beat_id, suffix, route_tone)
			var routed := StoryNodeCopy.get_route(suffix, route_tone)
			if "{" in routed:
				var ctx_extra := {"beat_id": beat_id}
				if beat_id.ends_with("_N15") and GameState.IS_TEN_DAY_EDITION:
					ctx_extra["journal_max_lines"] = StoryBeatDirector.get_n15_journal_max_lines(beat_id)
				routed = StorySlotService.apply(
					routed,
					StorySlotService.build_context(ctx_extra)
				)
			return _format_node_text(routed, companion, crop)

	if key.ends_with("_N09"):
		var n09 := StoryNodeCopy.get_route("_N09", route_tone)
		if route_tone == "happy":
			return n09
		if route_tone == "true":
			return n09 % [companion, crop]
		if route_tone == "bad":
			return n09 % companion
		return n09 % [crop, companion]

	if key.ends_with("_N17"):
		if route_tone == "bad":
			return StoryNodeCopy.get_route("_N17", route_tone) % companion
		if nights >= 1 and route_tone in ["true", "happy"]:
			var warm_night := StoryNodeCopy.get_route("_N17", route_tone, "true_nights")
			if warm_night.strip_edges() != "":
				return warm_night % companion
		var n17 := StoryNodeCopy.get_route("_N17", route_tone)
		if n17.strip_edges() != "":
			return n17 % companion
		return StoryNodeCopy.get_route("_N17", route_tone, "default") % companion

	return ""


func _render_n16_line(beat_id: String, route_tone: String) -> String:
	var variant := ""
	if GameState.IS_TEN_DAY_EDITION:
		match StoryBeatDirector.get_n16_profile(beat_id):
			"warm":
				if route_tone in ["true", "happy"]:
					variant = route_tone
				elif route_tone == "normal":
					var persona: Dictionary = GameState.get_persona_vector()
					var warm := float(persona.get("warm", 0.5))
					var strict := float(persona.get("strict", 0.5))
					if warm >= strict + 0.12:
						variant = "normal_warm"
					elif strict >= warm + 0.12:
						variant = "normal_strict"
					else:
						variant = "normal_warm"
				else:
					variant = "default"
			"cold":
				variant = "cold"
			_:
				if route_tone == "normal":
					variant = "mid"
				else:
					variant = route_tone
	elif route_tone == "normal":
		var persona: Dictionary = GameState.get_persona_vector()
		var warm := float(persona.get("warm", 0.5))
		var strict := float(persona.get("strict", 0.5))
		if warm >= strict + 0.12:
			variant = "normal_warm"
		elif strict >= warm + 0.12:
			variant = "normal_strict"
	var n16 := StoryNodeCopy.get_route("_N16", route_tone, variant)
	if n16.strip_edges() == "":
		n16 = StoryNodeCopy.get_route("_N16", route_tone)
	if n16.strip_edges() != "":
		return StorySlotService.apply(
			n16,
			StorySlotService.build_context({"beat_id": beat_id})
		)
	return StorySlotService.render_player_name_line(route_tone)


func _render_n02p_chat_line(_beat_id: String) -> String:
	var companion := StorySlotService.slot("companion_name")
	var snippet := extract_chat_snippet_for_beat(_beat_id)
	var routed := StoryNodeCopy.get_route("_N02p_chat", "default", "default")
	if routed.strip_edges() != "":
		return routed % [companion, snippet]
	return "%s 从怀里摸出本子，指尖停在一行字上，停了停：「……我记得是——『%s』」" % [companion, snippet]


func extract_chat_snippet_for_beat(_beat_id: String) -> String:
	var yesterday := GameState.get_yesterday_journal_entry()
	var snippet := str(yesterday.get("chat_summary", "")).strip_edges()
	if snippet == "":
		var highlights: Variant = yesterday.get("highlights", [])
		if highlights is Array:
			for raw in highlights:
				var line := str(raw).strip_edges()
				if line == "":
					continue
				if line.begins_with("主线"):
					continue
				snippet = line
				break
	if snippet == "":
		snippet = str(yesterday.get("summary", "")).strip_edges()
	if snippet == "":
		snippet = GameState.last_day_summary.strip_edges()
	if snippet == "":
		for turn in GameState.get_recent_chat_turns(8):
			if not turn is Dictionary:
				continue
			if str(turn.get("role", "")) != "player":
				continue
			snippet = str(turn.get("text", "")).strip_edges()
			if snippet != "":
				break
	if snippet == "":
		snippet = "你说过的话，她本子上有一行，字迹比正文轻。"
	return normalize_personal_snippet(snippet)


func normalize_personal_snippet(text: String) -> String:
	var cleaned := text.strip_edges()
	for prefix in ["你说：", "你说:", "聊天 · ", "聊天·"]:
		if cleaned.begins_with(prefix):
			cleaned = cleaned.substr(prefix.length()).strip_edges()
	cleaned = cleaned.trim_prefix("「").trim_prefix("『").trim_suffix("」").trim_suffix("』").strip_edges()
	if cleaned.length() > 28:
		cleaned = cleaned.substr(0, 28).strip_edges() + "…"
	return cleaned


func render_n02p_chat_line(beat_id: String) -> String:
	return _render_n02p_chat_line(beat_id)


func _is_n20c_tier_key(key: String) -> bool:
	if not key.contains("_N20c"):
		return false
	return key.ends_with("_warm") or key.ends_with("_cold")


func _is_n15_tier_key(key: String) -> bool:
	if not key.contains("_N15"):
		return false
	return key.ends_with("_warm") or key.ends_with("_cold")


func _render_n15_tier_line(beat_id: String, key: String, route_tone: String) -> String:
	var tier := "warm" if key.ends_with("_warm") else "cold"
	var ctx := StorySlotService.build_context({
		"beat_id": beat_id,
		"journal_max_lines": StoryBeatDirector.get_n15_journal_max_lines(beat_id),
	})
	var routed := StoryNodeCopy.get_route("_N15", route_tone, tier)
	if routed.strip_edges() == "":
		routed = StoryNodeCopy.get_route("_N15", route_tone)
	if "{" in routed:
		routed = StorySlotService.apply(routed, ctx)
	return _format_node_text(routed, StorySlotService.slot("companion_name", ctx), StorySlotService.slot("crop_label", ctx))


func _render_n20c_tier_line(beat_id: String, key: String, route_tone: String) -> String:
	var tier := "warm" if key.ends_with("_warm") else "cold"
	var suffix := "_N20c_b" if key.contains("_N20c_b_") else "_N20c"
	var routed := StoryNodeCopy.get_route(suffix, route_tone, tier)
	if routed.strip_edges() == "":
		routed = StoryNodeCopy.get_route(suffix, route_tone)
	if "{" in routed:
		routed = StorySlotService.apply(
			routed,
			StorySlotService.build_context({"beat_id": beat_id})
		)
	return routed


func _render_n20a_line(beat_id: String, route_tone: String) -> String:
	var variant := ""
	if route_tone == "normal":
		var persona: Dictionary = GameState.get_persona_vector()
		var warm := float(persona.get("warm", 0.5))
		var strict := float(persona.get("strict", 0.5))
		if warm >= strict + 0.12:
			variant = "normal_warm"
		elif strict >= warm + 0.12:
			variant = "normal_strict"
	var n20a := StoryNodeCopy.get_route("_N20a", route_tone, variant)
	if n20a.strip_edges() == "":
		n20a = StoryNodeCopy.get_route("_N20a", route_tone)
	if n20a.strip_edges() == "":
		return StorySlotService.render_player_name_line(route_tone)
	var applied := StorySlotService.apply(
		n20a,
		StorySlotService.build_context({"beat_id": beat_id})
	)
	return _format_node_text(applied, StorySlotService.slot("companion_name"), _crop_label())


func _render_n19_part(beat_id: String, key: String, route_tone: String) -> String:
	var suffix := "_N19_a"
	if key.ends_with("_N19_b"):
		suffix = "_N19_b"
	elif key.ends_with("_N19_c"):
		suffix = "_N19_c"
	var text := StoryNodeCopy.get_route(suffix, route_tone)
	if text.strip_edges() == "":
		return ""
	if "{" in text:
		text = StorySlotService.apply(text, StorySlotService.build_context({"beat_id": beat_id}))
	return _format_node_text(text, StorySlotService.slot("companion_name"), _crop_label())


func _render_n20b_part(beat_id: String, suffix: String, route_tone: String) -> String:
	var text := StoryNodeCopy.get_route(suffix, route_tone)
	if text.strip_edges() == "":
		return ""
	if "{" in text:
		text = StorySlotService.apply(text, StorySlotService.build_context({"beat_id": beat_id}))
	return _format_node_text(text, StorySlotService.slot("companion_name"), _crop_label())


func _format_node_text(text: String, companion: String, crop: String = "") -> String:
	if text == "":
		return ""
	if "%s" not in text:
		return text
	if text.count("%s") == 1 and "这片" in text and crop != "":
		return text % crop
	return text % companion


func _fragment_fallback(fid: String) -> String:
	var entry := StoryNodeCopy.get_fragment(fid)
	return str(entry.get("fallback", ""))


func _route_tone(beat_id: String) -> String:
	if beat_id.begins_with("TR_"):
		return "true"
	if beat_id.begins_with("HP_"):
		return "happy"
	if beat_id.begins_with("BL_"):
		return "bad"
	if beat_id.begins_with("BE_"):
		return "bad_early"
	if beat_id.begins_with("NM_"):
		return "normal"
	return "prologue"


func _crop_label() -> String:
	return StorySlotService.slot("crop_label")


func _fragment_body(fragment_id: String, fallback: String) -> String:
	var entry := StoryNodeCopy.get_fragment(fragment_id)
	var subtitle := str(entry.get("subtitle", ""))
	if subtitle == "":
		subtitle = fragment_id
	var personal := _personal_fragment_line(fragment_id, fallback)
	return "%s\n\n%s" % [subtitle, personal]


func _personal_fragment_line(fragment_id: String, fallback: String) -> String:
	return StorySlotService.pick_fragment_line(fragment_id, fallback)


func render_morning_opening(include_yesterday_echo: bool = false, beat_id: String = "") -> String:
	var week := GameState.get_week_index()
	var day := GameState.get_loop_day()
	var companion := GameState.companion_name
	var sky := "%s的%s" % [GameState.get_weather_label(), GameState.get_time_label()]

	if GameState.has_pending_absence() and not StoryDirector.is_stranger_mode():
		var facts := GameState.get_pending_absence_facts()
		var hint := str(facts.get("comeback_hint", "")).strip_edges()
		if hint != "":
			return hint

	if GameState.IS_TEN_DAY_EDITION:
		return _render_morning_ten_day(include_yesterday_echo, beat_id, sky, companion)

	if week == 2 and day == 1 and not GameState.has_revealed_memory():
		if beat_id in ["P_N05", "BE_N05"]:
			return StoryNodeCopy.get_morning("w2_d1_beat_n05")
		return StoryNodeCopy.get_morning("w2_d1_default")
	if week == 2 and day == 2 and not GameState.has_revealed_memory():
		if beat_id in ["P_N06", "BE_N06"]:
			return StoryNodeCopy.get_morning("w2_d2_beat_n06") % sky
		return StoryNodeCopy.get_morning("w2_d2_default")
	if week == 2 and not GameState.has_revealed_memory():
		var chat_days := int(RelationshipDirector.get_signals().get("chat_days", 0))
		match day:
			3:
				return StoryNodeCopy.get_morning("w2_d3") % [sky, companion]
			4:
				return StoryNodeCopy.get_morning("w2_d4") % [sky, companion]
			5, 6:
				if chat_days >= 3:
					return StoryNodeCopy.get_morning("w2_d5_d6_patience") % [sky, companion]
				if GameState.affection < 15:
					return StoryNodeCopy.get_morning("w2_d5_d6_quiet") % [sky, companion]
				return StoryNodeCopy.get_morning("w2_d5_d6") % [sky, companion]
	if week == 3 and not GameState.has_revealed_memory():
		match day:
			1:
				return StoryNodeCopy.get_morning("w3_d1") % [sky, companion]
			2:
				if beat_id.ends_with("_N02p"):
					return StoryNodeCopy.get_morning("w3_d2_beat_n02p") % [sky, companion]
			3:
				return StoryNodeCopy.get_morning("w3_d3") % [sky, companion]
			4:
				if beat_id.ends_with("_N13"):
					return StoryNodeCopy.get_morning("w3_d4_beat_n13") % [sky, companion]
			5, 6:
				return StoryNodeCopy.get_morning("w3_d5_d6") % [sky, companion]
			7:
				if beat_id.ends_with("_N15"):
					return StoryNodeCopy.get_morning("w3_d7_beat_n15") % [sky, companion]
				return StoryNodeCopy.get_morning("w3_d7_default") % companion
	if week == 4 and not GameState.has_revealed_memory():
		match day:
			1:
				if beat_id.ends_with("_N16"):
					return StoryNodeCopy.get_morning("w4_d1_beat_n16") % [sky, companion]
				return StoryNodeCopy.get_morning("w4_d1") % [sky, companion]
			2:
				if beat_id.ends_with("_N11p"):
					return StoryNodeCopy.get_morning("w4_d2_beat_n11p") % [sky, companion]
			3:
				return StoryNodeCopy.get_morning("w4_d3") % [sky, companion]
			4:
				return StoryNodeCopy.get_morning("w4_d4") % [sky, companion]
			5, 6:
				if day == 6 and beat_id.ends_with("_N18p"):
					return StoryNodeCopy.get_morning("w4_d6_beat_n18p") % [sky, companion]
				return StoryNodeCopy.get_morning("w4_d5_d6") % [sky, companion]
			7:
				if beat_id.ends_with("_N08p"):
					return StoryNodeCopy.get_morning("w4_d7_beat_n08p") % [sky, companion]
				return StoryNodeCopy.get_morning("w4_d7_default") % companion
	if week == 5 and day == 1 and not GameState.has_revealed_memory():
		return StoryNodeCopy.get_morning("w5_d1")
	if week == 5 and not GameState.has_revealed_memory():
		match day:
			2:
				if beat_id.ends_with("_N20a"):
					return StoryNodeCopy.get_morning("w5_d2_beat_n20a") % [sky, companion]
			3:
				return StoryNodeCopy.get_morning("w5_d3") % [sky, companion]
			4:
				if beat_id.ends_with("_N20b"):
					return StoryNodeCopy.get_morning("w5_d4_beat_n20b") % [sky, companion]
			5:
				if beat_id.ends_with("_N33"):
					return StoryNodeCopy.get_morning("w5_d5_beat_n33") % [sky, companion]
			6:
				if beat_id.ends_with("_N20c"):
					return StoryNodeCopy.get_morning("w5_d6_beat_n20c") % [sky, companion]
	if week == 5 and day == 7 and GameState.has_revealed_memory():
		return StoryNodeCopy.get_morning("w5_d7_revealed")
	if day == 7 and not GameState.has_revealed_memory() and week < 5:
		if beat_id in ["P_N04"]:
			return StoryNodeCopy.get_morning("weekend_d7_beat_n04") % sky
		return StoryNodeCopy.get_morning("weekend_d7_default")

	if include_yesterday_echo and GameState.last_day_summary.strip_edges() != "":
		if not StoryDirector.is_stranger_mode():
			var clause := GameState.build_yesterday_echo_hint()
			if clause == "":
				clause = StorySlotService.slot("yesterday_echo")
			return StoryNodeCopy.get_morning("yesterday_echo") % clause

	if week >= 3 and not GameState.has_revealed_memory():
		return StoryNodeCopy.get_morning("w3plus_stranger") % sky

	match GameState.get_stage():
		GameState.STAGE_BOND:
			return StoryNodeCopy.get_morning("stage_bond") % sky
		GameState.STAGE_FAMILIAR:
			return StoryNodeCopy.get_morning("stage_familiar") % sky
		_:
			if week == 1 and day == 1:
				return StoryNodeCopy.get_morning("w1_d1") % [sky, companion]
			var rhythm_line := StorySlotService.render_time_rhythm_hint(companion)
			if rhythm_line != "":
				return StoryNodeCopy.get_morning("rhythm_prefix") % [rhythm_line, sky]
			return StoryNodeCopy.get_morning("generic") % sky


func _render_morning_ten_day(
	include_yesterday_echo: bool,
	beat_id: String,
	sky: String,
	companion: String
) -> String:
	var gday := GameState.game_day
	match gday:
		1:
			return StoryNodeCopy.get_morning("t10_d1") % [sky, companion]
		2:
			return StoryNodeCopy.get_morning("t10_d2") % sky
		3:
			return StoryNodeCopy.get_morning("t10_d3") % [sky, companion]
		4:
			if bool(GameState.get_ending_flags().get("d4_telegraph_ack_at_wake", false)):
				return ""
			return StoryNodeCopy.get_morning("t10_d4_telegraph")
		5:
			return StoryNodeCopy.get_morning("t10_d5") % [sky, companion]
		6:
			if beat_id.ends_with("_N02p") or beat_id == "BE_N07":
				return StoryNodeCopy.get_morning("t10_d6_leak") % [sky, companion]
			return StoryNodeCopy.get_morning("t10_d6") % [sky, companion]
		7:
			if beat_id.ends_with("_N16"):
				return StoryNodeCopy.get_morning("t10_d7_name") % [sky, companion]
			return StoryNodeCopy.get_morning("t10_d7") % [sky, companion]
		8:
			if beat_id.ends_with("_N15"):
				return StoryNodeCopy.get_morning("t10_d8_notebook") % [sky, companion]
			return StoryNodeCopy.get_morning("t10_d8") % [sky, companion]
		9:
			return StoryNodeCopy.get_morning("t10_d9") % [sky, companion]
		10:
			return StoryNodeCopy.get_morning("t10_d10")
	if include_yesterday_echo and GameState.last_day_summary.strip_edges() != "":
		if not StoryDirector.is_stranger_mode():
			var clause := GameState.build_yesterday_echo_hint()
			if clause == "":
				clause = StorySlotService.slot("yesterday_echo")
			return StoryNodeCopy.get_morning("yesterday_echo") % clause
	return StoryNodeCopy.get_morning("generic") % sky


func render_evening_opening(beat_id: String) -> String:
	var companion := GameState.companion_name
	var sky := "%s的%s" % [GameState.get_weather_label(), GameState.get_time_label()]
	if beat_id.ends_with("_N14n"):
		return StoryNodeCopy.get_morning("night_hollow_weekend") % [sky, companion]
	if beat_id.ends_with("_N17"):
		return StoryNodeCopy.get_morning("night_hollow_fog") % [sky, companion]
	return StoryNodeCopy.get_morning("night_hollow_default") % sky


func render_companion_night_line(beat_id: String, choice_id: String) -> String:
	var suffix := _companion_night_response_suffix(beat_id, choice_id)
	if suffix == "":
		return ""
	var route_tone := _route_tone(beat_id)
	var key := suffix
	if beat_id.ends_with("_N17") and choice_id == "companion_sit":
		var nights := int(GameState.get_ending_flags().get("companionship_nights", 0))
		if nights >= 1 and route_tone in ["true", "happy"] and StoryNodeCopy.get_route(key, route_tone, "true_nights") != "":
			return StoryNodeCopy.get_route(key, route_tone, "true_nights")
	if beat_id.ends_with("_N16") and GameState.IS_TEN_DAY_EDITION:
		var profile := StoryBeatDirector.get_n16_profile(beat_id)
		if profile == "cold":
			var cold := StoryNodeCopy.get_route(key, route_tone, "cold")
			if cold.strip_edges() != "":
				return cold
		elif profile == "mid":
			var mid := StoryNodeCopy.get_route(key, route_tone, "mid")
			if mid.strip_edges() != "":
				return mid
		elif profile == "warm" and route_tone in ["true", "happy"]:
			var warm := StoryNodeCopy.get_route(key, route_tone, route_tone)
			if warm.strip_edges() != "":
				return warm
	return StoryNodeCopy.get_route(key, route_tone)


func render_companion_night_after(beat_id: String, choice_id: String) -> String:
	var line := render_companion_night_line(beat_id, choice_id).strip_edges()
	if line == "" or line == "……":
		return ""
	var companion := GameState.companion_name
	if choice_id == "companion_leave":
		return "%s 在树洞里轻声说：「%s」" % [companion, line]
	return "%s 轻声说：「%s」" % [companion, line]


func _companion_night_response_suffix(beat_id: String, choice_id: String) -> String:
	if beat_id.ends_with("_N14n"):
		return "_N14n_sit" if choice_id == "companion_sit" else "_N14n_leave"
	## 十日版 D7：夜选挂在 N16 上，复用树洞陪伴台词
	if beat_id.ends_with("_N16") and GameState.IS_TEN_DAY_EDITION:
		return "_N14n_sit" if choice_id == "companion_sit" else "_N14n_leave"
	if beat_id.ends_with("_N17"):
		return "_N17_sit" if choice_id == "companion_sit" else "_N17_leave"
	return ""


func render_companion_night_farewell(beat_id: String) -> String:
	var line := render_companion_night_line(beat_id, "companion_sit").strip_edges()
	if line == "":
		return "快休息吧，明天见。"
	if line.ends_with("。") or line.ends_with("！") or line.ends_with("？"):
		return "%s快休息吧，明天见。" % line
	return "%s。快休息吧，明天见。" % line


func render_proactive_nudge() -> String:
	if not StoryDirector.should_proactive_nudge():
		return ""
	var week := GameState.get_week_index()
	var day := GameState.get_loop_day()
	var companion := GameState.companion_name

	match week:
		1:
			if day == 3:
				return StoryNodeCopy.get_nudge("w1_d3") % companion
		2:
			if day == 4 and not GameState.has_revealed_memory():
				return StoryNodeCopy.get_nudge("w2_d4") % companion
		3:
			if day == 1 and not GameState.has_revealed_memory():
				var prefs: Dictionary = GameState.long_term_memory.get("prefs", {})
				if prefs.has("fav_crop"):
					return StoryNodeCopy.get_nudge("w3_d1_fav_crop") % [
						companion, StorySlotService.slot("crop_label"),
					]
				return StoryNodeCopy.get_nudge("w3_d1_default") % companion
		4:
			if day == 1 and not GameState.has_revealed_memory():
				return StoryNodeCopy.get_nudge("w4_d1_default") % companion
		5:
			if day == 1 and not GameState.has_revealed_memory():
				return StoryNodeCopy.get_nudge("w5_d1_default") % companion
		_:
			pass
	return ""


func render_beat_followup(beat_id: String) -> String:
	if beat_id in PROLOGUE_SELF_CONTAINED:
		return ""
	var base := _base_def(beat_id)
	if base.is_empty():
		return ""
	var emotion := str(base.get("emotion", ""))
	var companion := GameState.companion_name
	var player := StorySlotService.slot("player_name")
	var signals := RelationshipDirector.get_signals()
	var chat_days := int(signals.get("chat_days", 0))
	var nights := int(GameState.get_ending_flags().get("companionship_nights", 0))
	if GameState.get_week_index() == 2 and not GameState.has_revealed_memory():
		match emotion:
			"失去", "确认":
				if chat_days >= 3:
					return StoryNodeCopy.get_followup("w2_patience") % companion
				if GameState.affection < 15:
					return StoryNodeCopy.get_followup("w2_cold") % companion
				return StoryNodeCopy.get_followup("w2_lost_confirm") % companion
			"选择":
				return StoryNodeCopy.get_followup("w2_choice")
	if GameState.get_week_index() == 3 and not GameState.has_revealed_memory():
		if beat_id.ends_with("_N09"):
			if chat_days >= 3:
				return StoryNodeCopy.get_followup("w3_n09_warm") % companion
			return StoryNodeCopy.get_followup("w3_n09") % companion
		if beat_id.ends_with("_N02p"):
			return StoryNodeCopy.get_followup("w3_n02p") % companion
		if beat_id.ends_with("_N13"):
			return StoryNodeCopy.get_followup("w3_n13")
		if beat_id.ends_with("_N14"):
			return StoryNodeCopy.get_followup("w3_n14") % companion
		if beat_id.ends_with("_N15"):
			if GameState.get_memory_recovery() >= 0.35:
				return StoryNodeCopy.get_followup("w3_n15_recall") % companion
			return StoryNodeCopy.get_followup("w3_n15") % companion
	if GameState.get_week_index() == 4 and not GameState.has_revealed_memory():
		if beat_id.ends_with("_N16"):
			if chat_days >= 4 or GameState.get_memory_recovery() >= 0.45:
				return StorySlotService.apply(
					StoryNodeCopy.get_followup("w4_n16_warm"),
					StorySlotService.build_context({"beat_id": beat_id})
				)
			return StorySlotService.apply(
				StoryNodeCopy.get_followup("w4_n16"),
				StorySlotService.build_context({"beat_id": beat_id})
			)
		if beat_id.ends_with("_N11p"):
			return StoryNodeCopy.get_followup("w4_n11p")
		if beat_id.ends_with("_N17"):
			return StoryNodeCopy.get_followup("w4_n17") % companion
		if beat_id.ends_with("_N18p"):
			return StoryNodeCopy.get_followup("w4_n18p") % companion
		if beat_id.ends_with("_N08p"):
			if GameState.get_memory_recovery() >= 0.55:
				return StoryNodeCopy.get_followup("w4_weekend_recall") % companion
			return StoryNodeCopy.get_followup("w4_n08p") % companion
	if GameState.get_week_index() == 5 and not GameState.has_revealed_memory():
		if beat_id.ends_with("_N19"):
			if chat_days >= 4 or GameState.get_memory_recovery() >= 0.65:
				return StoryNodeCopy.get_followup("w5_n19_warm") % companion
			return StoryNodeCopy.get_followup("w5_n19") % companion
		if beat_id.ends_with("_N20a"):
			if chat_days >= 5 or GameState.get_memory_recovery() >= 0.70:
				return StoryNodeCopy.get_followup("w5_n20a_warm") % companion
			return StoryNodeCopy.get_followup("w5_n20a") % companion
		if beat_id.ends_with("_N20b"):
			return StoryNodeCopy.get_followup("w5_n20b") % companion
		if beat_id.ends_with("_N20c"):
			return StoryNodeCopy.get_followup("w5_n20c") % companion
		if beat_id.ends_with("_N33"):
			return StoryNodeCopy.get_followup("w5_quiet_eve") % companion
	if beat_id.ends_with("_N08p"):
		if GameState.get_memory_recovery() >= 0.55:
			return StoryNodeCopy.get_followup("w4_weekend_recall") % companion
		return StoryNodeCopy.get_followup("w4_weekend_default") % companion
	if beat_id.ends_with("_N33"):
		return StoryNodeCopy.get_followup("w5_quiet_eve") % companion
	if beat_id.ends_with("_N16"):
		if nights >= 1:
			return StoryNodeCopy.get_followup("name_after_night") % player
		if chat_days >= 6:
			return StoryNodeCopy.get_followup("name_after_chat") % player
	match emotion:
		"失去", "确认":
			return StoryNodeCopy.get_followup("lost_confirm") % player
		"名字":
			return StoryNodeCopy.get_followup("name") % player
		"起雾", "独自夜坐", "雾夜":
			if nights >= 1:
				return StoryNodeCopy.get_followup("fog_night_warm")
			return StoryNodeCopy.get_followup("fog_night")
		"信", "前夕":
			return StoryNodeCopy.get_followup("letter_eve")
		"宁静":
			return StoryNodeCopy.get_followup("w5_quiet_eve") % companion
		_:
			if GameState.get_memory_recovery() >= 0.5:
				return StoryNodeCopy.get_followup("recovery_warm") % companion
			if GameState.get_stage() == GameState.STAGE_BOND:
				return StoryNodeCopy.get_followup("bond_default") % companion
			return StoryNodeCopy.get_followup("generic")


func render_week_relationship_feel() -> String:
	if GameState.has_revealed_memory():
		return StoryNodeCopy.get_week_wrap_hint("feel_revealed")
	var week := GameState.get_week_index()
	var recovery := GameState.get_memory_recovery()
	var factors := RelationshipDirector.get_ending_factors()
	var chat_days := int(factors.get("chat_days", 0))
	var nights := int(factors.get("companionship_nights", 0))
	var affection := int(factors.get("affection", 0))
	if week <= 1 and not GameState.has_revealed_memory():
		if affection < 20:
			return StoryNodeCopy.get_week_wrap_hint("feel_w1_quiet")
		if chat_days >= 4 and affection >= 35:
			return StoryNodeCopy.get_week_wrap_hint("feel_w1_bond")
		return StoryNodeCopy.get_week_wrap_hint("feel_w1_default")
	if week >= 3 and recovery >= 0.55:
		return StoryNodeCopy.get_week_wrap_hint("feel_recovery_high")
	if chat_days >= 4 and affection >= 35:
		return StoryNodeCopy.get_week_wrap_hint("feel_bond_warm")
	if week >= 2 and nights >= 1:
		return StoryNodeCopy.get_week_wrap_hint("feel_companion_warm")
	if affection < 20:
		return StoryNodeCopy.get_week_wrap_hint("feel_quiet")
	return StoryNodeCopy.get_week_wrap_hint("feel_default")


func render_deferred_journal_hint(beat_id: String) -> String:
	if beat_id.ends_with("_N07"):
		return StoryNodeCopy.get_deferred_hint("n07")
	if beat_id.ends_with("_N16"):
		return StoryNodeCopy.get_deferred_hint("n16") % GameState.companion_name
	if beat_id.ends_with("_N33"):
		return StoryNodeCopy.get_deferred_hint("n33")
	return ""


func render_route_shift_message(old_route: String, new_route: String) -> String:
	if old_route == new_route:
		return ""
	match new_route:
		StoryRouteData.ROUTE_HAPPY:
			return StoryNodeCopy.get_route_shift("to_happy")
		StoryRouteData.ROUTE_TRUE:
			return StoryNodeCopy.get_route_shift("to_true")
		StoryRouteData.ROUTE_BAD:
			return StoryNodeCopy.get_route_shift("to_bad")
		_:
			if old_route in [StoryRouteData.ROUTE_HAPPY, StoryRouteData.ROUTE_TRUE]:
				return StoryNodeCopy.get_route_shift("to_normal")
			return ""
