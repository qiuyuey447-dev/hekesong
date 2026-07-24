extends Node2D
## 世界空间雨效：雨滴从视野上方生成，落在地面与角色身上。

const RainSplashScript := preload("res://scripts/world/rain_splash.gd")

const DROP_COUNT := 360
const MAX_SPLASH_NODES := 100
const WIND := Vector2(88.0, 480.0)

var _active := false
var _drops: Array[Dictionary] = []
var _splash_root: Node2D
var _splash_count := 0
var _night_factor := 1.0


func _ready() -> void:
	set_process(false)
	top_level = true
	z_index = 4096
	z_as_relative = false


func configure(splash_root: Node2D) -> void:
	_splash_root = splash_root


func set_raining(on: bool) -> void:
	_active = on
	visible = on
	set_process(on)
	if on:
		_reset_drops()
	else:
		_clear_splashes()
	queue_redraw()


func set_night_factor(f: float) -> void:
	_night_factor = clampf(f, 0.55, 1.0)


func _process(delta: float) -> void:
	if not _active:
		return
	var view := _camera_world_rect()
	var keep_rect := view.grow(280.0)

	for drop in _drops:
		var pos: Vector2 = drop["pos"]
		var prev_y: float = drop.get("prev_y", pos.y)
		pos += WIND * delta * drop.get("speed", 1.0)
		var hit := _resolve_hit(pos, prev_y)
		if hit != Vector2.INF:
			_spawn_splash(hit)
			_respawn_drop(drop, view)
		elif not keep_rect.has_point(pos):
			_respawn_drop(drop, view)
		else:
			drop["prev_y"] = pos.y
			drop["pos"] = pos

	queue_redraw()


func _draw() -> void:
	if not _active:
		return
	var streak_color := Color(0.78, 0.88, 1.0, 0.82 * _night_factor)
	for drop in _drops:
		var g_pos: Vector2 = drop["pos"]
		var seg: float = drop["seg"]
		var end := g_pos + Vector2(seg * 0.36, seg)
		draw_line(g_pos, end, streak_color, 2.0)


func _camera_world_rect() -> Rect2:
	var vp := get_viewport()
	if vp == null:
		return Rect2(-480, -270, 960, 540)
	var inv := vp.get_canvas_transform().affine_inverse()
	var p0 := inv * Vector2.ZERO
	var p1 := inv * vp.get_visible_rect().size
	return Rect2(p0, p1 - p0)


func _reset_drops() -> void:
	_drops.clear()
	var view := _camera_world_rect()
	for i in DROP_COUNT:
		var drop := {}
		_respawn_drop(drop, view)
		_drops.append(drop)


func _respawn_drop(drop: Dictionary, view: Rect2) -> void:
	var pos := _random_air_position(view)
	drop["pos"] = pos
	drop["prev_y"] = pos.y
	drop["seg"] = randf_range(12.0, 22.0)
	drop["speed"] = randf_range(0.85, 1.15)


func _random_air_position(view: Rect2) -> Vector2:
	# 在整个可见区域内均匀随机；雨丝可穿过画面任意高度，落地判定只用于溅点。
	var x := randf_range(view.position.x - 48.0, view.end.x + 48.0)
	var y := randf_range(view.position.y - 40.0, view.end.y + 24.0)
	return Vector2(x, y)


func _resolve_hit(pos: Vector2, prev_y: float) -> Vector2:
	var feet := _character_feet_at(pos, prev_y)
	if feet != Vector2.INF:
		return feet
	var ground_y := _ground_surface_y(pos.x, minf(prev_y, pos.y))
	if prev_y <= ground_y and pos.y >= ground_y:
		return Vector2(pos.x, ground_y - 1.0)
	return Vector2.INF


func _character_feet_at(pos: Vector2, prev_y: float) -> Vector2:
	for node in get_tree().get_nodes_in_group("rain_target"):
		if not node is Node2D:
			continue
		var n := node as Node2D
		if not n.is_inside_tree():
			continue
		var feet := n.global_position
		if node.has_method("get_rain_feet_position"):
			feet = node.call("get_rain_feet_position")
		var half_w := 16.0 * n.scale.x
		if node.is_in_group("player"):
			half_w = 20.0 * n.scale.x
		var top_y := feet.y - 40.0 * n.scale.y
		if pos.x < feet.x - half_w or pos.x > feet.x + half_w:
			continue
		if prev_y <= feet.y and pos.y >= top_y:
			return Vector2(pos.x, feet.y - 2.0)
	return Vector2.INF


func _ground_surface_y(world_x: float, from_y: float) -> float:
	var world := get_tree().get_first_node_in_group("farm_world")
	if world != null and world.has_method("get_ground_surface_y_at"):
		return world.call("get_ground_surface_y_at", world_x, from_y)
	if world != null and world.has_method("has_ground_at"):
		var y := from_y
		for _i in 100:
			if world.call("has_ground_at", Vector2(world_x, y)):
				return y
			y += 5.0
	return from_y + 400.0


func _spawn_splash(world_pos: Vector2) -> void:
	if _splash_root == null or not is_instance_valid(_splash_root):
		return
	if _splash_count >= MAX_SPLASH_NODES:
		return
	var splash: Node2D = RainSplashScript.new()
	_splash_root.add_child(splash)
	splash.setup(world_pos, randf_range(0.14, 0.28))
	_splash_count += 1
	splash.tree_exited.connect(func(): _splash_count = maxi(_splash_count - 1, 0))


func _clear_splashes() -> void:
	if _splash_root == null:
		return
	for child in _splash_root.get_children():
		child.queue_free()
	_splash_count = 0
