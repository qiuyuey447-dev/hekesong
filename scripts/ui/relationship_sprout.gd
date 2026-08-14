extends Control
class_name RelationshipSprout
## 关系小苗：像素风盆栽 + 轻摇摆 / 呼吸 / 生长动画。不写任何说明文字。

const STAGE_HEIGHTS := [10.0, 22.0, 34.0, 44.0]

var tier: int = 0
var twin: bool = false

var _phase: float = 0.0
var _sway: float = 0.0
var _breath: float = 1.0
var _grow_punch: float = 1.0
var _sparkle_t: float = 0.0
var _idle_tween: Tween = null
var _grow_tween: Tween = null
var _idle_active: bool = false


func _ready() -> void:
	custom_minimum_size = Vector2(0, 188)
	size_flags_horizontal = Control.SIZE_EXPAND_FILL
	size_flags_vertical = Control.SIZE_EXPAND_FILL
	mouse_filter = Control.MOUSE_FILTER_IGNORE
	# 抽屉未打开时不空转；打开后再 start_idle。
	set_process(false)


func set_state(new_tier: int, show_twin: bool = false, animate_grow: bool = false) -> void:
	var old := tier
	tier = clampi(new_tier, 0, 3)
	twin = show_twin
	if animate_grow and tier > old:
		_play_grow()
	queue_redraw()


func start_idle() -> void:
	_idle_active = true
	set_process(true)
	_start_idle()


func stop_idle() -> void:
	_idle_active = false
	set_process(false)
	if _idle_tween != null and _idle_tween.is_valid():
		_idle_tween.kill()
	_idle_tween = null
	_sway = 0.0
	_breath = 1.0
	queue_redraw()


func _start_idle() -> void:
	if not _idle_active:
		return
	if _idle_tween != null and _idle_tween.is_valid():
		_idle_tween.kill()
	_idle_tween = create_tween().set_loops()
	_idle_tween.tween_method(_on_idle_tick, 0.0, TAU, 2.6)


func _on_idle_tick(t: float) -> void:
	_phase = t
	# 只轻轻摆叶，不要把整株从土里转出去。
	_sway = sin(t) * 0.045
	_breath = 1.0 + sin(t * 1.4) * 0.012
	_sparkle_t = t
	queue_redraw()


func _play_grow() -> void:
	if _grow_tween != null and _grow_tween.is_valid():
		_grow_tween.kill()
	_grow_punch = 0.68
	_grow_tween = create_tween()
	_grow_tween.tween_property(self, "_grow_punch", 1.14, 0.3).set_trans(Tween.TRANS_BACK).set_ease(Tween.EASE_OUT)
	_grow_tween.tween_property(self, "_grow_punch", 1.0, 0.24).set_trans(Tween.TRANS_CUBIC).set_ease(Tween.EASE_OUT)
	_grow_tween.tween_callback(queue_redraw)


func _process(_delta: float) -> void:
	if absf(_grow_punch - 1.0) > 0.001:
		queue_redraw()


func _draw() -> void:
	var w := size.x
	var h := size.y
	if w < 8.0 or h < 8.0:
		return

	var cx := w * 0.5
	var ground_y := h - 28.0
	var pot_top := ground_y - 6.0
	# 土面中心；植株原点再往土里埋一点，摇摆绕这里转才不会离盆。
	var soil_y := pot_top - 1.0
	var plant_origin := Vector2(cx, soil_y + 3.0)
	var scale_v := _breath * _grow_punch

	_draw_backdrop(w, h, ground_y)
	_draw_pot(cx, ground_y)

	var xform := Transform2D(_sway, plant_origin)
	xform = xform.scaled_local(Vector2(scale_v, scale_v))
	draw_set_transform_matrix(xform)
	_draw_plant_at_origin()
	if twin:
		var twin_origin := plant_origin + Vector2(20, 1)
		var twin_xform := Transform2D(-_sway * 0.85, twin_origin)
		twin_xform = twin_xform.scaled_local(Vector2(scale_v * 0.88, scale_v * 0.88))
		draw_set_transform_matrix(twin_xform)
		_draw_plant_at_origin(true)
	draw_set_transform_matrix(Transform2D.IDENTITY)

	# 土面盖在茎根上，摇摆时也不会露出缝。
	_draw_soil_cap(cx, soil_y)
	if twin:
		_draw_soil_cap(cx + 20.0, soil_y + 1.0, 0.72)

	if tier >= 3:
		var bloom_y := plant_origin.y - (STAGE_HEIGHTS[3] + 8.0) * scale_v
		_draw_sparkles(cx, bloom_y)


