class_name InteractHighlight
extends Node2D

enum Style { READY, TOO_FAR, WATER, HARVEST, PLANT }

const COLOR_READY := Color(1.0, 0.88, 0.12, 1.0)
const COLOR_READY_GLOW := Color(1.0, 0.95, 0.35, 0.55)
const COLOR_FAR := Color(0.55, 0.78, 1.0, 0.95)
const COLOR_FAR_GLOW := Color(0.7, 0.88, 1.0, 0.45)
const COLOR_WATER := Color(0.42, 0.74, 1.0, 0.98)
const COLOR_WATER_GLOW := Color(0.55, 0.82, 1.0, 0.42)
const COLOR_HARVEST := Color(1.0, 0.62, 0.18, 0.98)
const COLOR_HARVEST_GLOW := Color(1.0, 0.78, 0.35, 0.45)
const COLOR_PLANT := Color(0.52, 0.88, 0.48, 0.92)
const COLOR_PLANT_GLOW := Color(0.62, 0.95, 0.58, 0.38)

@export var frame_size := Vector2(40, 40)
@export var frame_offset := Vector2.ZERO
@export var line_width := 3.5
@export var glow_grow := 4.0
@export var pulse_amount := 0.06

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
	_pulse_t += delta * 5.5
	queue_redraw()


func _style_colors() -> Array[Color]:
	match _style:
		Style.WATER:
			return [COLOR_WATER, COLOR_WATER_GLOW]
		Style.HARVEST:
			return [COLOR_HARVEST, COLOR_HARVEST_GLOW]
		Style.PLANT:
			return [COLOR_PLANT, COLOR_PLANT_GLOW]
		Style.TOO_FAR:
			return [COLOR_FAR, COLOR_FAR_GLOW]
		_:
			return [COLOR_READY, COLOR_READY_GLOW]


func _draw() -> void:
	if not _active:
		return

	var pulse := 1.0 + sin(_pulse_t) * pulse_amount
	var half := frame_size * 0.5 * pulse
	var rect := Rect2(frame_offset - half, frame_size * pulse)
	var colors := _style_colors()
	var main_color: Color = colors[0]
	var glow_color: Color = colors[1]
	var width := line_width if _style != Style.TOO_FAR else line_width - 0.5

	if glow_grow > 0.0:
		draw_rect(rect.grow(glow_grow), glow_color, false, 2.0)
	draw_rect(rect, main_color, false, width)
