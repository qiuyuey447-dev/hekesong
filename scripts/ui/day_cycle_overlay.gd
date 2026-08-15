class_name DayCycleOverlay
extends CanvasLayer
## 夜晚结束提示、睡觉渐黑、新一天开场卡（自动渐亮，无需确认）。

signal sleep_now_pressed
signal day_opening_finished

const FADE_TO_BLACK_SEC := 1.1
const FADE_FROM_BLACK_SEC := 0.9
const HOLD_BLACK_SEC := 0.35
const DAY_CARD_HOLD_SEC := 1.6
const DAY_CARD_FADE_OUT_SEC := 0.35

var _fade: ColorRect
var _sleep_panel: PanelContainer
var _day_panel: PanelContainer
var _day_title: Label
var _day_body: Label
var _busy := false
var _prompt_visible := false
var _tween: Tween


func _ready() -> void:
	layer = 60
	process_mode = Node.PROCESS_MODE_ALWAYS
	_fade = ColorRect.new()
	_fade.set_anchors_preset(Control.PRESET_FULL_RECT)
	_fade.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_fade.color = Color(0.02, 0.03, 0.06, 0.0)
	add_child(_fade)
	_build_sleep_panel()
	_build_day_panel()
	_sleep_panel.visible = false
	_day_panel.visible = false


func is_busy() -> bool:
	return _busy


func is_prompt_visible() -> bool:
	return _prompt_visible and _sleep_panel.visible


func show_sleep_prompt() -> void:
	if _busy or _prompt_visible:
		return
	BgmDirector.stop_for_sleep(true)
	_prompt_visible = true
	_fade.color = Color(0.02, 0.03, 0.06, 0.52)
	_fade.mouse_filter = Control.MOUSE_FILTER_STOP
	_sleep_panel.visible = true
	_sleep_panel.modulate.a = 0.0
	_sleep_panel.scale = Vector2(0.96, 0.96)
	move_child(_sleep_panel, get_child_count() - 1)
	call_deferred("_finalize_sleep_prompt_layout")
	var intro := create_tween()
	intro.set_parallel(true)
	intro.tween_property(_sleep_panel, "modulate:a", 1.0, 0.28)
	intro.tween_property(_sleep_panel, "scale", Vector2.ONE, 0.28).set_trans(Tween.TRANS_BACK).set_ease(Tween.EASE_OUT)


func _finalize_sleep_prompt_layout() -> void:
	if not _sleep_panel.visible:
		return
	_sleep_panel.pivot_offset = _sleep_panel.size * 0.5


func hide_sleep_prompt() -> void:
	_prompt_visible = false
	_sleep_panel.visible = false
	if not _busy:
		_fade.color = Color(0.02, 0.03, 0.06, 0.0)
		_fade.mouse_filter = Control.MOUSE_FILTER_IGNORE


func run_sleep_sequence(advance_callback: Callable) -> void:
	if _busy:
		return
	if GameState.is_awaiting_sleep() and not _prompt_visible:
		return
	_busy = true
	_prompt_visible = false
	hide_sleep_prompt()
	BgmDirector.stop_for_sleep()
	await _fade_to_black(FADE_TO_BLACK_SEC)
	if advance_callback.is_valid():
		advance_callback.call()
	await get_tree().create_timer(HOLD_BLACK_SEC).timeout
	await _play_day_opening_auto(GameState.game_day)
	await _fade_from_black(FADE_FROM_BLACK_SEC)
	BgmDirector.resume_day_after_sleep()
	_day_panel.visible = false
	_busy = false
	day_opening_finished.emit()


func _play_day_opening_auto(day: int) -> void:
	_day_title.text = "第 %d 天" % day
	if GameState.IS_TEN_DAY_EDITION:
		_day_body.text = "%s · %s" % [
			GameState.get_time_label(GameState.TIME_MORNING),
			GameState.get_weather_label(),
		]
	else:
		_day_body.text = "%s · %s" % [GameState.get_day_period_label(), GameState.get_weather_label()]
	_day_panel.visible = true
	_day_panel.modulate.a = 0.0
	_day_panel.scale = Vector2(0.94, 0.94)
	call_deferred("_finalize_day_panel_layout")
	var intro := create_tween()
	intro.set_parallel(true)
	intro.tween_property(_day_panel, "modulate:a", 1.0, 0.32)
	intro.tween_property(_day_panel, "scale", Vector2.ONE, 0.32).set_trans(Tween.TRANS_BACK).set_ease(Tween.EASE_OUT)
	await intro.finished
	await get_tree().create_timer(DAY_CARD_HOLD_SEC).timeout
	var outro := create_tween()
	outro.tween_property(_day_panel, "modulate:a", 0.0, DAY_CARD_FADE_OUT_SEC)
	await outro.finished


