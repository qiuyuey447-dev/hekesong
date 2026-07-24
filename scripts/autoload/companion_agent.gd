extends Node
## 小狸移动与任务执行：随机漫游、走到目标点、上报位置给 LLM。

signal location_changed(snapshot: Dictionary)

const WORK_DURATION := 5.0
const SHOP_WORK_DURATION := 2.5
const IDLE_WANDER_MIN := 5.0
const IDLE_WANDER_MAX := 10.0
const IDLE_STAND_MIN := 4.0
const IDLE_STAND_MAX := 10.0
const IDLE_STAND_CHANCE := 0.42
const ARRIVE_DISTANCE := 6.0

enum Activity { IDLE, WALKING, WORKING }

var _companion: Node2D
var _visual: Node
var _plot_positions: Dictionary = {}
var _shop_position := Vector2.ZERO
var _field_center := Vector2.ZERO
var _path_waypoints: Array[Vector2] = []
var _pois: Array[Dictionary] = []

var _activity := Activity.IDLE
var _activity_label := "闲逛"
var _location_id := "path"
var _location_name := "小径"
var _current_job: Dictionary = {}
var _idle_cooldown := 3.0
var _idle_stand_left := 0.0
var _work_left := 0.0
var _ready := false
var _snuggle_paused := false


func setup(
	companion: Node2D,
	plot_positions: Dictionary,
	shop_position: Vector2,
	path_waypoints: Array[Vector2]
) -> void:
	_companion = companion
	_visual = companion
	_plot_positions = plot_positions.duplicate(true)
	_shop_position = shop_position
	_path_waypoints = path_waypoints.duplicate()
	_field_center = _compute_field_center()
	_pois = _build_pois()
	_ready = _companion != null
	_update_location_from_position()
	location_changed.emit(get_snapshot())


func is_active() -> bool:
	return _activity != Activity.IDLE or not _current_job.is_empty()


func set_snuggle_paused(paused: bool) -> void:
	_snuggle_paused = paused
	if not paused:
		return
	if _visual != null and _visual.has_method("cancel_move"):
		_visual.cancel_move()
	if _visual != null and _visual.has_method("hide_status_bubble"):
		_visual.hide_status_bubble()
	_set_activity(Activity.IDLE, "依偎")


func get_snapshot() -> Dictionary:
	var pos := Vector2.ZERO
	if _companion != null:
		pos = _companion.global_position
	return {
		"position": {"x": snappedf(pos.x, 0.1), "y": snappedf(pos.y, 0.1)},
		"location_id": _location_id,
		"location_name": _location_name,
		"activity": _activity_label,
		"state": Activity.keys()[_activity],
		"near_plot_id": _nearest_plot_id(pos),
	}


func start_water_job(plot_ids: Array[int]) -> bool:
	return _start_field_job("water", plot_ids, "浇水")


func start_harvest_job(plot_ids: Array[int]) -> bool:
	return _start_field_job("harvest", plot_ids, "收萝卜")


func start_plant_job(plot_ids: Array[int]) -> bool:
	return _start_field_job("plant", plot_ids, "种萝卜")


func start_shop_job(auto_seed_flow: bool = false) -> bool:
	if not _prepare_for_job():
		return false
	_current_job = {
		"kind": "shop",
		"open_ui": not auto_seed_flow,
		"auto_seed_flow": auto_seed_flow,
	}
	var bubble := "小狸正在前往商店买种子…" if auto_seed_flow else "小狸正在前往商店…"
	_walk_to_target(_shop_position, "前往商店", bubble, func() -> void:
		var work_bubble := "小狸正在挑选种子…" if auto_seed_flow else "小狸正在挑选商品…"
		var work_label := "挑选种子" if auto_seed_flow else "挑选商品"
		_begin_work(work_label, SHOP_WORK_DURATION, work_bubble)
	)
	return true


func _start_field_job(kind: String, plot_ids: Array[int], work_label: String) -> bool:
	if plot_ids.is_empty():
		return false
	if not _prepare_for_job():
		return false
	_current_job = {
		"kind": kind,
		"plot_ids": plot_ids.duplicate(),
		"index": 0,
		"work_label": work_label,
	}
	_advance_field_job()
	return true


func _advance_field_job() -> void:
	var plot_ids: Array = _current_job.get("plot_ids", [])
	var index := int(_current_job.get("index", 0))
	while index < plot_ids.size() and _should_skip_field_step(int(plot_ids[index])):
		index += 1
	_current_job["index"] = index
	if index >= plot_ids.size():
		_finish_job()
		return

	var plot_id := int(plot_ids[index])
	var target: Vector2 = _plot_positions.get(plot_id, _field_center)
	var kind := str(_current_job.get("kind", ""))
	var dest := "萝卜田" if kind in ["harvest", "plant"] else "田地"
	var bubble_travel := "小狸正在前往%s…" % dest
	_walk_to_target(target, "前往%s" % dest, bubble_travel, func() -> void:
		var work_text := "小狸正在%s…" % str(_current_job.get("work_label", "帮忙"))
		_begin_work(str(_current_job.get("work_label", "帮忙")), WORK_DURATION, work_text)
	)


