extends PanelContainer
## W5 D35 觉醒演出 — 按 ending_id 分支四幕（§六 · §十一）。

signal finished(skipped: bool)

const FONT_TITLE := 32
const FONT_BODY := 22
const FONT_HINT := 18
const FONT_BUTTON := 22

var _title_label: Label
var _body_label: RichTextLabel
var _step_label: Label
var _continue_button: Button
var _skip_button: Button
var _steps: Array[Dictionary] = []
var _step_index: int = 0
var _ending_id: String = ""


func _ready() -> void:
	visible = false
	mouse_filter = Control.MOUSE_FILTER_STOP
	_build_shell()
	_continue_button.pressed.connect(_on_continue_pressed)
	_skip_button.pressed.connect(_on_skip_pressed)


func open() -> void:
	_ending_id = EndingDirector.resolve_ending(false)
	_steps = EndingDirector.get_d35_awakening_steps(_ending_id)
	_step_index = 0
	visible = true
	_show_step()


func close_panel() -> void:
	visible = false


func _show_step() -> void:
	if _steps.is_empty():
		_finish(false)
		return
	var step: Dictionary = _steps[_step_index]
	_title_label.text = str(step.get("title", ""))
	_body_label.text = str(step.get("body", ""))
	_step_label.text = "%d / %d" % [_step_index + 1, _steps.size()]
	_continue_button.text = "听完了" if _step_index >= _steps.size() - 1 else "继续"


func _on_continue_pressed() -> void:
	if _step_index >= _steps.size() - 1:
		_finish(false)
		return
	_step_index += 1
	_show_step()


func _on_skip_pressed() -> void:
	_finish(true)


func _finish(skipped: bool) -> void:
	close_panel()
	finished.emit(skipped)


func _build_styles() -> void:
	var panel_style := StyleBoxFlat.new()
	panel_style.bg_color = Color(0.12, 0.1, 0.14, 0.82)
	panel_style.border_color = Color(0.85, 0.72, 0.52, 0.55)
	panel_style.set_border_width_all(2)
	panel_style.set_corner_radius_all(20)
	panel_style.content_margin_left = 12
	panel_style.content_margin_top = 12
	panel_style.content_margin_right = 12
	panel_style.content_margin_bottom = 12
	panel_style.shadow_color = Color(0, 0, 0, 0.35)
	panel_style.shadow_size = 12
	panel_style.shadow_offset = Vector2(0, 4)
	add_theme_stylebox_override("panel", panel_style)

	var card_style := StyleBoxFlat.new()
	card_style.bg_color = Color(0.98, 0.95, 0.9, 0.98)
	card_style.border_color = Color(0.78, 0.62, 0.44, 0.5)
	card_style.set_border_width_all(2)
	card_style.set_corner_radius_all(16)
	card_style.content_margin_left = 20
	card_style.content_margin_top = 16
	card_style.content_margin_right = 20
	card_style.content_margin_bottom = 16

	var button_style := card_style.duplicate()
	button_style.bg_color = Color(0.93, 0.78, 0.52, 1.0)
	var button_hover := button_style.duplicate()
	button_hover.bg_color = Color(0.98, 0.86, 0.62, 1.0)

	for button in [_continue_button, _skip_button]:
		if button != null:
			button.add_theme_stylebox_override("normal", button_style)
			button.add_theme_stylebox_override("hover", button_hover)
			button.add_theme_stylebox_override("pressed", button_hover)


func _build_shell() -> void:
	set_anchors_preset(Control.PRESET_FULL_RECT)
	offset_left = 0.0
	offset_top = 0.0
	offset_right = 0.0
	offset_bottom = 0.0

	var dim := ColorRect.new()
	dim.name = "Dim"
	dim.set_anchors_preset(Control.PRESET_FULL_RECT)
	dim.color = Color(0.05, 0.04, 0.08, 0.45)
	dim.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(dim)

	var center := CenterContainer.new()
	center.name = "Center"
	center.set_anchors_preset(Control.PRESET_FULL_RECT)
	add_child(center)

	var card := PanelContainer.new()
	card.name = "Card"
	card.custom_minimum_size = Vector2(720, 420)
	var card_style := StyleBoxFlat.new()
	card_style.bg_color = Color(0.98, 0.95, 0.9, 0.98)
	card_style.border_color = Color(0.78, 0.62, 0.44, 0.5)
	card_style.set_border_width_all(2)
	card_style.set_corner_radius_all(16)
	card_style.content_margin_left = 20
	card_style.content_margin_top = 16
	card_style.content_margin_right = 20
	card_style.content_margin_bottom = 16
	card.add_theme_stylebox_override("panel", card_style)
	center.add_child(card)

	var margin := MarginContainer.new()
	margin.add_theme_constant_override("margin_left", 8)
	margin.add_theme_constant_override("margin_top", 4)
	margin.add_theme_constant_override("margin_right", 8)
	margin.add_theme_constant_override("margin_bottom", 4)
	card.add_child(margin)

	var vbox := VBoxContainer.new()
	vbox.add_theme_constant_override("separation", 12)
	margin.add_child(vbox)

	_title_label = Label.new()
	_title_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	_title_label.add_theme_font_size_override("font_size", FONT_TITLE)
	_title_label.add_theme_color_override("font_color", Color(0.32, 0.24, 0.18))
	vbox.add_child(_title_label)

	_step_label = Label.new()
	_step_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	_step_label.add_theme_font_size_override("font_size", FONT_HINT)
	_step_label.add_theme_color_override("font_color", Color(0.5, 0.42, 0.32))
	vbox.add_child(_step_label)

	_body_label = RichTextLabel.new()
	_body_label.custom_minimum_size = Vector2(640, 220)
	_body_label.fit_content = true
	_body_label.scroll_active = true
	_body_label.add_theme_font_size_override("normal_font_size", FONT_BODY)
	_body_label.add_theme_color_override("default_color", Color(0.28, 0.22, 0.18))
	vbox.add_child(_body_label)

	var hint := Label.new()
	hint.text = StoryNodeCopy.get_awakening("skip_hint")
	hint.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	hint.add_theme_font_size_override("font_size", FONT_HINT)
	hint.add_theme_color_override("font_color", Color(0.55, 0.48, 0.38))
	vbox.add_child(hint)

	var buttons := HBoxContainer.new()
	buttons.alignment = BoxContainer.ALIGNMENT_CENTER
	buttons.add_theme_constant_override("separation", 16)
	vbox.add_child(buttons)

	_skip_button = Button.new()
	_skip_button.text = "先略过"
	_skip_button.add_theme_font_size_override("font_size", FONT_BUTTON)
	buttons.add_child(_skip_button)

	_continue_button = Button.new()
	_continue_button.text = "继续"
	_continue_button.add_theme_font_size_override("font_size", FONT_BUTTON)
	buttons.add_child(_continue_button)

	_build_styles()
