extends PanelContainer

signal closed
signal feed_requested(item_id: String)

const ICON_SIZE := 72
const FONT_TITLE := 42
const FONT_HINT := 21
const FONT_NAME := 27
const FONT_BODY := 21
const FONT_BUTTON := 27
const FONT_MESSAGE := 24

var _list: VBoxContainer
var _hint_label: Label
var _message_label: Label
var _panel_style: StyleBoxFlat
var _row_style: StyleBoxFlat
var _icon_bg_style: StyleBoxFlat
var _button_style: StyleBoxFlat
var _button_hover_style: StyleBoxFlat


func _ready() -> void:
	visible = false
	_build_styles()
	_build_shell()
	GameState.stats_changed.connect(rebuild)


func open() -> void:
	rebuild()
	visible = true


func close() -> void:
	visible = false
	closed.emit()


func set_status_message(text: String) -> void:
	if _message_label:
		_message_label.text = text


func rebuild() -> void:
	for child in _list.get_children():
		child.queue_free()

	if _hint_label:
		if GameState.has_fed_today():
			_hint_label.text = "今天已经投喂过了。小狸每天只吃一份零食哦。"
		else:
			_hint_label.text = "每天只能投喂一次；选择零食送给小狸，提升亲密度和心情。"

	var treats := GameState.get_owned_treats()
	if treats.is_empty():
		var empty_card := _make_row_card()
		var empty := Label.new()
		empty.text = "背包里没有零食，去商店买点吧。"
		empty.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
		empty.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
		empty.add_theme_font_size_override("font_size", FONT_BODY)
		empty.add_theme_color_override("font_color", Color(0.42, 0.38, 0.34))
		empty_card.add_child(empty)
		_list.add_child(empty_card)
		return

	for item in treats:
		_list.add_child(_make_feed_row(item))


func _build_styles() -> void:
	_panel_style = StyleBoxFlat.new()
	_panel_style.bg_color = Color(0.99, 0.96, 0.9, 0.97)
	_panel_style.border_color = Color(0.82, 0.68, 0.48, 0.65)
	_panel_style.set_border_width_all(2)
	_panel_style.set_corner_radius_all(28)
	_panel_style.content_margin_left = 8
	_panel_style.content_margin_top = 8
	_panel_style.content_margin_right = 8
	_panel_style.content_margin_bottom = 8
	_panel_style.shadow_color = Color(0, 0, 0, 0.14)
	_panel_style.shadow_size = 10
	_panel_style.shadow_offset = Vector2(0, 4)
	add_theme_stylebox_override("panel", _panel_style)

	_row_style = StyleBoxFlat.new()
	_row_style.bg_color = Color(1.0, 0.98, 0.94, 0.96)
	_row_style.border_color = Color(0.88, 0.76, 0.56, 0.45)
	_row_style.set_border_width_all(1)
	_row_style.set_corner_radius_all(20)
	_row_style.content_margin_left = 14
	_row_style.content_margin_top = 12
	_row_style.content_margin_right = 14
	_row_style.content_margin_bottom = 12

	_icon_bg_style = StyleBoxFlat.new()
	_icon_bg_style.bg_color = Color(0.96, 0.91, 0.82, 1.0)
	_icon_bg_style.border_color = Color(0.86, 0.74, 0.54, 0.35)
	_icon_bg_style.set_border_width_all(1)
	_icon_bg_style.set_corner_radius_all(18)
	_icon_bg_style.content_margin_left = 10
	_icon_bg_style.content_margin_top = 10
	_icon_bg_style.content_margin_right = 10
	_icon_bg_style.content_margin_bottom = 10

	_button_style = StyleBoxFlat.new()
	_button_style.bg_color = Color(0.95, 0.8, 0.52, 1.0)
	_button_style.border_color = Color(0.7, 0.54, 0.32, 0.9)
	_button_style.set_border_width_all(2)
	_button_style.set_corner_radius_all(18)
	_button_style.content_margin_left = 16
	_button_style.content_margin_top = 8
	_button_style.content_margin_right = 16
	_button_style.content_margin_bottom = 8

	_button_hover_style = _button_style.duplicate()
	_button_hover_style.bg_color = Color(1.0, 0.9, 0.66, 1.0)


func _style_button(button: Button) -> void:
	button.add_theme_stylebox_override("normal", _button_style)
	button.add_theme_stylebox_override("hover", _button_hover_style)
	button.add_theme_stylebox_override("pressed", _button_hover_style)
	button.add_theme_stylebox_override("disabled", _button_style.duplicate())
	button.add_theme_font_size_override("font_size", FONT_BUTTON)


