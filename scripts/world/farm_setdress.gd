class_name FarmSetdress
extends RefCounted
## 十日版院子：旧屋、廊下、萝卜田、树洞、商店分开放。廊下是田边避雨亭，不贴屋墙。

const HOUSE_TEX: Texture2D = preload("res://Props/Houses/Sprites/house_02.png")
const SHED_TEX: Texture2D = preload("res://Props/Houses/Sprites/house_10.png")
const TREE_TEX: Texture2D = preload("res://Props/Trees/Sprites/tree_04.png")
const TREE_HOLLOW_TEX: Texture2D = preload("res://Props/Trees/Sprites/tree_03.png")
const TREE_B: Texture2D = preload("res://Props/Trees/Sprites/tree_05.png")
const TREE_C: Texture2D = preload("res://Props/Trees/Sprites/tree_10.png")
const BARREL_TEX: Texture2D = preload("res://Props/Barrels/Sprites/barrel_02.png")
const BOOK_TEX: Texture2D = preload("res://Props/Books/Sprites/book_01.png")
const CRATE_TEX: Texture2D = preload("res://Props/Crates/Sprites/crate_02.png")
const LAMP_TEX: Texture2D = preload("res://Props/Lamps/Sprites/lamp_04.png")

const PLANT_POT_A: Texture2D = preload("res://Props/Potted plants/Sprites/potted_plant_01.png")
const PLANT_POT_B: Texture2D = preload("res://Props/Potted plants/Sprites/potted_plant_06.png")
const FLOWER_A: Texture2D = preload("res://Props/Potted plants/Sprites/potted_plant_08.png")
const FLOWER_B: Texture2D = preload("res://Props/Potted plants/Sprites/potted_plant_07.png")
const BUSH_A: Texture2D = preload("res://Props/Trees/Sprites/tree_01.png")
const BUSH_B: Texture2D = preload("res://Props/Trees/Sprites/tree_02.png")

# 旧屋偏西北，廊下仍在田北，商店偏东北。三处用带弯的路连成一圈。
const POS_HOME := Vector2(832, 400)
const POS_PORCH := Vector2(1040, 640)
const POS_FOX := Vector2(1216, 568)
const POS_HOLLOW := Vector2(1184, 552)
const POS_SHOP := Vector2(1360, 384)
const POS_RIDGE := Vector2(1520, 672)
const POS_EMPTY := Vector2(1688, 780)
const POS_RIVER := Vector2(700, 560)

const ACTORS_NAME := "Entities"
const YARD_CLEAR := Rect2(720, 250, 700, 430)
# 廊下以南、田以西：原地图广场（断头路、告示牌、雕像），清掉改成草地。
const PLAZA_CLEAR := Rect2(720, 670, 728, 430)
const FARM_KEEP_X := 1448.0
const FIELD_KEEP := Rect2i(46, 21, 5, 6)
const RIVER_KEEP_X := 720.0
const PORCH_HALF_W := 126.0
const PORCH_DECK_H := 80.0
const TERRAIN_SET_GROUND := 0
const TERRAIN_DIRT := 1
const TERRAIN_ROAD := 2
const SRC_DECOR := 0
const DETAIL_LAYER := "地面细节"
const TUFT_TILES: Array[Vector2i] = [
	Vector2i(17, 2), Vector2i(19, 4), Vector2i(20, 4), Vector2i(22, 4), Vector2i(23, 4),
]
const ROCK_A: Texture2D = preload("res://Props/Rocks/Sprites/rock_18.png")
const ROCK_B: Texture2D = preload("res://Props/Rocks/Sprites/rock_20.png")
const ROCK_C: Texture2D = preload("res://Props/Rocks/Sprites/rock_22.png")

const _SETDRESS_NAMES: Array[String] = [
	"OldHouse", "DoorBarrel", "DoorPlant", "PorchDeck", "PorchRoof",
	"PorchPillarL", "PorchPillarR", "PorchWetEdge", "Kettle", "Bowl", "HerBowl",
	"PorchLamp", "PorchCrate", "PorchRail", "PorchPillarM", "HollowTree", "HollowBook",
	"RidgeRockA", "RidgeRockB", "RidgeBarrel", "ShopStall", "Setdress",
	"YardPath", "YardTufts", "YardEdge", "地面细节",
	"HousePotL", "HousePotR", "HouseBushW", "HouseBushE", "HouseTreeN", "HousePotFront",
	"PorchBushL", "PorchBushR", "PorchFern", "PorchPot", "PorchTree",
	"FieldBushW", "FieldBushSW", "FieldBushE", "FieldBushSE", "FieldBushS",
	"FieldRockA", "FieldRockB", "FieldRockC", "FieldBarrel", "FieldPot", "FieldHay",
	"PathTreeA", "PathBushA", "PathBushB", "PathRockA", "YardFill", "HollowLamp",
]


