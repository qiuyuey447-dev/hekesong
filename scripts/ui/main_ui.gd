extends CanvasLayer

@onready var _hud_day: Label = $HUD/Margin/VBox/Row1/DayLabel
@onready var _hud_stats: Label = $HUD/Margin/VBox/StatsLabel
@onready var _hud_stage: Label = $HUD/Margin/VBox/StageLabel
@onready var _task_panel: PanelContainer = $TaskPanel
@onready var _task_title: Label = $TaskPanel/Margin/VBox/Title
@onready var _task_body: Label = $TaskPanel/Margin/VBox/Body
@onready var _task_timer: Label = $TaskPanel/Margin/VBox/TimerLabel
@onready var _confirm_button: Button = $TaskPanel/Margin/VBox/Buttons/ConfirmButton
@onready var _cancel_button: Button = $TaskPanel/Margin/VBox/Buttons/CancelButton
@onready var _skip_button: Button = $TaskPanel/Margin/VBox/SkipButton
@onready var _chat_log: RichTextLabel = $ChatPanel/Margin/VBox/ChatLog
@onready var _chat_date: Label = $ChatPanel/Margin/VBox/DateChip
@onready var _player_echo: Label = $ChatPanel/Margin/VBox/PlayerEcho
@onready var _companion_sign: Label = $ChatPanel/Margin/VBox/Sign
@onready var _continue_arrow: Label = $ChatPanel/Margin/VBox/ContinueArrow
@onready var _toast: Label = $Toast
@onready var _nudge_bar: HBoxContainer = $ChatPanel/Margin/VBox/NudgeBar
@onready var _nudge_ok_button: Button = $ChatPanel/Margin/VBox/NudgeBar/NudgeOk
@onready var _nudge_later_button: Button = $ChatPanel/Margin/VBox/NudgeBar/NudgeLater
@onready var _chat_input: LineEdit = $ChatPanel/Margin/VBox/ChatRow/ChatInput
@onready var _chat_send: Button = $ChatPanel/Margin/VBox/ChatRow/ChatSend
@onready var _next_day_button: Button = $HUD/Margin/VBox/Row1/NextDayButton
@onready var _market_button: Button = $HUD/Margin/VBox/Row1/MarketButton
@onready var _memory_button: Button = $HUD/Margin/VBox/Row1/MemoryButton
@onready var _shop_panel: PanelContainer = $ShopPanel
@onready var _feed_panel: PanelContainer = $FeedPanel
@onready var _market_panel: PanelContainer = $MarketPanel
@onready var _memory_panel: PanelContainer = $MemoryPanel
@onready var _awakening_panel: PanelContainer = $AwakeningPanel
@onready var _week_wrap_panel: PanelContainer = $WeekWrapPanel
@onready var _story_beat_panel: StoryBeatPanel = $StoryBeatPanel
@onready var _ending_panel: PanelContainer = $EndingPanel
@onready var _name_prompt_panel: PanelContainer = $NamePromptPanel
@onready var _story_choice_panel: PanelContainer = $StoryChoicePanel

var _notebook_eviction_active: bool = false
var _basket_drawer: BasketDrawer
var _basket_button: Button
var _coin_bubble: Label
var _top_status: Label
var _pending_morning_sidewrite: bool = false
var _session_start_retries: int = 0
var _ambient_sidewrite_retries: int = 0
var _notebook_eviction_retries: int = 0
var _pending_react_type: String = ""
var _pending_react_facts: Dictionary = {}
var _pending_proactive_speech: Dictionary = {}
var _proactive_chase_spoken: Array = []
var _last_sprout_tier_seen: int = -1
var _day_cycle_overlay: DayCycleOverlay
var _defer_day_content: bool = false
var _sleep_flow_active: bool = false

var _npc_busy: bool = false
var _queued_busy_chat: String = ""
var _pending_chat_intent: Dictionary = {}
var _pending_chat_text: String = ""
var _chat_action_handled: bool = false
var _pending_nudge_type: String = ""
var _pending_session_absence: bool = false
var _story_choice_blocked: bool = false
var _story_beat_blocked: bool = false
var _pending_beat_yesterday_echo: bool = false
var _name_prompt_blocked: bool = false
var _api_mock_hint_shown: bool = false
var _pending_seed_purchase: bool = false
var _pending_seed_source_text: String = ""
var _auto_seed_shop_flow: bool = false
var _pending_companion_night_line: String = ""
var _companion_snuggle_pending_beat_id: String = ""
var _snuggle_blocked: bool = false
var _pending_post_snuggle_day_advance: bool = false
var _queued_seed_count: int = -1
var _seed_quantity_prompted: bool = false
var _seed_purchase_resolved: bool = false
var _farm_chain_after_task: String = ""
var _pending_water_offer: bool = false
var _pending_shop_offer: bool = false
var _pending_plant_offer: bool = false
var _pending_harvest_offer: bool = false
var _skip_player_chat_reply: bool = false
var _pending_feed_item_id: String = ""
var _pending_feed_refuse: bool = false
var _last_chat_activity_msec: int = 0
var _deferred_invite_speech: Dictionary = {}
var _pending_invite_story_beat_id: String = ""
var _deferred_invite_flush_token: int = 0
var _invite_proactive_dispatched: bool = false
var _recent_citation_summaries: Array = []

## 去 AI 味：LLM 调试副作用（delta/引用/mock 来源）默认不进对话流，仅调试时开启。
const SHOW_LLM_DEBUG: bool = false
const TYPEWRITER_SEC_PER_CHAR: float = 0.071
const PLAYER_ECHO_HOLD_SEC: float = 1.8
const PLAYER_ECHO_FADE_SEC: float = 0.4
const PLAYER_ECHO_RISE_PX: float = 12.0
const CHAT_PANEL_HEIGHT := 292.0
const OPENING_HINT_HOLD_SEC := 5.0
const OPENING_HINT_FADE_IN_SEC := 0.25
const OPENING_HINT_FADE_OUT_SEC := 0.45
const TOAST_FONT_SIZE := 20
const TOAST_OUTLINE_SIZE := 8
const OPENING_HINT_FONT_SIZE := 40
const OPENING_HINT_OUTLINE_SIZE := 16
const NARRATIVE_HINT_SEC := 8.0
## 玩家聊天结束后，暂缓剧情邀请 / 信纸弹窗，避免与自由对话抢通道。
const CHAT_NARRATIVE_GRACE_SEC := 15.0
const STORY_BEAT_AFTER_INVITE_DELAY_SEC := 5.0
const NARRATIVE_HINT_KEYS := {
	"d4_amnesia_hint": true,
	"d4_memory_panel_hint": true,
	"d5_notebook_trust_hint": true,
	"tutorial_notebook_hint": true,
}
var _companion_tween: Tween = null
var _player_echo_tween: Tween = null
var _toast_tween: Tween = null
var _opening_hint_phase: int = 0
var _opening_hint_tween: Tween = null
var _opening_hint_token: int = 0
var _narrative_hint_tween: Tween = null
var _arrow_tween: Tween = null
var _typing: bool = false
var _typewriter_full_text: String = ""
var _typewriter_visible_count: int = 0
var _transient_companion_aside: String = ""
var _player_echo_base_y: float = 0.0


func _ready() -> void:
	add_to_group("main_ui")
	DisplayServer.window_set_title(GameState.GAME_DISPLAY_NAME)
	_apply_cozy_theme()
	_setup_minimal_top_bar()
	_setup_basket_drawer()
	_setup_day_cycle_overlay()
	_task_panel.visible = false
	_chat_input.placeholder_text = "…（轻声对小狸说）"
	_setup_dialogue_panel()
	_restore_chat_history()

	GameState.stats_changed.connect(_refresh_hud)
	GameState.time_changed.connect(_on_time_changed)
	TaskSystem.task_started.connect(_on_task_started)
	TaskSystem.task_progress.connect(_on_task_progress)
	TaskSystem.task_completed.connect(_on_task_completed)
	GameState.day_advanced.connect(_on_day_advanced)
	GameState.sleep_prompt_requested.connect(_on_sleep_prompt_requested)
	GameState.week_reset.connect(_on_week_reset)
	GameState.milestone_trigger.connect(_on_milestone_trigger)
	GameState.companion_world_event.connect(_on_companion_world_event)
	StoryBeatDirector.scheduled_beat_due.connect(_on_scheduled_story_beat)
	CompanionAgent.proactive_chase_shout.connect(_on_companion_chase_shout)
	NpcBridge.reply_ready.connect(_on_npc_reply_ready)
	NpcBridge.request_failed.connect(_on_npc_request_failed)
	MemoryService.anchor_eviction_pending.connect(_on_anchor_eviction_pending)
	if _story_choice_panel.has_signal("chosen"):
		_story_choice_panel.chosen.connect(_on_story_choice_chosen)

	_confirm_button.pressed.connect(_on_confirm_pressed)
	_cancel_button.pressed.connect(_on_cancel_pressed)
	_chat_send.pressed.connect(_on_chat_send_pressed)
	_chat_input.text_submitted.connect(_on_chat_submitted)
	_chat_input.text_changed.connect(_on_chat_input_text_changed)
	_chat_input.gui_input.connect(_on_chat_input_gui_input)
	_chat_input.gui_input.connect(_ensure_audio_unlocked)
	_nudge_ok_button.pressed.connect(_on_nudge_ok_pressed)
	_nudge_later_button.pressed.connect(_on_nudge_later_pressed)
	_next_day_button.pressed.connect(_on_next_day_pressed)
	_market_button.pressed.connect(_on_market_pressed)
	_memory_button.pressed.connect(_on_memory_pressed)
	_shop_panel.closed.connect(_on_shop_closed)
	_feed_panel.feed_requested.connect(_on_feed_requested)
	_feed_panel.closed.connect(_on_feed_closed)
	if _awakening_panel.has_signal("finished"):
		_awakening_panel.finished.connect(_on_awakening_finished)
	if _week_wrap_panel.has_signal("confirmed"):
		_week_wrap_panel.confirmed.connect(_on_week_wrap_confirmed)
	if _ending_panel.has_signal("finished"):
		_ending_panel.finished.connect(_on_ending_finished)
	if _story_beat_panel.has_signal("finished"):
		_story_beat_panel.finished.connect(_on_story_beat_finished)
	if _story_beat_panel.has_signal("choice_made"):
		_story_beat_panel.choice_made.connect(_on_story_beat_choice)
	if _name_prompt_panel.has_signal("confirmed"):
		_name_prompt_panel.confirmed.connect(_on_name_prompt_confirmed)
	StoryBeatDirector.story_route_changed.connect(_on_story_route_changed)
	GameState.debug_awakening_requested.connect(_on_debug_awakening_requested)

	_refresh_hud()
	_apply_ui_scale()
	if not get_viewport().size_changed.is_connected(_apply_ui_scale):
		get_viewport().size_changed.connect(_apply_ui_scale)
	_last_sprout_tier_seen = BasketDrawer.sprout_tier_for_affection(GameState.affection)
	# 开场状态已在顶栏 / 篮子，不弹系统旁白。
	if GameState.is_story_complete():
		call_deferred("_enter_game_over_state")
		return
	if GameState.game_day >= (5 if GameState.IS_TEN_DAY_EDITION else 10):
		StoryBeatDirector.ensure_story_route_locked()
	call_deferred("_maybe_force_story_finale")
	call_deferred("_maybe_show_awakening")
	call_deferred("_maybe_show_story_beat")
	call_deferred("_maybe_show_name_prompt_after_load")
	call_deferred("_maybe_resume_pending_eviction")
	call_deferred("_maybe_trigger_persona_shift")
	call_deferred("_ensure_bgm")


func _ensure_bgm() -> void:
	BgmDirector.ensure_playing()


func _ensure_audio_unlocked(_event: InputEvent = null) -> void:
	AmbientAudio.ensure_unlocked()
	BgmDirector.ensure_unlocked()


func _setup_dialogue_panel() -> void:
	_chat_send.visible = true
	_chat_send.disabled = false
	_chat_send.text = "发送"
	if _chat_date:
		_chat_date.visible = false
	_player_echo.visible = false
	_continue_arrow.visible = false
	_companion_sign.visible = true
	_companion_sign.modulate.a = 1.0
	_companion_sign.text = "和她说说话"
	_companion_sign.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	_chat_log.mouse_filter = Control.MOUSE_FILTER_STOP
	_chat_log.scroll_active = true
	_chat_log.scroll_following = true
	_chat_log.bbcode_enabled = true
	_chat_log.visible_ratio = 1.0


func _process(_delta: float) -> void:
	if _chat_input.has_focus() and _is_player_moving():
		_chat_input.release_focus()


func _unhandled_input(event: InputEvent) -> void:
	if not _is_enter_focus_chat_event(event):
		return
	if _chat_input.has_focus():
		return
	if not _can_focus_chat_input():
		return
	_ensure_audio_unlocked(event)
	_chat_input.grab_focus()
	get_viewport().set_input_as_handled()


func _is_enter_focus_chat_event(event: InputEvent) -> bool:
	if not event is InputEventKey:
		return false
	var key := event as InputEventKey
	if not key.pressed or key.echo:
		return false
	return key.keycode == KEY_ENTER or key.keycode == KEY_KP_ENTER


func _can_focus_chat_input() -> bool:
	if not is_instance_valid(_chat_input) or not _chat_input.editable or not _chat_input.visible:
		return false
	if _is_gameplay_locked() or GameState.is_story_complete():
		return false
	if (
		_story_beat_panel.visible
		or _awakening_panel.visible
		or _ending_panel.visible
		or _name_prompt_panel.visible
		or _week_wrap_panel.visible
		or _task_panel.visible
		or _story_choice_blocked
		or _story_beat_blocked
	):
		return false
	if (
		_shop_panel.visible
		or _feed_panel.visible
		or _market_panel.visible
		or _memory_panel.visible
	):
		return false
	var focus := get_viewport().gui_get_focus_owner()
	if focus == null:
		return true
	if focus == _chat_input:
		return true
	if focus is LineEdit or focus is TextEdit:
		return false
	if focus is BaseButton:
		return false
	return true


func _on_chat_input_gui_input(event: InputEvent) -> void:
	if _is_player_moving():
		_chat_input.add_theme_color_override(
			"font_placeholder_color",
			Color(0.55, 0.48, 0.40, 0.55)
		)
		if _is_movement_key_event(event):
			_chat_input.accept_event()
			_chat_input.release_focus()
		return
	_chat_input.add_theme_color_override(
		"font_placeholder_color",
		Color(0.42, 0.34, 0.26, 0.82)
	)


func _on_chat_input_text_changed(new_text: String) -> void:
	if _opening_hint_phase != 1:
		return
	if new_text.strip_edges() != "":
		_dismiss_opening_chat_hint()


func _is_player_moving() -> bool:
	var player := get_tree().get_first_node_in_group("player")
	if player != null and player.has_method("is_moving"):
		return bool(player.call("is_moving"))
	return false


func _is_movement_key_event(event: InputEvent) -> bool:
	if not event is InputEventKey or not event.pressed or event.echo:
		return false
	return (
		event.is_action("move_left")
		or event.is_action("move_right")
		or event.is_action("move_up")
		or event.is_action("move_down")
	)


func _maybe_show_name_prompt_after_load() -> void:
	if GameState.has_player_name_set():
		return
	if GameState.get_week_index() != 1:
		return
	if not GameState.is_story_node_seen("P_N01"):
		return
	if _story_beat_blocked or _name_prompt_blocked:
		return
	_maybe_show_name_prompt()


func _maybe_show_name_prompt() -> void:
	if GameState.has_player_name_set():
		return
	if GameState.get_week_index() != 1:
		return
	if _name_prompt_blocked:
		return
	_name_prompt_blocked = true
	_set_gameplay_controls_enabled(false)
	GameState.push_time_pause()
	_name_prompt_panel.open()


func _on_name_prompt_confirmed(name: String) -> void:
	_name_prompt_blocked = false
	GameState.pop_time_pause()
	_set_gameplay_controls_enabled(true)
	var cleaned := str(name).strip_edges()
	if cleaned == "":
		return
	_append_companion_message("……%s。好。我先念三遍。" % cleaned)
	_maybe_show_d1_opening_guide()
	_refresh_hud()
	CompanionDirector.schedule_consider(0.8, "period")


func _maybe_show_d1_opening_guide() -> void:
	if not GameState.IS_TEN_DAY_EDITION or GameState.game_day != 1:
		return
	if bool(GameState.get_ending_flags().get("d1_opening_guide_shown", false)):
		return
	GameState.set_ending_flag("d1_opening_guide_shown", true)
	var guide := StoryNodeCopy.get_system("d1_after_name_companion").strip_edges()
	if guide != "":
		get_tree().create_timer(1.2).timeout.connect(func() -> void:
			_append_companion_message(guide)
		, CONNECT_ONE_SHOT)
	_maybe_show_opening_hint_sequence()


func _maybe_show_opening_hint_sequence() -> void:
	if bool(GameState.get_ending_flags().get("tutorial_controls_hint_seen", false)):
		return
	if _opening_hint_phase != 0:
		return
	get_tree().create_timer(1.0).timeout.connect(_begin_opening_chat_hint, CONNECT_ONE_SHOT)


func _begin_opening_chat_hint() -> void:
	if bool(GameState.get_ending_flags().get("tutorial_controls_hint_seen", false)):
		return
	if not GameState.IS_TEN_DAY_EDITION or GameState.game_day != 1:
		return
	var line := StoryNodeCopy.get_system("tutorial_chat_hint").strip_edges()
	if line == "":
		line = "试着和她聊聊天吧"
	_opening_hint_phase = 1
	_fade_in_opening_toast(line)
	_schedule_opening_hint_timeout(1, _on_opening_chat_hint_timeout)


func _schedule_opening_hint_timeout(phase: int, callback: Callable) -> void:
	_opening_hint_token += 1
	var token := _opening_hint_token
	get_tree().create_timer(OPENING_HINT_HOLD_SEC).timeout.connect(func() -> void:
		if token != _opening_hint_token or _opening_hint_phase != phase:
			return
		if callback.is_valid():
			callback.call()
	, CONNECT_ONE_SHOT)


