extends Node2D
## 昼夜染色 + 世界空间雨效 + 屏幕遮罩。

const OVERLAY_LAYER := 5

const RainWorldScript := preload("res://scripts/world/rain_world.gd")

var _modulate: CanvasModulate
var _overlay_layer: CanvasLayer
var _rain_world: Node2D
var _splash_root: Node2D
var _rain_dim: ColorRect
var _night_veil: ColorRect
var _tween: Tween
var _overlay_tween: Tween
var _layers_ready := false


func _ready() -> void:
	_ensure_modulate()
	call_deferred("_ensure_layers")
	GameState.atmosphere_changed.connect(_refresh)
	GameState.time_changed.connect(_refresh)
	GameState.day_advanced.connect(_refresh)


func _exit_tree() -> void:
	if _overlay_layer != null and is_instance_valid(_overlay_layer):
		_overlay_layer.queue_free()
	if _rain_world != null and is_instance_valid(_rain_world):
		_rain_world.queue_free()
	if _splash_root != null and is_instance_valid(_splash_root):
		_splash_root.queue_free()


func _ensure_layers() -> void:
	if _layers_ready:
		return
	var main := _get_main_root()
	if main == null:
		call_deferred("_ensure_layers")
		return

	var farm_world := get_tree().get_first_node_in_group("farm_world")
	var farm_map: Node2D = null
	if farm_world != null and farm_world.has_method("get_farm_map"):
		farm_map = farm_world.call("get_farm_map") as Node2D
	if farm_map == null:
		call_deferred("_ensure_layers")
		return

	var world_node := get_parent()

	var old_overlay := main.get_node_or_null("WeatherOverlayLayer")
	if old_overlay != null:
		old_overlay.queue_free()
	var old_star := main.get_node_or_null("WeatherStarLayer")
	if old_star != null:
		old_star.queue_free()

	if world_node != null:
		var old_rain := world_node.get_node_or_null("RainWorld")
		if old_rain != null:
			old_rain.queue_free()
	var old_rain_map := farm_map.get_node_or_null("RainWorld")
	if old_rain_map != null:
		old_rain_map.queue_free()
	var old_splash := farm_map.get_node_or_null("RainSplashes")
	if old_splash != null:
		old_splash.queue_free()

	_overlay_layer = CanvasLayer.new()
	_overlay_layer.name = "WeatherOverlayLayer"
	_overlay_layer.layer = OVERLAY_LAYER
	main.add_child(_overlay_layer)

	_rain_dim = _make_fullscreen_overlay(_overlay_layer, "RainDim")
	_night_veil = _make_fullscreen_overlay(_overlay_layer, "NightVeil")

	_splash_root = Node2D.new()
	_splash_root.name = "RainSplashes"
	_splash_root.y_sort_enabled = true
	farm_map.add_child(_splash_root)

	_rain_world = RainWorldScript.new()
	_rain_world.name = "RainWorld"
	if world_node != null:
		world_node.add_child(_rain_world)
	else:
		farm_map.add_child(_rain_world)
	if _rain_world.has_method("configure"):
		_rain_world.call("configure", _splash_root)

	_layers_ready = true
	_refresh(true)


func _get_main_root() -> Node:
	if get_tree().current_scene != null:
		return get_tree().current_scene
	var node: Node = self
	while node.get_parent() != null and node.get_parent() != get_tree().root:
		node = node.get_parent()
	return node


func _process(_delta: float) -> void:
	if not _layers_ready:
		return
	_sync_layout()


func _refresh(instant: bool = false) -> void:
	if not is_inside_tree():
		return
	if not _layers_ready:
		call_deferred("_ensure_layers")
		return

	_sync_layout()
	var target := GameState.get_atmosphere_color()
	RenderingServer.set_default_clear_color(GameState.get_clear_color())

	var raining := GameState.weather_today == GameState.WEATHER_RAIN
	var night := GameState.is_night()

	if _rain_world != null:
		if _rain_world.has_method("set_night_factor"):
			_rain_world.call("set_night_factor", 0.65 if night else 1.0)
		if _rain_world.has_method("set_raining"):
			_rain_world.call("set_raining", raining)

	_update_overlays(raining, night, instant)

	if _modulate == null:
		return
	if instant:
		_modulate.color = target
		return
	if _tween != null and _tween.is_valid():
		_tween.kill()
	_tween = create_tween()
	_tween.set_trans(Tween.TRANS_SINE).set_ease(Tween.EASE_IN_OUT)
	_tween.tween_property(_modulate, "color", target, 1.1)


func _sync_layout() -> void:
	var vp_size := get_viewport().get_visible_rect().size
	for rect in [_rain_dim, _night_veil]:
		if rect != null:
			rect.position = Vector2.ZERO
			rect.size = vp_size


func _update_overlays(raining: bool, night: bool, instant: bool) -> void:
	var rain_dim := Color(0, 0, 0, 0)
	if raining:
		rain_dim = Color(0.08, 0.12, 0.22, 0.22 if night else 0.14)

	var night_veil := Color(0, 0, 0, 0)
	if night:
		night_veil = Color(0.06, 0.08, 0.24, 0.28 if raining else 0.2)

	_apply_overlay(_rain_dim, rain_dim, instant)
	_apply_overlay(_night_veil, night_veil, instant)


func _apply_overlay(rect: ColorRect, target: Color, instant: bool) -> void:
	if rect == null:
		return
	rect.visible = target.a > 0.01
	if instant:
		rect.color = target
		return
	if _overlay_tween != null and _overlay_tween.is_valid():
		_overlay_tween.kill()
	_overlay_tween = create_tween()
	_overlay_tween.tween_property(rect, "color", target, 1.0)


func _ensure_modulate() -> void:
	_modulate = get_node_or_null("CanvasModulate") as CanvasModulate
	if _modulate == null:
		_modulate = CanvasModulate.new()
		_modulate.name = "CanvasModulate"
		add_child(_modulate)


func _make_fullscreen_overlay(parent: CanvasLayer, node_name: String) -> ColorRect:
	var rect := ColorRect.new()
	rect.name = node_name
	rect.mouse_filter = Control.MOUSE_FILTER_IGNORE
	rect.color = Color(0, 0, 0, 0)
	parent.add_child(rect)
	return rect
