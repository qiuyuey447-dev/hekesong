extends Node

signal stats_changed
signal day_advanced
signal debug_awakening_requested
signal market_changed
signal week_reset(week_index: int)
signal memory_changed
signal time_changed(time_of_day: String)
signal atmosphere_changed
signal companion_world_event(event_type: String, facts: Dictionary)
signal milestone_trigger(milestone_id: String, facts: Dictionary)

const STAGE_STRANGER := "stranger"
const STAGE_FAMILIAR := "familiar"
const STAGE_BOND := "bond"
## 剧情分支档位（Phase 1）：S0 远 / S1 近 / S2 贴
const AFFECTION_TIER_COLD := "S0"
const AFFECTION_TIER_MID := "S1"
const AFFECTION_TIER_WARM := "S2"
const AFFECTION_TIER_MID_MIN := 25
const AFFECTION_TIER_WARM_MIN := 55
const MILESTONE_AFFECTION_FAMILIAR := 30
const MILESTONE_AFFECTION_BOND := 60
const MILESTONE_TRADE_BIG_WIN_PRICE := 15
const MILESTONE_TRADE_LOW_COINS := 15
const MILESTONE_TRADE_RISKY_BUY_RATIO := 0.45
const ABSENCE_MIN_GAP_HOURS := 2
## 十日完整版：总天数 10；STORY_WEEKS 仅作旧周逻辑兼容，周结算在十日版关闭。
const STORY_WEEKS := 2
const FINAL_GAME_DAY := 10
const IS_TEN_DAY_EDITION := true
const CROP_TURNIP := "turnip"
const MATURE_STAGE := 3
const SAVE_VERSION := 2
const SAVE_FILE_NAME := "save_game.json"
## 仅用于迁移：曾用显示名对应的 userdata 目录（当前目录由 project.godot config/name 固定）
const LEGACY_USER_DIRS := ["去你的岛", "hekesong"]
const GAME_DISPLAY_NAME := "去狸的岛"
const GAME_SUBTITLE := "十日完整故事"
const GAME_PITCH := "十天里，一只会忘事的狐狸试图记住你——而你会发现，需要被反复认回的也不只是她。"

const WEATHER_SUN := "sun"
const WEATHER_RAIN := "rain"
const WEATHER_ORDER := [WEATHER_SUN, WEATHER_RAIN]
const WEATHER_LABELS := {
	WEATHER_SUN: "晴天",
	WEATHER_RAIN: "雨天",
}
# 十日版：D2 雨天廊下强制雨天。
const STORY_RAIN_DAYS: Array[int] = [2]
const WEATHER_RAIN_CHANCE := 0.38

const TIME_MORNING := "morning"
const TIME_NOON := "noon"
const TIME_EVENING := "evening"
const TIME_NIGHT := "night"
const TIME_ORDER := [TIME_MORNING, TIME_NOON, TIME_EVENING, TIME_NIGHT]
const TIME_LABELS := {
	TIME_MORNING: "白天",
	TIME_NOON: "白天",
	TIME_EVENING: "傍晚",
	TIME_NIGHT: "夜晚",
}
## 一日总时长（秒）：白天 1 · 傍晚 0.5 · 夜晚 1 → 72s / 36s / 72s。
const DAY_CYCLE_SECONDS := 180.0
const PERIOD_WEIGHT_DAY := 1.0
const PERIOD_WEIGHT_EVENING := 0.5
const PERIOD_WEIGHT_NIGHT := 1.0
const PERIOD_WEIGHT_SUM := PERIOD_WEIGHT_DAY + PERIOD_WEIGHT_EVENING + PERIOD_WEIGHT_NIGHT
const PLAYABLE_TIME_ORDER := [TIME_MORNING, TIME_EVENING, TIME_NIGHT]

signal sleep_prompt_requested

var player_name: String = ""
var companion_name: String = "小狸"
var game_day: int = 1
var affection: int = 0
var bond: int = 0
var mood: int = 80
var coins: int = 80

var weather_today: String = WEATHER_SUN
var weather_tomorrow_hint: String = WEATHER_RAIN
var weather_seed: int = 0
const AUDIO_PREFS_PATH := "user://audio_prefs.json"
var bgm_volume_linear: float = 1.0
var ambient_volume_linear: float = 1.0
var time_of_day: String = TIME_MORNING
var _period_elapsed: float = 0.0
var _awaiting_sleep: bool = false
var _time_pause_depth: int = 0
var watered_plots: Array[int] = []
var inventory: Dictionary = {
	"turnip_seed": 5,
	"turnip": 0,
}
var plot_data: Dictionary = {}
var farm_plot_count: int = 0
var last_task_summary: String = ""
var last_day_summary: String = ""

var market_state: Dictionary = {
	"turnip_seed_price": 8,
	"turnip_sell_price": 12,
	"trend": "stable",
}

var short_term_memory: Array[Dictionary] = []
var recent_chat_turns: Array[Dictionary] = []
const MAX_CHAT_TURNS := 48
const MAX_TODAY_CHAT := 32
const MAX_ARCHIVED_CHAT_DAYS := 9
var today_chat_log: Array[Dictionary] = []
var feeds_today: int = 0
var feed_pester_count: int = 0
var today_feed_replies: Array[String] = []
var today_water_by_player: int = 0
var today_water_by_companion: int = 0
var day_journal: Array[Dictionary] = []
var long_term_memory: Dictionary = {
	"prefs": {
		"fav_crop": CROP_TURNIP,
		"time_rhythm": "",
	},
	"persona": {
		"warm": 0.5,
		"strict": 0.5,
		"active": 0.5,
		"optimistic": 0.5,
		"dependent": 0.5,
	},
	"behavior_inferred": {
		"risk": 0.5,
		"coping": "neutral",
		"absence_days": 0,
	},
	"initiations": [],
	"absence_notes": [],
	"player_busy": 0,
	"counters": {
		"plant_count": 0,
		"harvest_count": 0,
		"sell_count": 0,
		"buy_seed_count": 0,
	},
	"last_play_unix": 0,
	"anchors": [],
	"week_summaries": [],
	"promise": {},
	"revealed": false,
	"w2_stranger_seen": false,
	"awakening_seen": false,
	"memory_recovery": 0.0,
	"memory_fragments": [],
	"story_complete": false,
	"final_ending_id": "",
	"endings_seen": [],
	"story_nodes_seen": [],
	"story_route": "",
	"relationship_signals": {
		"chat_turns": 0,
		"chat_days": 0,
		"last_chat_day": 0,
		"gifts_given": 0,
		"nodes_cleared": 0,
		"tasks_together": 0,
		"llm_affection_net": 0,
		"llm_bond_net": 0,
		"beat_chats": 0,
	},
	"ending_flags": {
		"w2_chose_keep": true,
		"w2_chose_expel": false,
		"companionship_nights": 0,
		"w2_choice_made": false,
		"f10_skipped": false,
	},
}


func get_about_dialog_text() -> String:
	var lines: PackedStringArray = [
		"%s · %s" % [GAME_DISPLAY_NAME, GAME_SUBTITLE],
		"",
		GAME_PITCH,
		"",
		"与 AI 伙伴小狸一起种田、聊天、留下约定；她会忘记你，也会在雾里慢慢认出你。多结局。",
		"",
		"· 联网时可走 AI 对话；断网时仍有完整固定剧本可通关。",
		"· 第四天起小狸会「陌生化」——这是设定，不是存档坏了。",
	]
	return "\n".join(lines)


func _ready() -> void:
	ensure_save_migrated()
	load_game()
	_load_audio_prefs()
	_ensure_runtime_defaults()
	atmosphere_changed.emit()


func _process(delta: float) -> void:
	if is_story_complete():
		return
	if _awaiting_sleep:
		return
	if not is_time_paused():
		_period_elapsed += delta
	StoryBeatDirector.check_schedule()
	if is_time_paused():
		return
	if _period_elapsed < get_period_seconds():
		return
	_period_elapsed = 0.0
	if time_of_day == TIME_NIGHT:
		StoryBeatDirector.check_schedule()
		_awaiting_sleep = true
		sleep_prompt_requested.emit()
		stats_changed.emit()
		save_game()
		return
	advance_time_period()


func get_stage() -> String:
	if affection >= 60:
		return STAGE_BOND
	if affection >= 30:
		return STAGE_FAMILIAR
	return STAGE_STRANGER


func get_affection_tier() -> String:
	if affection >= AFFECTION_TIER_WARM_MIN:
		return AFFECTION_TIER_WARM
	if affection >= AFFECTION_TIER_MID_MIN:
		return AFFECTION_TIER_MID
	return AFFECTION_TIER_COLD


func chatted_today() -> bool:
	if not today_chat_log.is_empty():
		return true
	var signals: Variant = long_term_memory.get("relationship_signals", {})
	if signals is Dictionary:
		return int(signals.get("last_chat_day", 0)) == game_day
	return false


func get_loop_day() -> int:
	return ((game_day - 1) % 7) + 1


func get_week_index() -> int:
	return int((game_day - 1) / 7) + 1


const NAME_RECALL_NODES := ["NM_N16", "HP_N16", "TR_N16", "BL_N16", "BE_N16"]


func has_player_name_set() -> bool:
	return bool(long_term_memory.get("player_name_set", false)) and player_name.strip_edges() != ""


func get_player_display_name() -> String:
	if has_player_name_set():
		return player_name.strip_edges()
	return "你"


func set_player_display_name(name: String) -> void:
	var cleaned := name.strip_edges()
	if cleaned.is_empty():
		return
	if cleaned.length() > 12:
		cleaned = cleaned.substr(0, 12)
	player_name = cleaned
	long_term_memory["player_name_set"] = true
	record_memory_event(
		"name_set",
		"你告诉%s可以叫你「%s」" % [companion_name, player_name],
		0.9,
		{"player_name": player_name, "node": "N01", "game_day": game_day}
	)
	memory_changed.emit()
	save_game()


func get_player_name_for_llm() -> String:
	if companion_knows_player_name():
		return player_name.strip_edges()
	return ""


func companion_knows_player_name() -> bool:
	if not has_player_name_set():
		return false
	if has_revealed_memory():
		return true
	if IS_TEN_DAY_EDITION:
		if game_day <= 3:
			return true
		if game_day <= 6:
			return false
		return has_name_recall_unlocked() or game_day >= 7
	var week := get_week_index()
	if week == 1:
		return true
	if week == 2 and not has_revealed_memory():
		return false
	if week == 3 and not has_revealed_memory():
		return false
	if week >= 4 or has_revealed_memory():
		return true
	return false


func companion_can_say_player_name() -> bool:
	if not has_player_name_set():
		return false
	if StoryDirector.is_stranger_mode():
		return false
	if IS_TEN_DAY_EDITION:
		if game_day <= 3:
			return true
		return has_name_recall_unlocked()
	var week := get_week_index()
	if week == 1:
		return true
	if week == 2 or week == 3:
		return false
	return has_name_recall_unlocked()


func has_name_recall_unlocked() -> bool:
	if has_revealed_memory():
		return true
	for node_id in NAME_RECALL_NODES:
		if is_story_node_seen(node_id):
			return true
	if IS_TEN_DAY_EDITION:
		return game_day >= 7 and bool(get_ending_flags().get("w2_chose_keep", false))
	if get_week_index() >= 5:
		return true
	if get_week_index() >= 4 and game_day >= 22:
		return true
	return false


func get_player_name_context() -> Dictionary:
	var stored := player_name.strip_edges() if has_player_name_set() else ""
	var knows := companion_knows_player_name()
	var can_say := companion_can_say_player_name()
	return {
		"player_name_set": has_player_name_set(),
		"stored_name": stored,
		"player_name": stored if knows else "",
		"companion_knows_name": knows,
		"companion_can_say_name": can_say,
		"name_recall_unlocked": has_name_recall_unlocked(),
		"display_fallback": get_player_display_name(),
	}


func get_weather_label(weather: String = weather_today) -> String:
	return str(WEATHER_LABELS.get(weather, "未知天气"))


func get_time_label(time_key: String = time_of_day) -> String:
	return str(TIME_LABELS.get(time_key, "未知时段"))


func get_day_period_label() -> String:
	## 玩家可见：第 X 天 · 白天 / 傍晚 / 夜晚
	return "第 %d 天 · %s" % [game_day, get_time_label()]


