extends RefCounted

const TILE_SIZE := 32
const CLIFF_H := 10


static func create_tileset_texture() -> ImageTexture:
	var count := 10
	var img := Image.create(TILE_SIZE * count, TILE_SIZE, false, Image.FORMAT_RGBA8)
	img.fill(Color(0, 0, 0, 0))

	_paint_grass(img, 0)
	_paint_grass_alt(img, 1)
	_paint_soil(img, 2, Color(0.62, 0.42, 0.24), Color(0.52, 0.34, 0.18))
	_paint_soil(img, 3, Color(0.48, 0.58, 0.72), Color(0.38, 0.48, 0.62))
	_paint_wood(img, 4)
	_paint_path(img, 5)
	_paint_fence(img, 6)
	_paint_pond(img, 7)
	_paint_flowers_ground(img, 8)
	_paint_grass_dark(img, 9)

	return ImageTexture.create_from_image(img)


static func create_raised_surface(kind: String, cliff_south: bool) -> ImageTexture:
	var h := TILE_SIZE + (CLIFF_H if cliff_south else 0)
	var img := Image.create(TILE_SIZE, h, false, Image.FORMAT_RGBA8)
	img.fill(Color(0, 0, 0, 0))

	match kind:
		"soil_dry":
			_blit_flat_soil(img, 0, Color(0.62, 0.42, 0.24), Color(0.52, 0.34, 0.18))
		"soil_wet":
			_blit_flat_soil(img, 0, Color(0.48, 0.58, 0.72), Color(0.38, 0.48, 0.62))
		"wood":
			_blit_flat_wood(img, 0)
		_:
			_blit_flat_grass(img, 0)

	if cliff_south:
		var side := _side_color_for_kind(kind)
		for y in range(TILE_SIZE, TILE_SIZE + CLIFF_H):
			for x in range(TILE_SIZE):
				var depth := float(y - TILE_SIZE) / CLIFF_H
				img.set_pixel(x, y, side.darkened(0.06 * depth))
		for x in range(0, TILE_SIZE, 4):
			img.set_pixel(x, TILE_SIZE + CLIFF_H - 1, side.darkened(0.18))

	_frame(img, 0, TILE_SIZE)
	return ImageTexture.create_from_image(img)


static func create_cliff_cap(kind: String) -> ImageTexture:
	return create_raised_surface(kind, true)


static func create_wall_texture() -> ImageTexture:
	var img := Image.create(32, 20, false, Image.FORMAT_RGBA8)
	img.fill(Color(0, 0, 0, 0))
	var base := Color(0.68, 0.52, 0.36)
	for y in range(20):
		for x in range(32):
			img.set_pixel(x, y, base.darkened(0.04 * y))
	for y in range(0, 20, 4):
		for x in range(32):
			img.set_pixel(x, y, base.lightened(0.04))
	_add_outline(img)
	return ImageTexture.create_from_image(img)


static func create_player_texture() -> ImageTexture:
	var img := Image.create(32, 48, false, Image.FORMAT_RGBA8)
	img.fill(Color(0, 0, 0, 0))

	var skin := Color(0.94, 0.76, 0.62)
	var hair := Color(0.30, 0.22, 0.18)
	var shirt := Color(0.38, 0.62, 0.88)
	var pants := Color(0.42, 0.38, 0.58)
	var shoe := Color(0.24, 0.20, 0.18)

	for y in range(14, 20):
		for x in range(11, 21):
			img.set_pixel(x, y, hair)
	for y in range(20, 26):
		for x in range(12, 20):
			img.set_pixel(x, y, skin)
	for y in range(26, 36):
		for x in range(11, 21):
			img.set_pixel(x, y, shirt)
	for y in range(36, 42):
		for x in range(12, 20):
			img.set_pixel(x, y, pants)
	for x in [11, 12, 19, 20]:
		img.set_pixel(x, 42, shoe)
		img.set_pixel(x, 43, shoe)

	img.set_pixel(14, 22, Color(0.12, 0.10, 0.08))
	img.set_pixel(17, 22, Color(0.12, 0.10, 0.08))
	_add_outline(img)
	return ImageTexture.create_from_image(img)


