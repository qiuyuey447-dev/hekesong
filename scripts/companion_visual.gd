extends Area2D

const COMPANION_TEXTURE: Texture2D = preload("res://Characters/Animals/fox2_16x20.png")
const COMPANION_FRAME := Vector2i(16, 20)

const WANDER_MOVE_SPEED := 36.0
const TASK_MOVE_SPEED := 92.0
const WANDER_ANIM_FPS := 4.0
const TASK_ANIM_FPS := 9.0
const IDLE_WAG_FPS := 2.8
const WANDER_BOB_AMOUNT := 1.4
const IDLE_WAG_INTERVAL_MIN := 6.0
const IDLE_WAG_INTERVAL_MAX := 14.0

enum MovePace { WANDER, TASK }

const WALK_ANIMS := {
	"down": "walk_down",
	"up": "walk_up",
	"left": "walk_left",
	"right": "walk_right",
}

const STAND_ANIMS := {
	"down": "stand_down",
	"up": "stand_up",
	"left": "stand_left",
	"right": "stand_right",
}

var _anim: AnimatedSprite2D
var _bubble: PanelContainer
var _bubble_label: Label
var _move_target := Vector2.ZERO
var _arrive_distance := 6.0
var _move_callback: Callable = Callable()
var _moving := false
var _move_pace := MovePace.WANDER
var _facing := "down"
var _walk_anim := ""
var _walk_phase := 0.0
var _anim_base_y := 0.0
var _idle_wag_cooldown := 3.0
var _force_stand := false


func _ready() -> void:
	add_to_group("interactable")
	add_to_group("companion_interact")
	add_to_group("rain_target")
	scale = Vector2(2, 2)
	_build_visual()
	_build_status_bubble()
	InteractHover.attach(
		self,
		COMPANION_FRAME,
		Vector2(0, -8),
		80.0,
		0.0,
		0.0,
		2.5
	)


func _process(delta: float) -> void:
	if not _moving:
		_tick_idle(delta)
		return

	var offset := _move_target - global_position
	var distance := offset.length()
	if distance <= _arrive_distance:
		global_position = _move_target
		_stop_move(true)
		return

	var speed := TASK_MOVE_SPEED if _move_pace == MovePace.TASK else WANDER_MOVE_SPEED
	var step := offset.normalized() * speed * delta
	if step.length() > distance:
		step = offset
	global_position += step

	_force_stand = false
	_update_walk_animation(step)
	_apply_walk_bob(delta)


func activate() -> void:
	if not _is_player_near():
		get_tree().call_group("main_ui", "on_need_closer")
		return
	get_tree().call_group("main_ui", "on_companion_clicked")


func get_rain_feet_position() -> Vector2:
	return get_feet_position()


func get_feet_position() -> Vector2:
	return global_position + Vector2(0, 6)


func is_moving() -> bool:
	return _moving


func move_to(target: Vector2, arrive_distance: float, on_arrived: Callable, urgent: bool = false) -> void:
	_move_target = target
	_arrive_distance = maxf(arrive_distance, 2.0)
	_move_callback = on_arrived
	_move_pace = MovePace.TASK if urgent else MovePace.WANDER
	_moving = true
	_force_stand = false
	_walk_phase = 0.0
	_start_walk_from_facing()


func cancel_move() -> void:
	_stop_move(false)


func play_stand_still(facing: String = "") -> void:
	if facing != "":
		_facing = facing
	_force_stand = true
	_show_stand_frame()


func show_status_bubble(text: String) -> void:
	if _bubble == null:
		_build_status_bubble()
	_bubble_label.text = text
	_bubble.visible = not text.is_empty()


func hide_status_bubble() -> void:
	if _bubble != null:
		_bubble.visible = false


func _stop_move(call_callback: bool) -> void:
	_moving = false
	_play_stand_still()
	if call_callback and _move_callback.is_valid():
		_move_callback.call()
	_move_callback = Callable()


func _build_visual() -> void:
	var shadow := Sprite2D.new()
	var shadow_img := Image.create(22, 8, false, Image.FORMAT_RGBA8)
	shadow_img.fill(Color(0, 0, 0, 0))
	for y in range(8):
		for x in range(22):
			var dx := (x - 11.0) / 11.0
			var dy := (y - 4.0) / 4.0
			if dx * dx + dy * dy <= 1.0:
				shadow_img.set_pixel(x, y, Color(0, 0, 0, 0.22))
	shadow.texture = ImageTexture.create_from_image(shadow_img)
	shadow.texture_filter = CanvasItem.TEXTURE_FILTER_NEAREST
	shadow.centered = true
	shadow.position = Vector2(0, 2)
	shadow.z_index = -1
	add_child(shadow)

	_anim = AnimatedSprite2D.new()
	_anim.texture_filter = CanvasItem.TEXTURE_FILTER_NEAREST
	_anim.centered = false
	_anim.offset = Vector2(-8, -18)
	_anim_base_y = _anim.position.y
	_setup_sprite_frames()
	add_child(_anim)
	_play_stand_still()

	var label := Label.new()
	label.text = GameState.companion_name
	label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	label.add_theme_color_override("font_outline_color", Color(0.12, 0.12, 0.12))
	label.add_theme_constant_override("outline_size", 3)
	label.add_theme_font_size_override("font_size", 12)
	label.position = Vector2(-28, -36)
	label.size = Vector2(56, 18)
	add_child(label)


