extends Control
class_name BasketDrawer
## 左上「口袋篮子」：像随手翻开的藤编小筐，不是系统背包菜单。
## 根节点必须是 Control（不能用 PanelContainer），否则子节点锚点会被容器覆写。

signal shop_requested
signal market_requested
signal memory_requested
signal sleep_requested
signal closed

const DRAWER_WIDTH := 368.0
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
var _sprout: RelationshipSprout
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
var _title_label: Label
var _day_chip: Label
var _open: bool = false
var _slide_tween: Tween = null
var _last_sprout_tier: int = -1
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
	if _sprout:
		_sprout.start_idle()

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
	if _sprout:
		_sprout.stop_idle()

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
	if GameState.is_night():
		_sleep_button.text = "睡觉"
	else:
		_sleep_button.text = "下一天"
	if _day_chip:
		_day_chip.text = GameState.get_day_period_label()
	_refresh_today()
	_refresh_sprout()


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


func _refresh_sprout() -> void:
	if _sprout == null:
		return
	var tier := get_sprout_tier()
	var twin := (
		GameState.is_story_node_seen("_N15")
		or GameState.is_story_node_seen("P_N15")
		or GameState.is_story_node_seen("t10_d8_notebook")
	)
	var grew := _last_sprout_tier >= 0 and tier > _last_sprout_tier
	_sprout.set_state(tier, twin, grew)
	_last_sprout_tier = tier


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
	margin.add_theme_constant_override("margin_left", 4)
	margin.add_theme_constant_override("margin_top", 4)
	margin.add_theme_constant_override("margin_right", 4)
	margin.add_theme_constant_override("margin_bottom", 4)
	_panel.add_child(margin)

	var vbox := VBoxContainer.new()
	vbox.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	vbox.size_flags_vertical = Control.SIZE_EXPAND_FILL
	vbox.add_theme_constant_override("separation", 10)
	margin.add_child(vbox)

	_build_header(vbox)
	_build_living_grid(vbox)
	_build_today_strip(vbox)
	_build_sleep_strip(vbox)
	_build_entries(vbox)
	_build_her_pocket(vbox)
	_build_footer_weave(vbox)


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
	## 标题排在篮子图标右侧，用满那一块，不再空出顶栏。
	var top := HBoxContainer.new()
	top.add_theme_constant_override("separation", 8)
	parent.add_child(top)

	var basket_gap := Control.new()
	basket_gap.custom_minimum_size = Vector2(100, 72)
	basket_gap.mouse_filter = Control.MOUSE_FILTER_IGNORE
	top.add_child(basket_gap)

	var title_col := VBoxContainer.new()
	title_col.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	title_col.add_theme_constant_override("separation", 4)
	top.add_child(title_col)

	_title_label = Label.new()
	_title_label.text = "我的背包"
	_title_label.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	_title_label.add_theme_font_size_override("font_size", 22)
	_title_label.add_theme_color_override("font_color", Color(0.38, 0.24, 0.12, 1.0))
	_title_label.mouse_filter = Control.MOUSE_FILTER_IGNORE
	title_col.add_child(_title_label)

	_day_chip = Label.new()
	_day_chip.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	_day_chip.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	_day_chip.add_theme_font_size_override("font_size", 13)
	_day_chip.add_theme_color_override("font_color", Color(0.42, 0.28, 0.14, 1.0))
	var chip_wrap := PanelContainer.new()
	chip_wrap.size_flags_horizontal = Control.SIZE_SHRINK_BEGIN
	var chip_style := StyleBoxFlat.new()
	chip_style.bg_color = Color(0.93, 0.82, 0.58, 0.95)
	chip_style.set_corner_radius_all(10)
	chip_style.content_margin_left = 10
	chip_style.content_margin_right = 10
	chip_style.content_margin_top = 3
	chip_style.content_margin_bottom = 3
	chip_wrap.add_theme_stylebox_override("panel", chip_style)
	chip_wrap.add_child(_day_chip)
	title_col.add_child(chip_wrap)

	_close_button = Button.new()
	_close_button.text = "收起"
	_close_button.focus_mode = Control.FOCUS_NONE
	_close_button.custom_minimum_size = Vector2(64, 30)
	_close_button.size_flags_vertical = Control.SIZE_SHRINK_BEGIN
	_style_ghost_button(_close_button)
	_close_button.pressed.connect(close_drawer)
	top.add_child(_close_button)

	_add_weave_row(parent)