static func create_character_texture(main: Color, accent: Color) -> ImageTexture:
	var img := Image.create(32, 48, false, Image.FORMAT_RGBA8)
	img.fill(Color(0, 0, 0, 0))

	for y in range(18, 22):
		for x in range(12, 20):
			img.set_pixel(x, y, main)
	for y in range(22, 36):
		for x in range(11, 21):
			img.set_pixel(x, y, main)
	for y in range(34, 42):
		for x in range(10, 14):
			img.set_pixel(x, y, main.darkened(0.15))
		for x in range(18, 22):
			img.set_pixel(x, y, main.darkened(0.15))
	for y in range(24, 30):
		for x in range(14, 18):
			img.set_pixel(x, y, accent)

	img.set_pixel(11, 17, main)
	img.set_pixel(20, 17, main)
	img.set_pixel(10, 18, main)
	img.set_pixel(21, 18, main)
	img.set_pixel(14, 20, Color(0.12, 0.1, 0.08))
	img.set_pixel(17, 20, Color(0.12, 0.1, 0.08))
	_add_outline(img)

	return ImageTexture.create_from_image(img)


static func create_crop_texture(watered: bool) -> ImageTexture:
	var img := Image.create(24, 28, false, Image.FORMAT_RGBA8)
	img.fill(Color(0, 0, 0, 0))
	var green := Color(0.36, 0.72, 0.32) if watered else Color(0.30, 0.58, 0.26)
	var stem := green.darkened(0.12)

	for y in range(14, 24):
		img.set_pixel(11, y, stem)
		img.set_pixel(12, y, stem)
	for y in range(10, 16):
		for x in range(6, 11):
			img.set_pixel(x, y, green)
	for y in range(8, 14):
		for x in range(13, 18):
			img.set_pixel(x, y, green.lightened(0.06))
	for y in range(4, 10):
		img.set_pixel(11, y, green.lightened(0.08))
		img.set_pixel(12, y, green.lightened(0.08))

	_add_outline(img)
	return ImageTexture.create_from_image(img)


static func create_prop_texture(size: Vector2i, base: Color, accent: Color) -> ImageTexture:
	var img := Image.create(size.x, size.y, false, Image.FORMAT_RGBA8)
	img.fill(Color(0, 0, 0, 0))
	for y in range(size.y):
		for x in range(size.x):
			img.set_pixel(x, y, base)
	for x in range(2, size.x - 2):
		img.set_pixel(x, 2, accent)
	_add_outline(img)
	return ImageTexture.create_from_image(img)


static func create_door_texture() -> ImageTexture:
	return create_prop_texture(
		Vector2i(28, 40),
		Color(0.52, 0.36, 0.22),
		Color(0.68, 0.50, 0.32)
	)


static func create_bush_texture() -> ImageTexture:
	var img := Image.create(24, 20, false, Image.FORMAT_RGBA8)
	img.fill(Color(0, 0, 0, 0))
	var green := Color(0.34, 0.66, 0.30)
	for y in range(6, 18):
		for x in range(4, 20):
			if (x - 12) * (x - 12) + (y - 12) * (y - 12) < 64:
				img.set_pixel(x, y, green if x % 2 == 0 else green.darkened(0.08))
	_add_outline(img)
	return ImageTexture.create_from_image(img)


static func create_rock_texture() -> ImageTexture:
	var img := Image.create(20, 16, false, Image.FORMAT_RGBA8)
	img.fill(Color(0, 0, 0, 0))
	var stone := Color(0.58, 0.56, 0.52)
	for y in range(4, 14):
		for x in range(3, 17):
			if (x - 10) * (x - 10) + (y - 10) * (y - 10) < 36:
				img.set_pixel(x, y, stone.darkened(0.04 * y))
	_add_outline(img)
	return ImageTexture.create_from_image(img)


