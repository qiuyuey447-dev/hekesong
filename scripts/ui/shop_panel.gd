extends PanelContainer

signal closed

const ICON_SIZE := 72
const FONT_TITLE := 42
const FONT_COINS := 30
const FONT_SECTION := 30
const FONT_NAME := 27
const FONT_BODY := 21
const FONT_BUTTON := 27
const FONT_MESSAGE := 24

var _coins_label: Label
var _buy_list: VBoxContainer
var _sell_list: VBoxContainer
var _message_label: Label
var _quantity_panel: PanelContainer
var _quantity_spin: SpinBox
var _quantity_item_label: Label
var _pending_buy_item_id: String = ""
var _panel_style: StyleBoxFlat
var _row_style: StyleBoxFlat
var _icon_bg_style: StyleBoxFlat
var _button_style: StyleBoxFlat
var _button_hover_style: StyleBoxFlat


func _ready() -> void:
	visible = false
	_build_styles()
	_build_shell()
	_build_shop_rows()
	_build_sell_rows()
	_build_quantity_prompt()
	GameState.stats_changed.connect(refresh)


func open() -> void:
	visible = true
	refresh()


func close() -> void:
	_hide_quantity_prompt()
	visible = false
	closed.emit()


func refresh() -> void:
	_coins_label.text = "金币：%d" % GameState.coins
	_refresh_buy_rows()
	_refresh_sell_rows()


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
	offset_top = -310.0
	offset_right = 430.0
	offset_bottom = 310.0

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
	title.text = "乡村杂货铺"
	title.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	title.add_theme_font_size_override("font_size", FONT_TITLE)
	title.add_theme_color_override("font_color", Color(0.42, 0.3, 0.18))
	root.add_child(title)

	_coins_label = Label.new()
	_coins_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	_coins_label.add_theme_font_size_override("font_size", FONT_COINS)
	_coins_label.add_theme_color_override("font_color", Color(0.72, 0.52, 0.12))
	root.add_child(_coins_label)

	var scroll := ScrollContainer.new()
	scroll.custom_minimum_size = Vector2(0, 430)
	scroll.size_flags_vertical = Control.SIZE_EXPAND_FILL
	scroll.horizontal_scroll_mode = ScrollContainer.SCROLL_MODE_DISABLED
	root.add_child(scroll)

	var scroll_body := VBoxContainer.new()
	scroll_body.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	scroll_body.add_theme_constant_override("separation", 14)
	scroll.add_child(scroll_body)

	_add_section_title(scroll_body, "购买")
	_buy_list = VBoxContainer.new()
	_buy_list.add_theme_constant_override("separation", 12)
	scroll_body.add_child(_buy_list)

	_add_section_title(scroll_body, "出售")
	_sell_list = VBoxContainer.new()
	_sell_list.add_theme_constant_override("separation", 12)
	scroll_body.add_child(_sell_list)

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


	close_button.pressed.connect(close)
	root.add_child(close_button)


