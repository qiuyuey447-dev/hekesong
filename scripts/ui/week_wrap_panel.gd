extends PanelContainer
## 每周第 7 天跨周前小结（XL-F1 · N04/N08）。

signal confirmed

var _title_label: Label
var _body_label: RichTextLabel
var _hint_label: Label
var _confirm_button: Button


func _ready() -> void:
	visible = false
	mouse_filter = Control.MOUSE_FILTER_STOP
	_build_shell()
	_confirm_button.pressed.connect(_on_confirm_pressed)


func open() -> void:
	_refresh_content()
	visible = true


func build_summary_text() -> String:
	return _build_summary_text()


func close_panel() -> void:
	visible = false


func _refresh_content() -> void:
	var week := GameState.get_week_index()
	_title_label.text = "第 %d 周 · 今夜" % week
	_body_label.text = _build_summary_text()
	var hint := _preview_hint()
	_hint_label.text = hint
	_hint_label.visible = hint != ""
	_confirm_button.text = "睡觉，进入下一天"


func _build_summary_text() -> String:
	var lines: PackedStringArray = []
	lines.append("【本周回顾】")
	var week := GameState.get_week_index()
	var found := false
	for entry in GameState.day_journal:
		if entry is Dictionary and int(entry.get("week_index", 0)) == week:
			if _append_journal_entry_lines(lines, entry):
				found = true
	if (
		GameState.is_week_last_day()
		and not _has_journal_for_current_day(week)
	):
		var preview := DayJournalService.build_entry(GameState.weather_today)
		if _append_journal_entry_lines(lines, preview):
			found = true
	var archived := MemoryService.get_week_summary(week)
	if not archived.is_empty():
		for highlight in archived.get("merged_highlights", []):
			var merged_line := str(highlight).strip_edges()
			if merged_line != "":
				lines.append("· %s" % merged_line)
				found = true
	if not found and GameState.last_day_summary.strip_edges() != "":
		lines.append("· %s" % GameState.last_day_summary.strip_edges())
	if lines.size() <= 1:
		lines.append("· 你和 %s 一起把家园又往前推了一小步。" % GameState.companion_name)
	return "\n".join(lines)


func _append_journal_entry_lines(lines: PackedStringArray, entry: Dictionary) -> bool:
	var added := false
	var loop_day := int(entry.get("loop_day", 0))
	var highlights: Variant = entry.get("highlights", [])
	if highlights is Array and highlights.size() > 0:
		for highlight in highlights:
			var line := str(highlight).strip_edges()
			if line != "":
				lines.append("· 第 %d 天：%s" % [loop_day, line])
				added = true
		return added
	var summary := str(entry.get("summary", "")).strip_edges()
	if summary != "":
		lines.append("· 第 %d 天：%s" % [loop_day, summary])
		return true
	return false


func _has_journal_for_current_day(week_index: int) -> bool:
	for entry in GameState.day_journal:
		if not entry is Dictionary:
			continue
		if int(entry.get("week_index", 0)) != week_index:
			continue
		if int(entry.get("day", -1)) == GameState.game_day:
			return true
	return false


func _preview_hint() -> String:
	return StoryRouteData.render_week_relationship_feel().strip_edges()


func _on_confirm_pressed() -> void:
	close_panel()
	confirmed.emit()


func _build_shell() -> void:
	set_anchors_preset(Control.PRESET_FULL_RECT)

	var dim := ColorRect.new()
	dim.set_anchors_preset(Control.PRESET_FULL_RECT)
	dim.color = Color(0.04, 0.05, 0.08, 0.35)
	dim.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(dim)

	var center := CenterContainer.new()
	center.set_anchors_preset(Control.PRESET_FULL_RECT)
	add_child(center)

	var card := PanelContainer.new()
	card.custom_minimum_size = Vector2(680, 360)
	var card_style := StyleBoxFlat.new()
	card_style.bg_color = Color(0.98, 0.95, 0.9, 0.98)
	card_style.border_color = Color(0.78, 0.62, 0.44, 0.55)
	card_style.set_border_width_all(2)
	card_style.set_corner_radius_all(16)
	card_style.content_margin_left = 20
	card_style.content_margin_top = 16
	card_style.content_margin_right = 20
	card_style.content_margin_bottom = 16
	card.add_theme_stylebox_override("panel", card_style)
	center.add_child(card)

	var vbox := VBoxContainer.new()
	vbox.add_theme_constant_override("separation", 14)
	card.add_child(vbox)

	_title_label = Label.new()
	_title_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	_title_label.add_theme_font_size_override("font_size", 30)
	_title_label.add_theme_color_override("font_color", Color(0.32, 0.24, 0.18))
	vbox.add_child(_title_label)

	_body_label = RichTextLabel.new()
	_body_label.custom_minimum_size = Vector2(620, 150)
	_body_label.fit_content = true
	_body_label.scroll_active = true
	_body_label.add_theme_font_size_override("normal_font_size", 20)
	_body_label.add_theme_color_override("default_color", Color(0.28, 0.22, 0.18))
	vbox.add_child(_body_label)

	_hint_label = Label.new()
	_hint_label.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	_hint_label.custom_minimum_size = Vector2(620, 0)
	_hint_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	_hint_label.add_theme_font_size_override("font_size", 19)
	_hint_label.add_theme_color_override("font_color", Color(0.45, 0.36, 0.28))
	vbox.add_child(_hint_label)

	var row := HBoxContainer.new()
	row.alignment = BoxContainer.ALIGNMENT_CENTER
	vbox.add_child(row)

	_confirm_button = Button.new()
	_confirm_button.add_theme_font_size_override("font_size", 22)
	row.add_child(_confirm_button)

	var panel_style := StyleBoxFlat.new()
	panel_style.bg_color = Color(0.1, 0.08, 0.12, 0.5)
	panel_style.set_corner_radius_all(0)
	add_theme_stylebox_override("panel", panel_style)

	var button_style := card_style.duplicate()
	button_style.bg_color = Color(0.93, 0.78, 0.52, 1.0)
	var button_hover := button_style.duplicate()
	button_hover.bg_color = Color(0.98, 0.86, 0.62, 1.0)
	_confirm_button.add_theme_stylebox_override("normal", button_style)
	_confirm_button.add_theme_stylebox_override("hover", button_hover)
	_confirm_button.add_theme_stylebox_override("pressed", button_hover)
