extends Node
## 环境音与叙事短 stinger。雨天循环雨声（优先 rain.ogg / rain.flac）。

const RAIN_STREAM_CANDIDATES := [
	"res://assets/audio/rain.ogg",
	"res://assets/audio/rain.flac",
	"res://雨声.flac",
]
const RAIN_VOLUME_DB := -2.0
const RAIN_SHELTER_VOLUME_DB := -8.0
const STINGER_VOLUME_DB := -14.0
const SFX_VOLUME_DB := -18.0

var _rain_player: AudioStreamPlayer
var _stinger_player: AudioStreamPlayer
var _sfx_player: AudioStreamPlayer
var _rain_active := false
var _rain_sheltered := false
var _web_unlocked := false
var _rain_stream_ready := false


func _ready() -> void:
	_rain_player = AudioStreamPlayer.new()
	_rain_player.name = "RainAmbient"
	_rain_player.volume_db = RAIN_VOLUME_DB
	_rain_player.bus = &"Master"
	_rain_player.process_mode = Node.PROCESS_MODE_ALWAYS
	add_child(_rain_player)
	if not _rain_player.finished.is_connected(_on_rain_finished):
		_rain_player.finished.connect(_on_rain_finished)

	_stinger_player = AudioStreamPlayer.new()
	_stinger_player.name = "NarrativeStinger"
	_stinger_player.volume_db = STINGER_VOLUME_DB
	_stinger_player.bus = &"Master"
	add_child(_stinger_player)

	_sfx_player = AudioStreamPlayer.new()
	_sfx_player.name = "PropSfx"
	_sfx_player.volume_db = SFX_VOLUME_DB
	_sfx_player.bus = &"Master"
	add_child(_sfx_player)

	if not OS.has_feature("web"):
		_web_unlocked = true

	if not GameState.atmosphere_changed.is_connected(_sync_weather_rain):
		GameState.atmosphere_changed.connect(_sync_weather_rain)

	call_deferred("_init_rain_stream")
	call_deferred("apply_volume_preference")
	call_deferred("_sync_weather_rain")


func apply_volume_preference() -> void:
	var linear := GameState.ambient_volume_linear
	if _rain_player != null:
		var rain_base := RAIN_SHELTER_VOLUME_DB if _rain_sheltered else RAIN_VOLUME_DB
		_rain_player.volume_db = _effective_ambient_db(rain_base, linear)
	if _stinger_player != null:
		_stinger_player.volume_db = _effective_ambient_db(STINGER_VOLUME_DB, linear)
	if _sfx_player != null:
		_sfx_player.volume_db = _effective_ambient_db(SFX_VOLUME_DB, linear)


func _effective_ambient_db(base_db: float, linear: float = -1.0) -> float:
	if linear < 0.0:
		linear = GameState.ambient_volume_linear
	if linear <= 0.001:
		return -80.0
	return base_db + linear_to_db(linear)


func ensure_unlocked() -> void:
	if _web_unlocked:
		_sync_rain_playback()
		return
	_web_unlocked = true
	_sync_rain_playback()


func set_rain_active(on: bool) -> void:
	_rain_active = on
	_ensure_rain_stream()
	if _rain_player == null:
		return
	if on:
		_apply_rain_volume()
		_sync_rain_playback()
	elif _rain_player.playing:
		_rain_player.stop()
	if not on:
		set_rain_sheltered(false)


func set_rain_sheltered(sheltered: bool) -> void:
	if sheltered == _rain_sheltered or _rain_player == null:
		return
	_rain_sheltered = sheltered
	if _rain_active:
		_apply_rain_volume()


func is_rain_playing() -> bool:
	return _rain_player != null and _rain_player.playing


func play_prop_sfx(kind: String) -> void:
	if not _web_unlocked or _sfx_player == null:
		return
	var stream := _make_prop_sfx(kind)
	if stream == null:
		return
	_sfx_player.stream = stream
	_sfx_player.play()