func _setup_sprite_frames() -> void:
	var frames := SpriteFrames.new()
	var row_names: Array[String] = ["down", "left", "right", "up"]

	for row in range(row_names.size()):
		var facing: String = row_names[row]
		var stand_name := "stand_%s" % facing
		frames.add_animation(stand_name)
		frames.set_animation_loop(stand_name, false)
		frames.set_animation_speed(stand_name, 1.0)
		frames.add_frame(stand_name, SpriteSheet.grid_frame(COMPANION_TEXTURE, COMPANION_FRAME, 1, row))

		var walk_name := "walk_%s" % facing
		frames.add_animation(walk_name)
		frames.set_animation_speed(walk_name, WANDER_ANIM_FPS)
		frames.set_animation_loop(walk_name, true)
		for col in range(3):
			frames.add_frame(walk_name, SpriteSheet.grid_frame(COMPANION_TEXTURE, COMPANION_FRAME, col, row))

	frames.add_animation("idle_wag")
	frames.set_animation_speed("idle_wag", IDLE_WAG_FPS)
	frames.set_animation_loop("idle_wag", true)
	for col in range(3):
		frames.add_frame("idle_wag", SpriteSheet.grid_frame(COMPANION_TEXTURE, COMPANION_FRAME, col, 0))

	_anim.sprite_frames = frames


func _build_status_bubble() -> void:
	if _bubble != null:
		return

	_bubble = PanelContainer.new()
	_bubble.visible = false
	_bubble.position = Vector2(-72, -72)
	_bubble.custom_minimum_size = Vector2(144, 0)

	var style := StyleBoxFlat.new()
	style.bg_color = Color(1.0, 1.0, 1.0, 0.94)
	style.border_color = Color(0.72, 0.72, 0.78, 1.0)
	style.set_border_width_all(1)
	style.set_corner_radius_all(10)
	style.content_margin_left = 8
	style.content_margin_right = 8
	style.content_margin_top = 5
	style.content_margin_bottom = 5
	_bubble.add_theme_stylebox_override("panel", style)

	_bubble_label = Label.new()
	_bubble_label.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	_bubble_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	_bubble_label.add_theme_font_size_override("font_size", 11)
	_bubble_label.add_theme_color_override("font_color", Color(0.18, 0.18, 0.22))
	_bubble.add_child(_bubble_label)
	add_child(_bubble)


func _facing_key(dir: Vector2) -> String:
	if dir.length_squared() < 0.0001:
		return _facing
	if absf(dir.x) > absf(dir.y):
		return "right" if dir.x > 0.0 else "left"
	return "down" if dir.y > 0.0 else "up"


func _play_walk_anim(facing: String) -> void:
	var anim_name := str(WALK_ANIMS.get(facing, "walk_down"))
	if _anim == null or _anim.sprite_frames == null:
		return
	if not _anim.sprite_frames.has_animation(anim_name):
		return
	if _walk_anim == anim_name and _anim.is_playing():
		return
	_facing = facing
	_walk_anim = anim_name
	var fps := TASK_ANIM_FPS if _move_pace == MovePace.TASK else WANDER_ANIM_FPS
	_anim.sprite_frames.set_animation_speed(anim_name, fps)
	_anim.play(anim_name)


func _play_stand_still() -> void:
	_force_stand = true
	_show_stand_frame()


func _show_stand_frame() -> void:
	if _anim == null or _anim.sprite_frames == null:
		return
	var anim_name := str(STAND_ANIMS.get(_facing, "stand_down"))
	if not _anim.sprite_frames.has_animation(anim_name):
		return
	_walk_anim = anim_name
	_anim.stop()
	_anim.animation = anim_name
	_anim.frame = 0
	_anim.position.y = _anim_base_y


func _play_idle_wag() -> void:
	if _anim == null or _anim.sprite_frames == null:
		return
	if not _anim.sprite_frames.has_animation("idle_wag"):
		return
	_facing = "down"
	_force_stand = false
	_walk_anim = "idle_wag"
	_anim.play("idle_wag")


func _tick_idle(delta: float) -> void:
	if _anim == null:
		return
	_anim.position.y = _anim_base_y

	if _force_stand:
		if _anim.animation != str(STAND_ANIMS.get(_facing, "stand_down")) or _anim.is_playing():
			_show_stand_frame()
		return

	if _anim.animation == "idle_wag" and _anim.is_playing():
		return

	_idle_wag_cooldown -= delta
	if _idle_wag_cooldown <= 0.0:
		_idle_wag_cooldown = randf_range(IDLE_WAG_INTERVAL_MIN, IDLE_WAG_INTERVAL_MAX)
		if randf() < 0.35:
			_play_idle_wag()
			return

	_play_stand_still()


func _start_walk_from_facing() -> void:
	var offset := _move_target - global_position
	var facing := _facing_key(offset)
	_play_walk_anim(facing)


func _update_walk_animation(step: Vector2) -> void:
	var facing := _facing_key(step)
	_play_walk_anim(facing)


func _apply_walk_bob(delta: float) -> void:
	if _anim == null:
		return
	if _move_pace == MovePace.WANDER:
		_walk_phase += delta * 5.0
		_anim.position.y = _anim_base_y + sin(_walk_phase) * WANDER_BOB_AMOUNT
	else:
		_walk_phase += delta * 8.5
		_anim.position.y = _anim_base_y + sin(_walk_phase) * 0.6


func _is_player_near() -> bool:
	var player := get_tree().get_first_node_in_group("player") as Node2D
	if player == null:
		return true
	return player.global_position.distance_to(global_position) <= 80.0
