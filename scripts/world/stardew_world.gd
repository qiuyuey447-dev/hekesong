extends Node2D

const TileFactory := preload("res://scripts/world/tile_factory.gd")

const TILE_SIZE := 32
const MAP_W := 40
const MAP_H := 23

const T_GRASS := Vector2i(0, 0)
const T_SOIL_DRY := Vector2i(1, 0)
const T_SOIL_WET := Vector2i(2, 0)
const T_WOOD := Vector2i(3, 0)
const T_PATH := Vector2i(4, 0)
const T_FENCE := Vector2i(5, 0)

const PLOT_SCENE: PackedScene = preload("res://scenes/plot.tscn")
const COMPANION_SCENE: PackedScene = preload("res://scenes/companion.tscn")

const PLOT_CELLS: Array[Vector2i] = [
	Vector2i(4, 5), Vector2i(5, 5), Vector2i(6, 5),
	Vector2i(4, 6), Vector2i(5, 6),
]

var _tile_layer: TileMapLayer
var _plot_cells: Dictionary = {}


func _ready() -> void:
	add_to_group("stardew_world")
	_build_background()
	_build_tilemap()
	_build_entities()


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
	_tile_layer.name = "Ground"
	_tile_layer.texture_filter = CanvasItem.TEXTURE_FILTER_NEAREST
	_tile_layer.tile_set = _create_tileset()
	add_child(_tile_layer)
	add_to_group("tilemap")

	for x in range(MAP_W):
		for y in range(MAP_H):
			_tile_layer.set_cell(Vector2i(x, y), 0, T_GRASS)

	for cell in PLOT_CELLS:
		_tile_layer.set_cell(cell, 0, T_SOIL_DRY)

	for cell in PLOT_CELLS:
		for n in _neighbors4(cell):
			if not _contains_cell(PLOT_CELLS, n) and _in_map(n):
				if _tile_layer.get_cell_source_id(n) >= 0:
					var atlas: Vector2i = _tile_layer.get_cell_atlas_coords(n)
					if atlas == T_GRASS:
						_tile_layer.set_cell(n, 0, T_FENCE)

	for x in range(22, 36):
		for y in range(8, 19):
			_tile_layer.set_cell(Vector2i(x, y), 0, T_WOOD)

	for y in range(10, 17):
		_tile_layer.set_cell(Vector2i(36, y), 0, T_PATH)
	_tile_layer.set_cell(Vector2i(37, 13), 0, T_PATH)


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
		TileFactory.create_prop_texture(Vector2i(28, 36), Color(0.62, 0.48, 0.76), Color(0.78, 0.66, 0.88)))
	_spawn_prop(entities, "Table", Vector2i(30, 14),
		TileFactory.create_prop_texture(Vector2i(36, 24), Color(0.58, 0.42, 0.28), Color(0.72, 0.56, 0.36)))
	_spawn_prop(entities, "Tree", Vector2i(2, 3),
		TileFactory.create_prop_texture(Vector2i(32, 40), Color(0.32, 0.58, 0.28), Color(0.48, 0.74, 0.36)))
	_spawn_prop(entities, "Tree2", Vector2i(8, 2),
		TileFactory.create_prop_texture(Vector2i(32, 40), Color(0.30, 0.54, 0.26), Color(0.44, 0.70, 0.34)))

	var companion := COMPANION_SCENE.instantiate() as Area2D
	entities.add_child(companion)
	companion.position = _cell_to_feet(Vector2i(28, 13))


func set_plot_watered(plot_id: int, watered: bool) -> void:
	if not _plot_cells.has(plot_id):
		return
	var cell: Vector2i = _plot_cells[plot_id]
	_tile_layer.set_cell(cell, 0, T_SOIL_WET if watered else T_SOIL_DRY)


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


func _cell_to_feet(cell: Vector2i) -> Vector2:
	return Vector2(
		cell.x * TILE_SIZE + TILE_SIZE * 0.5,
		cell.y * TILE_SIZE + TILE_SIZE * 0.85
	)


func _create_tileset() -> TileSet:
	var tileset := TileSet.new()
	var atlas := TileSetAtlasSource.new()
	atlas.texture = TileFactory.create_tileset_texture()
	atlas.texture_region_size = Vector2i(TILE_SIZE, TILE_SIZE)
	for i in range(6):
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
