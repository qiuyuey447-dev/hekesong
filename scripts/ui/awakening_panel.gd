extends PanelContainer
## W5 D35 觉醒演出 — 信纸翻页 + 打字机（设计稿 §6）。

signal finished(skipped: bool)

var _dim: ColorRect
var _card: PanelContainer
var _title_label: Label
var _body_label: RichTextLabel
var _step_label: Label
var _hint_label: Label
var _continue_button: Button
var _skip_button: Button
var _button_row: HBoxContainer

var _steps: Array[Dictionary] = []
var _step_index: int = 0
var _ending_id: String = ""
var _pages: PackedStringArray = []
var _page_index: int = 0
var _typing: bool = false
var _page_turning: bool = false
var _type_tween: Tween = null
var _page_tween: Tween = null
var _pending_advance: bool = false
var _fade_tween: Tween = null
var _arrow_tween: Tween = null


func _ready() -> void:
	visible = false
	mouse_filter = Control.MOUSE_FILTER_IGNORE
	_build_shell()
	_continue_button.pressed.connect(_on_continue_pressed)
	_skip_button.pressed.connect(_on_skip_pressed)
	_sync_viewport_layout()
	if not get_viewport().size_changed.is_connected(_sync_viewport_layout):
		get_viewport().size_changed.connect(_sync_viewport_layout)


func open() -> void:
	if visible:
		return
	_ending_id = EndingDirector.resolve_ending(false)
	_steps = EndingDirector.get_awakening_steps(_ending_id)
	_step_index = 0
	_page_index = 0
	visible = true
	show()
	move_to_front()
	mouse_filter = Control.MOUSE_FILTER_STOP
	_sync_viewport_layout()
	_play_open_fade()
	_show_step()
	AmbientAudio.play_narrative_stinger("d10_awakening")


func close_panel() -> void:
	_kill_typewriter()
	_kill_page_tween()
	_pending_advance = false
	_stop_arrow()
	visible = false
	mouse_filter = Control.MOUSE_FILTER_IGNORE
	modulate = Color(1, 1, 1, 1)
	if _dim:
		_dim.modulate.a = 1.0
	if _card:
		_card.modulate.a = 1.0
		_card.scale = Vector2.ONE
	if _body_label:
		_body_label.modulate.a = 1.0


func _play_open_fade() -> void:
	if _fade_tween != null and _fade_tween.is_valid():
		_fade_tween.kill()
	if _dim:
		_dim.modulate.a = 0.0
	if _card:
		_card.modulate.a = 0.0
		_card.scale = Vector2(0.96, 0.96)
	_fade_tween = create_tween()
	_fade_tween.set_parallel(true)
	if _dim:
		_fade_tween.tween_property(_dim, "modulate:a", 1.0, 0.4)
	if _card:
		_fade_tween.tween_property(_card, "modulate:a", 1.0, 0.45)
		_fade_tween.tween_property(_card, "scale", Vector2.ONE, 0.45).set_trans(Tween.TRANS_CUBIC).set_ease(Tween.EASE_OUT)


func _show_step() -> void:
	if _steps.is_empty():
		_finish(false)
		return
	var step: Dictionary = _steps[_step_index]
	if bool(step.get("needs_notebook_reveal", false)) and not bool(step.get("notebook_revealed", false)):
		step["notebook_revealed"] = true
		step["body"] = EndingDirector.append_act2_notebook_reveal(str(step.get("body", "")))
		_steps[_step_index] = step
	_title_label.text = str(step.get("title", ""))
	_apply_title_scale(str(step.get("kind", "")))
	_pages = LetterPaperKit.paginate_body(LetterPaperKit.prettify_body(str(step.get("body", ""))))
	_page_index = 0
	_present_page(false)


func _apply_title_scale(kind: String) -> void:
	## 高潮幕略放大标题；普通觉醒幕保持 22–26。
	var size := 26 if kind == "climax" or _step_index >= _steps.size() - 1 else 22
	_title_label.add_theme_font_size_override("font_size", size)