func _on_opening_chat_hint_timeout() -> void:
	_dismiss_opening_chat_hint()


func _dismiss_opening_chat_hint() -> void:
	if _opening_hint_phase != 1:
		return
	_opening_hint_phase = 0
	_bump_opening_hint_token()
	_fade_out_opening_toast(_begin_opening_movement_hint)


func _begin_opening_movement_hint() -> void:
	if bool(GameState.get_ending_flags().get("tutorial_controls_hint_seen", false)):
		return
	var line := _opening_movement_hint_line()
	if line == "":
		_finish_opening_hint_sequence()
		return
	_opening_hint_phase = 2
	_fade_in_opening_toast(line)
	_schedule_opening_hint_timeout(2, _on_opening_movement_hint_timeout)


func _on_opening_movement_hint_timeout() -> void:
	if _opening_hint_phase != 2:
		return
	_opening_hint_phase = 0
	_bump_opening_hint_token()
	_fade_out_opening_toast(_finish_opening_hint_sequence)


func _finish_opening_hint_sequence() -> void:
	_opening_hint_phase = 0
	_bump_opening_hint_token()
	_restore_toast_layout()
	GameState.set_ending_flag("tutorial_controls_hint_seen", true)


func _bump_opening_hint_token() -> void:
	_opening_hint_token += 1


func _opening_movement_hint_line() -> String:
	var key := "tutorial_controls_hint_touch" if _needs_touch_controls_hint() else "tutorial_controls_hint"
	var line := StoryNodeCopy.get_system(key).strip_edges()
	if line == "":
		line = StoryNodeCopy.get_system("tutorial_controls_hint").strip_edges()
	return line


func _fade_in_opening_toast(text: String) -> void:
	var line := text.strip_edges()
	if line == "":
		return
	_cancel_opening_hint_tween()
	if _toast_tween != null and _toast_tween.is_valid():
		_toast_tween.kill()
	_apply_opening_toast_layout()
	_toast.text = line
	_toast.modulate.a = 0.0
	_opening_hint_tween = create_tween()
	_opening_hint_tween.tween_property(_toast, "modulate:a", 1.0, OPENING_HINT_FADE_IN_SEC)


func _apply_opening_toast_layout() -> void:
	_toast.set_anchors_preset(Control.PRESET_CENTER)
	_toast.offset_left = -420.0
	_toast.offset_top = -96.0
	_toast.offset_right = 420.0
	_toast.offset_bottom = 96.0
	_toast.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	_toast.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	_toast.add_theme_font_size_override("font_size", OPENING_HINT_FONT_SIZE)
	_toast.add_theme_constant_override("outline_size", OPENING_HINT_OUTLINE_SIZE)


func _restore_toast_layout() -> void:
	_toast.set_anchors_preset(Control.PRESET_CENTER_TOP)
	_toast.offset_left = -320.0
	_toast.offset_top = 70.0
	_toast.offset_right = 320.0
	_toast.offset_bottom = 112.0
	_toast.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	_toast.vertical_alignment = VERTICAL_ALIGNMENT_TOP
	_toast.add_theme_font_size_override("font_size", TOAST_FONT_SIZE)
	_toast.add_theme_constant_override("outline_size", TOAST_OUTLINE_SIZE)


func _fade_out_opening_toast(on_finished: Callable = Callable()) -> void:
	_cancel_opening_hint_tween()
	_opening_hint_tween = create_tween()
	_opening_hint_tween.tween_property(_toast, "modulate:a", 0.0, OPENING_HINT_FADE_OUT_SEC)
	if on_finished.is_valid():
		_opening_hint_tween.finished.connect(on_finished, CONNECT_ONE_SHOT)


func _cancel_opening_hint_tween() -> void:
	if _opening_hint_tween != null and _opening_hint_tween.is_valid():
		_opening_hint_tween.kill()
	_opening_hint_tween = null


func _cancel_opening_hint_sequence() -> void:
	_opening_hint_phase = 0
	_bump_opening_hint_token()
	_cancel_opening_hint_tween()
	_restore_toast_layout()


func _needs_touch_controls_hint() -> bool:
	if DisplayServer.is_touchscreen_available():
		return true
	if OS.has_feature("web"):
		var vp := get_viewport().get_visible_rect().size
		return vp.x < 1200.0 or vp.y < 820.0 or vp.y > vp.x * 1.05
	return false


func _on_time_changed(time_of_day: String) -> void:
	_refresh_hud()
	_hide_nudge_bar()
	StoryBeatDirector.check_schedule()
	if _sleep_flow_active or _defer_day_content:
		return
	if time_of_day == GameState.TIME_NIGHT:
		_hint("夜幕降临了。")
	elif time_of_day == GameState.TIME_EVENING:
		_hint("天色渐晚。")
		call_deferred("_maybe_remind_story_invite")
	call_deferred("_maybe_resume_beat_tail")


## 傍晚补一次轻邀请：她白天已经开过口，但玩家还没去听。
func _maybe_remind_story_invite() -> void:
	if _story_beat_blocked or _story_choice_blocked or _npc_busy:
		return
	if _is_gameplay_locked() or GameState.is_story_complete():
		return
	if _story_beat_panel.visible:
		return
	if not GameState.can_proactive_speech("invite"):
		return
	var speech := StoryBeatDirector.try_invite(true)
	if speech.is_empty():
		return
	if _should_defer_story_invite():
		_queue_deferred_story_invite(speech)
		return
	CompanionDirector.mark_delivered(speech)
	_request_proactive_speech(speech)


func _on_milestone_trigger(_milestone_id: String, facts: Dictionary) -> void:
	_request_companion_react("story_nudge", facts)


func _on_companion_world_event(event_type: String, facts: Dictionary) -> void:
	if event_type != "crop_became_ready":
		return
	_request_companion_react("world_crop_ready", facts)


## 反应口：世界发生了事她才出声，单独计池，不占叙事口与生活口。
func _request_companion_react(react_type: String, facts: Dictionary) -> void:
	if _npc_busy or _is_gameplay_locked() or GameState.is_story_complete():
		return
	if GameState.is_night() or StoryDirector.is_stranger_mode():
		return
	if _story_beat_panel.visible or _story_beat_blocked or _story_choice_blocked:
		return
	if not GameState.can_proactive_speech("react"):
		return
	GameState.consume_proactive_speech("react")
	_pending_react_type = react_type
	_pending_react_facts = facts.duplicate(true)
	_request_companion_line("companion_react", {
		"react_type": react_type,
		"react_facts": _pending_react_facts,
	})


func _refresh_hud() -> void:
	## 玩家可见状态：日 + 时段（与 GameState 同步）；天气仍留给旧 HUD 节点。
	var day_period := GameState.get_day_period_label()
	var week_label := day_period
	if GameState.IS_TEN_DAY_EDITION:
		week_label = "%s · 共 %d 天 · %s" % [
			day_period,
			GameState.FINAL_GAME_DAY,
			GameState.get_weather_label(),
		]
	else:
		week_label = "周目 %d · %s · %s" % [
			GameState.get_week_index(),
			day_period,
			GameState.get_weather_label(),
		]
	if GameState.is_story_complete():
		week_label += " · 故事完结"
	_hud_day.text = week_label
	if _chat_date:
		_chat_date.text = _get_chat_date_label()
	if _top_status:
		_top_status.text = day_period
	if _coin_bubble:
		_coin_bubble.text = str(GameState.coins)
	# 旧 HUD 数值行保留节点但不展示（已收进篮子）。
	_hud_stats.text = ""
	_hud_stage.text = ""
	_next_day_button.text = "睡觉" if GameState.can_manual_sleep() else "天还亮着"
	if _basket_drawer:
		_basket_drawer.refresh()
	_maybe_announce_sprout_growth()


func _get_chat_date_label() -> String:
	var label := GameState.get_day_period_label()
	if GameState.is_story_complete():
		return "%s · 故事完结" % label
	return label


func _setup_minimal_top_bar() -> void:
	## P1c：左上大号像素篮子 + 金币气泡；状态串让到篮子右侧。
	_hud_stats.visible = false
	_hud_stage.visible = false
	var hint := $HUD/Margin/VBox/HintLabel as Label
	if hint:
		hint.visible = false
	_market_button.visible = false
	_memory_button.visible = false
	_next_day_button.visible = false
	_hud_day.visible = false

	var empty := StyleBoxEmpty.new()
	$HUD.add_theme_stylebox_override("panel", empty)
	$HUD.mouse_filter = Control.MOUSE_FILTER_IGNORE

	_basket_button = Button.new()
	_basket_button.name = "BasketButton"
	_basket_button.text = ""
	_basket_button.focus_mode = Control.FOCUS_NONE
	_basket_button.custom_minimum_size = Vector2(84, 84)
	_basket_button.set_anchors_preset(Control.PRESET_TOP_LEFT)
	_basket_button.offset_left = 16
	_basket_button.offset_top = 12
	_basket_button.offset_right = 100
	_basket_button.offset_bottom = 96
	_basket_button.mouse_default_cursor_shape = Control.CURSOR_POINTING_HAND
	_basket_button.expand_icon = true
	_basket_button.icon_alignment = HORIZONTAL_ALIGNMENT_CENTER
	var b_normal := StyleBoxFlat.new()
	b_normal.bg_color = Color(0.96, 0.90, 0.78, 0.92)
	b_normal.border_color = Color(0.62, 0.48, 0.30, 0.75)
	b_normal.set_border_width_all(2)
	b_normal.set_corner_radius_all(18)
	b_normal.content_margin_left = 8
	b_normal.content_margin_top = 8
	b_normal.content_margin_right = 8
	b_normal.content_margin_bottom = 8
	var b_hover := b_normal.duplicate()
	b_hover.bg_color = Color(1.0, 0.94, 0.82, 1.0)
	b_hover.shadow_color = Color(0.35, 0.22, 0.08, 0.2)
	b_hover.shadow_size = 8
	_basket_button.add_theme_stylebox_override("normal", b_normal)
	_basket_button.add_theme_stylebox_override("hover", b_hover)
	_basket_button.add_theme_stylebox_override("pressed", b_hover)
	_apply_basket_icon(_basket_button)
	_basket_button.texture_filter = CanvasItem.TEXTURE_FILTER_NEAREST
	_basket_button.pressed.connect(_on_basket_pressed)
	add_child(_basket_button)

	_coin_bubble = Label.new()
	_coin_bubble.name = "CoinBubble"
	_coin_bubble.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	_coin_bubble.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	_coin_bubble.add_theme_font_size_override("font_size", 13)
	_coin_bubble.add_theme_color_override("font_color", Color(0.35, 0.22, 0.10, 1.0))
	var bubble := StyleBoxFlat.new()
	bubble.bg_color = Color(1.0, 0.95, 0.82, 0.96)
	bubble.border_color = Color(0.78, 0.6, 0.38, 0.75)
	bubble.set_border_width_all(1)
	bubble.set_corner_radius_all(11)
	bubble.content_margin_left = 8
	bubble.content_margin_right = 8
	bubble.content_margin_top = 2
	bubble.content_margin_bottom = 2
	var coin_wrap := PanelContainer.new()
	coin_wrap.name = "CoinBubbleWrap"
	coin_wrap.set_anchors_preset(Control.PRESET_TOP_LEFT)
	coin_wrap.offset_left = 72
	coin_wrap.offset_top = 78
	coin_wrap.offset_right = 118
	coin_wrap.offset_bottom = 102
	coin_wrap.mouse_filter = Control.MOUSE_FILTER_IGNORE
	coin_wrap.add_theme_stylebox_override("panel", bubble)
	coin_wrap.add_child(_coin_bubble)
	add_child(coin_wrap)

	_top_status = Label.new()
	_top_status.name = "TopStatus"
	_top_status.set_anchors_preset(Control.PRESET_TOP_LEFT)
	_top_status.offset_left = 118
	_top_status.offset_top = 28
	_top_status.offset_right = 620
	_top_status.offset_bottom = 58
	_top_status.add_theme_font_size_override("font_size", 14)
	_top_status.add_theme_color_override("font_color", Color(0.54, 0.43, 0.31, 0.7))
	_top_status.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(_top_status)

	var font := UIFontTheme.get_font() if UIFontTheme else null
	if font:
		_top_status.add_theme_font_override("font", font)
		_coin_bubble.add_theme_font_override("font", font)


func _apply_basket_icon(button: Button) -> void:
	var tex: Texture2D = null
	if ResourceLoader.exists("res://assets/ui/basket_icon.png"):
		tex = load("res://assets/ui/basket_icon.png") as Texture2D
	if tex == null:
		tex = _make_fallback_basket_texture()
	button.icon = tex
	# 放大且保持像素感
	button.add_theme_constant_override("icon_max_width", 64)
	if tex is ImageTexture:
		# ImageTexture created at runtime already nearest if we set it
		pass


func _make_fallback_basket_texture() -> Texture2D:
	## 资源未导入时的像素筐兜底。
	var img := Image.create(32, 32, false, Image.FORMAT_RGBA8)
	img.fill(Color(0, 0, 0, 0))
	var out := Color(0.36, 0.23, 0.12, 1)
	var mid := Color(0.66, 0.46, 0.24, 1)
	var lite := Color(0.82, 0.66, 0.38, 1)
	for x in range(10, 22):
		img.set_pixel(x, 6, out)
	for y in range(7, 12):
		img.set_pixel(10, y, out)
		img.set_pixel(21, y, out)
	for x in range(6, 26):
		img.set_pixel(x, 12, out)
		img.set_pixel(x, 13, mid)
	for y in range(14, 27):
		for x in range(5, 27):
			img.set_pixel(x, y, mid if ((x + y) % 2) == 0 else lite)
		img.set_pixel(5, y, out)
		img.set_pixel(26, y, out)
	var tex := ImageTexture.create_from_image(img)
	return tex


func _setup_basket_drawer() -> void:
	_basket_drawer = BasketDrawer.new()
	_basket_drawer.name = "BasketDrawer"
	add_child(_basket_drawer)
	_basket_drawer.shop_requested.connect(_on_basket_shop)
	_basket_drawer.market_requested.connect(_on_basket_market)
	_basket_drawer.memory_requested.connect(_on_basket_memory)
	_basket_drawer.sleep_requested.connect(_on_basket_sleep)
	_basket_drawer.main_menu_requested.connect(_on_basket_main_menu)
	_basket_drawer.exit_game_requested.connect(_on_basket_exit_game)
	# 篮子按钮保持在抽屉之上，方便再点一次收起。
	if _basket_button:
		_basket_button.move_to_front()
	var coin_wrap := get_node_or_null("CoinBubbleWrap") as Control
	if coin_wrap:
		coin_wrap.move_to_front()


func _setup_day_cycle_overlay() -> void:
	_day_cycle_overlay = DayCycleOverlay.new()
	_day_cycle_overlay.name = "DayCycleOverlay"
	add_child(_day_cycle_overlay)
	_day_cycle_overlay.sleep_now_pressed.connect(_on_sleep_now_pressed)


func _on_sleep_prompt_requested() -> void:
	if _sleep_flow_active or _day_cycle_overlay.is_busy():
		return
	if _day_cycle_overlay.is_prompt_visible():
		return
	if not _can_begin_sleep(true):
		return
	_enter_sleep_prompt_mode()
	_day_cycle_overlay.show_sleep_prompt()


func _enter_sleep_prompt_mode() -> void:
	_chat_input.editable = false
	_chat_send.disabled = true
	if _basket_button:
		_basket_button.disabled = true
	if _basket_drawer and _basket_drawer.is_open():
		_basket_drawer.close_drawer()


func _exit_sleep_prompt_mode() -> void:
	if _sleep_flow_active or GameState.is_story_complete():
		return
	_chat_input.editable = true
	_chat_send.disabled = false
	if _basket_button:
		_basket_button.disabled = false


func _on_sleep_now_pressed() -> void:
	_exit_sleep_prompt_mode()
	_start_sleep_flow()


func _start_sleep_flow() -> void:
	if _sleep_flow_active or _day_cycle_overlay.is_busy():
		return
	if GameState.is_awaiting_sleep() and not _day_cycle_overlay.is_prompt_visible():
		return
	if not _can_begin_sleep(true):
		return
	_finish_proactive_approach()
	_exit_sleep_prompt_mode()
	_sleep_flow_active = true
	GameState.push_time_pause()
	_set_gameplay_controls_enabled(false)
	_run_sleep_flow()


func _run_sleep_flow() -> void:
	await _day_cycle_overlay.run_sleep_sequence(_sleep_advance_callback, true)
	_on_day_opening_finished()


func _sleep_advance_callback() -> void:
	GameState.notify_sleep_sequence_started()
	StoryBeatDirector.prepare_day_end()
	if not GameState.can_advance_day():
		return
	_defer_day_content = true
	GameState.advance_day()


func _on_day_opening_finished() -> void:
	if not _sleep_flow_active and not _defer_day_content:
		return
	_defer_day_content = false
	_sleep_flow_active = false
	GameState.pop_time_pause()
	_exit_sleep_prompt_mode()
	_set_gameplay_controls_enabled(true)
	_refresh_hud()
	_handle_day_advanced_content()


func _can_begin_sleep(show_hints: bool) -> bool:
	TaskSystem.reconcile_stale_task()
	if TaskSystem.is_busy():
		if show_hints:
			_system_hint("blocking_companion_busy")
		return false
	if GameState.is_story_complete():
		if show_hints:
			_hint("故事已经结束了。")
		return false
	if not GameState.can_manual_sleep():
		if show_hints:
			_system_hint("blocking_daylight")
		return false
	if GameState.game_day >= GameState.FINAL_GAME_DAY:
		if not GameState.has_seen_awakening():
			if show_hints:
				_system_hint("blocking_story_finale")
			call_deferred("_maybe_show_awakening")
			return false
		if not GameState.is_story_complete():
			call_deferred("_play_ending", EndingDirector.resolve_ending(
				bool(GameState.get_ending_flags().get("f10_skipped", false))
			))
			return false
		return false
	if not GameState.can_advance_day():
		return false
	if not GameState.has_player_name_set():
		if show_hints:
			_system_hint("blocking_player_name")
		return false
	if GameState.must_finish_awakening_today():
		if show_hints:
			_system_hint("blocking_story_finale")
		call_deferred("_maybe_show_awakening")
		return false
	if StoryBeatDirector.has_unseen_weekend_night_beat():
		if StoryBeatDirector.can_trigger_night_beat_at_hollow():
			if show_hints:
				_hint(StoryNodeCopy.get_system("tree_hollow_night_ready"))
		else:
			if show_hints:
				_hint(StoryNodeCopy.get_system("tree_hollow_night_wait"))
		return false
	if _has_unfinished_story_beat_today():
		if show_hints:
			_system_hint("blocking_story_beat")
		call_deferred("_maybe_show_story_beat", true)
		return false
	if GameState.should_show_week_wrap():
		StoryBeatDirector.prepare_day_end()
		_week_wrap_panel.open()
		return false
	return true