static func create_rug_texture() -> ImageTexture:
	var img := Image.create(48, 32, false, Image.FORMAT_RGBA8)
	img.fill(Color(0, 0, 0, 0))
	var base := Color(0.72, 0.42, 0.38)
	var border := Color(0.88, 0.62, 0.42)
	for y in range(32):
		for x in range(48):
			var edge := x < 3 or x > 44 or y < 3 or y > 28
			img.set_pixel(x, y, border if edge else base)
	for x in range(10, 38, 6):
		img.set_pixel(x, 16, border.darkened(0.1))
	_add_outline(img)
	return ImageTexture.create_from_image(img)


static func create_barrel_texture() -> ImageTexture:
	var img := Image.create(20, 24, false, Image.FORMAT_RGBA8)
	img.fill(Color(0, 0, 0, 0))
	var wood := Color(0.58, 0.40, 0.26)
	for y in range(4, 22):
		for x in range(5, 15):
			img.set_pixel(x, y, wood.darkened(0.03 * y))
	for y in [8, 16]:
		for x in range(4, 16):
			img.set_pixel(x, y, wood.darkened(0.15))
	_add_outline(img)
	return ImageTexture.create_from_image(img)


static func create_window_texture() -> ImageTexture:
	var img := Image.create(24, 20, false, Image.FORMAT_RGBA8)
	img.fill(Color(0, 0, 0, 0))
	var frame := Color(0.62, 0.48, 0.32)
	var glass := Color(0.62, 0.82, 0.94, 0.85)
	for y in range(20):
		for x in range(24):
			img.set_pixel(x, y, frame)
	for y in range(4, 16):
		for x in range(4, 20):
			img.set_pixel(x, y, glass)
	img.set_pixel(11, 4, frame)
	img.set_pixel(11, 15, frame)
	for y in range(4, 16):
		img.set_pixel(11, y, frame)
	_add_outline(img)
	return ImageTexture.create_from_image(img)


static func create_chair_texture() -> ImageTexture:
	return create_prop_texture(Vector2i(20, 28), Color(0.54, 0.38, 0.24), Color(0.68, 0.50, 0.32))


static func create_stump_texture() -> ImageTexture:
	var img := Image.create(20, 16, false, Image.FORMAT_RGBA8)
	img.fill(Color(0, 0, 0, 0))
	var wood := Color(0.52, 0.36, 0.22)
	for y in range(6, 14):
		for x in range(4, 16):
			img.set_pixel(x, y, wood)
	for y in range(4, 8):
		for x in range(6, 14):
			img.set_pixel(x, y, wood.lightened(0.06))
	_add_outline(img)
	return ImageTexture.create_from_image(img)


static func create_steps_texture() -> ImageTexture:
	var img := Image.create(32, 16, false, Image.FORMAT_RGBA8)
	img.fill(Color(0, 0, 0, 0))
	var stone := Color(0.62, 0.58, 0.52)
	for step in range(3):
		var y0 := step * 4
		for y in range(y0, y0 + 4):
			for x in range(step * 2, 32 - step * 2):
				img.set_pixel(x, y + 4, stone.darkened(0.05 * step))
	_add_outline(img)
	return ImageTexture.create_from_image(img)


static func create_shadow_texture(size: Vector2i) -> ImageTexture:
	var img := Image.create(size.x, size.y, false, Image.FORMAT_RGBA8)
	img.fill(Color(0, 0, 0, 0))
	var cx := size.x * 0.5
	var cy := size.y * 0.5
	for y in range(size.y):
		for x in range(size.x):
			var dx := (x - cx) / cx
			var dy := (y - cy) / cy
			if dx * dx + dy * dy <= 1.0:
				img.set_pixel(x, y, Color(0, 0, 0, 0.20))
	return ImageTexture.create_from_image(img)


