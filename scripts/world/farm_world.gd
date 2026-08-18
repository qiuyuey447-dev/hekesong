extends Node2D

const PLAYER_SCENE: PackedScene = preload("res://scenes/player.tscn")
const PLOT_SCENE: PackedScene = preload("res://scenes/plot.tscn")
const COMPANION_SCENE: PackedScene = preload("res://scenes/companion.tscn")
const SHOP_SCENE: PackedScene = preload("res://scenes/shop_spot.tscn")
const TREE_HOLLOW_SCENE: PackedScene = preload("res://scenes/tree_hollow_spot.tscn")

const TILE_SIZE := 16
const PLAYER_SPAWN_HOME_CELL := Vector2i(6, 7)
const COMPANION_SPAWN_CELL := Vector2i(8, 12)
const GROUND_LAYERS: Array[String] = ["草地", "沙地", "田"]
const PLOT_LAYER := "田"
# 中间那两垄是临时田，删掉。可种的田只用最右边围栏里的三垄。
const FIELD_CLEAR_RECT := Rect2i(31, 21, 9, 12)
const EXTRA_STRIP_XS: Array[int] = [54, 56]
const WORKING_PLOT_CELLS: Array[Vector2i] = [
	Vector2i(46, 21), Vector2i(46, 22), Vector2i(46, 23), Vector2i(46, 24), Vector2i(46, 25), Vector2i(46, 26),
	Vector2i(48, 21), Vector2i(48, 22), Vector2i(48, 23), Vector2i(48, 24), Vector2i(48, 25), Vector2i(48, 26),
	Vector2i(50, 21), Vector2i(50, 22), Vector2i(50, 23), Vector2i(50, 24), Vector2i(50, 25), Vector2i(50, 26),
]
const MAX_WORKING_PLOTS := 18
# 仅剥离 source 0 上「纯装饰用」的静态作物贴图（若地图里仍有）。source 6 是农田 autotile 土块，绝不能删。
const DECORATIVE_CROP_SOURCE := 0
const DECORATIVE_CROP_ATLAS_COORDS: Array[Vector2i] = [
	Vector2i(29, 1), Vector2i(30, 1), Vector2i(31, 1), Vector2i(32, 1), Vector2i(33, 1), Vector2i(34, 1),
	Vector2i(42, 1), Vector2i(43, 1), Vector2i(44, 1),
	Vector2i(49, 1), Vector2i(50, 1), Vector2i(51, 1), Vector2i(52, 1), Vector2i(53, 1), Vector2i(54, 1),
	Vector2i(55, 1), Vector2i(56, 1), Vector2i(57, 1), Vector2i(58, 1),
	Vector2i(60, 1), Vector2i(61, 1), Vector2i(62, 1),
]

@onready var _farm_map: Node2D = $FarmMap

var _ground_layer: TileMapLayer
var _ground_layers: Array[TileMapLayer] = []
var _layer_scale := Vector2(2, 2)
var _player: CharacterBody2D
var _snuggle_active := false
var _snuggle_elapsed := 0.0
var _snuggle_player_base := Vector2.ZERO
var _snuggle_companion_base := Vector2.ZERO
var _snuggle_companion: Node2D
var _snuggle_callback: Callable = Callable()
var _snuggle_player_phase := 0.0
var _snuggle_companion_phase := 0.0

const SNUGGLE_DURATION := 3.0
const SNUGGLE_PLAYER_SWAY_X := 12.0
const SNUGGLE_PLAYER_SWAY_Y := 4.0
const SNUGGLE_PLAYER_SWAY_SPEED := 2.15
const SNUGGLE_COMPANION_SWAY_X := 10.0
const SNUGGLE_COMPANION_SWAY_Y := 4.5
const SNUGGLE_COMPANION_SWAY_SPEED := 1.48
const SNUGGLE_SIT_FEET_OFFSET := Vector2(0, 22)
const SNUGGLE_PLAYER_X := -38.0
const SNUGGLE_COMPANION_X := 16.0


