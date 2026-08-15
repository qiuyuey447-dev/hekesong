extends Node
## 全局 BGM：标题页固定白天；主场景按 GameState 时段切换日/夜。

const DAY_BGM_PATH := "res://白天bgm.mp3"
const NIGHT_BGM_PATH := "res://夜晚bgm.mp3"
const DEFAULT_VOLUME_DB := -8.0
const FADE_SEC := 0.8

var _player: AudioStreamPlayer
var _day_stream: AudioStream
var _night_stream: AudioStream
var _current_mode := ""
var _fade_tween: Tween
var _sleep_hold := false


func _ready() -> void:
	_player = AudioStreamPlayer.new()
	_player.name = "BgmPlayer"
	_player.volume_db = DEFAULT_VOLUME_DB
	add_child(_player)

	_day_stream = _load_looping_stream(DAY_BGM_PATH)
	_night_stream = _load_looping_stream(NIGHT_BGM_PATH)
	if _day_stream == null:
		push_warning("BgmDirector: 未找到 %s" % DAY_BGM_PATH)
	if _night_stream == null:
		push_warning("BgmDirector: 未找到 %s" % NIGHT_BGM_PATH)

	if not GameState.time_changed.is_connected(_on_time_changed):
		GameState.time_changed.connect(_on_time_changed)

	var tree := get_tree()
	if not tree.scene_changed.is_connected(_on_scene_changed):
		tree.scene_changed.connect(_on_scene_changed)

	call_deferred("_refresh_for_current_context")


func _load_looping_stream(path: String) -> AudioStream:
	if not ResourceLoader.exists(path):
		return null
	var stream: AudioStream = load(path)
	if stream == null:
		return null
	if stream is AudioStreamMP3:
		var looped := (stream as AudioStreamMP3).duplicate()
		looped.loop = true
		return looped
	return stream


func stop_for_sleep(immediate: bool = false) -> void:
	_sleep_hold = true
	if _fade_tween != null and _fade_tween.is_valid():
		_fade_tween.kill()
	if not _player.playing:
		return
	if immediate:
		_player.stop()
		_player.volume_db = DEFAULT_VOLUME_DB
		return
	_fade_tween = create_tween()
	_fade_tween.tween_property(_player, "volume_db", -40.0, FADE_SEC * 0.5)
	_fade_tween.tween_callback(func() -> void:
		_player.stop()
	)


func resume_day_after_sleep() -> void:
	_sleep_hold = false
	_apply_mode("day", true)


func _on_scene_changed() -> void:
	call_deferred("_refresh_for_current_context")


func _on_time_changed(_time_of_day: String) -> void:
	if _sleep_hold:
		return
	if _is_main_game_scene():
		_apply_mode(_mode_for_game_time())


func _refresh_for_current_context() -> void:
	if _sleep_hold:
		return
	if _is_title_scene():
		_apply_mode("day")
	elif _is_main_game_scene():
		_apply_mode(_mode_for_game_time())


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
	if not force_restart and _current_mode == mode and _player.playing:
		return

	_current_mode = mode
	if force_restart or not _player.playing:
		if _fade_tween != null and _fade_tween.is_valid():
			_fade_tween.kill()
		_player.stream = stream
		_player.volume_db = DEFAULT_VOLUME_DB
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
	_fade_tween.tween_property(_player, "volume_db", DEFAULT_VOLUME_DB, FADE_SEC * 0.5)