static func _side_color_for_kind(kind: String) -> Color:
	match kind:
		"soil_dry":
			return Color(0.48, 0.32, 0.18)
		"soil_wet":
			return Color(0.32, 0.44, 0.58)
		"wood":
			return Color(0.58, 0.44, 0.30)
		_:
			return Color(0.30, 0.52, 0.28)


static func _blit_flat_grass(img: Image, y0: int) -> void:
	var base := Color(0.42, 0.72, 0.36)
	for y in range(y0, y0 + TILE_SIZE):
		for x in range(TILE_SIZE):
			img.set_pixel(x, y, base)


static func _blit_flat_soil(img: Image, y0: int, base: Color, dark: Color) -> void:
	for y in range(y0, y0 + TILE_SIZE):
		for x in range(TILE_SIZE):
			img.set_pixel(x, y, base)
	for x in range(4, TILE_SIZE - 4, 8):
		img.set_pixel(x, y0 + TILE_SIZE - 3, dark)


static func _blit_flat_wood(img: Image, y0: int) -> void:
	var base := Color(0.78, 0.62, 0.44)
	for y in range(y0, y0 + TILE_SIZE):
		for x in range(TILE_SIZE):
			img.set_pixel(x, y, base)
	for y in range(y0, y0 + TILE_SIZE, 4):
		for x in range(TILE_SIZE):
			img.set_pixel(x, y, base.darkened(0.08))


static func _paint_grass(img: Image, index: int) -> void:
	var ox := index * TILE_SIZE
	var base := Color(0.42, 0.72, 0.36)
	var dark := Color(0.34, 0.60, 0.30)
	var light := Color(0.52, 0.80, 0.44)
	for y in range(TILE_SIZE):
		for x in range(TILE_SIZE):
			img.set_pixel(ox + x, y, base)

	var accents := [Vector2i(8, 10), Vector2i(22, 6), Vector2i(16, 20)]
	for i in range(accents.size()):
		var d: Vector2i = accents[i]
		img.set_pixel(ox + d.x, d.y, dark if i % 2 == 0 else light)

	for x in range(TILE_SIZE):
		img.set_pixel(ox + x, TILE_SIZE - 1, dark)
		img.set_pixel(ox + x, 0, light.darkened(0.05))
	_frame(img, ox, TILE_SIZE)


static func _paint_grass_alt(img: Image, index: int) -> void:
	var ox := index * TILE_SIZE
	var base := Color(0.46, 0.76, 0.40)
	for y in range(TILE_SIZE):
		for x in range(TILE_SIZE):
			img.set_pixel(ox + x, y, base)
	img.set_pixel(ox + 10, 14, Color(0.38, 0.64, 0.34))
	img.set_pixel(ox + 20, 8, Color(0.54, 0.84, 0.46))
	_frame(img, ox, TILE_SIZE)


static func _paint_grass_dark(img: Image, index: int) -> void:
	var ox := index * TILE_SIZE
	var base := Color(0.36, 0.62, 0.32)
	for y in range(TILE_SIZE):
		for x in range(TILE_SIZE):
			img.set_pixel(ox + x, y, base)
	_frame(img, ox, TILE_SIZE)


static func _paint_pond(img: Image, index: int) -> void:
	var ox := index * TILE_SIZE
	var water := Color(0.38, 0.68, 0.88)
	var deep := Color(0.28, 0.54, 0.72)
	for y in range(TILE_SIZE):
		for x in range(TILE_SIZE):
			img.set_pixel(ox + x, y, water if (x + y) % 5 != 0 else deep)
	for x in range(4, TILE_SIZE - 4):
		img.set_pixel(ox + x, 4, water.lightened(0.12))
	_frame(img, ox, TILE_SIZE)


