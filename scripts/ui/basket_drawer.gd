extends Control
class_name BasketDrawer
## 左上「口袋篮子」：像随手翻开的藤编小筐，不是系统背包菜单。
## 根节点必须是 Control（不能用 PanelContainer），否则子节点锚点会被容器覆写。

signal shop_requested
signal market_requested
signal memory_requested
signal sleep_requested
signal main_menu_requested
signal exit_game_requested
signal closed

const DRAWER_WIDTH := 368.0
const CONTENT_MARGIN_H := 12
const CONTENT_MARGIN_TOP := 92
const SLIDE_SEC := 0.28
const ARM_CLOSE_DELAY := 0.45

## 四阶段小苗（按亲密度）。只长样子，不写提示词。
const SPROUT_STAGES := [
	{"min": 0, "height": 8},
	{"min": 20, "height": 18},
	{"min": 40, "height": 28},
	{"min": 60, "height": 36},
]

var _dim: ColorRect
var _panel: PanelContainer
var _coin_value: Label
var _seed_value: Label
var _turnip_value: Label
var _treat_value: Label
var _weather_value: Label
var _tomorrow_value: Label
var _farm_value: Label
var _market_value: Label
var _market_sub: Label
var _plot_dots: HBoxContainer
var _sleep_button: Button
var _shop_button: Button
var _market_button: Button
var _memory_button: Button
var _close_button: Button
var _main_menu_button: Button
var _exit_game_button: Button
var _bgm_slider: HSlider
var _ambient_slider: HSlider
var _title_label: Label
var _day_chip: Label
var _open: bool = false
var _slide_tween: Tween = null
var _close_armed: bool = false


func _ready() -> void:
	visible = false
	mouse_filter = Control.MOUSE_FILTER_IGNORE
	set_anchors_preset(Control.PRESET_FULL_RECT)
	set_offsets_preset(Control.PRESET_FULL_RECT)
	_build()
	_apply_fonts()
	refresh()


func is_open() -> bool:
	return _open


func open_drawer() -> void:
	if _open:
		return
	refresh()
	_open = true
	_close_armed = false
	visible = true
	mouse_filter = Control.MOUSE_FILTER_STOP
	move_to_front()

	if _slide_tween != null and _slide_tween.is_valid():
		_slide_tween.kill()

	_dim.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_dim.modulate.a = 0.0
	# 从屏幕左侧滑入。
	_panel.offset_left = -DRAWER_WIDTH
	_panel.offset_right = 0.0

	_slide_tween = create_tween()
	_slide_tween.set_parallel(true)
	_slide_tween.tween_property(_dim, "modulate:a", 1.0, SLIDE_SEC)
	_slide_tween.tween_property(_panel, "offset_left", 0.0, SLIDE_SEC).set_trans(Tween.TRANS_CUBIC).set_ease(Tween.EASE_OUT)
	_slide_tween.tween_property(_panel, "offset_right", DRAWER_WIDTH, SLIDE_SEC).set_trans(Tween.TRANS_CUBIC).set_ease(Tween.EASE_OUT)

	var tree := get_tree()
	if tree:
		tree.create_timer(ARM_CLOSE_DELAY).timeout.connect(_arm_dim_close, CONNECT_ONE_SHOT)


func close_drawer() -> void:
	if not _open:
		return
	_open = false
	_close_armed = false
	_dim.mouse_filter = Control.MOUSE_FILTER_IGNORE

	if _slide_tween != null and _slide_tween.is_valid():
		_slide_tween.kill()

	_slide_tween = create_tween()
	_slide_tween.set_parallel(true)
	_slide_tween.tween_property(_dim, "modulate:a", 0.0, SLIDE_SEC * 0.85)
	_slide_tween.tween_property(_panel, "offset_left", -DRAWER_WIDTH, SLIDE_SEC * 0.85).set_trans(Tween.TRANS_CUBIC).set_ease(Tween.EASE_IN)
	_slide_tween.tween_property(_panel, "offset_right", 0.0, SLIDE_SEC * 0.85).set_trans(Tween.TRANS_CUBIC).set_ease(Tween.EASE_IN)
	_slide_tween.finished.connect(func() -> void:
		if _open:
			return
		visible = false
		mouse_filter = Control.MOUSE_FILTER_IGNORE
		closed.emit()
	, CONNECT_ONE_SHOT)


func toggle_drawer() -> void:
	if _open:
		close_drawer()
	else:
		open_drawer()