func _ready() -> void:
	add_to_group("farm_world")
	add_to_group("pixel_world")
	y_sort_enabled = false
	_setup_layers()
	# 院子已经烘进 farm_map.tscn，标记点和摆设都以场景为准，不再运行时生成。
	_ensure_entities()
	_spawn_player()
	_setup_camera_limits()
	call_deferred("_setup_camera_limits")
	set_process(false)


func start_companion_snuggle(on_finished: Callable) -> void:
	if _snuggle_active:
		return
	var entities := _actors()
	if entities == null or _player == null:
		if on_finished.is_valid():
			on_finished.call()
		return

	_snuggle_companion = entities.get_node_or_null("Companion") as Node2D
	if _snuggle_companion == null:
		if on_finished.is_valid():
			on_finished.call()
		return

	var anchor := _tree_hollow_anchor()
	CompanionAgent.set_snuggle_paused(true)
	if _player.has_method("set_movement_locked"):
		_player.set_movement_locked(true)
	if _player.has_method("set_snuggle_facing"):
		_player.set_snuggle_facing("down")

	_align_snuggle_positions(anchor)

	if _snuggle_companion.has_method("play_stand_still"):
		_snuggle_companion.play_stand_still("down")
	if _snuggle_companion.has_method("show_status_bubble"):
		_snuggle_companion.show_status_bubble("正在和小狸依偎中..")

	_snuggle_player_phase = randf() * TAU
	_snuggle_companion_phase = randf() * TAU
	_snuggle_elapsed = 0.0
	_snuggle_callback = on_finished
	_snuggle_active = true
	set_process(true)


func _align_snuggle_positions(anchor: Vector2) -> void:
	var feet_y := anchor.y + SNUGGLE_SIT_FEET_OFFSET.y
	var player_feet_offset := Vector2.ZERO
	if _player.has_method("get_feet_position"):
		player_feet_offset = _player.get_feet_position() - _player.global_position
	var companion_feet_offset := Vector2.ZERO
	if _snuggle_companion.has_method("get_feet_position"):
		companion_feet_offset = _snuggle_companion.get_feet_position() - _snuggle_companion.global_position
	elif _snuggle_companion.has_method("get_rain_feet_position"):
		companion_feet_offset = _snuggle_companion.get_rain_feet_position() - _snuggle_companion.global_position

	_snuggle_player_base = Vector2(anchor.x + SNUGGLE_PLAYER_X, feet_y - player_feet_offset.y)
	_snuggle_companion_base = Vector2(anchor.x + SNUGGLE_COMPANION_X, feet_y - companion_feet_offset.y)
	_player.global_position = _snuggle_player_base
	_snuggle_companion.global_position = _snuggle_companion_base


func _tree_hollow_anchor() -> Vector2:
	var entities := _actors()
	if entities != null:
		var hollow := entities.get_node_or_null("TreeHollow") as Node2D
		if hollow != null:
			return hollow.global_position
	var marker := _farm_map.get_node_or_null("树洞") as Node2D
	if marker != null:
		return marker.global_position
	return FarmSetdress.POS_HOLLOW


func _process(delta: float) -> void:
	if not _snuggle_active:
		return

	_snuggle_elapsed += delta
	var player_t := _snuggle_elapsed * SNUGGLE_PLAYER_SWAY_SPEED + _snuggle_player_phase
	var companion_t := _snuggle_elapsed * SNUGGLE_COMPANION_SWAY_SPEED + _snuggle_companion_phase
	var player_offset := Vector2(
		sin(player_t) * SNUGGLE_PLAYER_SWAY_X,
		sin(player_t * 0.73) * SNUGGLE_PLAYER_SWAY_Y
	)
	var companion_offset := Vector2(
		sin(companion_t) * SNUGGLE_COMPANION_SWAY_X,
		sin(companion_t * 0.81) * SNUGGLE_COMPANION_SWAY_Y
	)
	if _player != null:
		_player.global_position = _snuggle_player_base + player_offset
	if _snuggle_companion != null:
		_snuggle_companion.global_position = _snuggle_companion_base + companion_offset

	if _snuggle_elapsed >= SNUGGLE_DURATION:
		_finish_companion_snuggle()