func _present_page(with_turn: bool) -> void:
	_update_page_indicator()
	_refresh_continue_label()
	var page_text := "" if _pages.is_empty() else str(_pages[_page_index])
	if with_turn:
		_page_turning = true
		_kill_typewriter()
		_kill_page_tween()
		_page_tween = create_tween()
		_page_tween.tween_property(_body_label, "modulate:a", 0.0, LetterPaperKit.PAGE_FADE_SEC * 0.55)
		_page_tween.tween_callback(func() -> void:
			_start_typewriter(page_text)
			_body_label.modulate.a = 0.0
		)
		_page_tween.tween_property(_body_label, "modulate:a", 1.0, LetterPaperKit.PAGE_FADE_SEC)
		_page_tween.tween_callback(func() -> void:
			_page_turning = false
			_flush_pending_advance()
		)
	else:
		_body_label.modulate.a = 1.0
		_start_typewriter(page_text)


func _update_page_indicator() -> void:
	var total := 0
	for i in range(_steps.size()):
		total += _pages_for_step(i)
	var current := _pages_before(_step_index) + _page_index + 1
	_step_label.text = "%d / %d" % [current, maxi(total, 1)]


func _pages_before(step_i: int) -> int:
	var total := 0
	for i in range(clampi(step_i, 0, _steps.size())):
		total += _pages_for_step(i)
	return total


func _pages_for_step(i: int) -> int:
	if i < 0 or i >= _steps.size():
		return 0
	if i == _step_index and not _pages.is_empty():
		return maxi(_pages.size(), 1)
	var step: Dictionary = _steps[i]
	return maxi(LetterPaperKit.paginate_body(LetterPaperKit.prettify_body(str(step.get("body", "")))).size(), 1)


func _refresh_continue_label() -> void:
	var last_page := _page_index >= _pages.size() - 1
	var last_step := _step_index >= _steps.size() - 1
	if not last_page:
		_continue_button.text = "翻页"
		_hint_label.text = ""
	elif not last_step:
		_continue_button.text = "继续"
		_hint_label.text = ""
	else:
		_continue_button.text = "听完了"
		_hint_label.text = ""
	_pulse_arrow()


func _start_typewriter(body: String) -> void:
	_kill_typewriter()
	_body_label.text = body
	if body.strip_edges() == "" or not LetterPaperKit.should_typewrite(body):
		_typing = false
		_body_label.visible_ratio = 1.0
		return
	_typing = true
	_body_label.visible_ratio = 0.0
	var dur := clampf(float(body.length()) * LetterPaperKit.TYPEWRITER_SEC_PER_CHAR, 0.35, 6.0)
	_type_tween = create_tween()
	_type_tween.tween_property(_body_label, "visible_ratio", 1.0, dur)
	_type_tween.tween_callback(func() -> void:
		_typing = false
	)


func _kill_typewriter() -> void:
	if _type_tween != null and _type_tween.is_valid():
		_type_tween.kill()
	_type_tween = null
	_typing = false
	if _body_label:
		_body_label.visible_ratio = 1.0


func _kill_page_tween() -> void:
	if _page_tween != null and _page_tween.is_valid():
		_page_tween.kill()
	_page_tween = null
	_page_turning = false


func _finish_typewriter_or_advance() -> void:
	if _page_turning:
		_pending_advance = true
		return
	if _typing:
		var short_page := not LetterPaperKit.should_typewrite(_body_label.text)
		_kill_typewriter()
		_body_label.visible_ratio = 1.0
		if short_page:
			_advance()
		return
	_advance()


func _flush_pending_advance() -> void:
	if not _pending_advance:
		return
	_pending_advance = false
	if visible:
		_advance()


func _advance() -> void:
	if _page_index < _pages.size() - 1:
		_page_index += 1
		_present_page(true)
		return
	if _step_index >= _steps.size() - 1:
		_finish(false)
		return
	_step_index += 1
	_page_turning = true
	_kill_typewriter()
	_kill_page_tween()
	_page_tween = create_tween()
	_page_tween.tween_property(_body_label, "modulate:a", 0.0, LetterPaperKit.PAGE_FADE_SEC * 0.55)
	_page_tween.tween_callback(func() -> void:
		_page_turning = false
		_show_step()
		_pending_advance = false
	)