func _arm_dim_close() -> void:
	if not _open:
		return
	_dim.mouse_filter = Control.MOUSE_FILTER_STOP
	_close_armed = true


func _on_dim_gui_input(event: InputEvent) -> void:
	if not _open or not _close_armed:
		return
	if event is InputEventMouseButton and event.pressed and event.button_index == MOUSE_BUTTON_LEFT:
		close_drawer()
		accept_event()


func refresh() -> void:
	if _coin_value == null:
		return
	_coin_value.text = str(GameState.coins)
	_seed_value.text = str(GameState.get_item_count("turnip_seed"))
	_turnip_value.text = str(GameState.get_item_count("turnip"))
	_treat_value.text = str(_count_treats())
	if GameState.is_awaiting_sleep() or GameState.can_manual_sleep():
		_sleep_button.text = "立马睡觉" if GameState.is_awaiting_sleep() else "睡觉"
		_sleep_button.disabled = false
	else:
		_sleep_button.text = "天还亮着"
		_sleep_button.disabled = true
	if _day_chip:
		_day_chip.text = GameState.get_day_period_label()
	if _bgm_slider:
		_bgm_slider.set_value_no_signal(GameState.bgm_volume_linear)
	if _ambient_slider:
		_ambient_slider.set_value_no_signal(GameState.ambient_volume_linear)
	_refresh_today()


func get_sprout_tier() -> int:
	var aff := GameState.affection
	var tier := 0
	for i in range(SPROUT_STAGES.size()):
		if aff >= int(SPROUT_STAGES[i]["min"]):
			tier = i
	return tier


func get_sprout_word() -> String:
	## 保留给清晨侧写等内部用；界面不再展示。
	match get_sprout_tier():
		0:
			return "还在熟悉"
		1:
			return "慢慢亲近"
		2:
			return "处得像家人"
		_:
			return "心照不宣"


func get_morning_sidewrite_fallback() -> String:
	match get_sprout_tier():
		0:
			return "……你还在。今天也在田边。"
		1:
			return "早上看到田里的苗，忽然觉得——我们好像比昨天更近一点了。"
		2:
			return "醒来第一件事是找你。找到了。"
		_:
			return "不用多说。你在，我就在。今天也一起过。"


static func sprout_tier_for_affection(affection: int) -> int:
	var tier := 0
	for i in range(SPROUT_STAGES.size()):
		if affection >= int(SPROUT_STAGES[i]["min"]):
			tier = i
	return tier


func _count_treats() -> int:
	var total := 0
	for item in ShopCatalog.get_treat_items():
		total += GameState.get_item_count(str(item.get("inventory_key", "")))
	return total


func _build() -> void:
	_dim = ColorRect.new()
	_dim.name = "Dim"
	_dim.set_anchors_preset(Control.PRESET_FULL_RECT)
	_dim.set_offsets_preset(Control.PRESET_FULL_RECT)
	_dim.color = Color(0.12, 0.08, 0.04, 0.34)
	_dim.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_dim.gui_input.connect(_on_dim_gui_input)
	add_child(_dim)

	_panel = PanelContainer.new()
	_panel.name = "Panel"
	_panel.mouse_filter = Control.MOUSE_FILTER_STOP
	_panel.anchor_left = 0.0
	_panel.anchor_right = 0.0
	_panel.anchor_top = 0.0
	_panel.anchor_bottom = 1.0
	_panel.offset_left = -DRAWER_WIDTH
	_panel.offset_right = 0.0
	_panel.offset_top = 0.0
	_panel.offset_bottom = 0.0
	_panel.custom_minimum_size = Vector2(DRAWER_WIDTH, 0)
	_panel.add_theme_stylebox_override("panel", _drawer_style())
	add_child(_panel)

	var margin := MarginContainer.new()
	margin.add_theme_constant_override("margin_left", CONTENT_MARGIN_H)
	margin.add_theme_constant_override("margin_top", CONTENT_MARGIN_TOP)
	margin.add_theme_constant_override("margin_right", CONTENT_MARGIN_H)
	margin.add_theme_constant_override("margin_bottom", 10)
	_panel.add_child(margin)

	var root_vbox := VBoxContainer.new()
	root_vbox.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	root_vbox.size_flags_vertical = Control.SIZE_EXPAND_FILL
	root_vbox.add_theme_constant_override("separation", 8)
	margin.add_child(root_vbox)

	var vbox := VBoxContainer.new()
	vbox.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	vbox.size_flags_vertical = Control.SIZE_EXPAND_FILL
	vbox.add_theme_constant_override("separation", 12)
	root_vbox.add_child(vbox)

	_build_header(vbox)
	_build_basket_contents(vbox)
	_build_today_block(vbox)
	_build_sleep_strip(vbox)
	_build_entries(vbox)
	_build_audio_strip(vbox)
	_build_system_strip(root_vbox)


