extends PanelContainer

signal closed

const FONT_TITLE := 40
const FONT_BODY := 22
const FONT_BUTTON := 24

var _weather_label: Label
var _price_label: Label
var _hint_label: Label
var _seed_count_label: Label
var _turnip_count_label: Label
var _message_label: Label


func _ready() -> void:
	visible = false
	_build_styles()
	_build_shell()
	GameState.stats_changed.connect(refresh)
	GameState.market_changed.connect(refresh)


func open() -> void:
	visible = true
	refresh()


func close() -> void:
	visible = false
	closed.emit()


func refresh() -> void:
	var market := GameState.get_market_snapshot()
	_weather_label.text = "今日：%s · %s    明日：%s" % [
		market.get("weather_label", ""),
		market.get("time_label", ""),
		market.get("weather_tomorrow_label", ""),
	]
	_price_label.text = "萝卜种子：%d 金    萝卜收购：%d 金    走势：%s" % [
		int(market.get("turnip_seed_price", 0)),
		int(market.get("turnip_sell_price", 0)),
		_trend_label(str(market.get("trend", "stable"))),
	]
	_hint_label.text = GameState.get_weather_effect_text()
	_seed_count_label.text = "背包萝卜种子：%d" % GameState.get_item_count("turnip_seed")
	_turnip_count_label.text = "背包萝卜：%d" % GameState.get_item_count("turnip")


func _trend_label(trend: String) -> String:
	match trend:
		"up":
			return "上扬"
		"surge":
			return "冲高"
		"volatile":
			return "震荡"
		_:
			return "平稳"


func _build_styles() -> void:
	var panel_style := StyleBoxFlat.new()
	panel_style.bg_color = Color(0.99, 0.96, 0.9, 0.97)
	panel_style.border_color = Color(0.82, 0.68, 0.48, 0.65)
	panel_style.set_border_width_all(2)
	panel_style.set_corner_radius_all(28)
	panel_style.content_margin_left = 8
	panel_style.content_margin_top = 8
	panel_style.content_margin_right = 8
	panel_style.content_margin_bottom = 8
	panel_style.shadow_color = Color(0, 0, 0, 0.14)
	panel_style.shadow_size = 10
	panel_style.shadow_offset = Vector2(0, 4)
	add_theme_stylebox_override("panel", panel_style)


func _build_shell() -> void:
	anchors_preset = Control.PRESET_CENTER
	offset_left = -430.0
	offset_top = -260.0
	offset_right = 430.0
	offset_bottom = 260.0

	var margin := MarginContainer.new()
	margin.add_theme_constant_override("margin_left", 24)
	margin.add_theme_constant_override("margin_top", 20)
	margin.add_theme_constant_override("margin_right", 24)
	margin.add_theme_constant_override("margin_bottom", 20)
	add_child(margin)

	var root := VBoxContainer.new()
	root.add_theme_constant_override("separation", 14)
	margin.add_child(root)

	var title := Label.new()
	title.text = "农田大盘"
	title.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	title.add_theme_font_size_override("font_size", FONT_TITLE)
	title.add_theme_color_override("font_color", Color(0.42, 0.3, 0.18))
	root.add_child(title)

	_weather_label = _make_body_label(true)
	root.add_child(_weather_label)

	_price_label = _make_body_label(true)
	root.add_child(_price_label)

	_hint_label = _make_body_label(false)
	root.add_child(_hint_label)

	var counts := HBoxContainer.new()
	counts.alignment = BoxContainer.ALIGNMENT_CENTER
	counts.add_theme_constant_override("separation", 24)
	root.add_child(counts)

	_seed_count_label = _make_body_label(false)
	counts.add_child(_seed_count_label)
	_turnip_count_label = _make_body_label(false)
	counts.add_child(_turnip_count_label)

	var buttons := HBoxContainer.new()
	buttons.alignment = BoxContainer.ALIGNMENT_CENTER
	buttons.add_theme_constant_override("separation", 14)
	root.add_child(buttons)

	var buy_button := _make_button("买 1 包萝卜种子")
	buy_button.pressed.connect(func() -> void:
		_message_label.text = GameState.buy_shop_item("turnip_seed")
		refresh()
	)
	buttons.add_child(buy_button)

	var sell_button := _make_button("卖 1 个萝卜")
	sell_button.pressed.connect(func() -> void:
		_message_label.text = GameState.sell_inventory_item("turnip")
		refresh()
	)
	buttons.add_child(sell_button)

	_message_label = _make_body_label(false)
	_message_label.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	root.add_child(_message_label)

	var close_button := _make_button("关闭")
	close_button.pressed.connect(close)
	root.add_child(close_button)


func _make_body_label(centered: bool) -> Label:
	var label := Label.new()
	label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER if centered else HORIZONTAL_ALIGNMENT_LEFT
	label.add_theme_font_size_override("font_size", FONT_BODY)
	label.add_theme_color_override("font_color", Color(0.42, 0.38, 0.34))
	return label


func _make_button(text: String) -> Button:
	var button := Button.new()
	button.text = text
	button.custom_minimum_size = Vector2(0, 50)
	button.add_theme_font_size_override("font_size", FONT_BUTTON)
	var style := StyleBoxFlat.new()
	style.bg_color = Color(0.95, 0.8, 0.52, 1.0)
	style.border_color = Color(0.7, 0.54, 0.32, 0.9)
	style.set_border_width_all(2)
	style.set_corner_radius_all(18)
	style.content_margin_left = 16
	style.content_margin_top = 8
	style.content_margin_right = 16
	style.content_margin_bottom = 8
	var hover := style.duplicate()
	hover.bg_color = Color(1.0, 0.9, 0.66, 1.0)
	button.add_theme_stylebox_override("normal", style)
	button.add_theme_stylebox_override("hover", hover)
	button.add_theme_stylebox_override("pressed", hover)
	return button
