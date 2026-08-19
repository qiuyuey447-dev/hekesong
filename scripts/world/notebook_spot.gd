extends Area2D
class_name NotebookSpot

enum Kind { COMPANION, PLAYER }

const INTERACT_RANGE := 72.0
const BOOK_FRAME := Vector2(46, 32)
const BOOK_OFFSET := Vector2(0, -14)

@export var kind: Kind = Kind.COMPANION

var _hover: InteractHover
var _hint: Label


func _ready() -> void:
	add_to_group("interactable")
	add_to_group("notebook_interact")
	_build_collision()
	_build_hint()
	_hover = InteractHover.attach(
		self,
		BOOK_FRAME,
		BOOK_OFFSET,
		INTERACT_RANGE,
		0.03,
		1.5,
		false
	)
	set_process(true)


func _process(_delta: float) -> void:
	var near := _is_player_near()
	if _hint != null:
		_hint.visible = near
		if near:
			_hint.text = "这是小狸的本子" if kind == Kind.COMPANION else "这是你的本子"


func activate() -> void:
	if not _is_player_near():
		get_tree().call_group("main_ui", "on_need_closer")
		return
	if kind == Kind.COMPANION:
		get_tree().call_group("main_ui", "on_companion_notebook_clicked")
	else:
		get_tree().call_group("main_ui", "on_player_notebook_clicked")


func get_interact_center() -> Vector2:
	return global_position + BOOK_OFFSET


func _build_collision() -> void:
	var shape_node := CollisionShape2D.new()
	var rect := RectangleShape2D.new()
	rect.size = Vector2(52, 40)
	shape_node.shape = rect
	shape_node.position = BOOK_OFFSET
	add_child(shape_node)


func _build_hint() -> void:
	_hint = Label.new()
	_hint.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	_hint.add_theme_color_override("font_outline_color", Color(0.1, 0.08, 0.06))
	_hint.add_theme_constant_override("outline_size", 4)
	_hint.add_theme_font_size_override("font_size", 15)
	_hint.add_theme_color_override("font_color", Color(1.0, 0.96, 0.78))
	_hint.position = Vector2(-72, -52)
	_hint.size = Vector2(144, 22)
	_hint.visible = false
	add_child(_hint)


func _is_player_near() -> bool:
	var player := get_tree().get_first_node_in_group("player") as Node2D
	if player == null:
		return true
	return player.global_position.distance_to(get_interact_center()) <= INTERACT_RANGE
