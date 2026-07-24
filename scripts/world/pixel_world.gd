extends Node2D

const TileFactory := preload("res://scripts/world/tile_factory.gd")
const PLAYER_SCENE: PackedScene = preload("res://scenes/player.tscn")

const TILE_SIZE := 32
const CLIFF_H := TileFactory.CLIFF_H
const MAP_W := 40
const MAP_H := 23

const T_GRASS := Vector2i(0, 0)
const T_GRASS_ALT := Vector2i(1, 0)
const T_SOIL_DRY := Vector2i(2, 0)
const T_SOIL_WET := Vector2i(3, 0)
const T_WOOD := Vector2i(4, 0)
const T_PATH := Vector2i(5, 0)
const T_FENCE := Vector2i(6, 0)
const T_POND := Vector2i(7, 0)
const T_FLOWERS := Vector2i(8, 0)
const T_GRASS_DARK := Vector2i(9, 0)

const PLOT_SCENE: PackedScene = preload("res://scenes/plot.tscn")
const COMPANION_SCENE: PackedScene = preload("res://scenes/companion.tscn")

const PLOT_CELLS: Array[Vector2i] = [
	Vector2i(4, 5), Vector2i(5, 5), Vector2i(6, 5),
	Vector2i(4, 6), Vector2i(5, 6),
]

const HOUSE_X0 := 22
const HOUSE_X1 := 36
const HOUSE_Y0 := 8
const HOUSE_Y1 := 19

const SPAWN_CELL := Vector2i(28, 14)

var _tile_layer: TileMapLayer
var _plot_cells: Dictionary = {}
var _elevation: Dictionary = {}
var _plot_surface_kind: Dictionary = {}
var _blocked_cells: Dictionary = {}
var _player: CharacterBody2D


func _ready() -> void:
	add_to_group("pixel_world")
	y_sort_enabled = true
	_init_elevation()
	_build_background()
	_build_tilemap()
	_build_raised_terrain()
	_build_house_walls()
	_build_decorations()
	_build_entities()
	_spawn_player()


func get_player() -> CharacterBody2D:
	return _player


func get_elevation(cell: Vector2i) -> int:
	return int(_elevation.get(cell, 0))


func get_elevation_at(world_pos: Vector2) -> int:
	return get_elevation(_world_to_cell(world_pos))


func is_walkable(_world_pos: Vector2) -> bool:
	return true


func set_plot_watered(plot_id: int, watered: bool) -> void:
	if not _plot_cells.has(plot_id):
		return
	var cell: Vector2i = _plot_cells[plot_id]
	_plot_surface_kind[cell] = "soil_wet" if watered else "soil_dry"
	_refresh_raised_cell(cell)


func _init_elevation() -> void:
	_elevation.clear()
	for cell in PLOT_CELLS:
		_elevation[cell] = 1
		_plot_surface_kind[cell] = "soil_dry"
	for x in range(HOUSE_X0, HOUSE_X1):
		for y in range(HOUSE_Y0, HOUSE_Y1):
			_elevation[Vector2i(x, y)] = 1


func _spawn_player() -> void:
	_player = PLAYER_SCENE.instantiate() as CharacterBody2D
	add_child(_player)
	_player.global_position = _cell_to_feet(SPAWN_CELL)


func _build_background() -> void:
	var layer := CanvasLayer.new()
	layer.layer = -10
	var sky := ColorRect.new()
	sky.set_anchors_preset(Control.PRESET_FULL_RECT)
	sky.color = Color(0.58, 0.78, 0.96)
	sky.mouse_filter = Control.MOUSE_FILTER_IGNORE
	layer.add_child(sky)
	add_child(layer)


func _build_tilemap() -> void:
	_tile_layer = TileMapLayer.new()
	_tile_layer.name = "GroundLow"
	_tile_layer.texture_filter = CanvasItem.TEXTURE_FILTER_NEAREST
	_tile_layer.tile_set = _create_tileset()
	_tile_layer.z_index = 0
	add_child(_tile_layer)

	for x in range(MAP_W):
		for y in range(MAP_H):
			var atlas := T_GRASS
			if (x + y) % 5 == 0:
				atlas = T_GRASS_ALT
			if x > 30 and y > 16:
				atlas = T_GRASS_DARK
			_tile_layer.set_cell(Vector2i(x, y), 0, atlas)

	# 小池塘（不可走）
	for x in range(11, 14):
		for y in range(17, 20):
			var cell := Vector2i(x, y)
			_tile_layer.set_cell(cell, 0, T_POND)
			_blocked_cells[cell] = true

	# 花丛地面
	for cell in [Vector2i(9, 4), Vector2i(14, 3), Vector2i(18, 16), Vector2i(20, 4)]:
		_tile_layer.set_cell(cell, 0, T_FLOWERS)

	# 农田围栏
	for cell in PLOT_CELLS:
		for n in _neighbors4(cell):
			if not _contains_cell(PLOT_CELLS, n) and _in_map(n) and get_elevation(n) == 0:
				_tile_layer.set_cell(n, 0, T_FENCE)

	# 通往房间与门的路径
	for y in range(9, 18):
		_tile_layer.set_cell(Vector2i(36, y), 0, T_PATH)
	for x in range(35, 39):
		_tile_layer.set_cell(Vector2i(x, 13), 0, T_PATH)
	_tile_layer.set_cell(Vector2i(37, 13), 0, T_PATH)