func get_time_context_for_llm() -> Dictionary:
	## 传给 LLM 的局内日历/时段事实（与 HUD 一致）。
	return {
		"game_day": game_day,
		"time_of_day": time_of_day,
		"time_label": get_time_label(),
		"day_period_label": get_day_period_label(),
		"awaiting_sleep": _awaiting_sleep,
		"can_manual_sleep": can_manual_sleep(),
	}


func get_period_elapsed() -> float:
	return _period_elapsed


func get_period_seconds(time_key: String = time_of_day) -> float:
	var weight := PERIOD_WEIGHT_DAY
	match time_key:
		TIME_EVENING:
			weight = PERIOD_WEIGHT_EVENING
		TIME_NIGHT:
			weight = PERIOD_WEIGHT_NIGHT
		TIME_NOON:
			weight = PERIOD_WEIGHT_DAY
	return DAY_CYCLE_SECONDS * weight / PERIOD_WEIGHT_SUM


func is_awaiting_sleep() -> bool:
	return _awaiting_sleep


func push_time_pause() -> void:
	_time_pause_depth += 1


func pop_time_pause() -> void:
	_time_pause_depth = maxi(_time_pause_depth - 1, 0)


func is_time_paused() -> bool:
	return _time_pause_depth > 0


func can_manual_sleep() -> bool:
	return time_of_day == TIME_NIGHT or _awaiting_sleep


func notify_sleep_sequence_started() -> void:
	_awaiting_sleep = false
	_period_elapsed = 0.0


func is_night() -> bool:
	return time_of_day == TIME_NIGHT


func get_weather_effect_text() -> String:
	match weather_today:
		WEATHER_SUN:
			return "晴天：萝卜正常生长，记得浇水。"
		WEATHER_RAIN:
			return "雨天：自动补水，萝卜更容易成长，天色也会变暗。"
		_:
			return ""


func get_time_tint() -> Color:
	match time_of_day:
		TIME_MORNING:
			return Color(1.0, 0.96, 0.9)
		TIME_NOON:
			return Color(1.0, 1.0, 0.98)
		TIME_EVENING:
			return Color(1.0, 0.78, 0.58)
		TIME_NIGHT:
			return Color(0.38, 0.42, 0.78)
		_:
			return Color.WHITE


func get_weather_tint() -> Color:
	if weather_today == WEATHER_RAIN:
		return Color(0.55, 0.62, 0.76)
	return Color(1.0, 1.0, 1.0)


func get_atmosphere_color() -> Color:
	return get_time_tint() * get_weather_tint()


func get_clear_color() -> Color:
	var sky_day := Color(0.58, 0.76, 0.96)
	var sky_night := Color(0.1, 0.12, 0.28)
	var sky_rain := Color(0.42, 0.5, 0.62)
	var base := sky_day
	if is_night():
		base = sky_night
	elif weather_today == WEATHER_RAIN:
		base = sky_rain
	return base.lerp(get_atmosphere_color(), 0.45)


func normalize_weather(weather: String) -> String:
	if weather == WEATHER_RAIN:
		return WEATHER_RAIN
	return WEATHER_SUN


func resolve_weather_for_day(day: int) -> String:
	var safe_day := maxi(day, 1)
	if safe_day in STORY_RAIN_DAYS:
		return WEATHER_RAIN
	return _random_weather_for_day(safe_day)


func _random_weather_for_day(day: int) -> String:
	var rng := RandomNumberGenerator.new()
	rng.seed = hash("%d:%d" % [weather_seed, day])
	if rng.randf() < WEATHER_RAIN_CHANCE:
		return WEATHER_RAIN
	return WEATHER_SUN


func _ensure_weather_seed() -> void:
	if weather_seed != 0:
		return
	weather_seed = randi()


func advance_time_period() -> bool:
	var idx := PLAYABLE_TIME_ORDER.find(time_of_day)
	if idx < 0:
		if time_of_day == TIME_NOON:
			time_of_day = TIME_EVENING
		else:
			time_of_day = TIME_MORNING
		_period_elapsed = 0.0
		_emit_time_changed()
		save_game()
		return true
	if idx >= PLAYABLE_TIME_ORDER.size() - 1:
		return false
	time_of_day = PLAYABLE_TIME_ORDER[idx + 1]
	_period_elapsed = 0.0
	_emit_time_changed()
	save_game()
	return true


func set_time_of_day(time_key: String) -> void:
	if not TIME_ORDER.has(time_key):
		return
	if time_of_day == time_key:
		return
	time_of_day = time_key
	_period_elapsed = 0.0
	_emit_time_changed()


func _emit_time_changed() -> void:
	time_changed.emit(time_of_day)
	atmosphere_changed.emit()
	stats_changed.emit()


func get_seed_buy_price() -> int:
	return int(market_state.get("turnip_seed_price", 8))


func get_turnip_sell_price() -> int:
	return 12


func get_market_snapshot() -> Dictionary:
	return {
		"weather_today": weather_today,
		"weather_label": get_weather_label(),
		"weather_tomorrow_hint": weather_tomorrow_hint,
		"weather_tomorrow_label": get_weather_label(weather_tomorrow_hint),
		"time_of_day": time_of_day,
		"time_label": get_time_label(),
		"turnip_seed_price": get_seed_buy_price(),
		"turnip_sell_price": get_turnip_sell_price(),
		"trend": str(market_state.get("trend", "stable")),
	}


func get_memory_snapshot() -> Dictionary:
	return {
		"week_index": get_week_index(),
		"loop_day": get_loop_day(),
		"short_term_memory": short_term_memory.duplicate(true),
		"day_journal": day_journal.duplicate(true),
		"long_term_memory": long_term_memory.duplicate(true),
		"persona": get_persona_vector(),
		"behavior_inferred": get_behavior_inferred(),
	}


func get_persona_vector() -> Dictionary:
	return long_term_memory.get("persona", _default_persona()).duplicate(true)


func get_behavior_inferred() -> Dictionary:
	return long_term_memory.get("behavior_inferred", _default_behavior_inferred()).duplicate(true)


func set_preference(key: String, value: Variant) -> void:
	var prefs: Dictionary = long_term_memory.get("prefs", {})
	prefs[key] = value
	long_term_memory["prefs"] = prefs
	memory_changed.emit()
	save_game()


func drift_persona(delta: Dictionary) -> void:
	var persona: Dictionary = long_term_memory.get("persona", _default_persona())
	for key in delta.keys():
		if not persona.has(key):
			continue
		var next := float(persona[key]) + float(delta[key])
		persona[key] = snappedf(clampf(next, 0.0, 1.0), 0.01)
	long_term_memory["persona"] = persona
	memory_changed.emit()


## 每日向基线 0.5 轻回归：漂移须持续行为维持，一次性偏转不会锁死人设。
func regress_persona_toward_baseline(rate: float = 0.02) -> void:
	var persona: Dictionary = long_term_memory.get("persona", _default_persona())
	var changed := false
	for key in persona.keys():
		var current := float(persona[key])
		var next := current + (0.5 - current) * rate
		var snapped_next := snappedf(clampf(next, 0.0, 1.0), 0.01)
		if not is_equal_approx(snapped_next, current):
			persona[key] = snapped_next
			changed = true
	if changed:
		long_term_memory["persona"] = persona
		memory_changed.emit()


## 某一维 persona 偏离基线足够远且尚未开口提过 → 返回待触发的 shift（不立即标记）。
func peek_persona_shift() -> Dictionary:
	if is_story_complete() or StoryDirector.is_stranger_mode():
		return {}
	var announced: Array = long_term_memory.get("persona_shift_announced", [])
	var persona := get_persona_vector()
	var best_key := ""
	var best_delta := 0.0
	for key in ["warm", "strict", "active", "optimistic", "dependent"]:
		if key in announced:
			continue
		var value := float(persona.get(key, 0.5))
		var delta := absf(value - 0.5)
		if delta >= 0.12 and delta > best_delta:
			best_delta = delta
			best_key = key
	if best_key == "":
		return {}
	var value := float(persona.get(best_key, 0.5))
	return {
		"dimension": best_key,
		"value": value,
		"direction": "high" if value > 0.5 else "low",
	}


func mark_persona_shift_announced(dimension: String) -> void:
	dimension = dimension.strip_edges()
	if dimension == "":
		return
	var announced: Array = long_term_memory.get("persona_shift_announced", [])
	if dimension in announced:
		return
	announced.append(dimension)
	long_term_memory["persona_shift_announced"] = announced
	memory_changed.emit()


func drift_behavior_inferred(delta: Dictionary) -> void:
	var behavior: Dictionary = long_term_memory.get("behavior_inferred", _default_behavior_inferred())
	if delta.has("risk"):
		behavior["risk"] = snappedf(clampf(float(behavior.get("risk", 0.5)) + float(delta["risk"]), 0.0, 1.0), 0.01)
	if delta.has("coping"):
		behavior["coping"] = str(delta["coping"])
	long_term_memory["behavior_inferred"] = behavior
	memory_changed.emit()


func increment_behavior_counter(counter_key: String, amount: int = 1) -> void:
	var counters: Dictionary = long_term_memory.get("counters", {})
	counters[counter_key] = int(counters.get(counter_key, 0)) + amount
	long_term_memory["counters"] = counters
	memory_changed.emit()


func increment_player_busy(amount: int = 1) -> void:
	long_term_memory["player_busy"] = int(long_term_memory.get("player_busy", 0)) + amount
	memory_changed.emit()
	save_game()


func has_milestone(milestone_id: String) -> bool:
	var seen: Variant = long_term_memory.get("milestones_seen", [])
	if seen is Array:
		return milestone_id in seen
	return false


func mark_milestone(milestone_id: String) -> void:
	if not long_term_memory.has("milestones_seen"):
		long_term_memory["milestones_seen"] = []
	var seen: Array = long_term_memory["milestones_seen"]
	if milestone_id in seen:
		return
	seen.append(milestone_id)
	long_term_memory["milestones_seen"] = seen
	memory_changed.emit()


func has_leak_seen(node_id: String) -> bool:
	var key := "%s_w%d" % [node_id.strip_edges(), get_week_index()]
	var seen: Variant = long_term_memory.get("leaks_seen", [])
	if seen is Array:
		return key in seen
	return false


func mark_leak_seen(node_id: String) -> void:
	var clean := node_id.strip_edges()
	if clean == "":
		return
	if not long_term_memory.has("leaks_seen"):
		long_term_memory["leaks_seen"] = []
	var key := "%s_w%d" % [clean, get_week_index()]
	var seen: Array = long_term_memory["leaks_seen"]
	if key in seen:
		return
	seen.append(key)
	long_term_memory["leaks_seen"] = seen
	memory_changed.emit()
	save_game()


func try_trigger_milestone(milestone_id: String, facts: Dictionary = {}) -> bool:
	if milestone_id.strip_edges() == "" or has_milestone(milestone_id):
		return false
	if StoryDirector.is_stranger_mode():
		return false
	mark_milestone(milestone_id)
	var payload := facts.duplicate(true)
	payload["milestone_id"] = milestone_id
	payload["week_index"] = get_week_index()
	payload["loop_day"] = get_loop_day()
	milestone_trigger.emit(milestone_id, payload)
	return true


func _check_affection_milestones(old_affection: int, new_affection: int) -> void:
	if old_affection < MILESTONE_AFFECTION_FAMILIAR and new_affection >= MILESTONE_AFFECTION_FAMILIAR:
		try_trigger_milestone("affection_familiar", {
			"affection": new_affection,
			"stage": STAGE_FAMILIAR,
		})
	if old_affection < MILESTONE_AFFECTION_BOND and new_affection >= MILESTONE_AFFECTION_BOND:
		try_trigger_milestone("affection_bond", {
			"affection": new_affection,
			"stage": STAGE_BOND,
		})


func _check_trade_sell_milestone(item_id: String, price: int) -> void:
	if item_id != "turnip" or price < MILESTONE_TRADE_BIG_WIN_PRICE:
		return
	try_trigger_milestone("trade_big_win_w%d" % get_week_index(), {
		"price": price,
		"coins": coins,
		"trend": str(market_state.get("trend", "stable")),
	})


