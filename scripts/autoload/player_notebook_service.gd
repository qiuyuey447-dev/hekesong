extends Node
## 玩家「我的本子」：可见页、D9 缺页、暗线问号；D10 觉醒时逐条亮起。

const DARK_LINES := {
	"deja_vu_d1": {
		"reveal": "暮色里就眼熟。像见过，想不起来像谁。",
	},
	"rain_moment_d2": {
		"reveal": "廊下躲雨那刻，我真想把它记下来。",
	},
	"mutual_forgetting_d4": {
		"reveal": "被忘记的滋味……我好像也经历过。",
	},
	"player_knows_detail_d6": {
		"reveal": "那句话出口时，连我自己都愣了——我怎么会知道？",
	},
	"two_notebooks_d8": {
		"reveal": "原来我也怕忘。本子写满了她。",
	},
	"time_sense_gap": {
		"reveal": "这片田我来了多久？数不清。日期对不上。",
	},
	"care_direction_slip": {
		"reveal": "有时候说不清，是她在照顾我，还是我在照顾她。",
	},
}


func _ensure_notebook() -> Dictionary:
	var nb: Variant = GameState.long_term_memory.get("player_notebook", {})
	if nb is not Dictionary:
		nb = {}
	var data: Dictionary = nb
	if not data.has("pages"):
		data["pages"] = []
	if not data.has("dark_lines_triggered"):
		data["dark_lines_triggered"] = []
	if not data.has("awakening_revealed"):
		data["awakening_revealed"] = false
	GameState.long_term_memory["player_notebook"] = data
	return data


func get_pages_for_ui() -> Array:
	var pages: Array = []
	for raw in _ensure_notebook().get("pages", []):
		if not raw is Dictionary:
			continue
		var page: Dictionary = raw
		var status := str(page.get("status", "visible"))
		var line := str(page.get("text", "")).strip_edges()
		if status == "missing":
			line = "（缺页）"
		elif status == "question" and not bool(page.get("revealed", false)):
			line = "？"
		elif status == "question" and bool(page.get("revealed", false)):
			line = str(page.get("reveal_text", "？")).strip_edges()
		if line == "":
			continue
		pages.append({
			"game_day": int(page.get("game_day", 0)),
			"text": line,
			"status": status,
			"revealed": bool(page.get("revealed", false)),
		})
	return pages


func latest_visible_excerpt() -> String:
	var best := ""
	var best_day := -1
	for raw in _ensure_notebook().get("pages", []):
		if not raw is Dictionary:
			continue
		var page: Dictionary = raw
		if str(page.get("status", "visible")) != "visible":
			continue
		var day := int(page.get("game_day", 0))
		var text := str(page.get("text", "")).strip_edges()
		if text == "":
			continue
		if day >= best_day:
			best_day = day
			best = text
	return best


func on_beat_completed(beat_id: String) -> void:
	var base := beat_id
	if base.begins_with("BE_"):
		base = base.substr(3)
	match base:
		"P_N01":
			_trigger_dark_line("deja_vu_d1")
		"P_N02":
			add_visible_page("廊下躲雨。想把这一刻记下来。", GameState.game_day, "rain_moment_d2")
		"P_N05", "BE_N05":
			_trigger_dark_line("mutual_forgetting_d4")
		_:
			if base.ends_with("_N02p") or base.ends_with("N02p"):
				_trigger_dark_line("player_knows_detail_d6")
			elif base.ends_with("_N15") or base.ends_with("N15"):
				var excerpt := latest_visible_excerpt()
				if excerpt == "":
					excerpt = "她浇水的样子，她笑起来尾巴翘的角度。"
				add_visible_page(excerpt, GameState.game_day, "two_notebooks_d8")
				_trigger_dark_line("time_sense_gap")


func on_first_write_d7() -> void:
	var text := "她笑起来尾巴翘的角度。"
	if GameState.companion_name.strip_edges() != "":
		text = "%s 在树洞边写下的第一个字。" % GameState.companion_name
	add_visible_page(text, GameState.game_day, "first_write_d7")