func _build_raised_terrain() -> void:
	var layer := Node2D.new()
	layer.name = "RaisedTerrain"
	layer.y_sort_enabled = true
	add_child(layer)

	for cell in _elevation.keys():
		_add_raised_sprite(layer, cell)


func _refresh_raised_cell(cell: Vector2i) -> void:
	var layer := get_node_or_null("RaisedTerrain")
	if layer == null:
		return
	for child in layer.get_children():
		if child is Sprite2D and child.name == "Raised_%d_%d" % [cell.x, cell.y]:
			child.queue_free()
			break
	_add_raised_sprite(layer, cell)


func _add_raised_sprite(parent: Node2D, cell: Vector2i) -> void:
	var kind := str(_plot_surface_kind.get(cell, "wood"))
	if not _plot_surface_kind.has(cell):
		kind = "wood"
	var cliff_s := _has_cliff_south(cell)
	var tex := TileFactory.create_raised_surface(kind, cliff_s)
	var spr := Sprite2D.new()
	spr.name = "Raised_%d_%d" % [cell.x, cell.y]
	spr.texture = tex
	spr.texture_filter = CanvasItem.TEXTURE_FILTER_NEAREST
	spr.centered = false
	spr.position = Vector2(cell.x * TILE_SIZE, cell.y * TILE_SIZE - CLIFF_H)
	parent.add_child(spr)


func _has_cliff_south(cell: Vector2i) -> bool:
	var south := cell + Vector2i(0, 1)
	if not _in_map(south):
		return true
	return get_elevation(south) < get_elevation(cell)


func _build_house_walls() -> void:
	var walls := Node2D.new()
	walls.name = "HouseWalls"
	walls.y_sort_enabled = true
	add_child(walls)

	var wall_tex := TileFactory.create_wall_texture()
	for x in range(HOUSE_X0, HOUSE_X1):
		_spawn_wall(walls, Vector2i(x, 8), wall_tex, false)
	for y in range(HOUSE_Y0, HOUSE_Y1):
		_spawn_wall(walls, Vector2i(22, y), wall_tex, true)

	# 北墙窗户
	for x in [26, 30, 34]:
		_spawn_sprite(walls, Vector2i(x * TILE_SIZE + 4, 8 * TILE_SIZE - CLIFF_H - 22),
			TileFactory.create_window_texture(), Vector2(-12, -10))


func _build_decorations() -> void:
	var decor := Node2D.new()
	decor.name = "Decorations"
	decor.y_sort_enabled = true
	add_child(decor)

	# 农田南台阶
	_spawn_sprite(decor, Vector2(3 * TILE_SIZE, 7 * TILE_SIZE + 8),
		TileFactory.create_steps_texture(), Vector2(0, -8))

	# 树木
	for cell in [Vector2i(2, 3), Vector2i(8, 2), Vector2i(1, 10), Vector2i(16, 2), Vector2i(38, 5)]:
		_spawn_prop(decor, "Tree_%d_%d" % [cell.x, cell.y], cell,
			TileFactory.create_prop_texture(Vector2i(32, 40), Color(0.34, 0.62, 0.30), Color(0.50, 0.78, 0.38)))

	# 灌木、石头
	for cell in [Vector2i(10, 8), Vector2i(15, 12), Vector2i(19, 8), Vector2i(7, 14)]:
		_spawn_sprite(decor, _cell_to_feet(cell),
			TileFactory.create_bush_texture(), Vector2(-12, -18))
	for cell in [Vector2i(12, 10), Vector2i(17, 15), Vector2i(33, 17)]:
		_spawn_sprite(decor, _cell_to_feet(cell),
			TileFactory.create_rock_texture(), Vector2(-10, -14))
	_spawn_sprite(decor, _cell_to_feet(Vector2i(6, 12)),
		TileFactory.create_stump_texture(), Vector2(-10, -14))

	# 房间内地毯
	_spawn_sprite(decor, Vector2(26 * TILE_SIZE, 12 * TILE_SIZE - CLIFF_H),
		TileFactory.create_rug_texture(), Vector2(0, 0))

	# 门边木桶
	_spawn_sprite(decor, _cell_to_feet(Vector2i(36, 12)),
		TileFactory.create_barrel_texture(), Vector2(-10, -22))