func _finish_companion_snuggle() -> void:
	if not _snuggle_active:
		return
	_snuggle_active = false
	set_process(false)

	if _snuggle_companion != null and _snuggle_companion.has_method("hide_status_bubble"):
		_snuggle_companion.hide_status_bubble()
	CompanionAgent.set_snuggle_paused(false)
	if _player != null and _player.has_method("set_movement_locked"):
		_player.set_movement_locked(false)

	var callback := _snuggle_callback
	_snuggle_callback = Callable()
	if callback.is_valid():
		callback.call()


func get_player() -> CharacterBody2D:
	return _player


func is_walkable(_world_pos: Vector2) -> bool:
	return true


func has_ground_at(world_pos: Vector2) -> bool:
	return _has_ground_at(world_pos)


func get_ground_surface_y_at(world_x: float, from_y: float) -> float:
	if _ground_layer == null:
		return from_y + 400.0
	var y := from_y
	for _i in 120:
		var probe := Vector2(world_x, y)
		if _has_ground_at(probe):
			var cell := _world_pos_to_cell(probe)
			var cell_center := _cell_to_local(cell)
			var tile_h := TILE_SIZE * _layer_scale.y
			return cell_center.y - tile_h * 0.42
		y += 5.0
	return from_y + 500.0


func get_farm_map() -> Node2D:
	return _farm_map


func is_rain_sheltered(world_pos: Vector2) -> bool:
	return FarmSetdress.porch_shelter_rect(_farm_map).has_point(world_pos)


func _has_ground_at(world_pos: Vector2) -> bool:
	for layer in _ground_layers:
		var cell := layer.local_to_map(layer.to_local(world_pos))
		if layer.get_cell_source_id(cell) != -1:
			return true
	return false


func set_plot_watered(_plot_id: int, _watered: bool) -> void:
	pass


func _setup_layers() -> void:
	_farm_map.y_sort_enabled = false
	_ground_layer = _farm_map.get_node_or_null("草地") as TileMapLayer
	if _ground_layer == null:
		for child in _farm_map.get_children():
			if child is TileMapLayer:
				_ground_layer = child as TileMapLayer
				break
	if _ground_layer != null:
		_layer_scale = _ground_layer.scale
	_ground_layers.clear()
	for layer_name in GROUND_LAYERS:
		var layer := _farm_map.get_node_or_null(layer_name) as TileMapLayer
		if layer != null:
			layer.z_index = 0
			layer.y_sort_enabled = false
			_ground_layers.append(layer)


func _actors() -> Node2D:
	return FarmSetdress.ensure_actors(_farm_map)


func _ensure_entities() -> void:
	var entities := _actors()

	var door := entities.get_node_or_null("Door")
	if door != null:
		door.queue_free()

	var companion := entities.get_node_or_null("Companion") as Area2D
	if companion == null:
		companion = COMPANION_SCENE.instantiate() as Area2D
		companion.name = "Companion"
		entities.add_child(companion)
	companion.position = _companion_spawn_position()
	var plot_count := _spawn_plots(entities)
	GameState.register_farm_plots(plot_count)
	_spawn_shop(entities)
	_spawn_tree_hollow(entities)
	call_deferred("_setup_companion_agent", entities)


func _spawn_tree_hollow(entities: Node2D) -> void:
	var marker := _farm_map.get_node_or_null("树洞") as Node2D
	var pos := FarmSetdress.POS_HOLLOW
	if marker != null:
		pos = marker.position

	var existing := entities.get_node_or_null("TreeHollow") as Node2D
	if existing != null:
		existing.position = pos
		return

	var hollow := TREE_HOLLOW_SCENE.instantiate() as Area2D
	if hollow == null:
		return
	hollow.name = "TreeHollow"
	hollow.position = pos
	entities.add_child(hollow)


