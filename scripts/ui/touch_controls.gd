extends CanvasLayer
## 触屏 / 窄窗 Web：左侧浮动摇杆（按下才出现）+ 右下互动键。桌面 Web 不显示。

const LAYER := 15
const JOY_RADIUS := 72.0
const KNOB_RADIUS := 28.0
const DEADZONE := 0.14
const INTERACT_BTN_SIZE := Vector2(112, 112)
const CHAT_PANEL_HEIGHT := 292.0
const BOTTOM_UI_MARGIN := 36.0
const LEFT_STICK_WIDTH_RATIO := 0.52

var move_vector := Vector2.ZERO

var _root: Control
var _stick_wrap: Control
var _joy_base: Panel
var _joy_knob: Panel
var _interact_btn: Button
var _pointer_id := -1
var _stick_center := Vector2.ZERO
var _stick_active := false
var _visible_in_game := false


func _ready() -> void:
	layer = LAYER
	process_mode = Node.PROCESS_MODE_ALWAYS
	set_process_input(true)
	_build_ui()
	_sync_layout()
	var tree := get_tree()
	if tree.root != null and not tree.root.size_changed.is_connected(_on_viewport_resized):
		tree.root.size_changed.connect(_on_viewport_resized)
	if not tree.scene_changed.is_connected(_on_scene_changed):
		tree.scene_changed.connect(_on_scene_changed)
	call_deferred("_on_scene_changed")


func _on_viewport_resized() -> void:
	_sync_layout()
	_update_visibility()


func get_move_vector() -> Vector2:
	if not _stick_active:
		return Vector2.ZERO
	return move_vector


func _should_show() -> bool:
	if not _visible_in_game:
		return false
	if DisplayServer.is_touchscreen_available():
		return true
	if not OS.has_feature("web"):
		return false
	var vp := get_viewport().get_visible_rect().size
	# 仅窄窗 / 竖屏等手机式布局启用；桌面全屏 Web 走键鼠
	return vp.x < 1200.0 or vp.y < 820.0 or vp.y > vp.x * 1.05


func _on_scene_changed() -> void:
	var scene := get_tree().current_scene
	_visible_in_game = scene != null and scene.name == "Main"
	_update_visibility()
	_reset_joystick()


func _update_visibility() -> void:
	if _root == null:
		return
	var show := _should_show()
	set_process_input(show)
	_root.visible = show
	_interact_btn.visible = show
	if not show:
		_reset_joystick()
	elif not _stick_active:
		_stick_wrap.visible = false


func _build_ui() -> void:
	_root = Control.new()
	_root.name = "TouchControlsRoot"
	_root.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	_root.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(_root)

	_stick_wrap = Control.new()
	_stick_wrap.name = "StickWrap"
	_stick_wrap.visible = false
	_stick_wrap.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_root.add_child(_stick_wrap)

	_joy_base = Panel.new()
	_joy_base.name = "JoyBase"
	_joy_base.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_joy_base.custom_minimum_size = Vector2(JOY_RADIUS * 2.0, JOY_RADIUS * 2.0)
	_apply_disc_style(_joy_base, Color(0.98, 0.95, 0.88, 0.42), Color(0.72, 0.58, 0.42, 0.55))
	_stick_wrap.add_child(_joy_base)

	_joy_knob = Panel.new()
	_joy_knob.name = "JoyKnob"
	_joy_knob.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_joy_knob.custom_minimum_size = Vector2(KNOB_RADIUS * 2.0, KNOB_RADIUS * 2.0)
	_apply_disc_style(_joy_knob, Color(0.98, 0.95, 0.88, 0.88), Color(0.62, 0.48, 0.34, 0.75))
	_stick_wrap.add_child(_joy_knob)

	_interact_btn = Button.new()
	_interact_btn.name = "Interact"
	_interact_btn.text = "互动"
	_interact_btn.custom_minimum_size = INTERACT_BTN_SIZE
	_interact_btn.add_theme_font_size_override("font_size", 22)
	var font := UIFontTheme.get_font()
	if font != null:
		_interact_btn.add_theme_font_override("font", font)
	var btn_style := StyleBoxFlat.new()
	btn_style.bg_color = Color(0.98, 0.95, 0.88, 0.88)
	btn_style.border_color = Color(0.62, 0.48, 0.34, 0.75)
	btn_style.set_border_width_all(3)
	btn_style.set_corner_radius_all(56)
	btn_style.content_margin_left = 12
	btn_style.content_margin_right = 12
	_interact_btn.add_theme_stylebox_override("normal", btn_style)
	var hover := btn_style.duplicate()
	hover.bg_color = Color(1.0, 0.98, 0.94, 0.96)
	_interact_btn.add_theme_stylebox_override("hover", hover)
	_interact_btn.add_theme_stylebox_override("pressed", hover)
	_interact_btn.add_theme_color_override("font_color", Color(0.24, 0.16, 0.1))
	_interact_btn.pressed.connect(_on_interact_pressed)
	_root.add_child(_interact_btn)

	_update_visibility()


func _apply_disc_style(panel: Panel, fill: Color, border: Color) -> void:
	var style := StyleBoxFlat.new()
	style.bg_color = fill
	style.border_color = border
	style.set_border_width_all(2)
	style.set_corner_radius_all(int(panel.custom_minimum_size.x * 0.5))
	panel.add_theme_stylebox_override("panel", style)


