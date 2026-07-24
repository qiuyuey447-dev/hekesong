class_name FarmMapBuilder
extends RefCounted

const TILESET: TileSet = preload("res://Tilesets/Super_Retro_Tilesets.tres")
const TILE_SIZE := 16
const CAMERA_ZOOM := 2.0

const SRC_MAIN := 0

const TERRAIN_GRASS := Vector2i(0, 0)
const TERRAIN_DIRT := Vector2i(0, 1)
const TERRAIN_ROAD := Vector2i(0, 2)
const TERRAIN_FENCE := Vector2i(3, 0)

const TREE_TILES: Array[Vector3i] = [
	Vector3i(SRC_MAIN, 21, 1),
	Vector3i(SRC_MAIN, 19, 1),
	Vector3i(SRC_MAIN, 23, 1),
]

const FLOWER_SPRITE_PATHS: PackedStringArray = [
	"res://Props/Crops/Sprites/crop_11.png",
	"res://Props/Crops/Sprites/crop_12.png",
]

const ROCK_SPRITE_PATHS: PackedStringArray = [
	"res://Props/Rocks/Sprites/rock_16.png",
	"res://Props/Rocks/Sprites/rock_18.png",
	"res://Props/Rocks/Sprites/rock_20.png",
	"res://Props/Rocks/Sprites/rock_22.png",
]


static func compute_map_size(viewport_size: Vector2) -> Vector2i:
	var w := maxi(32, int(ceil(viewport_size.x / CAMERA_ZOOM / float(TILE_SIZE))))
	var h := maxi(18, int(ceil(viewport_size.y / CAMERA_ZOOM / float(TILE_SIZE))))
	return Vector2i(w, h)


static func build(parent: Node2D, map_size: Vector2i) -> Dictionary:
	var root := Node2D.new()
	root.name = "FarmMap"
	root.y_sort_enabled = true
	parent.add_child(root)

	var floor := _make_layer("Floor", 0)
	var trees := _make_layer("Trees", 1)
	var decor := Node2D.new()
	decor.name = "Decor"
	decor.y_sort_enabled = true
	decor.z_index = 3
	root.add_child(floor)
	root.add_child(trees)
	root.add_child(decor)

	var layout := _compute_layout(map_size)
	var blocked: Dictionary = {}

	_paint_grass(floor, map_size, layout)
	_paint_road(floor, layout.road_cells)
	_paint_farm_soil(floor, layout.farm_rect)
	_paint_fence(floor, map_size, blocked)
	_paint_trees(trees, layout.tree_cells, blocked)
	_add_props(decor, layout)
	_add_flower_props(decor, layout.flower_cells)
	_add_rock_props(decor, layout.rock_cells)

	return {
		"map_root": root,
		"map_size": map_size,
		"walk_bounds": layout.walk_bounds,
		"blocked_cells": blocked,
		"spawn_cell": layout.spawn_cell,
		"companion_cell": layout.companion_cell,
		"door_cell": layout.door_cell,
		"plot_cells": layout.plot_cells,
		"home_cell": layout.home_cell,
	}


static func _make_layer(layer_name: String, z: int) -> TileMapLayer:
	var layer := TileMapLayer.new()
	layer.name = layer_name
	layer.tile_set = TILESET
	layer.z_index = z
	layer.texture_filter = CanvasItem.TEXTURE_FILTER_NEAREST
	layer.y_sort_enabled = true
	return layer


