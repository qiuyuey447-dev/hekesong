extends Control

const MAIN_SCENE := "res://scenes/main.tscn"
const FARM_MAP_SCENE := preload("res://scenes/farm_map.tscn")
const FOX_TEX := preload("res://Characters/Animals/fox1_16x20.png")
const FOX_FRAME := Vector2i(16, 20)

## 封面构图：旧屋 + 廊下 + 树洞旁的小狸。不把商店/田埂拉进画框。
const WORLD_FOCUS := Vector2(1120, 548)
const WORLD_ZOOM := Vector2(2.05, 2.05)
const COVER_MARKERS: Array[String] = ["人", "廊下", "树洞", "小狸"]
const TITLE_MAP_BOUNDS := Rect2(64, 108, 520, 380)
const TITLE_FRAME_MIN_SIZE := Vector2(620, 360)
const TITLE_FRAME_PADDING := 72.0
const TITLE_BACKDROP_COLOR := Color(0.77, 0.87, 0.97, 1.0)
const DAY_MODULATE := Color(1.0, 1.0, 0.98)
const CAMERA_COVER_OVERSCAN := 1.012
const FOX_BASE_SCALE := 2.6
const FOX_VIEW_OFFSET := Vector2(0.26, 0.20)
const TITLE_FONT_SIZE := 78
const MENU_BUTTON_SIZE := Vector2(372, 93)
const MENU_FONT_SIZE := 42

var _menu_root: Control
var _title_root: Control
var _title_sign: Control
var _continue_button: Button
var _new_game_button: Button
var _exit_button: Button
var _world_viewport_container: SubViewportContainer
var _world_viewport: SubViewport
var _world_camera: Camera2D
var _farm_map: Node2D
var _camera_base := WORLD_FOCUS
var _camera_zoom := WORLD_ZOOM
var _title_map_bounds := TITLE_MAP_BOUNDS
var _title_fox: Node2D
var _fox_body: Sprite2D
var _fox_frames: Array[Texture2D] = []
var _fox_frame_col := -1
var _menu_buttons: Array[Button] = []
var _time := 0.0


func _ready() -> void:
	GameState.push_time_pause()
	set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	mouse_filter = Control.MOUSE_FILTER_STOP
	RenderingServer.set_default_clear_color(TITLE_BACKDROP_COLOR)
	DisplayServer.window_set_title(GameState.GAME_DISPLAY_NAME)
	_build_world_background()
	_build_overlay()
	_build_menu()
	await get_tree().process_frame
	_sync_world_viewport_size()
	if not get_viewport().size_changed.is_connected(_sync_world_viewport_size):
		get_viewport().size_changed.connect(_sync_world_viewport_size)
	if _world_viewport_container != null and not _world_viewport_container.resized.is_connected(_sync_world_viewport_size):
		_world_viewport_container.resized.connect(_sync_world_viewport_size)
	_refresh_save_state()
	call_deferred("_ensure_bgm")


func _ensure_bgm() -> void:
	BgmDirector.ensure_playing()


func _process(delta: float) -> void:
	_time += delta
	if _world_camera != null:
		var drift := Vector2(
			sin(_time * 0.22) * 3.0,
			cos(_time * 0.17) * 4.0
		)
		_world_camera.position = _clamp_camera_position(_camera_base + drift)
		_world_camera.zoom = _camera_zoom
	if _title_sign != null:
		_title_sign.rotation = sin(_time * 0.55) * 0.008
	_update_title_fox()


func _update_title_fox() -> void:
	if _title_fox == null or _fox_body == null:
		return

	var wag := sin(_time * 4.6)
	var bounce := sin(_time * 1.85)
	_title_fox.rotation = wag * 0.08
	_title_fox.position.x = float(_title_fox.get_meta("base_x", _title_fox.position.x))
	_title_fox.position.y = float(_title_fox.get_meta("base_y", _title_fox.position.y)) + bounce * 2.4
	var squash := 1.0 + sin(_time * 2.8) * 0.035
	_title_fox.scale = Vector2(FOX_BASE_SCALE * squash, FOX_BASE_SCALE * (1.05 - squash * 0.05))

	var frame_col := 1
	if wag > 0.42:
		frame_col = 2
	elif wag < -0.42:
		frame_col = 0
	if frame_col != _fox_frame_col:
		_fox_frame_col = frame_col
		_fox_body.texture = _fox_frame_texture(frame_col)