func _check_trade_buy_milestone(item_id: String, price: int, coins_before: int) -> void:
	if coins_before <= 0 or price <= 0:
		return
	var ratio := float(price) / float(coins_before)
	if ratio < MILESTONE_TRADE_RISKY_BUY_RATIO:
		return
	if coins > MILESTONE_TRADE_LOW_COINS:
		return
	try_trigger_milestone("trade_big_loss_w%d" % get_week_index(), {
		"item_id": item_id,
		"price": price,
		"coins_before": coins_before,
		"coins_left": coins,
	})


func get_nudge_period_key() -> String:
	return "%d_%s" % [game_day, time_of_day]


func dismiss_companion_nudge(react_type: String = "") -> void:
	increment_player_busy()
	long_term_memory["nudge_dismiss_period"] = get_nudge_period_key()
	if react_type.strip_edges() != "":
		long_term_memory["nudge_dismiss_type"] = react_type.strip_edges()
	memory_changed.emit()
	save_game()


func is_companion_nudge_dismissed() -> bool:
	return str(long_term_memory.get("nudge_dismiss_period", "")) == get_nudge_period_key()


func _proactive_rec() -> Dictionary:
	var rec: Variant = long_term_memory.get("proactive_speech", {})
	if rec is not Dictionary:
		rec = {}
	var data: Dictionary = rec
	if int(data.get("day", -1)) != game_day:
		return {
			"day": game_day,
			"count": 0,
			"period": "",
			"channels": [],
			"channel_counts": {},
			"period_channels": [],
			"invite_beat": "",
			"invite_spoken": false,
			"invite_reminded": false,
			"pending_invite": "",
		}
	return data


func _save_proactive_rec(data: Dictionary) -> void:
	long_term_memory["proactive_speech"] = data
	memory_changed.emit()


## 主动开口按频道分池：叙事口（invite / leak）优先，不会被生活闲聊挤掉当天的剧情邀请。
const PROACTIVE_CHANNEL_LIMITS := {
	"invite": 2,
	"leak": 1,
	"casual": 3,
	"ambient": 1,
	"react": 2,
}
const PROACTIVE_TOTAL_LIMIT := 5
## 只有生活口与反应口受「每时段一次」约束；叙事口不受时段限制。
const PROACTIVE_PERIOD_GATED := ["casual", "react"]


func proactive_count_today() -> int:
	return int(_proactive_rec().get("count", 0))


func proactive_channel_count(channel: String) -> int:
	var counts: Variant = _proactive_rec().get("channel_counts", {})
	if counts is Dictionary:
		return int(counts.get(channel, 0))
	return 0


func proactive_period_used(channel: String = "") -> bool:
	var rec := _proactive_rec()
	if str(rec.get("period", "")) != time_of_day:
		return false
	if channel == "":
		return int(rec.get("count", 0)) > 0
	var used: Variant = rec.get("period_channels", [])
	if used is Array:
		return channel in used
	return false


func proactive_had_channel(channel: String) -> bool:
	var channels: Variant = _proactive_rec().get("channels", [])
	if channels is Array:
		return channel in channels
	return false


func can_proactive_speech(channel: String) -> bool:
	if is_story_complete():
		return false
	if proactive_count_today() >= PROACTIVE_TOTAL_LIMIT:
		return false
	if proactive_channel_count(channel) >= int(PROACTIVE_CHANNEL_LIMITS.get(channel, 2)):
		return false
	if channel in PROACTIVE_PERIOD_GATED and proactive_period_used(channel):
		return false
	return true


func consume_proactive_speech(channel: String, extra: Dictionary = {}) -> void:
	var rec := _proactive_rec()
	rec["day"] = game_day
	rec["count"] = int(rec.get("count", 0)) + 1
	var period_changed := str(rec.get("period", "")) != time_of_day
	rec["period"] = time_of_day
	var period_channels: Array = []
	if not period_changed:
		var prev: Variant = rec.get("period_channels", [])
		if prev is Array:
			period_channels = prev.duplicate()
	if channel != "" and channel not in period_channels:
		period_channels.append(channel)
	rec["period_channels"] = period_channels
	var counts: Dictionary = {}
	var raw_counts: Variant = rec.get("channel_counts", {})
	if raw_counts is Dictionary:
		counts = raw_counts.duplicate()
	if channel != "":
		counts[channel] = int(counts.get(channel, 0)) + 1
	rec["channel_counts"] = counts
	var channels: Array = []
	var raw: Variant = rec.get("channels", [])
	if raw is Array:
		channels = raw.duplicate()
	if channel != "" and channel not in channels:
		channels.append(channel)
	rec["channels"] = channels
	if extra.has("invite_beat"):
		rec["invite_beat"] = str(extra.get("invite_beat", ""))
		rec["invite_spoken"] = true
	if bool(extra.get("remind", false)):
		rec["invite_reminded"] = true
	if extra.has("pending_invite"):
		rec["pending_invite"] = str(extra.get("pending_invite", ""))
	if extra.has("extra_channel"):
		var extra_ch := str(extra.get("extra_channel", "")).strip_edges()
		if extra_ch != "":
			if extra_ch not in channels:
				channels.append(extra_ch)
			counts[extra_ch] = int(counts.get(extra_ch, 0)) + 1
		rec["channels"] = channels
		rec["channel_counts"] = counts
	_save_proactive_rec(rec)


func get_pending_invite_beat() -> String:
	return str(_proactive_rec().get("pending_invite", "")).strip_edges()


func set_pending_invite_beat(beat_id: String) -> void:
	var rec := _proactive_rec()
	rec["pending_invite"] = beat_id.strip_edges()
	_save_proactive_rec(rec)


func clear_pending_invite_beat() -> void:
	var rec := _proactive_rec()
	rec["pending_invite"] = ""
	_save_proactive_rec(rec)


func was_invite_spoken_for(beat_id: String) -> bool:
	var rec := _proactive_rec()
	return bool(rec.get("invite_spoken", false)) and str(rec.get("invite_beat", "")) == beat_id


func was_invite_reminded_for(beat_id: String) -> bool:
	var rec := _proactive_rec()
	return bool(rec.get("invite_reminded", false)) and str(rec.get("invite_beat", "")) == beat_id


func get_recent_initiation_lines(limit: int = 8) -> Array:
	var inits: Variant = long_term_memory.get("initiations", [])
	var out: Array = []
	if inits is not Array:
		return out
	var start := maxi(0, inits.size() - limit)
	for i in range(start, inits.size()):
		var item: Variant = inits[i]
		if item is not Dictionary:
			continue
		var said := str(item.get("said", "")).strip_edges()
		if said != "":
			out.append(said)
	return out


func record_initiation(trigger: String, facts: Dictionary, said: String = "") -> void:
	var inits: Array = long_term_memory.get("initiations", [])
	inits.append({
		"week_index": get_week_index(),
		"loop_day": get_loop_day(),
		"game_day": game_day,
		"trigger": trigger,
		"facts": facts.duplicate(true),
		"said": said,
		"weight": 0.65,
	})
	while inits.size() > 24:
		inits.remove_at(0)
	long_term_memory["initiations"] = inits
	memory_changed.emit()
	save_game()


func touch_play_timestamp() -> void:
	long_term_memory["last_play_unix"] = int(Time.get_unix_time_from_system())
	save_game()


func apply_absence_since_last_play() -> void:
	var last_unix := int(long_term_memory.get("last_play_unix", 0))
	if last_unix <= 0:
		return
	var now_unix := int(Time.get_unix_time_from_system())
	var gap_sec := maxi(now_unix - last_unix, 0)
	var gap_hours := int(gap_sec / 3600)
	if gap_hours < ABSENCE_MIN_GAP_HOURS:
		return
	if _has_absence_note_for_last_play(last_unix):
		return

	var behavior: Dictionary = long_term_memory.get("behavior_inferred", _default_behavior_inferred())
	behavior["absence_hours"] = gap_hours
	behavior["absence_days"] = int(gap_hours / 24)
	long_term_memory["behavior_inferred"] = behavior

	var notes: Array = long_term_memory.get("absence_notes", [])
	notes.append({
		"gap_hours": gap_hours,
		"return_day": game_day,
		"week_index": get_week_index(),
		"last_play_unix": last_unix,
		"shown": false,
		"comeback_hint": build_absence_comeback_hint(gap_hours),
	})
	while notes.size() > 8:
		notes.remove_at(0)
	long_term_memory["absence_notes"] = notes
	record_memory_event(
		"absence",
		"你离开了 %s 后回来。" % format_absence_gap(gap_hours),
		0.7,
		{"gap_hours": gap_hours, "return_day": game_day}
	)
	memory_changed.emit()
	save_game()


func _has_absence_note_for_last_play(last_unix: int) -> bool:
	for entry in long_term_memory.get("absence_notes", []):
		if entry is Dictionary and int(entry.get("last_play_unix", 0)) == last_unix:
			return true
	return false


func format_absence_gap(gap_hours: int) -> String:
	if gap_hours < 24:
		return "%d 小时" % gap_hours
	var days := int(gap_hours / 24)
	if gap_hours % 24 == 0:
		return "%d 天" % days
	return "%d 天多" % days


func build_absence_comeback_hint(gap_hours: int) -> String:
	if gap_hours >= 168:
		if affection >= MILESTONE_AFFECTION_BOND:
			return "好久不见……我还以为你不回来了。这片萝卜田，我一直在守。"
		return "你离开有一阵了。我不在的时候，也把院子先照顾着。回来就好。"
	if gap_hours >= 48:
		return "你不在的这几天，我把萝卜田都先照看好了。回来就好。"
	if gap_hours >= 12:
		return "你不在的这段时间，我把萝卜田先照看着。回来就好。"
	return "你离开了一阵子，我把院子先看着。回来就好。"


func has_pending_absence() -> bool:
	if StoryDirector.is_stranger_mode() or should_show_awakening():
		return false
	var notes: Array = long_term_memory.get("absence_notes", [])
	if notes.is_empty():
		return false
	var latest: Variant = notes[notes.size() - 1]
	if not latest is Dictionary:
		return false
	if bool(latest.get("shown", false)):
		return false
	return int(latest.get("return_day", -1)) == game_day


func get_chat_timing_context_for_llm() -> Dictionary:
	var today_lines: Array[String] = []
	for item in today_chat_log:
		if not item is Dictionary:
			continue
		if str(item.get("role", "")) != "player":
			continue
		var line := str(item.get("text", "")).strip_edges()
		if line != "":
			today_lines.append(line)
	return {
		"game_day": game_day,
		"can_reference_yesterday": game_day >= 2 and has_yesterday_journal(),
		"today_player_lines": today_lines.slice(-8),
	}


func get_pending_absence_facts() -> Dictionary:
	if not has_pending_absence():
		return {}
	var notes: Array = long_term_memory.get("absence_notes", [])
	var latest: Dictionary = notes[notes.size() - 1]
	return latest.duplicate(true)


func mark_absence_shown() -> void:
	var notes: Array = long_term_memory.get("absence_notes", [])
	if notes.is_empty():
		return
	var latest: Dictionary = notes[notes.size() - 1]
	if int(latest.get("return_day", -1)) != game_day:
		return
	latest["shown"] = true
	notes[notes.size() - 1] = latest
	long_term_memory["absence_notes"] = notes
	memory_changed.emit()
	save_game()


func get_absence_comeback_line() -> String:
	return str(get_pending_absence_facts().get("comeback_hint", "")).strip_edges()


func get_recent_memories(limit: int = 3) -> Array[Dictionary]:
	var count := mini(limit, short_term_memory.size())
	if count <= 0:
		return []
	return short_term_memory.slice(short_term_memory.size() - count, short_term_memory.size())


func get_latest_anchor() -> Dictionary:
	var anchors: Array = long_term_memory.get("anchors", [])
	if anchors.is_empty():
		return {}
	return anchors[anchors.size() - 1]


func has_revealed_memory() -> bool:
	return bool(long_term_memory.get("revealed", false))


func mark_w2_stranger_seen() -> void:
	if bool(long_term_memory.get("w2_stranger_seen", false)):
		return
	long_term_memory["w2_stranger_seen"] = true
	record_memory_event(
		"story",
		"第二周第一天，小狸说不认识你。",
		0.95,
		{"node": "N05", "week_index": get_week_index()}
	)
	save_game()


func is_awakening_day() -> bool:
	return game_day == FINAL_GAME_DAY