func _on_basket_pressed() -> void:
	if _is_gameplay_locked():
		return
	if _basket_drawer == null:
		return
	if _basket_drawer.is_open():
		_basket_drawer.close_drawer()
	else:
		_basket_drawer.open_drawer()
		# 打开后再次把按钮抬到最前，避免被抽屉挡住。
		_basket_button.move_to_front()
		var coin_wrap := get_node_or_null("CoinBubbleWrap") as Control
		if coin_wrap:
			coin_wrap.move_to_front()


func _on_basket_shop() -> void:
	if _basket_drawer:
		_basket_drawer.close_drawer()
	if _is_gameplay_locked():
		return
	if _feed_panel.visible:
		_feed_panel.close()
	if _market_panel.visible:
		_market_panel.close()
	if _memory_panel.visible:
		_memory_panel.close()
	_shop_panel.open()


func _on_basket_market() -> void:
	if _basket_drawer:
		_basket_drawer.close_drawer()
	_sell_turnips_from_basket()


func _on_basket_memory() -> void:
	if _basket_drawer:
		_basket_drawer.close_drawer()
	_on_memory_pressed()


func _on_basket_sleep() -> void:
	if _basket_drawer:
		_basket_drawer.close_drawer()
	sleep_from_companion()


func _on_basket_main_menu() -> void:
	if _basket_drawer:
		_basket_drawer.close_drawer()
	GameState.save_game()
	get_tree().change_scene_to_file("res://scenes/title_screen.tscn")


func _on_basket_exit_game() -> void:
	if _basket_drawer:
		_basket_drawer.close_drawer()
	GameState.save_game()
	get_tree().quit()


func _maybe_announce_sprout_growth() -> void:
	var tier := BasketDrawer.sprout_tier_for_affection(GameState.affection)
	if _last_sprout_tier_seen < 0:
		_last_sprout_tier_seen = tier
		return
	if tier <= _last_sprout_tier_seen:
		return
	var line := _sprout_growth_line(tier)
	_last_sprout_tier_seen = tier
	if line != "" and not _npc_busy and not _story_beat_panel.visible:
		_append_companion_message(line)


func _sprout_growth_line(tier: int) -> String:
	match tier:
		1:
			return "……篮子里那株冒了芽。别盯着我看，是土自己长的。"
		2:
			return "小苗抽高了。我浇的水，它记得——比我还诚实。"
		3:
			return "……开花了。像萝卜田，但它是我们的。"
		_:
			return ""


## 每天清晨她自己先开一句口（走 LLM，带昨日日志与缺席回归），
## 与信纸里的「清晨」正文互不替代：信纸是叙事，这一句是她本人。
func _maybe_request_session_start() -> void:
	if not _pending_morning_sidewrite:
		return
	if GameState.is_story_complete() or GameState.should_show_awakening():
		_pending_morning_sidewrite = false
		return
	## D1 是登门，开场交给 P_N01；D10 整天归觉醒。
	if GameState.game_day <= 1 or GameState.is_pure_narrative_day():
		_pending_morning_sidewrite = false
		return
	if _story_choice_blocked or _name_prompt_blocked:
		_pending_morning_sidewrite = false
		return
	if _npc_busy or _is_gameplay_locked() or _story_beat_blocked:
		_session_start_retries += 1
		if _session_start_retries > 20:
			_pending_morning_sidewrite = false
			return
		get_tree().create_timer(1.0).timeout.connect(
			_maybe_request_session_start, CONNECT_ONE_SHOT
		)
		return
	_pending_morning_sidewrite = false
	_session_start_retries = 0
	_ambient_sidewrite_retries = 0
	_request_companion_line("session_start", {
		"include_yesterday_echo": GameState.has_yesterday_journal(),
		"include_absence_comeback": GameState.has_pending_absence(),
	})


func _request_ambient_sidewrite() -> void:
	if not CompanionDirector.should_offer_ambient():
		return
	var extra := CompanionDirector.collect_llm_extra({"channel": "ambient"})
	extra["proactive_goal"] = "雨天廊下。一句环境侧写，像自言自语。不邀请、不报价、不催任务，最多一句。"
	extra["weather"] = GameState.weather_today
	_set_npc_busy(true)
	NpcBridge.request_event("morning_sidewrite", extra)


func _maybe_request_ambient_sidewrite() -> void:
	if _npc_busy or _story_beat_panel.visible:
		_ambient_sidewrite_retries += 1
		if _ambient_sidewrite_retries > 20:
			_ambient_sidewrite_retries = 0
			return
		call_deferred("_maybe_request_ambient_sidewrite")
		return
	_ambient_sidewrite_retries = 0
	_request_ambient_sidewrite()


func _request_casual_chat() -> void:
	_request_proactive_speech({
		"channel": "casual",
		"line": "",
		"beat_id": "",
	})


func _request_proactive_speech(speech: Dictionary) -> void:
	if _is_story_invite_speech(speech) and _should_defer_story_invite():
		_queue_deferred_story_invite(speech)
		return
	_pending_proactive_speech = speech.duplicate(true)
	_begin_proactive_approach_for_speech()


func _deliver_pending_proactive_speech() -> void:
	if _pending_proactive_speech.is_empty():
		return
	if str(_pending_proactive_speech.get("channel", "")) == "invite":
		_invite_proactive_dispatched = true
	var extra := CompanionDirector.collect_llm_extra(_pending_proactive_speech)
	if _basket_drawer:
		extra["sprout_word"] = _basket_drawer.get_sprout_word()
	_request_companion_line("companion_proactive", extra)


func _begin_proactive_approach_for_speech() -> void:
	_proactive_chase_spoken.clear()
	var channel := str(_pending_proactive_speech.get("channel", ""))
	# 剧情邀请自带台词，不再叠「她好像有话跟你说」toast，避免与聊天抢注意力。
	if channel != "invite":
		_hint(StoryNodeCopy.get_system("proactive_nudge"))
	# 已在聊天里：直接接一句邀请，不再追跑打断。
	if channel == "invite" and _is_chat_session_active():
		_deliver_pending_proactive_speech()
		return
	if CompanionAgent.is_proactive_active():
		_deliver_pending_proactive_speech()
		return
	CompanionAgent.begin_proactive_approach(func() -> void:
		_deliver_pending_proactive_speech()
	)


func _finish_proactive_approach() -> void:
	_invite_proactive_dispatched = false
	if not CompanionAgent.is_proactive_active():
		_proactive_chase_spoken.clear()
		return
	CompanionAgent.end_proactive_approach()
	_proactive_chase_spoken.clear()


func _is_story_invite_speech(speech: Dictionary) -> bool:
	return str(speech.get("channel", "")).strip_edges() == "invite"


func _mark_chat_activity() -> void:
	_last_chat_activity_msec = Time.get_ticks_msec()
	_schedule_deferred_invite_flush(CHAT_NARRATIVE_GRACE_SEC + 0.35)


func _is_chat_session_active() -> bool:
	if _npc_busy:
		return true
	if _pending_chat_text.strip_edges() != "":
		return true
	if _queued_busy_chat.strip_edges() != "":
		return true
	if _last_chat_activity_msec <= 0:
		return false
	return (Time.get_ticks_msec() - _last_chat_activity_msec) < int(CHAT_NARRATIVE_GRACE_SEC * 1000.0)


func _should_defer_story_invite() -> bool:
	return _is_chat_session_active()


func _queue_deferred_story_invite(speech: Dictionary) -> void:
	if speech.is_empty():
		return
	_deferred_invite_speech = speech.duplicate(true)
	_schedule_deferred_invite_flush(CHAT_NARRATIVE_GRACE_SEC + 0.35)


func _schedule_deferred_invite_flush(delay_sec: float = 0.5) -> void:
	if not is_inside_tree():
		return
	_deferred_invite_flush_token += 1
	var token := _deferred_invite_flush_token
	get_tree().create_timer(maxf(delay_sec, 0.05)).timeout.connect(func() -> void:
		if token != _deferred_invite_flush_token:
			return
		_flush_deferred_story_invite()
	, CONNECT_ONE_SHOT)


func _flush_deferred_story_invite() -> void:
	if _pending_invite_story_beat_id != "":
		if _should_defer_story_invite() or _npc_busy or _story_beat_panel.visible:
			_schedule_deferred_invite_flush(STORY_BEAT_AFTER_INVITE_DELAY_SEC)
			return
		var beat_id := _pending_invite_story_beat_id
		_pending_invite_story_beat_id = ""
		if beat_id != "" and not StoryBeatDirector.is_beat_seen(beat_id):
			_maybe_show_story_beat(true)
		return
	if _deferred_invite_speech.is_empty():
		return
	if _should_defer_story_invite() or _story_beat_panel.visible:
		_schedule_deferred_invite_flush(CHAT_NARRATIVE_GRACE_SEC + 0.35)
		return
	if _npc_busy:
		_schedule_deferred_invite_flush(0.6)
		return
	var speech := _deferred_invite_speech.duplicate(true)
	_deferred_invite_speech = {}
	var beat_id := str(speech.get("beat_id", "")).strip_edges()
	if beat_id != "" and not GameState.was_invite_spoken_for(beat_id):
		CompanionDirector.mark_delivered(speech)
	_request_proactive_speech(speech)


func _maybe_open_story_after_invite(beat_id: String) -> void:
	beat_id = beat_id.strip_edges()
	if beat_id == "" or StoryBeatDirector.is_beat_seen(beat_id):
		return
	## 邀请台词已出口后，信纸不再被聊天保护期 indefinitely 挡住。
	get_tree().create_timer(STORY_BEAT_AFTER_INVITE_DELAY_SEC).timeout.connect(func() -> void:
		if _story_beat_panel.visible or StoryBeatDirector.is_beat_seen(beat_id):
			return
		_pending_invite_story_beat_id = ""
		_maybe_show_story_beat(true)
	, CONNECT_ONE_SHOT)


func _ensure_pending_invite_delivered() -> void:
	if _pending_proactive_speech.is_empty():
		return
	if str(_pending_proactive_speech.get("channel", "")) != "invite":
		return
	if _invite_proactive_dispatched:
		return
	_deliver_pending_proactive_speech()


func _on_companion_chase_shout() -> void:
	if _should_defer_story_invite():
		return
	var line := NpcFallback.proactive_chase_line(_proactive_chase_spoken)
	if line.strip_edges() == "":
		return
	_proactive_chase_spoken.append(line)
	_append_companion_message(line)
	if (
		str(_pending_proactive_speech.get("channel", "")) == "invite"
		and not _invite_proactive_dispatched
		and _proactive_chase_spoken.size() >= 2
	):
		call_deferred("_deliver_pending_proactive_speech")


func _casual_fallback_line() -> String:
	var extra := CompanionDirector.collect_llm_extra(_pending_proactive_speech)
	if _basket_drawer:
		extra["sprout_word"] = _basket_drawer.get_sprout_word()
	var fallback := NpcFallback.proactive_line(extra)
	if fallback.strip_edges() != "":
		return fallback
	if _basket_drawer:
		return _basket_drawer.get_morning_sidewrite_fallback()
	return "……我在。你忙的话，我就在旁边。"


func _stage_label(stage: String) -> String:
	match stage:
		GameState.STAGE_BOND:
			return "羁绊"
		GameState.STAGE_FAMILIAR:
			return "熟悉"
		_:
			return "初识"


func _on_debug_awakening_requested() -> void:
	_refresh_hud()
	_memory_panel.close()
	call_deferred("_maybe_show_awakening")


func _maybe_show_awakening() -> void:
	if not GameState.should_show_awakening():
		return
	if _awakening_panel.visible:
		return
	if _story_choice_blocked or _ending_panel.visible:
		return
	# 开场文案在信纸里演，不再 toast 一整段。
	_awakening_panel.open()
	call_deferred("_sync_player_movement_lock")


func _maybe_force_story_finale() -> void:
	if GameState.is_story_complete() or _story_choice_blocked:
		return
	if GameState.should_show_awakening():
		return
	if not GameState.should_force_story_finale():
		return
	var skipped := not GameState.has_seen_awakening()
	if skipped:
		GameState.mark_awakening_complete(true)
	else:
		skipped = bool(GameState.get_ending_flags().get("f10_skipped", false))
	var ending_id := EndingDirector.resolve_ending(skipped)
	_debug_note("—— 故事收束（兜底）——")
	call_deferred("_play_ending", ending_id)


func _on_awakening_finished(skipped: bool) -> void:
	GameState.mark_awakening_complete(skipped)
	call_deferred("_sync_player_movement_lock")
	GameState.mark_story_node_seen("N20")
	var ending_id := EndingDirector.resolve_ending(skipped)
	if not EndingDirector.is_bad_ending(ending_id):
		GameState.unlock_fragment("F10", "N20")
	call_deferred("_play_ending", ending_id)


func _on_scheduled_story_beat(beat_id: String) -> void:
	if GameState.should_show_awakening():
		return
	if _story_beat_blocked or _is_gameplay_locked():
		return
	if StoryBeatDirector.should_auto_open_beat(beat_id):
		_maybe_show_story_beat(true)
		return
	_request_scheduled_story_invite(beat_id)


func _request_scheduled_story_invite(beat_id: String) -> void:
	if _story_beat_panel.visible:
		call_deferred("_request_scheduled_story_invite", beat_id)
		return
	if not _pending_proactive_speech.is_empty():
		_pending_proactive_speech = {}
		_invite_proactive_dispatched = false
		_finish_proactive_approach()
	var speech := StoryBeatDirector.build_scheduled_invite(beat_id)
	if speech.is_empty():
		call_deferred("_maybe_show_story_beat", true)
		return
	if _should_defer_story_invite():
		_queue_deferred_story_invite(speech)
		return
	if _npc_busy:
		call_deferred("_request_scheduled_story_invite", beat_id)
		return
	CompanionDirector.mark_delivered(speech)
	_request_proactive_speech(speech)


func _has_unfinished_story_beat_today() -> bool:
	if StoryBeatDirector.has_blocking_today_beat():
		return true
	if StoryBeatDirector.has_pending_night_beat():
		return true
	return StoryBeatDirector.has_unfired_schedule_today()


func _maybe_show_story_beat(force_open: bool = false) -> void:
	if _story_choice_blocked or _story_beat_blocked or GameState.is_story_complete():
		return
	if GameState.should_show_awakening():
		return
	var beat := StoryBeatDirector.get_pending_session_beat(_pending_beat_yesterday_echo)
	if beat.is_empty() and StoryBeatDirector.has_pending_night_beat():
		if StoryBeatDirector.can_trigger_night_beat_at_hollow() or force_open:
			beat = StoryBeatDirector.get_pending_night_beat(_pending_beat_yesterday_echo)
	if beat.is_empty():
		if not force_open:
			StoryBeatDirector.refresh_daily_schedule()
		return
	var beat_id := str(beat.get("id", ""))
	if not force_open and not StoryBeatDirector.should_auto_open_beat(beat_id):
		StoryBeatDirector.refresh_daily_schedule()
		return
	_pending_beat_yesterday_echo = false
	if beat_id in ["P_N05", "BE_N05"] and not GameState.has_revealed_memory():
		GameState.mark_w2_stranger_seen()
	beat = StoryBeatDirector.take_displayable_beat(beat)
	if beat.is_empty():
		return
	beat = await StoryBeatDirector.prepare_beat_for_display(beat)
	if beat_id == "P_N06p":
		_maybe_show_d5_notebook_trust_hint()
	_story_beat_blocked = true
	if beat_id.ends_with("_N20c"):
		GameState.set_ending_flag("d9_soft_pause_beat", "")
	GameState.clear_pending_invite_beat()
	StoryBeatDirector.mark_schedule_fired()
	_open_story_beat_panel(beat)
	call_deferred("_sync_player_movement_lock")


func _open_story_beat_panel(beat: Dictionary) -> void:
	GameState.push_time_pause()
	_story_beat_panel.open(beat)


func _maybe_resume_beat_tail() -> void:
	if _story_choice_blocked or _story_beat_blocked or GameState.is_story_complete():
		return
	if _story_beat_panel.visible or _awakening_panel.visible or _ending_panel.visible:
		return
	if GameState.time_of_day not in [GameState.TIME_EVENING, GameState.TIME_NIGHT]:
		return
	var beat := StoryBeatDirector.build_beat_tail_resume()
	if beat.is_empty():
		return
	beat = await StoryBeatDirector.prepare_beat_for_display(beat)
	_story_beat_blocked = true
	_open_story_beat_panel(beat)
	call_deferred("_sync_player_movement_lock")


func deliver_companion_proactive() -> void:
	if _story_beat_panel.visible or _awakening_panel.visible or _ending_panel.visible:
		return
	if _name_prompt_panel.visible:
		return
	if (
		_is_gameplay_locked()
		or _npc_busy
		or _story_beat_blocked
		or _snuggle_blocked
		or _shop_panel.visible
		or _market_panel.visible
		or _memory_panel.visible
		or _feed_panel.visible
	):
		return
	var speech := CompanionDirector.pick_speech()
	if speech.is_empty():
		return
	CompanionDirector.mark_delivered(speech)
	_request_proactive_speech(speech)