func _draw_backdrop(w: float, h: float, ground_y: float) -> void:
	var sky := Color(0.78, 0.90, 0.82, 1.0)
	var horizon := Color(0.70, 0.84, 0.62, 0.9)
	var time_key := str(GameState.time_of_day)
	match time_key:
		GameState.TIME_MORNING:
			sky = Color(0.96, 0.86, 0.72, 1.0)
			horizon = Color(0.88, 0.78, 0.52, 0.7)
		GameState.TIME_NOON:
			sky = Color(0.76, 0.90, 0.94, 1.0)
			horizon = Color(0.70, 0.86, 0.68, 0.75)
		GameState.TIME_EVENING:
			sky = Color(0.94, 0.72, 0.58, 1.0)
			horizon = Color(0.86, 0.58, 0.42, 0.7)
		GameState.TIME_NIGHT:
			sky = Color(0.42, 0.46, 0.62, 1.0)
			horizon = Color(0.32, 0.36, 0.48, 0.8)

	draw_rect(Rect2(0, 0, w, h), sky, true)
	# 近地暖色过渡，把增高后的空白填成田野。
	draw_rect(Rect2(0, ground_y - 52, w, 52), horizon, true)
	draw_rect(Rect2(0, ground_y - 18, w, h - ground_y + 18), Color(0.62, 0.74, 0.46, 0.55), true)

	# 远田垄（细条，不是大圆占位）
	for i in range(4):
		var row_y := ground_y - 44.0 + i * 7.0
		draw_line(Vector2(18, row_y), Vector2(w - 18, row_y + 2), Color(0.48, 0.62, 0.34, 0.18 + i * 0.04), 2.0)

	# 日 / 月
	if time_key == GameState.TIME_NIGHT:
		draw_circle(Vector2(w - 28, 22), 8, Color(0.92, 0.94, 0.86, 0.9))
		for i in range(6):
			var sx := 16.0 + fmod(float(i) * 47.0, w - 40.0)
			var sy := 10.0 + float(i % 3) * 9.0
			draw_circle(Vector2(sx, sy), 1.1, Color(1, 1, 0.92, 0.55))
	else:
		var sun_c := Color(1.0, 0.92, 0.55, 0.9) if time_key != GameState.TIME_EVENING else Color(1.0, 0.62, 0.32, 0.95)
		draw_circle(Vector2(w - 30, 24), 11, sun_c)
		draw_circle(Vector2(w - 32, 22), 4, Color(1, 1, 0.88, 0.5))

	# 小草贴地
	for i in range(9):
		var gx := 16.0 + i * ((w - 32.0) / 8.0)
		var gy := ground_y + 6.0 + (i % 3) * 1.2
		draw_line(Vector2(gx, gy), Vector2(gx - 1.5, gy - 5), Color(0.40, 0.56, 0.28, 0.45), 1.3)
		draw_line(Vector2(gx, gy), Vector2(gx + 1.8, gy - 4), Color(0.46, 0.62, 0.30, 0.38), 1.1)

	# 木台
	draw_rect(Rect2(22, ground_y + 10, w - 44, 8), Color(0.62, 0.42, 0.24, 0.7), true)
	draw_line(Vector2(22, ground_y + 10), Vector2(w - 22, ground_y + 10), Color(0.46, 0.30, 0.16, 0.45), 1.5)


func _draw_pot(cx: float, ground_y: float) -> void:
	var top := ground_y - 6.0
	var bottom := ground_y + 20.0
	var pot_mid := Color(0.68, 0.42, 0.26, 1.0)
	var pot_dark := Color(0.50, 0.30, 0.18, 1.0)
	var pot_rim := Color(0.80, 0.54, 0.32, 1.0)
	var pot_shadow := Color(0.28, 0.16, 0.08, 0.22)

	# 阴影
	_draw_ellipse(Vector2(cx, bottom + 4), Vector2(38, 6), pot_shadow)
	# 盆身（梯形感：上宽下窄的分段）
	draw_rect(Rect2(cx - 36, top, 72, bottom - top), pot_mid, true)
	draw_rect(Rect2(cx - 30, top + 10, 60, bottom - top - 8), pot_dark, true)
	# 底部收口
	draw_rect(Rect2(cx - 26, bottom - 6, 52, 6), Color(0.42, 0.24, 0.14, 1.0), true)
	# 口沿
	draw_rect(Rect2(cx - 42, top - 5, 84, 9), pot_rim, true)
	draw_rect(Rect2(cx - 40, top - 6, 80, 3), Color(0.88, 0.64, 0.40, 1.0), true)
	# 土面在植株绘制后再盖一层，这里只铺盆里的底土。
	_draw_ellipse(Vector2(cx, top - 1), Vector2(34, 7), Color(0.34, 0.22, 0.12, 1.0))
	_draw_ellipse(Vector2(cx - 4, top - 2), Vector2(12, 4), Color(0.42, 0.28, 0.16, 1.0))
	_draw_ellipse(Vector2(cx + 8, top - 1), Vector2(8, 3), Color(0.30, 0.20, 0.10, 1.0))
	# 盆身高光 / 刻线
	draw_rect(Rect2(cx - 32, top + 4, 5, 14), Color(1, 1, 1, 0.14), true)
	draw_line(Vector2(cx - 28, top + 14), Vector2(cx + 28, top + 14), Color(0.38, 0.22, 0.12, 0.35), 1.5)