func is_post_story() -> bool:
	return game_day > FINAL_GAME_DAY or (has_revealed_memory() and game_day >= FINAL_GAME_DAY)


func must_finish_awakening_today() -> bool:
	return is_awakening_day() and not has_seen_awakening()


func is_pure_narrative_day() -> bool:
	## D10 觉醒前：纯叙事日，锁种田与商店派活。
	return must_finish_awakening_today()


func is_bad_early_path() -> bool:
	return bool(get_ending_flags().get("w2_chose_expel", false))


func should_force_story_finale() -> bool:
	if is_story_complete():
		return false
	if is_bad_early_path():
		return is_story_node_seen("BE_N07") or (IS_TEN_DAY_EDITION and game_day >= 6 and is_story_node_seen("BE_N07"))
	if game_day > FINAL_GAME_DAY:
		return true
	# 仅终章日觉醒之后兜底收束；旧存档 awakening_seen 不应阻断序章节点。
	if game_day >= FINAL_GAME_DAY and has_seen_awakening() and not is_story_complete():
		return true
	return false


func is_week_last_day() -> bool:
	return get_loop_day() == 7


func should_show_week_wrap() -> bool:
	if IS_TEN_DAY_EDITION:
		return false
	if not is_week_last_day():
		return false
	if must_finish_awakening_today():
		return false
	if StoryBeatDirector.has_unseen_weekend_night_beat():
		return false
	if TaskSystem.is_busy():
		return false
	return true


func get_week_summaries() -> Array[Dictionary]:
	var raw: Variant = long_term_memory.get("week_summaries", [])
	if raw is Array:
		return _duplicate_dict_array(raw)
	return []


func get_yesterday_journal_entry() -> Dictionary:
	if day_journal.is_empty():
		return {}
	var entry: Variant = day_journal[day_journal.size() - 1]
	if entry is Dictionary:
		return entry.duplicate(true)
	return {}


func get_yesterday_journal_summary() -> String:
	return str(get_yesterday_journal_entry().get("summary", "")).strip_edges()


func has_yesterday_journal() -> bool:
	return get_yesterday_journal_summary() != ""


func build_yesterday_echo_hint() -> String:
	var summary := get_yesterday_journal_summary()
	if summary == "":
		return ""
	var weather := _weather_word_from_summary(summary)
	var watered := "浇" in summary
	var harvested := "收" in summary and "售价" not in summary
	var sold := "卖" in summary or "售出" in summary
	if watered:
		match weather:
			"sun":
				return "太阳很好，咱们把萝卜田都浇透了"
			"rain":
				return "下着雨，咱们还是去把田照看了"
			_:
				return "咱们一起把萝卜田照顾好了"
	if harvested:
		return "萝卜熟了几块，咱们收回来了"
	if sold:
		return "去大盘卖了一轮萝卜"
	match weather:
		"sun":
			return "天气不错，在田里忙了一天"
		"rain":
			return "下了一天雨，田喝饱了水"
		_:
			return "在家园里忙了一天"


func _weather_word_from_summary(summary: String) -> String:
	if "雨天" in summary or "下雨" in summary:
		return "rain"
	if "晴天" in summary or "晴" in summary:
		return "sun"
	return ""


func should_show_awakening() -> bool:
	if is_bad_early_path():
		return false
	return is_awakening_day() and not bool(long_term_memory.get("awakening_seen", false))


func has_seen_awakening() -> bool:
	return bool(long_term_memory.get("awakening_seen", false))


func mark_awakening_complete(skipped: bool) -> void:
	long_term_memory["awakening_seen"] = true
	long_term_memory["revealed"] = true
	set_ending_flag("f10_skipped", skipped)
	add_memory_recovery(0.08)
	var summary := "第十天，她把话说完了——忘的，从来不只是她。"
	if skipped:
		summary = "第十天，你跳过了觉醒闪回，但这一天仍被记了下来。"
	record_memory_event(
		"awakening",
		summary,
		1.0,
		{"node": "N18", "skipped": skipped, "game_day": game_day}
	)
	memory_changed.emit()
	save_game()


func debug_jump_to_d35() -> void:
	## 兼容旧名：跳到终章日（十日版为 D10）。
	if is_story_complete():
		return
	game_day = FINAL_GAME_DAY
	time_of_day = TIME_NIGHT
	_period_elapsed = 0.0
	weather_today = resolve_weather_for_day(game_day)
	weather_tomorrow_hint = resolve_weather_for_day(game_day + 1)
	long_term_memory["awakening_seen"] = false
	long_term_memory["revealed"] = false
	save_game()
	stats_changed.emit()
	time_changed.emit(time_of_day)
	atmosphere_changed.emit()
	debug_awakening_requested.emit()


func is_story_complete() -> bool:
	return bool(long_term_memory.get("story_complete", false))


func can_advance_day() -> bool:
	if is_story_complete():
		return false
	if is_bad_early_path() and game_day >= 6:
		return false
	return game_day < FINAL_GAME_DAY


func reset_for_new_game() -> void:
	var saved_companion := companion_name
	_apply_new_game_defaults("", saved_companion)
	save_game()
	stats_changed.emit()
	memory_changed.emit()
	atmosphere_changed.emit()
	market_changed.emit()
	time_changed.emit(time_of_day)


func _apply_new_game_defaults(player: String, companion: String) -> void:
	player_name = player
	companion_name = companion
	game_day = 1
	affection = 0
	bond = 0
	mood = 80
	coins = 80
	weather_seed = randi()
	weather_today = resolve_weather_for_day(game_day)
	weather_tomorrow_hint = resolve_weather_for_day(game_day + 1)
	time_of_day = TIME_MORNING
	_period_elapsed = 0.0
	_awaiting_sleep = false
	_time_pause_depth = 0
	watered_plots.clear()
	inventory = {
		"turnip_seed": 5,
		"turnip": 0,
	}
	plot_data.clear()
	farm_plot_count = 0
	last_task_summary = ""
	last_day_summary = ""
	market_state = {
		"turnip_seed_price": 8,
		"turnip_sell_price": 12,
		"trend": "stable",
	}
	short_term_memory.clear()
	recent_chat_turns.clear()
	today_chat_log.clear()
	day_journal.clear()
	long_term_memory = _default_long_term_memory()
	_ensure_runtime_defaults()
	roll_market_for_weather(weather_today)


func _default_long_term_memory() -> Dictionary:
	return {
		"prefs": {
			"fav_crop": CROP_TURNIP,
			"time_rhythm": "",
		},
		"persona": {
			"warm": 0.5,
			"strict": 0.5,
			"active": 0.5,
			"optimistic": 0.5,
			"dependent": 0.5,
		},
		"behavior_inferred": {
			"risk": 0.5,
			"coping": "neutral",
			"absence_days": 0,
		},
		"initiations": [],
		"proactive_speech": {},
		"absence_notes": [],
		"player_busy": 0,
		"counters": {
			"plant_count": 0,
			"harvest_count": 0,
			"sell_count": 0,
			"buy_seed_count": 0,
		},
		"last_play_unix": 0,
		"anchors": [],
		"week_summaries": [],
		"promise": {},
		"revealed": false,
		"w2_stranger_seen": false,
		"awakening_seen": false,
		"memory_recovery": 0.0,
		"memory_fragments": [],
		"story_complete": false,
		"final_ending_id": "",
		"endings_seen": [],
		"story_nodes_seen": [],
		"story_route": "",
		"relationship_signals": {
			"chat_turns": 0,
			"chat_days": 0,
			"last_chat_day": 0,
			"gifts_given": 0,
			"nodes_cleared": 0,
			"tasks_together": 0,
			"llm_affection_net": 0,
			"llm_bond_net": 0,
			"beat_chats": 0,
		},
		"ending_flags": {
			"w2_chose_keep": true,
			"w2_chose_expel": false,
			"companionship_nights": 0,
			"w2_choice_made": false,
			"f10_skipped": false,
		},
		"player_name_set": false,
		"pending_story_beat_tail_id": "",
		"pending_story_beat_tail_steps": [],
		"chat_archive": [],
	}


func get_final_ending_id() -> String:
	return str(long_term_memory.get("final_ending_id", ""))


func get_endings_seen() -> Array:
	var seen: Variant = long_term_memory.get("endings_seen", [])
	if seen is Array:
		return seen.duplicate()
	return []


func get_ending_flags() -> Dictionary:
	var flags: Variant = long_term_memory.get("ending_flags", {})
	if flags is Dictionary:
		return flags.duplicate(true)
	return {}


func set_ending_flag(key: String, value: Variant) -> void:
	var flags := get_ending_flags()
	flags[key] = value
	long_term_memory["ending_flags"] = flags
	save_game()


func get_deferred_story_beat() -> String:
	return str(long_term_memory.get("deferred_story_beat", "")).strip_edges()


func get_deferred_story_beat_from_day() -> int:
	return int(long_term_memory.get("deferred_story_beat_from_day", 0))


func set_deferred_story_beat(beat_id: String, from_day: int = -1) -> void:
	var clean := beat_id.strip_edges()
	if clean == "":
		clear_deferred_story_beat()
		return
	long_term_memory["deferred_story_beat"] = clean
	long_term_memory["deferred_story_beat_from_day"] = from_day if from_day > 0 else game_day
	save_game()


func clear_deferred_story_beat() -> void:
	long_term_memory.erase("deferred_story_beat")
	long_term_memory.erase("deferred_story_beat_from_day")
	save_game()


func set_pending_story_beat_tail(beat_id: String, steps: Array) -> void:
	long_term_memory["pending_story_beat_tail_id"] = beat_id.strip_edges()
	var stored: Array = []
	for step in steps:
		if step is Dictionary:
			stored.append(step.duplicate(true))
	long_term_memory["pending_story_beat_tail_steps"] = stored
	save_game()


func get_pending_story_beat_tail_id() -> String:
	return str(long_term_memory.get("pending_story_beat_tail_id", "")).strip_edges()


func get_pending_story_beat_tail_steps() -> Array:
	var raw: Variant = long_term_memory.get("pending_story_beat_tail_steps", [])
	if raw is Array:
		return raw.duplicate(true)
	return []


func clear_pending_story_beat_tail() -> void:
	long_term_memory["pending_story_beat_tail_id"] = ""
	long_term_memory["pending_story_beat_tail_steps"] = []
	save_game()


func has_pending_story_beat_tail() -> bool:
	return get_pending_story_beat_tail_id() != "" and not get_pending_story_beat_tail_steps().is_empty()


func record_companionship_night(week: int) -> void:
	var key := "companionship_w%d" % week
	var flags := get_ending_flags()
	if bool(flags.get(key, false)):
		return
	flags[key] = true
	flags["companionship_nights"] = int(flags.get("companionship_nights", 0)) + 1
	long_term_memory["ending_flags"] = flags
	save_game()


func mark_w2_expel_choice() -> void:
	set_ending_flag("w2_choice_made", true)
	set_ending_flag("w2_chose_expel", true)
	set_ending_flag("w2_chose_keep", false)


func mark_w2_keep_choice() -> void:
	set_ending_flag("w2_choice_made", true)
	set_ending_flag("w2_chose_keep", true)
	set_ending_flag("w2_chose_expel", false)
	add_memory_recovery(0.05)
	PlayerNotebookService.on_w2_keep_choice()


func should_show_w2_keep_choice() -> bool:
	var choice_day := 5 if IS_TEN_DAY_EDITION else 10
	if game_day != choice_day:
		return false
	var flags := get_ending_flags()
	return not bool(flags.get("w2_choice_made", false))


func get_companion_night_week() -> int:
	if IS_TEN_DAY_EDITION:
		if game_day == 7:
			return 1
		return 0
	if game_day == 14:
		return 2
	if game_day == 25:
		return 4
	return 0


func should_show_companion_choice() -> bool:
	var week := get_companion_night_week()
	if week <= 0:
		return false
	var flags := get_ending_flags()
	var key := "companionship_w%d" % week
	return not bool(flags.get(key, false)) and not bool(flags.get("companionship_d%d" % game_day, false))


func mark_companion_choice(made: bool) -> void:
	var week := get_companion_night_week()
	if week <= 0:
		return
	var flags := get_ending_flags()
	flags["companionship_d%d" % game_day] = true
	long_term_memory["ending_flags"] = flags
	if made:
		record_companionship_night(week)
	else:
		save_game()


