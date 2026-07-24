class_name FarmPlot
extends Area2D

const TURNIP_DRY_PATH := "res://Props/Crops/Sprites/crop_05.png"
const TURNIP_WET_PATH := "res://Props/Crops/Sprites/crop_06.png"
const GROWTH_FRAME_BY_STAGE := {
	1: 1,
	2: 3,
	3: 5,
}
const PLOT_FRAME_SIZE := Vector2(30, 22)
const PLOT_FRAME_OFFSET := Vector2(0, -2)

@export var plot_id: int = 1

var grid_cell: Vector2i = Vector2i.ZERO
var world_builder: Node = null

var _crop: Sprite2D
var _label: Label
var _hover: InteractHover


func _ready() -> void:
	add_to_group("interactable")
	add_to_group("farm_plot")
	GameState.stats_changed.connect(_refresh_state)

	_crop = Sprite2D.new()
	_crop.texture_filter = CanvasItem.TEXTURE_FILTER_NEAREST
	_crop.centered = false
	_crop.position = Vector2(0, -2)
	add_child(_crop)

	_label = Label.new()
	_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	_label.add_theme_font_size_override("font_size", 11)
	_label.add_theme_constant_override("outline_size", 2)
	_label.position = Vector2(-14, -26)
	_label.size = Vector2(28, 14)
	add_child(_label)

	_hover = InteractHover.attach(
		self,
		PLOT_FRAME_SIZE,
		PLOT_FRAME_OFFSET,
		48.0,
		1.0,
		0.025,
		2.0,
		true
	)
	_refresh_state()


func get_interaction_style() -> InteractHighlight.Style:
	return _highlight_style()


func set_hover_focused(focused: bool) -> void:
	if _hover == null:
		return
	if not focused or not should_show_interaction_hint():
		_hover.set_focused(false)
		return
	_hover.set_focused(true, _highlight_style())


func should_show_interaction_hint() -> bool:
	var plot := GameState.get_plot(plot_id)
	var stage := int(plot.get("stage", 0))
	if stage <= 0:
		return false
	if GameState.can_harvest(plot_id):
		return true
	return _needs_water(plot)


func activate() -> void:
	if not _is_player_near():
		get_tree().call_group("main_ui", "on_need_closer")
		return
	get_tree().call_group("main_ui", "on_plot_clicked", plot_id, global_position)


func _is_player_near() -> bool:
	var player := get_tree().get_first_node_in_group("player") as Node2D
	if player == null:
		return true
	return player.global_position.distance_to(global_position) <= 48.0


func _highlight_style() -> InteractHighlight.Style:
	var plot := GameState.get_plot(plot_id)
	var stage := int(plot.get("stage", 0))
	if stage <= 0:
		return InteractHighlight.Style.PLANT
	if GameState.can_harvest(plot_id):
		return InteractHighlight.Style.HARVEST
	if _needs_water(plot):
		return InteractHighlight.Style.WATER
	return InteractHighlight.Style.PLANT


func _needs_water(plot: Dictionary) -> bool:
	if GameState.weather_today == GameState.WEATHER_RAIN:
		return false
	return not (plot_id in GameState.watered_plots or bool(plot.get("watered", false)))


func _refresh_state() -> void:
	var plot := GameState.get_plot(plot_id)
	var stage := int(plot.get("stage", 0))
	var watered := bool(plot.get("watered", false)) or plot_id in GameState.watered_plots

	if stage <= 0:
		_crop.visible = false
		_label.text = ""
		return

	_crop.visible = true
	var tex_path := TURNIP_WET_PATH if watered else TURNIP_DRY_PATH
	var tex := load(tex_path) as Texture2D
	if tex == null:
		return

	var frame_idx := int(GROWTH_FRAME_BY_STAGE.get(stage, 1))
	_crop.texture = SpriteSheet.crop_frame(tex, frame_idx)
	var frame_h := tex.get_height()
	var cols := maxi(1, SpriteSheet.idiv(tex.get_width(), frame_h))
	var frame_w := SpriteSheet.idiv(tex.get_width(), cols)
	_crop.offset = Vector2(-frame_w * 0.5, -frame_h + 2)
	_crop.modulate = Color(1.04, 1.06, 1.0) if watered else Color.WHITE

	if stage >= GameState.MATURE_STAGE and GameState.can_harvest(plot_id):
		_label.text = "收"
		_label.add_theme_color_override("font_color", InteractHighlight.COLOR_HARVEST)
		_label.add_theme_color_override("font_outline_color", Color(0.28, 0.14, 0.04))
	elif _needs_water(plot):
		_label.text = "浇"
		_label.add_theme_color_override("font_color", InteractHighlight.COLOR_WATER)
		_label.add_theme_color_override("font_outline_color", Color(0.08, 0.16, 0.28))
	else:
		_label.text = ""

	if world_builder and world_builder.has_method("set_plot_watered"):
		world_builder.set_plot_watered(plot_id, watered)