func _on_story_beat_finished(beat_id: String) -> void:
	GameState.pop_time_pause()
	call_deferred("_sync_player_movement_lock")
	if _pending_post_snuggle_day_advance:
		_pending_post_snuggle_day_advance = false
		_story_beat_blocked = false
		if beat_id.strip_edges() != "":
			_finalize_story_beat_after_companion_night(beat_id)
		call_deferred("_finish_night_after_snuggle")
		return

	if _companion_snuggle_pending_beat_id != "":
		var snuggle_beat := _companion_snuggle_pending_beat_id
		_companion_snuggle_pending_beat_id = ""
		if beat_id.strip_edges() != "":
			if StoryBeatDirector.should_complete_beat_after_panel(beat_id):
				StoryBeatDirector.complete_beat(beat_id)
				_debug_note("主线完成：%s" % beat_id)
		_story_beat_blocked = false
		_begin_companion_snuggle(snuggle_beat)
		return

	if beat_id.strip_edges() != "":
		if StoryBeatDirector.should_complete_beat_after_panel(beat_id):
			StoryBeatDirector.complete_beat(beat_id)
			_debug_note("主线完成：%s" % beat_id)
			if beat_id == "BE_N07":
				call_deferred("_play_ending", EndingDirector.ENDING_BAD_EARLY)
	_story_beat_blocked = false
	var companion_line := _pending_companion_night_line.strip_edges()
	_pending_companion_night_line = ""
	if companion_line != "" and companion_line != "……":
		_append_companion_message(companion_line)
	if beat_id == "P_N01":
		call_deferred("_maybe_show_name_prompt")
	if beat_id in ["P_N05", "BE_N05"]:
		_show_d4_amnesia_hint_once()
	if beat_id in ["P_N01", "P_N02"]:
		call_deferred("_maybe_show_notebook_tutorial")
	CompanionDirector.schedule_consider(0.9)
	call_deferred("_maybe_trigger_persona_shift")


func _maybe_show_d5_notebook_trust_hint() -> void:
	if bool(GameState.get_ending_flags().get("d5_notebook_trust_hint_shown", false)):
		return
	GameState.set_ending_flag("d5_notebook_trust_hint_shown", true)
	_system_hint("d5_notebook_trust_hint")


func _maybe_show_notebook_tutorial() -> void:
	if not GameState.IS_TEN_DAY_EDITION:
		return
	if GameState.game_day > 2:
		return
	if bool(GameState.get_ending_flags().get("tutorial_notebook_hint_seen", false)):
		return
	GameState.set_ending_flag("tutorial_notebook_hint_seen", true)
	_system_hint("tutorial_notebook_hint")


func _on_story_beat_choice(choice_id: String) -> void:
	var beat_id := _story_beat_panel.get_beat_id()
	if beat_id == "P_N06p":
		_handle_w2_beat_choice(choice_id)
		return
	if beat_id.ends_with("_N14n") or beat_id.ends_with("_N17") or beat_id.ends_with("_N16"):
		_handle_companion_night_choice(beat_id, choice_id)
		return


func _handle_w2_beat_choice(choice_id: String) -> void:
	match choice_id:
		"w2_keep":
			_apply_w2_keep_choice()
			_story_beat_panel.finish_now()
		"w2_expel":
			_story_beat_panel.append_steps([{
				"title": StoryNodeCopy.get_choice("w2_expel_confirm_title"),
				"body": StoryNodeCopy.get_choice("w2_expel_confirm_body"),
				"kind": "choice",
				"choices": [
					{"id": "w2_expel_confirm", "label": StoryNodeCopy.get_choice("w2_expel_confirm")},
					{"id": "w2_expel_cancel", "label": StoryNodeCopy.get_choice("w2_expel_cancel")},
				],
			}])
			_story_beat_panel.show_step_at(_story_beat_panel.get_step_count() - 1)
		"w2_expel_confirm":
			_apply_w2_expel_choice()
			_story_beat_panel.finish_now()
		"w2_expel_cancel":
			_story_beat_panel.show_step_at(1)



func _handle_companion_night_choice(beat_id: String, choice_id: String) -> void:
	_apply_companion_night_choice(choice_id)
	if choice_id == "companion_sit":
		_companion_snuggle_pending_beat_id = beat_id
		_story_beat_panel.finish_now()
		return

	var after_steps: Array = []
	var pause_key := "companion_leave"
	after_steps.append({
		"title": "旧屋",
		"body": StoryNodeCopy.get_system(pause_key),
	})
	var companion_line := StoryRouteData.render_companion_night_after(beat_id, choice_id)
	_pending_companion_night_line = StoryRouteData.render_companion_night_line(beat_id, choice_id)
	if companion_line.strip_edges() != "":
		after_steps.append({
			"title": GameState.companion_name,
			"body": companion_line,
		})
	_story_beat_panel.append_steps(after_steps)
	_story_beat_panel.show_step_at(_story_beat_panel.get_step_count() - after_steps.size())


func _begin_companion_snuggle(beat_id: String) -> void:
	_snuggle_blocked = true
	_set_snuggle_controls(true)
	call_deferred("_sync_player_movement_lock")
	var farm := get_tree().get_first_node_in_group("farm_world")
	if farm != null and farm.has_method("start_companion_snuggle"):
		farm.start_companion_snuggle(func() -> void:
			_on_companion_snuggle_finished(beat_id)
		)
	else:
		_on_companion_snuggle_finished(beat_id)


func _on_companion_snuggle_finished(beat_id: String) -> void:
	_snuggle_blocked = false
	_set_snuggle_controls(false)
	call_deferred("_sync_player_movement_lock")
	var farewell := StoryRouteData.render_companion_night_farewell(beat_id)
	if farewell.strip_edges() != "":
		_append_companion_message(farewell)
	if GameState.game_day == 7 and beat_id.ends_with("_N16"):
		var afterglow := StoryNodeCopy.get_system("companion_snuggle_afterglow").strip_edges()
		if afterglow != "":
			_show_narrative_hint(afterglow)
		PlayerNotebookService.on_first_write_d7()
	if _try_show_post_snuggle_fragment(beat_id):
		return
	_finalize_story_beat_after_companion_night(beat_id)
	call_deferred("_finish_night_after_snuggle")


func _finalize_story_beat_after_companion_night(beat_id: String) -> void:
	if beat_id.strip_edges() == "":
		return
	if GameState.is_story_node_seen(beat_id):
		if GameState.get_pending_story_beat_tail_id() == beat_id:
			GameState.clear_pending_story_beat_tail()
		return
	if StoryBeatDirector.should_complete_beat_after_panel(beat_id):
		StoryBeatDirector.complete_beat(beat_id)
		_debug_note("主线完成：%s" % beat_id)


func _try_show_post_snuggle_fragment(beat_id: String) -> bool:
	var def := StoryRouteData.get_beat_def(beat_id)
	if str(def.get("fragment", "")).strip_edges() == "":
		return false
	var beat := StoryBeatDirector.build_beat(beat_id)
	var fragment_steps: Array = []
	for step in beat.get("steps", []):
		if step is Dictionary and str(step.get("kind", "")) == "fragment":
			fragment_steps.append(step)
	if fragment_steps.is_empty():
		return false
	_pending_post_snuggle_day_advance = true
	_story_beat_blocked = true
	beat["steps"] = fragment_steps
	_open_story_beat_panel(beat)
	call_deferred("_sync_player_movement_lock")
	return true


func _finish_night_after_snuggle() -> void:
	StoryBeatDirector.prepare_day_end()
	if GameState.should_show_week_wrap():
		_week_wrap_panel.open()
		return
	if GameState.is_awaiting_sleep() or GameState.can_manual_sleep():
		if not _sleep_flow_active and not _day_cycle_overlay.is_busy():
			if not _day_cycle_overlay.is_prompt_visible():
				if _can_begin_sleep(true):
					_enter_sleep_prompt_mode()
					_day_cycle_overlay.show_sleep_prompt()
		return
	_advance_to_next_day()


func _set_snuggle_controls(active: bool) -> void:
	_chat_input.editable = not active
	_chat_send.disabled = active
	for button in [_next_day_button, _market_button, _memory_button]:
		button.disabled = active
	if active:
		_chat_input.placeholder_text = "正在和小狸依偎中…"
		_chat_input.release_focus()
	elif not GameState.is_story_complete():
		_chat_input.placeholder_text = "和小狸说点什么…"


func _apply_companion_night_choice(choice_id: String) -> void:
	match choice_id:
		"companion_sit":
			GameState.mark_companion_choice(true)
		"companion_leave":
			GameState.mark_companion_choice(false)


func _apply_w2_keep_choice() -> void:
	GameState.mark_w2_keep_choice()
	StoryBeatDirector.refresh_story_route()
	_debug_note("收留 · 路线 %s" % StoryBeatDirector.get_route_label())


func _apply_w2_expel_choice() -> void:
	GameState.mark_w2_expel_choice()
	GameState.lock_story_route(StoryRouteData.ROUTE_BAD_EARLY)
	_debug_note("送走 · 早坏线")


func _play_ending(ending_id: String) -> void:
	_story_choice_blocked = true
	_ending_panel.open(ending_id)


func _on_ending_finished(action: String) -> void:
	## 十日收束：回到标题。不自动开下一轮。重玩请在标题选「新游戏」。
	if action == "restart":
		get_tree().change_scene_to_file("res://scenes/title_screen.tscn")
		return
	if action == "title" or action == "done":
		get_tree().change_scene_to_file("res://scenes/title_screen.tscn")
		return
	_enter_game_over_state()


func _enter_game_over_state() -> void:
	_story_choice_blocked = true
	_set_gameplay_controls_enabled(false)
	var ending_id := GameState.get_final_ending_id()
	if ending_id.strip_edges() == "":
		ending_id = EndingDirector.ENDING_NORMAL
	_ending_panel.open_game_over(ending_id)


func _is_gameplay_locked() -> bool:
	return (
		GameState.is_story_complete()
		or _story_choice_blocked
		or _name_prompt_panel.visible
		or _snuggle_blocked
		or _sleep_flow_active
		or (_day_cycle_overlay != null and _day_cycle_overlay.is_busy())
		or (_day_cycle_overlay != null and _day_cycle_overlay.is_prompt_visible())
	)


func _set_gameplay_controls_enabled(enabled: bool) -> void:
	_chat_input.editable = enabled
	for button in [_chat_send, _next_day_button, _market_button, _memory_button]:
		button.disabled = not enabled
	if _basket_button:
		_basket_button.disabled = not enabled
	if not enabled:
		_chat_input.placeholder_text = _locked_chat_placeholder()
		if _basket_drawer and _basket_drawer.is_open():
			_basket_drawer.close_drawer()
	else:
		_chat_input.placeholder_text = "…（轻声对小狸说）"


func _locked_chat_placeholder() -> String:
	if GameState.is_story_complete():
		return "故事已结束"
	if _name_prompt_blocked or (_name_prompt_panel != null and _name_prompt_panel.visible):
		return "先写下你的名字"
	if _sleep_flow_active:
		return "夜里了"
	return "…"


func _on_story_route_changed(old_route: String, new_route: String) -> void:
	var msg := StoryRouteData.render_route_shift_message(old_route, new_route)
	_debug_note("路线 %s → %s" % [old_route, new_route])
	if msg.strip_edges() == "":
		return
	# 关系转向：一句轻旁白，不写路线码，也不假装是她说的。
	_hint(msg)


func on_tree_hollow_clicked() -> void:
	if _is_gameplay_locked():
		return
	if _story_beat_blocked:
		return
	CompanionDirector.notify_player_active()
	if StoryBeatDirector.has_pending_night_beat() and not StoryBeatDirector.is_beat_seen(StoryBeatDirector.get_pending_night_beat_id()):
		_hint("今晚她会来找你。再等等。")
		return
	_hint(StoryNodeCopy.get_system("tree_hollow_day"))


func on_plot_clicked(plot_id: int, _world_pos: Vector2) -> void:
	if _is_gameplay_locked():
		return
	if _blocks_farm_chores(true):
		return

	var plot := GameState.get_plot(plot_id)
	var stage := int(plot.get("stage", 0))

	if stage == 0:
		if GameState.plant_turnip(plot_id):
			_companion_farm_reaction("plant_ok")
			_clear_companion_aside()
			_refresh_hud()
		else:
			_companion_farm_reaction("no_seeds")
		return

	if GameState.can_harvest(plot_id):
		if GameState.harvest_turnip(plot_id):
			_companion_farm_reaction("harvest_ok")
			_clear_companion_aside()
			_refresh_hud()
		else:
			_companion_farm_reaction("harvest_failed")
		return

	if stage >= GameState.MATURE_STAGE:
		_companion_farm_reaction("not_mature")
		return

	if plot_id in GameState.watered_plots or bool(plot.get("watered", false)):
		_companion_farm_reaction("already_watered")
		return

	if GameState.weather_today == GameState.WEATHER_RAIN:
		_companion_farm_reaction("rain")
		return

	GameState.mark_plot_watered(plot_id)
	AmbientAudio.play_prop_sfx("water")
	_companion_farm_reaction("water_ok")
	_clear_companion_aside()
	_refresh_hud()


func on_door_clicked() -> void:
	CompanionDirector.notify_player_active()
	_hint("旧屋今天不用进。田埂上还有她在。")


func on_shop_clicked() -> void:
	if _blocks_farm_chores(true):
		return
	if TaskSystem.is_busy():
		_hint("她还在走动。")
		return
	if _feed_panel.visible:
		_feed_panel.close()
	if _market_panel.visible:
		_market_panel.close()
	if _memory_panel.visible:
		_memory_panel.close()
	_shop_panel.open()


func on_companion_clicked() -> void:
	if _is_gameplay_locked():
		return
	CompanionDirector.notify_player_active()
	if GameState.get_owned_treats().size() > 0:
		if _shop_panel.visible:
			_shop_panel.close()
		if _market_panel.visible:
			_market_panel.close()
		if _memory_panel.visible:
			_memory_panel.close()
		_feed_panel.open()
		return

	_chat_input.grab_focus()
	if _npc_busy:
		return
	_append_companion_message("嗯？想和我说说话吗？")


func on_need_closer() -> void:
	_companion_farm_reaction("need_closer")


func _on_feed_closed() -> void:
	pass


func _on_shop_closed() -> void:
	pass


func _sell_turnips_from_basket() -> void:
	if _is_gameplay_locked():
		return
	var sold := GameState.sell_all_turnips()
	_hint(str(sold.get("message", "")))
	_refresh_hud()


func _on_market_pressed() -> void:
	_sell_turnips_from_basket()


func _dismiss_overlays_for_memory() -> void:
	if _basket_drawer and _basket_drawer.is_open():
		_basket_drawer.close_drawer()
	if _feed_panel.visible:
		_feed_panel.close()
	if _shop_panel.visible:
		_shop_panel.close()
	if _market_panel.visible:
		_market_panel.close()


func _on_memory_pressed() -> void:
	if _is_gameplay_locked():
		return
	_dismiss_overlays_for_memory()
	_memory_panel.open()
	_maybe_show_d4_memory_panel_hint()


func on_companion_notebook_clicked() -> void:
	if _is_gameplay_locked() or _story_beat_blocked:
		return
	CompanionDirector.notify_player_active()
	_dismiss_overlays_for_memory()
	_memory_panel.open_companion_notebook()


func on_player_notebook_clicked() -> void:
	if _is_gameplay_locked() or _story_beat_blocked:
		return
	CompanionDirector.notify_player_active()
	_dismiss_overlays_for_memory()
	_memory_panel.open_player_notebook()


func _maybe_resume_pending_eviction() -> void:
	if not MemoryService.has_pending_eviction():
		return
	if _is_gameplay_locked() or _story_beat_panel.visible or _npc_busy:
		_notebook_eviction_retries += 1
		if _notebook_eviction_retries > 20:
			_notebook_eviction_retries = 0
			return
		call_deferred("_maybe_resume_pending_eviction")
		return
	_notebook_eviction_retries = 0
	_show_notebook_eviction(MemoryService.get_pending_eviction_candidates())


func _on_anchor_eviction_pending(candidates: Array) -> void:
	call_deferred("_show_notebook_eviction", candidates)


func _show_notebook_eviction(candidates: Array) -> void:
	if candidates.size() < 2:
		return
	if _is_gameplay_locked() or _story_beat_panel.visible:
		_notebook_eviction_retries += 1
		if _notebook_eviction_retries > 20:
			_notebook_eviction_retries = 0
			return
		call_deferred("_show_notebook_eviction", candidates)
		return
	_notebook_eviction_retries = 0
	_notebook_eviction_active = true
	_story_choice_blocked = true
	var choices: Array = []
	for raw in candidates:
		if not raw is Dictionary:
			continue
		var entry: Dictionary = raw
		var summary := str(entry.get("summary", "")).strip_edges()
		if summary.length() > 36:
			summary = summary.substr(0, 36) + "…"
		choices.append({
			"id": str(entry.get("id", "")),
			"label": summary if summary != "" else "这一页",
		})
	if choices.size() < 2:
		_notebook_eviction_active = false
		_story_choice_blocked = false
		return
	if _story_choice_panel.has_method("open"):
		_story_choice_panel.open({
			"title": "她的本子",
			"body": "本子写满了。\n\n%s 翻来翻去，停在两页之间。\n\n「……我得划掉一条。」" % GameState.companion_name,
			"choices": choices,
		})


func _on_story_choice_chosen(choice_id: String) -> void:
	choice_id = choice_id.strip_edges()
	if choice_id == "":
		return
	# 本子划页：StoryChoicePanel 仅用于 eviction；勿依赖 _notebook_eviction_active（自动化/harness 可能竞态）
	if MemoryService.has_pending_eviction():
		_notebook_eviction_active = false
		_story_choice_blocked = false
		var erased_summary := ""
		for entry in MemoryService.get_pending_eviction_candidates():
			if str(entry.get("id", "")) == choice_id:
				erased_summary = str(entry.get("summary", "")).strip_edges()
				break
		MemoryService.resolve_eviction(choice_id)
		if _story_choice_panel.has_method("close_panel"):
			_story_choice_panel.close_panel()
		if erased_summary != "":
			if erased_summary.length() > 28:
				erased_summary = erased_summary.substr(0, 28) + "…"
			_append_companion_message("……划掉了。「%s」——以后想不起来，别怪我。" % erased_summary)
		else:
			_append_companion_message("……划掉了。以后想不起来，别怪我。")


