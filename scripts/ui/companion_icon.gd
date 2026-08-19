class_name CompanionIcon
extends RefCounted

const FOX_TEX: Texture2D = preload("res://Characters/Animals/fox1_16x20.png")
const FRAME := Vector2i(16, 20)
const STAND_COL := 1
const STAND_ROW := 0


static func bake_texture(size: int = 128, scale: int = 4) -> ImageTexture:
	var img := Image.create(size, size, false, Image.FORMAT_RGBA8)
	img.fill(Color(0, 0, 0, 0))
	_paint_round_rect(img, Rect2i(0, 0, size, size), 18, Color(0.96, 0.90, 0.78, 1.0))
	_paint_round_rect(img, Rect2i(1, 1, size - 2, size - 2), 17, Color(0.96, 0.90, 0.78, 1.0))
	_blit_fox(img, scale)
	return ImageTexture.create_from_image(img)


static func save_png(path: String, size: int = 128, scale: int = 4) -> bool:
	var tex := bake_texture(size, scale)
	var abs_path := ProjectSettings.globalize_path(path)
	DirAccess.make_dir_recursive_absolute(abs_path.get_base_dir())
	var err := tex.get_image().save_png(abs_path)
	return err == OK


static func _paint_round_rect(img: Image, rect: Rect2i, radius: int, color: Color) -> void:
	var r := maxi(radius, 0)
	for y in range(rect.position.y, rect.position.y + rect.size.y):
		for x in range(rect.position.x, rect.position.x + rect.size.x):
			if _point_in_round_rect(Vector2i(x, y), rect, r):
				img.set_pixel(x, y, color)


static func _point_in_round_rect(p: Vector2i, rect: Rect2i, radius: int) -> bool:
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


static func _blit_fox(img: Image, scale: int) -> void:
	var atlas := FOX_TEX.get_image()
	if atlas == null:
		return
	var src_x := STAND_COL * FRAME.x
	var src_y := STAND_ROW * FRAME.y
	var dest_w := FRAME.x * scale
	var dest_h := FRAME.y * scale
	var dest_x := int((img.get_width() - dest_w) * 0.5)
	var dest_y := int((img.get_height() - dest_h) * 0.5) + int(scale * 1.5)
	for dy in range(dest_h):
		for dx in range(dest_w):
			var sx := src_x + int(float(dx) / float(scale))
			var sy := src_y + int(float(dy) / float(scale))
			var c := atlas.get_pixel(sx, sy)
			if c.a <= 0.01:
				continue
			var px := dest_x + dx
			var py := dest_y + dy
			if px < 0 or py < 0 or px >= img.get_width() or py >= img.get_height():
				continue
			img.set_pixel(px, py, c)
