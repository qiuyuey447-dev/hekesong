extends PanelContainer

signal closed

enum ViewMode { FULL, COMPANION, PLAYER }

const CARD_SIZE_FULL := Vector2(1360, 640)
const CARD_SIZE_SINGLE := Vector2(640, 520)

var _dim: ColorRect
var _card: PanelContainer
var _card_style: StyleBoxFlat
var _summary_label: Label
var _title_label: Label
var _memory_label: RichTextLabel
var _anchor_label: RichTextLabel
var _player_notebook_label: RichTextLabel
var _fragment_label: RichTextLabel
var _memory_wrap: PanelContainer
var _player_wrap: PanelContainer
var _fragment_wrap: PanelContainer
var _view_mode := ViewMode.FULL


func _ready() -> void:
	visible = false
	mouse_filter = Control.MOUSE_FILTER_IGNORE
	_build_styles()
	_build_shell()
	_sync_layout()
	if not get_viewport().size_changed.is_connected(_sync_layout):
		get_viewport().size_changed.connect(_sync_layout)
	GameState.memory_changed.connect(refresh)
	GameState.day_advanced.connect(refresh)
	refresh()
	if _memory_label != null and not _memory_label.meta_clicked.is_connected(_on_notebook_meta_clicked):
		_memory_label.meta_clicked.connect(_on_notebook_meta_clicked)


func open(mode: ViewMode = ViewMode.FULL) -> void:
	_view_mode = mode
	_apply_view_mode()
	_sync_layout()
	visible = true
	mouse_filter = Control.MOUSE_FILTER_STOP
	move_to_front()
	refresh()


func open_companion_notebook() -> void:
	open(ViewMode.COMPANION)


func open_player_notebook() -> void:
	open(ViewMode.PLAYER)


func close() -> void:
	visible = false
	mouse_filter = Control.MOUSE_FILTER_IGNORE
	closed.emit()


func refresh() -> void:
	_summary_label.text = "第 %d 天" % GameState.game_day

	_memory_label.text = ""
	var pages: Array = MemoryService.get_anchor_pages()
	var wrote := false
	if not pages.is_empty():
		var page_no := 1
		for page_raw in pages:
			if not page_raw is Dictionary:
				continue
			var page: Dictionary = page_raw
			var line := str(page.get("summary", "")).strip_edges()
			if line == "":
				continue
			var mem_id := str(page.get("id", "")).strip_edges()
			var day_n := int(page.get("game_day", 0))
			if bool(page.get("pinned", false)):
				_memory_label.append_text("[i]第 %d 页 · 留住了[/i]" % page_no)
			else:
				_memory_label.append_text("第 %d 页" % page_no)
			if day_n > 0:
				_memory_label.append_text("（第 %d 天）" % day_n)
			if mem_id != "" and not bool(page.get("pinned", false)):
				_memory_label.append_text("  [url=pin:%s]留住[/url]" % mem_id)
			_memory_label.append_text("\n%s\n\n" % line)
			page_no += 1
			wrote = true
	if not wrote:
		_memory_label.append_text("本子还空着。日子过了，字会来。")

	_fragment_label.text = ""
	for line in StoryBeatDirector.get_fragment_display_lines():
		if line.begins_with("?"):
			_fragment_label.append_text("%s\n" % line)
		else:
			_fragment_label.append_text("%s\n" % line)

	_player_notebook_label.text = ""
	var player_pages: Array = PlayerNotebookService.get_pages_for_ui()
	if player_pages.is_empty():
		_player_notebook_label.append_text("还没写下什么。")
	else:
		if (
			GameState.is_awakening_day()
			and not PlayerNotebookService.is_awakening_revealed()
			and PlayerNotebookService.has_unrevealed_questions()
		):
			_player_notebook_label.append_text(
				"[i]有些字还看不清……等今天她说完，也许会亮起来。[/i]\n\n"
			)
		var page_no := 1
		for page_raw in player_pages:
			if not page_raw is Dictionary:
				continue
			var page: Dictionary = page_raw
			var line := str(page.get("text", "")).strip_edges()
			if line == "":
				continue
			var day_n := int(page.get("game_day", 0))
			var status := str(page.get("status", "visible"))
			if status == "missing":
				_player_notebook_label.append_text("第 %d 页" % page_no)
				if day_n > 0:
					_player_notebook_label.append_text("（第 %d 天）" % day_n)
				_player_notebook_label.append_text("\n[color=#998877]%s[/color]\n\n" % line)
			elif status == "question" and not bool(page.get("revealed", false)):
				_player_notebook_label.append_text("第 %d 页" % page_no)
				if day_n > 0:
					_player_notebook_label.append_text("（第 %d 天）" % day_n)
				_player_notebook_label.append_text("\n[color=#998877]%s[/color]\n\n" % line)
			else:
				_player_notebook_label.append_text("第 %d 页" % page_no)
				if day_n > 0:
					_player_notebook_label.append_text("（第 %d 天）" % day_n)
				_player_notebook_label.append_text("\n%s\n\n" % line)
			page_no += 1