func _build_world_background() -> void:
	_world_viewport_container = SubViewportContainer.new()
	_world_viewport_container.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	_world_viewport_container.stretch = true
	if OS.has_feature("web"):
		_world_viewport_container.stretch_shrink = 2
	_world_viewport_container.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(_world_viewport_container)

	_world_viewport = SubViewport.new()
	_world_viewport.transparent_bg = false
	_world_viewport.size = Vector2i(1920, 1080)
	_world_viewport.render_target_update_mode = SubViewport.UPDATE_ALWAYS
	_world_viewport.handle_input_locally = false
	_world_viewport.gui_disable_input = true
	_world_viewport.canvas_item_default_texture_filter = Viewport.DEFAULT_CANVAS_ITEM_TEXTURE_FILTER_NEAREST
	_world_viewport_container.add_child(_world_viewport)

	var world := Node2D.new()
	world.name = "TitleWorld"
	_world_viewport.add_child(world)

	_add_title_world_backdrop(world)

	var atmosphere := CanvasModulate.new()
	atmosphere.color = DAY_MODULATE
	world.add_child(atmosphere)

	var farm_map := FARM_MAP_SCENE.instantiate() as Node2D
	_farm_map = farm_map
	world.add_child(farm_map)
	FarmSetdress.sync_markers(farm_map)
	var stall := Node2D.new()
	stall.name = "ShopStall"
	stall.position = FarmSetdress.marker_position(farm_map, "商店", FarmSetdress.POS_SHOP)
	FarmSetdress.ensure_actors(farm_map).add_child(stall)
	FarmSetdress.build_shop_stall(stall)

	_spawn_title_fox(world, farm_map)

	_world_camera = Camera2D.new()
	_world_camera.enabled = true
	world.add_child(_world_camera)

	_configure_title_camera(farm_map)
	_place_title_fox_in_view()


func _sync_world_viewport_size() -> void:
	if _world_viewport == null:
		return
	# stretch=true 时由 SubViewportContainer 管尺寸，禁止手动改 size（会刷 WARNING）。
	if _world_viewport_container == null or not _world_viewport_container.stretch:
		var size := _get_layout_viewport_size()
		_world_viewport.size = Vector2i(maxi(1, int(size.x)), maxi(1, int(size.y)))
	if _farm_map != null:
		_configure_title_camera(_farm_map)
	if _world_camera != null:
		_world_camera.zoom = _camera_zoom
		_world_camera.position = _clamp_camera_position(_camera_base)
	_place_title_fox_in_view()


func _get_layout_viewport_size() -> Vector2:
	if _world_viewport != null:
		var vp_size := Vector2(_world_viewport.size)
		if vp_size.x > 1.0 and vp_size.y > 1.0:
			return vp_size
	if _world_viewport_container != null:
		var container_size := _world_viewport_container.get_rect().size
		var shrink := 1
		if _world_viewport_container.stretch:
			shrink = maxi(1, _world_viewport_container.stretch_shrink)
		if container_size.x > 1.0 and container_size.y > 1.0:
			return container_size / float(shrink)
	return get_viewport_rect().size


func _configure_title_camera(farm_map: Node2D) -> void:
	var content_bounds := _compute_title_map_bounds(farm_map)
	_title_map_bounds = content_bounds
	var frame_rect := _compute_title_frame_rect(farm_map, content_bounds)

	var vp_size := _get_layout_viewport_size()
	if vp_size.x <= 0.0 or vp_size.y <= 0.0:
		vp_size = Vector2(1920, 1080)

	var zoom_x := vp_size.x / maxf(frame_rect.size.x, 1.0)
	var zoom_y := vp_size.y / maxf(frame_rect.size.y, 1.0)
	var zoom_value := maxf(zoom_x, zoom_y) * CAMERA_COVER_OVERSCAN
	_camera_zoom = Vector2(zoom_value, zoom_value)
	_camera_base = frame_rect.get_center()
	var fox_marker := farm_map.get_node_or_null("小狸") as Node2D
	if fox_marker != null:
		_camera_base = _camera_base.lerp(fox_marker.position, 0.32)
	_camera_base = _clamp_camera_position(_camera_base)