func get_memory_recovery() -> float:
	var stored := float(long_term_memory.get("memory_recovery", 0.0))
	if stored > 0.0:
		return clampf(stored, 0.0, 1.0)
	return _estimate_memory_recovery()


func add_memory_recovery(amount: float) -> void:
	var next := clampf(get_memory_recovery() + amount, 0.0, 1.0)
	long_term_memory["memory_recovery"] = snappedf(next, 0.01)
	memory_changed.emit()


func get_fragment_count() -> int:
	return get_memory_fragments().size()


func get_memory_fragments() -> Array:
	var frags: Variant = long_term_memory.get("memory_fragments", [])
	if frags is Array:
		return frags.duplicate(true)
	return []


func has_fragment(fragment_id: String) -> bool:
	for entry in get_memory_fragments():
		if entry is Dictionary and str(entry.get("id", "")) == fragment_id:
			return true
	return false


func get_fragment_entry(fragment_id: String) -> Dictionary:
	for entry in get_memory_fragments():
		if entry is Dictionary and str(entry.get("id", "")) == fragment_id:
			return entry.duplicate(true)
	return {}


func unlock_fragment(fragment_id: String, node_id: String = "", personal: String = "") -> void:
	if has_fragment(fragment_id):
		return
	if not long_term_memory.has("memory_fragments"):
		long_term_memory["memory_fragments"] = []
	var frags: Array = long_term_memory["memory_fragments"]
	frags.append({
		"id": fragment_id,
		"node": node_id,
		"game_day": game_day,
		"personal": personal,
		"unlocked_at": Time.get_unix_time_from_system(),
	})
	long_term_memory["memory_fragments"] = frags
	memory_changed.emit()
	save_game()


func mark_story_node_seen(node_id: String) -> void:
	if not long_term_memory.has("story_nodes_seen"):
		long_term_memory["story_nodes_seen"] = []
	var seen: Array = long_term_memory["story_nodes_seen"]
	if node_id not in seen:
		seen.append(node_id)
	long_term_memory["story_nodes_seen"] = seen
	save_game()


func get_story_route() -> String:
	return str(long_term_memory.get("story_route", ""))


func lock_story_route(route: String) -> void:
	long_term_memory["story_route"] = route
	save_game()


func is_story_node_seen(node_id: String) -> bool:
	var seen: Variant = long_term_memory.get("story_nodes_seen", [])
	if seen is Array:
		return node_id in seen
	return false


func get_story_nodes_seen() -> Array:
	var seen: Variant = long_term_memory.get("story_nodes_seen", [])
	if seen is Array:
		return seen.duplicate()
	return []


func mark_story_ended(ending_id: String) -> void:
	long_term_memory["story_complete"] = true
	long_term_memory["final_ending_id"] = ending_id
	if not long_term_memory.has("endings_seen"):
		long_term_memory["endings_seen"] = []
	var seen: Array = long_term_memory["endings_seen"]
	if ending_id not in seen:
		seen.append(ending_id)
	long_term_memory["endings_seen"] = seen
	add_memory_recovery(0.05)
	memory_changed.emit()
	save_game()


func _estimate_memory_recovery() -> float:
	var recovery := clampf(float(game_day) / float(FINAL_GAME_DAY), 0.0, 1.0) * 0.45
	recovery += float(affection) / 100.0 * 0.25
	recovery += float(bond) / 100.0 * 0.15
	var flags := get_ending_flags()
	if bool(flags.get("w2_chose_keep", true)) and not bool(flags.get("w2_chose_expel", false)):
		recovery += 0.05
	recovery += mini(int(flags.get("companionship_nights", 0)), 2) * 0.05
	return clampf(recovery, 0.0, 1.0)


func add_affection(amount: int) -> void:
	var old_affection := affection
	affection = clampi(affection + amount, 0, 100)
	_check_affection_milestones(old_affection, affection)
	stats_changed.emit()
	save_game()


func add_bond(amount: int) -> void:
	bond = clampi(bond + amount, 0, 100)
	stats_changed.emit()
	save_game()


func set_mood(value: int) -> void:
	mood = clampi(value, 0, 100)
	stats_changed.emit()
	save_game()


func get_item_count(item_key: String) -> int:
	return int(inventory.get(item_key, 0))


func add_item(item_key: String, amount: int = 1) -> void:
	if amount <= 0:
		return
	inventory[item_key] = get_item_count(item_key) + amount
	stats_changed.emit()
	save_game()


func remove_item(item_key: String, amount: int = 1) -> bool:
	if get_item_count(item_key) < amount:
		return false
	var left := get_item_count(item_key) - amount
	if left <= 0:
		inventory.erase(item_key)
	else:
		inventory[item_key] = left
	stats_changed.emit()
	save_game()
	return true


func can_afford(price: int) -> bool:
	return coins >= price


func get_shop_item_unit_price(item_id: String) -> int:
	var item := ShopCatalog.get_shop_item(item_id)
	if item.is_empty():
		return 0
	if item_id == "turnip_seed":
		return get_seed_buy_price()
	return int(item.get("buy_price", 0))


func buy_shop_item_count(item_id: String, count: int) -> Dictionary:
	if count <= 0:
		return {"ok": false, "reason": "invalid_count", "message": "数量至少为 1。"}

	var item := ShopCatalog.get_shop_item(item_id)
	if item.is_empty():
		return {"ok": false, "reason": "no_item", "message": "没有这个商品。"}

	var unit_price := get_shop_item_unit_price(item_id)
	if unit_price <= 0:
		return {"ok": false, "reason": "not_for_sale", "message": "这个商品暂时不卖。"}

	var total_price := unit_price * count
	if coins < total_price:
		var affordable := coins / unit_price if unit_price > 0 else 0
		if affordable <= 0:
			return {
				"ok": false,
				"reason": "insufficient_coins",
				"message": "金币不够。买 %d 包要 %d 金，你现在只有 %d 金。" % [count, total_price, coins],
				"affordable_count": 0,
			}
		return {
			"ok": false,
			"reason": "insufficient_coins",
			"message": "金币不够买 %d 包（要 %d 金）。你现在 %d 金，最多能买 %d 包。" % [
				count, total_price, coins, affordable,
			],
			"affordable_count": affordable,
		}

	var coins_before := coins
	coins -= total_price
	if coins < 0:
		coins = coins_before
		return {
			"ok": false,
			"reason": "insufficient_coins",
			"message": "金币不够。买 %d 包要 %d 金，你现在只有 %d 金。" % [count, total_price, coins_before],
			"affordable_count": coins_before / unit_price if unit_price > 0 else 0,
		}
	add_item(str(item.get("inventory_key", item_id)), count)
	var item_name := str(item.get("name", item_id))
	record_memory_event(
		"trade_buy",
		"你买入了 %d 包%s，共 %d 金币。" % [count, item_name, total_price],
		0.45,
		{"item_id": item_id, "price": unit_price, "count": count, "total_price": total_price}
	)
	for _i in range(count):
		BehaviorCollector.observe_trade_buy(item_id, unit_price)
	_check_trade_buy_milestone(item_id, unit_price, coins_before)
	save_game()
	return {
		"ok": true,
		"count": count,
		"total_price": total_price,
		"message": "买了 %d 包%s，花费 %d 金币。" % [count, item_name, total_price],
	}


func get_inventory_snapshot_for_llm() -> Dictionary:
	var snap := {
		"coins": coins,
		"turnip_seed": get_item_count("turnip_seed"),
		"turnip": get_item_count("turnip"),
	}
	for item in ShopCatalog.get_treat_items():
		var key := str(item.get("inventory_key", ""))
		if key != "":
			snap[key] = get_item_count(key)
	return snap


func get_shop_snapshot_for_llm() -> Dictionary:
	var buy_items: Array = []
	for item in ShopCatalog.SHOP_ITEMS:
		var item_id := str(item.get("id", ""))
		buy_items.append({
			"id": item_id,
			"name": str(item.get("name", "")),
			"category": str(item.get("category", "")),
			"price": get_shop_item_unit_price(item_id),
		})
	var sell_items: Array = []
	for item in ShopCatalog.SELL_ITEMS:
		var sell_id := str(item.get("id", ""))
		var sell_price := get_turnip_sell_price() if sell_id == "turnip" else int(item.get("sell_price", 0))
		sell_items.append({
			"id": sell_id,
			"name": str(item.get("name", "")),
			"price": sell_price,
		})
	return {
		"turnip_seed_price": get_seed_buy_price(),
		"turnip_sell_price": get_turnip_sell_price(),
		"buy_items": buy_items,
		"sell_items": sell_items,
	}


func get_plot_details_for_llm() -> Array:
	var result: Array = []
	for plot_id in get_all_plot_ids():
		var plot := get_plot(plot_id)
		var stage := int(plot.get("stage", 0))
		var status := "empty"
		if can_harvest(plot_id):
			status = "harvestable"
		elif stage > 0:
			status = "growing"
		var watered := bool(plot.get("watered", false)) or plot_id in watered_plots
		var needs_water := (
			stage > 0
			and not can_harvest(plot_id)
			and not watered
			and weather_today != WEATHER_RAIN
		)
		result.append({
			"plot_id": plot_id,
			"crop": str(plot.get("crop", "")),
			"stage": stage,
			"max_stage": MATURE_STAGE,
			"status": status,
			"watered_today": watered,
			"needs_water": needs_water,
		})
	result.sort_custom(func(a: Dictionary, b: Dictionary) -> bool:
		return int(a.get("plot_id", 0)) < int(b.get("plot_id", 0))
	)
	return result


func buy_shop_item(item_id: String) -> String:
	var result := buy_shop_item_count(item_id, 1)
	if not bool(result.get("ok", false)):
		return str(result.get("message", "购买失败。"))
	return str(result.get("message", ""))


func sell_inventory_item(item_id: String) -> String:
	var item := ShopCatalog.get_sell_item(item_id)
	if item.is_empty():
		return "商店不收这个。"

	var item_key := str(item.get("inventory_key", item_id))
	if get_item_count(item_key) <= 0:
		return "背包里没有 %s。" % str(item.get("name", item_id))

	var price := int(item.get("sell_price", 0))
	if item_id == "turnip":
		price = get_turnip_sell_price()

	remove_item(item_key, 1)
	coins += price
	stats_changed.emit()
	record_memory_event(
		"trade_sell",
		"你把 1 个萝卜换成了 %d 金币。" % price,
		0.45,
		{"item_id": item_id, "price": price}
	)
	BehaviorCollector.observe_trade_sell(item_id, price)
	_check_trade_sell_milestone(item_id, price)
	save_game()
	return "卖掉了 %s，换来 %d 金币。" % [str(item.get("name", item_id)), price]


func sell_all_turnips() -> Dictionary:
	var count := get_item_count("turnip")
	if count <= 0:
		return {
			"ok": false,
			"count": 0,
			"total": 0,
			"message": "筐里还没有萝卜。",
		}
	var price := get_turnip_sell_price()
	var total := count * price
	remove_item("turnip", count)
	coins += total
	stats_changed.emit()
	record_memory_event(
		"trade_sell",
		"你们把 %d 个萝卜换成了 %d 金币。" % [count, total],
		0.55,
		{"item_id": "turnip", "price": price, "count": count, "total": total}
	)
	for _i in range(count):
		BehaviorCollector.observe_trade_sell("turnip", price)
	_check_trade_sell_milestone("turnip", price)
	save_game()
	return {
		"ok": true,
		"count": count,
		"total": total,
		"message": "卖掉了 %d 个萝卜，换来 %d 金币。" % [count, total],
	}


func get_owned_treats() -> Array[Dictionary]:
	var owned: Array[Dictionary] = []
	for item in ShopCatalog.get_treat_items():
		var key := str(item.get("inventory_key", ""))
		if get_item_count(key) > 0:
			owned.append(item)
	return owned


func has_fed_today() -> bool:
	return feeds_today >= 1


func get_today_feed_replies() -> Array[String]:
	return today_feed_replies.duplicate()


func register_feed_reply(text: String) -> void:
	var cleaned := text.strip_edges()
	if cleaned == "":
		return
	for existing in today_feed_replies:
		if existing == cleaned:
			return
	today_feed_replies.append(cleaned)


