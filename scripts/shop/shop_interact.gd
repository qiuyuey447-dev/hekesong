extends Area2D

const INTERACT_RANGE := 110.0


func _ready() -> void:
	add_to_group("interactable")
	add_to_group("shop_interact")
	_build_collision()
	FarmSetdress.build_shop_stall(self)
	InteractHover.attach(self, Vector2(108, 96), Vector2(0, -36), INTERACT_RANGE)


func activate() -> void:
	if not _is_player_near():
		get_tree().call_group("main_ui", "on_need_closer")
		return
	get_tree().call_group("main_ui", "on_shop_clicked")


func get_interact_center() -> Vector2:
	return global_position + Vector2(0, -28)


func _build_collision() -> void:
	if get_node_or_null("Collision") != null:
		return
	var shape_node := CollisionShape2D.new()
	shape_node.name = "Collision"
	var circle := CircleShape2D.new()
	circle.radius = 56.0
	shape_node.shape = circle
	shape_node.position = Vector2(0, -20)
	add_child(shape_node)


func _is_player_near() -> bool:
	var player := get_tree().get_first_node_in_group("player") as Node2D
	if player == null:
		return true
	return player.global_position.distance_to(get_interact_center()) <= INTERACT_RANGE
