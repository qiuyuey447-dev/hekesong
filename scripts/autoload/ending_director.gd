extends Node
## 四结局判定与 epilogue 文案（§十一）。

const ENDING_NORMAL := "ending_normal"
const ENDING_HAPPY := "ending_happy"
const ENDING_TRUE := "ending_true"
const ENDING_BAD := "ending_bad"
const ENDING_BAD_EARLY := "ending_bad_early"

const ENDING_LABELS := {
	ENDING_NORMAL: {"title": "安顿之日", "tagline": "今天，壶还热着。"},
	ENDING_HAPPY: {"title": "廊下的碗", "tagline": "这里也是她的家。"},
	ENDING_TRUE: {"title": "最后一程", "tagline": "从空白里，把对方找回来。"},
	ENDING_BAD: {"title": "雾中", "tagline": "最要紧的，又弄丢了。"},
	ENDING_BAD_EARLY: {"title": "田埂尽头", "tagline": "她没有回头。"},
}


func resolve_ending(flashback_skipped: bool = false) -> String:
	GameState.set_ending_flag("f10_skipped", flashback_skipped)
	var flags := GameState.get_ending_flags()
	if bool(flags.get("w2_chose_expel", false)):
		return ENDING_BAD_EARLY
	return _resolve_d35_ending(flashback_skipped)


func _resolve_d35_ending(flashback_skipped: bool) -> String:
	var factors := RelationshipDirector.get_ending_factors()
	var recovery := float(factors.get("memory_recovery", 0.0))
	var fragments := int(factors.get("fragments", 0))
	var nights := int(factors.get("companionship_nights", 0))
	var interaction := float(factors.get("interaction_score", 0.0))
	var promise: Dictionary = GameState.long_term_memory.get("promise", {})

	if GameState.IS_TEN_DAY_EDITION:
		if recovery < 0.22 or interaction < 0.18 or (nights == 0 and GameState.affection < 12):
			return ENDING_BAD
		if _meets_true(flashback_skipped, recovery, fragments, nights, promise, factors):
			return ENDING_TRUE
		if _meets_happy(flashback_skipped, recovery, fragments, nights, factors):
			return ENDING_HAPPY
		return ENDING_NORMAL

	if recovery < 0.40 or interaction < 0.32 or (nights == 0 and GameState.affection < 25):
		return ENDING_BAD
	if _meets_true(flashback_skipped, recovery, fragments, nights, promise, factors):
		return ENDING_TRUE
	if _meets_happy(flashback_skipped, recovery, fragments, nights, factors):
		return ENDING_HAPPY
	return ENDING_NORMAL


func get_ending_resolution_debug() -> Dictionary:
	var skipped := bool(GameState.get_ending_flags().get("f10_skipped", false))
	return {
		"ending_id": resolve_ending(skipped),
		"factors": RelationshipDirector.get_ending_factors(),
	}


func _meets_true(
	flashback_skipped: bool,
	recovery: float,
	fragments: int,
	nights: int,
	promise: Dictionary,
	factors: Dictionary
) -> bool:
	if flashback_skipped:
		return false
	if GameState.IS_TEN_DAY_EDITION:
		if recovery < 0.48 or fragments < 3:
			return false
		if nights < 1 or GameState.bond < 20:
			return false
		if promise.is_empty() or not bool(promise.get("fulfilled", false)):
			return false
		if GameState.affection < 28:
			return false
		if float(factors.get("interaction_score", 0.0)) < 0.40:
			return false
		if int(factors.get("chat_days", 0)) < 3:
			return false
		return true
	if recovery < 0.85 or fragments < 10:
		return false
	if nights < 2 or GameState.bond < 40:
		return false
	if promise.is_empty() or not bool(promise.get("fulfilled", false)):
		return false
	if GameState.affection < 50:
		return false
	if float(factors.get("interaction_score", 0.0)) < 0.72:
		return false
	if int(factors.get("chat_days", 0)) < 8:
		return false
	if int(factors.get("gifts_given", 0)) < 2:
		return false
	return true


