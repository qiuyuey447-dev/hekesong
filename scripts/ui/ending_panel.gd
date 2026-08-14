extends PanelContainer
## 四结局完结演出：信纸翻页 + 打字机（设计稿 §6，底色略暗、留白更多）。

signal finished(action: String)

var _dim: ColorRect
var _card: PanelContainer
var _title_label: Label
var _body_label: RichTextLabel
var _step_label: Label
var _hint_label: Label
var _continue_button: Button
var _restart_button: Button
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
var _fade_tween: Tween = null
var _arrow_tween: Tween = null
var _is_credits: bool = false


func _ready() -> void:
	visible = false
	mouse_filter = Control.MOUSE_FILTER_IGNORE
	_build_shell()
	_continue_button.pressed.connect(_on_continue_pressed)
	_restart_button.pressed.connect(_on_restart_pressed)
	_sync_viewport_layout()
	if not get_viewport().size_changed.is_connected(_sync_viewport_layout):
		get_viewport().size_changed.connect(_sync_viewport_layout)


func open(ending_id: String) -> void:
	_ending_id = ending_id
	_steps = EndingDirector.get_full_ending_steps(ending_id)
	_begin_show()


func open_game_over(ending_id: String) -> void:
	_ending_id = ending_id
	_steps = []
	for step in EndingDirector.get_full_ending_steps(ending_id):
		if str(step.get("kind", "")) == "credits":
			_steps.append(step)
	if _steps.is_empty():
		_steps = [{"title": "游戏结束", "body": "—— 感谢游玩 ——", "kind": "credits"}]
	_begin_show()


func _begin_show() -> void:
	_step_index = 0
	_page_index = 0
	visible = true
	show()
	move_to_front()
	mouse_filter = Control.MOUSE_FILTER_STOP
	_sync_viewport_layout()
	_play_open_fade()
	_show_step()


func close_panel() -> void:
	_kill_typewriter()
	_kill_page_tween()
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
		_fade_tween.tween_property(_dim, "modulate:a", 1.0, 0.45)
	if _card:
		_fade_tween.tween_property(_card, "modulate:a", 1.0, 0.5)
		_fade_tween.tween_property(_card, "scale", Vector2.ONE, 0.5).set_trans(Tween.TRANS_CUBIC).set_ease(Tween.EASE_OUT)


func _show_step() -> void:
	if _steps.is_empty():
		_finish("title")
		return
	var step: Dictionary = _steps[_step_index]
	var kind := str(step.get("kind", ""))
	_is_credits = kind == "credits"
	_title_label.text = str(step.get("title", ""))
	_apply_kind_style(kind)
	_pages = LetterPaperKit.paginate_body(LetterPaperKit.prettify_body(str(step.get("body", ""))))
	_page_index = 0
	_update_buttons()
	_present_page(false)


func _apply_kind_style(kind: String) -> void:
	## title_card / climax 放大；credits 更疏。
	match kind:
		"title_card":
			_title_label.add_theme_font_size_override("font_size", 30)
			_body_label.add_theme_font_size_override("normal_font_size", 20)
			_body_label.add_theme_constant_override("line_separation", 22)
		"climax":
			_title_label.add_theme_font_size_override("font_size", 26)
			_body_label.add_theme_font_size_override("normal_font_size", 19)
			_body_label.add_theme_constant_override("line_separation", 18)
		"credits":
			_title_label.add_theme_font_size_override("font_size", 24)
			_body_label.add_theme_font_size_override("normal_font_size", 17)
			_body_label.add_theme_constant_override("line_separation", 20)
		_:
			_title_label.add_theme_font_size_override("font_size", 22)
			_body_label.add_theme_font_size_override("normal_font_size", 19)
			_body_label.add_theme_constant_override("line_separation", 18)


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
	if _is_credits:
		_continue_button.text = "回到标题"
		_hint_label.text = "↘"
	elif _page_index < _pages.size() - 1:
		_continue_button.text = "翻页"
		_hint_label.text = "↘"
	elif _step_index < _steps.size() - 1:
		_continue_button.text = "继续"
		_hint_label.text = "↘"
	else:
		_continue_button.text = "继续"
		_hint_label.text = "↘"
	_pulse_arrow()


func _update_buttons() -> void:
	_continue_button.visible = true
	_restart_button.visible = false
	if _is_credits:
		_continue_button.text = "回到标题"