func inspect_feed_attempt(item_id: String) -> Dictionary:
	var item := ShopCatalog.get_treat_item(item_id)
	if item.is_empty():
		return {"status": "invalid_item"}

	var item_key := str(item.get("inventory_key", item_id))
	if get_item_count(item_key) <= 0:
		return {
			"status": "no_item",
			"item_name": str(item.get("name", item_id)),
		}

	if feeds_today >= 1:
		feed_pester_count += 1
		if feed_pester_count >= 2:
			return {
				"status": "refuse_many",
				"item": item,
				"pester_count": feed_pester_count,
			}
		return {
			"status": "refuse_already",
			"item": item,
			"pester_count": feed_pester_count,
		}

	return {"status": "ok", "item": item}


func commit_feed_treat(item_id: String) -> Dictionary:
	var item := ShopCatalog.get_treat_item(item_id)
	if item.is_empty():
		return {"ok": false, "reason": "invalid_item"}

	var item_key := str(item.get("inventory_key", item_id))
	if not remove_item(item_key, 1):
		return {"ok": false, "reason": "no_item"}

	add_affection(int(item.get("affection", 0)))
	add_bond(int(item.get("bond", 0)))
	set_mood(mini(mood + int(item.get("mood", 0)), 100))
	feeds_today = 1
	RelationshipDirector.record_gift(item_id)
	record_memory_event(
		"gift",
		"你给小狸喂了 %s。" % str(item.get("name", item_id)),
		0.65,
		{"item_id": item_id}
	)
	stats_changed.emit()
	save_game()
	return {"ok": true, "item": item}


func reset_daily_feed() -> void:
	feeds_today = 0
	feed_pester_count = 0
	today_feed_replies.clear()


func register_farm_plots(count: int) -> void:
	farm_plot_count = maxi(count, 0)
	stats_changed.emit()


func get_all_plot_ids() -> Array[int]:
	var ids: Array[int] = []
	if farm_plot_count > 0:
		for plot_id in range(1, farm_plot_count + 1):
			ids.append(plot_id)
		return ids
	for key in plot_data.keys():
		ids.append(int(key))
	ids.sort()
	return ids


func get_empty_plot_ids() -> Array[int]:
	var empty_ids: Array[int] = []
	for plot_id in get_all_plot_ids():
		if int(get_plot(plot_id).get("stage", 0)) <= 0:
			empty_ids.append(plot_id)
	return empty_ids


func get_plot_summary() -> Dictionary:
	var empty := 0
	var growing := 0
	var harvestable := 0
	var unwatered_growing := 0
	var harvestable_plot_ids: Array[int] = []
	var unwatered_plot_ids: Array[int] = []

	for plot_id in get_all_plot_ids():
		var plot: Dictionary = get_plot(plot_id)
		var stage := int(plot.get("stage", 0))
		if stage <= 0:
			empty += 1
			continue
		if can_harvest(plot_id):
			harvestable += 1
			harvestable_plot_ids.append(plot_id)
			continue
		growing += 1
		var watered := bool(plot.get("watered", false)) or plot_id in watered_plots
		if not watered and weather_today != WEATHER_RAIN:
			unwatered_growing += 1
			unwatered_plot_ids.append(plot_id)

	return {
		"empty": empty,
		"growing": growing,
		"harvestable": harvestable,
		"unwatered_growing": unwatered_growing,
		"harvestable_plot_ids": harvestable_plot_ids,
		"unwatered_plot_ids": unwatered_plot_ids,
		"planted_total": empty + growing + harvestable,
		"total_plots": get_all_plot_ids().size(),
	}


func get_unwatered_growing_plot_ids() -> Array[int]:
	var summary := get_plot_summary()
	var ids: Variant = summary.get("unwatered_plot_ids", [])
	var result: Array[int] = []
	if ids is Array:
		for plot_id in ids:
			result.append(int(plot_id))
	result.sort()
	return result


func get_plot(plot_id: int) -> Dictionary:
	return plot_data.get(_plot_key(plot_id), _empty_plot())


func ensure_plot(plot_id: int) -> Dictionary:
	var key := _plot_key(plot_id)
	if not plot_data.has(key):
		plot_data[key] = _empty_plot()
	var plot: Dictionary = plot_data[key]
	if int(plot.get("stage", 0)) > 0 and str(plot.get("crop", "")).strip_edges() == "":
		plot["crop"] = CROP_TURNIP
	return plot


func get_plantable_plot_ids() -> Array[int]:
	var seeds := int(inventory.get("turnip_seed", 0))
	if seeds <= 0:
		return []
	var empty_ids := get_empty_plot_ids()
	var result: Array[int] = []
	for i in range(mini(seeds, empty_ids.size())):
		result.append(empty_ids[i])
	return result


func can_plant_turnip(plot_id: int) -> bool:
	var plot := get_plot(plot_id)
	return int(plot.get("stage", 0)) == 0 and int(inventory.get("turnip_seed", 0)) > 0


func plant_turnip(plot_id: int, by_companion: bool = false) -> bool:
	if not can_plant_turnip(plot_id):
		return false

	inventory["turnip_seed"] = int(inventory.get("turnip_seed", 0)) - 1
	var plot := ensure_plot(plot_id)
	plot["crop"] = CROP_TURNIP
	plot["stage"] = 1
	plot["watered"] = false
	stats_changed.emit()
	if by_companion:
		record_memory_event(
			"task_plant",
			"小狸在第 %d 块田里种下了萝卜。" % plot_id,
			0.4,
			{"plot_id": plot_id, "crop": CROP_TURNIP, "by_companion": true}
		)
		companion_world_event.emit("companion_planted", {"plot_id": plot_id, "crop": CROP_TURNIP})
	else:
		record_memory_event(
			"plant",
			"你在第 %d 块田里种下了萝卜。" % plot_id,
			0.35,
			{"plot_id": plot_id, "crop": CROP_TURNIP}
		)
		companion_world_event.emit("player_planted", {"plot_id": plot_id, "crop": CROP_TURNIP})
	save_game()
	return true


func can_harvest(plot_id: int) -> bool:
	var plot := get_plot(plot_id)
	var stage := int(plot.get("stage", 0))
	if stage < MATURE_STAGE:
		return false
	var crop := str(plot.get("crop", "")).strip_edges()
	if crop == "" or crop == CROP_TURNIP:
		return true
	return crop == CROP_TURNIP


func harvest_turnip(plot_id: int) -> bool:
	if not can_harvest(plot_id):
		return false

	inventory["turnip"] = int(inventory.get("turnip", 0)) + 1
	var plot := ensure_plot(plot_id)
	plot["crop"] = ""
	plot["stage"] = 0
	plot["watered"] = false
	stats_changed.emit()
	record_memory_event(
		"harvest",
		"你收获了 1 个萝卜。",
		0.7,
		{"plot_id": plot_id, "crop": CROP_TURNIP, "count": 1}
	)
	set_preference("fav_crop", CROP_TURNIP)
	companion_world_event.emit("player_harvested", {"plot_id": plot_id, "count": 1})
	save_game()
	return true


func mark_plot_watered(plot_id: int, by_companion: bool = false) -> void:
	if plot_id not in watered_plots:
		watered_plots.append(plot_id)
	var plot := ensure_plot(plot_id)
	plot["watered"] = true
	stats_changed.emit()
	if by_companion:
		today_water_by_companion += 1
		if today_water_by_companion == 1:
			record_memory_event(
				"task_water",
				"小狸帮你浇了田。手抬起来，就知道往哪走。",
				0.45,
				{"plot_id": plot_id, "by_companion": true}
			)
			companion_world_event.emit("companion_watered", {"plot_id": plot_id})
	else:
		today_water_by_player += 1
		if today_water_by_player == 1:
			record_memory_event(
				"water",
				"你浇了田。她在旁边看着。",
				0.4,
				{"plot_id": plot_id, "by_companion": false}
			)
			companion_world_event.emit("player_watered", {"plot_id": plot_id})
	save_game()


func record_chat_turn(role: String, text: String, ephemeral: bool = false) -> void:
	var cleaned := text.strip_edges()
	if cleaned.is_empty():
		return
	var turn := {"role": role, "text": cleaned, "game_day": game_day}
	if ephemeral:
		turn["ephemeral"] = true
	recent_chat_turns.append(turn)
	while recent_chat_turns.size() > MAX_CHAT_TURNS:
		recent_chat_turns.remove_at(0)
	today_chat_log.append(turn.duplicate(true))
	while today_chat_log.size() > MAX_TODAY_CHAT:
		today_chat_log.remove_at(0)
	save_game()


func purge_ephemeral_chat_turns() -> void:
	var kept_recent: Array[Dictionary] = []
	for turn in recent_chat_turns:
		if turn is Dictionary and bool(turn.get("ephemeral", false)):
			continue
		kept_recent.append(turn)
	recent_chat_turns = kept_recent
	var kept_today: Array[Dictionary] = []
	for turn in today_chat_log:
		if turn is Dictionary and bool(turn.get("ephemeral", false)):
			continue
		kept_today.append(turn)
	today_chat_log = kept_today


func get_chat_history_for_ui(limit: int = MAX_CHAT_TURNS) -> Array[Dictionary]:
	## 归档（最多 9 天）+ 今日；继续游戏时应能看到跨日对话。
	var merged: Array[Dictionary] = []
	var archive: Variant = long_term_memory.get("chat_archive", [])
	if archive is Array:
		for raw_day in archive:
			if not raw_day is Dictionary:
				continue
			var turns: Variant = raw_day.get("turns", [])
			if not turns is Array:
				continue
			for turn in turns:
				if turn is Dictionary:
					merged.append(turn.duplicate(true))
	for turn in today_chat_log:
		if turn is Dictionary:
			merged.append(turn.duplicate(true))
	if merged.is_empty() and not recent_chat_turns.is_empty():
		var count := mini(limit, recent_chat_turns.size())
		return recent_chat_turns.slice(recent_chat_turns.size() - count, recent_chat_turns.size())
	if merged.size() > limit:
		return merged.slice(merged.size() - limit, merged.size())
	return merged


func snapshot_today_chat_log() -> Array[Dictionary]:
	return today_chat_log.duplicate(true)


func archive_today_chat_log() -> void:
	var turns := snapshot_today_chat_log()
	if turns.is_empty():
		return
	var archive: Variant = long_term_memory.get("chat_archive", [])
	if not archive is Array:
		archive = []
	archive.append({
		"game_day": game_day,
		"turns": turns,
	})
	while archive.size() > MAX_ARCHIVED_CHAT_DAYS:
		archive.remove_at(0)
	long_term_memory["chat_archive"] = archive


func clear_today_chat_log() -> void:
	today_chat_log.clear()


func patch_day_journal_entry(day: int, patch: Dictionary) -> bool:
	for i in day_journal.size():
		var entry: Variant = day_journal[i]
		if not entry is Dictionary:
			continue
		if int(entry.get("day", -1)) != day:
			continue
		var merged: Dictionary = entry.duplicate(true)
		for key in patch.keys():
			merged[key] = patch[key]
		day_journal[i] = merged
		return true
	return false


func get_day_journal_entry(day: int) -> Dictionary:
	for entry in day_journal:
		if entry is Dictionary and int(entry.get("day", -1)) == day:
			return entry.duplicate(true)
	return {}


func get_recent_chat_turns(limit: int = 8) -> Array[Dictionary]:
	var count := mini(limit, recent_chat_turns.size())
	if count <= 0:
		return []
	return recent_chat_turns.slice(recent_chat_turns.size() - count, recent_chat_turns.size())


func record_player_chat(text: String) -> void:
	if text.strip_edges().is_empty():
		return
	record_chat_turn("player", text)
	RelationshipDirector.record_player_chat_turn(text)
	var importance := 0.45
	if "喜欢" in text or "记住" in text or "约定" in text:
		importance = 0.8
	record_memory_event("chat", "你说：“%s”" % text.strip_edges(), importance, {"text": text.strip_edges()})
	companion_world_event.emit("player_chat", {"text": text.strip_edges()})
	if "慢慢来" in text:
		set_preference("pace", "slow")
	if "喜欢萝卜" in text or "萝卜" in text:
		set_preference("fav_crop", CROP_TURNIP)
	if "约定" in text or "记得告诉我" in text:
		_maybe_set_promise_from_chat(text.strip_edges())


