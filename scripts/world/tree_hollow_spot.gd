extends Area2D

const INTERACT_RANGE := 96.0
const HOLLOW_FRAME := Vector2(76, 92)
const HOLLOW_FRAME_OFFSET := Vector2(0, -28)

var _label: Label
var _action_label: Label
var _hover: InteractHover
var _shape: CollisionShape2D


func _ready() -> void:
	add_to_group("interactable")
	add_to_group("tree_hollow_interact")
	monitoring = false
	_build_collision()
	_build_hint_visual()
	_hover = InteractHover.attach(
		self,
		HOLLOW_FRAME,
		HOLLOW_FRAME_OFFSET,
		INTERACT_RANGE,
		0.03,
		1.5,
		true
	)
	GameState.time_changed.connect(_refresh_hint)
	GameState.day_advanced.connect(_on_day_advanced_hint)
	StoryBeatDirector.story_route_changed.connect(func(_old, _new): _refresh_hint())
	set_process(true)
	call_deferred("_refresh_hint")


func _process(_delta: float) -> void:
	_refresh_hover_focus()


func _on_day_advanced_hint(_unused: Variant = null) -> void:
	_refresh_hint()


func activate() -> void:
	if not _is_player_near():
		get_tree().call_group("main_ui", "on_need_closer")
		return
	get_tree().call_group("main_ui", "on_tree_hollow_clicked")


func should_show_night_hint() -> bool:
	return StoryBeatDirector.has_pending_night_beat()


func should_show_interaction_hint() -> bool:
	return should_show_night_hint()


func can_activate_now() -> bool:
	return should_show_night_hint() and StoryBeatDirector.can_trigger_night_beat_at_hollow()


func get_interaction_style() -> InteractHighlight.Style:
	if can_activate_now():
		return InteractHighlight.Style.READY
	return InteractHighlight.Style.TOO_FAR


func get_interaction_label() -> String:
	if should_show_night_hint():
		if can_activate_now():
			return "树洞 · 夜"
		if GameState.is_night() or GameState.time_of_day == GameState.TIME_EVENING:
			return "树洞 · 夜"
		return "树洞 · 有人"
	return "树洞"


func get_action_label() -> String:
	if not should_show_night_hint():
		return ""
	if can_activate_now():
		return "按 E / 点击"
	return "傍晚再来"


func get_interact_center() -> Vector2:
	return global_position + HOLLOW_FRAME_OFFSET


func _refresh_hint(_unused: Variant = null) -> void:
	if _label == null:
		return
	var show := should_show_night_hint()
	_label.visible = show
	if show:
		_label.text = get_interaction_label()
	if _action_label != null:
		_action_label.visible = show
		_action_label.text = get_action_label()
	_refresh_hover_focus()


func _refresh_hover_focus() -> void:
	if _hover == null:
		return
	if not should_show_interaction_hint():
		_hover.set_focused(false)
		return
	var near := _is_player_near()
	if near:
		_hover.set_focused(true, get_interaction_style())
	else:
		_hover.set_focused(true, InteractHighlight.Style.TOO_FAR)


func _build_collision() -> void:
	_shape = CollisionShape2D.new()
	var circle := CircleShape2D.new()
	circle.radius = 44.0
	_shape.shape = circle
	_shape.position = HOLLOW_FRAME_OFFSET
	add_child(_shape)


func _build_hint_visual() -> void:
	_label = Label.new()
	_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	_label.add_theme_color_override("font_outline_color", Color(0.1, 0.08, 0.06))
	_label.add_theme_constant_override("outline_size", 4)
	_label.add_theme_font_size_override("font_size", 16)
	_label.add_theme_color_override("font_color", Color(1.0, 0.92, 0.62))
	_label.position = Vector2(-56, -92)
	_label.size = Vector2(112, 22)
	_label.visible = false
	add_child(_label)

	_action_label = Label.new()
	_action_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	_action_label.add_theme_color_override("font_outline_color", Color(0.08, 0.06, 0.04))
	_action_label.add_theme_constant_override("outline_size", 3)
	_action_label.add_theme_font_size_override("font_size", 13)
	_action_label.add_theme_color_override("font_color", Color(0.98, 0.86, 0.48))
	_action_label.position = Vector2(-56, -72)
	_action_label.size = Vector2(112, 18)
	_action_label.visible = false
	add_child(_action_label)
	_refresh_hint()


func _is_player_near() -> bool:
	var player := get_tree().get_first_node_in_group("player") as Node2D
	if player == null:
		return true
	return player.global_position.distance_to(get_interact_center()) <= INTERACT_RANGE