func _build_quantity_prompt() -> void:
	_quantity_panel = PanelContainer.new()
	_quantity_panel.visible = false
	_quantity_panel.mouse_filter = Control.MOUSE_FILTER_STOP
	var prompt_style := StyleBoxFlat.new()
	prompt_style.bg_color = Color(0.12, 0.1, 0.08, 0.55)
	prompt_style.set_corner_radius_all(24)
	_quantity_panel.add_theme_stylebox_override("panel", prompt_style)
	_quantity_panel.anchors_preset = Control.PRESET_FULL_RECT
	add_child(_quantity_panel)

	var center := CenterContainer.new()
	center.anchors_preset = Control.PRESET_FULL_RECT
	_quantity_panel.add_child(center)

	var card := PanelContainer.new()
	card.add_theme_stylebox_override("panel", _panel_style.duplicate())
	card.custom_minimum_size = Vector2(360, 0)
	center.add_child(card)

	var margin := MarginContainer.new()
	margin.add_theme_constant_override("margin_left", 20)
	margin.add_theme_constant_override("margin_top", 18)
	margin.add_theme_constant_override("margin_right", 20)
	margin.add_theme_constant_override("margin_bottom", 18)
	card.add_child(margin)

	var body := VBoxContainer.new()
	body.add_theme_constant_override("separation", 12)
	margin.add_child(body)

	var title := Label.new()
	title.text = "购买数量"
	title.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	title.add_theme_font_size_override("font_size", FONT_SECTION)
	body.add_child(title)

	_quantity_item_label = Label.new()
	_quantity_item_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	_quantity_item_label.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	_quantity_item_label.add_theme_font_size_override("font_size", FONT_BODY)
	body.add_child(_quantity_item_label)

	_quantity_spin = SpinBox.new()
	_quantity_spin.min_value = 1
	_quantity_spin.max_value = 99
	_quantity_spin.value = 1
	_quantity_spin.custom_minimum_size = Vector2(0, 42)
	body.add_child(_quantity_spin)

	var row := HBoxContainer.new()
	row.add_theme_constant_override("separation", 10)
	var confirm := Button.new()
	confirm.text = "确认购买"
	confirm.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	_style_button(confirm)
	confirm.pressed.connect(_on_quantity_confirm_pressed)
	row.add_child(confirm)
	var cancel := Button.new()
	cancel.text = "取消"
	cancel.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	_style_button(cancel)
	cancel.pressed.connect(_hide_quantity_prompt)
	row.add_child(cancel)
	body.add_child(row)


func _add_section_title(parent: VBoxContainer, text: String) -> void:
	var label := Label.new()
	label.text = text
	label.add_theme_font_size_override("font_size", FONT_SECTION)
	label.add_theme_color_override("font_color", Color(0.45, 0.34, 0.22))
	parent.add_child(label)


func _build_shop_rows() -> void:
	for item in ShopCatalog.SHOP_ITEMS:
		_buy_list.add_child(_make_buy_row(item))


func _build_sell_rows() -> void:
	for item in ShopCatalog.SELL_ITEMS:
		_sell_list.add_child(_make_sell_row(item))


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
	icon.size_flags_horizontal = Control.SIZE_SHRINK_CENTER
	icon.size_flags_vertical = Control.SIZE_SHRINK_CENTER
	icon.texture_filter = CanvasItem.TEXTURE_FILTER_NEAREST
	icon.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
	icon.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	icon.texture = ShopCatalog.get_item_icon(item)
	center.add_child(icon)
	return box


func _make_buy_row(item: Dictionary) -> PanelContainer:
	var card := _make_row_card()
	var row := HBoxContainer.new()
	row.add_theme_constant_override("separation", 16)
	card.add_child(row)

	row.add_child(_make_icon_box(item))

	var info := VBoxContainer.new()
	info.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	info.add_theme_constant_override("separation", 4)

	var name_label := Label.new()
	name_label.add_theme_font_size_override("font_size", FONT_NAME)
	name_label.add_theme_color_override("font_color", Color(0.32, 0.24, 0.16))
	name_label.set_meta("item_id", str(item.get("id", "")))
	info.add_child(name_label)
	card.set_meta("name_label", name_label)

	var desc_label := Label.new()
	desc_label.text = str(item.get("desc", ""))
	desc_label.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	desc_label.add_theme_font_size_override("font_size", FONT_BODY)
	desc_label.add_theme_color_override("font_color", Color(0.42, 0.38, 0.34))
	info.add_child(desc_label)
	row.add_child(info)

	var button := Button.new()
	button.text = "购买"
	button.custom_minimum_size = Vector2(108, 52)
	button.set_meta("item_id", str(item.get("id", "")))
	button.set_meta("buy_price", int(item.get("buy_price", 0)))
	_style_button(button)
	button.pressed.connect(func() -> void:
		_on_buy_pressed(str(button.get_meta("item_id")))
	)
	row.add_child(button)
	card.set_meta("buy_button", button)
	return card