func _build_entities() -> void:
	var entities := Node2D.new()
	entities.name = "Entities"
	entities.y_sort_enabled = true
	add_child(entities)

	for i in range(PLOT_CELLS.size()):
		var plot := PLOT_SCENE.instantiate() as FarmPlot
		plot.plot_id = i + 1
		plot.grid_cell = PLOT_CELLS[i]
		plot.world_builder = self
		entities.add_child(plot)
		plot.position = _cell_to_feet(PLOT_CELLS[i])
		_plot_cells[i + 1] = PLOT_CELLS[i]

	_spawn_prop(entities, "Bed", Vector2i(24, 10),
		TileFactory.create_prop_texture(Vector2i(28, 36), Color(0.66, 0.50, 0.80), Color(0.82, 0.70, 0.92)))
	_spawn_prop(entities, "Table", Vector2i(30, 14),
		TileFactory.create_prop_texture(Vector2i(36, 24), Color(0.62, 0.44, 0.28), Color(0.76, 0.58, 0.36)))
	_spawn_prop(entities, "Chair", Vector2i(31, 15),
		TileFactory.create_chair_texture())

	var companion := COMPANION_SCENE.instantiate() as Area2D
	entities.add_child(companion)
	companion.position = _cell_to_feet(Vector2i(28, 13))


func _spawn_prop(parent: Node2D, prop_name: String, cell: Vector2i, texture: Texture2D) -> void:
	var prop := Sprite2D.new()
	prop.name = prop_name
	prop.texture = texture
	prop.texture_filter = CanvasItem.TEXTURE_FILTER_NEAREST
	prop.centered = false
	var tex_size := texture.get_size()
	prop.offset = Vector2(-tex_size.x * 0.5, -tex_size.y + 8.0)
	prop.position = _cell_to_feet(cell)
	parent.add_child(prop)


func _spawn_sprite(parent: Node2D, pos: Vector2, texture: Texture2D, offset: Vector2) -> void:
	var spr := Sprite2D.new()
	spr.texture = texture
	spr.texture_filter = CanvasItem.TEXTURE_FILTER_NEAREST
	spr.centered = false
	spr.offset = offset
	spr.position = pos
	parent.add_child(spr)


func _spawn_wall(parent: Node2D, cell: Vector2i, tex: Texture2D, vertical: bool) -> void:
	var spr := Sprite2D.new()
	spr.texture = tex
	spr.texture_filter = CanvasItem.TEXTURE_FILTER_NEAREST
	spr.centered = false
	if vertical:
		spr.rotation_degrees = 90
		spr.position = Vector2(cell.x * TILE_SIZE - 4, cell.y * TILE_SIZE - CLIFF_H - 8)
	else:
		spr.position = Vector2(cell.x * TILE_SIZE, cell.y * TILE_SIZE - CLIFF_H - 18)
	parent.add_child(spr)


func _cell_to_feet(cell: Vector2i, x_override: float = -1.0) -> Vector2:
	var elev := get_elevation(cell)
	var x := x_override if x_override >= 0.0 else cell.x * TILE_SIZE + TILE_SIZE * 0.5
	return Vector2(
		x,
		cell.y * TILE_SIZE + TILE_SIZE - 6 - elev * CLIFF_H
	)


func _world_to_cell(world_pos: Vector2) -> Vector2i:
	return Vector2i(
		int(floor(world_pos.x / TILE_SIZE)),
		int(floor(world_pos.y / TILE_SIZE))
	)


func _create_tileset() -> TileSet:
	var tileset := TileSet.new()
	var atlas := TileSetAtlasSource.new()
	atlas.texture = TileFactory.create_tileset_texture()
	atlas.texture_region_size = Vector2i(TILE_SIZE, TILE_SIZE)
	for i in range(10):
		atlas.create_tile(Vector2i(i, 0))
	tileset.add_source(atlas, 0)
	return tileset


func _neighbors4(cell: Vector2i) -> Array[Vector2i]:
	return [
		cell + Vector2i(1, 0), cell + Vector2i(-1, 0),
		cell + Vector2i(0, 1), cell + Vector2i(0, -1),
	]


func _contains_cell(cells: Array[Vector2i], target: Vector2i) -> bool:
	for c in cells:
		if c == target:
			return true
	return false


func _in_map(cell: Vector2i) -> bool:
	return cell.x >= 0 and cell.y >= 0 and cell.x < MAP_W and cell.y < MAP_H