static func apply(farm_map: Node2D, actors: Node2D = null) -> Node2D:
	sync_markers(farm_map)
	_prepare_ground_layers(farm_map)
	_punch_clearing(farm_map)
	if actors == null:
		actors = ensure_actors(farm_map)
	_clear_old_setdress(farm_map, actors)
	_paint_yard_floors(farm_map)
	_add_house(actors, marker_position(farm_map, "人", POS_HOME))
	_add_house_greens(actors, marker_position(farm_map, "人", POS_HOME))
	_add_porch(actors, marker_position(farm_map, "廊下", POS_PORCH))
	_add_porch_greens(actors, marker_position(farm_map, "廊下", POS_PORCH))
	_add_field_dress(actors)
	_add_path_greens(actors)
	_add_yard_fill(actors)
	_add_yard_edge_props(actors)
	_add_hollow_tree(actors, marker_position(farm_map, "树洞", POS_HOLLOW))
	_nudge_spawned_actors(actors, farm_map)
	if actors.get_node_or_null("Shop") == null:
		var stall := Node2D.new()
		stall.name = "ShopStall"
		stall.position = marker_position(farm_map, "商店", POS_SHOP)
		actors.add_child(stall)
		build_shop_stall(stall)
	return actors


static func sync_markers(farm_map: Node2D) -> void:
	_set_marker(farm_map, "人", POS_HOME)
	_set_marker(farm_map, "廊下", POS_PORCH)
	_set_marker(farm_map, "小狸", POS_FOX)
	_set_marker(farm_map, "树洞", POS_HOLLOW)
	_set_marker(farm_map, "商店", POS_SHOP)
	_set_marker(farm_map, "田埂", POS_RIDGE)
	_set_marker(farm_map, "空土垄", POS_EMPTY)
	_set_marker(farm_map, "河边", POS_RIVER)


static func ensure_actors(farm_map: Node2D) -> Node2D:
	var actors := farm_map.get_node_or_null(ACTORS_NAME) as Node2D
	if actors == null:
		actors = Node2D.new()
		actors.name = ACTORS_NAME
		farm_map.add_child(actors)
	actors.y_sort_enabled = true
	actors.z_index = 1
	actors.z_as_relative = true
	return actors


static func marker_position(farm_map: Node2D, marker_name: String, fallback: Vector2) -> Vector2:
	return _marker(farm_map, marker_name, fallback)


static func living_yard_rect(farm_map: Node2D) -> Rect2:
	var rect := Rect2(_marker(farm_map, "人", POS_HOME), Vector2.ZERO)
	for marker_name in ["廊下", "小狸", "树洞", "商店", "田埂", "空土垄", "河边"]:
		var node := farm_map.get_node_or_null(marker_name) as Node2D
		if node != null:
			rect = rect.expand(node.position)
	rect = rect.expand(Vector2(1488, 688))
	rect = rect.expand(Vector2(1616, 848))
	return rect


static func porch_shelter_rect(farm_map: Node2D) -> Rect2:
	var porch := _marker(farm_map, "廊下", POS_PORCH)
	return Rect2(porch.x - PORCH_HALF_W, porch.y - 112.0, PORCH_HALF_W * 2.0, 132.0)


static func story_pois(farm_map: Node2D, field_center: Vector2, shop_position: Vector2) -> Array[Dictionary]:
	return [
		{"id": "home", "name": "旧屋门口", "pos": _marker(farm_map, "人", POS_HOME), "radius": 95.0},
		{"id": "porch", "name": "廊下", "pos": _marker(farm_map, "廊下", POS_PORCH), "radius": 120.0},
		{"id": "field", "name": "萝卜田", "pos": field_center, "radius": 140.0},
		{"id": "ridge", "name": "田埂", "pos": _marker(farm_map, "田埂", POS_RIDGE), "radius": 80.0},
		{"id": "hollow", "name": "树洞", "pos": _marker(farm_map, "树洞", POS_HOLLOW), "radius": 100.0},
		{"id": "shop", "name": "商店", "pos": shop_position, "radius": 120.0},
		{"id": "empty", "name": "空土垄", "pos": _marker(farm_map, "空土垄", POS_EMPTY), "radius": 70.0},
		{"id": "river", "name": "河边", "pos": _marker(farm_map, "河边", POS_RIVER), "radius": 90.0},
	]


