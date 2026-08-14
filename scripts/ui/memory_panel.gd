extends PanelContainer

signal closed

var _summary_label: Label
var _journal_label: RichTextLabel
var _memory_label: RichTextLabel
var _anchor_label: RichTextLabel
var _fragment_label: RichTextLabel
var _memory_toggle: Button
var _fact_toggle: Button
var _d35_button: Button


func _ready() -> void:
	visible = false
	_build_styles()
	_build_shell()
	GameState.memory_changed.connect(refresh)
	GameState.day_advanced.connect(refresh)
	refresh()


func open() -> void:
	visible = true
	refresh()


func close() -> void:
	visible = false
	closed.emit()


func refresh() -> void:
	var snapshot := GameState.get_memory_snapshot()
	_summary_label.text = "第 %d 天" % GameState.game_day

	_journal_label.text = ""
	var journal_entries: Array = snapshot.get("day_journal", [])
	if journal_entries.is_empty():
		_journal_label.append_text("这几天的字，还没写下。")
	else:
		for entry in journal_entries:
			var day_n := int(entry.get("loop_day", entry.get("game_day", 0)))
			var summary := str(entry.get("summary", "")).strip_edges()
			if summary == "":
				continue
			_journal_label.append_text("第 %d 天\n%s\n\n" % [day_n, summary])

	_memory_label.text = ""
	var long_term: Dictionary = snapshot.get("long_term_memory", {})
	var promise: Dictionary = long_term.get("promise", {})
	if not promise.is_empty():
		_memory_label.append_text("约定\n%s\n\n" % str(promise.get("summary", "")))
	var name := GameState.get_player_display_name()
	if name != "":
		_memory_label.append_text("名字\n%s\n\n" % name)
	var wrote := false
	for entry in long_term.get("anchors", []):
		var line := str(entry.get("summary", "")).strip_edges()
		if line == "":
			continue
		if not wrote:
			_memory_label.append_text("记下的\n")
			wrote = true
		_memory_label.append_text("· %s\n" % line)
	if _memory_label.text.strip_edges() == "":
		_memory_label.append_text("本子还空着。日子过了，字会来。")

	_fragment_label.text = ""
	for line in StoryBeatDirector.get_fragment_display_lines():
		if line.begins_with("?"):
			_fragment_label.append_text("%s\n" % line)
		else:
			_fragment_label.append_text("%s\n" % line)


func _build_styles() -> void:
	var panel_style := StyleBoxFlat.new()
	panel_style.bg_color = Color(0.99, 0.96, 0.9, 0.97)
	panel_style.border_color = Color(0.82, 0.68, 0.48, 0.65)
	panel_style.set_border_width_all(2)
	panel_style.set_corner_radius_all(28)
	panel_style.content_margin_left = 8
	panel_style.content_margin_top = 8
	panel_style.content_margin_right = 8
	panel_style.content_margin_bottom = 8
	panel_style.shadow_color = Color(0, 0, 0, 0.14)
	panel_style.shadow_size = 10
	panel_style.shadow_offset = Vector2(0, 4)
	add_theme_stylebox_override("panel", panel_style)


func _build_shell() -> void:
	anchors_preset = Control.PRESET_CENTER
	offset_left = -520.0
	offset_top = -320.0
	offset_right = 520.0
	offset_bottom = 320.0

	var margin := MarginContainer.new()
	margin.add_theme_constant_override("margin_left", 20)
	margin.add_theme_constant_override("margin_top", 18)
	margin.add_theme_constant_override("margin_right", 20)
	margin.add_theme_constant_override("margin_bottom", 18)
	add_child(margin)

	var root := VBoxContainer.new()
	root.add_theme_constant_override("separation", 12)
	margin.add_child(root)

	var title := Label.new()
	title.text = "她的本子"
	title.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	title.add_theme_font_size_override("font_size", 38)
	title.add_theme_color_override("font_color", Color(0.42, 0.3, 0.18))
	root.add_child(title)

	_summary_label = Label.new()
	_summary_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	_summary_label.add_theme_font_size_override("font_size", 20)
	root.add_child(_summary_label)

	var columns := HBoxContainer.new()
	columns.add_theme_constant_override("separation", 12)
	root.add_child(columns)

	_journal_label = _make_rich_box("日记")
	columns.add_child(_wrap_box("这些日子", _journal_label))
	_memory_label = _make_rich_box("本子")
	columns.add_child(_wrap_box("写进去的", _memory_label))
	_fragment_label = _make_rich_box("记起的片段")
	columns.add_child(_wrap_box("记起的片段", _fragment_label))
	_anchor_label = _memory_label

	var toggles := HBoxContainer.new()
	toggles.alignment = BoxContainer.ALIGNMENT_CENTER
	toggles.add_theme_constant_override("separation", 10)
	toggles.visible = OS.is_debug_build()
	root.add_child(toggles)

	_memory_toggle = Button.new()
	_memory_toggle.custom_minimum_size = Vector2(0, 44)
	_memory_toggle.add_theme_font_size_override("font_size", 20)
	_memory_toggle.pressed.connect(func() -> void:
		MemoryService.set_debug_disable_memory(not MemoryService.debug_disable_memory)
		refresh()
	)
	toggles.add_child(_memory_toggle)

	_fact_toggle = Button.new()
	_fact_toggle.custom_minimum_size = Vector2(0, 44)
	_fact_toggle.add_theme_font_size_override("font_size", 20)
	_fact_toggle.pressed.connect(func() -> void:
		ResponseValidator.set_debug_disable_fact_lock(not ResponseValidator.debug_disable_fact_lock)
		refresh()
	)
	toggles.add_child(_fact_toggle)

	_d35_button = Button.new()
	_d35_button.text = "调试 · 跳到终章日"
	_d35_button.custom_minimum_size = Vector2(0, 44)
	_d35_button.add_theme_font_size_override("font_size", 20)
	_d35_button.pressed.connect(_on_jump_d35_pressed)
	toggles.add_child(_d35_button)

	var close_button := Button.new()
	close_button.text = "关闭"
	close_button.custom_minimum_size = Vector2(0, 48)
	close_button.add_theme_font_size_override("font_size", 22)
	close_button.pressed.connect(close)
	root.add_child(close_button)


func _on_jump_d35_pressed() -> void:
	GameState.debug_jump_to_d35()
	refresh()


func _wrap_box(title: String, content: RichTextLabel) -> PanelContainer:
	var card := PanelContainer.new()
	card.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	card.size_flags_vertical = Control.SIZE_EXPAND_FILL
	var style := StyleBoxFlat.new()
	style.bg_color = Color(1.0, 0.98, 0.94, 0.96)
	style.border_color = Color(0.88, 0.76, 0.56, 0.45)
	style.set_border_width_all(1)
	style.set_corner_radius_all(20)
	style.content_margin_left = 12
	style.content_margin_top = 10
	style.content_margin_right = 12
	style.content_margin_bottom = 10
	card.add_theme_stylebox_override("panel", style)

	var box := VBoxContainer.new()
	box.add_theme_constant_override("separation", 8)
	card.add_child(box)

	var label := Label.new()
	label.text = title
	label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	label.add_theme_font_size_override("font_size", 22)
	box.add_child(label)
	box.add_child(content)
	return card


func _make_rich_box(_name: String) -> RichTextLabel:
	var rich := RichTextLabel.new()
	rich.custom_minimum_size = Vector2(280, 360)
	rich.bbcode_enabled = true
	rich.scroll_active = true
	rich.fit_content = false
	return rich
