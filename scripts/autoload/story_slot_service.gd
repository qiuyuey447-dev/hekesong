extends Node
## 节点 {slot} 填槽：从 promise / prefs / journal / anchors 读取，读不到走 fallback（XL-C8）。

const SLOT_FALLBACKS := {
	"player_name": "你",
	"companion_name": "小狸",
	"promise.summary": "一起站在这里看看",
	"crop_label": "萝卜",
	"item_name": "零食",
	"notebook_excerpt": "3月？不对……昨天？好像浇过，又好像没有。",
	"my_notebook_excerpt": "她浇水的样子，她笑起来尾巴翘的角度。",
	"time_rhythm_hint": "",
	"first_meet_summary": "她第一次请求留下帮工。",
	"first_plant_summary": "你们在你的田上种下第一粒种子。",
	"absence_comeback": "你回来了。",
	"yesterday_echo": "在家园里忙了一天",
	"journal_line_1": "田浇过。手还泥着。",
	"journal_line_2": "",
	"journal_line_3": "",
}

const TREAT_LABELS := {
	"carrot": "胡萝卜",
	"pumpkin": "南瓜",
	"apple": "苹果",
	"turnip": "萝卜",
}


func build_context(extra: Dictionary = {}) -> Dictionary:
	var max_lines := int(extra.get("journal_max_lines", 3))
	var ctx := _base_context(max_lines)
	for key in extra.keys():
		if str(key) == "journal_max_lines":
			continue
		ctx[str(key)] = str(extra[key])
	return ctx


func slot(key: String, context: Dictionary = {}) -> String:
	var ctx := context if not context.is_empty() else build_context()
	return _resolve_slot(str(key).strip_edges(), ctx)


func apply(text: String, context: Dictionary = {}) -> String:
	if text.find("{") < 0:
		return text
	var ctx := context if not context.is_empty() else build_context()
	var result := text
	var guard := 0
	while guard < 32:
		guard += 1
		var start := result.find("{")
		if start < 0:
			break
		var end := result.find("}", start + 1)
		if end < 0:
			break
		var key := result.substr(start + 1, end - start - 1).strip_edges()
		var value := _resolve_slot(key, ctx)
		result = result.substr(0, start) + value + result.substr(end + 1)
	return result


func pick_fragment_line(fragment_id: String, fallback: String) -> String:
	match fragment_id:
		"F01":
			return _pick_journal_line(["rain", "story", "daily"], fallback)
		"F02":
			return _pick_memory_line(["plant", "harvest"], fallback)
		"F04":
			return slot("promise.summary", build_context({"promise.summary": fallback}))
		"F07":
			return "· %s" % apply(fallback, build_context())
		"F06":
			var absence := _pick_absence_line()
			if absence != "":
				return "· %s" % absence
			return "· %s" % fallback
		_:
			return "· %s" % fallback


func render_gift_deja_vu(route_tone: String) -> String:
	var item_name := slot("item_name")
	var companion := GameState.companion_name
	var text := StoryNodeCopy.get_render("gift_deja_vu", route_tone)
	if text == "":
		text = StoryNodeCopy.get_render("gift_deja_vu", "default")
	return text % [companion, item_name]


func render_promise_line(route_tone: String) -> String:
	return apply(StoryNodeCopy.get_render("promise_line", route_tone), build_context())


func render_player_name_line(route_tone: String) -> String:
	var player := slot("player_name")
	if not GameState.companion_can_say_player_name() or player == SLOT_FALLBACKS["player_name"]:
		var key := "no_name_bad" if route_tone == "bad" else "no_name_default"
		return StoryNodeCopy.get_render("player_name_line", route_tone, key) % slot("companion_name")
	match route_tone:
		"true", "happy", "bad":
			return apply(StoryNodeCopy.get_render("player_name_line", route_tone), build_context())
		_:
			var persona := GameState.get_persona_vector()
			var warm := float(persona.get("warm", 0.5))
			var strict := float(persona.get("strict", 0.5))
			var subkey := "normal_default"
			if warm >= strict + 0.12:
				subkey = "normal_warm"
			elif strict >= warm + 0.12:
				subkey = "normal_strict"
			return apply(StoryNodeCopy.get_render("player_name_line", route_tone, subkey), build_context())


func render_time_rhythm_hint(companion: String) -> String:
	var hint := slot("time_rhythm_hint")
	if hint == "":
		return ""
	return "%s 轻声说：「%s」" % [companion, hint]


