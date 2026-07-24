extends CharacterBody2D

const WALK_ATLAS: Texture2D = preload("res://Characters/Farm/farm_walk_atlas_32x32.png")

const MOVE_SPEED := 240.0
const INTERACT_RANGE := 64.0
const PLOT_HOVER_RANGE := 30.0
const FRAME_SIZE := Vector2i(32, 32)

@onready var _shadow: Sprite2D = $Shadow
@onready var _anim: AnimatedSprite2D = $AnimatedSprite2D
@onready var _camera: Camera2D = $Camera2D

var _facing := "down"
var _focused_plot: FarmPlot = null
var _movement_locked := false


func _ready() -> void:
	add_to_group("player")
	add_to_group("rain_target")
	scale = Vector2(2, 2)
	_setup_shadow()
	_setup_animation()
	_camera.enabled = true
	_camera.position_smoothing_enabled = true
	_camera.position_smoothing_speed = 8.0
	_camera.zoom = Vector2(2.0, 2.0)


func sync_world_position() -> void:
	pass


func is_moving() -> bool:
	var input_dir := Input.get_vector("move_left", "move_right", "move_up", "move_down")
	if input_dir != Vector2.ZERO:
		return true
	return velocity.length() > 8.0


func get_rain_feet_position() -> Vector2:
	return get_feet_position()


func get_feet_position() -> Vector2:
	return global_position + Vector2(0, 8)


func _physics_process(_delta: float) -> void:
	if _movement_locked:
		velocity = Vector2.ZERO
		_anim.stop()
		_anim.frame = 0
		move_and_slide()
		_update_plot_hover()
		_update_interact_cursor()
		return

	var input_dir := Input.get_vector("move_left", "move_right", "move_up", "move_down")
	if input_dir != Vector2.ZERO:
		velocity = input_dir.normalized() * MOVE_SPEED
		_update_facing(input_dir)
		_anim.play(_facing)
	else:
		velocity = Vector2.ZERO
		_anim.stop()
		_anim.frame = 0

	move_and_slide()
	_update_plot_hover()
	_update_interact_cursor()


func _update_interact_cursor() -> void:
	if _focused_plot != null and _focused_plot.should_show_interaction_hint():
		InteractCursor.set_from_highlight_style(_focused_plot.get_interaction_style())
		return
	var hollow := _find_tree_hollow_in_range()
	if hollow != null and hollow.has_method("should_show_interaction_hint") and hollow.should_show_interaction_hint():
		if hollow.has_method("get_interaction_style"):
			InteractCursor.set_from_highlight_style(hollow.get_interaction_style())
		else:
			InteractCursor.set_mode(InteractCursor.Mode.INTERACT)
		return
	var target := _find_nearest_interactable()
	if target != null and target.global_position.distance_to(global_position) <= INTERACT_RANGE:
		if target is FarmPlot:
			var plot := target as FarmPlot
			if plot.should_show_interaction_hint():
				InteractCursor.set_from_highlight_style(plot.get_interaction_style())
				return
		if target.is_in_group("shop_interact") or target.is_in_group("companion_interact") or target.is_in_group("door_interact"):
			InteractCursor.set_mode(InteractCursor.Mode.INTERACT)
			return
		if target.is_in_group("tree_hollow_interact") and target.has_method("should_show_night_hint") and target.should_show_night_hint():
			InteractCursor.set_mode(InteractCursor.Mode.INTERACT)
			return
	InteractCursor.reset()


func _update_plot_hover() -> void:
	var best: FarmPlot = null
	var best_dist := PLOT_HOVER_RANGE
	for node in get_tree().get_nodes_in_group("farm_plot"):
		if not node is FarmPlot:
			continue
		var plot := node as FarmPlot
		if not plot.should_show_interaction_hint():
			continue
		var dist := global_position.distance_to(plot.global_position)
		if dist <= PLOT_HOVER_RANGE and (best == null or dist < best_dist):
			best_dist = dist
			best = plot

	if best == _focused_plot:
		return

	if _focused_plot != null:
		_focused_plot.set_hover_focused(false)
	_focused_plot = best
	if _focused_plot != null:
		_focused_plot.set_hover_focused(true)


func _setup_shadow() -> void:
	var img := Image.create(24, 8, false, Image.FORMAT_RGBA8)
	img.fill(Color(0, 0, 0, 0))
	for y in range(8):
		for x in range(24):
			var dx := (x - 12.0) / 12.0
			var dy := (y - 4.0) / 4.0
			if dx * dx + dy * dy <= 1.0:
				img.set_pixel(x, y, Color(0, 0, 0, 0.24))
	_shadow.texture = ImageTexture.create_from_image(img)
	_shadow.texture_filter = CanvasItem.TEXTURE_FILTER_NEAREST
	_shadow.centered = true
	_shadow.position = Vector2(0, 2)
	_shadow.z_index = -1