func play_narrative_stinger(kind: String) -> void:
	if not _web_unlocked:
		return
	var stream := _make_stinger(kind)
	if stream == null or _stinger_player == null:
		return
	_stinger_player.stream = stream
	_stinger_player.play()
	if not _is_rainy_main_scene():
		BgmDirector.duck_for_stinger(_stinger_duration(kind))


func stinger_for_beat(beat_id: String) -> String:
	var id := beat_id.strip_edges()
	if id in ["P_N05", "BE_N05"]:
		return "d4_stranger"
	if id in ["N16", "P_N16", "BE_N16"] or id.contains("N16"):
		return "d7_night"
	if GameState.game_day >= 10 or id.contains("awakening"):
		return "d10_awakening"
	return ""


func _stinger_duration(kind: String) -> float:
	match kind:
		"d10_awakening":
			return 14.0
		"d7_night":
			return 11.0
		_:
			return 10.0


func _sync_weather_rain() -> void:
	set_rain_active(GameState.weather_today == GameState.WEATHER_RAIN)


func _init_rain_stream() -> void:
	_ensure_rain_stream()
	_sync_rain_playback()


func _ensure_rain_stream() -> void:
	if _rain_stream_ready and _rain_player.stream != null:
		return
	var stream := _load_rain_stream()
	if stream == null:
		push_warning("AmbientAudio: rain asset missing, using procedural fallback")
		stream = _make_rain_loop(2.4)
	_rain_player.stream = stream
	_rain_stream_ready = true


func _sync_rain_playback() -> void:
	if not _rain_active or _rain_player == null or _rain_player.stream == null:
		return
	if OS.has_feature("web") and not _web_unlocked:
		return
	if not _rain_player.playing:
		_rain_player.play()


func _apply_rain_volume() -> void:
	if _rain_player == null:
		return
	var rain_base := RAIN_SHELTER_VOLUME_DB if _rain_sheltered else RAIN_VOLUME_DB
	_rain_player.volume_db = _effective_ambient_db(rain_base)


func _on_rain_finished() -> void:
	_sync_rain_playback()


func _is_rainy_main_scene() -> bool:
	if GameState.weather_today != GameState.WEATHER_RAIN:
		return false
	var scene := get_tree().current_scene
	return scene != null and scene.scene_file_path.ends_with("main.tscn")


func _load_rain_stream() -> AudioStream:
	for path in RAIN_STREAM_CANDIDATES:
		var stream := _load_looping_stream(path)
		if stream != null:
			return stream
	return null


func _load_looping_stream(path: String) -> AudioStream:
	if not FileAccess.file_exists(path) and not ResourceLoader.exists(path):
		return null
	var stream: AudioStream = ResourceLoader.load(path, "", ResourceLoader.CACHE_MODE_REUSE)
	if stream == null:
		stream = load(path)
	if stream == null:
		return null
	if stream is AudioStreamMP3:
		(stream as AudioStreamMP3).loop = true
	elif stream is AudioStreamOggVorbis:
		(stream as AudioStreamOggVorbis).loop = true
	elif stream is AudioStreamWAV:
		(stream as AudioStreamWAV).loop_mode = AudioStreamWAV.LOOP_FORWARD
	elif "loop" in stream:
		stream.set("loop", true)
	return stream


func _make_rain_loop(duration_sec: float) -> AudioStreamWAV:
	var sample_rate := 22050
	var count := int(sample_rate * duration_sec)
	var data := PackedByteArray()
	data.resize(count * 2)
	var rng := RandomNumberGenerator.new()
	rng.seed = 9042
	var smooth := 0.0
	for i in count:
		var raw := rng.randf_range(-1.0, 1.0)
		smooth = lerpf(smooth, raw, 0.08)
		var sample := int(clampf(smooth * 24000.0, -32768.0, 32767.0))
		data[i * 2] = sample & 0xFF
		data[i * 2 + 1] = (sample >> 8) & 0xFF
	var wav := AudioStreamWAV.new()
	wav.format = AudioStreamWAV.FORMAT_16_BITS
	wav.stereo = false
	wav.mix_rate = sample_rate
	wav.loop_mode = AudioStreamWAV.LOOP_FORWARD
	wav.data = data
	return wav