func _build_shell() -> void:
	anchors_preset = Control.PRESET_CENTER
	offset_left = -430.0
	offset_top = -280.0
	offset_right = 430.0
	offset_bottom = 280.0

	var margin := MarginContainer.new()
	margin.add_theme_constant_override("margin_left", 22)
	margin.add_theme_constant_override("margin_top", 20)
	margin.add_theme_constant_override("margin_right", 22)
	margin.add_theme_constant_override("margin_bottom", 20)
	add_child(margin)

	var root := VBoxContainer.new()
	root.add_theme_constant_override("separation", 14)
	margin.add_child(root)

	var title := Label.new()
	title.text = "投喂小狸"
	title.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	title.add_theme_font_size_override("font_size", FONT_TITLE)
	title.add_theme_color_override("font_color", Color(0.42, 0.3, 0.18))
	root.add_child(title)

	_hint_label = Label.new()
	_hint_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	_hint_label.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	_hint_label.add_theme_font_size_override("font_size", FONT_HINT)
	_hint_label.add_theme_color_override("font_color", Color(0.45, 0.38, 0.32))
	root.add_child(_hint_label)

	var scroll := ScrollContainer.new()
	scroll.custom_minimum_size = Vector2(0, 360)
	scroll.size_flags_vertical = Control.SIZE_EXPAND_FILL
	scroll.horizontal_scroll_mode = ScrollContainer.SCROLL_MODE_DISABLED
	root.add_child(scroll)

	_list = VBoxContainer.new()
	_list.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	_list.add_theme_constant_override("separation", 12)
	scroll.add_child(_list)

	_message_label = Label.new()
	_message_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	_message_label.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	_message_label.add_theme_font_size_override("font_size", FONT_MESSAGE)
	_message_label.add_theme_color_override("font_color", Color(0.4, 0.48, 0.36))
	root.add_child(_message_label)

	var close_button := Button.new()
	close_button.text = "关闭"
	close_button.custom_minimum_size = Vector2(0, 52)
	_style_button(close_button)
	close_button.pressed.connect(close)
	root.add_child(close_button)


func _make_row_card() -> PanelContainer:
	var card := PanelContainer.new()
	card.add_theme_stylebox_override("panel", _row_style.duplicate())
	return card


func _make_icon_box(item: Dictionary) -> PanelContainer:
	var box := PanelContainer.new()
	box.custom_minimum_size = Vector2(ICON_SIZE + 20, ICON_SIZE + 20)
	box.add_theme_stylebox_override("panel", _icon_bg_style.duplicate())

	var center := CenterContainer.new()
	center.custom_minimum_size = Vector2(ICON_SIZE + 20, ICON_SIZE + 20)
	box.add_child(center)

	var icon := TextureRect.new()
	icon.custom_minimum_size = Vector2(ICON_SIZE, ICON_SIZE)
	icon.texture_filter = CanvasItem.TEXTURE_FILTER_NEAREST
	icon.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
	icon.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	icon.texture = ShopCatalog.get_item_icon(item)
	center.add_child(icon)
	return box


func _make_feed_row(item: Dictionary) -> PanelContainer:
	var card := _make_row_card()
	var row := HBoxContainer.new()
	row.add_theme_constant_override("separation", 16)
	card.add_child(row)

	row.add_child(_make_icon_box(item))

	var info := VBoxContainer.new()
	info.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	info.add_theme_constant_override("separation", 4)

	var item_key := str(item.get("inventory_key", ""))
	var name_label := Label.new()
	name_label.text = "%s  x%d" % [str(item.get("name", "")), GameState.get_item_count(item_key)]
	name_label.add_theme_font_size_override("font_size", FONT_NAME)
	name_label.add_theme_color_override("font_color", Color(0.32, 0.24, 0.16))
	info.add_child(name_label)

	var effect_label := Label.new()
	effect_label.text = "亲密度+%d  心情+%d  默契+%d" % [
		int(item.get("affection", 0)),
		int(item.get("mood", 0)),
		int(item.get("bond", 0)),
	]
	effect_label.add_theme_font_size_override("font_size", FONT_BODY)
	effect_label.add_theme_color_override("font_color", Color(0.42, 0.38, 0.34))
	info.add_child(effect_label)
	row.add_child(info)

	var button := Button.new()
	button.text = "投喂"
	button.custom_minimum_size = Vector2(108, 52)
	_style_button(button)
	button.pressed.connect(func() -> void:
		var item_id := str(item.get("id", ""))
		_message_label.text = "小狸正看着零食…"
		feed_requested.emit(item_id)
	)
	row.add_child(button)
	return card
