extends Node
## 世界快照：小狸做决策时使用的只读事实包。

const COMPANION_PROFILE_PATH := "res://config/companion_profile.json"

var _companion_profile_cache: Dictionary = {}


func capture(extra: Dictionary = {}) -> Dictionary:
	var plots := GameState.get_plot_summary()
	var market := GameState.get_market_snapshot()
	return {
		"game_day": GameState.game_day,
		"week_index": GameState.get_week_index(),
		"loop_day": GameState.get_loop_day(),
		"weather_today": GameState.weather_today,
		"weather_label": GameState.get_weather_label(),
		"weather_tomorrow_hint": GameState.weather_tomorrow_hint,
		"weather_tomorrow_label": GameState.get_weather_label(GameState.weather_tomorrow_hint),
		"time_of_day": GameState.time_of_day,
		"time_label": GameState.get_time_label(),
		"market": market,
		"shop": GameState.get_shop_snapshot_for_llm(),
		"inventory": GameState.get_inventory_snapshot_for_llm(),
		"plots": plots,
		"plot_details": GameState.get_plot_details_for_llm(),
		"crops": {
			"turnip": {
				"mature_stage": GameState.MATURE_STAGE,
				"empty_plots": int(plots.get("empty", 0)),
				"growing_plots": int(plots.get("growing", 0)),
				"harvestable_plots": int(plots.get("harvestable", 0)),
				"unwatered_growing": int(plots.get("unwatered_growing", 0)),
			},
		},
		"relationship": {
			"affection": GameState.affection,
			"bond": GameState.bond,
			"mood": GameState.mood,
			"stage": GameState.get_stage(),
		},
		"story": StoryDirector.get_beat(),
		"story_mode": StoryDirector.get_story_mode(),
		"last_task_summary": GameState.last_task_summary,
		"companion": _capture_companion_snapshot(),
		"companion_profile": get_companion_profile(),
		"react_type": str(extra.get("react_type", "")),
		"react_facts": extra.get("react_facts", {}).duplicate(true),
	}


func get_companion_profile() -> Dictionary:
	if _companion_profile_cache.is_empty():
		_companion_profile_cache = _load_companion_profile()
	return _companion_profile_cache.duplicate(true)


func _capture_companion_snapshot() -> Dictionary:
	var profile := get_companion_profile()
	var snap := CompanionAgent.get_snapshot()
	var movement: Dictionary = {}
	var movement_raw: Variant = profile.get("movement", {})
	if movement_raw is Dictionary:
		movement = movement_raw
	var caps: Variant = profile.get("capabilities", [])
	if caps is Array:
		snap["capabilities"] = caps.duplicate()
	else:
		snap["capabilities"] = [
			"water", "water_all", "plant", "plant_all", "harvest", "harvest_all",
			"open_shop", "open_market", "open_memory", "check_status", "help", "sleep",
		]
	var blocked: Variant = profile.get("cannot_delegate", ["sell"])
	if blocked is Array:
		snap["cannot_delegate"] = blocked.duplicate()
	snap["can_water"] = PersonaGuard.can_delegate_water()
	snap["can_harvest"] = PersonaGuard.can_delegate_harvest()
	snap["is_busy"] = TaskSystem.is_busy()
	snap["moves_on_map"] = true
	snap["walks_to_target"] = bool(movement.get("walks_to_target_on_command", true))
	snap["movement"] = {
		"wander_speed": float(movement.get("wander_speed", 36.0)),
		"task_speed": float(movement.get("task_speed", 92.0)),
		"idle_behaviors": movement.get("idle_behaviors", ["stand", "wander"]),
	}
	snap["command_examples"] = profile.get("command_examples", [])
	snap["animations"] = profile.get("animations", {})
	return snap


func _load_companion_profile() -> Dictionary:
	if not FileAccess.file_exists(COMPANION_PROFILE_PATH):
		return {}
	var parsed: Variant = JSON.parse_string(FileAccess.get_file_as_string(COMPANION_PROFILE_PATH))
	if parsed is Dictionary:
		return parsed
	return {}