func _build_living_grid(parent: VBoxContainer) -> void:
	var grid := GridContainer.new()
	grid.columns = 2
	grid.add_theme_constant_override("h_separation", 10)
	grid.add_theme_constant_override("v_separation", 10)
	parent.add_child(grid)

	var coin_tile := _make_item_tile("金币", "res://assets/ui/icon_coin.png", Color(0.98, 0.92, 0.72), Color(0.45, 0.28, 0.08))
	_coin_value = coin_tile["value"]
	grid.add_child(coin_tile["root"])

	var seed_tile := _make_item_tile("萝卜种子", "res://assets/ui/icon_seed.png", Color(0.88, 0.94, 0.82), Color(0.22, 0.36, 0.14))
	_seed_value = seed_tile["value"]
	grid.add_child(seed_tile["root"])

	var turnip_tile := _make_item_tile("萝卜", "res://assets/ui/icon_turnip.png", Color(0.98, 0.88, 0.84), Color(0.45, 0.22, 0.12))
	_turnip_value = turnip_tile["value"]
	grid.add_child(turnip_tile["root"])

	var treat_tile := _make_item_tile("零食", "res://assets/ui/icon_snack.png", Color(0.96, 0.90, 0.82), Color(0.42, 0.24, 0.12))
	_treat_value = treat_tile["value"]
	grid.add_child(treat_tile["root"])


func _build_today_strip(parent: VBoxContainer) -> void:
	var row := HBoxContainer.new()
	row.add_theme_constant_override("separation", 8)
	parent.add_child(row)

	var weather_tile := _make_info_tile("天气", Color(0.86, 0.93, 0.96), Color(0.18, 0.32, 0.42))
	_weather_value = weather_tile["value"]
	_tomorrow_value = weather_tile["sub"]
	row.add_child(weather_tile["root"])

	var farm_tile := _make_info_tile("田里", Color(0.88, 0.94, 0.82), Color(0.22, 0.36, 0.14))
	_farm_value = farm_tile["value"]
	farm_tile["sub"].visible = false
	row.add_child(farm_tile["root"])
	_plot_dots = HBoxContainer.new()
	_plot_dots.add_theme_constant_override("separation", 3)
	farm_tile["extra"].add_child(_plot_dots)

	var market_tile := _make_info_tile("筐里", Color(0.98, 0.92, 0.78), Color(0.42, 0.26, 0.10))
	_market_value = market_tile["value"]
	_market_sub = market_tile["sub"]
	row.add_child(market_tile["root"])


func _make_info_tile(title: String, badge_bg: Color, ink: Color) -> Dictionary:
	var root := PanelContainer.new()
	root.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	root.custom_minimum_size = Vector2(0, 86)
	var style := StyleBoxFlat.new()
	style.bg_color = Color(1.0, 0.97, 0.90, 0.96)
	style.border_color = Color(0.70, 0.52, 0.32, 0.35)
	style.set_border_width_all(1)
	style.set_corner_radius_all(14)
	style.content_margin_left = 10
	style.content_margin_top = 8
	style.content_margin_right = 10
	style.content_margin_bottom = 8
	root.add_theme_stylebox_override("panel", style)

	var col := VBoxContainer.new()
	col.add_theme_constant_override("separation", 2)
	root.add_child(col)

	var name_lab := Label.new()
	name_lab.text = title
	name_lab.add_theme_font_size_override("font_size", 12)
	name_lab.add_theme_color_override("font_color", Color(0.48, 0.36, 0.24, 0.85))
	col.add_child(name_lab)

	var value := Label.new()
	value.text = "—"
	value.autowrap_mode = TextServer.AUTOWRAP_OFF
	value.add_theme_font_size_override("font_size", 16)
	value.add_theme_color_override("font_color", ink)
	col.add_child(value)

	var extra := VBoxContainer.new()
	extra.add_theme_constant_override("separation", 2)
	col.add_child(extra)

	var sub := Label.new()
	sub.text = ""
	sub.add_theme_font_size_override("font_size", 11)
	sub.add_theme_color_override("font_color", Color(0.50, 0.38, 0.26, 0.75))
	extra.add_child(sub)

	return {"root": root, "value": value, "sub": sub, "extra": extra}


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


