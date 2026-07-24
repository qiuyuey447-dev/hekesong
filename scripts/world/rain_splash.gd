extends Node2D
class_name RainSplash
## 落在地面/角色脚边的溅点，参与 y_sort。

var _life := 0.2
var _max_life := 0.2


func setup(world_pos: Vector2, life: float = 0.22) -> void:
	global_position = world_pos
	_max_life = life
	_life = life
	z_index = int(world_pos.y)
	set_process(true)


func _process(delta: float) -> void:
	_life -= delta
	if _life <= 0.0:
		queue_free()
		return
	queue_redraw()


func _draw() -> void:
	var t := clampf(_life / _max_life, 0.0, 1.0)
	var radius := lerpf(1.5, 4.0, 1.0 - t)
	draw_circle(Vector2.ZERO, radius, Color(0.92, 0.96, 1.0, t * 0.85))