func _on_continue_pressed() -> void:
	_finish_typewriter_or_advance()


func _on_skip_pressed() -> void:
	AmbientAudio.play_narrative_stinger("d10_awakening")
	_finish(true)


func _finish(skipped: bool) -> void:
	close_panel()
	finished.emit(skipped)


func _on_paper_gui_input(event: InputEvent) -> void:
	if not visible:
		return
	if event is InputEventMouseButton and event.pressed and event.button_index == MOUSE_BUTTON_LEFT:
		_finish_typewriter_or_advance()
		accept_event()


func _pulse_arrow() -> void:
	_stop_arrow()
	if _hint_label == null:
		return
	_hint_label.modulate.a = 0.55
	_arrow_tween = create_tween().set_loops()
	_arrow_tween.tween_property(_hint_label, "modulate:a", 1.0, 0.45).set_trans(Tween.TRANS_SINE)
	_arrow_tween.tween_property(_hint_label, "modulate:a", 0.45, 0.45).set_trans(Tween.TRANS_SINE)


func _stop_arrow() -> void:
	if _arrow_tween != null and _arrow_tween.is_valid():
		_arrow_tween.kill()
	_arrow_tween = null


func _build_shell() -> void:
	add_theme_stylebox_override("panel", StyleBoxEmpty.new())

	_dim = ColorRect.new()
	_dim.name = "Dim"
	_dim.set_anchors_preset(Control.PRESET_FULL_RECT)
	_dim.set_offsets_preset(Control.PRESET_FULL_RECT)
	_dim.color = LetterPaperKit.DIM_SOFT
	_dim.mouse_filter = Control.MOUSE_FILTER_STOP
	_dim.gui_input.connect(_on_paper_gui_input)
	add_child(_dim)

	var center := CenterContainer.new()
	center.name = "Center"
	center.set_anchors_preset(Control.PRESET_FULL_RECT)
	center.set_offsets_preset(Control.PRESET_FULL_RECT)
	center.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(center)

	_card = PanelContainer.new()
	_card.name = "Card"
	_card.mouse_filter = Control.MOUSE_FILTER_STOP
	_card.custom_minimum_size = Vector2(720, 440)
	_card.pivot_offset = Vector2(360, 220)
	_card.add_theme_stylebox_override("panel", LetterPaperKit.paper_style(false))
	_card.gui_input.connect(_on_paper_gui_input)
	center.add_child(_card)

	var ruled := LetterPaperKit.make_ruled_overlay()
	_card.add_child(ruled)

	var margin := MarginContainer.new()
	margin.mouse_filter = Control.MOUSE_FILTER_IGNORE
	margin.add_theme_constant_override("margin_left", 4)
	margin.add_theme_constant_override("margin_top", 4)
	margin.add_theme_constant_override("margin_right", 4)
	margin.add_theme_constant_override("margin_bottom", 4)
	_card.add_child(margin)

	var vbox := VBoxContainer.new()
	vbox.add_theme_constant_override("separation", 18)
	margin.add_child(vbox)

	_title_label = Label.new()
	_title_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	_title_label.add_theme_font_size_override("font_size", 22)
	_title_label.add_theme_color_override("font_color", LetterPaperKit.INK)
	vbox.add_child(_title_label)

	_body_label = RichTextLabel.new()
	_body_label.custom_minimum_size = Vector2(560, 220)
	_body_label.size_flags_vertical = Control.SIZE_EXPAND_FILL
	_body_label.fit_content = false
	_body_label.scroll_active = false
	_body_label.bbcode_enabled = false
	_body_label.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	_body_label.add_theme_font_size_override("normal_font_size", 19)
	_body_label.add_theme_constant_override("line_separation", 16)
	_body_label.add_theme_color_override("default_color", LetterPaperKit.INK)
	_body_label.gui_input.connect(_on_paper_gui_input)
	_body_label.mouse_filter = Control.MOUSE_FILTER_STOP
	vbox.add_child(_body_label)

	var foot := HBoxContainer.new()
	foot.add_theme_constant_override("separation", 12)
	vbox.add_child(foot)

	_hint_label = Label.new()
	_hint_label.text = ""
	_hint_label.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	_hint_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_RIGHT
	_hint_label.add_theme_font_size_override("font_size", 16)
	_hint_label.add_theme_color_override("font_color", LetterPaperKit.INK_SOFT)
	foot.add_child(_hint_label)

	_step_label = Label.new()
	_step_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_RIGHT
	_step_label.add_theme_font_size_override("font_size", 14)
	_step_label.add_theme_color_override("font_color", Color(LetterPaperKit.INK.r, LetterPaperKit.INK.g, LetterPaperKit.INK.b, 0.3))
	foot.add_child(_step_label)

	_button_row = HBoxContainer.new()
	_button_row.alignment = BoxContainer.ALIGNMENT_CENTER
	_button_row.add_theme_constant_override("separation", 18)
	vbox.add_child(_button_row)

	_skip_button = Button.new()
	_skip_button.text = "先略过"
	_skip_button.custom_minimum_size = Vector2(140, 48)
	_skip_button.add_theme_font_size_override("font_size", 16)
	LetterPaperKit.apply_sticky_button(_skip_button, Color(0.78, 0.68, 0.55, 1.0))
	_skip_button.rotation_degrees = -1.5
	_button_row.add_child(_skip_button)

	_continue_button = Button.new()
	_continue_button.text = "继续"
	_continue_button.custom_minimum_size = Vector2(160, 48)
	_continue_button.add_theme_font_size_override("font_size", 16)
	LetterPaperKit.apply_sticky_button(_continue_button, Color(0.86, 0.70, 0.42, 1.0))
	_continue_button.rotation_degrees = 1.8
	_button_row.add_child(_continue_button)

	_wire_sticky_hover(_skip_button)
	_wire_sticky_hover(_continue_button)

	for node in [_title_label, _step_label, _hint_label, _skip_button, _continue_button]:
		LetterPaperKit.apply_font(node)
	LetterPaperKit.apply_font(_body_label)