func _maybe_trigger_persona_shift() -> void:
	if _npc_busy or _is_gameplay_locked() or GameState.is_story_complete():
		return
	if StoryDirector.is_stranger_mode() or GameState.is_night():
		return
	if (
		_story_beat_blocked
		or _story_beat_panel.visible
		or _story_choice_panel.visible
		or _awakening_panel.visible
	):
		return
	if not GameState.can_proactive_speech("react"):
		return
	var shift := GameState.peek_persona_shift()
	if shift.is_empty():
		return
	_request_companion_react("persona_shift", shift)


func _on_feed_requested(item_id: String) -> void:
	if _npc_busy:
		_feed_panel.set_status_message("小狸还在想上一句话…")
		return

	var check := GameState.inspect_feed_attempt(item_id)
	match str(check.get("status", "")):
		"invalid_item":
			_feed_panel.set_status_message("这个不能投喂。")
			return
		"no_item":
			_feed_panel.set_status_message(
				"背包里没有 %s。" % str(check.get("item_name", "这份零食"))
			)
			_feed_panel.rebuild()
			return
		"refuse_already", "refuse_many":
			_pending_feed_item_id = item_id
			_pending_feed_refuse = true
			_request_companion_line("companion_feed", {
				"feed_item": check.get("item", {}),
				"refused": true,
				"pester_count": int(check.get("pester_count", 1)),
				"previous_replies": GameState.get_today_feed_replies(),
			})
			return
		"ok":
			_pending_feed_item_id = item_id
			_pending_feed_refuse = false
			_request_companion_line("companion_feed", {
				"feed_item": check.get("item", {}),
				"refused": false,
				"previous_replies": GameState.get_today_feed_replies(),
			})
			return
		_:
			_feed_panel.set_status_message("暂时没法投喂。")


func _open_feed_beat(beat: Dictionary) -> void:
	_story_beat_blocked = true
	_open_story_beat_panel(beat)
	call_deferred("_sync_player_movement_lock")


func _count_treats() -> int:
	var total := 0
	for item in ShopCatalog.get_treat_items():
		total += GameState.get_item_count(str(item.get("inventory_key", "")))
	return total


func _on_confirm_pressed() -> void:
	pass


func _on_cancel_pressed() -> void:
	_task_panel.visible = false


func _on_task_started(_task_type: TaskSystem.TaskType, _label: String) -> void:
	# 小狸任务进度由头顶气泡展示，不再弹出任务面板
	pass


func _on_task_progress(_seconds_left: float) -> void:
	pass


func _on_task_completed(task_type: TaskSystem.TaskType, _summary: String, game_facts: Dictionary) -> void:
	_refresh_hud()
	if _farm_chain_after_task == "water_all" and task_type == TaskSystem.TaskType.PLANT:
		_farm_chain_after_task = ""
		var planted_line := NpcFallback.task_complete(game_facts, {})
		if planted_line.strip_edges() != "":
			_append_companion_message(planted_line)
		_try_start_water_all_after_buy(true)
		return
	if _auto_seed_shop_flow and task_type == TaskSystem.TaskType.SHOP:
		return
	_request_companion_line("task_complete", {"game_facts": game_facts})


func _on_next_day_pressed() -> void:
	_start_sleep_flow()


func _on_week_wrap_confirmed() -> void:
	_start_sleep_flow()


func _advance_to_next_day() -> void:
	_start_sleep_flow()


func _on_day_advanced() -> void:
	if _defer_day_content:
		return
	_handle_day_advanced_content()


func _handle_day_advanced_content() -> void:
	_restore_chat_history()
	if GameState.IS_TEN_DAY_EDITION and GameState.game_day >= 5:
		# 十日 D5 锁路线；D6–D9 每天按当前结局投影刷新（35 日是 D22/D29）。
		StoryBeatDirector.refresh_story_route()
	elif GameState.game_day >= 10:
		StoryBeatDirector.ensure_story_route_locked()
	if not GameState.IS_TEN_DAY_EDITION and GameState.game_day in [22, 29]:
		StoryBeatDirector.refresh_story_route()
	if GameState.should_force_story_finale():
		call_deferred("_maybe_force_story_finale")
		return
	if GameState.game_day == GameState.FINAL_GAME_DAY:
		StoryBeatDirector.resolve_finale_day_carryover()
	if GameState.should_show_awakening():
		call_deferred("_maybe_show_awakening")
		return
	_pending_beat_yesterday_echo = true
	_pending_morning_sidewrite = true
	_session_start_retries = 0
	_ambient_sidewrite_retries = 0
	StoryBeatDirector.refresh_daily_schedule()
	if StoryBeatDirector.has_pending_night_beat():
		_hint(StoryNodeCopy.get_system("tree_hollow_night_wait"))
	call_deferred("_maybe_show_story_beat")
	call_deferred("_maybe_request_session_start")
	if GameState.IS_TEN_DAY_EDITION and GameState.game_day == 4:
		call_deferred("_begin_d4_trust_telegraph")


func _on_week_reset(week_index: int) -> void:
	if week_index == 2:
		_hint("她看你的眼神，好像有点不一样。")


func _on_chat_send_pressed() -> void:
	_send_chat(_chat_input.text)


func _on_chat_submitted(text: String) -> void:
	_send_chat(text)


func open_market_from_companion() -> void:
	if _is_gameplay_locked():
		return
	_sell_turnips_from_basket()


func begin_companion_seed_purchase() -> void:
	if _seed_purchase_resolved:
		return

	_pending_seed_purchase = true

	if _queued_seed_count > 0:
		var queued := _queued_seed_count
		_queued_seed_count = -1
		_execute_companion_seed_purchase(queued, false)
		return

	var preset := ShopDelegate.parse_seed_purchase_quantity(_pending_seed_source_text)
	if preset > 0:
		_execute_companion_seed_purchase(preset, false)
		if _seed_purchase_resolved or not _pending_seed_purchase:
			return

	if _seed_quantity_prompted:
		return

	_seed_quantity_prompted = true
	_append_companion_message("要买几包萝卜种子？说个数字就行。")


func open_shop_from_companion() -> void:
	if _is_gameplay_locked():
		return
	if _blocks_farm_chores(true):
		return
	if TaskSystem.is_busy():
		_hint("她还在走动。")
		return
	if _feed_panel.visible:
		_feed_panel.close()
	if _market_panel.visible:
		_market_panel.close()
	if _memory_panel.visible:
		_memory_panel.close()
	_shop_panel.open()


func open_memory_from_companion() -> void:
	if _is_gameplay_locked():
		return
	if TaskSystem.is_busy():
		_hint("她还在走动。")
		return
	_dismiss_overlays_for_memory()
	_memory_panel.open()
	_maybe_show_d4_memory_panel_hint()


func sleep_from_companion() -> void:
	if _sleep_flow_active:
		return
	if _name_prompt_blocked or (_name_prompt_panel != null and _name_prompt_panel.visible):
		return
	if _day_cycle_overlay != null and _day_cycle_overlay.is_busy() and not _day_cycle_overlay.is_prompt_visible():
		return
	if _story_beat_panel.visible or _story_beat_blocked:
		_system_hint("blocking_story_beat")
		call_deferred("_maybe_show_story_beat", true)
		return
	TaskSystem.reconcile_stale_task()
	if TaskSystem.is_busy():
		_system_hint("blocking_companion_busy")
		return
	if not _can_begin_sleep(true):
		return
	if _day_cycle_overlay != null and _day_cycle_overlay.is_prompt_visible():
		_exit_sleep_prompt_mode()
	_start_sleep_flow()


func _try_sleep_from_chat() -> void:
	_queued_busy_chat = ""
	if _has_unfinished_story_beat_today():
		if StoryBeatDirector.should_force_schedule_now():
			call_deferred("_maybe_show_story_beat", true)
		_system_hint("blocking_sleep_story")
		_append_companion_message("信纸还没翻完呢。看完再睡？")
		return
	TaskSystem.reconcile_stale_task()
	if TaskSystem.is_busy():
		_system_hint("blocking_companion_busy")
		_append_companion_message("等我忙完手上这一阵，再一起睡。")
		return
	if not _can_begin_sleep(true):
		return
	_append_companion_message(_sleep_ack_line())
	sleep_from_companion()


func _sleep_ack_line() -> String:
	if GameState.weather_today == GameState.WEATHER_RAIN:
		return "好，睡吧。这雨声听着就困。"
	return "好，睡吧。"


func _send_chat(text: String) -> void:
	_send_chat_async(text)


func _send_chat_async(text: String) -> void:
	var trimmed := text.strip_edges()
	if trimmed.is_empty():
		return
	if _is_gameplay_locked():
		return

	# 睡觉指令不排队等 LLM：否则会在次日清晨才被当作普通聊天处理。
	if IntentParser.looks_like_sleep_request(trimmed):
		CompanionDirector.notify_player_active()
		_mark_chat_activity()
		_clear_companion_aside()
		_chat_input.clear()
		GameState.record_player_chat(trimmed)
		_append_player_message(trimmed)
		_try_sleep_from_chat()
		return

	if _npc_busy:
		_queued_busy_chat = trimmed
		if _feed_panel:
			_feed_panel.set_status_message("小狸还在想上一句话…")
		_hint("小狸还在想上一句话…")
		return

	CompanionDirector.notify_player_active()
	_mark_chat_activity()
	_clear_companion_aside()
	_chat_input.clear()
	GameState.record_player_chat(trimmed)
	_append_player_message(trimmed)

	_ensure_pending_invite_delivered()

	if _try_answer_chore_progress_inquiry(trimmed):
		return

	if _try_answer_chore_completion_statement(trimmed):
		return

	if _try_answer_planting_rebuttal(trimmed):
		return

	if MemoryService.looks_like_pin_request(trimmed):
		var pin_result := MemoryService.pin_from_player_chat(trimmed)
		if bool(pin_result.get("ok", false)):
			var pinned_summary := str(pin_result.get("summary", "")).strip_edges()
			if pinned_summary != "":
				_append_companion_message("写进本子了——「%s」。" % pinned_summary)
			else:
				_append_companion_message("写进本子了。")
			return

	if IntentParser.looks_like_stop_farm_chore(trimmed):
		if _try_cancel_active_chore_from_chat():
			_pending_chat_text = ""
			_append_companion_message("好。那我先停下手上的。")
			return

	if _try_handle_seed_quantity_reply(trimmed):
		return

	if ShopDelegate.is_affirmative_reply(trimmed):
		_maybe_arm_pending_from_last_companion_line()

	if _try_handle_water_offer_reply(trimmed):
		return

	if _try_handle_shop_offer_reply(trimmed):
		return

	if _try_handle_plant_offer_reply(trimmed):
		return

	if _try_handle_harvest_offer_reply(trimmed):
		return

	if _try_start_plant_from_correction(trimmed):
		_pending_chat_text = ""
		return

	_pending_chat_text = trimmed
	_chat_action_handled = false
	_skip_player_chat_reply = false

	var local_intent := IntentParser.parse(trimmed)
	var classify_attempted := IntentBridge.should_fallback(local_intent)
	var api_intent := {}
	if classify_attempted:
		_set_npc_busy(true)
		api_intent = await IntentBridge.classify_message(trimmed)
		_set_npc_busy(false)

	_pending_chat_intent = IntentParser.resolve_misclassified_refuse(
		IntentParser.merge_intents(local_intent, api_intent, trimmed, classify_attempted)
	)

	var guard := PersonaGuard.check_intent(_pending_chat_intent)
	if bool(guard.get("blocked", false)):
		_pending_chat_intent = {}
		_pending_chat_text = ""
		_append_companion_message(str(guard.get("reply", "")))
		_set_npc_busy(false)
		return

	_try_execute_chat_intent(true)

	if _skip_player_chat_reply:
		_pending_chat_text = ""
		return

	_request_companion_line("player_chat", {
		"player_message": trimmed,
		"parsed_intent": _pending_chat_intent,
		"needs_intent_fallback": IntentBridge.should_fallback(local_intent),
	})


func _request_companion_line(event: String, extra: Dictionary = {}) -> void:
	_pending_session_absence = event == "session_start" and bool(extra.get("include_absence_comeback", false))
	_set_npc_busy(true)
	NpcBridge.request_event(event, extra)


func _on_npc_reply_ready(
	request_id: int,
	event: String,
	text: String,
	used_fallback: bool
) -> void:
	if event == "companion_feed":
		_handle_companion_feed_reply(request_id, text, used_fallback)
		return

	if event == "companion_react":
		_set_npc_busy(false)
		var reacted := text.strip_edges()
		var react_type := _pending_react_type
		var react_facts := _pending_react_facts
		_pending_react_type = ""
		_pending_react_facts = {}
		if react_type == "persona_shift":
			GameState.mark_persona_shift_announced(str(react_facts.get("dimension", "")))
		if reacted != "" and reacted != "……":
			_append_companion_message(reacted)
		return

	if event == "story_beat":
		_set_npc_busy(false)
		return

	if event == "story_step_render":
		return

	if event == "day_journal_summarize":
		_set_npc_busy(false)
		return

	if event == "morning_sidewrite":
		_set_npc_busy(false)
		var ambient_line := text.strip_edges()
		if ambient_line == "" or ambient_line == "……":
			ambient_line = _ambient_sidewrite_fallback()
		if ambient_line.strip_edges() != "":
			if GameState.can_proactive_speech("ambient"):
				GameState.consume_proactive_speech("ambient", {"kind": "rain_porch"})
			GameState.record_initiation("ambient", {"kind": "rain_porch"}, ambient_line)
			_append_companion_message(ambient_line, true)
		return

	if event == "companion_casual" or event == "companion_proactive":
		_set_npc_busy(false)
		var spoken := text.strip_edges()
		if spoken == "" or spoken == "……":
			spoken = _casual_fallback_line()
		var channel := str(_pending_proactive_speech.get("channel", "casual"))
		var beat_id := str(_pending_proactive_speech.get("beat_id", ""))
		GameState.record_initiation(channel, {"beat_id": beat_id}, spoken)
		_pending_proactive_speech = {}
		_append_companion_message(spoken)
		_finish_proactive_approach()
		if channel == "invite" and beat_id != "" and not StoryBeatDirector.is_beat_seen(beat_id):
			_maybe_open_story_after_invite(beat_id)
		return

	if event == "player_chat" and _should_discard_player_chat_reply():
		_set_npc_busy(false)
		NpcBridge.take_chat_intent(request_id)
		_pending_chat_text = ""
		return

	_set_npc_busy(false)
	var display_text := text
	var farm_reply_grounded := false
	if event == "player_chat":
		display_text = _sanitize_sleep_hijack(_pending_chat_text, display_text)
		display_text = _sanitize_unrequested_sleep_push(_pending_chat_text, display_text)
		var sanitized := _sanitize_farm_hallucination(display_text)
		farm_reply_grounded = sanitized.strip_edges() != text.strip_edges()
		display_text = sanitized
	_append_companion_message(display_text)
	_show_api_source_hint(request_id, used_fallback)

	if event == "session_start" and bool(_pending_session_absence):
		GameState.mark_absence_shown()
		_pending_session_absence = false
	if event == "session_start":
		call_deferred("_maybe_request_ambient_sidewrite")

	if event == "player_chat":
		_apply_relationship_delta(request_id, event, _pending_chat_text, used_fallback)
		_show_citation_feedback(request_id, used_fallback)
		if farm_reply_grounded:
			_chat_action_handled = true
		if not _chat_action_handled:
			var chat_api_intent := NpcBridge.take_chat_intent(request_id)
			if not chat_api_intent.is_empty():
				_pending_chat_intent = IntentParser.resolve_misclassified_refuse(
					IntentParser.merge_intents(
						_pending_chat_intent,
						chat_api_intent,
						_pending_chat_text
					)
				)
			_try_execute_chat_intent(false)
			if not _chat_action_handled:
				_try_execute_companion_followthrough(display_text, chat_api_intent)
		else:
			NpcBridge.take_chat_intent(request_id)
		var player_line := _pending_chat_text
		if (
			not _chat_action_handled
			and IntentParser.looks_like_sleep_request(player_line)
			and ShopDelegate.looks_like_sleep_commitment(display_text)
		):
			call_deferred("_try_sleep_from_chat")
		_maybe_show_d4_amnesia_hint(_pending_chat_text)
		_mark_chat_activity()
		_pending_chat_text = ""
		return


func _on_npc_request_failed(request_id: int, event: String, _error: String) -> void:
	if event in ["player_chat", "session_start", "task_complete", "day_end"]:
		_set_npc_busy(false)
		if event == "player_chat" and _pending_chat_text.strip_edges() != "":
			var fallback := NpcFallback.player_chat(
				_pending_chat_text,
				GameState.get_stage(),
				MemoryService.get_context_for_event("player_chat", {"player_message": _pending_chat_text}),
				{"player_message": _pending_chat_text, "story_mode": StoryDirector.get_story_mode()}
			)
			if fallback.strip_edges() != "":
				_append_companion_message(fallback)
			else:
				_append_companion_message("……你刚才说的，我再想想。")
			_pending_chat_text = ""
		return
	if event == "morning_sidewrite":
		_set_npc_busy(false)
		var ambient_line := _ambient_sidewrite_fallback()
		if ambient_line.strip_edges() != "":
			if GameState.can_proactive_speech("ambient"):
				GameState.consume_proactive_speech("ambient", {"kind": "rain_porch"})
			GameState.record_initiation("ambient", {"kind": "rain_porch"}, ambient_line)
			_append_companion_message(ambient_line, true)
		return
	if event == "companion_casual" or event == "companion_proactive":
		_set_npc_busy(false)
		var casual := _casual_fallback_line()
		var channel := str(_pending_proactive_speech.get("channel", "casual"))
		var beat_id := str(_pending_proactive_speech.get("beat_id", ""))
		GameState.record_initiation(channel, {"beat_id": beat_id}, casual)
		_pending_proactive_speech = {}
		_append_companion_message(casual)
		_finish_proactive_approach()
		if channel == "invite" and beat_id != "" and not StoryBeatDirector.is_beat_seen(beat_id):
			_maybe_open_story_after_invite(beat_id)
		return
	if event == "companion_react":
		_set_npc_busy(false)
		var react_type := _pending_react_type
		var react_facts := _pending_react_facts
		_pending_react_type = ""
		_pending_react_facts = {}
		if react_type == "":
			return
		var snapshot := WorldSnapshot.capture({
			"react_type": react_type,
			"react_facts": react_facts,
		})
		var local := NpcFallback.companion_react(
			react_type,
			snapshot,
			StoryDirector.get_story_hint(),
			GameState.get_stage(),
			MemoryService.get_context_for_event("companion_react", {})
		)
		if local.strip_edges() != "":
			_append_companion_message(local)
		if react_type == "persona_shift":
			GameState.mark_persona_shift_announced(str(react_facts.get("dimension", "")))
		return
	if event != "companion_feed":
		return
	var item := ShopCatalog.get_treat_item(_pending_feed_item_id)
	var fallback := NpcFallback.companion_feed(
		item,
		GameState.get_today_feed_replies(),
		_pending_feed_refuse,
		GameState.feed_pester_count
	)
	_handle_companion_feed_reply(request_id, fallback, true)