func _add_title_world_backdrop(world: Node2D) -> void:
	var backdrop := Sprite2D.new()
	backdrop.name = "TitleBackdrop"
	backdrop.z_index = -100
	var img := Image.create(1, 1, false, Image.FORMAT_RGBA8)
	img.fill(TITLE_BACKDROP_COLOR)
	backdrop.texture = ImageTexture.create_from_image(img)
	backdrop.centered = false
	backdrop.position = Vector2(-2048, -2048)
	backdrop.scale = Vector2(4096, 4096)
	world.add_child(backdrop)


func _compute_title_map_bounds(farm_map: Node2D) -> Rect2:
	var bounds := _layer_world_bounds(farm_map.get_node_or_null("草地") as TileMapLayer)
	var has_bounds := bounds.size.x > 0.0 and bounds.size.y > 0.0
	for layer_name in ["河流树木家园", "沙地", "家", "田", "商店以及附属品"]:
		var layer_bounds := _layer_world_bounds(farm_map.get_node_or_null(layer_name) as TileMapLayer)
		if layer_bounds.size.x <= 0.0 or layer_bounds.size.y <= 0.0:
			continue
		if not has_bounds:
			bounds = layer_bounds
			has_bounds = true
		else:
			bounds = bounds.merge(layer_bounds)
	return bounds if has_bounds else TITLE_MAP_BOUNDS


func _compute_title_frame_rect(farm_map: Node2D, content_bounds: Rect2) -> Rect2:
	var frame := Rect2()
	var has_frame := false
	for marker_name in COVER_MARKERS:
		var marker := farm_map.get_node_or_null(marker_name) as Node2D
		if marker == null:
			continue
		if not has_frame:
			frame = Rect2(marker.position, Vector2.ZERO)
			has_frame = true
		else:
			frame = frame.expand(marker.position)
	if not has_frame:
		frame = content_bounds
	frame = frame.grow(TITLE_FRAME_PADDING)
	if frame.size.x < TITLE_FRAME_MIN_SIZE.x:
		var pad_x := (TITLE_FRAME_MIN_SIZE.x - frame.size.x) * 0.5
		frame = frame.grow_individual(pad_x, 0.0, pad_x, 0.0)
	if frame.size.y < TITLE_FRAME_MIN_SIZE.y:
		var pad_y := (TITLE_FRAME_MIN_SIZE.y - frame.size.y) * 0.5
		frame = frame.grow_individual(0.0, pad_y, 0.0, pad_y)
	return _rect_clamp_inside(frame, content_bounds) if content_bounds.size.x > 0.0 else frame


func _rect_clamp_inside(inner: Rect2, outer: Rect2) -> Rect2:
	if outer.size.x <= 0.0 or outer.size.y <= 0.0:
		return inner
	var size := inner.size
	size.x = minf(size.x, outer.size.x)
	size.y = minf(size.y, outer.size.y)
	var center := inner.get_center()
	center.x = clampf(
		center.x,
		outer.position.x + size.x * 0.5,
		outer.position.x + outer.size.x - size.x * 0.5
	)
	center.y = clampf(
		center.y,
		outer.position.y + size.y * 0.5,
		outer.position.y + outer.size.y - size.y * 0.5
	)
	return Rect2(center - size * 0.5, size)


func _layer_world_bounds(layer: TileMapLayer) -> Rect2:
	if layer == null:
		return Rect2()
	var used := layer.get_used_rect()
	if used.size.x <= 0 or used.size.y <= 0:
		return Rect2()
	var scale := layer.scale
	return Rect2(
		Vector2(used.position) * 16.0 * scale,
		Vector2(used.size) * 16.0 * scale
	)


func _clamp_camera_position(target: Vector2) -> Vector2:
	var vp_size := _get_layout_viewport_size()
	if vp_size.x <= 0.0 or vp_size.y <= 0.0:
		return target

	var half_w := vp_size.x / (2.0 * _camera_zoom.x)
	var half_h := vp_size.y / (2.0 * _camera_zoom.y)
	var bounds := _title_map_bounds
	var result := target

	var min_x := bounds.position.x + half_w
	var max_x := bounds.position.x + bounds.size.x - half_w
	if min_x > max_x:
		result.x = bounds.get_center().x
	else:
		result.x = clampf(target.x, min_x, max_x)

	var min_y := bounds.position.y + half_h
	var max_y := bounds.position.y + bounds.size.y - half_h
	if min_y > max_y:
		result.y = bounds.get_center().y
	else:
		result.y = clampf(target.y, min_y, max_y)

	return result


