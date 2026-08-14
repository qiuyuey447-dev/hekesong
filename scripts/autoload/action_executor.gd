extends Node
## 指令执行层（XL-B1）：将 IntentParser 输出转为游戏内行为。

signal action_executed(intent: Dictionary, result: Dictionary)


func execute(intent: Dictionary) -> Dictionary:
	if not IntentParser.is_action_intent(intent):
		return {"executed": false, "reason": "not_action"}

	var action := str(intent.get("intent", ""))
	if action != IntentParser.INTENT_CHECK_STATUS and action != IntentParser.INTENT_HELP:
		if TaskSystem.is_busy():
			return {"executed": false, "reason": "busy"}

	var result := {"executed": false, "reason": "unknown", "task_started": false}

	match action:
		IntentParser.INTENT_WATER:
			result = _execute_water(intent)
		IntentParser.INTENT_WATER_ALL:
			result = _execute_water_all()
		IntentParser.INTENT_HARVEST:
			result = _execute_harvest(intent)
		IntentParser.INTENT_HARVEST_ALL:
			result = _execute_harvest_all()
		IntentParser.INTENT_PLANT:
			result = _execute_plant(intent)
		IntentParser.INTENT_PLANT_ALL:
			result = _execute_plant_all()
		IntentParser.INTENT_OPEN_MARKET:
			result = _execute_open_market()
		IntentParser.INTENT_OPEN_SHOP:
			result = _execute_open_shop(intent)
		IntentParser.INTENT_OPEN_MEMORY:
			result = _execute_open_memory()
		IntentParser.INTENT_CHECK_STATUS:
			result = _execute_check_status()
		IntentParser.INTENT_HELP:
			result = _execute_help()
		IntentParser.INTENT_SLEEP:
			result = _execute_sleep()

	if bool(result.get("executed", false)):
		action_executed.emit(intent, result)
	return result


func _execute_water(intent: Dictionary) -> Dictionary:
	var plot_id := int(intent.get("plot_id", -1))
	if plot_id > 0:
		var plot := GameState.get_plot(plot_id)
		if int(plot.get("stage", 0)) <= 0:
			return {"executed": false, "reason": "plot_not_found"}
		if not _plot_needs_water(plot_id):
			if GameState.can_harvest(plot_id):
				return {"executed": false, "reason": "plot_not_growing"}
			return {"executed": false, "reason": "plot_already_watered"}
		if TaskSystem.start_water_task([plot_id]):
			return {"executed": true, "task_started": true, "plot_ids": [plot_id]}
		return {"executed": false, "reason": "busy"}

	return _execute_water_all()


func _execute_water_all() -> Dictionary:
	var plot_ids := GameState.get_unwatered_growing_plot_ids()
	if plot_ids.is_empty():
		var summary := GameState.get_plot_summary()
		var growing := int(summary.get("growing", 0))
		var harvestable := int(summary.get("harvestable", 0))
		if growing <= 0 and harvestable <= 0:
			return {"executed": false, "reason": "no_growing"}
		return {"executed": false, "reason": "no_plots"}
	if TaskSystem.start_water_task(plot_ids):
		return {"executed": true, "task_started": true, "plot_ids": plot_ids.duplicate()}
	return {"executed": false, "reason": "busy"}


func _execute_plant_all() -> Dictionary:
	var plot_ids := GameState.get_plantable_plot_ids()
	if plot_ids.is_empty():
		if int(GameState.get_item_count("turnip_seed")) <= 0:
			return {"executed": false, "reason": "no_seeds"}
		return {"executed": false, "reason": "no_empty_plots"}
	if TaskSystem.start_plant_task(plot_ids):
		return {"executed": true, "task_started": true, "plot_ids": plot_ids.duplicate()}
	return {"executed": false, "reason": "busy"}


func _execute_plant(intent: Dictionary) -> Dictionary:
	var plot_id := int(intent.get("plot_id", -1))
	if plot_id > 0:
		if int(GameState.get_plot(plot_id).get("stage", 0)) > 0:
			return {"executed": false, "reason": "plot_not_empty"}
		if int(GameState.get_item_count("turnip_seed")) <= 0:
			return {"executed": false, "reason": "no_seeds"}
		if TaskSystem.start_plant_task([plot_id]):
			return {"executed": true, "task_started": true, "plot_ids": [plot_id]}
		return {"executed": false, "reason": "busy"}

	var plot_ids := GameState.get_plantable_plot_ids()
	if plot_ids.is_empty():
		if int(GameState.get_item_count("turnip_seed")) <= 0:
			return {"executed": false, "reason": "no_seeds"}
		return {"executed": false, "reason": "no_empty_plots"}
	var target_id := plot_ids[0]
	if TaskSystem.start_plant_task([target_id]):
		return {"executed": true, "task_started": true, "plot_ids": [target_id]}
	return {"executed": false, "reason": "busy"}