static func _compute_layout(map_size: Vector2i) -> Dictionary:
	var mw := map_size.x
	var mh := map_size.y
	var margin := 1

	var home_rect := Rect2i(2, 2, maxi(8, int(mw * 0.24)), maxi(6, int(mh * 0.30)))
	var farm_rect := Rect2i(
		mw - maxi(10, int(mw * 0.30)) - 2,
		mh - maxi(7, int(mh * 0.34)) - 2,
		maxi(10, int(mw * 0.30)),
		maxi(7, int(mh * 0.34))
	)
	var plaza_rect := Rect2i(
		int(mw * 0.36),
		int(mh * 0.30),
		maxi(8, int(mw * 0.22)),
		maxi(6, int(mh * 0.24))
	)

	var home_cell := Vector2i(home_rect.position.x + 3, home_rect.position.y + 3)
	var companion_cell := Vector2i(
		plaza_rect.position.x + plaza_rect.size.x / 2,
		plaza_rect.position.y + plaza_rect.size.y / 2 + 1
	)
	var door_cell := Vector2i(home_rect.end.x - 1, home_rect.position.y + home_rect.size.y / 2)

	var farm_origin := Vector2i(farm_rect.position.x + 2, farm_rect.position.y + 2)
	var plot_cells: Array[Vector2i] = [
		farm_origin + Vector2i(0, 0),
		farm_origin + Vector2i(1, 0),
		farm_origin + Vector2i(2, 0),
		farm_origin + Vector2i(0, 1),
		farm_origin + Vector2i(1, 1),
	]

	var road_cells: Dictionary = {}
	_carve_path(road_cells, home_cell + Vector2i(1, 2), companion_cell)
	_carve_path(road_cells, companion_cell, farm_origin + Vector2i(1, 0))
	_widen_path(road_cells, 1)

	var layout := {
		"home_rect": home_rect,
		"farm_rect": farm_rect,
		"plaza_rect": plaza_rect,
		"home_cell": home_cell,
		"companion_cell": companion_cell,
		"door_cell": door_cell,
		"spawn_cell": companion_cell + Vector2i(1, 0),
		"plot_cells": plot_cells,
		"road_cells": road_cells,
		"tree_cells": [] as Array[Vector2i],
		"flower_cells": [] as Array[Vector2i],
		"rock_cells": [] as Array[Vector2i],
		"walk_bounds": Rect2i(margin, margin, mw - margin * 2, mh - margin * 2),
		"map_size": map_size,
	}

	layout["protected"] = _build_protected(layout, margin)
	_place_nature(layout)

	return layout


static func _build_protected(layout: Dictionary, _margin: int) -> Dictionary:
	var protected: Dictionary = {}
	_grow_rect_into(protected, layout.home_rect, 2)
	_grow_rect_into(protected, layout.farm_rect, 1)
	_grow_rect_into(protected, layout.plaza_rect, 1)

	for cell in layout.road_cells.keys():
		protected[cell] = true
	for cell in layout.plot_cells:
		protected[cell] = true

	return protected


static func _grow_rect_into(protected: Dictionary, rect: Rect2i, pad: int) -> void:
	for x in range(rect.position.x - pad, rect.end.x + pad):
		for y in range(rect.position.y - pad, rect.end.y + pad):
			protected[Vector2i(x, y)] = true


static func _place_nature(layout: Dictionary) -> void:
	_place_trees(layout, layout.protected)
	_place_flowers(layout, layout.protected)
	_place_rocks(layout, layout.protected)


static func _place_trees(layout: Dictionary, protected: Dictionary) -> void:
	var map_size: Vector2i = layout.map_size
	var trees: Array[Vector2i] = layout.tree_cells
	var home_rect: Rect2i = layout.home_rect
	var farm_rect: Rect2i = layout.farm_rect

	for x in range(3, map_size.x - 3, 3):
		_try_add_tree(trees, Vector2i(x, 2), protected, home_rect)

	for y in range(6, map_size.y - 4, 4):
		_try_add_tree(trees, Vector2i(2, y), protected, home_rect)
		_try_add_tree(trees, Vector2i(map_size.x - 3, y), protected, home_rect)

	var gap_x0 := home_rect.end.x + 2
	var gap_x1 := farm_rect.position.x - 2
	if gap_x1 > gap_x0 + 4:
		for x in range(gap_x0, gap_x1, 4):
			_try_add_tree(trees, Vector2i(x, map_size.y - 4), protected, home_rect)

	layout.tree_cells = trees