func _make_stinger(kind: String) -> AudioStreamWAV:
	var notes: Array[float] = []
	match kind:
		"d4_stranger":
			notes = [220.0, 261.63, 329.63]
		"d7_night":
			notes = [196.0, 246.94, 293.66]
		"d10_awakening":
			notes = [164.81, 220.0, 261.63, 329.63]
		_:
			notes = [220.0, 277.18]
	var sample_rate := 22050
	var per_note := int(sample_rate * 0.36)
	var gap := int(sample_rate * 0.05)
	var tail := int(sample_rate * 0.28)
	var count := notes.size() * per_note + maxi(notes.size() - 1, 0) * gap + tail
	var data := PackedByteArray()
	data.resize(count * 2)
	var write_idx := 0
	var t := 0.0
	var dt := 1.0 / float(sample_rate)
	for note_i in range(notes.size()):
		var freq := notes[note_i]
		for j in range(per_note):
			if write_idx >= count:
				break
			var env := sin(PI * float(j) / float(maxi(per_note - 1, 1)))
			var sample := sin(TAU * freq * t) * env * 0.38
			var s16 := int(clampf(sample * 32767.0, -32768.0, 32767.0))
			data[write_idx * 2] = s16 & 0xFF
			data[write_idx * 2 + 1] = (s16 >> 8) & 0xFF
			t += dt
			write_idx += 1
		write_idx += gap
		t += float(gap) * dt
	while write_idx < count:
		var fade := 1.0 - float(write_idx - (count - tail)) / float(maxi(tail, 1))
		fade = clampf(fade, 0.0, 1.0)
		var sample := sin(TAU * notes[notes.size() - 1] * t) * fade * 0.12
		var s16 := int(clampf(sample * 32767.0, -32768.0, 32767.0))
		data[write_idx * 2] = s16 & 0xFF
		data[write_idx * 2 + 1] = (s16 >> 8) & 0xFF
		t += dt
		write_idx += 1
	var wav := AudioStreamWAV.new()
	wav.format = AudioStreamWAV.FORMAT_16_BITS
	wav.stereo = false
	wav.mix_rate = sample_rate
	wav.loop_mode = AudioStreamWAV.LOOP_DISABLED
	wav.data = data
	return wav


func _make_prop_sfx(kind: String) -> AudioStreamWAV:
	var sample_rate := 22050
	var count := int(sample_rate * 0.12)
	if kind == "water":
		count = int(sample_rate * 0.18)
	var data := PackedByteArray()
	data.resize(count * 2)
	var rng := RandomNumberGenerator.new()
	rng.seed = int(hash(kind)) & 0x7fffffff
	var smooth := 0.0
	for i in count:
		var env := 1.0 - float(i) / float(maxi(count - 1, 1))
		if kind == "page":
			env *= sin(PI * float(i) / float(maxi(count - 1, 1)))
		var raw := rng.randf_range(-1.0, 1.0)
		smooth = lerpf(smooth, raw, 0.22 if kind == "water" else 0.35)
		var amp := 0.28 if kind == "page" else 0.42
		var sample := int(clampf(smooth * amp * env * 32767.0, -32768.0, 32767.0))
		data[i * 2] = sample & 0xFF
		data[i * 2 + 1] = (sample >> 8) & 0xFF
	var wav := AudioStreamWAV.new()
	wav.format = AudioStreamWAV.FORMAT_16_BITS
	wav.stereo = false
	wav.mix_rate = sample_rate
	wav.loop_mode = AudioStreamWAV.LOOP_DISABLED
	wav.data = data
	return wav
