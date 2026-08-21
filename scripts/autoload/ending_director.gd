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
	var locked := str(flags.get("locked_ending_id", "")).strip_edges()
	if locked != "":
		return locked
	return _resolve_d35_ending(flashback_skipped)


func lock_ending_id(ending_id: String) -> String:
	var locked := ending_id.strip_edges()
	if locked == "":
		locked = _resolve_d35_ending(bool(GameState.get_ending_flags().get("f10_skipped", false)))
	GameState.set_ending_flag("locked_ending_id", locked)
	return locked


func count_ten_day_gate_fragments() -> int:
	var n := 0
	for fid in ["F01", "F02", "F03", "F04", "F05"]:
		if GameState.has_fragment(fid):
			n += 1
	return n


func _resolve_d35_ending(flashback_skipped: bool) -> String:
	var factors := RelationshipDirector.get_ending_factors()
	var recovery := float(factors.get("memory_recovery", 0.0))
	var fragments := count_ten_day_gate_fragments() if GameState.IS_TEN_DAY_EDITION else int(factors.get("fragments", 0))
	var nights := int(factors.get("companionship_nights", 0))
	var interaction := float(factors.get("interaction_score", 0.0))
	var promise: Dictionary = GameState.long_term_memory.get("promise", {})

	if GameState.IS_TEN_DAY_EDITION:
		## D7 才有夜坐。此前 nights=0 不能当 Bad 证据，否则留下线 D6 会锁成空土垄。
		var sit_night_passed := GameState.game_day >= 8
		if recovery < 0.22 or interaction < 0.18:
			return ENDING_BAD
		if sit_night_passed and nights == 0 and GameState.affection < 12:
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
		if nights < 1:
			return false
		if promise.is_empty() or not bool(promise.get("fulfilled", false)):
			return false
		if float(factors.get("interaction_score", 0.0)) < 0.40:
			return false
		if int(factors.get("chat_days", 0)) < 3:
			return false
		if int(factors.get("gifts_given", 0)) < 2:
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
	## 结局面板只播尾声。高潮（碎片墙 / journal / 幕三 / F10）在觉醒面板。
	return get_epilogue_steps(ending_id)


func get_fixed_climax_steps(ending_id: String) -> Array[Dictionary]:
	## 旧 35 日「结局卡内高潮」。十日版高潮改走 get_awakening_steps，此处不再并进面板。
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
			"needs_notebook_reveal": true,
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
	return "\n\n".join(body_lines)


func append_act2_notebook_reveal(body: String) -> String:
	var body_lines: Array[String] = []
	var trimmed := body.strip_edges()
	if trimmed != "":
		body_lines.append(trimmed)
	var question_lines := PlayerNotebookService.reveal_for_awakening()
	if not question_lines.is_empty():
		body_lines.append("\n".join(question_lines))
	if PlayerNotebookService.has_deep_two_way_hint():
		var tease := _awakening_text("act2_twoway_tease")
		if tease.strip_edges() != "":
			body_lines.append(tease)
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
	var seen: Dictionary = {}
	var ids: Array[String] = ["F01", "F02", "F03", "F04", "F05"]
	if not GameState.IS_TEN_DAY_EDITION:
		ids = ["F01", "F02", "F03", "F04", "F05", "F06", "F07", "F08", "F09", "F10"]
	for fid in ids:
		if lines.size() >= limit:
			break
		if not GameState.has_fragment(fid):
			continue
		var line := _fragment_awakening_line(fid)
		if line == "" or seen.has(line):
			continue
		seen[line] = true
		lines.append("· %s" % line)
	return lines


func _fragment_awakening_line(fragment_id: String) -> String:
	var entry := StoryNodeCopy.get_fragment(fragment_id)
	var fallback := str(entry.get("fallback", "")).strip_edges()
	var subtitle := str(entry.get("subtitle", "")).strip_edges()
	var raw := fallback if fallback != "" else subtitle
	raw = raw.replace("——失忆物证", "").replace("失忆物证", "").strip_edges()
	if raw == "" or raw == fragment_id:
		return ""
	return StorySlotService.apply(raw, StorySlotService.build_context()).strip_edges()


func _f10_montage(length: String) -> String:
	var key := "f10_short"
	match length:
		"full":
			key = "f10_full"
		"medium":
			key = "f10_medium"
	return StoryNodeCopy.get_awakening(key)