func on_w2_keep_choice() -> void:
	_trigger_dark_line("care_direction_slip")


func on_day_advanced(new_day: int) -> void:
	if new_day >= 9:
		apply_d9_missing_pages()


func add_visible_page(text: String, game_day: int = -1, dark_line_id: String = "") -> void:
	text = text.strip_edges()
	if text == "":
		return
	if game_day < 0:
		game_day = GameState.game_day
	var page := _make_page(text, game_day, "visible", dark_line_id)
	_append_page(page)
	_notify()


func apply_d9_missing_pages() -> void:
	var nb := _ensure_notebook()
	var pages: Array = nb.get("pages", [])
	if pages.is_empty():
		return
	var missing_count := 0
	for raw in pages:
		if not raw is Dictionary:
			continue
		if str(raw.get("status", "visible")) == "missing":
			missing_count += 1
	if missing_count > 0:
		return
	var candidates: Array[Dictionary] = []
	for raw in pages:
		if not raw is Dictionary:
			continue
		var page: Dictionary = raw
		if str(page.get("status", "visible")) != "visible":
			continue
		if str(page.get("dark_line_id", "")) == "first_write_d7":
			continue
		candidates.append(page)
	candidates.sort_custom(func(a: Dictionary, b: Dictionary) -> bool:
		return int(a.get("game_day", 999)) < int(b.get("game_day", 999))
	)
	var to_hide := mini(2, candidates.size())
	for i in range(to_hide):
		candidates[i]["status"] = "missing"
	nb["pages"] = pages
	GameState.long_term_memory["player_notebook"] = nb
	_notify()


func reveal_for_awakening() -> Array[String]:
	var nb := _ensure_notebook()
	if bool(nb.get("awakening_revealed", false)):
		return []
	var lines: Array[String] = []
	var pages: Array = nb.get("pages", [])
	for raw in pages:
		if not raw is Dictionary:
			continue
		var page: Dictionary = raw
		if str(page.get("status", "")) != "question":
			continue
		var reveal := str(page.get("reveal_text", "")).strip_edges()
		if reveal == "":
			continue
		page["revealed"] = true
		lines.append("· %s" % reveal)
	nb["pages"] = pages
	nb["awakening_revealed"] = true
	GameState.long_term_memory["player_notebook"] = nb
	_notify()
	return lines


func _trigger_dark_line(line_id: String) -> void:
	line_id = line_id.strip_edges()
	if line_id == "" or line_id not in DARK_LINES:
		return
	var nb := _ensure_notebook()
	var triggered: Array = nb.get("dark_lines_triggered", [])
	if line_id in triggered:
		return
	triggered.append(line_id)
	nb["dark_lines_triggered"] = triggered
	var def: Dictionary = DARK_LINES[line_id]
	_append_page(_make_page(
		"？",
		GameState.game_day,
		"question",
		line_id,
		str(def.get("reveal", ""))
	))
	GameState.long_term_memory["player_notebook"] = nb
	_notify()


func _make_page(
	text: String,
	game_day: int,
	status: String,
	dark_line_id: String = "",
	reveal_text: String = ""
) -> Dictionary:
	return {
		"id": "pn_%d_%d" % [game_day, _ensure_notebook().get("pages", []).size() + 1],
		"game_day": game_day,
		"text": text,
		"status": status,
		"dark_line_id": dark_line_id,
		"reveal_text": reveal_text,
		"revealed": false,
	}


func _append_page(page: Dictionary) -> void:
	var nb := _ensure_notebook()
	var pages: Array = nb.get("pages", [])
	pages.append(page)
	nb["pages"] = pages
	GameState.long_term_memory["player_notebook"] = nb


func _notify() -> void:
	GameState.memory_changed.emit()
	MemoryService.notify_memory_changed()