func _drawer_style() -> StyleBoxFlat:
	var style := StyleBoxFlat.new()
	# 藤编感：偏暖亚麻底 + 深褐右侧条（左侧抽屉开口朝右）
	style.bg_color = Color(0.96, 0.90, 0.78, 0.98)
	style.border_color = Color(0.55, 0.38, 0.22, 0.85)
	style.border_width_right = 5
	style.border_width_top = 1
	style.border_width_bottom = 1
	style.content_margin_left = 14
	style.content_margin_top = 12
	style.content_margin_right = 14
	style.content_margin_bottom = 12
	style.shadow_color = Color(0.12, 0.06, 0.02, 0.35)
	style.shadow_size = 22
	style.shadow_offset = Vector2(6, 2)
	return style


func _build_header(parent: VBoxContainer) -> void:
	var top := HBoxContainer.new()
	top.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	top.add_theme_constant_override("separation", 8)
	parent.add_child(top)

	# 左侧占位，与右侧「收起」对称，标题才能视觉居中。
	var left_pad := Control.new()
	left_pad.custom_minimum_size = Vector2(62, 1)
	left_pad.mouse_filter = Control.MOUSE_FILTER_IGNORE
	top.add_child(left_pad)

	var title_col := VBoxContainer.new()
	title_col.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	title_col.add_theme_constant_override("separation", 2)
	top.add_child(title_col)

	_title_label = Label.new()
	_title_label.text = "口袋篮子"
	_title_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	_title_label.add_theme_font_size_override("font_size", 24)
	_title_label.add_theme_color_override("font_color", Color(0.32, 0.18, 0.08, 1.0))
	title_col.add_child(_title_label)

	_day_chip = Label.new()
	_day_chip.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	_day_chip.add_theme_font_size_override("font_size", 15)
	_day_chip.add_theme_color_override("font_color", Color(0.44, 0.28, 0.14, 0.92))
	title_col.add_child(_day_chip)

	_close_button = Button.new()
	_close_button.text = "收起"
	_close_button.focus_mode = Control.FOCUS_NONE
	_close_button.custom_minimum_size = Vector2(62, 34)
	_style_ghost_button(_close_button)
	_close_button.pressed.connect(close_drawer)
	top.add_child(_close_button)

	var rule := ColorRect.new()
	rule.custom_minimum_size = Vector2(0, 2)
	rule.color = Color(0.62, 0.44, 0.26, 0.45)
	parent.add_child(rule)


func _build_basket_contents(parent: VBoxContainer) -> void:
	var panel := _make_linen_panel()
	panel.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	parent.add_child(panel)

	var col := VBoxContainer.new()
	col.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	col.add_theme_constant_override("separation", 6)
	panel.add_child(col)

	var heading := Label.new()
	heading.text = "筐里"
	heading.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	heading.add_theme_font_size_override("font_size", 14)
	heading.add_theme_color_override("font_color", Color(0.46, 0.32, 0.18, 0.88))
	col.add_child(heading)

	var coin_row := _make_stock_row("金币", "res://assets/ui/icon_coin.png")
	_coin_value = coin_row["value"]
	col.add_child(coin_row["root"])

	var seed_row := _make_stock_row("萝卜种子", "res://assets/ui/icon_seed.png")
	_seed_value = seed_row["value"]
	col.add_child(seed_row["root"])

	var turnip_row := _make_stock_row("萝卜", "res://assets/ui/icon_turnip.png")
	_turnip_value = turnip_row["value"]
	col.add_child(turnip_row["root"])

	var treat_row := _make_stock_row("零食", "res://assets/ui/icon_snack.png")
	_treat_value = treat_row["value"]
	col.add_child(treat_row["root"])