func get_epilogue_steps(ending_id: String) -> Array[Dictionary]:
	## 余韵：物件落点。禁止复述觉醒幕三 / journal / F10。
	var steps: Array[Dictionary] = []
	match ending_id:
		ENDING_NORMAL:
			steps = [
				_epilogue_step("epilogue_normal_1_title", "epilogue_normal_1_body"),
				_epilogue_step("epilogue_normal_2_title", "epilogue_normal_2_body"),
			]
		ENDING_HAPPY:
			steps = [
				_epilogue_step("epilogue_happy_1_title", "epilogue_happy_1_body"),
				_epilogue_step("epilogue_happy_2_title", "epilogue_happy_2_body"),
			]
		ENDING_TRUE:
			steps = [
				_epilogue_step("epilogue_true_1_title", "epilogue_true_1_body"),
				_epilogue_step("epilogue_true_2_title", "epilogue_true_2_body"),
			]
		ENDING_BAD:
			steps = [
				_epilogue_step("epilogue_bad_1_title", "epilogue_bad_1_body"),
				_epilogue_step("epilogue_bad_2_title", "epilogue_bad_2_body"),
			]
		ENDING_BAD_EARLY:
			steps = [
				_epilogue_step("epilogue_bad_early_1_title", "epilogue_bad_early_1_body"),
				_epilogue_step("epilogue_bad_early_2_title", "epilogue_bad_early_2_body"),
			]
		_:
			steps = [{"title": "尾声", "body": "故事结束了。", "kind": "epilogue"}]

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


func _epilogue_step(title_key: String, body_key: String) -> Dictionary:
	return {
		"title": StoryNodeCopy.get_ending(title_key),
		"body": _ending_text(body_key),
		"kind": "epilogue",
	}


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
				_try_append_awakening_journal_line(str(highlight), lines, seen)
			continue
		_try_append_awakening_journal_line(str(entry.get("summary", "")), lines, seen)
	for summary_entry in GameState.get_week_summaries():
		for highlight in summary_entry.get("highlights", []):
			_try_append_awakening_journal_line(str(highlight), lines, seen)
		for highlight in summary_entry.get("merged_highlights", []):
			_try_append_awakening_journal_line(str(highlight), lines, seen)
	if lines.is_empty():
		return [
			"· 她登门那天，你说可以留下帮工。",
			"· 你们一起把第一块萝卜田浇透。",
			"· 你发现本子的日期对不上，却没有赶她走。",
		]
	if lines.size() > max_lines:
		return lines.slice(lines.size() - max_lines, lines.size())
	return lines


func _try_append_awakening_journal_line(raw: String, lines: Array[String], seen: Dictionary) -> void:
	var line := _awakening_journal_line(raw)
	if line == "" or _is_duplicate_journal_line(line, seen):
		return
	lines.append("· %s" % line)


func _awakening_journal_line(raw: String) -> String:
	var cleaned := raw.strip_edges()
	while cleaned.begins_with("·"):
		cleaned = cleaned.substr(1).strip_edges()
	for _i in range(3):
		var stripped := false
		for prefix in ["归档 ·", "归档·", "聊天 ·", "聊天·", "主线 ·", "主线·"]:
			if cleaned.begins_with(prefix):
				cleaned = cleaned.substr(prefix.length()).strip_edges()
				stripped = true
		if not stripped:
			break
	var day_rx := RegEx.new()
	day_rx.compile("^第\\s*\\d+\\s*天[，,]?\\s*(?:晴天|雨天|阴天)?[，,]?")
	cleaned = day_rx.sub(cleaned, "").strip_edges()
	for prefix in ["归档 ·", "归档·", "聊天 ·", "聊天·", "主线 ·", "主线·"]:
		if cleaned.begins_with(prefix):
			cleaned = cleaned.substr(prefix.length()).strip_edges()
	var count_rx := RegEx.new()
	count_rx.compile("^你们聊了\\s*\\d+\\s*句[，,、]?")
	cleaned = count_rx.sub(cleaned, "").strip_edges()
	var quote_rx := RegEx.new()
	quote_rx.compile("^最后提到[：:]\\s*[「\"](.+)[」\"]。?$")
	var quoted := quote_rx.search(cleaned)
	if quoted:
		cleaned = "「%s」" % quoted.get_string(1)
	for prefix in ["你提到：", "你提到:", "今天：", "今天:"]:
		if cleaned.begins_with(prefix):
			cleaned = cleaned.substr(prefix.length()).strip_edges()
	if cleaned == "" or cleaned in ["打理了农场。", "打理了农场", "晴天", "雨天", "阴天"]:
		return ""
	if MemoryService.is_generic_farm_log(cleaned):
		return ""
	if "小狸写进本子" in cleaned:
		return ""
	if " · " in cleaned:
		var left := cleaned.get_slice(" · ", 0)
		if left in ["白天", "傍晚", "夜晚", "清晨", "夜里", "归档", "聊天", "主线"]:
			return ""
	if cleaned.begins_with("你们聊了") and "句" in cleaned:
		return ""
	var beat_rx := RegEx.new()
	beat_rx.compile("^(?:[A-Z]{1,3}_)?N\\d+[a-z]?$")
	if beat_rx.search(cleaned) != null:
		return ""
	return cleaned


func _journal_line_key(line: String) -> String:
	var cleaned := _awakening_journal_line(line)
	if cleaned == "":
		cleaned = line.strip_edges()
	while cleaned.begins_with("·"):
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