func _setup_animation() -> void:
	var frames := SpriteFrames.new()
	var directions := ["down", "left", "right", "up"]
	for row in range(directions.size()):
		var anim_name: String = directions[row]
		frames.add_animation(anim_name)
		frames.set_animation_speed(anim_name, 8.0)
		frames.set_animation_loop(anim_name, true)
		for col in range(4):
			var atlas := AtlasTexture.new()
			atlas.atlas = WALK_ATLAS
			atlas.region = Rect2(col * FRAME_SIZE.x, row * FRAME_SIZE.y, FRAME_SIZE.x, FRAME_SIZE.y)
			frames.add_frame(anim_name, atlas)

	_anim.sprite_frames = frames
	_anim.texture_filter = CanvasItem.TEXTURE_FILTER_NEAREST
	_anim.centered = false
	_anim.offset = Vector2(-16, -28)
	_anim.play("down")


func _update_facing(input_dir: Vector2) -> void:
	if absf(input_dir.x) > absf(input_dir.y):
		_facing = "right" if input_dir.x > 0.0 else "left"
	else:
		_facing = "down" if input_dir.y > 0.0 else "up"


func set_movement_locked(locked: bool) -> void:
	_movement_locked = locked
	if locked:
		velocity = Vector2.ZERO


func set_snuggle_facing(facing: String) -> void:
	if facing.strip_edges() != "":
		_facing = facing
	if _anim != null and _anim.sprite_frames != null and _anim.sprite_frames.has_animation(_facing):
		_anim.play(_facing)
		_anim.stop()
		_anim.frame = 0


func is_movement_locked() -> bool:
	return _movement_locked


func _unhandled_input(event: InputEvent) -> void:
	if _movement_locked:
		return
	if event.is_action_pressed("interact"):
		_try_interact()
		return
	if event is InputEventMouseButton and event.pressed and event.button_index == MOUSE_BUTTON_LEFT:
		_try_interact()


func _try_interact() -> void:
	if _try_tree_hollow_interact():
		return
	if _focused_plot != null and _focused_plot.should_show_interaction_hint():
		if global_position.distance_to(_focused_plot.global_position) <= INTERACT_RANGE:
			_focused_plot.activate()
			return

	var target := _find_nearest_interactable()
	if target == null:
		return

	if target.has_method("activate"):
		target.call("activate")
		return

	if target is FarmPlot:
		var plot := target as FarmPlot
		get_tree().call_group("main_ui", "on_plot_clicked", plot.plot_id, plot.global_position)
	elif target.is_in_group("door_interact"):
		get_tree().call_group("main_ui", "on_door_clicked")
	elif target.is_in_group("companion_interact"):
		get_tree().call_group("main_ui", "on_companion_clicked")
	elif target.is_in_group("shop_interact"):
		get_tree().call_group("main_ui", "on_shop_clicked")
	elif target.is_in_group("tree_hollow_interact"):
		get_tree().call_group("main_ui", "on_tree_hollow_clicked")


func _try_tree_hollow_interact() -> bool:
	var best: Node2D = null
	var best_dist := 9999.0
	for node in get_tree().get_nodes_in_group("tree_hollow_interact"):
		if not node is Node2D:
			continue
		var hollow := node as Node2D
		var center := hollow.global_position
		if hollow.has_method("get_interact_center"):
			center = hollow.call("get_interact_center")
		var dist := global_position.distance_to(center)
		var range_limit := 96.0 if StoryBeatDirector.has_pending_night_beat() else 64.0
		if dist > range_limit:
			continue
		if best == null or dist < best_dist:
			best_dist = dist
			best = hollow
	if best != null and best.has_method("activate"):
		best.activate()
		return true
	return false


func _find_tree_hollow_in_range() -> Node2D:
	var best: Node2D = null
	var best_dist := 9999.0
	for node in get_tree().get_nodes_in_group("tree_hollow_interact"):
		if not node is Node2D:
			continue
		var hollow := node as Node2D
		if hollow.has_method("should_show_interaction_hint") and not hollow.should_show_interaction_hint():
			continue
		var center := hollow.global_position
		if hollow.has_method("get_interact_center"):
			center = hollow.call("get_interact_center")
		var dist := global_position.distance_to(center)
		var range_limit := 96.0 if StoryBeatDirector.has_pending_night_beat() else 72.0
		if dist > range_limit:
			continue
		if best == null or dist < best_dist:
			best_dist = dist
			best = hollow
	return best


func _find_nearest_interactable() -> Node2D:
	var best: Node2D = null
	var best_dist := INTERACT_RANGE

	for node in get_tree().get_nodes_in_group("interactable"):
		if not node is Node2D:
			continue
		if node.is_in_group("tree_hollow_interact"):
			continue
		var dist := global_position.distance_to((node as Node2D).global_position)
		if dist <= INTERACT_RANGE and (best == null or dist < best_dist):
			best_dist = dist
			best = node

	return best