func _fox_frame_texture(col: int) -> Texture2D:
	var idx := clampi(col, 0, 2)
	while _fox_frames.size() <= idx:
		_fox_frames.append(SpriteSheet.grid_frame(FOX_TEX, FOX_FRAME, _fox_frames.size(), 0))
	return _fox_frames[idx]


func _spawn_title_fox(world: Node2D, farm_map: Node2D) -> void:
	_title_fox = Node2D.new()
	_title_fox.name = "TitleFox"
	var fox_pos := FarmSetdress.marker_position(farm_map, "小狸", FarmSetdress.POS_FOX)
	_title_fox.position = fox_pos + Vector2(0, 8)
	_title_fox.set_meta("base_x", _title_fox.position.x)
	_title_fox.set_meta("base_y", _title_fox.position.y)
	_title_fox.z_as_relative = false
	_title_fox.z_index = 24

	var shadow := Sprite2D.new()
	var shadow_img := Image.create(22, 8, false, Image.FORMAT_RGBA8)
	shadow_img.fill(Color(0, 0, 0, 0))
	for y in range(8):
		for x in range(22):
			var dx := (x - 11.0) / 11.0
			var dy := (y - 4.0) / 4.0
			if dx * dx + dy * dy <= 1.0:
				shadow_img.set_pixel(x, y, Color(0, 0, 0, 0.28))
	shadow.texture = ImageTexture.create_from_image(shadow_img)
	shadow.texture_filter = CanvasItem.TEXTURE_FILTER_NEAREST
	shadow.centered = true
	shadow.position = Vector2(0, 4)
	shadow.z_index = -1
	_title_fox.add_child(shadow)

	_fox_body = Sprite2D.new()
	_fox_body.texture = _fox_frame_texture(1)
	_fox_frame_col = 1
	_fox_body.texture_filter = CanvasItem.TEXTURE_FILTER_NEAREST
	_fox_body.centered = false
	_fox_body.offset = Vector2(-8, -18)
	_title_fox.add_child(_fox_body)

	_title_fox.scale = Vector2(FOX_BASE_SCALE, FOX_BASE_SCALE)
	world.add_child(_title_fox)


func _place_title_fox_in_view() -> void:
	if _title_fox == null or _world_camera == null:
		return
	var vp_size := _get_layout_viewport_size()
	if vp_size.x <= 1.0 or vp_size.y <= 1.0:
		return
	var cam := _clamp_camera_position(_camera_base)
	var half_w := vp_size.x / (2.0 * _camera_zoom.x)
	var half_h := vp_size.y / (2.0 * _camera_zoom.y)
	var pos := cam + Vector2(half_w * FOX_VIEW_OFFSET.x, half_h * FOX_VIEW_OFFSET.y)
	_title_fox.position = pos
	_title_fox.set_meta("base_x", pos.x)
	_title_fox.set_meta("base_y", pos.y)
	_title_fox.z_as_relative = false
	_title_fox.z_index = 120
	var world := _title_fox.get_parent()
	if world != null:
		world.move_child(_title_fox, world.get_child_count() - 1)


func _build_overlay() -> void:
	var vignette := TextureRect.new()
	vignette.set_anchors_preset(Control.PRESET_FULL_RECT)
	vignette.mouse_filter = Control.MOUSE_FILTER_IGNORE
	vignette.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	vignette.stretch_mode = TextureRect.STRETCH_SCALE
	vignette.texture = _make_cover_vignette()
	vignette.texture_filter = CanvasItem.TEXTURE_FILTER_LINEAR
	add_child(vignette)