func _handle_companion_feed_reply(request_id: int, text: String, used_fallback: bool) -> void:
	_set_npc_busy(false)
	var item := ShopCatalog.get_treat_item(_pending_feed_item_id)
	var previous := GameState.get_today_feed_replies()
	var reply := _finalize_feed_reply(text, item, previous, _pending_feed_refuse)

	if _pending_feed_refuse:
		GameState.register_feed_reply(reply)
		_feed_panel.set_status_message("今天已经投喂过了。")
		_append_companion_message(reply)
		_show_api_source_hint(request_id, used_fallback)
		_pending_feed_item_id = ""
		_pending_feed_refuse = false
		return

	var commit := GameState.commit_feed_treat(_pending_feed_item_id)
	if not bool(commit.get("ok", false)):
		_feed_panel.set_status_message("投喂没成功，零食还在背包里。")
		_pending_feed_item_id = ""
		_pending_feed_refuse = false
		return

	GameState.register_feed_reply(reply)
	_refresh_hud()
	# 投喂结果由她的回话交代，不再叠系统旁白。
	_append_companion_message(reply)
	if GameState.try_fulfill_promise_from_feed():
		var fulfill_line := StoryNodeCopy.get_system("promise_fulfilled_feed_companion").strip_edges()
		if fulfill_line != "":
			_append_companion_message(fulfill_line)
	_show_api_source_hint(request_id, used_fallback)
	_feed_panel.set_status_message("")
	_feed_panel.rebuild()

	var feed_beat := StoryBeatDirector.get_pending_feed_beat()
	if not feed_beat.is_empty():
		call_deferred("_open_feed_beat", feed_beat)
	if GameState.get_owned_treats().is_empty():
		_feed_panel.close()

	_pending_feed_item_id = ""
	_pending_feed_refuse = false


func _finalize_feed_reply(
	text: String,
	item: Dictionary,
	previous: Array[String],
	refused: bool
) -> String:
	var cleaned := text.strip_edges()
	if _is_acceptable_feed_reply(cleaned, previous, refused, item):
		return cleaned
	return NpcFallback.companion_feed(
		item,
		previous,
		refused,
		GameState.feed_pester_count
	)


func _is_acceptable_feed_reply(
	text: String,
	previous: Array[String],
	refused: bool,
	item: Dictionary = {}
) -> bool:
	if text.length() < 4:
		return false
	for line in previous:
		if line == text:
			return false
	var bland := [
		"可以", "好的", "好", "嗯", "好好吃", "谢谢你", "谢谢", "收到", "知道了",
	]
	for phrase in bland:
		if text == phrase or text == phrase + "。" or text == phrase + "～":
			return false
	var payload := {
		"refused": refused,
		"feed_item": item,
	}
	if ResponseValidator.is_off_topic_feed_reply(text, payload):
		return false
	if not refused:
		for phrase in ["不行", "不要", "吃不下", "饱了", "够了"]:
			if phrase in text:
				return false
	return true


func _apply_relationship_delta(
	request_id: int,
	event: String,
	player_text: String,
	used_fallback: bool
) -> void:
	var delta := NpcBridge.take_relationship_delta(request_id)
	if delta.is_empty() and (used_fallback or not NpcBridge.is_api_enabled()):
		delta = RelationshipDirector.estimate_local_delta(player_text, event)
	if delta.is_empty():
		return
	var aff := int(delta.get("affection_delta", 0))
	RelationshipDirector.apply_llm_relationship_delta(delta, event)
	## 去 AI 味：关系变化不再以「亲密度 +N（原因）」数字提示外露，
	## 改由篮子里的关系小苗体现（P1d）。仅调试模式打印。
	if not SHOW_LLM_DEBUG:
		return
	var reason := str(delta.get("relationship_reason", "")).strip_edges()
	if aff > 0:
		var line := "亲密度 +%d" % aff
		if reason != "":
			line += "（%s）" % reason
		_debug_note(line)
	elif aff < 0:
		var line := "亲密度 %d" % aff
		if reason != "":
			line += "（%s）" % reason
		_debug_note(line)
	elif reason != "" and reason not in ["空消息", "敷衍回应", "节点搭话，等玩家回应后再计分"]:
		_debug_note("（%s）" % reason)
	if used_fallback and event == "player_chat":
		_debug_note("（本地判定 · 未接大模型）")


func _show_citation_feedback(request_id: int, used_fallback: bool) -> void:
	if used_fallback or not NpcBridge.is_api_enabled():
		NpcBridge.take_cited_memory_ids(request_id)
		return
	var cited_ids := NpcBridge.take_cited_memory_ids(request_id)
	if cited_ids.is_empty():
		return
	var line := MemoryService.build_citation_feedback(cited_ids)
	if line == "":
		return
	var dedupe_key := line.strip_edges()
	if dedupe_key in _recent_citation_summaries:
		return
	_recent_citation_summaries.append(dedupe_key)
	if _recent_citation_summaries.size() > 8:
		_recent_citation_summaries.remove_at(0)
	## 渗漏期去掉括号，让「想起来」直接混进她的话里；其余日子保留括号做旁注。
	if _should_show_leak_citation():
		_append_companion_message(_format_leak_citation(line))
		return
	_append_companion_message(line)


func _should_show_leak_citation() -> bool:
	if not GameState.IS_TEN_DAY_EDITION:
		return false
	return GameState.game_day in [6, 7, 8] and StoryDirector.get_story_mode() == "leak"


func _format_leak_citation(raw: String) -> String:
	var cleaned := raw.strip_edges()
	if cleaned.begins_with("（") and cleaned.ends_with("）"):
		cleaned = cleaned.substr(1, cleaned.length() - 2).strip_edges()
	return cleaned


func _try_answer_chore_progress_inquiry(text: String) -> bool:
	var line := PersonaGuard.reply_for_chore_progress_inquiry(text)
	if line.strip_edges() == "":
		return false
	_append_companion_message(line)
	return true


func _try_answer_chore_completion_statement(text: String) -> bool:
	if not IntentParser.looks_like_chore_completion_statement(text):
		return false
	var compact := text.strip_edges().replace(" ", "").replace("　", "")
	_pending_harvest_offer = false
	_pending_plant_offer = false
	_pending_water_offer = false
	if "收" in compact or "摘" in compact:
		var harvestable := int(GameState.get_plot_summary().get("harvestable", 0))
		if harvestable > 0:
			_append_companion_message("嗯，还有 %d 块没收呢。" % harvestable)
		else:
			_append_companion_message("好，收干净了。")
		return true
	if "种" in compact:
		if GameState.get_plantable_plot_ids().is_empty():
			_append_companion_message("好，种上了。")
		else:
			_append_companion_message("还有空田，要接着种吗？")
		return true
	if "浇" in compact:
		if GameState.get_unwatered_growing_plot_ids().is_empty():
			_append_companion_message("好，都浇过了。")
		else:
			_append_companion_message("还有几块没浇，要我去吗？")
		return true
	if "买" in compact or "种子" in compact:
		_append_companion_message("好，种子在篮子里了。")
		return true
	return false


func _maybe_sync_companion_move_from_line(text: String) -> void:
	if text.strip_edges() == "":
		return
	if TaskSystem.is_busy() or CompanionAgent.is_proactive_active():
		return
	if _line_commits_to_porch(text):
		CompanionAgent.go_to_poi("porch", "在廊下")


func _line_commits_to_porch(text: String) -> bool:
	var compact := text.strip_edges().replace(" ", "").replace("　", "")
	if compact == "" or "廊下" not in compact:
		return false
	if compact.contains("要不要") and compact.contains("廊下"):
		return false
	for phrase in [
		"走到廊下", "去廊下", "到廊下", "往廊下", "回廊下",
		"占了廊下", "占廊下", "廊下坐", "廊下躲", "廊下歇",
		"在廊下坐", "在廊下等", "咱们廊下", "我们廊下",
	]:
		if phrase in compact:
			return true
	return false


func _blocks_farm_chores(show_hint: bool = false) -> bool:
	if not GameState.is_pure_narrative_day():
		return false
	if show_hint:
		_system_hint("blocking_farm_d10")
	return true


func _show_api_source_hint(request_id: int, used_fallback: bool) -> void:
	if used_fallback:
		return
	var meta := NpcBridge.take_response_meta(request_id)
	## 去 AI 味：mock / 降级 / 「非大模型」等来源提示不进玩家可见流，仅调试可见。
	if not SHOW_LLM_DEBUG:
		return
	var source := str(meta.get("source", ""))
	match source:
		"mock_fallback":
			var reason := str(meta.get("fallback_reason", "")).strip_edges()
			if reason != "":
				_debug_note("（LLM 失败，已降级 mock：%s）" % reason)
			else:
				_debug_note("（LLM 失败，已降级 mock）")
		"mock":
			if _api_mock_hint_shown:
				return
			_api_mock_hint_shown = true
			_debug_note("（本地 mock · 非大模型；请检查服务是否 [LLM] 模式）")


func _try_execute_chat_intent(from_local_first: bool = false) -> void:
	if _pending_chat_intent.is_empty():
		return

	var intent := _pending_chat_intent.duplicate(true)
	if _chat_action_handled and from_local_first:
		return

	if not IntentParser.is_action_intent(intent):
		return

	var result := ActionExecutor.execute(intent)
	if bool(result.get("executed", false)):
		_chat_action_handled = true
		_skip_player_chat_reply = true
		_pending_chat_intent = {}
		var action := str(intent.get("intent", ""))
		if action in [IntentParser.INTENT_WATER, IntentParser.INTENT_WATER_ALL]:
			_pending_water_offer = false
		if action in [IntentParser.INTENT_PLANT, IntentParser.INTENT_PLANT_ALL]:
			_pending_plant_offer = false
		if action in [IntentParser.INTENT_HARVEST, IntentParser.INTENT_HARVEST_ALL]:
			_pending_harvest_offer = false
		if action == IntentParser.INTENT_OPEN_SHOP:
			_pending_shop_offer = false
		if bool(result.get("auto_seed_flow", false)):
			_begin_auto_seed_shop_flow(str(intent.get("raw_text", _pending_chat_text)))
			_pending_shop_offer = false
			_pending_plant_offer = false
		var extra := str(result.get("companion_extra", "")).strip_edges()
		if extra != "":
			_append_companion_message(extra)
		return

	# 浇/种/收等动作失败：用田况实话回复，避免再交给 LLM 编造「我去浇」。
	var failed_action := str(intent.get("intent", ""))
	var farm_actions := [
		IntentParser.INTENT_WATER,
		IntentParser.INTENT_WATER_ALL,
		IntentParser.INTENT_PLANT,
		IntentParser.INTENT_PLANT_ALL,
		IntentParser.INTENT_HARVEST,
		IntentParser.INTENT_HARVEST_ALL,
	]
	if failed_action in farm_actions:
		var fail_line := PersonaGuard.check_execution_failure(intent, result)
		if fail_line.strip_edges() != "":
			_append_companion_message(fail_line)
			_chat_action_handled = true
			_skip_player_chat_reply = true
			_pending_chat_intent = {}
			if failed_action in [IntentParser.INTENT_WATER, IntentParser.INTENT_WATER_ALL]:
				_pending_water_offer = false
			return

	if from_local_first:
		return

	_pending_chat_intent = {}
	var fail_line2 := PersonaGuard.check_execution_failure(intent, result)
	if fail_line2.strip_edges() != "":
		_append_companion_message(fail_line2)


func _try_handle_harvest_offer_reply(text: String) -> bool:
	## 玩家对「要不要我收」回「好/收吧」时，直接开收田，不再只靠 LLM 嘴上答应。
	if not _pending_harvest_offer:
		return false

	var trimmed := text.strip_edges()
	if ShopDelegate.is_negative_reply(trimmed):
		_pending_harvest_offer = false
		_append_companion_message("好，你想收的时候再叫我。")
		return true

	var direct_harvest := ShopDelegate.looks_like_harvest_commitment(trimmed)
	var intent := IntentParser.parse(trimmed)
	var intent_harvest := str(intent.get("intent", "")) in [
		IntentParser.INTENT_HARVEST,
		IntentParser.INTENT_HARVEST_ALL,
	]
	if not ShopDelegate.is_affirmative_reply(trimmed) and not direct_harvest and not intent_harvest:
		return false

	_pending_harvest_offer = false
	if not PersonaGuard.can_delegate_harvest():
		_append_companion_message(PersonaGuard.reply_when_cannot_harvest())
		_chat_action_handled = true
		return true

	if not _ensure_companion_task_ready():
		_pending_harvest_offer = true
		_append_companion_message("我还在忙上一件事，稍等一下再吩咐我。")
		return true

	var harvestable := int(GameState.get_plot_summary().get("harvestable", 0))
	if harvestable <= 0:
		_append_companion_message("还没有能收的。")
		_chat_action_handled = true
		return true

	var harvest_intent := {
		"intent": IntentParser.INTENT_HARVEST_ALL,
		"plot_id": -1,
		"raw_text": trimmed,
	}
	var harvest_result := ActionExecutor.execute(harvest_intent)
	if bool(harvest_result.get("executed", false)):
		_append_companion_message("好，我这就去收。")
		_chat_action_handled = true
		return true

	var fail_line := PersonaGuard.check_execution_failure(harvest_intent, harvest_result)
	_append_companion_message(
		fail_line if fail_line.strip_edges() != "" else PersonaGuard.reply_when_cannot_harvest()
	)
	_chat_action_handled = true
	return true


func _try_answer_planting_rebuttal(text: String) -> bool:
	if not IntentParser.looks_like_planting_rebuttal(text):
		return false
	if not PersonaGuard.can_delegate_harvest():
		_append_companion_message("是，我帮过。种是帮手，收得你来——我馋，规矩不让。")
		return true
	var harvestable := int(GameState.get_plot_summary().get("harvestable", 0))
	if harvestable <= 0:
		_append_companion_message("是，我帮过。可这会儿还没熟的呢。")
		return true
	if not _ensure_companion_task_ready():
		_append_companion_message("是，我帮过。等我忙完这一阵就去收。")
		return true
	var harvest_result := ActionExecutor.execute({
		"intent": IntentParser.INTENT_HARVEST_ALL,
		"plot_id": -1,
		"raw_text": text,
	})
	if bool(harvest_result.get("executed", false)):
		_append_companion_message("是，我帮过。那这次我来收。")
		_chat_action_handled = true
		return true
	_append_companion_message("是，我帮过。可这会儿还走不开，稍等。")
	return true


func _try_handle_seed_quantity_reply(text: String) -> bool:
	if _seed_purchase_resolved:
		return false
	if not _pending_seed_purchase and not _auto_seed_shop_flow:
		return false

	var trimmed := text.strip_edges()
	if trimmed in ["取消", "算了", "不用了", "不买了"]:
		_clear_seed_purchase_flow()
		_append_companion_message("好，先不买。")
		return true

	if ShopDelegate.looks_like_plant_now(trimmed) or _looks_like_immediate_plant_intent(trimmed):
		_clear_seed_purchase_flow()
		_append_companion_message("好，我现在就去种。")
		_begin_plant_and_water_chain()
		return true

	var count := ShopDelegate.parse_quantity(trimmed)
	if count <= 0:
		if ShopDelegate.is_quantity_reply(trimmed):
			_append_companion_message("我没听清数量，再说一次好吗？比如「3」或「三」。")
			return true
		return false

	if TaskSystem.is_busy():
		_queued_seed_count = count
		_pending_seed_purchase = true
		_append_companion_message("好，记下了，买 %d 包萝卜种子。" % count)
		return true

	_execute_companion_seed_purchase(count, true)
	return true


func _begin_auto_seed_shop_flow(source_text: String, already_committed: bool = false) -> void:
	_auto_seed_shop_flow = true
	_pending_seed_purchase = true
	_pending_seed_source_text = source_text
	_seed_purchase_resolved = false

	var preset := ShopDelegate.parse_seed_purchase_quantity(source_text)
	if preset > 0:
		if TaskSystem.is_busy():
			_queued_seed_count = preset
			if not _seed_quantity_prompted:
				_append_companion_message("好，我去商店买 %d 包萝卜种子。" % preset)
				_seed_quantity_prompted = true
		else:
			_execute_companion_seed_purchase(preset, false)
		return

	if not _seed_quantity_prompted:
		if already_committed:
			_append_companion_message("要买几包？说个数字就行。")
		else:
			_append_companion_message("好，我先去商店。要买几包萝卜种子？说个数字就行。")
		_seed_quantity_prompted = true


func _looks_like_immediate_plant_intent(text: String) -> bool:
	var intent := IntentParser.parse(text)
	return str(intent.get("intent", "")) in [IntentParser.INTENT_PLANT, IntentParser.INTENT_PLANT_ALL]


func _clear_seed_purchase_flow() -> void:
	_pending_seed_purchase = false
	_auto_seed_shop_flow = false
	_pending_seed_source_text = ""
	_queued_seed_count = -1
	_seed_quantity_prompted = false
	_seed_purchase_resolved = false


