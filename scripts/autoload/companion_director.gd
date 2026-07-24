extends Node
## 小狸主动反应导演：监听世界变化，在合适时机触发 companion_react。

const HIGH_SELL_PRICE := 14
const IDLE_REACT_SECONDS := 30.0
const DAY_START_REACT_DELAY := 1.8

var _idle_seconds: float = 0.0
var _reacted_keys: Dictionary = {}
var _last_harvestable_count: int = 0
var _react_cooldown: float = 0.0
var last_react_type: String = ""


func _ready() -> void:
	GameState.time_changed.connect(_on_time_changed)
	GameState.day_advanced.connect(_on_day_advanced)
	GameState.market_changed.connect(_on_market_changed)
	GameState.stats_changed.connect(_on_stats_changed)
	GameState.companion_world_event.connect(_on_world_event)
	GameState.milestone_trigger.connect(_on_milestone_trigger)
	call_deferred("_sync_harvestable_baseline")


func _process(delta: float) -> void:
	if GameState.is_story_complete():
		return
	if _react_cooldown > 0.0:
		_react_cooldown = maxf(_react_cooldown - delta, 0.0)

	if TaskSystem.is_busy() or GameState.is_night():
		return

	_idle_seconds += delta
	if _idle_seconds >= IDLE_REACT_SECONDS:
		_idle_seconds = 0.0
		_try_react("world_idle_long", {})


func notify_player_active() -> void:
	_idle_seconds = 0.0


func _sync_harvestable_baseline() -> void:
	_last_harvestable_count = int(GameState.get_plot_summary().get("harvestable", 0))


func _on_world_event(event_type: String, facts: Dictionary) -> void:
	notify_player_active()
	match event_type:
		"player_planted":
			_try_react("player_planted", facts)
		"player_harvested":
			_try_react("player_harvested", facts)
		"player_chat":
			pass
		"crop_became_ready":
			_try_react("world_crop_ready", facts)


func _on_time_changed(time_of_day: String) -> void:
	_clear_period_limits()
	if time_of_day == GameState.TIME_EVENING:
		_try_react("world_evening", {})


func _on_day_advanced() -> void:
	_clear_period_limits()
	_idle_seconds = 0.0
	call_deferred("_deferred_day_start_reacts")


func _deferred_day_start_reacts() -> void:
	await get_tree().create_timer(DAY_START_REACT_DELAY).timeout
	_on_market_changed()
	_check_crop_ready()


func _on_milestone_trigger(milestone_id: String, facts: Dictionary) -> void:
	pass


func _on_market_changed() -> void:
	if GameState.get_turnip_sell_price() >= HIGH_SELL_PRICE:
		_try_react("world_price_surge", {
			"turnip_sell_price": GameState.get_turnip_sell_price(),
			"trend": str(GameState.market_state.get("trend", "stable")),
		})


func _on_stats_changed() -> void:
	_check_crop_ready()


func _check_crop_ready() -> void:
	var summary := GameState.get_plot_summary()
	var count := int(summary.get("harvestable", 0))
	if count > _last_harvestable_count:
		_try_react("world_crop_ready", {
			"harvestable": count,
			"plot_ids": summary.get("harvestable_plot_ids", []),
		})
	_last_harvestable_count = count


func _clear_period_limits() -> void:
	_reacted_keys.clear()


func _try_react(_react_type: String, _facts: Dictionary) -> void:
	pass
