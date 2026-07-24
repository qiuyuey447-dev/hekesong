class_name SpriteSheet
extends RefCounted

## 从横向或网格精灵图中取单帧，避免整张图集显示成重复物体。


static func idiv(a: int, b: int) -> int:
	if b == 0:
		return 0
	return int(a / b)


static func frame_from_sheet(
	texture: Texture2D,
	frame_size: Vector2i,
	frame_index: int = 0
) -> AtlasTexture:
	var atlas := AtlasTexture.new()
	atlas.atlas = texture
	var cols := maxi(1, idiv(texture.get_width(), frame_size.x))
	var idx := clampi(frame_index, 0, cols - 1)
	atlas.region = Rect2(idx * frame_size.x, 0, frame_size.x, frame_size.y)
	return atlas


static func grid_frame(
	texture: Texture2D,
	frame_size: Vector2i,
	col: int,
	row: int
) -> AtlasTexture:
	var atlas := AtlasTexture.new()
	atlas.atlas = texture
	atlas.region = Rect2(col * frame_size.x, row * frame_size.y, frame_size.x, frame_size.y)
	return atlas


static func crop_frame(texture: Texture2D, frame_index: int) -> AtlasTexture:
	var frame_h := texture.get_height()
	var cols := maxi(1, idiv(texture.get_width(), frame_h))
	var frame_w := idiv(texture.get_width(), cols)
	var idx := clampi(frame_index, 0, cols - 1)
	return frame_from_sheet(texture, Vector2i(frame_w, frame_h), idx)


static func mature_crop_frame(texture: Texture2D) -> AtlasTexture:
	var frame_h := texture.get_height()
	var cols := maxi(1, idiv(texture.get_width(), frame_h))
	return crop_frame(texture, cols - 2)