static func build_shop_stall(parent: Node2D) -> void:
	var pad := Sprite2D.new()
	pad.name = "ShopPad"
	pad.texture = _shop_pad_texture()
	pad.texture_filter = CanvasItem.TEXTURE_FILTER_NEAREST
	pad.centered = true
	pad.position = Vector2(4, 10)
	pad.z_index = -2
	parent.add_child(pad)

	_add_sprite(
		parent,
		"ShopShed",
		SHED_TEX,
		Vector2(6, -8),
		Vector2(2.05, 2.05),
		Vector2(SHED_TEX.get_width() * -0.5, -SHED_TEX.get_height() + 6)
	)

	var crate_tex := SpriteSheet.grid_frame(CRATE_TEX, Vector2i(16, 16), 0, 0)
	_add_sprite(parent, "ShopCrateL", crate_tex, Vector2(-34, 8), Vector2(2.8, 2.8), Vector2(-8, -16))
	_add_sprite(parent, "ShopCrateM", crate_tex, Vector2(-4, 14), Vector2(3.0, 3.0), Vector2(-8, -16))
	_add_sprite(parent, "ShopCrateR", crate_tex, Vector2(28, 6), Vector2(2.6, 2.6), Vector2(-8, -16))
	_add_sprite(parent, "ShopBarrel", BARREL_TEX, Vector2(52, 10), Vector2(2.2, 2.2), Vector2(-8, -18))

	var sign_board := Sprite2D.new()
	sign_board.name = "ShopSignBoard"
	sign_board.texture = _shop_sign_texture()
	sign_board.texture_filter = CanvasItem.TEXTURE_FILTER_NEAREST
	sign_board.centered = true
	sign_board.position = Vector2(0, -78)
	parent.add_child(sign_board)

	var seed_icon := Sprite2D.new()
	seed_icon.name = "ShopSeedIcon"
	seed_icon.texture = ShopCatalog.get_item_icon(ShopCatalog.SHOP_ITEMS[0])
	seed_icon.texture_filter = CanvasItem.TEXTURE_FILTER_NEAREST
	seed_icon.centered = true
	seed_icon.scale = Vector2(2.2, 2.2)
	seed_icon.position = Vector2(-36, -78)
	parent.add_child(seed_icon)

	var label := Label.new()
	label.name = "ShopLabel"
	label.text = "商店"
	label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	label.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	label.add_theme_color_override("font_color", Color(0.98, 0.93, 0.72))
	label.add_theme_color_override("font_outline_color", Color(0.22, 0.12, 0.06))
	label.add_theme_constant_override("outline_size", 5)
	label.add_theme_font_size_override("font_size", 22)
	label.mouse_filter = Control.MOUSE_FILTER_IGNORE
	label.position = Vector2(-22, -90)
	label.size = Vector2(72, 26)
	var tree := Engine.get_main_loop() as SceneTree
	if tree != null:
		var theme_node := tree.root.get_node_or_null("UIFontTheme")
		if theme_node != null and theme_node.has_method("apply_control"):
			theme_node.apply_control(label)
	parent.add_child(label)


static func _marker(farm_map: Node2D, marker_name: String, fallback: Vector2) -> Vector2:
	var node := farm_map.get_node_or_null(marker_name) as Node2D
	if node != null:
		return node.position
	return fallback


static func _set_marker(farm_map: Node2D, marker_name: String, pos: Vector2) -> void:
	var node := farm_map.get_node_or_null(marker_name) as Node2D
	if node == null:
		node = Marker2D.new()
		node.name = marker_name
		farm_map.add_child(node)
	node.position = pos


static func _nudge_spawned_actors(actors: Node2D, farm_map: Node2D) -> void:
	var shop := actors.get_node_or_null("Shop") as Node2D
	if shop != null:
		shop.position = marker_position(farm_map, "商店", POS_SHOP)
	var hollow := actors.get_node_or_null("TreeHollow") as Node2D
	if hollow != null:
		hollow.position = marker_position(farm_map, "树洞", POS_HOLLOW)
	var companion := actors.get_node_or_null("Companion") as Node2D
	if companion != null:
		companion.position = marker_position(farm_map, "小狸", POS_FOX)


static func _prepare_ground_layers(farm_map: Node2D) -> void:
	farm_map.y_sort_enabled = false
	for child in farm_map.get_children():
		if child is TileMapLayer:
			var layer := child as TileMapLayer
			layer.z_index = 0
			layer.y_sort_enabled = false
	var house_layer := farm_map.get_node_or_null("家") as TileMapLayer
	if house_layer != null:
		house_layer.visible = false
	var shop_layer := farm_map.get_node_or_null("商店以及附属品") as TileMapLayer
	if shop_layer != null:
		shop_layer.visible = false
	var sand := farm_map.get_node_or_null("沙地") as TileMapLayer
	if sand != null:
		sand.visible = false
	var decor := farm_map.get_node_or_null("河流树木家园") as TileMapLayer
	if decor != null:
		decor.modulate = Color(0.86, 0.90, 0.82, 1.0)


static func _punch_clearing(farm_map: Node2D) -> void:
	for layer_name in ["河流树木家园", "沙地", "商店以及附属品"]:
		var layer := farm_map.get_node_or_null(layer_name) as TileMapLayer
		if layer == null:
			continue
		var cells := layer.get_used_cells()
		for cell in cells:
			var world_pos := layer.to_global(layer.map_to_local(cell))
			if _should_keep_decor(world_pos):
				continue
			if _in_clear_zone(world_pos):
				layer.erase_cell(cell)


static func _in_clear_zone(world_pos: Vector2) -> bool:
	return YARD_CLEAR.has_point(world_pos) or PLAZA_CLEAR.has_point(world_pos)


static func _should_keep_decor(world_pos: Vector2) -> bool:
	if world_pos.x < RIVER_KEEP_X:
		return true
	if world_pos.x >= FARM_KEEP_X:
		return true
	return false