func _build_today_block(parent: VBoxContainer) -> void:
	var panel := _make_linen_panel()
	panel.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	parent.add_child(panel)

	var col := VBoxContainer.new()
	col.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	col.add_theme_constant_override("separation", 6)
	panel.add_child(col)

	var heading := Label.new()
	heading.text = "今日"
	heading.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	heading.add_theme_font_size_override("font_size", 14)
	heading.add_theme_color_override("font_color", Color(0.46, 0.32, 0.18, 0.88))
	col.add_child(heading)

	var weather_row := HBoxContainer.new()
	weather_row.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	weather_row.add_theme_constant_override("separation", 6)
	col.add_child(weather_row)

	_weather_value = Label.new()
	_weather_value.text = "—"
	_weather_value.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	_weather_value.add_theme_font_size_override("font_size", 17)
	_weather_value.add_theme_color_override("font_color", Color(0.28, 0.38, 0.48, 1.0))
	weather_row.add_child(_weather_value)

	_tomorrow_value = Label.new()
	_tomorrow_value.text = ""
	_tomorrow_value.add_theme_font_size_override("font_size", 14)
	_tomorrow_value.add_theme_color_override("font_color", Color(0.50, 0.38, 0.26, 0.72))
	weather_row.add_child(_tomorrow_value)

	var farm_row := HBoxContainer.new()
	farm_row.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	farm_row.add_theme_constant_override("separation", 8)
	col.add_child(farm_row)

	var farm_tag := Label.new()
	farm_tag.text = "田里"
	farm_tag.custom_minimum_size = Vector2(40, 0)
	farm_tag.add_theme_font_size_override("font_size", 15)
	farm_tag.add_theme_color_override("font_color", Color(0.48, 0.36, 0.24, 0.85))
	farm_row.add_child(farm_tag)

	_farm_value = Label.new()
	_farm_value.text = "—"
	_farm_value.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	_farm_value.add_theme_font_size_override("font_size", 17)
	_farm_value.add_theme_color_override("font_color", Color(0.22, 0.36, 0.14, 1.0))
	farm_row.add_child(_farm_value)

	_plot_dots = HBoxContainer.new()
	_plot_dots.add_theme_constant_override("separation", 3)
	farm_row.add_child(_plot_dots)

	var market_row := HBoxContainer.new()
	market_row.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	market_row.add_theme_constant_override("separation", 8)
	col.add_child(market_row)

	var market_tag := Label.new()
	market_tag.text = "待售"
	market_tag.custom_minimum_size = Vector2(40, 0)
	market_tag.add_theme_font_size_override("font_size", 15)
	market_tag.add_theme_color_override("font_color", Color(0.48, 0.36, 0.24, 0.85))
	market_row.add_child(market_tag)

	_market_value = Label.new()
	_market_value.text = "—"
	_market_value.add_theme_font_size_override("font_size", 17)
	_market_value.add_theme_color_override("font_color", Color(0.42, 0.26, 0.10, 1.0))
	market_row.add_child(_market_value)

	_market_sub = Label.new()
	_market_sub.text = ""
	_market_sub.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	_market_sub.horizontal_alignment = HORIZONTAL_ALIGNMENT_RIGHT
	_market_sub.add_theme_font_size_override("font_size", 14)
	_market_sub.add_theme_color_override("font_color", Color(0.50, 0.38, 0.26, 0.72))
	market_row.add_child(_market_sub)


func _make_linen_panel() -> PanelContainer:
	var panel := PanelContainer.new()
	panel.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	var style := StyleBoxFlat.new()
	style.bg_color = Color(0.99, 0.96, 0.90, 0.98)
	style.border_color = Color(0.68, 0.52, 0.34, 0.55)
	style.border_width_left = 0
	style.border_width_top = 0
	style.border_width_right = 0
	style.border_width_bottom = 2
	style.content_margin_left = 10
	style.content_margin_top = 8
	style.content_margin_right = 10
	style.content_margin_bottom = 8
	panel.add_theme_stylebox_override("panel", style)
	return panel


func _make_stock_row(label: String, icon_path: String) -> Dictionary:
	var row := HBoxContainer.new()
	row.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	row.add_theme_constant_override("separation", 8)

	var icon := TextureRect.new()
	icon.custom_minimum_size = Vector2(26, 26)
	icon.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	icon.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
	icon.texture_filter = CanvasItem.TEXTURE_FILTER_NEAREST
	icon.texture = _load_item_icon(icon_path)
	row.add_child(icon)

	var name_lab := Label.new()
	name_lab.text = label
	name_lab.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	name_lab.add_theme_font_size_override("font_size", 16)
	name_lab.add_theme_color_override("font_color", Color(0.42, 0.30, 0.18, 0.92))
	row.add_child(name_lab)

	var value := Label.new()
	value.text = "0"
	value.horizontal_alignment = HORIZONTAL_ALIGNMENT_RIGHT
	value.add_theme_font_size_override("font_size", 22)
	value.add_theme_color_override("font_color", Color(0.32, 0.20, 0.10, 1.0))
	row.add_child(value)

	return {"root": row, "value": value}


