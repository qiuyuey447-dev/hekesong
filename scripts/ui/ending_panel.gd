extends PanelContainer
## 四结局完结演出：尾声 → 标题卡 → Staff → 收束。

signal finished(action: String)

const FONT_TITLE := 30
const FONT_BODY := 21
const FONT_HINT := 18
const FONT_BUTTON := 20

var _title_label: Label
var _body_label: RichTextLabel
var _step_label: Label
var _continue_button: Button
var _restart_button: Button
var _steps: Array[Dictionary] = []
var _step_index: int = 0
var _ending_id: String = ""


func _ready() -> void:
	visible = false
	mouse_filter = Control.MOUSE_FILTER_STOP
	_build_shell()
	_continue_button.pressed.connect(_on_continue_pressed)
	_restart_button.pressed.connect(_on_restart_pressed)


func open(ending_id: String) -> void:
	_ending_id = ending_id
	_steps = EndingDirector.get_full_ending_steps(ending_id)
	_step_index = 0
	visible = true
	_update_buttons()
	_show_step()


func open_game_over(ending_id: String) -> void:
	_ending_id = ending_id
	_steps = []
	for step in EndingDirector.get_full_ending_steps(ending_id):
		if str(step.get("kind", "")) == "credits":
			_steps.append(step)
	if _steps.is_empty():
		_steps = [{"title": "游戏结束", "body": "—— 感谢游玩 ——", "kind": "credits"}]
	_step_index = 0
	visible = true
	_update_buttons()
	_show_step()


func close_panel() -> void:
	visible = false


func _show_step() -> void:
	if _steps.is_empty():
		_finish("restart")
		return
	var step: Dictionary = _steps[_step_index]
	_title_label.text = str(step.get("title", ""))
	_body_label.text = str(step.get("body", ""))
	_step_label.text = "%d / %d" % [_step_index + 1, _steps.size()]
	var kind := str(step.get("kind", ""))
	if kind == "credits":
		_continue_button.text = "重新开始"
	else:
		_continue_button.text = "继续"
	_update_buttons()


func _update_buttons() -> void:
	var kind := ""
	if not _steps.is_empty() and _step_index < _steps.size():
		kind = str(_steps[_step_index].get("kind", ""))
	var is_credits := kind == "credits"
	_continue_button.visible = true
	_restart_button.visible = false
	if is_credits:
		_continue_button.text = "重新开始"
	else:
		_continue_button.text = "继续"


func _on_continue_pressed() -> void:
	if _steps.is_empty():
		_finish("restart")
		return
	var kind := str(_steps[_step_index].get("kind", ""))
	if kind == "credits":
		_finish("restart")
		return
	if _step_index >= _steps.size() - 1:
		_finish("restart")
		return
	_step_index += 1
	_show_step()


func _on_restart_pressed() -> void:
	_finish("restart")


func _finish(action: String) -> void:
	if not GameState.is_story_complete():
		EndingDirector.finalize_ending(_ending_id)
	close_panel()
	finished.emit(action)


func _build_shell() -> void:
	set_anchors_preset(Control.PRESET_FULL_RECT)
	offset_left = 0.0
	offset_top = 0.0
	offset_right = 0.0
	offset_bottom = 0.0

	var dim := ColorRect.new()
	dim.set_anchors_preset(Control.PRESET_FULL_RECT)
	dim.color = Color(0.03, 0.03, 0.06, 0.72)
	dim.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(dim)

	var center := CenterContainer.new()
	center.set_anchors_preset(Control.PRESET_FULL_RECT)
	add_child(center)

	var card := PanelContainer.new()
	card.custom_minimum_size = Vector2(760, 440)
	var card_style := StyleBoxFlat.new()
	card_style.bg_color = Color(0.97, 0.94, 0.9, 0.98)
	card_style.border_color = Color(0.72, 0.58, 0.42, 0.55)
	card_style.set_border_width_all(2)
	card_style.set_corner_radius_all(16)
	card_style.content_margin_left = 20
	card_style.content_margin_top = 16
	card_style.content_margin_right = 20
	card_style.content_margin_bottom = 16
	card.add_theme_stylebox_override("panel", card_style)
	center.add_child(card)

	var vbox := VBoxContainer.new()
	vbox.add_theme_constant_override("separation", 12)
	card.add_child(vbox)

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
	_body_label.custom_minimum_size = Vector2(680, 240)
	_body_label.fit_content = true
	_body_label.scroll_active = true
	_body_label.add_theme_font_size_override("normal_font_size", FONT_BODY)
	_body_label.add_theme_color_override("default_color", Color(0.28, 0.22, 0.18))
	vbox.add_child(_body_label)

	var buttons := HBoxContainer.new()
	buttons.alignment = BoxContainer.ALIGNMENT_CENTER
	buttons.add_theme_constant_override("separation", 16)
	vbox.add_child(buttons)

	_restart_button = Button.new()
	_restart_button.text = "重新开始"
	_restart_button.add_theme_font_size_override("font_size", FONT_BUTTON)
	buttons.add_child(_restart_button)

	_continue_button = Button.new()
	_continue_button.text = "继续"
	_continue_button.add_theme_font_size_override("font_size", FONT_BUTTON)
	buttons.add_child(_continue_button)

	var panel_style := StyleBoxFlat.new()
	panel_style.bg_color = Color(0.08, 0.07, 0.1, 0.55)
	add_theme_stylebox_override("panel", panel_style)