static func _paint_yard_floors(farm_map: Node2D) -> void:
	var grass := farm_map.get_node_or_null("草地") as TileMapLayer
	if grass == null or grass.tile_set == null:
		return

	var porch_cell := _world_to_cell(grass, marker_position(farm_map, "廊下", POS_PORCH))
	var home_cell := _world_to_cell(grass, marker_position(farm_map, "人", POS_HOME))
	var ridge_cell := _world_to_cell(grass, marker_position(farm_map, "田埂", POS_RIDGE))
	var shop_cell := _world_to_cell(grass, marker_position(farm_map, "商店", POS_SHOP))
	var hollow_cell := _world_to_cell(grass, marker_position(farm_map, "树洞", POS_HOLLOW))

	var dirt: Dictionary = {}
	var road: Dictionary = {}

	_fill_rect(dirt, home_cell + Vector2i(-2, 0), 5, 3)
	_fill_rect(dirt, porch_cell + Vector2i(-2, 0), 5, 3)
	_fill_rect(dirt, shop_cell + Vector2i(-1, 0), 4, 3)
	_stamp_mud(dirt, _world_to_cell(grass, Vector2(768, 620)), 2, 1)
	_stamp_mud(dirt, _world_to_cell(grass, Vector2(1320, 560)), 2, 2)

	_carve_polyline(road, _path_home_porch(home_cell, porch_cell))
	_carve_polyline(road, _path_porch_shop(porch_cell, shop_cell))
	_carve_polyline(road, _path_porch_field(porch_cell, ridge_cell))
	_widen_path(road, 1)
	var branch: Dictionary = {}
	_carve_polyline(branch, _path_home_shop(home_cell, shop_cell))
	_carve_path(branch, porch_cell + Vector2i(2, -1), hollow_cell)
	_carve_path(branch, shop_cell, ridge_cell)
	_widen_path(branch, 0)
	for cell in branch.keys():
		road[cell] = true

	for cell in road.keys():
		dirt.erase(cell)
	for cell in _dict_cells(dirt):
		if FIELD_KEEP.has_point(cell):
			dirt.erase(cell)
	for cell in _dict_cells(road):
		if FIELD_KEEP.has_point(cell):
			road.erase(cell)

	var hole_cells: Array[Vector2i] = []
	var yard_start := _world_to_cell(grass, YARD_CLEAR.position)
	var yard_end := _world_to_cell(grass, YARD_CLEAR.position + YARD_CLEAR.size)
	var x0 := mini(yard_start.x, yard_end.x)
	var x1 := maxi(yard_start.x, yard_end.x)
	var y0 := mini(yard_start.y, yard_end.y)
	var y1 := maxi(yard_start.y, yard_end.y)
	for x in range(x0, x1 + 1):
		for y in range(y0, y1 + 1):
			var cell := Vector2i(x, y)
			if FIELD_KEEP.has_point(cell) or cell in road or cell in dirt:
				continue
			if grass.get_cell_source_id(cell) < 0:
				hole_cells.append(cell)

	if not hole_cells.is_empty():
		grass.set_cells_terrain_connect(hole_cells, TERRAIN_SET_GROUND, 0)
	_paint_south_meadow(grass, road, dirt)
	var dirt_cells := _dict_cells(dirt)
	if not dirt_cells.is_empty():
		grass.set_cells_terrain_connect(dirt_cells, TERRAIN_SET_GROUND, TERRAIN_DIRT)
	var road_cells := _dict_cells(road)
	if not road_cells.is_empty():
		grass.set_cells_terrain_connect(road_cells, TERRAIN_SET_GROUND, TERRAIN_ROAD)

	_paint_ground_detail(farm_map, grass, road)


static func _paint_south_meadow(grass: TileMapLayer, road: Dictionary, dirt: Dictionary) -> void:
	var start := _world_to_cell(grass, PLAZA_CLEAR.position)
	var end := _world_to_cell(grass, PLAZA_CLEAR.position + PLAZA_CLEAR.size)
	var x0 := mini(start.x, end.x)
	var x1 := maxi(start.x, end.x)
	var y0 := mini(start.y, end.y)
	var y1 := maxi(start.y, end.y)
	var meadow: Array[Vector2i] = []
	for x in range(x0, x1 + 1):
		for y in range(y0, y1 + 1):
			var cell := Vector2i(x, y)
			if FIELD_KEEP.has_point(cell) or cell in road or cell in dirt:
				continue
			var world_pos := grass.to_global(grass.map_to_local(cell))
			if _should_keep_decor(world_pos):
				continue
			meadow.append(cell)
	if not meadow.is_empty():
		grass.set_cells_terrain_connect(meadow, TERRAIN_SET_GROUND, 0)