func _walk_to_target(
	target: Vector2,
	travel_label: String,
	bubble_text: String,
	on_arrived: Callable,
	urgent: bool = true
) -> void:
	_set_activity(Activity.WALKING, travel_label)
	if _visual != null and _visual.has_method("show_status_bubble"):
		_visual.show_status_bubble(bubble_text)
	if _visual != null and _visual.has_method("move_to"):
		_visual.move_to(target, ARRIVE_DISTANCE, on_arrived, urgent)
	else:
		if _companion != null:
			_companion.global_position = target
		on_arrived.call()


func _begin_work(label: String, duration: float, bubble_text: String) -> void:
	_set_activity(Activity.WORKING, label)
	_work_left = duration
	if _visual != null and _visual.has_method("play_stand_still"):
		_visual.play_stand_still()
	if _visual != null and _visual.has_method("show_status_bubble"):
		_visual.show_status_bubble(bubble_text)


func _finish_work_step() -> void:
	var kind := str(_current_job.get("kind", ""))
	match kind:
		"water":
			var plot_ids: Array = _current_job.get("plot_ids", [])
			var index := int(_current_job.get("index", 0))
			if index < plot_ids.size():
				GameState.mark_plot_watered(int(plot_ids[index]))
			_current_job["index"] = index + 1
			if int(_current_job.get("index", 0)) >= plot_ids.size():
				_finish_job()
			else:
				_advance_field_job()
		"harvest":
			var plot_ids: Array = _current_job.get("plot_ids", [])
			var index := int(_current_job.get("index", 0))
			if index < plot_ids.size():
				var plot_id := int(plot_ids[index])
				if GameState.can_harvest(plot_id):
					GameState.harvest_turnip(plot_id)
			_current_job["index"] = index + 1
			if int(_current_job.get("index", 0)) >= plot_ids.size():
				_finish_job()
			else:
				_advance_field_job()
		"plant":
			var plot_ids: Array = _current_job.get("plot_ids", [])
			var index := int(_current_job.get("index", 0))
			if index < plot_ids.size():
				GameState.plant_turnip(int(plot_ids[index]), true)
			_current_job["index"] = index + 1
			if int(_current_job.get("index", 0)) >= plot_ids.size():
				_finish_job()
			else:
				_advance_field_job()
		"shop":
			var should_open := bool(_current_job.get("open_ui", false))
			var auto_seed := bool(_current_job.get("auto_seed_flow", false))
			_finish_job()
			if should_open:
				call_deferred("_deferred_open_shop")
			elif auto_seed:
				call_deferred("_deferred_begin_seed_purchase")
		_:
			_finish_job()


func _deferred_open_shop() -> void:
	get_tree().call_group("main_ui", "open_shop_from_companion")


func _deferred_begin_seed_purchase() -> void:
	get_tree().call_group("main_ui", "begin_companion_seed_purchase")


func _prepare_for_job() -> bool:
	if not _ready:
		return false
	if not _current_job.is_empty() or TaskSystem.is_busy():
		return false
	if _activity == Activity.WORKING:
		return false
	if _activity == Activity.WALKING:
		if _visual != null and _visual.has_method("cancel_move"):
			_visual.cancel_move()
		if _visual != null and _visual.has_method("hide_status_bubble"):
			_visual.hide_status_bubble()
		_set_activity(Activity.IDLE, "待命")
	return true


func skip_current_job() -> void:
	if _current_job.is_empty() and _activity == Activity.IDLE:
		return

	if _visual != null and _visual.has_method("cancel_move"):
		_visual.cancel_move()

	var kind := str(_current_job.get("kind", ""))
	var open_shop_after := false
	match kind:
		"water":
			for plot_id in _remaining_plot_ids():
				GameState.mark_plot_watered(int(plot_id))
		"harvest":
			for plot_id in _remaining_plot_ids():
				var pid := int(plot_id)
				if GameState.can_harvest(pid):
					GameState.harvest_turnip(pid)
		"plant":
			for plot_id in _remaining_plot_ids():
				GameState.plant_turnip(int(plot_id), true)
		"shop":
			open_shop_after = bool(_current_job.get("open_ui", false))
			if bool(_current_job.get("auto_seed_flow", false)):
				call_deferred("_deferred_begin_seed_purchase")

	_finish_job()
	if open_shop_after:
		call_deferred("_deferred_open_shop")


func _should_skip_field_step(plot_id: int) -> bool:
	var kind := str(_current_job.get("kind", ""))
	match kind:
		"water":
			var plot := GameState.get_plot(plot_id)
			if int(plot.get("stage", 0)) <= 0:
				return true
			if plot_id in GameState.watered_plots or bool(plot.get("watered", false)):
				return true
			return GameState.weather_today == GameState.WEATHER_RAIN
		"harvest":
			return not GameState.can_harvest(plot_id)
		"plant":
			return not GameState.can_plant_turnip(plot_id)
		_:
			return false