func _mark_seed_purchase_resolved() -> void:
	_seed_purchase_resolved = true
	_pending_seed_purchase = false
	_auto_seed_shop_flow = false
	_queued_seed_count = -1
	_pending_seed_source_text = ""


func _execute_companion_seed_purchase(count: int, clear_before_attempt: bool = true) -> void:
	if clear_before_attempt:
		_pending_seed_purchase = false
	var result := GameState.buy_shop_item_count("turnip_seed", count)
	if not bool(result.get("ok", false)):
		_pending_seed_purchase = true
		_auto_seed_shop_flow = true
		_append_companion_message(str(result.get("message", "买不成。")))
		return

	_mark_seed_purchase_resolved()
	_append_companion_message(str(result.get("message", "")))
	_refresh_hud()
	_append_companion_message("好，我现在就去种。")
	_begin_plant_and_water_chain()


func _begin_plant_and_water_chain() -> void:
	var plot_ids := GameState.get_plantable_plot_ids()
	if plot_ids.is_empty():
		var summary := GameState.get_plot_summary()
		if int(summary.get("empty", 0)) <= 0:
			_append_companion_message("种子买好了，田都种满了。我去看看要不要浇水。")
		else:
			_append_companion_message("种子买好了。我去看看要不要浇水。")
		_try_start_water_all_after_buy()
		return

	_farm_chain_after_task = "water_all"
	if TaskSystem.start_plant_task(plot_ids):
		return

	_farm_chain_after_task = ""
	_try_start_water_all_after_buy()


func _try_start_water_all_after_buy(from_plant_chain: bool = false) -> void:
	var unwatered := GameState.get_unwatered_growing_plot_ids()
	if unwatered.is_empty():
		return
	if TaskSystem.start_water_all_task():
		_pending_water_offer = false
		if from_plant_chain:
			_append_companion_message("我去给它们浇点水。")
		return
	if from_plant_chain:
		pass
	_offer_water_help()


func _ensure_companion_task_ready() -> bool:
	TaskSystem.reconcile_stale_task()
	return not TaskSystem.is_busy()


func _offer_water_help() -> void:
	if GameState.get_unwatered_growing_plot_ids().is_empty():
		_pending_water_offer = false
		return
	_pending_water_offer = true
	_append_companion_message("垄还干着。要浇你说一声。")


func _try_handle_water_offer_reply(text: String) -> bool:
	if not _pending_water_offer:
		return false

	var trimmed := text.strip_edges()
	if ShopDelegate.is_negative_reply(trimmed):
		_pending_water_offer = false
		_append_companion_message("好，那你需要的时候再叫我。")
		return true

	if not ShopDelegate.is_affirmative_reply(trimmed):
		return false

	if not _ensure_companion_task_ready():
		_append_companion_message("我还在忙上一件事，稍等一下再吩咐我。")
		return true

	if GameState.get_unwatered_growing_plot_ids().is_empty():
		_pending_water_offer = false
		var grounded := PersonaGuard.reply_when_cannot_water() if _field_has_no_crops() else PersonaGuard.reply_when_already_watered()
		_append_companion_message(grounded)
		_arm_pending_offers_from_companion_line(grounded)
		return true

	if TaskSystem.start_water_all_task():
		_pending_water_offer = false
		_append_companion_message("好，我这就去浇。")
		return true

	_append_companion_message("这会儿还走不开，稍等我一下。")
	return true


func _try_handle_shop_offer_reply(text: String) -> bool:
	## 玩家对「要不要我去买种子」回「可以」时，直接开代买流程，不再只靠 LLM 嘴上答应。
	if not _pending_shop_offer:
		return false

	var trimmed := text.strip_edges()
	if ShopDelegate.is_negative_reply(trimmed):
		_pending_shop_offer = false
		_append_companion_message("好，想买的时候再叫我。")
		return true

	if not ShopDelegate.is_affirmative_reply(trimmed):
		return false

	_pending_shop_offer = false
	if not _ensure_companion_task_ready():
		_begin_auto_seed_shop_flow(trimmed)
		return true

	if TaskSystem.start_shop_task(true):
		_begin_auto_seed_shop_flow(trimmed)
		return true

	_begin_auto_seed_shop_flow(trimmed)
	return true


func _try_handle_plant_offer_reply(text: String) -> bool:
	## 玩家对「要不要我帮你种上」回「可以」时，直接开种植/代买，不再只靠 LLM。
	if not _pending_plant_offer:
		return false

	var trimmed := text.strip_edges()
	if ShopDelegate.is_negative_reply(trimmed):
		_pending_plant_offer = false
		_append_companion_message("好，想种的时候再叫我。")
		return true

	if not ShopDelegate.is_affirmative_reply(trimmed):
		return false

	_pending_plant_offer = false
	if not _ensure_companion_task_ready():
		_append_companion_message("我还在忙上一件事，稍等一下再吩咐我。")
		return true

	if _start_companion_plant_task():
		_append_companion_message("好，我这就去种。")
		return true

	if int(GameState.get_item_count("turnip_seed")) <= 0 and not GameState.get_empty_plot_ids().is_empty():
		_start_companion_seed_buy_from_commitment(trimmed)
		return true

	var grounded := PersonaGuard.reply_when_cannot_plant()
	_append_companion_message(grounded)
	return true


func _field_has_no_crops() -> bool:
	var summary := GameState.get_plot_summary()
	return int(summary.get("growing", 0)) <= 0 and int(summary.get("harvestable", 0)) <= 0


func _sanitize_sleep_hijack(player_text: String, reply: String) -> String:
	## 玩家说要睡，却回浇田 → 改口，避免睡觉幻觉成浇水。
	if not IntentParser.looks_like_sleep_request(player_text):
		return reply
	var cleaned := reply.strip_edges()
	if cleaned == "":
		return "好，今天先到这儿。你也早点休息。"
	if ("浇" in cleaned or "田" in cleaned) and not ("睡" in cleaned or "休息" in cleaned or "晚安" in cleaned):
		return "好，今天先到这儿。你也早点休息。"
	return cleaned


func _sanitize_unrequested_sleep_push(player_text: String, reply: String) -> String:
	## 玩家问田况，LLM 却催睡觉 → 去掉纯睡话段落。
	if not IntentParser.looks_like_status_inquiry(player_text):
		return reply
	var cleaned := reply.strip_edges()
	if cleaned == "":
		return cleaned
	var sleep_only := true
	for marker in ["田", "苗", "萝卜", "熟", "浇", "收"]:
		if marker in cleaned:
			sleep_only = false
			break
	if sleep_only and ("睡" in cleaned or "休息" in cleaned or "晚安" in cleaned):
		return "我先帮你看看田。熟了的话我会说。"
	return cleaned


func _try_cancel_active_chore_from_chat() -> bool:
	if not TaskSystem.is_busy() and not CompanionAgent.has_current_job():
		return false
	TaskSystem.cancel_task()
	return true


func _sanitize_farm_hallucination(text: String) -> String:
	## 田况与对话不一致时，把「我去浇/种/收/已买好」等幻觉换成实话，避免先胡说再纠正。
	var cleaned := text.strip_edges()
	if cleaned == "":
		return cleaned

	## 已完成类声称：与当前田况/背包不符则改写。
	if ShopDelegate.looks_like_completed_shop_claim(cleaned):
		## 种子数为 0 时绝不可能刚买成；有种子也不要把「买好了」当真成新交易。
		if int(GameState.get_item_count("turnip_seed")) <= 0:
			return PersonaGuard.reply_when_shop_not_done()
		## 有种子却口头「买好了」：改成可跟进的邀约，避免假交易。
		if not (_pending_seed_purchase or _auto_seed_shop_flow or _seed_purchase_resolved):
			return PersonaGuard.reply_when_shop_not_done()

	if ShopDelegate.looks_like_completed_water_claim(cleaned):
		## 空田/无苗却说浇完 → 改口；仍有待浇留给 followthrough 补浇。
		if _field_has_no_crops():
			return PersonaGuard.reply_when_cannot_water()
		if GameState.get_unwatered_growing_plot_ids().is_empty():
			return PersonaGuard.reply_when_already_watered()

	if ShopDelegate.looks_like_completed_plant_claim(cleaned):
		var empty_ids := GameState.get_empty_plot_ids()
		## 有空田却没种子还说种好了 → 改口邀约买种；仍可种则留给 followthrough。
		if not empty_ids.is_empty() and int(GameState.get_item_count("turnip_seed")) <= 0:
			return PersonaGuard.reply_when_cannot_plant()

	if ShopDelegate.looks_like_completed_harvest_claim(cleaned):
		## 亲密度不够却声称代收 → 改口；仍有可收却声称收完 → 留给 followthrough 补做。
		if not PersonaGuard.can_delegate_harvest():
			return PersonaGuard.reply_when_cannot_harvest()

	## 承诺类：空田却说去浇。
	if ShopDelegate.looks_like_water_commitment(cleaned):
		var unwatered := GameState.get_unwatered_growing_plot_ids()
		if unwatered.is_empty():
			return (
				PersonaGuard.reply_when_cannot_water()
				if _field_has_no_crops()
				else PersonaGuard.reply_when_already_watered()
			)

	## 承诺去种但完全无空田：先改口，避免嘴上种、实际无动作。
	## （无种子但有空田留给 followthrough 代买，不在这里改写。）
	if ShopDelegate.looks_like_plant_commitment(cleaned):
		if GameState.get_empty_plot_ids().is_empty():
			return PersonaGuard.reply_when_cannot_plant()

	## 承诺去收但亲密度不够 / 无可收。
	if ShopDelegate.looks_like_harvest_commitment(cleaned):
		if not PersonaGuard.can_delegate_harvest():
			return PersonaGuard.reply_when_cannot_harvest()
		if int(GameState.get_plot_summary().get("harvestable", 0)) <= 0:
			return PersonaGuard.reply_when_cannot_harvest()

	return cleaned


func _should_discard_player_chat_reply() -> bool:
	if _skip_player_chat_reply:
		return true
	if _seed_purchase_resolved and str(_pending_chat_text).strip_edges() != "":
		var intent := IntentParser.parse(_pending_chat_text)
		if IntentParser.is_action_intent(intent):
			return true
	return false


func _try_start_plant_from_correction(text: String) -> bool:
	if not _looks_like_empty_field_correction(text):
		return false
	if not _ensure_companion_task_ready():
		_append_companion_message("我还在忙上一件事，稍等一下再吩咐我。")
		return true
	if _start_companion_plant_task():
		_append_companion_message("你说得对，田是空的——我这就去种萝卜。")
		return true
	if int(GameState.get_item_count("turnip_seed")) <= 0 and not GameState.get_empty_plot_ids().is_empty():
		_append_companion_message("你说得对，田是空的，背包也没有种子。我去商店买几包种上？")
		if TaskSystem.start_shop_task(true):
			_begin_auto_seed_shop_flow(text)
		return true
	_append_companion_message(PersonaGuard.reply_when_cannot_water())
	return true


func _try_execute_companion_followthrough(reply_text: String, api_intent: Dictionary) -> void:
	if _chat_action_handled or TaskSystem.is_busy():
		return

	if not api_intent.is_empty() and IntentParser.is_action_intent(api_intent):
		var guard := PersonaGuard.check_intent(api_intent)
		if not bool(guard.get("blocked", false)):
			var result := ActionExecutor.execute(api_intent)
			if bool(result.get("executed", false)):
				_chat_action_handled = true
				if bool(result.get("auto_seed_flow", false)):
					_begin_auto_seed_shop_flow(str(api_intent.get("raw_text", _pending_chat_text)))
				return
			# API 动作意图执行失败：用实话纠正
			var fail_line := PersonaGuard.check_execution_failure(api_intent, result)
			if fail_line.strip_edges() != "":
				_append_companion_message(fail_line)
				_chat_action_handled = true
				return

	# 口头「去买种子」优先于「种」：她常一句里既说买又说种，应先走代买。
	if ShopDelegate.looks_like_shop_seed_commitment(reply_text):
		_start_companion_seed_buy_from_commitment(reply_text)
		return

	if ShopDelegate.looks_like_plant_commitment(reply_text) or (
		ShopDelegate.looks_like_completed_plant_claim(reply_text)
		and not GameState.get_plantable_plot_ids().is_empty()
	):
		if _start_companion_plant_task():
			return
		# 嘴上说种、但没种子：改代买，而不是干瞪眼。
		if int(GameState.get_item_count("turnip_seed")) <= 0 and not GameState.get_empty_plot_ids().is_empty():
			_start_companion_seed_buy_from_commitment(reply_text)
			return
		_append_companion_message(PersonaGuard.reply_when_cannot_plant())
		_chat_action_handled = true
		return

	if ShopDelegate.looks_like_water_commitment(reply_text):
		var unwatered := GameState.get_unwatered_growing_plot_ids()
		if not unwatered.is_empty() and TaskSystem.start_water_all_task():
			_chat_action_handled = true
			_pending_water_offer = false
			return
		var grounded := (
			PersonaGuard.reply_when_cannot_water() if _field_has_no_crops() else PersonaGuard.reply_when_already_watered()
		)
		_append_companion_message(grounded)
		_chat_action_handled = true
		return

	## 口头「浇完了」但仍有待浇：补做浇水，而不是只改口。
	if (
		ShopDelegate.looks_like_completed_water_claim(reply_text)
		and not GameState.get_unwatered_growing_plot_ids().is_empty()
	):
		if TaskSystem.start_water_all_task():
			_chat_action_handled = true
			_pending_water_offer = false
			return

	if (
		ShopDelegate.looks_like_harvest_commitment(reply_text)
		or (
			ShopDelegate.looks_like_completed_harvest_claim(reply_text)
			and int(GameState.get_plot_summary().get("harvestable", 0)) > 0
		)
	):
		if not PersonaGuard.can_delegate_harvest():
			_append_companion_message(PersonaGuard.reply_when_cannot_harvest())
			_chat_action_handled = true
			return
		var harvest_intent := {
			"intent": IntentParser.INTENT_HARVEST_ALL,
			"plot_id": -1,
			"raw_text": reply_text,
		}
		var harvest_result := ActionExecutor.execute(harvest_intent)
		if bool(harvest_result.get("executed", false)):
			_chat_action_handled = true
			_pending_harvest_offer = false
			return
		var harvest_fail := PersonaGuard.check_execution_failure(harvest_intent, harvest_result)
		_append_companion_message(
			harvest_fail if harvest_fail.strip_edges() != "" else PersonaGuard.reply_when_cannot_harvest()
		)
		_chat_action_handled = true
		return

	if ShopDelegate.looks_like_market_commitment(reply_text):
		var market_result := ActionExecutor.execute({
			"intent": IntentParser.INTENT_OPEN_MARKET,
			"plot_id": -1,
			"raw_text": reply_text,
		})
		if bool(market_result.get("executed", false)):
			_chat_action_handled = true
		return

	if ShopDelegate.looks_like_sleep_commitment(reply_text):
		var sleep_result := ActionExecutor.execute({
			"intent": IntentParser.INTENT_SLEEP,
			"plot_id": -1,
			"raw_text": reply_text,
		})
		if bool(sleep_result.get("executed", false)):
			_chat_action_handled = true
			return
		_append_companion_message("我还在外面忙，等我回来再一起休息吧。")
		_chat_action_handled = true
		return


func _start_companion_seed_buy_from_commitment(source_text: String) -> void:
	_pending_shop_offer = false
	_pending_plant_offer = false
	_chat_action_handled = true
	if not TaskSystem.is_busy():
		TaskSystem.start_shop_task(true)
	_begin_auto_seed_shop_flow(source_text, true)


func _arm_pending_offers_from_companion_line(text: String) -> void:
	## 新邀约覆盖旧邀约，避免玩家回「好」时点到上一句的活。
	var has_shop := ShopDelegate.looks_like_shop_offer(text)
	var has_plant := (not has_shop) and ShopDelegate.looks_like_plant_offer(text)
	var has_water := ShopDelegate.looks_like_water_offer(text)
	var has_harvest := (
		not has_shop and not has_plant and not has_water
		and ShopDelegate.looks_like_harvest_offer(text)
	)
	if not (has_shop or has_plant or has_water or has_harvest):
		return
	_pending_shop_offer = has_shop
	_pending_plant_offer = has_plant
	_pending_water_offer = has_water
	_pending_harvest_offer = has_harvest


func _maybe_arm_pending_from_last_companion_line() -> void:
	## 玩家回「好/行」时，若 pending 未挂上（LLM 措辞偏口语），再扫上一句小狸台词。
	if _pending_shop_offer or _pending_plant_offer or _pending_water_offer or _pending_harvest_offer:
		return
	var last_line := _last_companion_chat_line()
	if last_line != "":
		_arm_pending_offers_from_companion_line(last_line)


func _last_companion_chat_line() -> String:
	for i in range(GameState.get_recent_chat_turns(12).size() - 1, -1, -1):
		var turn: Variant = GameState.get_recent_chat_turns(12)[i]
		if not turn is Dictionary:
			continue
		if str(turn.get("role", "")) != "companion":
			continue
		return str(turn.get("text", "")).strip_edges()
	return ""


func _recent_companion_line_texts(limit: int = 6) -> Array:
	var out: Array = []
	for turn in GameState.get_recent_chat_turns(12):
		if not turn is Dictionary:
			continue
		if str(turn.get("role", "")) != "companion":
			continue
		var line := str(turn.get("text", "")).strip_edges()
		if line != "":
			out.append(line)
	if out.size() <= limit:
		return out
	return out.slice(out.size() - limit, out.size())


func _start_companion_plant_task() -> bool:
	if TaskSystem.is_busy():
		return false
	var plot_ids := GameState.get_plantable_plot_ids()
	if plot_ids.is_empty():
		return false
	if TaskSystem.start_plant_task(plot_ids):
		_chat_action_handled = true
		_pending_plant_offer = false
		return true
	return false


