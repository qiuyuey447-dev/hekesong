extends Node
## 一次性工具：把 FarmSetdress 运行时生成的院子固化进 scenes/farm_map.tscn，
## 之后 farm_world / title_screen 不再调 apply()，院子改成在编辑器里手改。
##
## 跑两趟：
##   第一趟 —— 程序化贴图（廊下甲板/屋檐/廊柱/栏杆、草堆、泥洼）存成 PNG 后退出。
##             之后需要让编辑器 rescan 导入这些 PNG。
##   第二趟 —— PNG 已就位，组装院子、把生成的 Sprite 换成 PNG 贴图、打包存盘。

const FARM_MAP_PATH := "res://scenes/farm_map.tscn"
const GEN_DIR := "res://Props/Generated/"

const GEN_NAMES: Array[String] = [
	"porch_deck", "porch_eaves", "porch_pillar", "porch_rail", "hay", "mud",
]

# 生成出来的 Sprite2D 名字 -> 该用哪张烘好的 PNG
const TEXTURE_BY_NODE := {
	"PorchDeck": "porch_deck",
	"PorchRoof": "porch_eaves",
	"PorchPillarL": "porch_pillar",
	"PorchPillarM": "porch_pillar",
	"PorchPillarR": "porch_pillar",
	"PorchRail": "porch_rail",
	"FieldHay": "hay",
	"HayB": "hay",
	"HayC": "hay",
	"PuddleC": "mud",
}


func _ready() -> void:
	var missing := _missing_textures()
	if not missing.is_empty():
		_save_textures()
		print("[yard_bake] TEXTURES_SAVED %s" % str(missing))
		print("[yard_bake] 下一步：rescan_filesystem 导入 PNG，然后重跑本场景")
		return
	await _bake()


func _missing_textures() -> Array[String]:
	var missing: Array[String] = []
	for name in GEN_NAMES:
		if not ResourceLoader.exists(_png_path(name)):
			missing.append(name)
	return missing


func _png_path(name: String) -> String:
	return GEN_DIR + name + ".png"


func _generated_texture(name: String) -> Texture2D:
	match name:
		"porch_deck":
			return FarmSetdress._porch_deck_texture()
		"porch_eaves":
			return FarmSetdress._porch_eaves_texture()
		"porch_pillar":
			return FarmSetdress._porch_pillar_texture()
		"porch_rail":
			return FarmSetdress._porch_rail_texture()
		"hay":
			return FarmSetdress._hay_texture()
		"mud":
			return FarmSetdress._mud_texture()
	return null


func _save_textures() -> void:
	DirAccess.make_dir_recursive_absolute(ProjectSettings.globalize_path(GEN_DIR))
	for name in GEN_NAMES:
		var tex := _generated_texture(name)
		if tex == null:
			push_error("[yard_bake] 没有生成器: %s" % name)
			continue
		var image := tex.get_image()
		if image == null:
			push_error("[yard_bake] 贴图取不到 Image: %s" % name)
			continue
		var abs_path := ProjectSettings.globalize_path(_png_path(name))
		var err := image.save_png(abs_path)
		if err != OK:
			push_error("[yard_bake] 存 PNG 失败 %s: %d" % [name, err])
		else:
			print("[yard_bake] saved %s (%dx%d)" % [name, image.get_width(), image.get_height()])


func _bake() -> void:
	var packed: PackedScene = load(FARM_MAP_PATH)
	if packed == null:
		push_error("[yard_bake] 读不到 %s" % FARM_MAP_PATH)
		return
	var root := packed.instantiate() as Node2D
	add_child(root)

	FarmSetdress.sync_markers(root)
	FarmSetdress._prepare_ground_layers(root)
	FarmSetdress._punch_clearing(root)
	var actors := FarmSetdress.ensure_actors(root)
	FarmSetdress._clear_old_setdress(root, actors)
	FarmSetdress._paint_yard_floors(root)

	var home := FarmSetdress.marker_position(root, "人", FarmSetdress.POS_HOME)
	var porch := FarmSetdress.marker_position(root, "廊下", FarmSetdress.POS_PORCH)
	var hollow := FarmSetdress.marker_position(root, "树洞", FarmSetdress.POS_HOLLOW)
	FarmSetdress._add_house(actors, home)
	FarmSetdress._add_house_greens(actors, home)
	FarmSetdress._add_porch(actors, porch)
	FarmSetdress._add_porch_greens(actors, porch)
	FarmSetdress._add_field_dress(actors)
	FarmSetdress._add_path_greens(actors)
	FarmSetdress._add_yard_fill(actors)
	FarmSetdress._add_yard_edge_props(actors)
	FarmSetdress._add_hollow_tree(actors, hollow)
	# 商店台子不烘：运行时 farm_world 会 spawn Shop，那时 apply() 本来就不建 ShopStall。

	# _clear_old_setdress / 地面细节 重建都是 queue_free，等它们真正消失再打包。
	await get_tree().process_frame
	await get_tree().process_frame

	var swapped := _swap_generated_textures(root)
	var owned := _own_all(root, root)

	var out := PackedScene.new()
	var pack_err := out.pack(root)
	if pack_err != OK:
		push_error("[yard_bake] pack 失败: %d" % pack_err)
		return
	var save_err := ResourceSaver.save(out, FARM_MAP_PATH)
	if save_err != OK:
		push_error("[yard_bake] 存场景失败: %d" % save_err)
		return

	print("[yard_bake] BAKED ok: nodes=%d texture_swaps=%d -> %s" % [owned, swapped, FARM_MAP_PATH])
	print("[yard_bake] Entities 子节点=%d" % actors.get_child_count())


func _swap_generated_textures(node: Node) -> int:
	var count := 0
	var sprite := node as Sprite2D
	if sprite != null and TEXTURE_BY_NODE.has(sprite.name):
		var tex: Texture2D = load(_png_path(TEXTURE_BY_NODE[sprite.name]))
		if tex == null:
			push_error("[yard_bake] 载入不了烘好的贴图: %s" % sprite.name)
		else:
			sprite.texture = tex
			count += 1
	for child in node.get_children():
		count += _swap_generated_textures(child)
	return count


func _own_all(node: Node, owner_node: Node) -> int:
	var count := 0
	for child in node.get_children():
		child.owner = owner_node
		count += 1
		count += _own_all(child, owner_node)
	return count