func _make_item_tile(label: String, icon_path: String, badge_bg: Color, ink: Color) -> Dictionary:
	var root := PanelContainer.new()
	root.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	root.custom_minimum_size = Vector2(0, 78)
	var style := StyleBoxFlat.new()
	style.bg_color = Color(1.0, 0.97, 0.90, 0.96)
	style.border_color = Color(0.70, 0.52, 0.32, 0.35)
	style.set_border_width_all(1)
	style.set_corner_radius_all(14)
	style.content_margin_left = 12
	style.content_margin_top = 10
	style.content_margin_right = 12
	style.content_margin_bottom = 10
	style.shadow_color = Color(0.2, 0.1, 0.04, 0.12)
	style.shadow_size = 4
	style.shadow_offset = Vector2(0, 2)
	root.add_theme_stylebox_override("panel", style)

	var row := HBoxContainer.new()
	row.add_theme_constant_override("separation", 10)
	root.add_child(row)

	var badge_wrap := PanelContainer.new()
	badge_wrap.custom_minimum_size = Vector2(48, 48)
	var bstyle := StyleBoxFlat.new()
	bstyle.bg_color = badge_bg
	bstyle.set_corner_radius_all(12)
	bstyle.content_margin_left = 4
	bstyle.content_margin_top = 4
	bstyle.content_margin_right = 4
	bstyle.content_margin_bottom = 4
	badge_wrap.add_theme_stylebox_override("panel", bstyle)

	var icon := TextureRect.new()
	icon.custom_minimum_size = Vector2(40, 40)
	icon.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	icon.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
	icon.texture_filter = CanvasItem.TEXTURE_FILTER_NEAREST
	icon.texture = _load_item_icon(icon_path)
	badge_wrap.add_child(icon)
	row.add_child(badge_wrap)

	var col := VBoxContainer.new()
	col.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	col.add_theme_constant_override("separation", 0)
	row.add_child(col)

	var name_lab := Label.new()
	name_lab.text = label
	name_lab.add_theme_font_size_override("font_size", 13)
	name_lab.add_theme_color_override("font_color", Color(0.48, 0.36, 0.24, 0.9))
	col.add_child(name_lab)

	var value := Label.new()
	value.text = "0"
	value.add_theme_font_size_override("font_size", 26)
	value.add_theme_color_override("font_color", ink)
	col.add_child(value)

	return {"root": root, "value": value}


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


func _build_sleep_strip(parent: VBoxContainer) -> void:
	_sleep_button = Button.new()
	_sleep_button.focus_mode = Control.FOCUS_NONE
	_sleep_button.custom_minimum_size = Vector2(0, 52)
	_sleep_button.text = "下一天"
	var normal := StyleBoxFlat.new()
	normal.bg_color = Color(0.42, 0.30, 0.22, 0.94)
	normal.border_color = Color(0.72, 0.55, 0.36, 0.55)
	normal.set_border_width_all(1)
	normal.set_corner_radius_all(16)
	normal.content_margin_left = 16
	normal.content_margin_top = 12
	normal.content_margin_right = 16
	normal.content_margin_bottom = 12
	var hover := normal.duplicate()
	hover.bg_color = Color(0.50, 0.36, 0.26, 0.96)
	_sleep_button.add_theme_stylebox_override("normal", normal)
	_sleep_button.add_theme_stylebox_override("hover", hover)
	_sleep_button.add_theme_stylebox_override("pressed", hover)
	_sleep_button.add_theme_color_override("font_color", Color(0.96, 0.93, 0.86, 1.0))
	_sleep_button.add_theme_color_override("font_hover_color", Color(1, 0.98, 0.92, 1.0))
	_sleep_button.add_theme_font_size_override("font_size", 16)
	_sleep_button.pressed.connect(func() -> void:
		sleep_requested.emit()
	)
	parent.add_child(_sleep_button)