func _refresh_today() -> void:
	if _weather_value:
		_weather_value.text = GameState.get_weather_label()
	if _tomorrow_value:
		_tomorrow_value.text = "明日 %s" % GameState.get_weather_label(GameState.weather_tomorrow_hint)

	var plots := GameState.get_plot_summary()
	var growing := int(plots.get("growing", 0))
	var harvestable := int(plots.get("harvestable", 0))
	var empty := int(plots.get("empty", 0))
	var unwatered := int(plots.get("unwatered_growing", 0))
	if _farm_value:
		if harvestable > 0:
			_farm_value.text = "%d 垄能收" % harvestable
		elif unwatered > 0:
			_farm_value.text = "%d 垄还干" % unwatered
		elif growing > 0:
			_farm_value.text = "%d 垄在长" % growing
		elif empty > 0:
			_farm_value.text = "还空着"
		else:
			_farm_value.text = "安静着"
	_refresh_plot_dots(plots)

	var turnips := GameState.get_item_count("turnip")
	if _market_value:
		_market_value.text = "%d 个" % turnips
	if _market_sub:
		_market_sub.text = "点出售换金币" if turnips > 0 else "熟了再收"


func _refresh_plot_dots(plots: Dictionary) -> void:
	if _plot_dots == null:
		return
	for child in _plot_dots.get_children():
		_plot_dots.remove_child(child)
		child.free()
	var ids: Array = GameState.get_all_plot_ids()
	var harvestable_ids: Array = plots.get("harvestable_plot_ids", [])
	var unwatered_ids: Array = plots.get("unwatered_plot_ids", [])
	var shown := mini(ids.size(), 10)
	for i in range(shown):
		var plot_id := int(ids[i])
		var plot: Dictionary = GameState.get_plot(plot_id)
		var stage := int(plot.get("stage", 0))
		var dot := ColorRect.new()
		dot.custom_minimum_size = Vector2(8, 8)
		dot.color = Color(0.78, 0.70, 0.52, 0.9)
		if plot_id in harvestable_ids:
			dot.color = Color(0.86, 0.46, 0.38, 1.0)
		elif plot_id in unwatered_ids:
			dot.color = Color(0.72, 0.58, 0.28, 1.0)
		elif stage > 0:
			dot.color = Color(0.42, 0.68, 0.32, 1.0)
		_plot_dots.add_child(dot)


func _load_item_icon(path: String) -> Texture2D:
	if ResourceLoader.exists(path):
		var tex := load(path) as Texture2D
		if tex != null:
			return tex
	# 尚未被 Godot 导入时，直接读文件像素，保持最近邻。
	var abs_path := ProjectSettings.globalize_path(path)
	if FileAccess.file_exists(path) or FileAccess.file_exists(abs_path):
		var img := Image.new()
		var err := img.load(path)
		if err == OK:
			return ImageTexture.create_from_image(img)
	var img2 := Image.create(16, 16, false, Image.FORMAT_RGBA8)
	img2.fill(Color(0.7, 0.55, 0.3, 1))
	return ImageTexture.create_from_image(img2)


func _build_audio_strip(parent: VBoxContainer) -> void:
	var col := VBoxContainer.new()
	col.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	col.add_theme_constant_override("separation", 6)
	parent.add_child(col)

	var title := Label.new()
	title.text = "声音"
	title.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	title.add_theme_font_size_override("font_size", 14)
	title.add_theme_color_override("font_color", Color(0.50, 0.36, 0.22, 0.82))
	col.add_child(title)

	var bgm_row := _make_volume_row("音乐", GameState.bgm_volume_linear)
	_bgm_slider = bgm_row["slider"] as HSlider
	_bgm_slider.value_changed.connect(func(value: float) -> void:
		GameState.set_bgm_volume_linear(value)
	)
	col.add_child(bgm_row["root"] as Node)

	var ambient_row := _make_volume_row("环境", GameState.ambient_volume_linear)
	_ambient_slider = ambient_row["slider"] as HSlider
	_ambient_slider.value_changed.connect(func(value: float) -> void:
		GameState.set_ambient_volume_linear(value)
	)
	col.add_child(ambient_row["root"] as Node)