func _draw_soil_cap(cx: float, soil_y: float, scale: float = 1.0) -> void:
	_draw_ellipse(Vector2(cx, soil_y), Vector2(18 * scale, 5 * scale), Color(0.32, 0.21, 0.12, 1.0))
	_draw_ellipse(Vector2(cx - 3 * scale, soil_y - 1.2), Vector2(7 * scale, 2.4 * scale), Color(0.44, 0.30, 0.16, 1.0))
	_draw_ellipse(Vector2(cx + 5 * scale, soil_y), Vector2(5 * scale, 2.0 * scale), Color(0.26, 0.16, 0.08, 1.0))


func _draw_plant_at_origin(is_twin: bool = false) -> void:
	match tier:
		0:
			_draw_seed_stage()
		1:
			_draw_cotyledon_stage()
		2:
			_draw_leafy_stage()
		_:
			_draw_bloom_stage(is_twin)


func _draw_seed_stage() -> void:
	# 种子半埋在原点（土面）里，只探出一点芽尖。
	_draw_ellipse(Vector2(0, 2), Vector2(5.2, 3.6), Color(0.52, 0.34, 0.15, 1.0))
	_draw_ellipse(Vector2(-1.4, 1.2), Vector2(2.2, 1.6), Color(0.70, 0.50, 0.26, 1.0))
	var tip := 1.6 + sin(_phase * 2.0) * 0.5
	draw_rect(Rect2(-1.1, -3 - tip, 2.2, 4.0 + tip), Color(0.50, 0.72, 0.32, 1.0), true)
	draw_rect(Rect2(-0.55, -4.2 - tip, 1.1, 1.8), Color(0.62, 0.82, 0.40, 1.0), true)


func _draw_cotyledon_stage() -> void:
	var stem_h := STAGE_HEIGHTS[1] + sin(_phase) * 1.2
	_draw_stem(stem_h, 3.0)
	var bob := sin(_phase * 1.6) * 1.5
	_draw_leaf(Vector2(-2, -stem_h + 4), -0.75 + _sway, 12.0 + bob * 0.25, false)
	_draw_leaf(Vector2(2, -stem_h + 3), 0.75 - _sway, 12.0 - bob * 0.25, true)


func _draw_leafy_stage() -> void:
	var stem_h := STAGE_HEIGHTS[2] + sin(_phase) * 1.5
	_draw_stem(stem_h, 3.5)
	var bob := sin(_phase * 1.7)
	_draw_leaf(Vector2(-3, -stem_h * 0.42), -0.9, 13.0, false)
	_draw_leaf(Vector2(3, -stem_h * 0.48), 0.9, 13.0, true)
	_draw_leaf(Vector2(-2.5, -stem_h + 7 + bob), -0.55, 15.0, false)
	_draw_leaf(Vector2(2.5, -stem_h + 6 - bob), 0.55, 15.0, true)
	# 顶心一小撮新叶
	_draw_leaf(Vector2(-1, -stem_h + 1), -0.25, 8.0, false)
	_draw_leaf(Vector2(1, -stem_h), 0.25, 8.0, true)


func _draw_bloom_stage(is_twin: bool) -> void:
	var stem_h := STAGE_HEIGHTS[3] + sin(_phase) * 1.8
	_draw_stem(stem_h, 4.0)
	_draw_leaf(Vector2(-4, -stem_h * 0.38), -0.95, 14.0, false)
	_draw_leaf(Vector2(4, -stem_h * 0.4), 0.95, 14.0, true)
	_draw_leaf(Vector2(-3.5, -stem_h * 0.68), -0.55, 13.0, false)
	_draw_leaf(Vector2(3.5, -stem_h * 0.66), 0.55, 13.0, true)
	var bloom_y := -stem_h - 2.0
	var pulse := 1.0 + sin(_phase * 2.2) * 0.09
	_draw_flower(Vector2(0, bloom_y), 7.5 * pulse, is_twin)