func _wire_sticky_hover(button: Button) -> void:
	## HBox 会管 position，改用轻微上浮位移的 scale + 阴影感。
	button.mouse_entered.connect(func() -> void:
		button.pivot_offset = button.size * 0.5
		var tw := button.create_tween()
		tw.tween_property(button, "scale", Vector2(1.04, 1.04), 0.12).set_trans(Tween.TRANS_CUBIC).set_ease(Tween.EASE_OUT)
	)
	button.mouse_exited.connect(func() -> void:
		var tw := button.create_tween()
		tw.tween_property(button, "scale", Vector2.ONE, 0.12).set_trans(Tween.TRANS_CUBIC).set_ease(Tween.EASE_OUT)
	)


func _sync_viewport_layout() -> void:
	set_anchors_preset(Control.PRESET_FULL_RECT)
	set_offsets_preset(Control.PRESET_FULL_RECT)
	var center := get_node_or_null("Center") as CenterContainer
	if center:
		center.set_anchors_preset(Control.PRESET_FULL_RECT)
		center.set_offsets_preset(Control.PRESET_FULL_RECT)
	if _dim:
		_dim.set_anchors_preset(Control.PRESET_FULL_RECT)
		_dim.set_offsets_preset(Control.PRESET_FULL_RECT)
	if _card:
		var sz := LetterPaperKit.card_size_for_viewport(get_viewport().get_visible_rect().size, true)
		_card.custom_minimum_size = sz
		_card.pivot_offset = sz * 0.5
		if _body_label:
			_body_label.custom_minimum_size = Vector2(sz.x - 120.0, maxf(200.0, sz.y - 220.0))