func _meets_happy(
	flashback_skipped: bool,
	recovery: float,
	fragments: int,
	nights: int,
	factors: Dictionary
) -> bool:
	if flashback_skipped:
		return false
	if GameState.IS_TEN_DAY_EDITION:
		if recovery < 0.35 or fragments < 2:
			return false
		if nights < 1 and GameState.affection < 25:
			return false
		if float(factors.get("interaction_score", 0.0)) < 0.30:
			return false
		if int(factors.get("chat_days", 0)) < 2:
			return false
		return true
	if recovery < 0.75 or fragments < 7:
		return false
	if nights < 1 or GameState.affection < 45:
		return false
	if float(factors.get("interaction_score", 0.0)) < 0.55:
		return false
	if int(factors.get("chat_days", 0)) < 4:
		return false
	return true


func is_bad_ending(ending_id: String) -> bool:
	return ending_id in [ENDING_BAD, ENDING_BAD_EARLY]


const ENDING_ARCS := {
	ENDING_NORMAL: {
		"name": "安顿",
		"emotion": "记忆回来，但不完美",
		"fragments": "F01–F05 高亮",
		"f10": "short",
	},
	ENDING_HAPPY: {
		"name": "共处",
		"emotion": "这里也是她的家",
		"fragments": "F01–F09 高亮",
		"f10": "medium",
	},
	ENDING_TRUE: {
		"name": "归来",
		"emotion": "从空白里找回来",
		"fragments": "F01–F10 全集",
		"f10": "full",
	},
	ENDING_BAD: {
		"name": "雾中",
		"emotion": "未能接住",
		"fragments": "无 F10",
		"f10": "none",
	},
	ENDING_BAD_EARLY: {
		"name": "放手",
		"emotion": "早期切断",
		"fragments": "F01–F03 若已解锁则灰显",
		"f10": "none",
	},
}


func get_full_ending_steps(ending_id: String) -> Array[Dictionary]:
	var steps := get_fixed_climax_steps(ending_id)
	var epilogue := get_epilogue_steps(ending_id)
	# epilogue 已含 title_card + credits；climax 插在最前
	var narrative_end := epilogue.size() - 2
	if narrative_end < 0:
		narrative_end = 0
	var merged: Array[Dictionary] = []
	merged.append_array(steps)
	for i in range(narrative_end):
		merged.append(epilogue[i])
	for i in range(narrative_end, epilogue.size()):
		merged.append(epilogue[i])
	return merged


func get_fixed_climax_steps(ending_id: String) -> Array[Dictionary]:
	match ending_id:
		ENDING_NORMAL:
			return [
				_climax_step_with_fragments("climax_normal_1_title", 5, "act1_footer_normal"),
				_climax_step("climax_normal_2_title", "climax_normal_2_body"),
			]
		ENDING_HAPPY:
			return [
				_climax_step_with_fragments("climax_happy_1_title", 9, "climax_happy_1_suffix"),
				{
					"title": StoryNodeCopy.get_ending("climax_happy_2_title"),
					"body": _f10_montage("medium"),
					"kind": "climax",
				},
			]
		ENDING_TRUE:
			return [
				_climax_step("climax_true_1_title", "climax_true_1_body"),
				_climax_step("climax_true_2_title", "climax_true_2_body"),
				{
					"title": StoryNodeCopy.get_ending("climax_true_3_title"),
					"body": _f10_montage("full"),
					"kind": "climax",
				},
			]
		ENDING_BAD:
			return [
				_climax_step("climax_bad_1_title", "climax_bad_1_body"),
				_climax_step("climax_bad_2_title", "climax_bad_2_body"),
			]
		ENDING_BAD_EARLY:
			return [
				_climax_step("climax_bad_early_1_title", "climax_bad_early_1_body"),
				_climax_step("climax_bad_early_2_title", "climax_bad_early_2_body"),
			]
		_:
			return []


func _climax_step(title_key: String, body_key: String) -> Dictionary:
	return {
		"title": StoryNodeCopy.get_ending(title_key),
		"body": _ending_text(body_key),
		"kind": "climax",
	}


func _climax_step_with_fragments(title_key: String, fragment_limit: int, footer_key: String) -> Dictionary:
	var lines := _unlocked_fragment_lines(fragment_limit)
	var footer := _ending_text(footer_key) if footer_key.begins_with("climax_") else _awakening_text(footer_key)
	var body := footer
	if not lines.is_empty():
		body = "%s\n\n%s" % ["\n".join(lines), footer]
	return {
		"title": StoryNodeCopy.get_ending(title_key),
		"body": body,
		"kind": "climax",
	}


