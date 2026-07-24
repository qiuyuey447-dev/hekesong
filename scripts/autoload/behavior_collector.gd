extends Node
## 行为采集器（XL-D1）：从玩家操作推断 prefs / persona / behavior_inferred。

const EVENING_RHYTHM_THRESHOLD := 3

var _evening_hits_this_week: int = 0
var _last_week_index: int = 0


func _ready() -> void:
	GameState.companion_world_event.connect(_on_world_event)
	GameState.day_advanced.connect(_on_day_advanced)
	GameState.time_changed.connect(_on_time_changed)
	GameState.stats_changed.connect(_on_stats_changed)
	call_deferred("_on_boot")


func _on_boot() -> void:
	GameState.apply_absence_since_last_play()
	GameState.touch_play_timestamp()
	_last_week_index = GameState.get_week_index()


func _on_day_advanced() -> void:
	GameState.touch_play_timestamp()
	if GameState.get_week_index() != _last_week_index:
		_evening_hits_this_week = 0
		_last_week_index = GameState.get_week_index()


func _on_time_changed(time_of_day: String) -> void:
	if time_of_day == GameState.TIME_EVENING:
		_evening_hits_this_week += 1
		if _evening_hits_this_week >= EVENING_RHYTHM_THRESHOLD:
			GameState.set_preference("time_rhythm", "dusk")
			GameState.drift_persona({"optimistic": 0.01})


func _on_stats_changed() -> void:
	pass


func _on_world_event(event_type: String, facts: Dictionary) -> void:
	match event_type:
		"player_planted", "companion_planted":
			_on_player_planted(facts)
		"player_harvested":
			_on_player_harvested(facts)
		"player_chat":
			_on_player_chat(str(facts.get("text", "")))
		"crop_became_ready":
			GameState.drift_persona({"active": 0.005})


func observe_trade_buy(item_id: String, price: int) -> void:
	GameState.increment_behavior_counter("buy_seed_count")
	if item_id == "turnip_seed":
		GameState.set_preference("fav_crop", GameState.CROP_TURNIP)
	var coins_before := GameState.coins + price
	if coins_before > 0 and float(price) / float(coins_before) > 0.35:
		GameState.drift_behavior_inferred({"risk": 0.04})
	GameState.drift_persona({"active": 0.01})


func observe_trade_sell(item_id: String, price: int) -> void:
	GameState.increment_behavior_counter("sell_count")
	if item_id == "turnip":
		var sell_price := GameState.get_turnip_sell_price()
		if price >= sell_price:
			GameState.drift_persona({"optimistic": 0.02})
		else:
			GameState.drift_behavior_inferred({"risk": -0.02})


func observe_companion_initiation(trigger: String, facts: Dictionary) -> void:
	GameState.record_initiation(trigger, facts)


func _on_player_planted(facts: Dictionary) -> void:
	var crop := str(facts.get("crop", GameState.CROP_TURNIP))
	GameState.increment_behavior_counter("plant_count")
	GameState.set_preference("fav_crop", crop)
	GameState.drift_persona({"active": 0.015, "optimistic": 0.01})


func _on_player_harvested(_facts: Dictionary) -> void:
	GameState.increment_behavior_counter("harvest_count")
	GameState.drift_persona({"optimistic": 0.02, "warm": 0.01})


func _on_player_chat(text: String) -> void:
	if text.is_empty():
		return
	if "慢慢来" in text or "不着急" in text:
		GameState.drift_persona({"warm": 0.03, "strict": -0.03})
	if "喜欢" in text and "萝卜" in text:
		GameState.set_preference("fav_crop", GameState.CROP_TURNIP)
		GameState.drift_persona({"warm": 0.02})
	if "忙" in text or "等会" in text or "稍后" in text:
		GameState.increment_player_busy()
	if "记得" in text or "记住" in text:
		GameState.drift_persona({"warm": 0.02, "dependent": 0.01})