func _on_notebook_meta_clicked(meta: Variant) -> void:
	var token := str(meta).strip_edges()
	if not token.begins_with("pin:"):
		return
	var mem_id := token.substr(4).strip_edges()
	if mem_id == "":
		return
	if MemoryService.pin_anchor_by_id(mem_id):
		refresh()


func _build_styles() -> void:
	add_theme_stylebox_override("panel", StyleBoxEmpty.new())

	var panel_style := StyleBoxFlat.new()
	panel_style.bg_color = Color(0.99, 0.96, 0.9, 0.97)
	panel_style.border_color = Color(0.82, 0.68, 0.48, 0.65)
	panel_style.set_border_width_all(2)
	panel_style.set_corner_radius_all(28)
	panel_style.content_margin_left = 8
	panel_style.content_margin_top = 8
	panel_style.content_margin_right = 8
	panel_style.content_margin_bottom = 8
	panel_style.shadow_color = Color(0, 0, 0, 0.14)
	panel_style.shadow_size = 10
	panel_style.shadow_offset = Vector2(0, 4)
	_card_style = panel_style


func _build_shell() -> void:
	_dim = ColorRect.new()
	_dim.name = "Dim"
	_dim.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	_dim.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	_dim.size_flags_vertical = Control.SIZE_EXPAND_FILL
	_dim.color = Color(0.03, 0.03, 0.06, 0.45)
	_dim.mouse_filter = Control.MOUSE_FILTER_STOP
	add_child(_dim)

	var center := CenterContainer.new()
	center.name = "Center"
	center.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	center.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	center.size_flags_vertical = Control.SIZE_EXPAND_FILL
	center.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(center)

	_card = PanelContainer.new()
	_card.name = "Card"
	_card.custom_minimum_size = CARD_SIZE_FULL
	_card.add_theme_stylebox_override("panel", _card_style)
	center.add_child(_card)

	var margin := MarginContainer.new()
	margin.add_theme_constant_override("margin_left", 20)
	margin.add_theme_constant_override("margin_top", 18)
	margin.add_theme_constant_override("margin_right", 20)
	margin.add_theme_constant_override("margin_bottom", 18)
	_card.add_child(margin)

	var root := VBoxContainer.new()
	root.add_theme_constant_override("separation", 12)
	margin.add_child(root)

	var title := Label.new()
	title.text = "记忆与本子"
	title.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	title.add_theme_font_size_override("font_size", 38)
	title.add_theme_color_override("font_color", Color(0.42, 0.3, 0.18))
	root.add_child(title)
	_title_label = title

	_summary_label = Label.new()
	_summary_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	_summary_label.add_theme_font_size_override("font_size", 20)
	_summary_label.add_theme_color_override("font_color", LetterPaperKit.INK_SOFT)
	root.add_child(_summary_label)

	var columns := HBoxContainer.new()
	columns.add_theme_constant_override("separation", 12)
	root.add_child(columns)

	_memory_label = _make_rich_box("本子")
	_memory_wrap = _wrap_box("她的本子", _memory_label)
	columns.add_child(_memory_wrap)
	_player_notebook_label = _make_rich_box("我的本子")
	_player_wrap = _wrap_box("我的本子", _player_notebook_label)
	columns.add_child(_player_wrap)
	_fragment_label = _make_rich_box("记起的片段")
	_fragment_wrap = _wrap_box("记起的片段", _fragment_label)
	columns.add_child(_fragment_wrap)
	_anchor_label = _memory_label

	var close_button := Button.new()
	close_button.text = "关闭"
	close_button.custom_minimum_size = Vector2(0, 48)
	close_button.add_theme_font_size_override("font_size", 22)
	close_button.pressed.connect(close)
	root.add_child(close_button)


