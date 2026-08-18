extends Node2D
## 看图工具：把若干素材目录里的 PNG 排成带文件名的网格，一张截图看完整个调色板。
## 只服务于摆设设计，不参与游戏。

# 院子实际用到的几类。要看别的目录直接改这里再跑。
# 看树尤其有用：这套素材有四个色系（深绿 01/02/03/13、蓝 08~12、柠檬绿 04/30/31、
# 洋红 29/32），混着摆场景就花，摆之前先看一眼这张表。
const DIRS: Array[String] = [
	"res://Props/Trees/Sprites",
	"res://Props/Rocks/Sprites",
	"res://Props/Barrels/Sprites",
	"res://Props/Potted plants/Sprites",
	"res://Props/Books/Sprites",
]

const COLS := 10
const CELL := Vector2(186, 176)
const ICON_BOX := 104.0
const MARGIN := Vector2(40, 40)


func _ready() -> void:
	RenderingServer.set_default_clear_color(Color(0.24, 0.30, 0.24))
	var col := 0
	var row := 0
	for dir_path in DIRS:
		if col != 0:
			col = 0
			row += 1
		_add_header(dir_path, row)
		row += 1
		for file_name in _png_files(dir_path):
			_add_cell(dir_path + "/" + file_name, col, row)
			col += 1
			if col >= COLS:
				col = 0
				row += 1
	var camera := Camera2D.new()
	camera.position = MARGIN + Vector2(COLS, row + 1) * CELL * 0.5
	var span := Vector2(COLS, row + 1) * CELL + MARGIN * 2.0
	camera.zoom = Vector2.ONE * minf(1920.0 / span.x, 1080.0 / span.y)
	add_child(camera)
	camera.make_current()
	print("[asset_sheet] rows=%d zoom=%.3f" % [row + 1, camera.zoom.x])


func _png_files(dir_path: String) -> Array[String]:
	var out: Array[String] = []
	var dir := DirAccess.open(dir_path)
	if dir == null:
		push_error("[asset_sheet] 打不开 %s" % dir_path)
		return out
	for file_name in dir.get_files():
		if file_name.ends_with(".png"):
			out.append(file_name)
	out.sort()
	return out


func _add_header(text: String, row: int) -> void:
	var label := Label.new()
	label.text = text
	label.add_theme_font_size_override("font_size", 30)
	label.add_theme_color_override("font_color", Color(1, 0.95, 0.7))
	label.position = MARGIN + Vector2(0, row * CELL.y + CELL.y * 0.3)
	add_child(label)


func _add_cell(png_path: String, col: int, row: int) -> void:
	var tex: Texture2D = load(png_path)
	if tex == null:
		return
	var origin := MARGIN + Vector2(col, row) * CELL
	var sprite := Sprite2D.new()
	sprite.texture = tex
	sprite.texture_filter = CanvasItem.TEXTURE_FILTER_NEAREST
	sprite.centered = false
	var size := Vector2(tex.get_width(), tex.get_height())
	var fit := ICON_BOX / maxf(size.x, size.y)
	sprite.scale = Vector2(fit, fit)
	# 底对齐，方便比较各素材的实际站位高度
	sprite.position = origin + Vector2(CELL.x * 0.5 - size.x * fit * 0.5, ICON_BOX + 12.0 - size.y * fit)
	add_child(sprite)

	var label := Label.new()
	label.text = "%s  %dx%d" % [png_path.get_file().get_basename(), int(size.x), int(size.y)]
	label.add_theme_font_size_override("font_size", 19)
	label.add_theme_color_override("font_color", Color(0.92, 0.96, 0.9))
	label.position = origin + Vector2(6, ICON_BOX + 20.0)
	add_child(label)