func _execute_open_market() -> Dictionary:
	var sold := GameState.sell_all_turnips()
	return {
		"executed": true,
		"task_started": false,
		"sold": bool(sold.get("ok", false)),
		"companion_extra": str(sold.get("message", "")),
	}


func _execute_open_shop(intent: Dictionary) -> Dictionary:
	var raw := str(intent.get("raw_text", ""))
	var auto_seed := IntentParser.looks_like_shop_purchase(raw)
	if TaskSystem.start_shop_task(auto_seed):
		return {"executed": true, "task_started": true, "auto_seed_flow": auto_seed}
	return {"executed": false, "reason": "busy"}


func _execute_harvest(intent: Dictionary) -> Dictionary:
	if not PersonaGuard.can_delegate_harvest():
		return {"executed": false, "reason": "bond_harvest"}

	var plot_id := int(intent.get("plot_id", -1))
	if plot_id > 0:
		if not GameState.can_harvest(plot_id):
			return {"executed": false, "reason": "plot_not_harvestable"}
		if TaskSystem.start_harvest_task([plot_id]):
			return {"executed": true, "task_started": true, "plot_ids": [plot_id]}
		return {"executed": false, "reason": "busy"}

	var summary := GameState.get_plot_summary()
	var plot_ids: Array = summary.get("harvestable_plot_ids", [])
	if plot_ids.is_empty():
		return {"executed": false, "reason": "no_harvestable"}
	var target_id := int(plot_ids[0])
	if TaskSystem.start_harvest_task([target_id]):
		return {"executed": true, "task_started": true, "plot_ids": [target_id]}
	return {"executed": false, "reason": "busy"}


func _execute_harvest_all() -> Dictionary:
	if not PersonaGuard.can_delegate_harvest():
		return {"executed": false, "reason": "bond_harvest"}

	var summary := GameState.get_plot_summary()
	var plot_ids: Array = summary.get("harvestable_plot_ids", [])
	if plot_ids.is_empty():
		return {"executed": false, "reason": "no_harvestable"}
	var ids: Array[int] = []
	for plot_id in plot_ids:
		ids.append(int(plot_id))
	if TaskSystem.start_harvest_task(ids):
		return {"executed": true, "task_started": true, "plot_ids": ids.duplicate()}
	return {"executed": false, "reason": "busy"}


func _execute_open_memory() -> Dictionary:
	get_tree().call_group("main_ui", "open_memory_from_companion")
	return {"executed": true, "task_started": false, "opened_memory": true}


func _execute_check_status() -> Dictionary:
	var snapshot := WorldSnapshot.capture()
	var plots: Dictionary = snapshot.get("plots", {})
	var inventory: Dictionary = snapshot.get("inventory", {})
	var lines: PackedStringArray = []

	lines.append(
		"现在是%s的%s。" % [
			str(snapshot.get("weather_label", "晴天")),
			str(snapshot.get("time_label", "清晨")),
		]
	)

	var harvestable := int(plots.get("harvestable", 0))
	var unwatered := int(plots.get("unwatered_growing", 0))
	var growing := int(plots.get("growing", 0))

	if harvestable > 0:
		lines.append("有 %d 块田的萝卜可以收了。" % harvestable)
	if unwatered > 0 and str(snapshot.get("weather_today", "")) != GameState.WEATHER_RAIN:
		lines.append("还有 %d 块田今天没浇水。" % unwatered)
	elif growing > 0 and unwatered <= 0:
		lines.append("田里的萝卜都在长着，今天水够了。")
	if int(inventory.get("turnip", 0)) > 0:
		lines.append("背包里有 %d 个萝卜。" % int(inventory.get("turnip", 0)))

	return {
		"executed": true,
		"task_started": false,
		"companion_extra": " ".join(lines),
	}


func _execute_help() -> Dictionary:
	return {
		"executed": true,
		"task_started": false,
		"companion_extra": (
			"你可以让我：浇水、把田都浇了、种萝卜、把空田都种了、收萝卜、把萝卜都收了、"
			+ "去买种子、打开商店、翻本子、问田里怎么样、睡觉。"
			+ "筐里的萝卜要卖的话，跟我说一声，或者打开篮子。"
		),
	}


func _execute_sleep() -> Dictionary:
	if TaskSystem.is_busy():
		return {"executed": false, "reason": "busy"}
	get_tree().call_group("main_ui", "sleep_from_companion")
	return {"executed": true, "task_started": false, "advanced_day": true}


func _plot_needs_water(plot_id: int) -> bool:
	var plot := GameState.get_plot(plot_id)
	if int(plot.get("stage", 0)) <= 0:
		return false
	if GameState.can_harvest(plot_id):
		return false
	if plot_id in GameState.watered_plots or bool(plot.get("watered", false)):
		return false
	if GameState.weather_today == GameState.WEATHER_RAIN:
		return false
	return true