func _start_typewriter(body: String) -> void:
	_kill_typewriter()
	_body_label.text = body
	if body.strip_edges() == "":
		_typing = false
		_body_label.visible_ratio = 1.0
		return
	_typing = true
	_body_label.visible_ratio = 0.0
	var dur := clampf(float(body.length()) * LetterPaperKit.TYPEWRITER_SEC_PER_CHAR, 0.35, 6.5)
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
		return
	if _typing:
		_kill_typewriter()
		_body_label.visible_ratio = 1.0
		return
	_advance()


func _advance() -> void:
	if _is_credits:
		_finish("title")
		return
	if _page_index < _pages.size() - 1:
		_page_index += 1
		_present_page(true)
		return
	if _step_index >= _steps.size() - 1:
		_finish("title")
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
	)


func _on_continue_pressed() -> void:
	_finish_typewriter_or_advance()


func _on_restart_pressed() -> void:
	_finish("restart")


func _finish(action: String) -> void:
	if not GameState.is_story_complete():
		EndingDirector.finalize_ending(_ending_id)
	close_panel()
	finished.emit(action)


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
	_dim.color = LetterPaperKit.DIM_MOODY
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
	_card.custom_minimum_size = Vector2(740, 460)
	_card.pivot_offset = Vector2(370, 230)
	_card.add_theme_stylebox_override("panel", LetterPaperKit.paper_style(true))
	_card.gui_input.connect(_on_paper_gui_input)
	center.add_child(_card)

	var ruled := LetterPaperKit.make_ruled_overlay()
	_card.add_child(ruled)

	var margin := MarginContainer.new()
	margin.mouse_filter = Control.MOUSE_FILTER_IGNORE
	margin.add_theme_constant_override("margin_left", 8)
	margin.add_theme_constant_override("margin_top", 10)
	margin.add_theme_constant_override("margin_right", 8)
	margin.add_theme_constant_override("margin_bottom", 8)
	_card.add_child(margin)

	var vbox := VBoxContainer.new()
	vbox.add_theme_constant_override("separation", 22)
	margin.add_child(vbox)

	_title_label = Label.new()
	_title_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	_title_label.add_theme_font_size_override("font_size", 22)
	_title_label.add_theme_color_override("font_color", LetterPaperKit.INK)
	vbox.add_child(_title_label)

	_body_label = RichTextLabel.new()
	_body_label.custom_minimum_size = Vector2(580, 240)
	_body_label.size_flags_vertical = Control.SIZE_EXPAND_FILL
	_body_label.fit_content = false
	_body_label.scroll_active = false
	_body_label.bbcode_enabled = false
	_body_label.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	_body_label.add_theme_font_size_override("normal_font_size", 19)
	_body_label.add_theme_constant_override("line_separation", 18)
	_body_label.add_theme_color_override("default_color", LetterPaperKit.INK)
	_body_label.gui_input.connect(_on_paper_gui_input)
	_body_label.mouse_filter = Control.MOUSE_FILTER_STOP
	vbox.add_child(_body_label)

	var foot := HBoxContainer.new()
	foot.add_theme_constant_override("separation", 12)
	vbox.add_child(foot)

	_hint_label = Label.new()
	_hint_label.text = "↘"
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

	_restart_button = Button.new()
	_restart_button.text = "重新开始"
	_restart_button.visible = false
	_restart_button.custom_minimum_size = Vector2(160, 48)
	_restart_button.add_theme_font_size_override("font_size", 16)
	LetterPaperKit.apply_sticky_button(_restart_button, Color(0.78, 0.68, 0.55, 1.0))
	_restart_button.rotation_degrees = -1.6
	_button_row.add_child(_restart_button)

	_continue_button = Button.new()
	_continue_button.text = "继续"
	_continue_button.custom_minimum_size = Vector2(160, 48)
	_continue_button.add_theme_font_size_override("font_size", 16)
	LetterPaperKit.apply_sticky_button(_continue_button, Color(0.86, 0.70, 0.42, 1.0))
	_continue_button.rotation_degrees = 1.6
	_button_row.add_child(_continue_button)

	_wire_sticky_hover(_restart_button)
	_wire_sticky_hover(_continue_button)

	for node in [_title_label, _step_label, _hint_label, _restart_button, _continue_button]:
		LetterPaperKit.apply_font(node)
	LetterPaperKit.apply_font(_body_label)


func _wire_sticky_hover(button: Button) -> void:
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
			_body_label.custom_minimum_size = Vector2(sz.x - 130.0, maxf(220.0, sz.y - 240.0))