func _wrap_box(title: String, content: RichTextLabel) -> PanelContainer:
	var card := PanelContainer.new()
	card.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	card.size_flags_vertical = Control.SIZE_EXPAND_FILL
	var style := StyleBoxFlat.new()
	style.bg_color = Color(1.0, 0.98, 0.94, 0.96)
	style.border_color = Color(0.88, 0.76, 0.56, 0.45)
	style.set_border_width_all(1)
	style.set_corner_radius_all(20)
	style.content_margin_left = 12
	style.content_margin_top = 10
	style.content_margin_right = 12
	style.content_margin_bottom = 10
	card.add_theme_stylebox_override("panel", style)

	var box := VBoxContainer.new()
	box.add_theme_constant_override("separation", 8)
	card.add_child(box)

	var label := Label.new()
	label.text = title
	label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	label.add_theme_font_size_override("font_size", 22)
	label.add_theme_color_override("font_color", Color(0.42, 0.3, 0.18))
	box.add_child(label)
	box.add_child(content)
	return card


func _make_rich_box(_name: String) -> RichTextLabel:
	var rich := RichTextLabel.new()
	rich.custom_minimum_size = Vector2(220, 360)
	rich.bbcode_enabled = true
	rich.scroll_active = true
	rich.fit_content = false
	rich.add_theme_font_size_override("normal_font_size", 18)
	rich.add_theme_color_override("default_color", LetterPaperKit.INK)
	rich.add_theme_color_override("font_selected_color", LetterPaperKit.INK_SOFT)
	return rich


func _apply_view_mode() -> void:
	if _title_label == null:
		return
	match _view_mode:
		ViewMode.COMPANION:
			_title_label.text = "小狸的本子"
			_memory_wrap.visible = true
			_player_wrap.visible = false
			_fragment_wrap.visible = false
			_memory_label.custom_minimum_size = Vector2(560, 360)
			if _card:
				_card.custom_minimum_size = _card_size_for_mode()
		ViewMode.PLAYER:
			_title_label.text = "你的本子"
			_memory_wrap.visible = false
			_player_wrap.visible = true
			_fragment_wrap.visible = false
			_player_notebook_label.custom_minimum_size = Vector2(560, 360)
			if _card:
				_card.custom_minimum_size = _card_size_for_mode()
		_:
			_title_label.text = "记忆与本子"
			_memory_wrap.visible = true
			_player_wrap.visible = true
			_fragment_wrap.visible = true
			_memory_label.custom_minimum_size = Vector2(280, 360)
			_player_notebook_label.custom_minimum_size = Vector2(280, 360)
			_fragment_label.custom_minimum_size = Vector2(280, 360)
			if _card:
				_card.custom_minimum_size = _card_size_for_mode()


func _card_size_for_mode() -> Vector2:
	var vp := get_viewport().get_visible_rect().size
	var wanted := CARD_SIZE_SINGLE if _view_mode != ViewMode.FULL else CARD_SIZE_FULL
	return Vector2(minf(wanted.x, maxf(320.0, vp.x - 48.0)), minf(wanted.y, maxf(280.0, vp.y - 48.0)))


func _sync_layout() -> void:
	set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	size = get_viewport().get_visible_rect().size
	if _dim:
		_dim.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
		_dim.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		_dim.size_flags_vertical = Control.SIZE_EXPAND_FILL
	var center := get_node_or_null("Center") as CenterContainer
	if center:
		center.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
		center.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		center.size_flags_vertical = Control.SIZE_EXPAND_FILL
	if _card:
		_card.custom_minimum_size = _card_size_for_mode()