func _ending_text(key: String) -> String:
	var raw := StoryNodeCopy.get_ending(key)
	if raw.strip_edges() == "":
		return ""
	return StorySlotService.apply(raw, StorySlotService.build_context())


func get_awakening_steps(ending_id: String) -> Array[Dictionary]:
	return get_d35_awakening_steps(ending_id)


func get_d35_awakening_steps(ending_id: String) -> Array[Dictionary]:
	var journal_lines := _pick_journal_lines(3)
	var act2_body := _awakening_act2_body(journal_lines)
	var steps: Array[Dictionary] = [
		{
			"title": StoryNodeCopy.get_awakening("act_title_1"),
			"body": _fragment_wall_text(ending_id),
		},
		{
			"title": StoryNodeCopy.get_awakening("act_title_2"),
			"body": act2_body,
		},
	]
	match ending_id:
		ENDING_BAD:
			steps.append({
				"title": StoryNodeCopy.get_awakening("act_title_3_bad"),
				"body": _awakening_text("act3_bad"),
			})
		ENDING_TRUE:
			steps.append({
				"title": StoryNodeCopy.get_awakening("act_title_3"),
				"body": _awakening_text("act3_true"),
			})
			steps.append({
				"title": StoryNodeCopy.get_awakening("act_title_4_full"),
				"body": _f10_montage("full"),
			})
		ENDING_HAPPY:
			steps.append({
				"title": StoryNodeCopy.get_awakening("act_title_3"),
				"body": _awakening_text("act3_happy"),
			})
			steps.append({
				"title": StoryNodeCopy.get_awakening("act_title_4_medium"),
				"body": _f10_montage("medium"),
			})
		_:
			steps.append({
				"title": StoryNodeCopy.get_awakening("act_title_3"),
				"body": _awakening_text("act3_normal"),
			})
			if ending_id == ENDING_NORMAL:
				steps.append({
					"title": StoryNodeCopy.get_awakening("act_title_4_short"),
					"body": _f10_montage("short"),
				})
	return steps


func _awakening_text(key: String) -> String:
	var raw := StoryNodeCopy.get_awakening(key)
	if raw.strip_edges() == "":
		return ""
	return StorySlotService.apply(raw, StorySlotService.build_context())


func _awakening_act2_body(journal_lines: Array[String]) -> String:
	var intro := _awakening_text("act2_intro")
	var body_lines: Array[String] = []
	if intro.strip_edges() != "":
		body_lines.append(intro)
	if journal_lines.is_empty():
		body_lines.append(StoryNodeCopy.get_awakening("act2_journal_fallback"))
	else:
		body_lines.append("\n".join(journal_lines))
	var question_lines := PlayerNotebookService.reveal_for_awakening()
	if not question_lines.is_empty():
		body_lines.append("\n".join(question_lines))
	return "\n\n".join(body_lines)


func _fragment_wall_text(ending_id: String) -> String:
	var lines := _unlocked_fragment_lines(_max_fragments_for_ending(ending_id))
	var footer_key := "act1_footer_bad"
	match ending_id:
		ENDING_TRUE:
			footer_key = "act1_footer_true"
		ENDING_HAPPY:
			footer_key = "act1_footer_happy"
		ENDING_BAD:
			footer_key = "act1_footer_bad"
		_:
			footer_key = "act1_footer_normal"
	var footer := _awakening_text(footer_key)
	if lines.is_empty():
		var empty_hint := StoryNodeCopy.get_awakening("act1_empty")
		if empty_hint.strip_edges() != "":
			return "%s\n\n%s" % [empty_hint, footer]
		return footer
	return "%s\n\n%s" % ["\n".join(lines), footer]


func _max_fragments_for_ending(ending_id: String) -> int:
	match ending_id:
		ENDING_TRUE:
			return 10
		ENDING_HAPPY:
			return 9
		ENDING_BAD:
			return 10
		_:
			return 5


func _unlocked_fragment_lines(limit: int) -> Array[String]:
	var lines: Array[String] = []
	for fid in ["F01", "F02", "F03", "F04", "F05", "F06", "F07", "F08", "F09", "F10"]:
		if lines.size() >= limit:
			break
		if not GameState.has_fragment(fid):
			continue
		var meta: Dictionary = StoryBeatDirector.get_fragment_meta(fid)
		var title := str(meta.get("title", fid)).strip_edges()
		var subtitle := str(meta.get("subtitle", "")).strip_edges()
		if subtitle != "":
			lines.append("· %s — %s" % [title, subtitle])
		else:
			lines.append("· %s" % title)
	return lines