static func _paint_ground_detail(
	farm_map: Node2D,
	grass: TileMapLayer,
	road: Dictionary
) -> void:
	var old := farm_map.get_node_or_null(DETAIL_LAYER)
	if old != null:
		old.name = DETAIL_LAYER + "_dead"
		old.queue_free()
	var detail := TileMapLayer.new()
	detail.name = DETAIL_LAYER
	detail.tile_set = grass.tile_set
	detail.scale = grass.scale
	detail.z_index = 0
	detail.y_sort_enabled = false
	detail.texture_filter = CanvasItem.TEXTURE_FILTER_NEAREST
	farm_map.add_child(detail)
	# 插在草地之上、装饰层之下
	farm_map.move_child(detail, grass.get_index() + 1)

	for cell in grass.get_used_cells():
		if not YARD_CLEAR.has_point(grass.to_global(grass.map_to_local(cell))):
			continue
		if cell in road:
			continue
		var beside_path := _is_adjacent_to(cell, road)
		var h := _cell_hash(cell)
		var garden := cell.y >= 12 and cell.y <= 20 and cell.x >= 25 and cell.x <= 44
		if FIELD_KEEP.has_point(cell):
			continue
		if garden and h % 3 == 0:
			detail.set_cell(cell, SRC_DECOR, TUFT_TILES[h % TUFT_TILES.size()])
		elif beside_path and h % 5 == 0:
			detail.set_cell(cell, SRC_DECOR, TUFT_TILES[h % TUFT_TILES.size()])


static func _world_to_cell(layer: TileMapLayer, world: Vector2) -> Vector2i:
	return layer.local_to_map(layer.to_local(world))


static func _fill_rect(cells: Dictionary, origin: Vector2i, w: int, h: int) -> void:
	for x in range(origin.x, origin.x + w):
		for y in range(origin.y, origin.y + h):
			cells[Vector2i(x, y)] = true


static func _stamp_mud(cells: Dictionary, origin: Vector2i, w: int, h: int) -> void:
	_fill_rect(cells, origin, w, h)
	if w >= 2 and h >= 2:
		cells[origin + Vector2i(w, 0)] = true
		cells[origin + Vector2i(0, h)] = true


static func _carve_path(cells: Dictionary, from: Vector2i, to: Vector2i) -> void:
	var cur := from
	cells[cur] = true
	while cur.x != to.x:
		cur.x += signi(to.x - cur.x)
		cells[cur] = true
	while cur.y != to.y:
		cur.y += signi(to.y - cur.y)
		cells[cur] = true


static func _carve_polyline(cells: Dictionary, points: Array[Vector2i]) -> void:
	if points.size() < 2:
		return
	for i in range(points.size() - 1):
		_carve_path(cells, points[i], points[i + 1])


static func _path_home_porch(home: Vector2i, porch: Vector2i) -> Array[Vector2i]:
	var door := home + Vector2i(0, 1)
	var y_bend := door.y + int((porch.y - door.y) * 2 / 3.0)
	var x_bend := door.x + int((porch.x - door.x) / 2.0)
	return [
		door,
		Vector2i(door.x, y_bend),
		Vector2i(x_bend, y_bend),
		Vector2i(x_bend, porch.y),
		porch,
	]


static func _path_porch_shop(porch: Vector2i, shop: Vector2i) -> Array[Vector2i]:
	var x_bend := porch.x + int((shop.x - porch.x) / 2.0) - 2
	var y_bend := shop.y + int((porch.y - shop.y) / 2.0)
	return [
		porch,
		Vector2i(x_bend, porch.y),
		Vector2i(x_bend, y_bend),
		Vector2i(shop.x, y_bend),
		shop,
	]


static func _path_porch_field(porch: Vector2i, field_gate: Vector2i) -> Array[Vector2i]:
	return [
		porch,
		Vector2i(porch.x + 4, porch.y),
		Vector2i(field_gate.x, porch.y),
		field_gate,
	]


static func _path_home_shop(home: Vector2i, shop: Vector2i) -> Array[Vector2i]:
	var north_y := mini(home.y, shop.y) - 2
	var x_mid := int((home.x + shop.x) / 2.0)
	return [
		home,
		Vector2i(home.x, north_y),
		Vector2i(x_mid, north_y),
		Vector2i(x_mid, north_y + 3),
		Vector2i(shop.x, north_y + 3),
		shop,
	]


static func _widen_path(cells: Dictionary, radius: int) -> void:
	if radius <= 0:
		return
	var expanded: Dictionary = {}
	for cell in cells.keys():
		for dx in range(-radius, radius + 1):
			for dy in range(-radius, radius + 1):
				expanded[cell + Vector2i(dx, dy)] = true
	cells.clear()
	for cell in expanded.keys():
		cells[cell] = true


static func _is_adjacent_to(cell: Vector2i, other: Dictionary) -> bool:
	for dx in range(-1, 2):
		for dy in range(-1, 2):
			if dx == 0 and dy == 0:
				continue
			if other.has(cell + Vector2i(dx, dy)):
				return true
	return false


static func _dict_cells(cells: Dictionary) -> Array[Vector2i]:
	var result: Array[Vector2i] = []
	for cell in cells.keys():
		result.append(cell)
	return result


static func _cell_hash(cell: Vector2i) -> int:
	return absi(cell.x * 73856093 ^ cell.y * 19349663)


static func _clear_old_setdress(farm_map: Node2D, actors: Node2D) -> void:
	for node_name in _SETDRESS_NAMES:
		_free_named(farm_map, node_name)
		if actors != farm_map:
			_free_named(actors, node_name)


