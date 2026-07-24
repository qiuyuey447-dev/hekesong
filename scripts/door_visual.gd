extends Area2D

const DOOR_TEXTURE: Texture2D = preload("res://Props/Door/door_2_16x16.png")

var _door: Sprite2D


func _ready() -> void:
	add_to_group("interactable")
	add_to_group("door_interact")
	_build_visual()
	InteractHover.attach(self, Vector2(30, 34), Vector2(0, -12), 48.0)


func activate() -> void:
	if not _is_player_near():
		get_tree().call_group("main_ui", "on_need_closer")
		return
	get_tree().call_group("main_ui", "on_door_clicked")


func _build_visual() -> void:
	_door = Sprite2D.new()
	_door.texture = SpriteSheet.frame_from_sheet(DOOR_TEXTURE, Vector2i(16, 16), 0)
	_door.texture_filter = CanvasItem.TEXTURE_FILTER_NEAREST
	_door.centered = false
	_door.offset = Vector2(-8, -24)
	add_child(_door)

	var label := Label.new()
	label.text = "出门"
	label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	label.add_theme_color_override("font_outline_color", Color(0.1, 0.1, 0.1))
	label.add_theme_constant_override("outline_size", 3)
	label.add_theme_font_size_override("font_size", 12)
	label.position = Vector2(-24, -48)
	label.size = Vector2(48, 16)
	add_child(label)


func _is_player_near() -> bool:
	var player := get_tree().get_first_node_in_group("player") as Node2D
	if player == null:
		return true
	return player.global_position.distance_to(global_position) <= 48.0
