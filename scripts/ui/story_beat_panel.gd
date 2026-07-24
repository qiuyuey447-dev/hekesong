extends PanelContainer
class_name StoryBeatPanel
## P 节点固定剧情演出（§五 · StoryBeatDirector）。

signal finished(beat_id: String)
signal choice_made(choice_id: String)

const CARD_MIN_SIZE := Vector2(620, 300)
const CARD_BG_ALPHA := 0.82
const BODY_MIN_SIZE := Vector2(560, 160)

var _title_label: Label
var _body_label: RichTextLabel
var _step_label: Label
var _node_label: Label
var _continue_button: Button
var _button_row: HBoxContainer
var _choice_buttons: Array[Button] = []
var _card_style: StyleBoxFlat
var _steps: Array[Dictionary] = []
var _step_index: int = 0
var _beat_id: String = ""


func _ready() -> void:
	visible = false
	mouse_filter = Control.MOUSE_FILTER_IGNORE
	_build_shell()
	_continue_button.pressed.connect(_on_continue_pressed)
	_sync_viewport_layout()
	if not get_viewport().size_changed.is_connected(_sync_viewport_layout):
		get_viewport().size_changed.connect(_sync_viewport_layout)


func open(beat: Dictionary) -> void:
	_sync_viewport_layout()
	_beat_id = str(beat.get("id", ""))
	_steps = []
	var raw: Variant = beat.get("steps", [])
	if raw is Array:
		for item in raw:
			if item is Dictionary:
				_steps.append(item)
	_step_index = 0
	var route := str(beat.get("route", StoryBeatDirector.get_active_route()))
	_node_label.text = "%s · %s · %s" % [
		StoryBeatDirector.get_route_label(route),
		str(beat.get("node_label", _beat_id)),
		str(beat.get("emotion", "")),
	]
	visible = true
	show()
	move_to_front()
	_show_step()


func close_panel() -> void:
	visible = false
	_clear_choice_buttons()


func get_beat_id() -> String:
	return _beat_id


func get_step_count() -> int:
	return _steps.size()


func append_steps(new_steps: Array) -> void:
	for item in new_steps:
		if item is Dictionary:
			_steps.append(item)


func show_step_at(index: int) -> void:
	_step_index = clampi(index, 0, maxi(_steps.size() - 1, 0))
	_show_step()


func finish_now() -> void:
	_finish()


func advance_after_choice() -> void:
	if _step_index >= _steps.size() - 1:
		_finish()
		return
	_step_index += 1
	_show_step()


func _show_step() -> void:
	if _steps.is_empty():
		_finish()
		return
	var step: Dictionary = _steps[_step_index]
	_title_label.text = str(step.get("title", ""))
	_body_label.text = str(step.get("body", ""))
	_step_label.text = "%d / %d" % [_step_index + 1, _steps.size()]
	var kind := str(step.get("kind", ""))
	if kind == "choice":
		_continue_button.visible = false
		_show_choice_buttons(step.get("choices", []))
		return
	_clear_choice_buttons()
	_continue_button.visible = true
	if kind == "fragment":
		_continue_button.text = "收录"
	else:
		_continue_button.text = "继续" if _step_index < _steps.size() - 1 else "知道了"


func _on_continue_pressed() -> void:
	if _step_index >= _steps.size() - 1:
		_finish()
		return
	_step_index += 1
	_show_step()


func _finish() -> void:
	_clear_choice_buttons()
	close_panel()
	finished.emit(_beat_id)


func _show_choice_buttons(raw_choices: Variant) -> void:
	_clear_choice_buttons()
	if raw_choices is not Array:
		return
	for item in raw_choices:
		if not item is Dictionary:
			continue
		var choice: Dictionary = item
		var button := Button.new()
		button.text = str(choice.get("label", "选择"))
		button.custom_minimum_size = Vector2(140, 0)
		button.add_theme_font_size_override("font_size", 19)
		_apply_button_style(button, _card_style)
		var choice_id := str(choice.get("id", ""))
		button.pressed.connect(func() -> void:
			choice_made.emit(choice_id)
		)
		_button_row.add_child(button)
		_choice_buttons.append(button)


func _clear_choice_buttons() -> void:
	for button in _choice_buttons:
		if is_instance_valid(button):
			button.queue_free()
	_choice_buttons.clear()