static func _paint_flowers_ground(img: Image, index: int) -> void:
	var ox := index * TILE_SIZE
	var base := Color(0.44, 0.74, 0.38)
	for y in range(TILE_SIZE):
		for x in range(TILE_SIZE):
			img.set_pixel(ox + x, y, base)
	var colors := [Color(0.92, 0.52, 0.62), Color(0.92, 0.82, 0.38), Color(0.72, 0.58, 0.92)]
	var spots := [Vector2i(8, 12), Vector2i(18, 8), Vector2i(24, 18), Vector2i(12, 22)]
	for i in range(spots.size()):
		var d: Vector2i = spots[i]
		for dy in range(-1, 2):
			for dx in range(-1, 2):
				img.set_pixel(ox + d.x + dx, d.y + dy, colors[i % colors.size()])
	_frame(img, ox, TILE_SIZE)


static func _paint_soil(img: Image, index: int, base: Color, dark: Color) -> void:
	var ox := index * TILE_SIZE
	for y in range(TILE_SIZE):
		for x in range(TILE_SIZE):
			img.set_pixel(ox + x, y, base)
	for x in range(ox + 4, ox + TILE_SIZE - 4, 8):
		img.set_pixel(x, TILE_SIZE - 3, dark)
	_frame(img, ox, TILE_SIZE)


static func _paint_wood(img: Image, index: int) -> void:
	var ox := index * TILE_SIZE
	var base := Color(0.78, 0.62, 0.44)
	for y in range(TILE_SIZE):
		for x in range(TILE_SIZE):
			img.set_pixel(ox + x, y, base)
	for y in range(0, TILE_SIZE, 4):
		for x in range(TILE_SIZE):
			img.set_pixel(ox + x, y, base.darkened(0.08))
	_frame(img, ox, TILE_SIZE)


static func _paint_path(img: Image, index: int) -> void:
	var ox := index * TILE_SIZE
	var base := Color(0.66, 0.54, 0.40)
	for y in range(TILE_SIZE):
		for x in range(TILE_SIZE):
			img.set_pixel(ox + x, y, base)
	for i in range(4):
		img.set_pixel(ox + 6 + i * 6, 10 + i, base.darkened(0.08))
	_frame(img, ox, TILE_SIZE)


static func _paint_fence(img: Image, index: int) -> void:
	var ox := index * TILE_SIZE
	var wood := Color(0.68, 0.50, 0.32)
	for y in range(TILE_SIZE):
		for x in range(TILE_SIZE):
			img.set_pixel(ox + x, y, Color(0, 0, 0, 0))
	for x in range(ox + 6, ox + TILE_SIZE - 4, 8):
		for y in range(6, TILE_SIZE - 2):
			img.set_pixel(x, y, wood)
	for y in [8, 20]:
		for x in range(ox + 4, ox + TILE_SIZE - 4):
			img.set_pixel(x, y, wood.darkened(0.1))


static func _frame(img: Image, ox: int, height: int) -> void:
	var edge := Color(0, 0, 0, 0.18)
	for x in range(TILE_SIZE):
		img.set_pixel(ox + x, 0, edge)
		img.set_pixel(ox + x, height - 1, edge.darkened(0.05))
	for y in range(height):
		img.set_pixel(ox, y, edge)
		img.set_pixel(ox + TILE_SIZE - 1, y, edge)


static func _add_outline(img: Image) -> void:
	var w := img.get_width()
	var h := img.get_height()
	var copy := img.duplicate()
	for y in range(h):
		for x in range(w):
			if copy.get_pixel(x, y).a < 0.1:
				continue
			for ny in range(y - 1, y + 2):
				for nx in range(x - 1, x + 2):
					if nx < 0 or ny < 0 or nx >= w or ny >= h:
						continue
					if copy.get_pixel(nx, ny).a < 0.1:
						img.set_pixel(nx, ny, Color(0.08, 0.06, 0.05, 0.55))