func _base_context(max_lines: int = 3) -> Dictionary:
	var promise_summary := GameState.get_story_promise_summary()

	var player := GameState.get_player_display_name()
	if GameState.companion_can_say_player_name() and GameState.has_player_name_set():
		player = GameState.player_name.strip_edges()

	var journal_lines := _collect_journal_lines(max_lines)
	var ctx := {
		"player_name": player,
		"companion_name": GameState.companion_name,
		"promise.summary": promise_summary,
		"crop_label": _crop_label(),
		"item_name": _last_gift_name(),
		"notebook_excerpt": _notebook_excerpt(),
		"my_notebook_excerpt": _my_notebook_excerpt(),
		"time_rhythm_hint": _time_rhythm_hint(),
		"first_meet_summary": _pick_memory_line(["story_beat", "name_set"], str(SLOT_FALLBACKS["first_meet_summary"])),
		"first_plant_summary": _pick_memory_line(["plant", "harvest"], str(SLOT_FALLBACKS["first_plant_summary"])),
		"absence_comeback": _pick_absence_line(),
		"yesterday_echo": _yesterday_echo(),
		"journal_line_1": journal_lines[0] if journal_lines.size() > 0 else str(SLOT_FALLBACKS["journal_line_1"]),
		"journal_line_2": journal_lines[1] if journal_lines.size() > 1 else str(SLOT_FALLBACKS["journal_line_2"]),
		"journal_line_3": journal_lines[2] if journal_lines.size() > 2 else str(SLOT_FALLBACKS["journal_line_3"]),
	}
	return ctx


func _resolve_slot(key: String, ctx: Dictionary) -> String:
	if ctx.has(key):
		var value := str(ctx[key]).strip_edges()
		if value != "":
			return value
		if key == "promise.summary" and GameState.IS_TEN_DAY_EDITION:
			return ""
	if SLOT_FALLBACKS.has(key):
		return str(SLOT_FALLBACKS[key])
	return ""


func _crop_label() -> String:
	var crop := str(GameState.long_term_memory.get("prefs", {}).get("fav_crop", GameState.CROP_TURNIP))
	if crop == GameState.CROP_TURNIP or crop == "turnip":
		return "萝卜"
	return str(TREAT_LABELS.get(crop, crop))


func _last_gift_name() -> String:
	for raw in _all_memory_entries():
		if not raw is Dictionary:
			continue
		if str(raw.get("kind", "")) != "gift":
			continue
		var facts: Dictionary = raw.get("facts", {}) if raw.get("facts", {}) is Dictionary else {}
		var item_id := str(facts.get("item_id", "")).strip_edges()
		if item_id != "":
			var item := ShopCatalog.get_treat_item(item_id)
			if not item.is_empty():
				return str(item.get("name", item_id))
			return str(TREAT_LABELS.get(item_id, item_id))
		var summary := str(raw.get("summary", "")).strip_edges()
		if summary.begins_with("你给小狸喂了 "):
			return summary.trim_prefix("你给小狸喂了 ").trim_suffix("。").strip_edges()
		if summary.begins_with("你喂她"):
			return summary.trim_prefix("你喂她").trim_suffix("。").strip_edges()
	return str(SLOT_FALLBACKS["item_name"])


func _notebook_excerpt() -> String:
	for raw in _all_memory_entries():
		if not raw is Dictionary:
			continue
		var kind := str(raw.get("kind", ""))
		if kind not in ["chat", "journal_chat", "story_beat"]:
			continue
		var line := _player_facing_excerpt(str(raw.get("summary", "")))
		if line != "":
			return line
	for entry in GameState.day_journal:
		if not entry is Dictionary:
			continue
		var highlights: Variant = entry.get("highlights", [])
		if highlights is Array:
			for raw in highlights:
				var line := _player_facing_excerpt(str(raw))
				if line != "":
					return line
		var summary := _player_facing_excerpt(str(entry.get("summary", "")))
		if summary != "":
			return summary
	var promise := GameState.get_story_promise_summary().strip_edges()
	if promise != "":
		return promise.substr(0, mini(promise.length(), 48))
	if GameState.has_player_name_set():
		return "你让我叫你「%s」。" % GameState.player_name.strip_edges()
	return str(SLOT_FALLBACKS["notebook_excerpt"])


func _my_notebook_excerpt() -> String:
	## 玩家「偷偷记她」的本子摘录：优先取 PlayerNotebookService 可见页。
	var from_nb := PlayerNotebookService.latest_visible_excerpt()
	if from_nb != "":
		return from_nb
	var her_line := _notebook_excerpt()
	var companion := GameState.companion_name
	# ① journal 里 LLM 提炼的「companion_feel」——对她的观察，最贴题
	for entry in GameState.day_journal:
		if not entry is Dictionary:
			continue
		var feel := str(entry.get("companion_feel", "")).strip_edges()
		if feel != "" and feel != her_line:
			return _clean_excerpt(feel)
	# ② 提到她的日高亮（投喂 / 陪 / 聊天 / 名字）
	for entry in GameState.day_journal:
		if not entry is Dictionary:
			continue
		var highlights: Variant = entry.get("highlights", [])
		if highlights is Array:
			for h in highlights:
				var line := _clean_excerpt(str(h))
				if line == "" or line == her_line:
					continue
				if companion in line or "投喂" in line or "喂" in line or "陪" in line or "聊" in line:
					return line
	# ③ 与她相关的记忆 / 锚点
	for raw in _all_memory_entries():
		if not raw is Dictionary:
			continue
		if str(raw.get("kind", "")) in ["gift", "chat", "journal_chat", "companion"]:
			var s := _clean_excerpt(str(raw.get("summary", "")))
			if s != "" and s != her_line:
				return s
	return str(SLOT_FALLBACKS["my_notebook_excerpt"])


