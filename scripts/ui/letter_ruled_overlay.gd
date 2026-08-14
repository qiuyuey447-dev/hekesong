extends Control
class_name LetterRuledOverlay
## 信纸淡横线 + 左侧装订线。

func _ready() -> void:
	mouse_filter = Control.MOUSE_FILTER_IGNORE
	set_anchors_preset(Control.PRESET_FULL_RECT)
	set_offsets_preset(Control.PRESET_FULL_RECT)
	resized.connect(queue_redraw)


func _draw() -> void:
	var y := 56.0
	while y < size.y - 28.0:
		draw_line(Vector2(28, y), Vector2(size.x - 28, y), LetterPaperKit.RULE, 1.0)
		y += 28.0
	draw_line(Vector2(22, 24), Vector2(22, size.y - 20), Color(0.72, 0.42, 0.38, 0.18), 1.5)