func _make_volume_row(label_text: String, initial: float) -> Dictionary:
	var row := HBoxContainer.new()
	row.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	row.add_theme_constant_override("separation", 10)

	var label := Label.new()
	label.text = label_text
	label.custom_minimum_size = Vector2(48, 0)
	label.add_theme_font_size_override("font_size", 15)
	label.add_theme_color_override("font_color", Color(0.42, 0.28, 0.14, 1.0))
	row.add_child(label)

	var slider := HSlider.new()
	slider.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	slider.min_value = 0.05
	slider.max_value = 1.0
	slider.step = 0.05
	slider.value = maxf(initial, 0.05)
	slider.focus_mode = Control.FOCUS_NONE
	row.add_child(slider)

	return {"root": row, "slider": slider}


func _build_sleep_strip(parent: VBoxContainer) -> void:
	_sleep_button = Button.new()
	_sleep_button.focus_mode = Control.FOCUS_NONE
	_sleep_button.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	_sleep_button.custom_minimum_size = Vector2(0, 48)
	_sleep_button.text = "下一天"
	var normal := StyleBoxFlat.new()
	normal.bg_color = Color(0.44, 0.32, 0.22, 0.94)
	normal.border_color = Color(0.62, 0.46, 0.28, 0.65)
	normal.set_border_width_all(1)
	normal.set_corner_radius_all(6)
	normal.content_margin_left = 14
	normal.content_margin_top = 10
	normal.content_margin_right = 14
	normal.content_margin_bottom = 10
	var hover := normal.duplicate()
	hover.bg_color = Color(0.52, 0.38, 0.26, 0.96)
	_sleep_button.add_theme_stylebox_override("normal", normal)
	_sleep_button.add_theme_stylebox_override("hover", hover)
	_sleep_button.add_theme_stylebox_override("pressed", hover)
	_sleep_button.add_theme_color_override("font_color", Color(0.96, 0.93, 0.86, 1.0))
	_sleep_button.add_theme_color_override("font_hover_color", Color(1, 0.98, 0.92, 1.0))
	_sleep_button.add_theme_font_size_override("font_size", 17)
	_sleep_button.pressed.connect(func() -> void:
		sleep_requested.emit()
	)
	parent.add_child(_sleep_button)


func _build_entries(parent: VBoxContainer) -> void:
	var row := HBoxContainer.new()
	row.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	row.add_theme_constant_override("separation", 8)
	parent.add_child(row)

	_shop_button = _make_entry_tag("商店", Color(0.93, 0.72, 0.42), Color(0.42, 0.26, 0.10))
	_shop_button.pressed.connect(func() -> void: shop_requested.emit())
	row.add_child(_shop_button)

	_market_button = _make_entry_tag("出售", Color(0.72, 0.82, 0.58), Color(0.24, 0.34, 0.14))
	_market_button.pressed.connect(func() -> void: market_requested.emit())
	row.add_child(_market_button)

	_memory_button = _make_entry_tag("本子", Color(0.88, 0.78, 0.62), Color(0.38, 0.26, 0.14))
	_memory_button.pressed.connect(func() -> void: memory_requested.emit())
	row.add_child(_memory_button)


func _make_entry_tag(title: String, fill: Color, ink: Color) -> Button:
	var button := Button.new()
	button.focus_mode = Control.FOCUS_NONE
	button.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	button.custom_minimum_size = Vector2(0, 44)
	button.text = title
	var normal := StyleBoxFlat.new()
	normal.bg_color = fill
	normal.border_color = ink * Color(1, 1, 1, 0.4)
	normal.set_border_width_all(1)
	normal.set_corner_radius_all(6)
	normal.content_margin_left = 6
	normal.content_margin_top = 8
	normal.content_margin_right = 6
	normal.content_margin_bottom = 8
	var hover := normal.duplicate()
	hover.bg_color = fill.lightened(0.06)
	button.add_theme_stylebox_override("normal", normal)
	button.add_theme_stylebox_override("hover", hover)
	button.add_theme_stylebox_override("pressed", hover)
	button.add_theme_color_override("font_color", ink)
	button.add_theme_color_override("font_hover_color", ink)
	button.add_theme_font_size_override("font_size", 16)
	return button


