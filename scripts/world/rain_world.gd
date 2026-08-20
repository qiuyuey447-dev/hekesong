extends Node2D
## 世界空间雨效：雨滴从视野上方生成，落在地面与角色身上。

const RainSplashScript := preload("res://scripts/world/rain_splash.gd")

const DROP_COUNT := 360
const DROP_COUNT_WEB := 88
const MAX_SPLASH_NODES := 100
const MAX_SPLASH_WEB := 16
const WIND := Vector2(88.0, 480.0)
const GROUND_CACHE_STEP := 32.0
const CACHE_REFRESH_SEC := 0.2

var _active := false
var _drops: Array[Dictionary] = []
var _splash_root: Node2D
var _splash_count := 0
var _night_factor := 1.0
var _farm: Node
var _shelter := Rect2()
var _rain_targets: Array = []
var _ground_y_cache: Dictionary = {}
var _cache_age := 0.0
var _splash_skip := 0
var _is_web := false


func _ready() -> void:
	_is_web = OS.has_feature("web")
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
		_refresh_world_cache()
		_reset_drops()
	else:
		_clear_splashes()
	queue_redraw()


func set_night_factor(f: float) -> void:
	_night_factor = clampf(f, 0.55, 1.0)


func _drop_count() -> int:
	return DROP_COUNT_WEB if _is_web else DROP_COUNT


func _splash_cap() -> int:
	return MAX_SPLASH_WEB if _is_web else MAX_SPLASH_NODES


func _process(delta: float) -> void:
	if not _active:
		return
	_cache_age += delta
	if _cache_age >= CACHE_REFRESH_SEC or _farm == null:
		_refresh_world_cache()
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


func _refresh_world_cache() -> void:
	_cache_age = 0.0
	_ground_y_cache.clear()
	var tree := get_tree()
	if tree == null:
		return
	_farm = tree.get_first_node_in_group("farm_world")
	if _farm != null and _farm.has_method("get_farm_map"):
		var farm_map: Node2D = _farm.call("get_farm_map")
		_shelter = FarmSetdress.porch_shelter_rect(farm_map)
	else:
		_shelter = Rect2()
	_rain_targets = tree.get_nodes_in_group("rain_target")


func _draw() -> void:
	if not _active:
		return
	var streak_color := Color(0.78, 0.88, 1.0, 0.82 * _night_factor)
	for drop in _drops:
		var g_pos: Vector2 = drop["pos"]
		var seg: float = drop["seg"]
		var end := g_pos + Vector2(seg * 0.36, seg)
		draw_line(g_pos, end, streak_color, 1.0 if _is_web else 2.0)


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
	for i in _drop_count():
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
	if _is_sheltered(Vector2(pos.x, pos.y)):
		return Vector2.INF
	var feet := _character_feet_at(pos, prev_y)
	if feet != Vector2.INF:
		return feet
	var ground_y := _ground_surface_y(pos.x, minf(prev_y, pos.y))
	if prev_y <= ground_y and pos.y >= ground_y:
		return Vector2(pos.x, ground_y - 1.0)
	return Vector2.INF


func _is_sheltered(world_pos: Vector2) -> bool:
	if _shelter.size != Vector2.ZERO:
		return _shelter.has_point(world_pos)
	return false


func _character_feet_at(pos: Vector2, prev_y: float) -> Vector2:
	for node in _rain_targets:
		if not node is Node2D:
			continue
		var n := node as Node2D
		if not is_instance_valid(n) or not n.is_inside_tree():
			continue
		var feet := n.global_position
		if n.has_method("get_rain_feet_position"):
			feet = n.call("get_rain_feet_position")
		if _is_sheltered(feet):
			continue
		var half_w := 16.0 * n.scale.x
		if n.is_in_group("player"):
			half_w = 20.0 * n.scale.x
		var top_y := feet.y - 40.0 * n.scale.y
		if pos.x < feet.x - half_w or pos.x > feet.x + half_w:
			continue
		if prev_y <= feet.y and pos.y >= top_y:
			return Vector2(pos.x, feet.y - 2.0)
	return Vector2.INF


func _ground_surface_y(world_x: float, from_y: float) -> float:
	var key := int(floor(world_x / GROUND_CACHE_STEP))
	if _ground_y_cache.has(key):
		return float(_ground_y_cache[key])
	var y := from_y + 400.0
	if _farm != null and _farm.has_method("get_ground_surface_y_at"):
		y = float(_farm.call("get_ground_surface_y_at", world_x, from_y))
	_ground_y_cache[key] = y
	return y


func _spawn_splash(world_pos: Vector2) -> void:
	if _splash_root == null or not is_instance_valid(_splash_root):
		return
	if _splash_count >= _splash_cap():
		return
	if _is_web:
		_splash_skip += 1
		if _splash_skip % 3 != 0:
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
