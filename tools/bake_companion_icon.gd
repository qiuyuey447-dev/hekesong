extends Node
## godot --headless --path <根> res://tools/bake_companion_icon.tscn

const OUT_PATH := "res://assets/ui/companion_icon.png"
const FOX_TEX: Texture2D = preload("res://Characters/Animals/fox1_16x20.png")
const FRAME := Vector2i(16, 20)


func _ready() -> void:
	var ok := _save_png(OUT_PATH, 128, 5)
	if ok:
		print("Saved %s" % OUT_PATH)
	else:
		push_error("Failed to save companion icon")
	get_tree().quit(0 if ok else 1)


func _save_png(path: String, size: int, scale: int) -> bool:
	var img := _bake_image(size, scale)
	var abs_path := ProjectSettings.globalize_path(path)
	DirAccess.make_dir_recursive_absolute(abs_path.get_base_dir())
	return img.save_png(abs_path) == OK


func _bake_image(size: int, scale: int) -> Image:
	var img := Image.create(size, size, false, Image.FORMAT_RGBA8)
	img.fill(Color(0, 0, 0, 0))
	_paint_round_rect(img, Rect2i(0, 0, size, size), 18, Color(0.96, 0.90, 0.78, 1.0))
	_blit_fox(img, scale)
	return img


func _paint_round_rect(img: Image, rect: Rect2i, radius: int, color: Color) -> void:
	var r := maxi(radius, 0)
	for y in range(rect.position.y, rect.position.y + rect.size.y):
		for x in range(rect.position.x, rect.position.x + rect.size.x):
			if _point_in_round_rect(Vector2i(x, y), rect, r):
				img.set_pixel(x, y, color)


func _point_in_round_rect(p: Vector2i, rect: Rect2i, radius: int) -> bool:
	if not rect.has_point(p):
		return false
	var left := rect.position.x
	var top := rect.position.y
	var right := rect.position.x + rect.size.x - 1
	var bottom := rect.position.y + rect.size.y - 1
	var corners := [
		Vector2i(left + radius, top + radius),
		Vector2i(right - radius, top + radius),
		Vector2i(left + radius, bottom - radius),
		Vector2i(right - radius, bottom - radius),
	]
	if p.x < left + radius and p.y < top + radius:
		return p.distance_squared_to(corners[0]) <= radius * radius
	if p.x > right - radius and p.y < top + radius:
		return p.distance_squared_to(corners[1]) <= radius * radius
	if p.x < left + radius and p.y > bottom - radius:
		return p.distance_squared_to(corners[2]) <= radius * radius
	if p.x > right - radius and p.y > bottom - radius:
		return p.distance_squared_to(corners[3]) <= radius * radius
	return true


func _blit_fox(img: Image, scale: int) -> void:
	var atlas := FOX_TEX.get_image()
	if atlas == null:
		return
	var src_x := FRAME.x
	var src_y := 0
	var dest_w := FRAME.x * scale
	var dest_h := FRAME.y * scale
	var dest_x := int((img.get_width() - dest_w) * 0.5)
	var dest_y := int((img.get_height() - dest_h) * 0.5) + scale + scale / 2
	for dy in range(dest_h):
		for dx in range(dest_w):
			var sx := src_x + dx / scale
			var sy := src_y + dy / scale
			var c := atlas.get_pixel(sx, sy)
			if c.a <= 0.01:
				continue
			var px := dest_x + dx
			var py := dest_y + dy
			if px < 0 or py < 0 or px >= img.get_width() or py >= img.get_height():
				continue
			img.set_pixel(px, py, c)