func _build_system_strip(parent: VBoxContainer) -> void:
	var rule := ColorRect.new()
	rule.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	rule.custom_minimum_size = Vector2(0, 2)
	rule.color = Color(0.62, 0.44, 0.26, 0.35)
	parent.add_child(rule)

	var row := HBoxContainer.new()
	row.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	row.add_theme_constant_override("separation", 8)
	parent.add_child(row)

	_main_menu_button = _make_system_button("主菜单")
	_main_menu_button.pressed.connect(func() -> void: main_menu_requested.emit())
	row.add_child(_main_menu_button)

	_exit_game_button = _make_system_button("退出游戏")
	_exit_game_button.pressed.connect(func() -> void: exit_game_requested.emit())
	row.add_child(_exit_game_button)


func _make_system_button(title: String) -> Button:
	var button := Button.new()
	button.focus_mode = Control.FOCUS_NONE
	button.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	button.custom_minimum_size = Vector2(0, 42)
	button.text = title
	var normal := StyleBoxFlat.new()
	normal.bg_color = Color(0.94, 0.88, 0.78, 0.96)
	normal.border_color = Color(0.58, 0.42, 0.26, 0.55)
	normal.set_border_width_all(1)
	normal.set_corner_radius_all(6)
	normal.content_margin_left = 8
	normal.content_margin_top = 8
	normal.content_margin_right = 8
	normal.content_margin_bottom = 8
	var hover := normal.duplicate()
	hover.bg_color = Color(0.98, 0.94, 0.86, 1.0)
	button.add_theme_stylebox_override("normal", normal)
	button.add_theme_stylebox_override("hover", hover)
	button.add_theme_stylebox_override("pressed", hover)
	button.add_theme_color_override("font_color", Color(0.38, 0.24, 0.12, 1.0))
	button.add_theme_color_override("font_hover_color", Color(0.28, 0.16, 0.08, 1.0))
	button.add_theme_font_size_override("font_size", 16)
	return button


func _style_ghost_button(button: Button) -> void:
	var normal := StyleBoxFlat.new()
	normal.bg_color = Color(1, 1, 1, 0.22)
	normal.border_color = Color(0.55, 0.40, 0.24, 0.45)
	normal.set_border_width_all(1)
	normal.set_corner_radius_all(10)
	normal.content_margin_left = 10
	normal.content_margin_top = 6
	normal.content_margin_right = 10
	normal.content_margin_bottom = 6
	button.add_theme_stylebox_override("normal", normal)
	button.add_theme_stylebox_override("hover", normal)
	button.add_theme_color_override("font_color", Color(0.38, 0.24, 0.10, 1.0))
	button.add_theme_font_size_override("font_size", 16)


func _basket_font() -> Font:
	var base := UIFontTheme.get_font() if UIFontTheme else null
	if base == null:
		return null
	if base is FontVariation:
		var copy := (base as FontVariation).duplicate() as FontVariation
		copy.variation_embolden = maxf(copy.variation_embolden, 0.10)
		return copy
	if base is FontFile:
		var fv := FontVariation.new()
		fv.base_font = base
		fv.variation_embolden = 0.10
		fv.spacing_glyph = 1
		return fv
	return base


func _apply_fonts() -> void:
	var font := _basket_font()
	if font == null:
		return
	for node in [
		_coin_value, _seed_value, _turnip_value, _treat_value,
		_sleep_button, _shop_button, _market_button, _memory_button, _close_button,
		_main_menu_button, _exit_game_button,
		_title_label, _day_chip, _weather_value, _tomorrow_value, _farm_value, _market_value, _market_sub,
	]:
		if node == null:
			continue
		if node is Label or node is Button:
			node.add_theme_font_override("font", font)
			if node is Label:
				node.add_theme_constant_override("outline_size", 1)
				node.add_theme_color_override(
					"font_outline_color",
					(node as Label).get_theme_color("font_color").darkened(0.12)
				)
	_apply_font_recursive(_panel, font)


func _apply_font_recursive(node: Node, font: Font) -> void:
	if node is Label:
		node.add_theme_font_override("font", font)
		node.add_theme_constant_override("outline_size", 1)
		node.add_theme_color_override("font_outline_color", node.get_theme_color("font_color").darkened(0.12))
	elif node is Button:
		node.add_theme_font_override("font", font)
	for child in node.get_children():
		_apply_font_recursive(child, font)