func _spawn_shop(entities: Node2D) -> void:
	var marker := _farm_map.get_node_or_null("商店") as Node2D
	if marker == null:
		return

	var existing := entities.get_node_or_null("Shop") as Node2D
	if existing != null:
		existing.position = marker.position
		return

	var shop := SHOP_SCENE.instantiate() as Area2D
	if shop == null:
		return
	shop.name = "Shop"
	shop.position = marker.position
	entities.add_child(shop)


func _spawn_plots(entities: Node2D) -> int:
	for child in entities.get_children():
		if child is FarmPlot:
			child.queue_free()

	var plot_layer := _farm_map.get_node_or_null(PLOT_LAYER) as TileMapLayer
	if plot_layer == null:
		return 0

	_strip_decorative_crop_tiles(plot_layer)
	_layout_working_field(plot_layer)

	var plot_id := 1
	for cell in WORKING_PLOT_CELLS:
		if plot_id > MAX_WORKING_PLOTS:
			break
		var plot := PLOT_SCENE.instantiate() as FarmPlot
		if plot == null:
			continue
		plot.name = "Plot_%d" % plot_id
		plot.plot_id = plot_id
		plot.grid_cell = cell
		plot.world_builder = self
		plot.position = _layer_cell_to_local(plot_layer, cell)
		entities.add_child(plot)
		plot_id += 1
	return plot_id - 1


func _layout_working_field(plot_layer: TileMapLayer) -> void:
	for cell in plot_layer.get_used_cells():
		if FIELD_CLEAR_RECT.has_point(cell):
			plot_layer.erase_cell(cell)
		elif cell.x in EXTRA_STRIP_XS and cell.y >= 21 and cell.y <= 26:
			plot_layer.erase_cell(cell)


func _strip_decorative_crop_tiles(plot_layer: TileMapLayer) -> void:
	for cell in plot_layer.get_used_cells():
		if plot_layer.get_cell_source_id(cell) != DECORATIVE_CROP_SOURCE:
			continue
		if plot_layer.get_cell_atlas_coords(cell) in DECORATIVE_CROP_ATLAS_COORDS:
			plot_layer.erase_cell(cell)


func _spawn_player() -> void:
	var actors := _actors()
	_player = actors.get_node_or_null("Player") as CharacterBody2D
	if _player == null:
		_player = _farm_map.get_node_or_null("Player") as CharacterBody2D
	if _player == null:
		_player = PLAYER_SCENE.instantiate() as CharacterBody2D
		_player.name = "Player"
		actors.add_child(_player)
	elif _player.get_parent() != actors:
		_player.reparent(actors)
	_player.position = _player_spawn_position()
	if _player.has_method("sync_world_position"):
		_player.sync_world_position()


func _player_spawn_position() -> Vector2:
	for marker_name in ["人", "SpawnPoint"]:
		var spawn_marker := _farm_map.get_node_or_null(marker_name) as Node2D
		if spawn_marker != null:
			return spawn_marker.position
	var home_layer := _farm_map.get_node_or_null("家") as TileMapLayer
	if home_layer != null:
		return _layer_cell_to_local(home_layer, PLAYER_SPAWN_HOME_CELL)
	return _default_spawn_position()


func _companion_spawn_position() -> Vector2:
	for marker_name in ["小狸", "CompanionPoint"]:
		var companion_marker := _farm_map.get_node_or_null(marker_name) as Node2D
		if companion_marker != null:
			return companion_marker.position
	return _cell_to_local(COMPANION_SPAWN_CELL)


func _default_spawn_position() -> Vector2:
	if _ground_layer == null:
		return Vector2(200, 200)
	var used := _ground_layer.get_used_rect()
	var center_cell := Vector2i(
		used.position.x + used.size.x / 2,
		used.position.y + used.size.y / 2
	)
	return _cell_to_local(center_cell)