static func _try_add_tree(
	trees: Array[Vector2i],
	cell: Vector2i,
	protected: Dictionary,
	home_rect: Rect2i
) -> void:
	if protected.has(cell):
		return
	if home_rect.has_point(cell):
		return
	if cell in trees:
		return
	trees.append(cell)


static func _place_flowers(layout: Dictionary, protected: Dictionary) -> void:
	var flowers: Array[Vector2i] = layout.flower_cells
	var map_size: Vector2i = layout.map_size

	for x in range(3, map_size.x - 3):
		for y in range(3, map_size.y - 3):
			var cell := Vector2i(x, y)
			if protected.has(cell):
				continue
			if layout.road_cells.has(cell):
				continue
			if layout.farm_rect.has_point(cell):
				continue
			if cell in layout.tree_cells:
				continue
			if _cell_hash(cell) % 23 != 0:
				continue
			flowers.append(cell)

	layout.flower_cells = flowers


static func _place_rocks(layout: Dictionary, protected: Dictionary) -> void:
	var rocks: Array[Vector2i] = layout.rock_cells
	var map_size: Vector2i = layout.map_size

	for x in range(3, map_size.x - 3):
		for y in range(3, map_size.y - 3):
			var cell := Vector2i(x, y)
			if protected.has(cell):
				continue
			if layout.road_cells.has(cell):
				continue
			if layout.farm_rect.has_point(cell):
				continue
			if cell in layout.tree_cells:
				continue
			if _cell_hash(cell) % 41 != 5:
				continue
			rocks.append(cell)

	layout.rock_cells = rocks


static func _paint_grass(floor: TileMapLayer, map_size: Vector2i, _layout: Dictionary) -> void:
	var cells: Array[Vector2i] = []
	for x in range(1, map_size.x - 1):
		for y in range(1, map_size.y - 1):
			cells.append(Vector2i(x, y))
	if not cells.is_empty():
		floor.set_cells_terrain_connect(cells, TERRAIN_GRASS.x, TERRAIN_GRASS.y)


static func _paint_road(floor: TileMapLayer, road_cells: Dictionary) -> void:
	if road_cells.is_empty():
		return
	var cells: Array[Vector2i] = []
	for cell in road_cells.keys():
		cells.append(cell)
	floor.set_cells_terrain_connect(cells, TERRAIN_ROAD.x, TERRAIN_ROAD.y)


static func _paint_farm_soil(floor: TileMapLayer, farm_rect: Rect2i) -> void:
	var cells: Array[Vector2i] = []
	for x in range(farm_rect.position.x, farm_rect.end.x):
		for y in range(farm_rect.position.y, farm_rect.end.y):
			cells.append(Vector2i(x, y))
	if not cells.is_empty():
		floor.set_cells_terrain_connect(cells, TERRAIN_DIRT.x, TERRAIN_DIRT.y)


static func _paint_fence(floor: TileMapLayer, map_size: Vector2i, blocked: Dictionary) -> void:
	var cells: Array[Vector2i] = []
	for x in range(map_size.x):
		for y in range(map_size.y):
			if x == 0 or y == 0 or x == map_size.x - 1 or y == map_size.y - 1:
				var cell := Vector2i(x, y)
				cells.append(cell)
				blocked[cell] = true
	if not cells.is_empty():
		floor.set_cells_terrain_connect(cells, TERRAIN_FENCE.x, TERRAIN_FENCE.y)


static func _paint_trees(trees: TileMapLayer, tree_cells: Array[Vector2i], blocked: Dictionary) -> void:
	for i in range(tree_cells.size()):
		var cell: Vector2i = tree_cells[i]
		var tile: Vector3i = TREE_TILES[i % TREE_TILES.size()]
		trees.set_cell(cell, tile.x, Vector2i(tile.y, tile.z), 0)
		blocked[cell] = true