func _build_entries(parent: VBoxContainer) -> void:
	var row := HBoxContainer.new()
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
	button.custom_minimum_size = Vector2(0, 52)
	button.text = title
	var normal := StyleBoxFlat.new()
	normal.bg_color = fill
	normal.border_color = ink * Color(1, 1, 1, 0.35)
	normal.set_border_width_all(1)
	normal.border_width_top = 4
	normal.set_corner_radius_all(12)
	normal.corner_radius_top_left = 4
	normal.corner_radius_top_right = 4
	normal.content_margin_left = 8
	normal.content_margin_top = 12
	normal.content_margin_right = 8
	normal.content_margin_bottom = 12
	var hover := normal.duplicate()
	hover.bg_color = fill.lightened(0.08)
	hover.shadow_color = Color(0.2, 0.1, 0.04, 0.18)
	hover.shadow_size = 6
	hover.shadow_offset = Vector2(0, 3)
	button.add_theme_stylebox_override("normal", normal)
	button.add_theme_stylebox_override("hover", hover)
	button.add_theme_stylebox_override("pressed", hover)
	button.add_theme_color_override("font_color", ink)
	button.add_theme_color_override("font_hover_color", ink)
	button.add_theme_font_size_override("font_size", 16)
	return button


func _build_her_pocket(parent: VBoxContainer) -> void:
	## 小苗占满剩余高度，底下不再空一大块亚麻底。
	var pocket := PanelContainer.new()
	pocket.size_flags_vertical = Control.SIZE_EXPAND_FILL
	var pstyle := StyleBoxFlat.new()
	pstyle.bg_color = Color(0.88, 0.94, 0.82, 0.96)
	pstyle.border_color = Color(0.55, 0.68, 0.42, 0.5)
	pstyle.set_border_width_all(1)
	pstyle.set_corner_radius_all(18)
	pstyle.content_margin_left = 6
	pstyle.content_margin_top = 6
	pstyle.content_margin_right = 6
	pstyle.content_margin_bottom = 6
	pstyle.shadow_color = Color(0.2, 0.35, 0.12, 0.12)
	pstyle.shadow_size = 6
	pstyle.shadow_offset = Vector2(0, 2)
	pocket.add_theme_stylebox_override("panel", pstyle)
	parent.add_child(pocket)

	_sprout = RelationshipSprout.new()
	_sprout.name = "RelationshipSprout"
	pocket.add_child(_sprout)
	_refresh_sprout()


func _add_weave_row(parent: VBoxContainer) -> void:
	var weave := HBoxContainer.new()
	weave.add_theme_constant_override("separation", 4)
	parent.add_child(weave)
	for i in range(12):
		var strip := ColorRect.new()
		strip.custom_minimum_size = Vector2(0, 4)
		strip.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		strip.color = Color(0.72, 0.52, 0.30, 0.35 + (i % 2) * 0.12)
		weave.add_child(strip)


func _build_footer_weave(parent: VBoxContainer) -> void:
	_add_weave_row(parent)


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
	button.add_theme_color_override("font_color", Color(0.42, 0.30, 0.18, 1.0))
	button.add_theme_font_size_override("font_size", 14)


func _apply_fonts() -> void:
	var font := UIFontTheme.get_font() if UIFontTheme else null
	if font == null:
		return
	for node in [
		_coin_value, _seed_value, _turnip_value, _treat_value,
		_sleep_button, _shop_button, _market_button, _memory_button, _close_button,
		_title_label, _day_chip, _weather_value, _tomorrow_value, _farm_value, _market_value, _market_sub,
	]:
		if node == null:
			continue
		if node is Label or node is Button:
			node.add_theme_font_override("font", font)
	# 递归给分区标题等补字体
	_apply_font_recursive(_panel, font)


func _apply_font_recursive(node: Node, font: Font) -> void:
	if node is Label or node is Button:
		node.add_theme_font_override("font", font)
	for child in node.get_children():
		_apply_font_recursive(child, font)
