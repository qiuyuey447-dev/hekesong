class_name InteractHighlight
extends Node2D

enum Style { READY, TOO_FAR, WATER, HARVEST, PLANT }
enum Shape { RECT, ELLIPSE }

const COLOR_READY := Color(1.0, 0.96, 0.72, 0.9)
const COLOR_FAR := Color(0.55, 0.78, 1.0, 0.85)
const COLOR_WATER := Color(0.42, 0.74, 1.0, 0.92)
const COLOR_HARVEST := Color(1.0, 0.62, 0.18, 0.92)
const COLOR_PLANT := Color(0.52, 0.88, 0.48, 0.88)

@export var frame_size := Vector2(40, 40)
@export var frame_offset := Vector2.ZERO
@export var line_width := 1.5
@export var pulse_amount := 0.03
@export var shape := Shape.RECT

var _active := false
var _style := Style.READY
var _pulse_t := 0.0


func _ready() -> void:
	z_index = 50
	visible = false
	set_process(true)


func show_highlight(style: Style = Style.READY) -> void:
	_active = true
	_style = style
	visible = true
	queue_redraw()


func hide_highlight() -> void:
	_active = false
	visible = false
	queue_redraw()


func _process(delta: float) -> void:
	if not _active:
		return
	_pulse_t += delta * 4.5
	queue_redraw()


func _stroke_color() -> Color:
	match _style:
		Style.WATER:
			return COLOR_WATER
		Style.HARVEST:
			return COLOR_HARVEST
		Style.PLANT:
			return COLOR_PLANT
		Style.TOO_FAR:
			return COLOR_FAR
		_:
			return COLOR_READY


func _draw() -> void:
	if not _active:
		return

	var pulse := 1.0 + sin(_pulse_t) * pulse_amount
	var frame_sz := frame_size * pulse
	var half := frame_sz * 0.5
	var rect := Rect2(frame_offset - half, frame_sz)
	var color := _stroke_color()
	var width := line_width if _style != Style.TOO_FAR else maxf(line_width - 0.25, 1.0)

	match shape:
		Shape.ELLIPSE:
			_draw_ellipse_stroke(rect, color, width)
		_:
			draw_rect(rect, color, false, width)


func _draw_ellipse_stroke(rect: Rect2, color: Color, width: float) -> void:
	var center := rect.get_center()
	var rx := rect.size.x * 0.5
	var ry := rect.size.y * 0.5
	if rx <= 0.5 or ry <= 0.5:
		return
	var steps := 48
	var points := PackedVector2Array()
	points.resize(steps)
	for i in steps:
		var t := float(i) / float(steps) * TAU
		points[i] = center + Vector2(cos(t) * rx, sin(t) * ry)
	draw_polyline(points, color, width, true)