func _setup_camera_limits() -> void:
	if _player == null:
		return
	var camera := _player.get_node("Camera2D") as Camera2D
	if camera == null:
		return
	var map_rect := _grass_world_rect()
	if map_rect.size.x < 8.0 or map_rect.size.y < 8.0:
		map_rect = FarmSetdress.living_yard_rect(_farm_map).grow(80.0)
	# 镜头贴着草地边缘，能跟着人往南走，又不会探出地图露出灰边。
	camera.limit_left = int(floor(map_rect.position.x))
	camera.limit_top = int(floor(map_rect.position.y))
	camera.limit_right = int(ceil(map_rect.end.x))
	camera.limit_bottom = int(ceil(map_rect.end.y))
	camera.limit_smoothed = true
	if _player.has_method("set_walk_bounds"):
		_player.set_walk_bounds(map_rect.grow(-12.0))


func _grass_world_rect() -> Rect2:
	var layer := _ground_layer
	if layer == null or layer.tile_set == null:
		return Rect2()
	var used := layer.get_used_rect()
	if used.size.x <= 0 or used.size.y <= 0:
		return Rect2()
	var cell_px := Vector2(layer.tile_set.tile_size) * layer.scale
	var first := layer.to_global(layer.map_to_local(used.position))
	var last := layer.to_global(layer.map_to_local(used.position + used.size - Vector2i.ONE))
	var origin := first - cell_px * 0.5
	var end := last + cell_px * 0.5
	return Rect2(origin, end - origin)


func _world_pos_to_cell(world_pos: Vector2) -> Vector2i:
	if _ground_layer == null:
		return Vector2i.ZERO
	return _ground_layer.local_to_map(_ground_layer.to_local(world_pos))


func _cell_to_local(cell: Vector2i) -> Vector2:
	if _ground_layer == null:
		return Vector2.ZERO
	return _ground_layer.to_global(_ground_layer.map_to_local(cell))


func _layer_cell_to_local(layer: TileMapLayer, cell: Vector2i) -> Vector2:
	return layer.to_global(layer.map_to_local(cell))


func _setup_companion_agent(entities: Node2D) -> void:
	var companion := entities.get_node_or_null("Companion") as Node2D
	if companion == null:
		return

	var plot_positions: Dictionary = {}
	for child in entities.get_children():
		if child is FarmPlot:
			plot_positions[int(child.plot_id)] = child.global_position

	var shop_pos := FarmSetdress.marker_position(_farm_map, "商店", FarmSetdress.POS_SHOP)
	var shop_marker := _farm_map.get_node_or_null("商店") as Node2D
	if shop_marker != null:
		shop_pos = shop_marker.global_position

	var field_center := Vector2.ZERO
	if not plot_positions.is_empty():
		for raw_pos in plot_positions.values():
			field_center += Vector2(raw_pos)
		field_center /= float(plot_positions.size())
	else:
		field_center = FarmSetdress.marker_position(_farm_map, "田埂", FarmSetdress.POS_RIDGE)

	CompanionAgent.setup(
		companion,
		plot_positions,
		shop_pos,
		_companion_path_waypoints(field_center, shop_pos),
		FarmSetdress.story_pois(_farm_map, field_center, shop_pos)
	)


func _companion_path_waypoints(field_center: Vector2, shop_pos: Vector2) -> Array[Vector2]:
	var points: Array[Vector2] = [
		FarmSetdress.marker_position(_farm_map, "廊下", FarmSetdress.POS_PORCH),
		FarmSetdress.marker_position(_farm_map, "人", FarmSetdress.POS_HOME),
		FarmSetdress.marker_position(_farm_map, "树洞", FarmSetdress.POS_HOLLOW),
		shop_pos,
		field_center,
		FarmSetdress.marker_position(_farm_map, "田埂", FarmSetdress.POS_RIDGE),
		FarmSetdress.marker_position(_farm_map, "空土垄", FarmSetdress.POS_EMPTY),
		FarmSetdress.marker_position(_farm_map, "河边", FarmSetdress.POS_RIVER),
	]
	return points