func _build_shell() -> void:
	add_theme_stylebox_override("panel", StyleBoxEmpty.new())

	var center := CenterContainer.new()
	center.name = "Center"
	center.set_anchors_preset(Control.PRESET_FULL_RECT)
	center.set_offsets_preset(Control.PRESET_FULL_RECT)
	center.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(center)

	var card := PanelContainer.new()
	card.mouse_filter = Control.MOUSE_FILTER_STOP
	card.custom_minimum_size = CARD_MIN_SIZE
	_card_style = _card_stylebox()
	card.add_theme_stylebox_override("panel", _card_style)
	center.add_child(card)

	var margin := MarginContainer.new()
	margin.add_theme_constant_override("margin_left", 4)
	margin.add_theme_constant_override("margin_top", 4)
	margin.add_theme_constant_override("margin_right", 4)
	margin.add_theme_constant_override("margin_bottom", 4)
	card.add_child(margin)

	var vbox := VBoxContainer.new()
	vbox.add_theme_constant_override("separation", 10)
	margin.add_child(vbox)

	_node_label = Label.new()
	_node_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	_node_label.add_theme_font_size_override("font_size", 15)
	_node_label.add_theme_color_override("font_color", Color(0.45, 0.36, 0.26, 0.92))
	vbox.add_child(_node_label)

	_title_label = Label.new()
	_title_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	_title_label.add_theme_font_size_override("font_size", 26)
	_title_label.add_theme_color_override("font_color", Color(0.28, 0.22, 0.16, 0.95))
	vbox.add_child(_title_label)

	_step_label = Label.new()
	_step_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	_step_label.add_theme_font_size_override("font_size", 15)
	_step_label.add_theme_color_override("font_color", Color(0.5, 0.42, 0.32, 0.88))
	vbox.add_child(_step_label)

	_body_label = RichTextLabel.new()
	_body_label.custom_minimum_size = BODY_MIN_SIZE
	_body_label.size_flags_vertical = Control.SIZE_EXPAND_FILL
	_body_label.fit_content = true
	_body_label.scroll_active = true
	_body_label.add_theme_font_size_override("normal_font_size", 19)
	_body_label.add_theme_color_override("default_color", Color(0.24, 0.2, 0.16, 0.94))
	vbox.add_child(_body_label)

	_button_row = HBoxContainer.new()
	_button_row.alignment = BoxContainer.ALIGNMENT_CENTER
	_button_row.add_theme_constant_override("separation", 12)
	vbox.add_child(_button_row)

	_continue_button = Button.new()
	_continue_button.text = "继续"
	_continue_button.custom_minimum_size = Vector2(120, 0)
	_continue_button.add_theme_font_size_override("font_size", 19)
	_apply_button_style(_continue_button, _card_style)
	_button_row.add_child(_continue_button)


func _card_stylebox() -> StyleBoxFlat:
	var style := StyleBoxFlat.new()
	style.bg_color = Color(0.97, 0.94, 0.9, CARD_BG_ALPHA)
	style.border_color = Color(0.72, 0.58, 0.42, 0.42)
	style.set_border_width_all(2)
	style.set_corner_radius_all(14)
	style.content_margin_left = 18
	style.content_margin_top = 14
	style.content_margin_right = 18
	style.content_margin_bottom = 14
	style.shadow_color = Color(0, 0, 0, 0.12)
	style.shadow_size = 10
	style.shadow_offset = Vector2(0, 3)
	return style


func _apply_button_style(button: Button, card_style: StyleBoxFlat) -> void:
	var normal := card_style.duplicate()
	normal.bg_color = Color(0.93, 0.78, 0.52, 0.92)
	normal.border_color = Color(0.62, 0.48, 0.30, 0.55)
	var hover := normal.duplicate()
	hover.bg_color = Color(0.98, 0.86, 0.62, 0.96)
	button.add_theme_stylebox_override("normal", normal)
	button.add_theme_stylebox_override("hover", hover)
	button.add_theme_stylebox_override("pressed", hover)


func _sync_viewport_layout() -> void:
	set_anchors_preset(Control.PRESET_FULL_RECT)
	set_offsets_preset(Control.PRESET_FULL_RECT)
	var center := get_node_or_null("Center") as CenterContainer
	if center:
		center.set_anchors_preset(Control.PRESET_FULL_RECT)
		center.set_offsets_preset(Control.PRESET_FULL_RECT)
