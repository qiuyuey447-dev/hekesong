extends PanelContainer
## W1 开场：小狸询问玩家希望如何称呼。

signal confirmed(name: String)

var _name_input: LineEdit
var _confirm_button: Button


func _ready() -> void:
	visible = false
	mouse_filter = Control.MOUSE_FILTER_STOP
	_build_shell()
	_confirm_button.pressed.connect(_on_confirm_pressed)
	_name_input.text_submitted.connect(_on_name_submitted)


func open() -> void:
	_name_input.text = ""
	visible = true
	_name_input.grab_focus()


func close_panel() -> void:
	visible = false


func _on_confirm_pressed() -> void:
	_submit()


func _on_name_submitted(_text: String) -> void:
	_submit()


func _submit() -> void:
	var cleaned := _name_input.text.strip_edges()
	if cleaned.is_empty():
		_name_input.placeholder_text = "写一个字就行"
		_name_input.grab_focus()
		return
	GameState.set_player_display_name(cleaned)
	close_panel()
	confirmed.emit(GameState.player_name)


func _build_shell() -> void:
	set_anchors_preset(Control.PRESET_FULL_RECT)

	var dim := ColorRect.new()
	dim.set_anchors_preset(Control.PRESET_FULL_RECT)
	dim.color = Color(0.04, 0.05, 0.08, 0.42)
	dim.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(dim)

	var center := CenterContainer.new()
	center.set_anchors_preset(Control.PRESET_FULL_RECT)
	add_child(center)

	var card := PanelContainer.new()
	card.custom_minimum_size = Vector2(560, 280)
	var card_style := StyleBoxFlat.new()
	card_style.bg_color = Color(0.98, 0.95, 0.9, 0.98)
	card_style.border_color = Color(0.78, 0.62, 0.44, 0.55)
	card_style.set_border_width_all(2)
	card_style.set_corner_radius_all(16)
	card_style.content_margin_left = 24
	card_style.content_margin_top = 20
	card_style.content_margin_right = 24
	card_style.content_margin_bottom = 20
	card.add_theme_stylebox_override("panel", card_style)
	center.add_child(card)

	var vbox := VBoxContainer.new()
	vbox.add_theme_constant_override("separation", 16)
	card.add_child(vbox)

	var title := Label.new()
	title.text = "%s" % GameState.companion_name
	title.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	title.add_theme_font_size_override("font_size", 28)
	title.add_theme_color_override("font_color", Color(0.32, 0.24, 0.18))
	vbox.add_child(title)

	var body := Label.new()
	body.text = "那……我该怎么称呼你？叫起来别太绕口就行。"
	body.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	body.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	body.add_theme_font_size_override("font_size", 20)
	body.add_theme_color_override("font_color", Color(0.35, 0.28, 0.2))
	vbox.add_child(body)

	var hint := Label.new()
	hint.text = "一个名字就好"
	hint.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	hint.add_theme_font_size_override("font_size", 18)
	hint.add_theme_color_override("font_color", Color(0.5, 0.4, 0.3))
	vbox.add_child(hint)

	_name_input = LineEdit.new()
	_name_input.custom_minimum_size = Vector2(420, 44)
	_name_input.placeholder_text = "写下你的名字"
	_name_input.max_length = 12
	_name_input.alignment = HORIZONTAL_ALIGNMENT_CENTER
	_name_input.add_theme_font_size_override("font_size", 22)
	var input_style := StyleBoxFlat.new()
	input_style.bg_color = Color(1, 0.99, 0.96, 1)
	input_style.border_color = Color(0.75, 0.6, 0.42, 0.6)
	input_style.set_border_width_all(1)
	input_style.set_corner_radius_all(8)
	input_style.content_margin_left = 12
	input_style.content_margin_right = 12
	_name_input.add_theme_stylebox_override("normal", input_style)
	_name_input.add_theme_stylebox_override("focus", input_style.duplicate())
	vbox.add_child(_name_input)

	var row := HBoxContainer.new()
	row.alignment = BoxContainer.ALIGNMENT_CENTER
	vbox.add_child(row)

	_confirm_button = Button.new()
	_confirm_button.text = "叫我这个"
	_confirm_button.add_theme_font_size_override("font_size", 20)
	var button_style := card_style.duplicate()
	button_style.bg_color = Color(0.93, 0.78, 0.52, 1.0)
	var button_hover := button_style.duplicate()
	button_hover.bg_color = Color(0.98, 0.86, 0.62, 1.0)
	_confirm_button.add_theme_stylebox_override("normal", button_style)
	_confirm_button.add_theme_stylebox_override("hover", button_hover)
	_confirm_button.add_theme_stylebox_override("pressed", button_hover)
	row.add_child(_confirm_button)

	var panel_style := StyleBoxFlat.new()
	panel_style.bg_color = Color(0.1, 0.08, 0.12, 0.5)
	add_theme_stylebox_override("panel", panel_style)