func _f10_montage(length: String) -> String:
	var key := "f10_short"
	match length:
		"full":
			key = "f10_full"
		"medium":
			key = "f10_medium"
	var montage := StoryNodeCopy.get_awakening(key)
	var personal := _pick_journal_lines(2)
	if not personal.is_empty():
		return "%s\n\n——\n%s" % [montage, "\n".join(personal)]
	return montage


func get_epilogue_steps(ending_id: String) -> Array[Dictionary]:
	var player := GameState.player_name
	var companion := GameState.companion_name
	var steps: Array[Dictionary] = []

	match ending_id:
		ENDING_NORMAL:
			steps = [
				{
					"title": "尾声 · 一",
					"body": (
						"十日过去了。\n\n"
						+ "%s 把还温着的壶搁回廊下，又回头看你一眼。"
						+ "她记不清所有的日子。可这把壶，她认得；你，她今天也认得。"
					) % companion,
				},
				{
					"title": "尾声 · 二",
					"body": (
						"「明天，我说不定又会糊涂。」她低声说，"
						+ "「可今天——我记得 %s。谢谢你，没有嫌我麻烦。」" % player
					),
				},
				{
					"title": "尾声 · 三",
					"body": (
						"夜里，树洞口那盏灯依旧亮着。\n\n"
						+ "你把两个本子并排搁在枕边——她的，和你的。她不知道你那一本。"
						+ "这样，无论谁先醒来，至少还有一行字，能把路指回来。"
					),
				},
			]
		ENDING_HAPPY:
			steps = [
				{
					"title": "尾声 · 一",
					"body": (
						"今天，%s 能稳稳地叫出你的名字。\n\n"
						+ "廊下那只碗还在。她指着碗沿上的一圈水渍笑：「是你把我留下的。这里……也成了我每天要重新认一次的家。」"
					) % companion,
				},
				{
					"title": "尾声 · 二",
					"body": (
						"你们一起收下最后一茬萝卜。田边那粒她自己种的，还没冒芽。"
						+ "她蹲在那儿看了很久，再不像初来那天那样，缩着肩、攥着衣角。"
					),
				},
				{
					"title": "尾声 · 三",
					"body": (
						"「就算哪天我又忘了，」%s 望着你说，"
						+ "「你也知道该怎么把我找回来——碗在廊下，我就在。」"
					) % companion,
				},
				{
					"title": "尾声 · 四",
					"body": (
						"你的田里，从此多了一个要你每天重新认识一次的人。不是过客。\n\n"
						+ "明天她若又忘了，你会重新告诉她；哪天你若也空成一片，她会重新告诉你。碗还在。种还在。这样，就够了。"
					),
				},
			]
		ENDING_TRUE:
			var journal_lines := _pick_journal_lines(3)
			steps = [
				{
					"title": StoryNodeCopy.get_ending("epilogue_true_1_title"),
					"body": _ending_text("epilogue_true_1_body"),
				},
				{
					"title": "你替她记下的",
					"body": "……\n\n%s" % "\n\n".join(journal_lines),
				},
				{
					"title": "%s想对你说" % companion,
					"body": (
						"「我走了很久，来了又走。这么多轮，我才敢信——\n\n"
						+ "被爱不是被记住，是两个都会忘的人，还愿意一次次，从空白里重新把对方认回来。」\n\n"
						+ "「%s，这一轮，我们都把对方认回来了。哪天又空成一片——别怕。牙印还在壶上。墨还在掌心。我们总能，再找回来。」" % player
					),
				},
				{
					"title": "尾声",
					"body": (
						"临睡前，你把两个本子并排搁好——她那句「不能弄丢这里」，和你写满了她的那一本。"
						+ "水壶柄上的浅痕还在。无论下一次醒来是否还有，路是留好了的。\n\n"
						+ "你知道你们都好不了。这或许真是最后一轮。可这一程，你们好好地，把对方认了个够。"
					),
				},
			]
		ENDING_BAD_EARLY:
			steps = [
				{
					"title": "尾声 · 一",
					"body": (
						"你送她走了。\n\n"
						+ "%s 把活干完，手套叠好，柜角那只碗推了回去。"
						+ "水壶搁在廊下，还冒着热气。她向你点了点头：「谢谢你收留过我。」"
					) % companion,
				},
				{
					"title": "尾声 · 二",
					"body": (
						"她沿着田埂往外走。泥还是来时那层泥。这一回，她没有回头。"
						+ "往后的日子，你独自浇田。田还在，只是安静。"
					),
				},
				{
					"title": "尾声 · 三",
					"body": (
						"有时风起，你仿佛听见身后有脚步声。回头，却空无一人。\n\n"
						+ "那只碗还在柜角。往后就算你也空成一片，也不会再有人，回来把你认出来了。"
					),
				},
			]
		ENDING_BAD:
			steps = [
				{
					"title": "尾声 · 一",
					"body": (
						"第十天，%s 站在田边，眼神空了一截。"
						% companion
						+ "那只手套还在行李边。她张了张嘴，最后只挤出一句：「对不起……我又把最要紧的事，弄丢了。」"
					),
				},
				{
					"title": "尾声 · 二",
					"body": _ending_text("epilogue_bad_2_body"),
				},
				{
					"title": "尾声 · 三",
					"body": (
						"树洞口那盏灯忽明忽暗。田埂外那条空土垄已经干了。"
						+ "你守着这片田，可那个想在这里安顿的人，终究没能留住。\n\n"
						+ "树洞口那盏灯，再也没有人为你留着。"
					),
				},
			]
		_:
			steps = [{"title": "尾声", "body": "故事结束了。"}]

	var meta: Dictionary = ENDING_LABELS.get(ending_id, ENDING_LABELS[ENDING_NORMAL])
	steps.append({
		"title": str(meta.get("title", "终章")),
		"body": "「%s」" % str(meta.get("tagline", "")),
		"kind": "title_card",
	})
	steps.append({
		"title": "",
		"body": "\n".join(get_credits_animation_lines()),
		"kind": "credits",
	})
	return steps