func _sync_layout() -> void:
	if _root == null:
		return
	var vp := get_viewport().get_visible_rect().size
	var chat_top := vp.y - CHAT_PANEL_HEIGHT - BOTTOM_UI_MARGIN
	_interact_btn.position = Vector2(
		vp.x - INTERACT_BTN_SIZE.x - 28.0,
		chat_top - INTERACT_BTN_SIZE.y - 8.0
	)
	if _stick_active:
		_place_stick_visual(_stick_center)
	_update_visibility()


func _input(event: InputEvent) -> void:
	if not _should_show():
		return
	if _interact_btn != null and _interact_btn.get_global_rect().has_point(_event_pos(event)):
		return

	if event is InputEventScreenTouch:
		_handle_screen_touch(event as InputEventScreenTouch)
	elif event is InputEventScreenDrag:
		_handle_screen_drag(event as InputEventScreenDrag)
	elif event is InputEventMouseButton and event.button_index == MOUSE_BUTTON_LEFT:
		_handle_mouse_button(event as InputEventMouseButton)
	elif event is InputEventMouseMotion:
		_handle_mouse_motion(event as InputEventMouseMotion)


func _handle_screen_touch(event: InputEventScreenTouch) -> void:
	if event.pressed:
		if _pointer_id != -1:
			return
		var pos := _event_pos(event)
		if not _can_start_stick(pos):
			return
		_begin_stick(pos, event.index)
	else:
		if event.index == _pointer_id:
			_reset_joystick()


func _handle_screen_drag(event: InputEventScreenDrag) -> void:
	if event.index != _pointer_id:
		return
	_update_stick(_event_pos(event))


func _handle_mouse_button(event: InputEventMouseButton) -> void:
	# Web / 部分手机浏览器把触摸模拟成鼠标
	if event.pressed:
		if _pointer_id != -1:
			return
		var pos := _event_pos(event)
		if not _can_start_stick(pos):
			return
		_begin_stick(pos, 1000)
	else:
		if _pointer_id == 1000:
			_reset_joystick()


func _handle_mouse_motion(event: InputEventMouseMotion) -> void:
	if _pointer_id != 1000:
		return
	if (event.button_mask & MOUSE_BUTTON_MASK_LEFT) == 0:
		_reset_joystick()
		return
	_update_stick(_event_pos(event))


func _event_pos(event: InputEvent) -> Vector2:
	if event is InputEventMouse:
		return (event as InputEventMouse).position
	if "position" in event:
		return event.position
	return Vector2.ZERO


func _can_start_stick(pos: Vector2) -> bool:
	var vp := get_viewport().get_visible_rect().size
	var chat_top := vp.y - CHAT_PANEL_HEIGHT - BOTTOM_UI_MARGIN
	if pos.y >= chat_top:
		return false
	if pos.x > vp.x * LEFT_STICK_WIDTH_RATIO:
		return false
	return true


func _begin_stick(pos: Vector2, pointer_id: int) -> void:
	_pointer_id = pointer_id
	_stick_active = true
	_stick_center = pos
	_place_stick_visual(pos)
	_update_stick(pos)
	_stick_wrap.visible = true
	_release_chat_focus()
	AmbientAudio.ensure_unlocked()
	BgmDirector.ensure_unlocked()
	get_viewport().set_input_as_handled()


func _place_stick_visual(center: Vector2) -> void:
	_stick_wrap.position = center - Vector2(JOY_RADIUS, JOY_RADIUS)
	_stick_wrap.size = Vector2(JOY_RADIUS * 2.0, JOY_RADIUS * 2.0)
	_joy_base.position = Vector2.ZERO
	_reset_knob_visual()


func _update_stick(pos: Vector2) -> void:
	if not _stick_active:
		return
	var delta := pos - _stick_center
	if delta.length() > JOY_RADIUS:
		delta = delta.normalized() * JOY_RADIUS
	_joy_knob.position = Vector2(JOY_RADIUS, JOY_RADIUS) + delta - _joy_knob.custom_minimum_size * 0.5
	var norm := delta / JOY_RADIUS
	if norm.length() < DEADZONE:
		move_vector = Vector2.ZERO
	else:
		move_vector = norm.normalized() * ((norm.length() - DEADZONE) / (1.0 - DEADZONE))


func _reset_knob_visual() -> void:
	_joy_knob.position = Vector2(JOY_RADIUS, JOY_RADIUS) - _joy_knob.custom_minimum_size * 0.5


func _reset_joystick() -> void:
	_pointer_id = -1
	_stick_active = false
	move_vector = Vector2.ZERO
	if _stick_wrap != null:
		_stick_wrap.visible = false
	_reset_knob_visual()


func _release_chat_focus() -> void:
	var focus := get_viewport().gui_get_focus_owner()
	if focus is LineEdit:
		focus.release_focus()


func _on_interact_pressed() -> void:
	AmbientAudio.ensure_unlocked()
	BgmDirector.ensure_unlocked()
	var press := InputEventAction.new()
	press.action = "interact"
	press.pressed = true
	Input.parse_input_event(press)
	var release := InputEventAction.new()
	release.action = "interact"
	release.pressed = false
	Input.parse_input_event(release)