func _make_sell_row(item: Dictionary) -> PanelContainer:
	var card := _make_row_card()
	var row := HBoxContainer.new()
	row.add_theme_constant_override("separation", 16)
	card.add_child(row)

	row.add_child(_make_icon_box(item))

	var info := VBoxContainer.new()
	info.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	info.add_theme_constant_override("separation", 4)

	var name_label := Label.new()
	name_label.text = "%s  ·  %d 金币/个" % [str(item.get("name", "")), int(item.get("sell_price", 0))]
	name_label.add_theme_font_size_override("font_size", FONT_NAME)
	name_label.add_theme_color_override("font_color", Color(0.32, 0.24, 0.16))
	info.add_child(name_label)
	card.set_meta("name_label", name_label)

	var count_label := Label.new()
	count_label.add_theme_font_size_override("font_size", FONT_BODY)
	count_label.add_theme_color_override("font_color", Color(0.42, 0.38, 0.34))
	count_label.set_meta("inventory_key", str(item.get("inventory_key", "")))
	info.add_child(count_label)
	card.set_meta("count_label", count_label)

	var desc_label := Label.new()
	desc_label.text = str(item.get("desc", ""))
	desc_label.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	desc_label.add_theme_font_size_override("font_size", FONT_BODY)
	desc_label.add_theme_color_override("font_color", Color(0.42, 0.38, 0.34))
	info.add_child(desc_label)
	row.add_child(info)

	var button := Button.new()
	button.text = "出售"
	button.custom_minimum_size = Vector2(108, 52)
	button.set_meta("item_id", str(item.get("id", "")))
	_style_button(button)
	button.pressed.connect(func() -> void:
		_on_sell_pressed(str(button.get_meta("item_id")))
	)
	row.add_child(button)
	card.set_meta("sell_button", button)
	return card


func _refresh_buy_rows() -> void:
	for row in _buy_list.get_children():
		if not row is PanelContainer:
			continue
		var name_label := row.get_meta("name_label") as Label
		var button := row.get_meta("buy_button") as Button
		if button == null or name_label == null:
			continue
		var item_id := str(button.get_meta("item_id", ""))
		var item := ShopCatalog.get_shop_item(item_id)
		var price := GameState.get_shop_item_unit_price(item_id)
		name_label.text = "%s  ·  %d 金币/个" % [str(item.get("name", "")), price]
		button.disabled = price <= 0 or not GameState.can_afford(price)


func _refresh_sell_rows() -> void:
	for row in _sell_list.get_children():
		if not row is PanelContainer:
			continue
		var count_label := row.get_meta("count_label") as Label
		var button := row.get_meta("sell_button") as Button
		if count_label == null or button == null:
			continue
		var item_key := str(count_label.get_meta("inventory_key", ""))
		var count := GameState.get_item_count(item_key)
		count_label.text = "背包：%d" % count
		if item_key == "turnip":
			var name_label := row.get_meta("name_label") as Label
			if name_label != null:
				name_label.text = "%s  ·  %d 金币/个" % ["萝卜", GameState.get_turnip_sell_price()]
		button.disabled = count <= 0


func _on_buy_pressed(item_id: String) -> void:
	var item := ShopCatalog.get_shop_item(item_id)
	if item.is_empty():
		_message_label.text = "没有这个商品。"
		return
	_pending_buy_item_id = item_id
	var price := GameState.get_shop_item_unit_price(item_id)
	_quantity_item_label.text = "%s · %d 金币/个" % [str(item.get("name", item_id)), price]
	_quantity_spin.value = 1
	_quantity_panel.visible = true


func _on_quantity_confirm_pressed() -> void:
	if _pending_buy_item_id == "":
		_hide_quantity_prompt()
		return
	var count := int(_quantity_spin.value)
	var result := GameState.buy_shop_item_count(_pending_buy_item_id, count)
	_message_label.text = str(result.get("message", "购买失败。"))
	_hide_quantity_prompt()
	refresh()


func _hide_quantity_prompt() -> void:
	_pending_buy_item_id = ""
	_quantity_panel.visible = false


func _on_sell_pressed(item_id: String) -> void:
	var result := GameState.sell_inventory_item(item_id)
	_message_label.text = result
	refresh()