func _maybe_set_promise_from_chat(text: String) -> void:
	if not StoryBeatDirector.is_beat_seen("P_N11") and not StoryBeatDirector.is_beat_seen("BE_N11"):
		return
	var existing: Dictionary = long_term_memory.get("promise", {})
	var existing_id := str(existing.get("id", "")).strip_edges()
	var existing_summary := str(existing.get("summary", "")).strip_edges()
	if existing_summary != "" and existing_id not in ["", "chat_promise"]:
		return
	var line := _extract_promise_from_chat(text)
	if line == "":
		return
	set_promise("chat_promise", line)


func _extract_promise_from_chat(text: String) -> String:
	var cleaned := text.strip_edges()
	if cleaned == "":
		return ""
	for prefix in ["我们约定", "约定", "记得告诉我", "帮我记住"]:
		var idx := cleaned.find(prefix)
		if idx >= 0:
			cleaned = cleaned.substr(idx + prefix.length()).strip_edges()
			break
	cleaned = cleaned.trim_prefix("：").trim_prefix(":").trim_prefix("，").trim_prefix(",").strip_edges()
	cleaned = cleaned.trim_suffix("。").trim_suffix("！").trim_suffix("!").trim_suffix("？").trim_suffix("?").strip_edges()
	if cleaned.length() > 44:
		cleaned = cleaned.substr(0, 44).strip_edges() + "…"
	return cleaned


func set_promise(promise_id: String, summary: String) -> void:
	long_term_memory["promise"] = {
		"id": promise_id,
		"summary": summary,
		"fulfilled": false,
	}
	record_memory_event("promise", "小狸写进本子：%s" % summary, 0.95, {"promise_id": promise_id})


func has_story_promise() -> bool:
	## D3 信纸（P_N11）完成后才视为正式约定；此前 LLM 不得引用。
	if not StoryBeatDirector.is_beat_seen("P_N11") and not StoryBeatDirector.is_beat_seen("BE_N11"):
		return false
	var promise: Dictionary = long_term_memory.get("promise", {})
	return str(promise.get("summary", "")).strip_edges() != ""


func get_story_promise_summary() -> String:
	if not has_story_promise():
		return ""
	var promise: Dictionary = long_term_memory.get("promise", {})
	return str(promise.get("summary", "")).strip_edges()


func fulfill_promise(summary: String) -> void:
	var promise: Dictionary = long_term_memory.get("promise", {})
	if promise.is_empty():
		return
	promise["fulfilled"] = true
	long_term_memory["promise"] = promise
	record_memory_event("promise_done", summary, 1.0, {"promise_id": promise.get("id", "")})


func reset_daily_plots() -> void:
	watered_plots.clear()
	today_water_by_player = 0
	today_water_by_companion = 0
	reset_daily_feed()
	for key in plot_data.keys():
		plot_data[key]["watered"] = false
	save_game()


func advance_day() -> void:
	if not can_advance_day():
		return
	if not has_player_name_set():
		return
	StoryBeatDirector.resolve_soft_paused_beats_before_advance()
	var current_loop_day := get_loop_day()
	var previous_weather := weather_today
	_grow_crops_for_weather(previous_weather)
	var journal_entry := DayJournalService.build_entry(previous_weather)
	var chat_snapshot := snapshot_today_chat_log()
	last_day_summary = str(journal_entry.get("summary", ""))
	append_day_journal(journal_entry)
	DayJournalService.request_llm_enrich(journal_entry, chat_snapshot)
	purge_ephemeral_chat_turns()
	archive_today_chat_log()
	clear_today_chat_log()
	reset_daily_plots()
	game_day += 1
	mood = clampi(mood - 5, 40, 100)
	if not IS_TEN_DAY_EDITION and current_loop_day >= 7 and get_week_index() < STORY_WEEKS:
		_reset_for_new_week()
	weather_today = resolve_weather_for_day(game_day)
	weather_tomorrow_hint = resolve_weather_for_day(game_day + 1)
	time_of_day = TIME_MORNING
	_period_elapsed = 0.0
	_awaiting_sleep = false
	roll_market_for_weather(weather_today)
	_maybe_trigger_reveal()
	regress_persona_toward_baseline()
	PlayerNotebookService.on_day_advanced(game_day)
	day_advanced.emit()
	time_changed.emit(time_of_day)
	atmosphere_changed.emit()
	stats_changed.emit()
	market_changed.emit()
	add_memory_recovery(0.03)
	save_game()


func roll_market_for_weather(weather: String) -> void:
	market_state["turnip_sell_price"] = 12
	market_state["trend"] = "stable"
	match normalize_weather(weather):
		WEATHER_SUN:
			market_state["turnip_seed_price"] = 9
		_:
			market_state["turnip_seed_price"] = 8
	atmosphere_changed.emit()
	market_changed.emit()


func _grow_crops_for_weather(weather: String) -> void:
	var newly_ready: Array[int] = []
	for key in plot_data.keys():
		var plot: Dictionary = plot_data[key]
		var stage := int(plot.get("stage", 0))
		if stage <= 0 or stage >= MATURE_STAGE:
			continue
		var watered := bool(plot.get("watered", false))
		var growth := 0
		match normalize_weather(weather):
			WEATHER_RAIN:
				growth = 1
				plot["watered"] = true
			_:
				growth = 1 if watered else 0
		if growth > 0:
			var new_stage := mini(stage + growth, MATURE_STAGE)
			if stage < MATURE_STAGE and new_stage >= MATURE_STAGE:
				newly_ready.append(int(key))
			plot["stage"] = new_stage

	for plot_id in newly_ready:
		companion_world_event.emit("crop_became_ready", {"plot_id": plot_id})


func append_day_journal(entry: Dictionary) -> void:
	day_journal.append(entry.duplicate(true))
	while day_journal.size() > 7:
		day_journal.remove_at(0)
	var summary := str(entry.get("summary", "")).strip_edges()
	record_memory_event("day_end", summary, 0.6, entry.duplicate(true))


func record_memory_event(kind: String, summary: String, importance: float = 0.5, facts: Dictionary = {}) -> void:
	if kind == "journal_chat":
		if StoryDirector.is_stranger_mode():
			return
		var anchor_day := int(facts.get("game_day", game_day))
		for raw in short_term_memory:
			if raw is Dictionary and str(raw.get("kind", "")) == "journal_chat":
				if int(raw.get("game_day", -1)) == anchor_day:
					return
		var anchors_check: Array = long_term_memory.get("anchors", [])
		for raw in anchors_check:
			if raw is Dictionary and str(raw.get("kind", "")) == "journal_chat":
				if int(raw.get("game_day", -1)) == anchor_day:
					return
	var enriched_facts := facts.duplicate(true)
	var event_day := int(enriched_facts.get("game_day", game_day))
	if not enriched_facts.has("node"):
		match kind:
			"promise", "promise_done":
				enriched_facts["node"] = "N11"
			"harvest":
				enriched_facts["node"] = "N14"
			"gift":
				enriched_facts["node"] = "N07"
	var entry := {
		"id": "%s_%d_%d" % [kind, event_day, short_term_memory.size() + 1],
		"game_day": event_day,
		"week_index": int(enriched_facts.get("week_index", get_week_index())),
		"loop_day": int(enriched_facts.get("loop_day", get_loop_day())),
		"kind": kind,
		"summary": summary,
		"importance": snappedf(clampf(importance, 0.0, 1.0), 0.01),
		"facts": enriched_facts,
	}
	short_term_memory.append(entry)
	while short_term_memory.size() > 12:
		short_term_memory.remove_at(0)
	if importance >= 0.75:
		var anchors: Array = long_term_memory.get("anchors", [])
		anchors.append(entry.duplicate(true))
		long_term_memory["anchors"] = anchors
		MemoryService.enforce_anchor_cap()
	memory_changed.emit()
	save_game()


func _ensure_long_term_defaults() -> void:
	if not long_term_memory.has("prefs"):
		long_term_memory["prefs"] = {"fav_crop": CROP_TURNIP, "time_rhythm": ""}
	if not long_term_memory.has("persona"):
		long_term_memory["persona"] = _default_persona()
	if not long_term_memory.has("behavior_inferred"):
		long_term_memory["behavior_inferred"] = _default_behavior_inferred()
	if not long_term_memory.has("initiations"):
		long_term_memory["initiations"] = []
	if not long_term_memory.has("absence_notes"):
		long_term_memory["absence_notes"] = []
	if not long_term_memory.has("player_busy"):
		long_term_memory["player_busy"] = 0
	if not long_term_memory.has("counters"):
		long_term_memory["counters"] = {
			"plant_count": 0,
			"harvest_count": 0,
			"sell_count": 0,
			"buy_seed_count": 0,
		}
	if not long_term_memory.has("last_play_unix"):
		long_term_memory["last_play_unix"] = 0
	if not long_term_memory.has("anchors"):
		long_term_memory["anchors"] = []
	if not long_term_memory.has("pending_eviction"):
		long_term_memory["pending_eviction"] = {}
	if not long_term_memory.has("persona_shift_announced"):
		long_term_memory["persona_shift_announced"] = []
	if not long_term_memory.has("week_summaries"):
		long_term_memory["week_summaries"] = []
	if not long_term_memory.has("promise"):
		long_term_memory["promise"] = {}
	if not long_term_memory.has("revealed"):
		long_term_memory["revealed"] = false
	if not long_term_memory.has("w2_stranger_seen"):
		long_term_memory["w2_stranger_seen"] = false
	if not long_term_memory.has("awakening_seen"):
		long_term_memory["awakening_seen"] = false
	if not long_term_memory.has("milestones_seen"):
		long_term_memory["milestones_seen"] = []
	if not long_term_memory.has("leaks_seen"):
		long_term_memory["leaks_seen"] = []
	if not long_term_memory.has("memory_recovery"):
		long_term_memory["memory_recovery"] = 0.0
	if not long_term_memory.has("memory_fragments"):
		long_term_memory["memory_fragments"] = []
	if not long_term_memory.has("story_complete"):
		long_term_memory["story_complete"] = false
	if not long_term_memory.has("final_ending_id"):
		long_term_memory["final_ending_id"] = ""
	if not long_term_memory.has("endings_seen"):
		long_term_memory["endings_seen"] = []
	if not long_term_memory.has("story_nodes_seen"):
		long_term_memory["story_nodes_seen"] = []
	if not long_term_memory.has("story_route"):
		long_term_memory["story_route"] = ""
	if not long_term_memory.has("relationship_signals"):
		long_term_memory["relationship_signals"] = {
			"chat_turns": 0,
			"chat_days": 0,
			"last_chat_day": 0,
			"gifts_given": 0,
			"nodes_cleared": 0,
			"tasks_together": 0,
			"llm_affection_net": 0,
			"llm_bond_net": 0,
			"beat_chats": 0,
		}
	if not long_term_memory.has("ending_flags"):
		long_term_memory["ending_flags"] = {
			"w2_chose_keep": true,
			"w2_chose_expel": false,
			"w2_choice_made": false,
			"companionship_nights": 0,
			"f10_skipped": false,
		}
	if not long_term_memory.has("player_name_set"):
		long_term_memory["player_name_set"] = false
	if not long_term_memory.has("pending_story_beat_tail_id"):
		long_term_memory["pending_story_beat_tail_id"] = ""
	if not long_term_memory.has("pending_story_beat_tail_steps"):
		long_term_memory["pending_story_beat_tail_steps"] = []
	if not long_term_memory.has("chat_archive"):
		long_term_memory["chat_archive"] = []
	_sanitize_player_name_legacy()
	_sanitize_story_progress()


func _default_persona() -> Dictionary:
	return {
		"warm": 0.5,
		"strict": 0.5,
		"active": 0.5,
		"optimistic": 0.5,
		"dependent": 0.5,
	}


func _default_behavior_inferred() -> Dictionary:
	return {
		"risk": 0.5,
		"coping": "neutral",
		"absence_days": 0,
	}


func _reset_for_new_week() -> void:
	var completed_week := maxi(1, get_week_index() - 1)
	MemoryService.finalize_week_archive(completed_week, day_journal)
	short_term_memory.clear()
	recent_chat_turns.clear()
	today_chat_log.clear()
	day_journal.clear()
	last_task_summary = ""
	week_reset.emit(get_week_index())
	memory_changed.emit()


