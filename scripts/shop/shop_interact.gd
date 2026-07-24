extends Area2D

const CRATE_TEXTURE: Texture2D = preload("res://Props/Crates/Sprites/crate_02.png")


func _ready() -> void:
	add_to_group("interactable")
	add_to_group("shop_interact")
	_build_visual()
	InteractHover.attach(self, Vector2(64, 52), Vector2(0, -14), 72.0)


func activate() -> void:
	if not _is_player_near():
		get_tree().call_group("main_ui", "on_need_closer")
		return
	get_tree().call_group("main_ui", "on_shop_clicked")


func _build_visual() -> void:
	var shadow := Sprite2D.new()
	var shadow_img := Image.create(40, 10, false, Image.FORMAT_RGBA8)
	shadow_img.fill(Color(0, 0, 0, 0))
	for y in range(10):
		for x in range(40):
			var dx := (x - 20.0) / 20.0
			var dy := (y - 5.0) / 5.0
			if dx * dx + dy * dy <= 1.0:
				shadow_img.set_pixel(x, y, Color(0, 0, 0, 0.2))
	shadow.texture = ImageTexture.create_from_image(shadow_img)
	shadow.texture_filter = CanvasItem.TEXTURE_FILTER_NEAREST
	shadow.centered = true
	shadow.position = Vector2(0, 4)
	shadow.z_index = -1
	add_child(shadow)

	var crate := Sprite2D.new()
	crate.texture = SpriteSheet.grid_frame(CRATE_TEXTURE, Vector2i(16, 16), 0, 0)
	crate.texture_filter = CanvasItem.TEXTURE_FILTER_NEAREST
	crate.centered = false
	crate.offset = Vector2(-8, -22)
	add_child(crate)

	var sign := Sprite2D.new()
	sign.texture = ShopCatalog.get_item_icon(ShopCatalog.SHOP_ITEMS[1])
	sign.texture_filter = CanvasItem.TEXTURE_FILTER_NEAREST
	sign.centered = false
	sign.offset = Vector2(-8, -38)
	sign.scale = Vector2(1.4, 1.4)
	add_child(sign)

	var label := Label.new()
	label.text = "商店"
	label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	label.add_theme_color_override("font_outline_color", Color(0.1, 0.1, 0.1))
	label.add_theme_constant_override("outline_size", 3)
	label.add_theme_font_size_override("font_size", 14)
	label.position = Vector2(-28, -58)
	label.size = Vector2(56, 18)
	add_child(label)


func _is_player_near() -> bool:
	var player := get_tree().get_first_node_in_group("player") as Node2D
	if player == null:
		return true
	return player.global_position.distance_to(global_position) <= 72.0