func _make_cover_vignette() -> Texture2D:
	var img := Image.create(64, 36, false, Image.FORMAT_RGBA8)
	for y in range(36):
		for x in range(64):
			var nx := (x / 63.0) * 2.0 - 1.0
			var ny := (y / 35.0) * 2.0 - 1.0
			var d := sqrt(nx * nx * 0.62 + ny * ny * 0.92)
			var a := clampf((d - 0.48) / 0.82, 0.0, 1.0)
			a = a * a
			img.set_pixel(x, y, Color(0.12, 0.18, 0.28, a * 0.18))
	return ImageTexture.create_from_image(img)


func _build_menu() -> void:
	_menu_root = Control.new()
	_menu_root.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	_menu_root.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(_menu_root)

	_title_sign = _build_title_sign()
	_title_sign.set_anchors_preset(Control.PRESET_CENTER_TOP)
	_title_sign.anchor_left = 0.5
	_title_sign.anchor_right = 0.5
	_title_sign.offset_left = -420
	_title_sign.offset_right = 420
	_title_sign.offset_top = 20
	_title_sign.offset_bottom = 156
	_title_sign.pivot_offset = Vector2(420, 20)
	_menu_root.add_child(_title_sign)

	var center := CenterContainer.new()
	center.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	center.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_menu_root.add_child(center)

	var menu_stack := VBoxContainer.new()
	menu_stack.add_theme_constant_override("separation", 24)
	menu_stack.alignment = BoxContainer.ALIGNMENT_CENTER
	menu_stack.mouse_filter = Control.MOUSE_FILTER_IGNORE
	center.add_child(menu_stack)

	_continue_button = _make_menu_button("继续")
	_new_game_button = _make_menu_button("新游戏")
	_exit_button = _make_menu_button("退出")
	menu_stack.add_child(_continue_button)
	menu_stack.add_child(_new_game_button)
	menu_stack.add_child(_exit_button)

	_continue_button.pressed.connect(_on_continue_pressed)
	_new_game_button.pressed.connect(_on_new_game_pressed)
	_exit_button.pressed.connect(_on_exit_pressed)


func _build_title_sign() -> Control:
	_title_root = Control.new()
	_title_root.custom_minimum_size = Vector2(840, 136)
	_title_root.mouse_filter = Control.MOUSE_FILTER_IGNORE

	var title_holder := Control.new()
	title_holder.set_anchors_preset(Control.PRESET_FULL_RECT)
	title_holder.mouse_filter = Control.MOUSE_FILTER_IGNORE
	title_holder.add_child(_make_title_text_block())
	_title_root.add_child(title_holder)

	return _title_root


func _make_title_text_block() -> Control:
	var block := Control.new()
	block.set_anchors_preset(Control.PRESET_FULL_RECT)
	block.mouse_filter = Control.MOUSE_FILTER_IGNORE

	var title_text := GameState.GAME_DISPLAY_NAME
	var layers: Array[Dictionary] = [
		{
			"offset": Vector2(0, 4),
			"color": Color(0.18, 0.12, 0.08, 0.45),
			"outline": 0,
			"size": TITLE_FONT_SIZE,
		},
		{
			"offset": Vector2(0, 0),
			"color": Color(0.24, 0.16, 0.1),
			"outline": 10,
			"outline_color": Color(0.98, 0.95, 0.88, 0.95),
			"size": TITLE_FONT_SIZE,
		},
	]

	for layer_data in layers:
		var label := Label.new()
		label.text = title_text
		label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
		label.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
		label.set_anchors_preset(Control.PRESET_FULL_RECT)
		label.offset_left = layer_data["offset"].x
		label.offset_top = layer_data["offset"].y
		label.offset_right = layer_data["offset"].x
		label.offset_bottom = layer_data["offset"].y
		label.add_theme_font_override("font", _title_font())
		label.add_theme_font_size_override("font_size", int(layer_data["size"]))
		label.add_theme_color_override("font_color", layer_data["color"])
		var outline_size := int(layer_data.get("outline", 0))
		if outline_size > 0:
			label.add_theme_constant_override("outline_size", outline_size)
			label.add_theme_color_override(
				"font_outline_color",
				layer_data.get("outline_color", Color(0.2, 0.12, 0.08))
			)
		label.mouse_filter = Control.MOUSE_FILTER_IGNORE
		block.add_child(label)

	return block


func _title_font() -> Font:
	return UIFontTheme.get_font()