static func _free_named(parent: Node, node_name: String) -> void:
	var old := parent.get_node_or_null(node_name)
	if old == null:
		return
	old.name = node_name + "_dead"
	old.queue_free()


static func _add_house(root: Node2D, feet: Vector2) -> void:
	_add_sprite(
		root,
		"OldHouse",
		HOUSE_TEX,
		feet,
		Vector2(3.2, 3.2),
		Vector2(HOUSE_TEX.get_width() * -0.5, -HOUSE_TEX.get_height() + 6)
	)


static func _add_house_greens(root: Node2D, feet: Vector2) -> void:
	# 门口盆栽、屋基灌木。不挡门。
	_add_plant(root, "HousePotL", PLANT_POT_B, feet + Vector2(-48, 14), 2.2)
	_add_plant(root, "HousePotR", PLANT_POT_A, feet + Vector2(50, 16), 2.1)
	_add_plant(root, "HouseBushW", BUSH_A, feet + Vector2(-108, 6), 2.2)


static func _add_porch(root: Node2D, feet: Vector2) -> void:
	# 独立避雨亭：加宽木地 + 三根廊柱 + 大廊檐。里侧干，南沿还在滴水。
	var deck := Sprite2D.new()
	deck.name = "PorchDeck"
	deck.texture = _porch_deck_texture()
	deck.texture_filter = CanvasItem.TEXTURE_FILTER_NEAREST
	deck.centered = false
	deck.offset = Vector2(-PORCH_HALF_W, -PORCH_DECK_H + 12.0)
	deck.position = feet
	deck.z_index = -1
	root.add_child(deck)

	var rail := Sprite2D.new()
	rail.name = "PorchRail"
	rail.texture = _porch_rail_texture()
	rail.texture_filter = CanvasItem.TEXTURE_FILTER_NEAREST
	rail.centered = false
	rail.offset = Vector2(-PORCH_HALF_W + 8.0, -PORCH_DECK_H + 4.0)
	rail.position = feet
	rail.z_index = 0
	root.add_child(rail)

	_add_sprite(root, "PorchPillarL", _porch_pillar_texture(), feet + Vector2(-108, 6), Vector2(1, 1), Vector2(-4, -52))
	_add_sprite(root, "PorchPillarM", _porch_pillar_texture(), feet + Vector2(0, -8), Vector2(1, 1), Vector2(-4, -52))
	_add_sprite(root, "PorchPillarR", _porch_pillar_texture(), feet + Vector2(108, 6), Vector2(1, 1), Vector2(-4, -52))

	var eaves := Sprite2D.new()
	eaves.name = "PorchRoof"
	eaves.texture = _porch_eaves_texture()
	eaves.texture_filter = CanvasItem.TEXTURE_FILTER_NEAREST
	eaves.centered = false
	eaves.offset = Vector2(-PORCH_HALF_W - 10.0, -108.0)
	eaves.position = feet + Vector2(0, 22)
	eaves.z_index = 2
	root.add_child(eaves)


static func _add_porch_greens(root: Node2D, feet: Vector2) -> void:
	# 柱外灌木、南沿湿边的叶子。不摆到干处坐席上。
	_add_plant(root, "PorchBushL", BUSH_B, feet + Vector2(-148, 8), 2.3)
	_add_plant(root, "PorchBushR", BUSH_A, feet + Vector2(148, 14), 2.2)


static func _add_field_dress(root: Node2D) -> void:
	# 右边三垄外围：少量花、草堆，不挡围栏和田埂。
	_add_plant(root, "FieldPot", PLANT_POT_B, Vector2(1456, 676), 2.1)
	_add_plant(root, "FieldBushW", BUSH_A, Vector2(1448, 780), 2.1)
	_add_sprite(root, "FieldBarrel", BARREL_TEX, Vector2(1648, 720), Vector2(2.0, 2.0), Vector2(BARREL_TEX.get_width() * -0.5, -BARREL_TEX.get_height() + 4))
	_add_sprite(root, "FieldHay", _hay_texture(), Vector2(1464, 704), Vector2(1, 1), Vector2(-18, -16))


static func _add_path_greens(root: Node2D) -> void:
	# 路弯处的树和灌木，填开后的空地，不挡路心。
	_add_plant(root, "PathTreeA", TREE_TEX, Vector2(944, 496), 2.7)
	_add_plant(root, "PathBushA", BUSH_A, Vector2(900, 568), 2.2)
	_add_plant(root, "PathBushB", BUSH_B, Vector2(1288, 620), 2.15)
	_add_sprite(root, "PathRockA", ROCK_B, Vector2(1104, 480), Vector2(1.8, 1.8), Vector2(ROCK_B.get_width() * -0.5, -ROCK_B.get_height() + 4))