func _draw_stem(height: float, thickness: float) -> void:
	var dark := Color(0.32, 0.52, 0.26, 1.0)
	var lite := Color(0.48, 0.70, 0.36, 1.0)
	# 茎根埋进土里几像素，摆动时根还在土下。
	var buried := 6.0
	var mid_x := sin(_phase * 0.8) * 0.6
	draw_rect(Rect2(-thickness * 0.5 + mid_x * 0.25, -height * 0.55, thickness, height * 0.55 + buried), dark, true)
	draw_rect(Rect2(-thickness * 0.5, -height, thickness, height * 0.5), dark, true)
	draw_rect(Rect2(-thickness * 0.5, -height, thickness * 0.42, height + buried * 0.4), lite, true)


func _draw_leaf(pos: Vector2, angle: float, length: float, flip: bool) -> void:
	var c := Transform2D().translated(pos).rotated(angle)
	var dir := 1.0 if not flip else -1.0
	var fill := Color(0.44, 0.74, 0.34, 1.0)
	var edge := Color(0.30, 0.52, 0.22, 0.85)
	var tip := Color(0.58, 0.84, 0.42, 1.0)

	var pts := PackedVector2Array()
	pts.append(c * Vector2(0, 0))
	pts.append(c * Vector2(dir * length * 0.28, -length * 0.38))
	pts.append(c * Vector2(dir * length * 0.72, -length * 0.22))
	pts.append(c * Vector2(dir * length, -length * 0.05))
	pts.append(c * Vector2(dir * length * 0.55, length * 0.22))
	pts.append(c * Vector2(dir * length * 0.18, length * 0.12))
	draw_colored_polygon(pts, fill)
	# 叶尖亮一点
	draw_circle(c * Vector2(dir * length * 0.85, -length * 0.08), length * 0.12, tip)
	# 叶脉
	draw_line(c * Vector2(0, 0), c * Vector2(dir * length * 0.8, -length * 0.06), edge, 1.3)
	draw_line(c * Vector2(dir * length * 0.35, -length * 0.02), c * Vector2(dir * length * 0.5, -length * 0.28), edge * Color(1, 1, 1, 0.55), 1.0)


func _draw_flower(pos: Vector2, radius: float, soft: bool) -> void:
	# 主花：暖粉 / 双株时偏杏橙，像田里小花而非霓虹
	var petal := Color(0.90, 0.46, 0.56, 1.0) if not soft else Color(0.94, 0.60, 0.40, 1.0)
	var petal_inner := Color(0.98, 0.72, 0.70, 1.0) if not soft else Color(1.0, 0.78, 0.55, 1.0)
	var center := Color(1.0, 0.88, 0.42, 1.0)
	# 外圈花瓣
	for i in range(5):
		var a := float(i) * TAU / 5.0 + _phase * 0.12
		var p := pos + Vector2(cos(a), sin(a)) * radius * 0.58
		draw_circle(p, radius * 0.58, petal)
		draw_circle(p + Vector2(-0.8, -0.8), radius * 0.28, petal_inner)
	# 花心
	draw_circle(pos, radius * 0.44, center)
	draw_circle(pos, radius * 0.2, Color(0.82, 0.52, 0.18, 1.0))
	# 花萼
	draw_circle(pos + Vector2(0, radius * 0.55), radius * 0.22, Color(0.36, 0.58, 0.28, 1.0))


func _draw_sparkles(cx: float, cy: float) -> void:
	for i in range(5):
		var a := _sparkle_t * (1.15 + i * 0.18) + i * 1.55
		var ox := cos(a) * (16.0 + i * 3.5)
		var oy := sin(a * 1.25) * 9.0 - i * 2.2
		var alpha := 0.2 + 0.4 * (0.5 + 0.5 * sin(a * 2.0))
		var p := Vector2(cx + ox, cy + oy)
		# 小十字星，比纯圆更像像素闪光
		draw_circle(p, 1.4, Color(1.0, 0.95, 0.72, alpha))
		draw_line(p + Vector2(-2.5, 0), p + Vector2(2.5, 0), Color(1.0, 0.96, 0.78, alpha * 0.85), 1.0)
		draw_line(p + Vector2(0, -2.5), p + Vector2(0, 2.5), Color(1.0, 0.96, 0.78, alpha * 0.85), 1.0)


func _draw_ellipse(center: Vector2, radii: Vector2, color: Color) -> void:
	## Godot 4 无内建椭圆填充；用多边形近似。
	var pts := PackedVector2Array()
	var n := 16
	for i in range(n):
		var a := float(i) * TAU / float(n)
		pts.append(center + Vector2(cos(a) * radii.x, sin(a) * radii.y))
	draw_colored_polygon(pts, color)
