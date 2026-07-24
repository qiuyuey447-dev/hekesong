extends RefCounted

const SAMPLE_SCENE: PackedScene = preload("res://scenes/Super_Retro_World_Sample_Scene.tscn")

const TILE_SIZE := 16
const MAP_SCALE := Vector2(2.8, 2.8)

# 坐标对齐 Super Retro 示例地图（约 x:11-19, y:11-18）
# 区域：左上 home | 中央 NPC+井 | 右下农田
const SPAWN_CELL := Vector2i(13, 16)
const DOOR_CELL := Vector2i(17, 13)
const COMPANION_CELL := Vector2i(11, 14)

const PLOT_CELLS: Array[Vector2i] = [
	Vector2i(12, 13), Vector2i(13, 13), Vector2i(14, 13),
	Vector2i(12, 14), Vector2i(13, 14),
]

const HOME_SPRITE_CELL := Vector2i(9, 10)


static func build() -> Node2D:
	var root := SAMPLE_SCENE.instantiate() as Node2D
	root.name = "FarmMap"
	root.y_sort_enabled = true
	_add_home_sprite(root)
	return root


static func get_walk_bounds(farm_map: Node2D) -> Rect2i:
	var floor_map := farm_map.get_node("Floor") as TileMap
	return floor_map.get_used_rect().grow(2)


static func get_blocked_cells(farm_map: Node2D) -> Dictionary:
	var blocked: Dictionary = {}
	var trees := farm_map.get_node_or_null("Trees") as TileMap
	if trees == null:
		return blocked
	for cell in trees.get_used_cells(0):
		blocked[cell] = true
	return blocked


static func center_on_viewport(farm_map: Node2D, viewport_size: Vector2) -> void:
	var floor_map := farm_map.get_node("Floor") as TileMap
	var used := floor_map.get_used_rect()
	var map_size_px := Vector2(used.size) * float(TILE_SIZE) * MAP_SCALE
	var map_offset_px := Vector2(used.position) * float(TILE_SIZE) * MAP_SCALE
	var focus := Vector2(viewport_size.x * 0.52, viewport_size.y * 0.44)
	farm_map.position = focus - map_offset_px - map_size_px * 0.5


static func cell_to_local(cell: Vector2i) -> Vector2:
	return Vector2(
		cell.x * TILE_SIZE + TILE_SIZE * 0.5,
		cell.y * TILE_SIZE + TILE_SIZE - 4
	)


static func _add_home_sprite(root: Node2D) -> void:
	var tex := load("res://Props/Houses/Sprites/house_01.png") as Texture2D
	if tex == null:
		return
	var house := Sprite2D.new()
	house.name = "Home"
	house.texture = tex
	house.texture_filter = CanvasItem.TEXTURE_FILTER_NEAREST
	house.centered = false
	house.position = Vector2(HOME_SPRITE_CELL.x * TILE_SIZE, HOME_SPRITE_CELL.y * TILE_SIZE)
	house.offset = Vector2(-tex.get_width() * 0.5, -tex.get_height() + 8)
	root.add_child(house)
