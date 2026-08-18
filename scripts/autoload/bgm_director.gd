extends Node
## 全局 BGM：标题页固定白天；主场景按 GameState 时段切换日/夜。

const DAY_BGM_PATH := "res://白天bgm.mp3"
const NIGHT_BGM_PATH := "res://夜晚bgm.mp3"
const DEFAULT_VOLUME_DB := -4.0
const FADE_SEC := 0.8

var _player: AudioStreamPlayer
var _day_stream: AudioStream
var _night_stream: AudioStream
var _current_mode := ""
var _fade_tween: Tween
var _sleep_hold := false
var _web_unlocked := false


func _ready() -> void:
	_player = AudioStreamPlayer.new()
	_player.name = "BgmPlayer"
	_player.volume_db = DEFAULT_VOLUME_DB
	_player.bus = &"Master"
	_player.process_mode = Node.PROCESS_MODE_ALWAYS
	add_child(_player)
	if not _player.finished.is_connected(_on_player_finished):
		_player.finished.connect(_on_player_finished)

	_day_stream = _load_looping_stream(DAY_BGM_PATH)
	_night_stream = _load_looping_stream(NIGHT_BGM_PATH)
	if _day_stream == null:
		push_warning("BgmDirector: 未找到 %s" % DAY_BGM_PATH)
	if _night_stream == null:
		push_warning("BgmDirector: 未找到 %s" % NIGHT_BGM_PATH)

	if not OS.has_feature("web"):
		_web_unlocked = true

	process_mode = Node.PROCESS_MODE_ALWAYS

	if not GameState.time_changed.is_connected(_on_time_changed):
		GameState.time_changed.connect(_on_time_changed)
	if not GameState.atmosphere_changed.is_connected(_on_atmosphere_changed):
		GameState.atmosphere_changed.connect(_on_atmosphere_changed)

	var tree := get_tree()
	if not tree.scene_changed.is_connected(_on_scene_changed):
		tree.scene_changed.connect(_on_scene_changed)

	call_deferred("_refresh_for_current_context")
	call_deferred("apply_volume_preference")


func ensure_unlocked() -> void:
	if _web_unlocked:
		return
	_web_unlocked = true
	ensure_playing()


func ensure_playing() -> void:
	if _sleep_hold or not _web_unlocked:
		return
	if _should_mute_for_rain():
		_stop_bgm_for_rain()
		return
	if GameState.bgm_volume_linear <= 0.001:
		return
	if _player != null and _player.playing and _player.stream != null:
		_player.volume_db = _effective_bgm_db()
		return
	call_deferred("_refresh_for_current_context")


func is_audible() -> bool:
	return (
		_player != null
		and _player.playing
		and _player.stream != null
		and GameState.bgm_volume_linear > 0.001
		and _player.volume_db > -60.0
		and not _sleep_hold
	)


func get_debug_state() -> Dictionary:
	return {
		"playing": _player.playing if _player != null else false,
		"stream": str(_player.stream) if _player != null else "",
		"volume_db": _player.volume_db if _player != null else 0.0,
		"mode": _current_mode,
		"sleep_hold": _sleep_hold,
		"web_unlocked": _web_unlocked,
		"bgm_linear": GameState.bgm_volume_linear,
		"scene": get_tree().current_scene.scene_file_path if get_tree().current_scene else "",
	}


func apply_volume_preference() -> void:
	if _player == null:
		return
	_player.volume_db = _effective_bgm_db()
	if GameState.bgm_volume_linear <= 0.001:
		if _player.playing:
			_player.stop()
		return
	ensure_playing()


func _on_player_finished() -> void:
	if _sleep_hold or _player == null or _player.stream == null:
		return
	if GameState.bgm_volume_linear <= 0.001:
		return
	_player.play()


func _effective_bgm_db(offset_db: float = 0.0) -> float:
	var linear := GameState.bgm_volume_linear
	if linear <= 0.001:
		return -80.0
	return DEFAULT_VOLUME_DB + linear_to_db(linear) + offset_db


func _load_looping_stream(path: String) -> AudioStream:
	if not ResourceLoader.exists(path):
		return null
	var stream: AudioStream = load(path)
	if stream == null:
		return null
	if stream is AudioStreamMP3:
		var mp3 := stream as AudioStreamMP3
		mp3.loop = true
		return mp3
	return stream


