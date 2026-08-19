extends Node
## 根据当前可交互目标切换鼠标样式。

enum Mode { DEFAULT, PLANT, WATER, HARVEST, INTERACT }

var _textures: Dictionary = {}
var _current := Mode.DEFAULT


func _ready() -> void:
	_textures = {
		Mode.DEFAULT: _build_cursor(Color(0.92, 0.92, 0.94), Color(0.18, 0.18, 0.22)),
		Mode.PLANT: _build_cursor(Color(0.52, 0.88, 0.48), Color(0.12, 0.28, 0.1)),
		Mode.WATER: _build_cursor(Color(0.42, 0.74, 1.0), Color(0.08, 0.16, 0.28)),
		Mode.HARVEST: _build_cursor(Color(1.0, 0.62, 0.18), Color(0.28, 0.14, 0.04)),
		Mode.INTERACT: _build_cursor(Color(1.0, 0.96, 0.72), Color(0.34, 0.28, 0.12)),
	}
	set_mode(Mode.DEFAULT)


func set_mode(mode: Mode) -> void:
	if _current == mode:
		return
	_current = mode
	var tex: Texture2D = _textures.get(mode, _textures[Mode.DEFAULT])
	Input.set_custom_mouse_cursor(tex, Input.CURSOR_ARROW, Vector2(8, 8))


func set_from_highlight_style(style: InteractHighlight.Style) -> void:
	match style:
		InteractHighlight.Style.HARVEST:
			set_mode(Mode.HARVEST)
		InteractHighlight.Style.WATER:
			set_mode(Mode.WATER)
		InteractHighlight.Style.PLANT:
			set_mode(Mode.PLANT)
		_:
			set_mode(Mode.INTERACT)


func reset() -> void:
	set_mode(Mode.DEFAULT)


func _build_cursor(fill: Color, border: Color) -> ImageTexture:
	var size := 16
	var img := Image.create(size, size, false, Image.FORMAT_RGBA8)
	img.fill(Color(0, 0, 0, 0))
	for y in range(size):
		for x in range(size):
			var dx := absf(x - 7.5)
			var dy := absf(y - 7.5)
			if dx <= 6.5 and dy <= 6.5:
				if dx >= 5.5 or dy >= 5.5:
					img.set_pixel(x, y, border)
				else:
					img.set_pixel(x, y, fill)
	# Simple pointer tip at bottom-right.
	img.set_pixel(11, 11, border)
	img.set_pixel(12, 12, fill)
	img.set_pixel(13, 13, fill)
	return ImageTexture.create_from_image(img)
