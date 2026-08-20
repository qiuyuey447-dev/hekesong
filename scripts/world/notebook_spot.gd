extends Area2D
class_name NotebookSpot

enum Kind { COMPANION, PLAYER }

const INTERACT_RANGE := 72.0
const BOOK_FRAME := Vector2(46, 32)
const BOOK_OFFSET := Vector2(0, -14)
const HINT_FONT_SIZE := 15

@export var kind: Kind = Kind.COMPANION

var _hover: InteractHover
var _hint_visible: bool = false
var _near_check_age := 0.0
const NEAR_CHECK_SEC := 0.08


func _ready() -> void:
	add_to_group("interactable")
	add_to_group("notebook_interact")
	_build_collision()
	_hover = InteractHover.attach(
		self,
		BOOK_FRAME,
		BOOK_OFFSET,
		INTERACT_RANGE,
		0.03,
		1.5,
		true
	)
	set_process(true)
	z_as_relative = false
	z_index = 8


func _process(delta: float) -> void:
	_near_check_age += delta
	if _near_check_age < NEAR_CHECK_SEC:
		return
	_near_check_age = 0.0
	var show_hint := _is_player_near() and not _is_story_blocking()
	if _hover != null:
		_hover.set_focused(show_hint)
	if show_hint != _hint_visible:
		_hint_visible = show_hint
		queue_redraw()


func _draw() -> void:
	if not _hint_visible:
		return
	var text := "这是小狸的本子" if kind == Kind.COMPANION else "这是你的本子"
	var font := ThemeDB.fallback_font
	var size := font.get_string_size(text, HORIZONTAL_ALIGNMENT_LEFT, -1, HINT_FONT_SIZE)
	var pos := Vector2(-size.x * 0.5, BOOK_OFFSET.y - 28.0)
	var outline := Color(0.1, 0.08, 0.06, 1.0)
	for d in [
		Vector2(-1, -1), Vector2(1, -1), Vector2(-1, 1), Vector2(1, 1),
		Vector2(0, -2), Vector2(0, 2), Vector2(-2, 0), Vector2(2, 0),
	]:
		draw_string(font, pos + d, text, HORIZONTAL_ALIGNMENT_LEFT, -1, HINT_FONT_SIZE, outline)
	draw_string(font, pos, text, HORIZONTAL_ALIGNMENT_LEFT, -1, HINT_FONT_SIZE, Color(1.0, 0.96, 0.78))


func activate() -> void:
	if _is_story_blocking():
		return
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


func _is_story_blocking() -> bool:
	if GameState.should_show_awakening() or GameState.is_story_complete():
		return true
	for node in get_tree().get_nodes_in_group("main_ui"):
		if node.has_method("is_story_overlay_open") and bool(node.call("is_story_overlay_open")):
			return true
	return false


func _is_player_near() -> bool:
	var player := get_tree().get_first_node_in_group("player") as Node2D
	if player == null:
		return false
	return player.global_position.distance_to(get_interact_center()) <= INTERACT_RANGE