static func _add_yard_fill(root: Node2D) -> void:
	var fill := Node2D.new()
	fill.name = "YardFill"
	root.add_child(fill)
	# 只填院子里屋、廊下、商店之间的空地，南面交给原图树林收边。
	_add_plant(fill, "FillTreeN", TREE_TEX, Vector2(1128, 432), 2.5)
	_add_plant(fill, "FillTreeE", TREE_C, Vector2(1288, 560), 2.5)
	_add_plant(fill, "FillFlowerA", FLOWER_A, Vector2(980, 600), 2.2)
	_add_plant(fill, "FillFlowerB", FLOWER_B, Vector2(1140, 600), 2.2)
	_add_plant(fill, "FillFlowerD", FLOWER_A, Vector2(1264, 580), 2.15)
	_add_plant(fill, "FillFlowerE", FLOWER_B, Vector2(780, 500), 2.1)
	_add_plant(fill, "MeadowTreeW", TREE_B, Vector2(900, 780), 2.6)
	_add_plant(fill, "MeadowTreeE", TREE_TEX, Vector2(1208, 812), 2.5)
	_add_plant(fill, "MeadowBush", BUSH_A, Vector2(1080, 744), 2.2)
	_add_plant(fill, "MeadowFlower", FLOWER_A, Vector2(1024, 708), 2.15)
	_add_sprite(fill, "HayB", _hay_texture(), Vector2(760, 620), Vector2(1, 1), Vector2(-18, -16))
	_add_sprite(fill, "HayC", _hay_texture(), Vector2(1088, 680), Vector2(0.95, 0.95), Vector2(-18, -16))
	_add_sprite(fill, "PuddleC", _mud_texture(), Vector2(1336, 576), Vector2(1, 1), Vector2(-16, -8))


static func _add_yard_edge_props(root: Node2D) -> void:
	var edge := Node2D.new()
	edge.name = "YardEdge"
	edge.z_index = 0
	root.add_child(edge)
	var spots: Array[Dictionary] = [
		{"tex": ROCK_A, "pos": Vector2(612, 528), "scale": 2.0},
		{"tex": ROCK_B, "pos": Vector2(668, 548), "scale": 1.8},
		{"tex": ROCK_C, "pos": Vector2(780, 700), "scale": 1.8},
		{"tex": ROCK_A, "pos": Vector2(1420, 452), "scale": 1.8},
	]
	for i in spots.size():
		var item: Dictionary = spots[i]
		var tex: Texture2D = item["tex"]
		_add_sprite(
			edge,
			"EdgeRock_%d" % i,
			tex,
			item["pos"],
			Vector2(item["scale"], item["scale"]),
			Vector2(tex.get_width() * -0.5, -tex.get_height() + 4)
		)


static func _add_hollow_tree(root: Node2D, feet: Vector2) -> void:
	_add_sprite(
		root,
		"HollowTree",
		TREE_HOLLOW_TEX,
		feet + Vector2(0, 8),
		Vector2(3.3, 3.3),
		Vector2(TREE_HOLLOW_TEX.get_width() * -0.5, -TREE_HOLLOW_TEX.get_height() + 4)
	)
	_add_sprite(root, "HollowLamp", LAMP_TEX, feet + Vector2(28, 4), Vector2(2.0, 2.0), Vector2(-6, -28))
	_add_sprite(root, "HollowBook", BOOK_TEX, feet + Vector2(18, 12), Vector2(2.2, 2.2), Vector2(-6, -12))


static func _add_plant(root: Node2D, node_name: String, texture: Texture2D, pos: Vector2, plant_scale: float) -> void:
	_add_sprite(
		root,
		node_name,
		texture,
		pos,
		Vector2(plant_scale, plant_scale),
		Vector2(texture.get_width() * -0.5, -texture.get_height() + 4)
	)


static func _add_sprite(
	root: Node2D,
	node_name: String,
	texture: Texture2D,
	pos: Vector2,
	sprite_scale: Vector2,
	offset: Vector2
) -> Sprite2D:
	var sprite := Sprite2D.new()
	sprite.name = node_name
	sprite.texture = texture
	sprite.texture_filter = CanvasItem.TEXTURE_FILTER_NEAREST
	sprite.centered = false
	sprite.offset = offset
	sprite.scale = sprite_scale
	sprite.position = pos
	root.add_child(sprite)
	return sprite


static func _porch_deck_texture() -> Texture2D:
	var w := int(PORCH_HALF_W * 2.0)
	var h := int(PORCH_DECK_H)
	var img := Image.create(w, h, false, Image.FORMAT_RGBA8)
	img.fill(Color(0, 0, 0, 0))
	var dry := Color(0.52, 0.38, 0.22, 0.94)
	var dry_gap := Color(0.34, 0.22, 0.12, 0.9)
	var wet := Color(0.32, 0.26, 0.18, 0.92)
	var wet_gap := Color(0.22, 0.18, 0.12, 0.88)
	var puddle := Color(0.28, 0.36, 0.38, 0.35)
	var wet_from := int(h * 0.68)
	for y in range(h):
		var is_wet := y >= wet_from
		for x in range(w):
			var color := wet if is_wet else dry
			if y % 6 == 5:
				color = wet_gap if is_wet else dry_gap
			elif x == 0 or x == w - 1 or y == 0 or y == h - 1:
				color = Color(0.2, 0.14, 0.08, 0.7)
			elif (x + y * 2) % 19 == 0:
				color = color.lightened(0.08)
			if is_wet and ((x - 70) * (x - 70) + (y - h + 8) * (y - h + 8) < 40 or (x - w + 70) * (x - w + 70) + (y - h + 6) * (y - h + 6) < 24):
				color = puddle
			img.set_pixel(x, y, color)
	return ImageTexture.create_from_image(img)