static func _add_flower_props(decor: Node2D, flower_cells: Array[Vector2i]) -> void:
	for i in range(flower_cells.size()):
		var cell: Vector2i = flower_cells[i]
		var path: String = FLOWER_SPRITE_PATHS[i % FLOWER_SPRITE_PATHS.size()]
		_add_sprite_prop(decor, "Flower_%d" % i, path, cell, Vector2(0, 4), 2)


static func _add_props(decor: Node2D, layout: Dictionary) -> void:
	var home_rect: Rect2i = layout.home_rect
	var home_cell: Vector2i = layout.home_cell

	_add_sprite_prop(
		decor, "Home", "res://Props/Houses/Sprites/house_01.png",
		home_cell, Vector2(0, 8), 10
	)
	_add_sprite_prop(
		decor, "Well", "res://Props/Water/water_02_16x16.png",
		layout.companion_cell + Vector2i(-1, 0), Vector2(0, 0), 5
	)
	_add_sprite_prop(
		decor, "Barrel", "res://Props/Barrels/Sprites/barrel_02.png",
		layout.door_cell + Vector2i(0, 1), Vector2(0, 4), 4
	)
	_add_sprite_prop(
		decor, "Campfire", "res://Props/Fire/campfire_16x32.png",
		home_cell + Vector2i(home_rect.size.x - 2, 2), Vector2(0, 8), 4
	)
	_add_sprite_prop(
		decor, "Torch", "res://Props/Torches/Sprites/Torch_01.png",
		layout.plaza_rect.position + Vector2i(1, 0), Vector2(0, 4), 4
	)
	_add_sprite_prop(
		decor, "Crate", "res://Props/Crates/Sprites/crate_02.png",
		layout.farm_rect.position + Vector2i(1, 1), Vector2(0, 4), 3
	)


static func _add_rock_props(decor: Node2D, rock_cells: Array[Vector2i]) -> void:
	for i in range(rock_cells.size()):
		var cell: Vector2i = rock_cells[i]
		var path: String = ROCK_SPRITE_PATHS[i % ROCK_SPRITE_PATHS.size()]
		_add_sprite_prop(decor, "Rock_%d" % i, path, cell, Vector2(0, 2), 2)


static func _add_sprite_prop(
	parent: Node2D,
	prop_name: String,
	texture_path: String,
	cell: Vector2i,
	extra_offset: Vector2,
	z: int
) -> void:
	var tex := load(texture_path) as Texture2D
	if tex == null:
		return
	var spr := Sprite2D.new()
	spr.name = prop_name
	spr.texture = tex
	spr.texture_filter = CanvasItem.TEXTURE_FILTER_NEAREST
	spr.centered = false
	spr.z_index = z
	spr.position = Vector2(cell.x * TILE_SIZE, cell.y * TILE_SIZE)
	spr.offset = Vector2(-tex.get_width() * 0.5, -tex.get_height() + 8.0) + extra_offset
	parent.add_child(spr)


static func _carve_path(cells: Dictionary, from: Vector2i, to: Vector2i) -> void:
	var cur := from
	cells[cur] = true
	while cur.x != to.x:
		cur.x += signi(to.x - cur.x)
		cells[cur] = true
	while cur.y != to.y:
		cur.y += signi(to.y - cur.y)
		cells[cur] = true


static func _widen_path(cells: Dictionary, radius: int) -> void:
	var expanded: Dictionary = {}
	for cell in cells.keys():
		for dx in range(-radius, radius + 1):
			for dy in range(-radius, radius + 1):
				expanded[cell + Vector2i(dx, dy)] = true
	cells.clear()
	for cell in expanded.keys():
		cells[cell] = true


static func _cell_hash(cell: Vector2i) -> int:
	return absi(cell.x * 73856093 ^ cell.y * 19349663)
