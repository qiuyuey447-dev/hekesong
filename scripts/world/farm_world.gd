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
# Autotile crop overlays on the farm layer are decorative; gameplay crops use FarmPlot sprites.
const DECORATIVE_CROP_SOURCES: Array[int] = [1, 6]

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
	y_sort_enabled = true
	_setup_layers()
	_ensure_entities()
	_spawn_player()
	_setup_camera_limits()
	set_process(false)


func start_companion_snuggle(on_finished: Callable) -> void:
	if _snuggle_active:
		return
	var entities := _farm_map.get_node_or_null("Entities") as Node2D
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
	var entities := _farm_map.get_node_or_null("Entities") as Node2D
	if entities != null:
		var hollow := entities.get_node_or_null("TreeHollow") as Node2D
		if hollow != null:
			return hollow.global_position
	var marker := _farm_map.get_node_or_null("树洞") as Node2D
	if marker != null:
		return marker.global_position
	return Vector2(987, 440)


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


func _has_ground_at(world_pos: Vector2) -> bool:
	for layer in _ground_layers:
		var cell := layer.local_to_map(layer.to_local(world_pos))
		if layer.get_cell_source_id(cell) != -1:
			return true
	return false


func set_plot_watered(_plot_id: int, _watered: bool) -> void:
	pass


func _setup_layers() -> void:
	_farm_map.y_sort_enabled = true
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
			_ground_layers.append(layer)


func _ensure_entities() -> void:
	var entities := _farm_map.get_node_or_null("Entities") as Node2D
	if entities == null:
		entities = Node2D.new()
		entities.name = "Entities"
		entities.y_sort_enabled = true
		_farm_map.add_child(entities)
	entities.z_index = 1

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
	var existing := entities.get_node_or_null("TreeHollow")
	if existing != null:
		existing.queue_free()

	var marker := _farm_map.get_node_or_null("树洞") as Node2D
	var pos := Vector2(987, 440)
	if marker != null:
		pos = marker.position

	var hollow := TREE_HOLLOW_SCENE.instantiate() as Area2D
	if hollow == null:
		return
	hollow.name = "TreeHollow"
	hollow.position = pos
	entities.add_child(hollow)


func _spawn_shop(entities: Node2D) -> void:
	var existing := entities.get_node_or_null("Shop")
	if existing != null:
		existing.queue_free()

	var marker := _farm_map.get_node_or_null("商店") as Node2D
	if marker == null:
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

	var cells := plot_layer.get_used_cells()
	cells.sort_custom(func(a: Vector2i, b: Vector2i) -> bool:
		if a.y == b.y:
			return a.x < b.x
		return a.y < b.y
	)

	var plot_id := 1
	for cell in cells:
		if not _is_interactive_soil_cell(plot_layer, cell):
			continue
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


func _strip_decorative_crop_tiles(plot_layer: TileMapLayer) -> void:
	for cell in plot_layer.get_used_cells():
		if plot_layer.get_cell_source_id(cell) in DECORATIVE_CROP_SOURCES:
			plot_layer.erase_cell(cell)


func _is_interactive_soil_cell(plot_layer: TileMapLayer, cell: Vector2i) -> bool:
	var source_id := plot_layer.get_cell_source_id(cell)
	if source_id < 0:
		return false
	return source_id not in DECORATIVE_CROP_SOURCES


func _spawn_player() -> void:
	_player = _farm_map.get_node_or_null("Player") as CharacterBody2D
	if _player == null:
		_player = PLAYER_SCENE.instantiate() as CharacterBody2D
		_player.name = "Player"
		_farm_map.add_child(_player)
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
	if _player == null or _ground_layer == null:
		return
	var used := _ground_layer.get_used_rect()
	var offset_px := Vector2(used.position) * TILE_SIZE * _layer_scale
	var size_px := Vector2(used.size) * TILE_SIZE * _layer_scale
	var camera := _player.get_node("Camera2D") as Camera2D
	camera.limit_left = int(offset_px.x)
	camera.limit_top = int(offset_px.y)
	camera.limit_right = int(offset_px.x + size_px.x)
	camera.limit_bottom = int(offset_px.y + size_px.y)
	camera.limit_smoothed = true


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

	var shop_pos := Vector2(1321, 230)
	var shop_marker := _farm_map.get_node_or_null("商店") as Node2D
	if shop_marker != null:
		shop_pos = shop_marker.global_position

	CompanionAgent.setup(
		companion,
		plot_positions,
		shop_pos,
		_companion_path_waypoints()
	)


func _companion_path_waypoints() -> Array[Vector2]:
	# 沿主路、家-营地-商店-池塘-萝卜田的漫游路径（与地图可走区域大致对应）
	return [
		Vector2(240, 200), Vector2(180, 280), Vector2(220, 360), Vector2(272, 412),
		Vector2(340, 460), Vector2(420, 500), Vector2(520, 480), Vector2(620, 420),
		Vector2(740, 360), Vector2(880, 300), Vector2(1020, 260), Vector2(1180, 220),
		Vector2(1321, 230), Vector2(1100, 400), Vector2(950, 520), Vector2(780, 580),
		Vector2(600, 620), Vector2(420, 580), Vector2(300, 520), Vector2(200, 450),
		Vector2(150, 600), Vector2(280, 650), Vector2(450, 680), Vector2(650, 700),
		Vector2(850, 680), Vector2(1050, 650), Vector2(480, 380), Vector2(520, 180),
	]