func _remaining_plot_ids() -> Array:
	var plot_ids: Array = _current_job.get("plot_ids", [])
	var index := int(_current_job.get("index", 0))
	var remaining: Array = []
	for i in range(index, plot_ids.size()):
		remaining.append(plot_ids[i])
	return remaining


func _finish_job() -> void:
	var had_job := not _current_job.is_empty()
	_current_job = {}
	_work_left = 0.0
	_set_activity(Activity.IDLE, "闲逛")
	if _visual != null and _visual.has_method("hide_status_bubble"):
		_visual.hide_status_bubble()
	_idle_cooldown = randf_range(IDLE_WANDER_MIN, IDLE_WANDER_MAX)
	if had_job:
		TaskSystem.complete_from_agent()


func _process(delta: float) -> void:
	if not _ready or _companion == null:
		return
	if _snuggle_paused:
		return

	_update_location_from_position()

	if _activity == Activity.WORKING:
		_work_left = maxf(_work_left - delta, 0.0)
		TaskSystem.report_progress(_work_left)
		if _work_left <= 0.0:
			_finish_work_step()
		return

	if _activity == Activity.WALKING:
		return

	if not _current_job.is_empty() or TaskSystem.is_busy():
		return

	if _idle_stand_left > 0.0:
		_idle_stand_left = maxf(_idle_stand_left - delta, 0.0)
		if _idle_stand_left <= 0.0:
			_idle_cooldown = randf_range(IDLE_WANDER_MIN, IDLE_WANDER_MAX)
		return

	_idle_cooldown -= delta
	if _idle_cooldown <= 0.0:
		_pick_idle_behavior()


func _pick_idle_behavior() -> void:
	_idle_cooldown = randf_range(IDLE_WANDER_MIN, IDLE_WANDER_MAX)
	if randf() < IDLE_STAND_CHANCE:
		_idle_stand_left = randf_range(IDLE_STAND_MIN, IDLE_STAND_MAX)
		_set_activity(Activity.IDLE, "发呆")
		if _visual != null and _visual.has_method("play_stand_still"):
			_visual.play_stand_still()
		return
	_wander_random()


func _wander_random() -> void:
	if _path_waypoints.is_empty():
		return
	var target := _path_waypoints[randi() % _path_waypoints.size()]
	if _companion.global_position.distance_to(target) < 24.0:
		return
	_walk_to_target(target, "闲逛", "", func() -> void:
		_set_activity(Activity.IDLE, "闲逛")
		if _visual != null and _visual.has_method("hide_status_bubble"):
			_visual.hide_status_bubble()
	, false)


func _set_activity(activity: Activity, label: String) -> void:
	_activity = activity
	_activity_label = label
	location_changed.emit(get_snapshot())


func _update_location_from_position() -> void:
	if _companion == null:
		return
	var pos := _companion.global_position
	var best_id := "path"
	var best_name := "小径"
	var best_dist := INF
	for poi in _pois:
		var poi_pos: Vector2 = poi.get("pos", Vector2.ZERO)
		var radius := float(poi.get("radius", 80.0))
		var dist := pos.distance_to(poi_pos)
		if dist <= radius and dist < best_dist:
			best_dist = dist
			best_id = str(poi.get("id", "path"))
			best_name = str(poi.get("name", "小径"))
	_location_id = best_id
	_location_name = best_name


func _nearest_plot_id(pos: Vector2) -> int:
	var best_id := -1
	var best_dist := 120.0
	for plot_id in _plot_positions.keys():
		var plot_pos: Vector2 = _plot_positions[plot_id]
		var dist := pos.distance_to(plot_pos)
		if dist < best_dist:
			best_dist = dist
			best_id = int(plot_id)
	return best_id


func _compute_field_center() -> Vector2:
	if _plot_positions.is_empty():
		return Vector2(272, 412)
	var sum := Vector2.ZERO
	for plot_id in _plot_positions.keys():
		var plot_pos: Vector2 = _plot_positions[plot_id]
		sum += plot_pos
	return sum / float(_plot_positions.size())


func _build_pois() -> Array[Dictionary]:
	return [
		{"id": "home", "name": "家门口", "pos": Vector2(266, 215), "radius": 90.0},
		{"id": "shop", "name": "商店", "pos": _shop_position, "radius": 110.0},
		{"id": "field", "name": "萝卜田", "pos": _field_center, "radius": 150.0},
		{"id": "camp", "name": "营地", "pos": Vector2(520, 180), "radius": 85.0},
		{"id": "pond", "name": "池塘", "pos": Vector2(160, 620), "radius": 95.0},
		{"id": "log", "name": "空心树桩", "pos": Vector2(480, 380), "radius": 75.0},
		{"id": "waterfall", "name": "瀑布边", "pos": Vector2(1180, 140), "radius": 90.0},
	]