func _clean_excerpt(text: String) -> String:
	return _player_facing_excerpt(text)


func _player_facing_excerpt(text: String) -> String:
	var cleaned := MemoryService.player_facing_journal_line(text)
	if cleaned == "":
		return ""
	if MemoryService.looks_like_player_instruction(cleaned):
		return ""
	if cleaned.length() > 44:
		cleaned = cleaned.substr(0, 44).strip_edges() + "…"
	return cleaned


func _time_rhythm_hint() -> String:
	var rhythm := str(GameState.long_term_memory.get("prefs", {}).get("time_rhythm", "")).strip_edges()
	match rhythm:
		"dusk", "evening":
			return "你好像总在太阳快落山时出现。"
		"morning":
			return "你好像总在清晨就来田里。"
		"night":
			return "你好像总在夜里还在农场。"
		_:
			return ""


func _yesterday_echo() -> String:
	var echo := GameState.build_yesterday_echo_hint().strip_edges()
	if echo != "":
		return echo
	return str(SLOT_FALLBACKS["yesterday_echo"])


func _pick_absence_line() -> String:
	if GameState.has_pending_absence():
		var hint := GameState.get_absence_comeback_line()
		if hint.strip_edges() != "":
			return hint.strip_edges()
	var notes: Array = GameState.long_term_memory.get("absence_notes", [])
	for i in range(notes.size() - 1, -1, -1):
		if not notes[i] is Dictionary:
			continue
		var summary := str((notes[i] as Dictionary).get("summary", "")).strip_edges()
		if summary != "":
			return summary
	return ""


func _pick_memory_line(kinds: Array, fallback: String) -> String:
	for raw in _all_memory_entries():
		if not raw is Dictionary:
			continue
		if str(raw.get("kind", "")) in kinds:
			var summary := str(raw.get("summary", "")).strip_edges()
			if summary != "":
				return summary
	return fallback


func _pick_journal_line(preferred_tags: Array, fallback: String) -> String:
	for entry in GameState.day_journal:
		if not entry is Dictionary:
			continue
		var tags: Variant = entry.get("tags", [])
		if tags is Array:
			for tag in tags:
				if str(tag) in preferred_tags:
					var line := MemoryService.player_facing_journal_line(_journal_entry_line(entry))
					if line != "":
						return "· %s" % line
	for summary_entry in GameState.get_week_summaries():
		for highlight in summary_entry.get("highlights", []):
			var line := MemoryService.player_facing_journal_line(str(highlight))
			if line != "":
				return "· %s" % line
	for entry in GameState.day_journal:
		if entry is Dictionary:
			var line := MemoryService.player_facing_journal_line(_journal_entry_line(entry))
			if line != "":
				return "· %s" % line
	var authored := fallback.strip_edges()
	if authored == "":
		return ""
	return "· %s" % authored


func _journal_entry_line(entry: Dictionary) -> String:
	var highlights: Variant = entry.get("highlights", [])
	if highlights is Array and highlights.size() > 0:
		return str(highlights[0]).strip_edges()
	return str(entry.get("summary", "")).strip_edges()


func _collect_journal_lines(max_lines: int) -> Array[String]:
	var lines: Array[String] = []
	for entry in GameState.day_journal:
		if not entry is Dictionary:
			continue
		var line := _journal_entry_line(entry)
		var cleaned := MemoryService.player_facing_journal_line(line)
		if cleaned != "":
			lines.append(cleaned)
		if lines.size() >= max_lines:
			return lines
	for summary_entry in GameState.get_week_summaries():
		for highlight in summary_entry.get("highlights", []):
			var line := str(highlight).strip_edges()
			if line != "":
				lines.append(line)
			if lines.size() >= max_lines:
				return lines
		for highlight in summary_entry.get("merged_highlights", []):
			var line := str(highlight).strip_edges()
			if line != "":
				lines.append(line)
			if lines.size() >= max_lines:
				return lines
	return lines


func _all_memory_entries() -> Array:
	var combined: Array = []
	combined.append_array(GameState.short_term_memory)
	combined.append_array(GameState.long_term_memory.get("anchors", []))
	return combined