func _finalize_day_panel_layout() -> void:
	if not _day_panel.visible:
		return
	_day_panel.pivot_offset = _day_panel.size * 0.5


func _build_sleep_panel() -> void:
	_sleep_panel = PanelContainer.new()
	_sleep_panel.set_anchors_preset(Control.PRESET_CENTER)
	_sleep_panel.offset_left = -240
	_sleep_panel.offset_right = 240
	_sleep_panel.offset_top = -120
	_sleep_panel.offset_bottom = 120
	_sleep_panel.mouse_filter = Control.MOUSE_FILTER_STOP
	_sleep_panel.add_theme_stylebox_override("panel", LetterPaperKit.paper_style(true))
	add_child(_sleep_panel)

	var stack := VBoxContainer.new()
	stack.add_theme_constant_override("separation", 16)
	stack.alignment = BoxContainer.ALIGNMENT_CENTER
	_sleep_panel.add_child(stack)

	var title := Label.new()
	title.text = StoryNodeCopy.get_system("sleep_prompt_title")
	title.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	title.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	title.add_theme_font_size_override("font_size", 24)
	title.add_theme_color_override("font_color", LetterPaperKit.INK)
	LetterPaperKit.apply_font(title)
	stack.add_child(title)

	var body := Label.new()
	body.text = StoryNodeCopy.get_system("sleep_prompt_body")
	body.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	body.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	body.add_theme_font_size_override("font_size", 18)
	body.add_theme_color_override("font_color", LetterPaperKit.INK_SOFT)
	LetterPaperKit.apply_font(body)
	stack.add_child(body)

	var sleep_btn := Button.new()
	sleep_btn.name = "SleepNowButton"
	sleep_btn.text = StoryNodeCopy.get_system("sleep_prompt_confirm")
	sleep_btn.custom_minimum_size = Vector2(220, 52)
	sleep_btn.focus_mode = Control.FOCUS_NONE
	sleep_btn.mouse_filter = Control.MOUSE_FILTER_STOP
	LetterPaperKit.apply_sticky_button(sleep_btn)
	LetterPaperKit.apply_font(sleep_btn)
	sleep_btn.pressed.connect(func() -> void:
		if _busy:
			return
		sleep_now_pressed.emit()
	)
	stack.add_child(sleep_btn)


func _build_day_panel() -> void:
	_day_panel = PanelContainer.new()
	_day_panel.set_anchors_preset(Control.PRESET_CENTER)
	_day_panel.offset_left = -280
	_day_panel.offset_right = 280
	_day_panel.offset_top = -120
	_day_panel.offset_bottom = 120
	_day_panel.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_day_panel.add_theme_stylebox_override("panel", LetterPaperKit.paper_style(false))
	add_child(_day_panel)

	var stack := VBoxContainer.new()
	stack.add_theme_constant_override("separation", 14)
	stack.alignment = BoxContainer.ALIGNMENT_CENTER
	_day_panel.add_child(stack)

	_day_title = Label.new()
	_day_title.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	_day_title.add_theme_font_size_override("font_size", 34)
	_day_title.add_theme_color_override("font_color", LetterPaperKit.INK)
	LetterPaperKit.apply_font(_day_title)
	stack.add_child(_day_title)

	_day_body = Label.new()
	_day_body.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	_day_body.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	_day_body.add_theme_font_size_override("font_size", 20)
	_day_body.add_theme_color_override("font_color", LetterPaperKit.INK_SOFT)
	LetterPaperKit.apply_font(_day_body)
	stack.add_child(_day_body)


func _fade_to_black(duration: float) -> void:
	_kill_tween()
	_fade.mouse_filter = Control.MOUSE_FILTER_STOP
	_tween = create_tween()
	_tween.tween_property(_fade, "color:a", 1.0, duration).set_trans(Tween.TRANS_SINE).set_ease(Tween.EASE_IN)
	await _tween.finished


func _fade_from_black(duration: float) -> void:
	_kill_tween()
	_tween = create_tween()
	_tween.tween_property(_fade, "color:a", 0.0, duration).set_trans(Tween.TRANS_SINE).set_ease(Tween.EASE_OUT)
	await _tween.finished
	_fade.mouse_filter = Control.MOUSE_FILTER_IGNORE


func _kill_tween() -> void:
	if _tween != null and _tween.is_valid():
		_tween.kill()
