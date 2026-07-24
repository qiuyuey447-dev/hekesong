class_name InteractHover
extends Node

@export var frame_size := Vector2(40, 40)
@export var frame_offset := Vector2.ZERO
@export var player_near_distance := 48.0
@export var glow_grow := 4.0
@export var pulse_amount := 0.06
@export var line_width := 3.5

var _area: Area2D
var _highlight: InteractHighlight
var _was_near := false
var _manual_focus := false


static func attach(
	area: Area2D,
	size: Vector2,
	offset: Vector2 = Vector2.ZERO,
	near_distance: float = 48.0,
	hover_glow_grow: float = 4.0,
	hover_pulse_amount: float = 0.06,
	hover_line_width: float = 3.5,
	manual_focus: bool = false
) -> InteractHover:
	var hover := InteractHover.new()
	hover.frame_size = size
	hover.frame_offset = offset
	hover.player_near_distance = near_distance
	hover.glow_grow = hover_glow_grow
	hover.pulse_amount = hover_pulse_amount
	hover.line_width = hover_line_width
	hover._manual_focus = manual_focus
	area.add_child(hover)
	hover._bind(area)
	return hover


func set_focused(focused: bool, style: InteractHighlight.Style = InteractHighlight.Style.READY) -> void:
	if _highlight == null:
		return
	if focused:
		_highlight.show_highlight(style)
	else:
		_highlight.hide_highlight()


func _bind(area: Area2D) -> void:
	_area = area
	_highlight = InteractHighlight.new()
	_highlight.frame_size = frame_size
	_highlight.frame_offset = frame_offset
	_highlight.glow_grow = glow_grow
	_highlight.pulse_amount = pulse_amount
	_highlight.line_width = line_width
	_area.add_child(_highlight)
	set_process(not _manual_focus)


func _process(_delta: float) -> void:
	if _manual_focus:
		return
	var near := _is_player_near()
	if near:
		_highlight.show_highlight(InteractHighlight.Style.READY)
	elif _was_near:
		_highlight.hide_highlight()
	_was_near = near


func _is_player_near() -> bool:
	var player := get_tree().get_first_node_in_group("player") as Node2D
	if player == null:
		return false
	return player.global_position.distance_to(_area.global_position) <= player_near_distance