func _maybe_trigger_reveal() -> void:
	if has_revealed_memory():
		return
	if has_seen_awakening():
		long_term_memory["revealed"] = true
		memory_changed.emit()
		save_game()


func _next_weather_hint() -> String:
	return resolve_weather_for_day(game_day + 1)


func _sync_weather_to_story_day() -> void:
	weather_today = resolve_weather_for_day(game_day)
	weather_tomorrow_hint = resolve_weather_for_day(game_day + 1)


func _plot_key(plot_id: int) -> String:
	return str(plot_id)


func _empty_plot() -> Dictionary:
	return {
		"crop": "",
		"stage": 0,
		"watered": false,
	}


func _sanitize_player_name_legacy() -> void:
	if bool(long_term_memory.get("player_name_set", false)):
		return
	var cleaned := player_name.strip_edges()
	if cleaned == "" or cleaned == "玩家":
		player_name = ""
		long_term_memory["player_name_set"] = false
	elif cleaned != "":
		long_term_memory["player_name_set"] = true


func _sanitize_story_progress() -> void:
	var flags := get_ending_flags()
	var dirty := false

	# D1–D9 不应已做 W2 抉择或锁定终局路线（常见于脏存档 / 测试残留）
	if game_day <= 9:
		if bool(flags.get("w2_choice_made", false)):
			flags["w2_choice_made"] = false
			dirty = true
		if get_story_route() != "" and not bool(flags.get("w2_chose_expel", false)):
			long_term_memory["story_route"] = ""
			dirty = true

	# D10：未过 P_N06p 节点则 W2 抉择无效
	if game_day == 10 and bool(flags.get("w2_choice_made", false)):
		if not is_story_node_seen("P_N06p") and not is_story_node_seen("N06p"):
			flags["w2_choice_made"] = false
			if get_story_route() != "":
				long_term_memory["story_route"] = ""
			dirty = true

	var seen: Variant = long_term_memory.get("story_nodes_seen", [])
	if seen is Array:
		var seen_dirty := false
		for i in seen.size():
			if str(seen[i]) == "N06p":
				seen[i] = "P_N06p"
				seen_dirty = true
		if seen_dirty:
			long_term_memory["story_nodes_seen"] = seen
			dirty = true

	if dirty:
		long_term_memory["ending_flags"] = flags

	if game_day < FINAL_GAME_DAY and bool(long_term_memory.get("story_complete", false)):
		long_term_memory["story_complete"] = false


func _ensure_runtime_defaults() -> void:
	_ensure_weather_seed()
	_sync_weather_to_story_day()
	weather_today = normalize_weather(weather_today)
	weather_tomorrow_hint = normalize_weather(weather_tomorrow_hint)
	if not TIME_ORDER.has(time_of_day):
		time_of_day = TIME_MORNING
	elif time_of_day == TIME_NOON:
		time_of_day = TIME_MORNING
	if market_state.is_empty():
		roll_market_for_weather(weather_today)
	_ensure_long_term_defaults()


func has_save_file() -> bool:
	if FileAccess.file_exists(get_save_path()):
		return true
	return not _legacy_save_abs_paths().is_empty()


func ensure_save_migrated() -> bool:
	if FileAccess.file_exists(get_save_path()):
		return true
	var best_path := ""
	var best_day := -1
	for path in _legacy_save_abs_paths():
		var day := _peek_game_day_from_abs(path)
		if day > best_day:
			best_day = day
			best_path = path
	if best_path.is_empty():
		return false
	var content := FileAccess.get_file_as_string(best_path)
	if content.is_empty():
		return false
	var file := FileAccess.open(get_save_path(), FileAccess.WRITE)
	if file == null:
		return false
	file.store_string(content)
	file.close()
	return true


func delete_save_file() -> void:
	var path := ProjectSettings.globalize_path(get_save_path())
	if FileAccess.file_exists(get_save_path()):
		DirAccess.remove_absolute(path)
	for legacy in _legacy_save_abs_paths():
		if FileAccess.file_exists(legacy):
			DirAccess.remove_absolute(legacy)


func start_new_game_fresh() -> void:
	delete_save_file()
	reset_for_new_game()


func continue_from_save() -> void:
	if not ensure_save_migrated():
		return
	load_game()
	_ensure_runtime_defaults()
	atmosphere_changed.emit()
	stats_changed.emit()
	memory_changed.emit()
	time_changed.emit(time_of_day)
	market_changed.emit()


func get_save_path() -> String:
	return "user://%s" % SAVE_FILE_NAME


func _app_userdata_root() -> String:
	return OS.get_user_data_dir().get_base_dir()


func _legacy_save_abs_paths() -> Array[String]:
	var paths: Array[String] = []
	var current := ProjectSettings.globalize_path(get_save_path())
	var root := _app_userdata_root()
	for dir_name in LEGACY_USER_DIRS:
		var abs_path := root.path_join(dir_name).path_join(SAVE_FILE_NAME)
		if abs_path == current:
			continue
		if FileAccess.file_exists(abs_path):
			paths.append(abs_path)
	return paths


func _peek_game_day_from_abs(abs_path: String) -> int:
	var file := FileAccess.open(abs_path, FileAccess.READ)
	if file == null:
		return -1
	var parsed: Variant = JSON.parse_string(file.get_as_text())
	file.close()
	if typeof(parsed) != TYPE_DICTIONARY:
		return -1
	return int(parsed.get("game_day", -1))


func _duplicate_dict_array(source: Array) -> Array[Dictionary]:
	var result: Array[Dictionary] = []
	for item in source:
		if item is Dictionary:
			result.append(item.duplicate(true))
	return result


func _load_audio_prefs() -> void:
	if not FileAccess.file_exists(AUDIO_PREFS_PATH):
		return
	var file := FileAccess.open(AUDIO_PREFS_PATH, FileAccess.READ)
	if file == null:
		return
	var parsed: Variant = JSON.parse_string(file.get_as_text())
	file.close()
	if parsed is not Dictionary:
		return
	var data: Dictionary = parsed
	bgm_volume_linear = clampf(float(data.get("bgm_volume_linear", bgm_volume_linear)), 0.0, 1.0)
	ambient_volume_linear = clampf(float(data.get("ambient_volume_linear", ambient_volume_linear)), 0.0, 1.0)
	# 早期滑条误触会存 0，导致桌面端「完全没 BGM / 雨声」。
	if bgm_volume_linear <= 0.001:
		bgm_volume_linear = 1.0
	if ambient_volume_linear <= 0.001:
		ambient_volume_linear = 1.0


func _save_audio_prefs() -> void:
	var file := FileAccess.open(AUDIO_PREFS_PATH, FileAccess.WRITE)
	if file == null:
		return
	file.store_string(JSON.stringify({
		"bgm_volume_linear": bgm_volume_linear,
		"ambient_volume_linear": ambient_volume_linear,
	}, "\t"))
	file.close()


func set_bgm_volume_linear(value: float) -> void:
	bgm_volume_linear = clampf(value, 0.0, 1.0)
	_save_audio_prefs()
	if BgmDirector.has_method("apply_volume_preference"):
		BgmDirector.apply_volume_preference()


func set_ambient_volume_linear(value: float) -> void:
	ambient_volume_linear = clampf(value, 0.0, 1.0)
	_save_audio_prefs()
	if AmbientAudio.has_method("apply_volume_preference"):
		AmbientAudio.apply_volume_preference()


func save_game() -> void:
	var data := {
		"save_version": SAVE_VERSION,
		"player_name": player_name,
		"companion_name": companion_name,
		"game_day": game_day,
		"affection": affection,
		"bond": bond,
		"mood": mood,
		"coins": coins,
		"weather_today": weather_today,
		"weather_tomorrow_hint": weather_tomorrow_hint,
		"weather_seed": weather_seed,
		"time_of_day": time_of_day,
		"market_state": market_state.duplicate(true),
		"inventory": inventory.duplicate(),
		"plot_data": plot_data.duplicate(true),
		"farm_plot_count": farm_plot_count,
		"watered_plots": watered_plots,
		"last_task_summary": last_task_summary,
		"last_day_summary": last_day_summary,
		"short_term_memory": short_term_memory.duplicate(true),
		"recent_chat_turns": recent_chat_turns.duplicate(true),
		"today_chat_log": today_chat_log.duplicate(true),
		"feeds_today": feeds_today,
		"feed_pester_count": feed_pester_count,
		"today_feed_replies": today_feed_replies.duplicate(),
		"day_journal": day_journal.duplicate(true),
		"long_term_memory": long_term_memory.duplicate(true),
	}
	var file := FileAccess.open(get_save_path(), FileAccess.WRITE)
	if file:
		file.store_string(JSON.stringify(data, "\t"))
		file.close()


func load_game() -> void:
	ensure_save_migrated()
	if not FileAccess.file_exists(get_save_path()):
		roll_market_for_weather(weather_today)
		weather_tomorrow_hint = _next_weather_hint()
		return

	var file := FileAccess.open(get_save_path(), FileAccess.READ)
	if not file:
		return

	var parsed: Variant = JSON.parse_string(file.get_as_text())
	file.close()
	if typeof(parsed) != TYPE_DICTIONARY:
		return

	var data: Dictionary = parsed
	player_name = str(data.get("player_name", player_name))
	companion_name = str(data.get("companion_name", companion_name))
	game_day = int(data.get("game_day", game_day))
	affection = int(data.get("affection", affection))
	bond = int(data.get("bond", bond))
	mood = int(data.get("mood", mood))
	last_task_summary = str(data.get("last_task_summary", ""))
	last_day_summary = str(data.get("last_day_summary", ""))
	weather_today = normalize_weather(str(data.get("weather_today", weather_today)))
	weather_tomorrow_hint = normalize_weather(str(data.get("weather_tomorrow_hint", weather_tomorrow_hint)))
	weather_seed = int(data.get("weather_seed", weather_seed))
	time_of_day = str(data.get("time_of_day", time_of_day))
	_period_elapsed = 0.0

	if data.has("coins"):
		coins = int(data.get("coins", coins))

	if data.has("market_state"):
		var saved_market: Variant = data.get("market_state")
		if saved_market is Dictionary:
			market_state = saved_market.duplicate(true)

	if data.has("inventory"):
		var saved_inventory: Variant = data.get("inventory")
		if saved_inventory is Dictionary:
			inventory = saved_inventory.duplicate()

	if data.has("plot_data"):
		var saved_plots: Variant = data.get("plot_data")
		if saved_plots is Dictionary:
			plot_data = saved_plots.duplicate(true)
	for key in plot_data.keys():
		ensure_plot(int(key))

	farm_plot_count = int(data.get("farm_plot_count", farm_plot_count))

	if data.has("short_term_memory"):
		var saved_short: Variant = data.get("short_term_memory")
		if saved_short is Array:
			short_term_memory = _duplicate_dict_array(saved_short)

	if data.has("recent_chat_turns"):
		var saved_chat: Variant = data.get("recent_chat_turns")
		if saved_chat is Array:
			recent_chat_turns = _duplicate_dict_array(saved_chat)

	if data.has("today_chat_log"):
		var saved_today_chat: Variant = data.get("today_chat_log")
		if saved_today_chat is Array:
			today_chat_log = _duplicate_dict_array(saved_today_chat)

	feeds_today = int(data.get("feeds_today", feeds_today))
	feed_pester_count = int(data.get("feed_pester_count", feed_pester_count))
	if data.has("today_feed_replies"):
		var saved_feed_replies: Variant = data.get("today_feed_replies")
		if saved_feed_replies is Array:
			today_feed_replies.clear()
			for line in saved_feed_replies:
				var cleaned := str(line).strip_edges()
				if cleaned != "":
					today_feed_replies.append(cleaned)

	if data.has("day_journal"):
		var saved_journal: Variant = data.get("day_journal")
		if saved_journal is Array:
			day_journal = _duplicate_dict_array(saved_journal)

	if data.has("long_term_memory"):
		var saved_long: Variant = data.get("long_term_memory")
		if saved_long is Dictionary:
			long_term_memory = saved_long.duplicate(true)

	var plots: Variant = data.get("watered_plots", [])
	watered_plots.clear()
	if plots is Array:
		for plot_id in plots:
			watered_plots.append(int(plot_id))

	_ensure_runtime_defaults()
	stats_changed.emit()