func stop_for_sleep(immediate: bool = false) -> void:
	_sleep_hold = true
	if _fade_tween != null and _fade_tween.is_valid():
		_fade_tween.kill()
	if not _player.playing:
		return
	if immediate:
		_player.stop()
		_player.volume_db = _effective_bgm_db()
		return
	_fade_tween = create_tween()
	_fade_tween.tween_property(_player, "volume_db", -40.0, FADE_SEC * 0.5)
	_fade_tween.tween_callback(func() -> void:
		_player.stop()
	)


func resume_after_sleep() -> void:
	_sleep_hold = false
	if _should_mute_for_rain():
		_stop_bgm_for_rain()
		return
	_apply_mode(resume_mode_after_sleep(), true)


static func resume_mode_after_sleep() -> String:
	return "night" if GameState.is_night() else "day"


func duck_for_stinger(hold_sec: float) -> void:
	if _player == null or not _player.playing:
		return
	if _fade_tween != null and _fade_tween.is_valid():
		_fade_tween.kill()
	var target_db := _effective_bgm_db(-9.0)
	_fade_tween = create_tween()
	_fade_tween.tween_property(_player, "volume_db", target_db, 0.35)
	_fade_tween.tween_interval(maxi(hold_sec - 0.7, 0.2))
	_fade_tween.tween_property(_player, "volume_db", _effective_bgm_db(), 0.65)


func resume_day_after_sleep() -> void:
	resume_after_sleep()


func _on_scene_changed() -> void:
	call_deferred("_refresh_for_current_context")


func _on_time_changed(_time_of_day: String) -> void:
	if _sleep_hold:
		return
	if _should_mute_for_rain():
		_stop_bgm_for_rain()
		return
	if _is_main_game_scene():
		_apply_mode(_mode_for_game_time())


func _on_atmosphere_changed() -> void:
	if _sleep_hold:
		return
	if _should_mute_for_rain():
		_stop_bgm_for_rain()
		return
	if _is_main_game_scene():
		_apply_mode(_mode_for_game_time(), true)
	elif _is_title_scene():
		_apply_mode("day", true)


func _refresh_for_current_context() -> void:
	if _sleep_hold or not _web_unlocked:
		return
	if _should_mute_for_rain():
		_stop_bgm_for_rain()
		return
	if _is_title_scene():
		_apply_mode("day")
	elif _is_main_game_scene():
		_apply_mode(_mode_for_game_time())


func _should_mute_for_rain() -> bool:
	return _is_main_game_scene() and GameState.weather_today == GameState.WEATHER_RAIN


func _stop_bgm_for_rain() -> void:
	if _player == null:
		return
	if _fade_tween != null and _fade_tween.is_valid():
		_fade_tween.kill()
	if _player.playing:
		_player.stop()


func _mode_for_game_time() -> String:
	return "night" if GameState.is_night() else "day"


func _is_title_scene() -> bool:
	var scene := get_tree().current_scene
	return scene != null and scene.scene_file_path.ends_with("title_screen.tscn")


func _is_main_game_scene() -> bool:
	var scene := get_tree().current_scene
	return scene != null and scene.scene_file_path.ends_with("main.tscn")


func _apply_mode(mode: String, force_restart: bool = false) -> void:
	var stream := _night_stream if mode == "night" else _day_stream
	if stream == null:
		return
	if not force_restart and _current_mode == mode and _player.playing and _player.stream != null:
		_player.volume_db = _effective_bgm_db()
		return

	_current_mode = mode
	if force_restart or not _player.playing:
		if _fade_tween != null and _fade_tween.is_valid():
			_fade_tween.kill()
		_player.stream = stream
		_player.volume_db = _effective_bgm_db()
		_player.play()
		return

	if _fade_tween != null and _fade_tween.is_valid():
		_fade_tween.kill()
	_fade_tween = create_tween()
	_fade_tween.tween_property(_player, "volume_db", -40.0, FADE_SEC * 0.5)
	_fade_tween.tween_callback(func() -> void:
		_player.stream = stream
		_player.play()
	)
	_fade_tween.tween_property(_player, "volume_db", _effective_bgm_db(), FADE_SEC * 0.5)
