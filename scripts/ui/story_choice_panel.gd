extends PanelContainer
## 主线关键选项：W2 收留 / 夜伴 / 本子划页。铺满屏幕居中，勿贴左上角。

signal chosen(choice_id: String)

var _dim: ColorRect
var _center: CenterContainer
var _title_label: Label
var _body_label: RichTextLabel
var _buttons_row: HBoxContainer
var _choices: Array[Dictionary] = []


func _ready() -> void:
	visible = false
	mouse_filter = Control.MOUSE_FILTER_IGNORE
	_build_shell()
	_sync_viewport_layout()
	if not get_viewport().size_changed.is_connected(_sync_viewport_layout):
		get_viewport().size_changed.connect(_sync_viewport_layout)


func open(config: Dictionary) -> void:
	_sync_viewport_layout()
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
	show()
	move_to_front()
	mouse_filter = Control.MOUSE_FILTER_STOP


func close_panel() -> void:
	visible = false
	mouse_filter = Control.MOUSE_FILTER_IGNORE


func _rebuild_buttons() -> void:
	for child in _buttons_row.get_children():
		child.queue_free()
	for choice in _choices:
		var button := Button.new()
		button.text = str(choice.get("label", "选择"))
		button.add_theme_font_size_override("font_size", 20)
		button.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		button.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
		button.custom_minimum_size = Vector2(240, 64)
		var choice_id := str(choice.get("id", ""))
		button.pressed.connect(func() -> void:
			close_panel()
			chosen.emit(choice_id)
		)
		_buttons_row.add_child(button)


func _build_shell() -> void:
	set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	grow_horizontal = Control.GROW_DIRECTION_BOTH
	grow_vertical = Control.GROW_DIRECTION_BOTH
	z_index = 80
	z_as_relative = false
	add_theme_stylebox_override("panel", StyleBoxEmpty.new())

	_dim = ColorRect.new()
	_dim.name = "Dim"
	_dim.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	_dim.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	_dim.size_flags_vertical = Control.SIZE_EXPAND_FILL
	_dim.color = Color(0.03, 0.03, 0.06, 0.72)
	_dim.mouse_filter = Control.MOUSE_FILTER_STOP
	add_child(_dim)

	_center = CenterContainer.new()
	_center.name = "Center"
	_center.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	_center.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	_center.size_flags_vertical = Control.SIZE_EXPAND_FILL
	_center.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(_center)

	var card := PanelContainer.new()
	card.name = "Card"
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
	_center.add_child(card)

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


func _sync_viewport_layout() -> void:
	set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	grow_horizontal = Control.GROW_DIRECTION_BOTH
	grow_vertical = Control.GROW_DIRECTION_BOTH
	var vp := get_viewport()
	if vp:
		size = vp.get_visible_rect().size
	if _dim != null:
		_dim.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
		_dim.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		_dim.size_flags_vertical = Control.SIZE_EXPAND_FILL
	if _center != null:
		_center.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
		_center.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		_center.size_flags_vertical = Control.SIZE_EXPAND_FILL