func _style_system_dialog(dialog: Window) -> void:
	var font := _title_font()
	if font == null:
		return
	dialog.add_theme_font_override("font", font)
	dialog.add_theme_font_size_override("font_size", 24)


func _make_menu_button(label_text: String) -> Button:
	var button := Button.new()
	button.custom_minimum_size = MENU_BUTTON_SIZE
	button.size_flags_horizontal = Control.SIZE_SHRINK_CENTER
	button.text = label_text
	button.add_theme_font_size_override("font_size", MENU_FONT_SIZE)
	button.add_theme_font_override("font", _title_font())

	var normal := StyleBoxFlat.new()
	normal.bg_color = Color(0.98, 0.95, 0.9, 0.94)
	normal.border_color = Color(0.62, 0.48, 0.34, 0.75)
	normal.set_border_width_all(3)
	normal.set_corner_radius_all(24)
	normal.content_margin_left = 28
	normal.content_margin_right = 28
	normal.shadow_color = Color(0.12, 0.08, 0.04, 0.14)
	normal.shadow_size = 6
	normal.shadow_offset = Vector2(0, 2)

	var hover := normal.duplicate()
	hover.bg_color = Color(1.0, 0.98, 0.94, 0.98)
	hover.border_color = Color(0.72, 0.56, 0.38, 0.9)
	hover.shadow_size = 8

	var pressed := normal.duplicate()
	pressed.bg_color = Color(0.93, 0.88, 0.78, 1.0)
	pressed.shadow_size = 2

	var disabled := normal.duplicate()
	disabled.bg_color = Color(0.92, 0.9, 0.84, 0.72)
	disabled.border_color = Color(0.72, 0.66, 0.58, 0.45)

	button.add_theme_stylebox_override("normal", normal)
	button.add_theme_stylebox_override("hover", hover)
	button.add_theme_stylebox_override("pressed", pressed)
	button.add_theme_stylebox_override("focus", hover)
	button.add_theme_stylebox_override("disabled", disabled)
	button.add_theme_color_override("font_color", Color(0.24, 0.16, 0.1))
	button.add_theme_color_override("font_hover_color", Color(0.18, 0.12, 0.08))
	button.add_theme_color_override("font_disabled_color", Color(0.46, 0.4, 0.34))
	button.add_theme_color_override("font_outline_color", Color(0.98, 0.95, 0.88, 0.0))
	button.add_theme_constant_override("outline_size", 0)

	button.mouse_entered.connect(func() -> void:
		button.pivot_offset = button.size * 0.5
		button.scale = Vector2(1.05, 1.05)
	)
	button.mouse_exited.connect(func() -> void:
		button.scale = Vector2.ONE
	)
	_menu_buttons.append(button)
	return button


func _refresh_save_state() -> void:
	GameState.ensure_save_migrated()
	_continue_button.disabled = not GameState.has_save_file()


func _on_continue_pressed() -> void:
	AmbientAudio.ensure_unlocked()
	BgmDirector.ensure_unlocked()
	if not GameState.ensure_save_migrated():
		_refresh_save_state()
		return
	GameState.continue_from_save()
	GameState.pop_time_pause()
	get_tree().change_scene_to_file(MAIN_SCENE)


func _on_new_game_pressed() -> void:
	if GameState.has_save_file():
		var dialog := ConfirmationDialog.new()
		dialog.title = "开始新游戏"
		dialog.dialog_text = "这将删除当前存档，从第一天重新开始。确定吗？"
		dialog.ok_button_text = "确定"
		dialog.cancel_button_text = "取消"
		add_child(dialog)
		dialog.confirmed.connect(func() -> void:
			dialog.queue_free()
			_start_new_game_confirmed()
		)
		dialog.canceled.connect(dialog.queue_free)
		dialog.close_requested.connect(dialog.queue_free)
		_style_system_dialog(dialog)
		dialog.popup_centered()
		return
	_start_new_game_confirmed()


func _start_new_game_confirmed() -> void:
	AmbientAudio.ensure_unlocked()
	BgmDirector.ensure_unlocked()
	GameState.start_new_game_fresh()
	GameState.pop_time_pause()
	get_tree().change_scene_to_file(MAIN_SCENE)


func _on_exit_pressed() -> void:
	get_tree().quit()