func _looks_like_empty_field_correction(text: String) -> bool:
	for phrase in [
		"有空田", "明明有空", "空着的", "空田", "两块空", "没种满", "还有空",
		"没菜", "没有菜", "没种", "空空", "没有作物", "没作物", "浇什么水",
		"没什么可浇", "没有萝卜", "没萝卜", "田是空", "田里空",
	]:
		if phrase in text:
			return true
	return false


func _set_npc_busy(busy: bool) -> void:
	var was_busy := _npc_busy
	_npc_busy = busy
	_set_companion_thinking(busy)
	if busy:
		_chat_input.placeholder_text = "小狸在想…"
	else:
		_chat_input.placeholder_text = "…（轻声对小狸说）"
	if was_busy and not busy:
		var queued := _queued_busy_chat.strip_edges()
		_queued_busy_chat = ""
		if queued != "":
			call_deferred("_send_chat_async", queued)


func _set_companion_thinking(active: bool) -> void:
	for node in get_tree().get_nodes_in_group("companion_interact"):
		if node.has_method("show_status_bubble") and node.has_method("hide_status_bubble"):
			if active:
				node.show_status_bubble("…")
			else:
				node.hide_status_bubble()


func _escape_bbcode(text: String) -> String:
	return text.replace("[", "［").replace("]", "］")


func _format_player_line(line: String) -> String:
	return "[color=#8C7B68]%s[/color]" % _escape_bbcode(line)


func _format_companion_line(line: String) -> String:
	return "[color=#3D3329]%s[/color]" % _escape_bbcode(line)


func _restore_chat_history() -> void:
	_transient_companion_aside = ""
	_render_chat_log()


func _append_player_message(text: String) -> void:
	var line := text.strip_edges()
	if line == "":
		return
	_clear_companion_aside(false)
	_render_chat_log()


func _append_companion_message(text: String, ephemeral: bool = false) -> void:
	var raw := text.strip_edges()
	_maybe_sync_companion_move_from_line(raw)
	var cleaned := ResponseValidator.strip_stage_directions(raw)
	if cleaned != "" and ResponseValidator.looks_repetitive_companion_line(cleaned):
		var previous := _recent_companion_line_texts(8)
		cleaned = NpcFallback.pick_non_duplicate([
			"嗯，我在。",
			"……听着呢。",
			"有事你说。",
			"好，我在这儿。",
		], previous)
		if cleaned.strip_edges() == "":
			return
	_transient_companion_aside = ""
	if cleaned != "":
		GameState.record_chat_turn("companion", cleaned, ephemeral)
		_arm_pending_offers_from_companion_line(cleaned)
	_render_chat_log()


func _finish_typewriter_if_needed(_reveal_all: bool = false) -> void:
	if _companion_tween != null and _companion_tween.is_valid():
		_companion_tween.kill()
	_typing = false
	_continue_arrow.visible = false
	if _arrow_tween != null and _arrow_tween.is_valid():
		_arrow_tween.kill()
	_arrow_tween = null


func _scroll_chat_to_end() -> void:
	await get_tree().process_frame
	if is_instance_valid(_chat_log):
		_chat_log.scroll_to_line(_chat_log.get_line_count())


func _speak_companion_aside(text: String) -> void:
	var line := text.strip_edges()
	if line == "":
		return
	_transient_companion_aside = line
	_arm_pending_offers_from_companion_line(line)
	_render_chat_log()


func _clear_companion_aside(redraw: bool = true) -> void:
	if _transient_companion_aside == "":
		return
	_transient_companion_aside = ""
	if redraw:
		_render_chat_log()


func _render_chat_log() -> void:
	_chat_log.clear()
	var history: Array[Dictionary] = []
	if GameState.IS_TEN_DAY_EDITION:
		history = GameState.snapshot_today_chat_log()
	else:
		history = GameState.get_chat_history_for_ui()
	var first := true
	if history.is_empty() and _transient_companion_aside == "":
		_chat_log.append_text("[color=#8A6E4F]……[/color]")
		_sync_companion_sign_for_surface(false)
		_scroll_chat_to_end()
		return
	for turn in history:
		if not turn is Dictionary:
			continue
		var role := str(turn.get("role", ""))
		var line := str(turn.get("text", "")).strip_edges()
		if line == "":
			continue
		var prefix := "" if first else "\n"
		first = false
		if role == "player":
			_chat_log.append_text("%s%s" % [prefix, _format_player_line(line)])
		else:
			_chat_log.append_text("%s%s" % [prefix, _format_companion_line(line)])
	if _transient_companion_aside != "":
		var prefix := "" if first else "\n"
		_chat_log.append_text(
			"%s[color=#8C7B68]%s[/color]" % [prefix, _escape_bbcode(_transient_companion_aside)]
		)
	_sync_companion_sign_for_surface(_transient_companion_aside != "")
	_scroll_chat_to_end()


func _sync_companion_sign_for_surface(aside_active: bool) -> void:
	if aside_active:
		_companion_sign.text = str(GameState.companion_name)
		_companion_sign.horizontal_alignment = HORIZONTAL_ALIGNMENT_LEFT
		_companion_sign.visible = true
		return
	var history := GameState.snapshot_today_chat_log() if GameState.IS_TEN_DAY_EDITION else GameState.get_chat_history_for_ui()
	if history.is_empty():
		_companion_sign.text = "和她说说话"
		_companion_sign.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
		_companion_sign.visible = true
		return
	var last := history[history.size() - 1]
	if str(last.get("role", "")) == "companion":
		_companion_sign.text = str(GameState.companion_name)
		_companion_sign.horizontal_alignment = HORIZONTAL_ALIGNMENT_LEFT
	else:
		_companion_sign.text = "和她说说话"
		_companion_sign.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	_companion_sign.visible = true


func _show_nudge_bar(react_type: String) -> void:
	_pending_nudge_type = react_type.strip_edges()
	_nudge_bar.visible = true


func _hide_nudge_bar() -> void:
	_nudge_bar.visible = false
	_pending_nudge_type = ""


func _on_nudge_ok_pressed() -> void:
	_hide_nudge_bar()


func _on_nudge_later_pressed() -> void:
	var react_type := _pending_nudge_type
	GameState.dismiss_companion_nudge(react_type)
	if react_type != "":
		GameState.record_initiation("nudge_dismissed", {"react_type": react_type}, "玩家选择稍后")
	_hide_nudge_bar()
	_append_companion_message("好，你先忙。我等会儿再说。")


func _ambient_sidewrite_fallback() -> String:
	return NpcFallback.ambient_sidewrite(GameState.weather_today)


func _companion_farm_reaction(reason: String) -> void:
	var line := PersonaGuard.reply_for_plot_click(reason).strip_edges()
	if line != "":
		_speak_companion_aside(line)


func _system_hint(key: String) -> void:
	var line := StoryNodeCopy.get_system(key).strip_edges()
	if line == "":
		return
	if NARRATIVE_HINT_KEYS.has(key):
		_show_narrative_hint(line)
	else:
		_hint(line)


func _show_narrative_hint(text: String) -> void:
	var line := text.strip_edges()
	if line == "":
		return
	if _narrative_hint_tween != null and _narrative_hint_tween.is_valid():
		_narrative_hint_tween.kill()
	_companion_sign.text = line
	_companion_sign.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	_companion_sign.modulate = Color(0.55, 0.42, 0.30, 0.92)
	_companion_sign.visible = true
	_narrative_hint_tween = create_tween()
	_narrative_hint_tween.tween_interval(NARRATIVE_HINT_SEC)
	_narrative_hint_tween.tween_callback(_restore_companion_sign_after_narrative_hint)


func _restore_companion_sign_after_narrative_hint() -> void:
	_companion_sign.modulate = Color(1, 1, 1, 1)
	_sync_companion_sign_for_surface(_transient_companion_aside != "")


func _sync_player_movement_lock() -> void:
	var farm := get_tree().get_first_node_in_group("farm_world")
	if farm == null or not farm.has_method("get_player"):
		return
	var player: CharacterBody2D = farm.get_player()
	if player == null or not player.has_method("set_movement_locked"):
		return
	var should_lock: bool = (
		_story_beat_panel.visible
		or _awakening_panel.visible
		or _snuggle_blocked
		or (farm.has_method("is_snuggle_active") and bool(farm.is_snuggle_active()))
	)
	player.set_movement_locked(should_lock)


func _looks_like_identity_question(text: String) -> bool:
	for kw in ["你是谁", "我是谁", "认识我", "记得我", "不记得", "见过我", "见过你"]:
		if kw in text:
			return true
	return false


func _begin_d4_trust_telegraph() -> void:
	if not GameState.IS_TEN_DAY_EDITION or GameState.game_day != 4:
		return
	if bool(GameState.get_ending_flags().get("d4_telegraph_ack_at_wake", false)):
		return
	if _day_cycle_overlay == null or _day_cycle_overlay.is_busy():
		call_deferred("_begin_d4_trust_telegraph")
		return
	if _sleep_flow_active:
		return
	_set_gameplay_controls_enabled(false)
	await _day_cycle_overlay.show_d4_trust_telegraph_blocking()
	_set_gameplay_controls_enabled(true)


func _show_d4_amnesia_hint_once() -> void:
	if bool(GameState.get_ending_flags().get("d4_amnesia_hint_shown", false)):
		return
	GameState.set_ending_flag("d4_amnesia_hint_shown", true)
	_system_hint("d4_amnesia_hint")


func _maybe_show_d4_memory_panel_hint() -> void:
	if GameState.game_day < 4:
		return
	if bool(GameState.get_ending_flags().get("d4_memory_panel_hint_shown", false)):
		return
	GameState.set_ending_flag("d4_memory_panel_hint_shown", true)
	_system_hint("d4_memory_panel_hint")


func _maybe_show_d4_amnesia_hint(player_text: String) -> void:
	if GameState.game_day not in [4, 5]:
		return
	if not StoryDirector.is_stranger_mode():
		return
	if not _looks_like_identity_question(player_text):
		return
	_show_d4_amnesia_hint_once()


func _hint(text: String) -> void:
	## 玩家可见轻提示（toast），不进对话历史。
	_show_toast(text)


func _debug_note(text: String) -> void:
	## 仅调试：亲密度 / 路线码 / mock / 节点 ID 等。
	if not SHOW_LLM_DEBUG:
		return
	_show_toast(text)


func _append_system_message(text: String) -> void:
	## 兼容旧调用；一律走轻提示，不进对话流。
	_hint(text)


func _show_toast(text: String) -> void:
	var line := text.strip_edges()
	if line == "":
		return
	_cancel_opening_hint_sequence()
	if _toast_tween != null and _toast_tween.is_valid():
		_toast_tween.kill()
	_toast.text = line
	_toast.modulate.a = 0.0
	_toast_tween = create_tween()
	_toast_tween.tween_property(_toast, "modulate:a", 1.0, 0.2)
	_toast_tween.tween_interval(3.2)
	_toast_tween.tween_property(_toast, "modulate:a", 0.0, 0.45)


func _apply_ui_scale() -> void:
	var chat_panel := $ChatPanel as Control
	if chat_panel:
		chat_panel.offset_top = -CHAT_PANEL_HEIGHT
		chat_panel.modulate.a = 1.0
	var font := UIFontTheme.get_font()
	if font != null:
		for label in [_hud_day, _hud_stats, _hud_stage, $HUD/Margin/VBox/HintLabel, _task_title, _task_body, _task_timer, _chat_date, _player_echo, _companion_sign, _continue_arrow, _toast]:
			label.add_theme_font_override("font", font)
		_chat_log.add_theme_font_override("normal_font", font)
		_chat_input.add_theme_font_override("font", font)
		for button in [_confirm_button, _cancel_button, _skip_button, _chat_send, _nudge_ok_button, _nudge_later_button, _next_day_button, _market_button, _memory_button]:
			button.add_theme_font_override("font", font)
	_hud_day.add_theme_font_size_override("font_size", 24)
	_hud_stats.add_theme_font_size_override("font_size", 19)
	_hud_stage.add_theme_font_size_override("font_size", 19)
	$HUD/Margin/VBox/HintLabel.add_theme_font_size_override("font_size", 16)
	_task_title.add_theme_font_size_override("font_size", 28)
	_task_body.add_theme_font_size_override("font_size", 19)
	_task_timer.add_theme_font_size_override("font_size", 18)
	_chat_log.add_theme_font_size_override("normal_font_size", 19)
	_chat_log.add_theme_color_override("default_color", Color(0.24, 0.20, 0.16, 1.0))
	_chat_log.add_theme_constant_override("line_separation", 2)
	_player_echo.add_theme_font_size_override("font_size", 16)
	_player_echo.add_theme_color_override("font_color", Color(0.55, 0.48, 0.41, 0.88))
	_companion_sign.add_theme_font_size_override("font_size", 14)
	_companion_sign.add_theme_color_override("font_color", Color(0.54, 0.43, 0.31, 0.92))
	_continue_arrow.add_theme_font_size_override("font_size", 18)
	_toast.add_theme_font_size_override("font_size", TOAST_FONT_SIZE)
	_toast.add_theme_color_override("font_color", Color(0.28, 0.18, 0.10, 1.0))
	_toast.add_theme_constant_override("outline_size", TOAST_OUTLINE_SIZE)
	_chat_input.add_theme_font_size_override("font_size", 18)
	for button in [_confirm_button, _cancel_button, _skip_button, _chat_send, _nudge_ok_button, _nudge_later_button]:
		button.add_theme_font_size_override("font_size", 18)
	_chat_send.custom_minimum_size = Vector2(96, 48)
	_chat_send.add_theme_font_size_override("font_size", 18)
	_next_day_button.add_theme_font_size_override("font_size", 18)
	_market_button.add_theme_font_size_override("font_size", 18)
	_memory_button.add_theme_font_size_override("font_size", 18)


func _apply_cozy_theme() -> void:
	var panel_style := StyleBoxFlat.new()
	panel_style.bg_color = Color(0.98, 0.95, 0.88, 0.94)
	panel_style.border_color = Color(0.72, 0.58, 0.42, 0.55)
	panel_style.set_border_width_all(2)
	panel_style.set_corner_radius_all(14)
	panel_style.content_margin_left = 4
	panel_style.content_margin_top = 4
	panel_style.content_margin_right = 4
	panel_style.content_margin_bottom = 4
	panel_style.shadow_color = Color(0, 0, 0, 0.12)
	panel_style.shadow_size = 6
	panel_style.shadow_offset = Vector2(0, 3)

	var button_style := panel_style.duplicate()
	button_style.bg_color = Color(0.93, 0.78, 0.52, 1.0)
	button_style.border_color = Color(0.62, 0.48, 0.30, 1.0)

	var button_hover := button_style.duplicate()
	button_hover.bg_color = Color(0.98, 0.86, 0.62, 1.0)

	for panel in [$TaskPanel]:
		panel.add_theme_stylebox_override("panel", panel_style.duplicate())

	## 话区：无边框渐隐底，不抢画面。
	var chat_style := StyleBoxFlat.new()
	chat_style.bg_color = Color(0.98, 0.94, 0.86, 0.72)
	chat_style.border_width_top = 1
	chat_style.border_color = Color(0.72, 0.55, 0.36, 0.18)
	chat_style.set_border_width_all(0)
	chat_style.border_width_top = 1
	chat_style.content_margin_left = 12
	chat_style.content_margin_top = 10
	chat_style.content_margin_right = 12
	chat_style.content_margin_bottom = 8
	$ChatPanel.add_theme_stylebox_override("panel", chat_style)
	$ChatPanel.visible = true
	$ChatPanel.modulate = Color(1, 1, 1, 1)

	for button in [_confirm_button, _cancel_button, _skip_button, _chat_send, _next_day_button, _market_button, _memory_button, _nudge_ok_button, _nudge_later_button]:
		button.add_theme_stylebox_override("normal", button_style.duplicate())
		button.add_theme_stylebox_override("hover", button_hover.duplicate())
		button.add_theme_stylebox_override("pressed", button_hover.duplicate())

	## 输入行：白底 + 发送钮。
	var input_style := StyleBoxFlat.new()
	input_style.bg_color = Color(1.0, 0.99, 0.96, 1.0)
	input_style.border_color = Color(0.78, 0.6, 0.38, 0.85)
	input_style.set_border_width_all(2)
	input_style.set_corner_radius_all(12)
	input_style.content_margin_left = 14
	input_style.content_margin_top = 10
	input_style.content_margin_right = 14
	input_style.content_margin_bottom = 10
	var input_focus := input_style.duplicate()
	input_focus.bg_color = Color(1.0, 1.0, 0.98, 1.0)
	input_focus.border_color = Color(0.85, 0.62, 0.32, 1.0)
	input_focus.shadow_color = Color(0.85, 0.62, 0.32, 0.25)
	input_focus.shadow_size = 4
	_chat_input.add_theme_stylebox_override("normal", input_style)
	_chat_input.add_theme_stylebox_override("focus", input_focus)
	_chat_input.add_theme_color_override("font_placeholder_color", Color(0.38, 0.26, 0.16, 0.95))
	_chat_input.add_theme_color_override("font_color", Color(0.2, 0.15, 0.1, 1.0))
	_chat_input.add_theme_color_override("caret_color", Color(0.55, 0.38, 0.18, 1.0))
	_chat_input.add_theme_color_override("font_selected_color", Color(0.2, 0.15, 0.1, 1.0))
	_chat_input.add_theme_color_override("selection_color", Color(0.93, 0.78, 0.52, 0.55))
	_chat_input.add_theme_font_size_override("font_size", 18)
	_chat_input.custom_minimum_size = Vector2(0, 48)

	_companion_sign.text = "和她说说话"
	_companion_sign.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	_companion_sign.visible = true
	_companion_sign.modulate = Color(1, 1, 1, 1)
	_companion_sign.add_theme_color_override("font_color", Color(0.54, 0.43, 0.31, 0.92))
	_companion_sign.add_theme_font_size_override("font_size", 14)
	_chat_log.add_theme_constant_override("line_separation", 2)
	_player_echo.add_theme_color_override("font_color", Color(0.55, 0.48, 0.41, 0.88))
	_player_echo.add_theme_font_size_override("font_size", 16)
	_chat_input.custom_minimum_size = Vector2(0, 48)
