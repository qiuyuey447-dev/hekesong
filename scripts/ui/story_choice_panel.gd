extends PanelContainer
## 主线关键选项：W2 收留 / 夜伴 等。

signal chosen(choice_id: String)

var _title_label: Label
var _body_label: RichTextLabel
var _buttons_row: HBoxContainer
var _choices: Array[Dictionary] = []


func _ready() -> void:
	visible = false
	mouse_filter = Control.MOUSE_FILTER_STOP
	_build_shell()


func open(config: Dictionary) -> void:
	_title_label.text = str(config.get("title", ""))
	_body_label.text = str(config.get("body", ""))
	_choices = []
	var raw: Variant = config.get("choices", [])
	if raw is Array:
		for item in raw:
			if item is Dictionary:
				_choices.append(item)
	_rebuild_buttons()
	visible = true


func close_panel() -> void:
	visible = false


func _rebuild_buttons() -> void:
	for child in _buttons_row.get_children():
		child.queue_free()
	for choice in _choices:
		var button := Button.new()
		button.text = str(choice.get("label", "选择"))
		button.add_theme_font_size_override("font_size", 20)
		var choice_id := str(choice.get("id", ""))
		button.pressed.connect(func() -> void:
			close_panel()
			chosen.emit(choice_id)
		)
		_buttons_row.add_child(button)


func _build_shell() -> void:
	set_anchors_preset(Control.PRESET_FULL_RECT)

	var dim := ColorRect.new()
	dim.set_anchors_preset(Control.PRESET_FULL_RECT)
	dim.color = Color(0.03, 0.03, 0.06, 0.72)
	dim.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(dim)

	var center := CenterContainer.new()
	center.set_anchors_preset(Control.PRESET_FULL_RECT)
	add_child(center)

	var card := PanelContainer.new()
	card.custom_minimum_size = Vector2(720, 360)
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
	vbox.add_theme_constant_override("separation", 14)
	card.add_child(vbox)

	_title_label = Label.new()
	_title_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	_title_label.add_theme_font_size_override("font_size", 28)
	_title_label.add_theme_color_override("font_color", Color(0.32, 0.24, 0.18))
	vbox.add_child(_title_label)

	_body_label = RichTextLabel.new()
	_body_label.custom_minimum_size = Vector2(640, 180)
	_body_label.fit_content = true
	_body_label.scroll_active = true
	_body_label.add_theme_font_size_override("normal_font_size", 20)
	_body_label.add_theme_color_override("default_color", Color(0.28, 0.22, 0.18))
	vbox.add_child(_body_label)

	_buttons_row = HBoxContainer.new()
	_buttons_row.alignment = BoxContainer.ALIGNMENT_CENTER
	_buttons_row.add_theme_constant_override("separation", 16)
	vbox.add_child(_buttons_row)

	var panel_style := StyleBoxFlat.new()
	panel_style.bg_color = Color(0.08, 0.07, 0.1, 0.55)
	add_theme_stylebox_override("panel", panel_style)
