extends Node2D
## 看图工具：把 farm_map.tscn 整张摊在日光下，拉远到能一眼看全院子。
## 配合 MCP take_screenshot 用来自查布局，不参与游戏。
## 商店台子跟标题界面一样补上（游戏里那位置由 Shop 实体接管）。

const FARM_MAP_PATH := "res://scenes/farm_map.tscn"
# 改这两个常量换镜头。常用预设：
#   整院全景  Vector2(960, 560)  · 0.9
#   旧田/田近景 Vector2(1200, 800) · 1.5   （接近游戏内 1.65，用来判断细节读不读得出来）
#   游戏内视野 Vector2(1000, 640)  · 1.65  （玩家真正看到的画面，验收看这个）
#   查像素对齐 Vector2(848, 370)   · 5.0   （拉到这个倍数才看得出倍率是不是整数）
const MAP_CENTER := Vector2(954, 544)
const MAP_ZOOM := 0.9


func _ready() -> void:
	var packed: PackedScene = load(FARM_MAP_PATH)
	var farm_map := packed.instantiate() as Node2D
	add_child(farm_map)

	var stall := Node2D.new()
	stall.name = "ShopStall"
	stall.position = FarmSetdress.marker_position(farm_map, "商店", FarmSetdress.POS_SHOP)
	FarmSetdress.ensure_actors(farm_map).add_child(stall)
	FarmSetdress.build_shop_stall(stall)

	var camera := Camera2D.new()
	camera.position = MAP_CENTER
	camera.zoom = Vector2(MAP_ZOOM, MAP_ZOOM)
	add_child(camera)
	camera.make_current()