func get_credits_animation_lines() -> Array[String]:
	return [
		GameState.GAME_DISPLAY_NAME,
		"感谢体验",
		"感谢陪伴小狸的你",
	]


func _pick_journal_lines(max_lines: int) -> Array[String]:
	var lines: Array[String] = []
	var seen: Dictionary = {}
	for entry in GameState.day_journal:
		if not entry is Dictionary:
			continue
		var highlights: Variant = entry.get("highlights", [])
		if highlights is Array and highlights.size() > 0:
			for highlight in highlights:
				var line := str(highlight).strip_edges()
				if line == "" or _is_duplicate_journal_line(line, seen):
					continue
				lines.append("· %s" % line)
			continue
		var summary := str(entry.get("summary", "")).strip_edges()
		if summary != "" and not _is_duplicate_journal_line(summary, seen):
			lines.append("· %s" % summary)
	for summary_entry in GameState.get_week_summaries():
		for highlight in summary_entry.get("highlights", []):
			var line := str(highlight).strip_edges()
			if line == "" or _is_duplicate_journal_line(line, seen):
				continue
			lines.append("· %s" % line)
		for highlight in summary_entry.get("merged_highlights", []):
			var line := str(highlight).strip_edges()
			if line == "" or _is_duplicate_journal_line(line, seen):
				continue
			lines.append("· %s" % line)
	if lines.is_empty():
		return [
			"· 她登门那天，你说可以留下帮工。",
			"· 你们一起把第一块萝卜田浇透。",
			"· 你发现本子的日期对不上，却没有赶她走。",
		]
	if lines.size() > max_lines:
		return lines.slice(lines.size() - max_lines, lines.size())
	return lines


func _journal_line_key(line: String) -> String:
	var cleaned := line.strip_edges()
	if cleaned.begins_with("聊天 ·"):
		cleaned = cleaned.substr(4).strip_edges()
	if cleaned.begins_with("·"):
		cleaned = cleaned.substr(1).strip_edges()
	return cleaned


func _is_duplicate_journal_line(line: String, seen: Dictionary) -> bool:
	var key := _journal_line_key(line)
	if key == "":
		return true
	if seen.has(key):
		return true
	for existing in seen.keys():
		if key in str(existing) or str(existing) in key:
			return true
	seen[key] = true
	return false


func finalize_ending(ending_id: String) -> void:
	GameState.mark_story_ended(ending_id)