static func _porch_eaves_texture() -> Texture2D:
	var w := int(PORCH_HALF_W * 2.0) + 20
	var img := Image.create(w, 40, false, Image.FORMAT_RGBA8)
	img.fill(Color(0, 0, 0, 0))
	var tile := Color(0.28, 0.18, 0.14, 0.96)
	var lip := Color(0.42, 0.28, 0.16, 0.98)
	var shadow := Color(0.12, 0.08, 0.06, 0.55)
	for y in range(40):
		for x in range(w):
			var color := tile
			if y >= 30:
				color = lip
			elif y <= 3:
				color = shadow
			elif x % 12 == 0:
				color = Color(0.22, 0.14, 0.10, 0.96)
			elif y == 29:
				color = Color(0.18, 0.12, 0.08, 0.9)
			img.set_pixel(x, y, color)
	return ImageTexture.create_from_image(img)


static func _porch_pillar_texture() -> Texture2D:
	var img := Image.create(8, 56, false, Image.FORMAT_RGBA8)
	var wood := Color(0.36, 0.24, 0.14, 1.0)
	var edge := Color(0.2, 0.12, 0.08, 1.0)
	img.fill(wood)
	for y in range(56):
		img.set_pixel(0, y, edge)
		img.set_pixel(7, y, edge)
	return ImageTexture.create_from_image(img)


static func _porch_rail_texture() -> Texture2D:
	var w := int(PORCH_HALF_W * 2.0) - 16
	var img := Image.create(w, 18, false, Image.FORMAT_RGBA8)
	img.fill(Color(0, 0, 0, 0))
	var wood := Color(0.38, 0.24, 0.14, 0.94)
	var edge := Color(0.18, 0.10, 0.06, 0.95)
	for y in range(18):
		for x in range(w):
			if y <= 2 or y >= 15 or x <= 1 or x >= w - 2:
				img.set_pixel(x, y, edge)
			elif y == 8 or x % 22 == 0:
				img.set_pixel(x, y, edge)
			else:
				img.set_pixel(x, y, wood)
	return ImageTexture.create_from_image(img)


static func _hay_texture() -> Texture2D:
	var img := Image.create(36, 20, false, Image.FORMAT_RGBA8)
	img.fill(Color(0, 0, 0, 0))
	var straw := Color(0.72, 0.58, 0.22, 0.96)
	var dark := Color(0.50, 0.36, 0.12, 0.94)
	var wet := Color(0.42, 0.32, 0.10, 0.9)
	for y in range(20):
		for x in range(36):
			var dx := (x - 18.0) / 18.0
			var dy := (y - 12.0) / 10.0
			if dx * dx + dy * dy > 1.0:
				continue
			var color := straw
			if y % 3 == 0:
				color = dark
			elif (x + y * 3) % 7 == 0:
				color = wet
			img.set_pixel(x, y, color)
	return ImageTexture.create_from_image(img)


static func _mud_texture() -> Texture2D:
	var img := Image.create(32, 16, false, Image.FORMAT_RGBA8)
	img.fill(Color(0, 0, 0, 0))
	var mud := Color(0.28, 0.18, 0.10, 0.82)
	var puddle := Color(0.22, 0.28, 0.30, 0.55)
	for y in range(16):
		for x in range(32):
			var dx := (x - 16.0) / 16.0
			var dy := (y - 8.0) / 8.0
			if dx * dx + dy * dy > 1.0:
				continue
			var color := mud
			if dx * dx + dy * dy < 0.28:
				color = puddle
			img.set_pixel(x, y, color)
	return ImageTexture.create_from_image(img)


static func _shop_pad_texture() -> Texture2D:
	var img := Image.create(120, 36, false, Image.FORMAT_RGBA8)
	img.fill(Color(0, 0, 0, 0))
	var dirt := Color(0.42, 0.32, 0.18, 0.78)
	var grain := Color(0.50, 0.38, 0.22, 0.70)
	for y in range(36):
		for x in range(120):
			var dx := (x - 60.0) / 60.0
			var dy := (y - 18.0) / 18.0
			if dx * dx + dy * dy > 1.0:
				continue
			var color := dirt if ((x + y * 5) % 11 != 0) else grain
			img.set_pixel(x, y, color)
	return ImageTexture.create_from_image(img)


static func _shop_sign_texture() -> Texture2D:
	var img := Image.create(92, 22, false, Image.FORMAT_RGBA8)
	var board := Color(0.55, 0.18, 0.14, 0.96)
	var edge := Color(0.28, 0.10, 0.08, 1.0)
	img.fill(board)
	for x in range(92):
		img.set_pixel(x, 0, edge)
		img.set_pixel(x, 21, edge)
	for y in range(22):
		img.set_pixel(0, y, edge)
		img.set_pixel(91, y, edge)
	return ImageTexture.create_from_image(img)
