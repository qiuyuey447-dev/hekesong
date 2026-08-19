extends Node

enum TaskType { NONE, WATER, HARVEST, SHOP, PLANT }

signal task_started(task_type: TaskType, label: String)
signal task_progress(seconds_left: float)
signal task_completed(task_type: TaskType, summary: String, game_facts: Dictionary)

var current_task: TaskType = TaskType.NONE
var _target_plot_ids: Array[int] = []


func is_busy() -> bool:
	reconcile_stale_task()
	return current_task != TaskType.NONE


func cancel_task() -> void:
	if current_task == TaskType.NONE:
		return
	CompanionAgent.cancel_current_job()
	current_task = TaskType.NONE
	_target_plot_ids.clear()


func cancel_from_agent() -> void:
	current_task = TaskType.NONE
	_target_plot_ids.clear()


func reconcile_stale_task() -> void:
	if current_task == TaskType.NONE:
		return
	CompanionAgent.reconcile_stuck_job()
	if CompanionAgent.has_current_job():
		return
	current_task = TaskType.NONE
	_target_plot_ids.clear()


func start_water_all_task() -> bool:
	return start_water_task(GameState.get_unwatered_growing_plot_ids())


func start_water_task(plot_ids: Array[int]) -> bool:
	if GameState.is_pure_narrative_day() or is_busy() or plot_ids.is_empty():
		return false
	if not CompanionAgent.start_water_job(plot_ids.duplicate()):
		return false

	current_task = TaskType.WATER
	_target_plot_ids = plot_ids.duplicate()
	task_started.emit(current_task, "小狸正在浇水…")
	return true


func start_harvest_all_task() -> bool:
	var summary := GameState.get_plot_summary()
	var plot_ids: Array = summary.get("harvestable_plot_ids", [])
	var ids: Array[int] = []
	if plot_ids is Array:
		for plot_id in plot_ids:
			ids.append(int(plot_id))
	return start_harvest_task(ids)


func start_harvest_task(plot_ids: Array[int]) -> bool:
	if GameState.is_pure_narrative_day() or is_busy() or plot_ids.is_empty():
		return false
	if not CompanionAgent.start_harvest_job(plot_ids.duplicate()):
		return false

	current_task = TaskType.HARVEST
	_target_plot_ids = plot_ids.duplicate()
	task_started.emit(current_task, "小狸正在收萝卜…")
	return true


func start_shop_task(auto_seed_flow: bool = false) -> bool:
	if GameState.is_pure_narrative_day() or is_busy():
		return false
	if not CompanionAgent.start_shop_job(auto_seed_flow):
		return false

	current_task = TaskType.SHOP
	_target_plot_ids.clear()
	var label := "小狸正在去商店买种子…" if auto_seed_flow else "小狸正在去商店…"
	task_started.emit(current_task, label)
	return true


func start_plant_all_task() -> bool:
	return start_plant_task(GameState.get_plantable_plot_ids())


func start_plant_task(plot_ids: Array[int]) -> bool:
	if GameState.is_pure_narrative_day() or is_busy() or plot_ids.is_empty():
		return false
	if not CompanionAgent.start_plant_job(plot_ids.duplicate()):
		return false

	current_task = TaskType.PLANT
	_target_plot_ids = plot_ids.duplicate()
	task_started.emit(current_task, "小狸正在种萝卜…")
	return true


func report_progress(seconds_left: float) -> void:
	if is_busy():
		task_progress.emit(seconds_left)


func skip_task() -> void:
	if not is_busy():
		return
	CompanionAgent.skip_current_job()


func complete_from_agent() -> void:
	if is_busy():
		_finish_task()


func _finish_task() -> void:
	var finished_task := current_task
	var summary := ""
	var game_facts := {}

	match finished_task:
		TaskType.WATER:
			summary = "小狸浇好了 %d 块田。" % _target_plot_ids.size()
			game_facts = {
				"task": "water",
				"plot_count": _target_plot_ids.size(),
				"plot_ids": _target_plot_ids.duplicate(),
				"game_day": GameState.game_day,
			}
			GameState.add_affection(3)
			GameState.add_bond(2)
			RelationshipDirector.record_task_together()
			GameState.set_mood(mini(GameState.mood + 5, 100))
			GameState.record_memory_event("task_water", summary, 0.55, game_facts)
		TaskType.HARVEST:
			summary = "小狸收好了 %d 块田的萝卜。" % _target_plot_ids.size()
			game_facts = {
				"task": "harvest",
				"plot_count": _target_plot_ids.size(),
				"plot_ids": _target_plot_ids.duplicate(),
				"game_day": GameState.game_day,
			}
			GameState.add_affection(2)
			GameState.add_bond(2)
			RelationshipDirector.record_task_together()
			GameState.set_mood(mini(GameState.mood + 4, 100))
			GameState.record_memory_event("task_harvest", summary, 0.55, game_facts)
		TaskType.SHOP:
			summary = "小狸到了商店，你可以看看想买什么。"
			game_facts = {"task": "shop", "game_day": GameState.game_day}
			GameState.add_bond(1)
		TaskType.PLANT:
			summary = "小狸种好了 %d 块田。" % _target_plot_ids.size()
			game_facts = {
				"task": "plant",
				"plot_count": _target_plot_ids.size(),
				"plot_ids": _target_plot_ids.duplicate(),
				"game_day": GameState.game_day,
			}
			GameState.add_affection(2)
			GameState.add_bond(2)
			RelationshipDirector.record_task_together()
			GameState.set_mood(mini(GameState.mood + 4, 100))
			GameState.record_memory_event("task_plant", summary, 0.55, game_facts)

	GameState.last_task_summary = summary
	current_task = TaskType.NONE
	_target_plot_ids.clear()
	task_completed.emit(finished_task, summary, game_facts)
	GameState.save_game()
