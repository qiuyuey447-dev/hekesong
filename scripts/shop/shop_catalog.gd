class_name ShopCatalog
extends RefCounted

const FARM_ICONS: Texture2D = preload("res://Props/Farm/farm_icons_1_16x16.png")
const ICON_SIZE := Vector2i(16, 16)

const SHOP_ITEMS: Array[Dictionary] = [
	{
		"id": "turnip_seed",
		"name": "萝卜种子",
		"category": "seed",
		"buy_price": 8,
		"inventory_key": "turnip_seed",
		"icon_col": 8,
		"icon_row": 0,
		"desc": "种在农田里，每天浇水成长。",
	},
	{
		"id": "apple",
		"name": "红苹果",
		"category": "treat",
		"buy_price": 15,
		"inventory_key": "apple",
		"icon_col": 2,
		"icon_row": 0,
		"affection": 5,
		"mood": 4,
		"bond": 2,
		"desc": "小狸最爱的脆甜苹果。",
	},
	{
		"id": "berry",
		"name": "野蓝莓",
		"category": "treat",
		"buy_price": 10,
		"inventory_key": "berry",
		"icon_col": 1,
		"icon_row": 0,
		"affection": 3,
		"mood": 3,
		"bond": 1,
		"desc": "酸甜浆果，小狸会开心。",
	},
	{
		"id": "carrot",
		"name": "胡萝卜",
		"category": "treat",
		"buy_price": 12,
		"inventory_key": "carrot",
		"icon_col": 4,
		"icon_row": 0,
		"affection": 4,
		"mood": 2,
		"bond": 2,
		"desc": "清脆爽口，适合当零食。",
	},
	{
		"id": "pumpkin_snack",
		"name": "小南瓜",
		"category": "treat",
		"buy_price": 18,
		"inventory_key": "pumpkin_snack",
		"icon_col": 0,
		"icon_row": 2,
		"affection": 6,
		"mood": 5,
		"bond": 3,
		"desc": "软糯香甜，小狸超满足。",
	},
]

const SELL_ITEMS: Array[Dictionary] = [
	{
		"id": "turnip",
		"name": "萝卜",
		"sell_price": 12,
		"inventory_key": "turnip",
		"icon_col": 9,
		"icon_row": 0,
		"desc": "自己种的萝卜，商店收购。",
	},
]


static func get_shop_item(item_id: String) -> Dictionary:
	for item in SHOP_ITEMS:
		if str(item.get("id", "")) == item_id:
			return item
	return {}


static func get_sell_item(item_id: String) -> Dictionary:
	for item in SELL_ITEMS:
		if str(item.get("id", "")) == item_id:
			return item
	return {}


static func get_treat_item(item_id: String) -> Dictionary:
	var item := get_shop_item(item_id)
	if item.is_empty() or str(item.get("category", "")) != "treat":
		return {}
	return item


static func get_item_icon(item: Dictionary) -> Texture2D:
	return SpriteSheet.grid_frame(
		FARM_ICONS,
		ICON_SIZE,
		int(item.get("icon_col", 0)),
		int(item.get("icon_row", 0))
	)


static func get_treat_items() -> Array[Dictionary]:
	var treats: Array[Dictionary] = []
	for item in SHOP_ITEMS:
		if str(item.get("category", "")) == "treat":
			treats.append(item)
	return treats
