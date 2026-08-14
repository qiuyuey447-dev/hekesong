extends PanelContainer
class_name StoryBeatPanel
## 主线节点演出：信纸翻页 + 打字机。一页一页点进，不做上下滚动。

signal finished(beat_id: String)
signal choice_made(choice_id: String)

const TYPEWRITER_SEC_PER_CHAR := 0.036
const PAGE_FADE_SEC := 0.22
const CARD_MIN_SIZE := Vector2(720, 440)
const BODY_MIN_SIZE := Vector2(620, 200)
## 单页大约容纳的汉字量；超出会按句再切，避免再出现滚动条。
const MAX_CHARS_PER_PAGE := 90

var _dim: ColorRect
var _card: PanelContainer
var _title_label: Label
var _body_label: RichTextLabel
var _step_label: Label
var _node_label: Label
var _hint_label: Label
var _continue_button: Button
var _button_row: HBoxContainer
var _choice_bottom_spacer: Control
var _choice_buttons: Array[Button] = []
var _card_style: StyleBoxFlat
var _steps: Array[Dictionary] = []
var _step_index: int = 0
var _beat_id: String = ""
var _typing: bool = false
var _page_turning: bool = false
var _type_tween: Tween = null
var _fade_tween: Tween = null
var _page_tween: Tween = null
## 当前 step 内拆好的正文页（不含选项页）。
var _pages: PackedStringArray = []
var _page_index: int = 0
var _is_choice_step: bool = false


func _ready() -> void:
	visible = false
	mouse_filter = Control.MOUSE_FILTER_IGNORE
	_build_shell()
	_continue_button.pressed.connect(_on_continue_pressed)
	_sync_viewport_layout()
	if not get_viewport().size_changed.is_connected(_sync_viewport_layout):
		get_viewport().size_changed.connect(_sync_viewport_layout)


func open(beat: Dictionary) -> void:
	_sync_viewport_layout()
	_beat_id = str(beat.get("id", ""))
	_steps = []
	var raw: Variant = beat.get("steps", [])
	if raw is Array:
		for item in raw:
			if item is Dictionary:
				_steps.append(item)
	_step_index = 0
	# 玩家抬头用游戏日+时段，不展示路线码 / 节点 ID（如序章 · N06′）。
	_node_label.text = GameState.get_day_period_label()
	visible = true
	show()
	move_to_front()
	mouse_filter = Control.MOUSE_FILTER_STOP
	_play_open_fade()
	_show_step()


func close_panel() -> void:
	_kill_typewriter()
	_kill_page_tween()
	visible = false
	mouse_filter = Control.MOUSE_FILTER_IGNORE
	_clear_choice_buttons()
	_pages = PackedStringArray()
	_page_index = 0
	_is_choice_step = false
	_restore_header_for_story()
	modulate = Color(1, 1, 1, 1)
	if _dim:
		_dim.modulate.a = 1.0
	if _card:
		_card.modulate.a = 1.0
		_card.scale = Vector2.ONE
	if _body_label:
		_body_label.modulate.a = 1.0


func get_beat_id() -> String:
	return _beat_id


func get_step_count() -> int:
	return _steps.size()


func append_steps(new_steps: Array) -> void:
	for item in new_steps:
		if item is Dictionary:
			_steps.append(item)


func show_step_at(index: int) -> void:
	_step_index = clampi(index, 0, maxi(_steps.size() - 1, 0))
	_show_step()


func finish_now() -> void:
	_finish()


func advance_after_choice() -> void:
	if _step_index >= _steps.size() - 1:
		_finish()
		return
	_step_index += 1
	_show_step()


func _play_open_fade() -> void:
	if _fade_tween != null and _fade_tween.is_valid():
		_fade_tween.kill()
	if _dim:
		_dim.modulate.a = 0.0
	if _card:
		_card.modulate.a = 0.0
		_card.scale = Vector2(0.96, 0.96)
	_fade_tween = create_tween()
	_fade_tween.set_parallel(true)
	if _dim:
		_fade_tween.tween_property(_dim, "modulate:a", 1.0, 0.35)
	if _card:
		_fade_tween.tween_property(_card, "modulate:a", 1.0, 0.4)
		_fade_tween.tween_property(_card, "scale", Vector2.ONE, 0.4).set_trans(Tween.TRANS_CUBIC).set_ease(Tween.EASE_OUT)


func _show_step() -> void:
	if _steps.is_empty():
		_finish()
		return
	var step: Dictionary = _steps[_step_index]
	_restore_header_for_story()
	_title_label.text = str(step.get("title", ""))
	var kind := str(step.get("kind", ""))
	_is_choice_step = kind == "choice"
	_pages = _paginate_body(_prettify_body(str(step.get("body", ""))))
	_page_index = 0
	_update_page_indicator()

	_clear_choice_buttons()
	_continue_button.visible = true
	_hint_label.visible = true
	_refresh_continue_label()
	# 无正文：直接出选项。
	if _is_choice_step and (_pages.is_empty() or (_pages.size() == 1 and str(_pages[0]).strip_edges() == "")):
		_reveal_choices()
		return
	_present_page(false)


func _present_page(with_turn_anim: bool) -> void:
	if _pages.is_empty():
		_body_label.text = ""
		_body_label.visible_ratio = 1.0
		_typing = false
		_refresh_continue_label()
		return

	var page_text := str(_pages[_page_index])
	_update_page_indicator()
	_refresh_continue_label()

	if with_turn_anim:
		_page_turning = true
		_kill_typewriter()
		_kill_page_tween()
		_page_tween = create_tween()
		_page_tween.tween_property(_body_label, "modulate:a", 0.0, PAGE_FADE_SEC * 0.55)
		_page_tween.tween_callback(func() -> void:
			_start_typewriter(page_text)
			_body_label.modulate.a = 0.0
		)
		_page_tween.tween_property(_body_label, "modulate:a", 1.0, PAGE_FADE_SEC)
		_page_tween.tween_callback(func() -> void:
			_page_turning = false
		)
	else:
		_body_label.modulate.a = 1.0
		_start_typewriter(page_text)


func _update_page_indicator() -> void:
	## 进度按「整场演出」计：前面 steps 的页数 + 当前页。
	var total := _count_total_readable_pages()
	var current := _count_pages_before_step(_step_index) + _page_index + 1
	if total <= 0:
		_step_label.text = ""
		return
	_step_label.text = "%d / %d" % [current, total]


func _count_total_readable_pages() -> int:
	var total := 0
	for i in range(_steps.size()):
		total += _pages_for_step_index(i)
	return maxi(total, 1)


func _count_pages_before_step(step_i: int) -> int:
	var total := 0
	for i in range(clampi(step_i, 0, _steps.size())):
		total += _pages_for_step_index(i)
	return total


func _pages_for_step_index(i: int) -> int:
	if i < 0 or i >= _steps.size():
		return 0
	if i == _step_index and not _pages.is_empty():
		return maxi(_pages.size(), 1)
	var step: Dictionary = _steps[i]
	var pages := _paginate_body(_prettify_body(str(step.get("body", ""))))
	return maxi(pages.size(), 1)


func _refresh_continue_label() -> void:
	var kind := ""
	if _step_index >= 0 and _step_index < _steps.size():
		kind = str(_steps[_step_index].get("kind", ""))
	var has_more_pages := _page_index < _pages.size() - 1
	var has_more_steps := _step_index < _steps.size() - 1
	if has_more_pages:
		_continue_button.text = "继续"
		_hint_label.text = "轻触翻页"
	elif _is_choice_step:
		_continue_button.text = "继续"
		_hint_label.text = "轻触抉择"
	elif has_more_steps:
		_continue_button.text = "继续"
		_hint_label.text = "轻触继续"
	elif kind == "fragment":
		_continue_button.text = "收录"
		_hint_label.text = "轻触收录"
	else:
		_continue_button.text = "知道了"
		_hint_label.text = "轻触关闭"


func _prettify_body(text: String) -> String:
	## 段落之间统一空一行，避免「字墙」。
	var cleaned := text.strip_edges()
	if cleaned == "":
		return cleaned
	var paragraphs: PackedStringArray = []
	var buf: PackedStringArray = []
	for part in cleaned.split("\n"):
		var line := str(part).strip_edges()
		if line == "":
			if not buf.is_empty():
				paragraphs.append("\n".join(buf))
				buf.clear()
			continue
		buf.append(line)
	if not buf.is_empty():
		paragraphs.append("\n".join(buf))
	return "\n\n".join(paragraphs)


func _paginate_body(text: String) -> PackedStringArray:
	## 优先按段落分页；过长段落再按句切开，保证每页都能完整落在框内。
	var cleaned := text.strip_edges()
	if cleaned == "":
		return PackedStringArray([""])

	var paragraphs: PackedStringArray = []
	for part in cleaned.split("\n\n"):
		var para := str(part).strip_edges()
		if para != "":
			paragraphs.append(para)
	if paragraphs.is_empty():
		return PackedStringArray([cleaned])

	var pages: PackedStringArray = []
	for para in paragraphs:
		if para.length() <= MAX_CHARS_PER_PAGE:
			pages.append(para)
			continue
		for chunk in _split_long_paragraph(para):
			pages.append(chunk)
	if pages.is_empty():
		pages.append(cleaned)
	return pages


func _split_long_paragraph(para: String) -> PackedStringArray:
	var chunks: PackedStringArray = []
	var remaining := para
	while remaining.length() > MAX_CHARS_PER_PAGE:
		var cut := _find_soft_cut(remaining, MAX_CHARS_PER_PAGE)
		chunks.append(remaining.substr(0, cut).strip_edges())
		remaining = remaining.substr(cut).strip_edges()
	if remaining != "":
		chunks.append(remaining)
	return chunks


func _find_soft_cut(text: String, limit: int) -> int:
	var soft_limit := mini(limit, text.length())
	var punct := "。！？；…\n"
	var best := -1
	for i in range(soft_limit - 1, maxi(soft_limit - 36, 0), -1):
		if punct.find(text[i]) >= 0:
			best = i + 1
			break
	if best > 0:
		return best
	# 次选：逗号
	for i in range(soft_limit - 1, maxi(soft_limit - 24, 0), -1):
		if text[i] == "，" or text[i] == ",":
			return i + 1
	return soft_limit


func _start_typewriter(body: String) -> void:
	_kill_typewriter()
	_body_label.text = body
	if body.strip_edges() == "":
		_typing = false
		_body_label.visible_ratio = 1.0
		return
	_typing = true
	_body_label.visible_ratio = 0.0
	var dur := clampf(float(body.length()) * TYPEWRITER_SEC_PER_CHAR, 0.28, 5.5)
	_type_tween = create_tween()
	_type_tween.tween_property(_body_label, "visible_ratio", 1.0, dur)
	_type_tween.tween_callback(func() -> void:
		_typing = false
	)


func _kill_typewriter() -> void:
	if _type_tween != null and _type_tween.is_valid():
		_type_tween.kill()
	_type_tween = null
	_typing = false
	if _body_label:
		_body_label.visible_ratio = 1.0


func _kill_page_tween() -> void:
	if _page_tween != null and _page_tween.is_valid():
		_page_tween.kill()
	_page_tween = null
	_page_turning = false


func _finish_typewriter_or_advance() -> void:
	if _page_turning:
		return
	if _typing:
		_kill_typewriter()
		_body_label.visible_ratio = 1.0
		return
	_advance_page_or_step()


func _on_continue_pressed() -> void:
	_finish_typewriter_or_advance()


func _advance_page_or_step() -> void:
	if _page_index < _pages.size() - 1:
		_page_index += 1
		_present_page(true)
		if _is_choice_step and _page_index >= _pages.size() - 1:
			# 正文最后一页出完字后，点一次再亮选项更稳；此处仍先播正文。
			pass
		return

	if _is_choice_step:
		_reveal_choices()
		return

	if _step_index >= _steps.size() - 1:
		_finish()
		return
	_step_index += 1
	_show_step_with_turn()


func _reveal_choices() -> void:
	if not _is_choice_step or _step_index < 0 or _step_index >= _steps.size():
		return
	_kill_typewriter()
	_body_label.text = ""
	_body_label.visible_ratio = 1.0
	_body_label.modulate.a = 1.0
	_continue_button.visible = false
	_hint_label.visible = false
	# 抉择页：去掉日/时段抬头，标题放大；选项垂直居中。
	_node_label.visible = false
	_step_label.visible = false
	_title_label.add_theme_font_size_override("font_size", 44)
	_title_label.add_theme_color_override("font_color", Color(0.22, 0.14, 0.08, 1.0))
	_set_choice_layout(true)
	_show_choice_buttons(_steps[_step_index].get("choices", []))


func _restore_header_for_story() -> void:
	_node_label.visible = true
	_step_label.visible = true
	_title_label.add_theme_font_size_override("font_size", 34)
	_title_label.add_theme_color_override("font_color", Color(0.26, 0.18, 0.12, 1.0))
	_set_choice_layout(false)


func _set_choice_layout(active: bool) -> void:
	## 抉择时：正文区与底 spacer 对半撑开，把选项顶到卡片正中。
	if _body_label:
		if active:
			_body_label.custom_minimum_size = Vector2(BODY_MIN_SIZE.x, 0)
			_body_label.size_flags_vertical = Control.SIZE_EXPAND_FILL
			_body_label.mouse_filter = Control.MOUSE_FILTER_IGNORE
		else:
			_body_label.custom_minimum_size = BODY_MIN_SIZE
			_body_label.size_flags_vertical = Control.SIZE_EXPAND_FILL
			_body_label.mouse_filter = Control.MOUSE_FILTER_STOP
	if _choice_bottom_spacer:
		_choice_bottom_spacer.visible = active
		if active:
			_choice_bottom_spacer.size_flags_vertical = Control.SIZE_EXPAND_FILL
		else:
			_choice_bottom_spacer.size_flags_vertical = 0
		_choice_bottom_spacer.custom_minimum_size = Vector2.ZERO
	if _button_row:
		_button_row.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		_button_row.alignment = BoxContainer.ALIGNMENT_CENTER


func _show_step_with_turn() -> void:
	## 跨 step 时也做一次淡出再切入，保持翻页感。
	_page_turning = true
	_kill_typewriter()
	_kill_page_tween()
	_page_tween = create_tween()
	_page_tween.tween_property(_body_label, "modulate:a", 0.0, PAGE_FADE_SEC * 0.55)
	_page_tween.tween_callback(func() -> void:
		_page_turning = false
		_show_step()
	)


func _on_dim_gui_input(event: InputEvent) -> void:
	if not visible:
		return
	if event is InputEventMouseButton and event.pressed and event.button_index == MOUSE_BUTTON_LEFT:
		# 选项已出现时，点空白不推进，避免误触关掉抉择。
		if not _choice_buttons.is_empty():
			return
		if _continue_button.visible:
			_finish_typewriter_or_advance()
			accept_event()


func _finish() -> void:
	_kill_typewriter()
	_kill_page_tween()
	_clear_choice_buttons()
	close_panel()
	finished.emit(_beat_id)


func _show_choice_buttons(raw_choices: Variant) -> void:
	_clear_choice_buttons()
	if raw_choices is not Array:
		return
	_button_row.add_theme_constant_override("separation", 20)
	_button_row.alignment = BoxContainer.ALIGNMENT_CENTER
	for item in raw_choices:
		if not item is Dictionary:
			continue
		var choice: Dictionary = item
		var button := Button.new()
		button.text = str(choice.get("label", "选择"))
		button.custom_minimum_size = Vector2(260, 64)
		button.size_flags_horizontal = Control.SIZE_SHRINK_CENTER
		button.focus_mode = Control.FOCUS_NONE
		button.mouse_default_cursor_shape = Control.CURSOR_POINTING_HAND
		button.add_theme_font_size_override("font_size", 24)
		_apply_choice_button_style(button)
		var font := UIFontTheme.get_font() if UIFontTheme else null
		if font:
			button.add_theme_font_override("font", font)
		var choice_id := str(choice.get("id", ""))
		button.pressed.connect(func() -> void:
			choice_made.emit(choice_id)
		)
		button.mouse_entered.connect(_on_choice_hover.bind(button, true))
		button.mouse_exited.connect(_on_choice_hover.bind(button, false))
		_button_row.add_child(button)
		_choice_buttons.append(button)
	call_deferred("_center_choice_pivots")


func _center_choice_pivots() -> void:
	for button in _choice_buttons:
		if not is_instance_valid(button):
			continue
		button.pivot_offset = button.size * 0.5
		button.scale = Vector2.ONE


func _on_choice_hover(button: Button, hovering: bool) -> void:
	if not is_instance_valid(button):
		return
	if button.pivot_offset == Vector2.ZERO and button.size != Vector2.ZERO:
		button.pivot_offset = button.size * 0.5
	var target := Vector2(1.06, 1.06) if hovering else Vector2.ONE
	var tw := button.create_tween()
	tw.tween_property(button, "scale", target, 0.12).set_trans(Tween.TRANS_CUBIC).set_ease(Tween.EASE_OUT)


func _clear_choice_buttons() -> void:
	for button in _choice_buttons:
		if is_instance_valid(button):
			button.queue_free()
	_choice_buttons.clear()
	_button_row.add_theme_constant_override("separation", 14)


func _build_shell() -> void:
	add_theme_stylebox_override("panel", StyleBoxEmpty.new())

	_dim = ColorRect.new()
	_dim.name = "Dim"
	_dim.set_anchors_preset(Control.PRESET_FULL_RECT)
	_dim.set_offsets_preset(Control.PRESET_FULL_RECT)
	_dim.color = Color(0.06, 0.05, 0.08, 0.42)
	_dim.mouse_filter = Control.MOUSE_FILTER_STOP
	_dim.gui_input.connect(_on_dim_gui_input)
	add_child(_dim)

	var center := CenterContainer.new()
	center.name = "Center"
	center.set_anchors_preset(Control.PRESET_FULL_RECT)
	center.set_offsets_preset(Control.PRESET_FULL_RECT)
	center.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(center)

	_card = PanelContainer.new()
	_card.name = "Card"
	_card.mouse_filter = Control.MOUSE_FILTER_STOP
	_card.custom_minimum_size = CARD_MIN_SIZE
	_card.pivot_offset = CARD_MIN_SIZE * 0.5
	_card_style = _card_stylebox()
	_card.add_theme_stylebox_override("panel", _card_style)
	_card.gui_input.connect(_on_dim_gui_input)
	center.add_child(_card)

	var margin := MarginContainer.new()
	margin.add_theme_constant_override("margin_left", 8)
	margin.add_theme_constant_override("margin_top", 8)
	margin.add_theme_constant_override("margin_right", 8)
	margin.add_theme_constant_override("margin_bottom", 8)
	_card.add_child(margin)

	var vbox := VBoxContainer.new()
	vbox.add_theme_constant_override("separation", 14)
	margin.add_child(vbox)

	_node_label = Label.new()
	_node_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	_node_label.add_theme_font_size_override("font_size", 15)
	_node_label.add_theme_color_override("font_color", Color(0.55, 0.42, 0.28, 0.85))
	vbox.add_child(_node_label)

	_title_label = Label.new()
	_title_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	_title_label.add_theme_font_size_override("font_size", 34)
	_title_label.add_theme_color_override("font_color", Color(0.26, 0.18, 0.12, 1.0))
	vbox.add_child(_title_label)

	_step_label = Label.new()
	_step_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	_step_label.add_theme_font_size_override("font_size", 16)
	_step_label.add_theme_color_override("font_color", Color(0.42, 0.32, 0.22, 0.92))
	vbox.add_child(_step_label)

	_body_label = RichTextLabel.new()
	_body_label.custom_minimum_size = BODY_MIN_SIZE
	_body_label.size_flags_vertical = Control.SIZE_EXPAND_FILL
	_body_label.fit_content = false
	_body_label.scroll_active = false
	_body_label.scroll_following = false
	_body_label.bbcode_enabled = false
	_body_label.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	_body_label.add_theme_font_size_override("normal_font_size", 22)
	_body_label.add_theme_constant_override("line_separation", 14)
	_body_label.add_theme_color_override("default_color", Color(0.22, 0.16, 0.12, 1.0))
	_body_label.gui_input.connect(_on_dim_gui_input)
	_body_label.mouse_filter = Control.MOUSE_FILTER_STOP
	vbox.add_child(_body_label)

	_hint_label = Label.new()
	_hint_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	_hint_label.add_theme_font_size_override("font_size", 22)
	_hint_label.add_theme_color_override("font_color", Color(0.32, 0.20, 0.10, 1.0))
	_hint_label.text = "轻触继续"
	vbox.add_child(_hint_label)

	_button_row = HBoxContainer.new()
	_button_row.alignment = BoxContainer.ALIGNMENT_CENTER
	_button_row.add_theme_constant_override("separation", 14)
	vbox.add_child(_button_row)

	_continue_button = Button.new()
	_continue_button.text = "继续"
	_continue_button.custom_minimum_size = Vector2(160, 52)
	_continue_button.add_theme_font_size_override("font_size", 20)
	_apply_button_style(_continue_button)
	_button_row.add_child(_continue_button)

	_choice_bottom_spacer = Control.new()
	_choice_bottom_spacer.name = "ChoiceBottomSpacer"
	_choice_bottom_spacer.visible = false
	_choice_bottom_spacer.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_choice_bottom_spacer.size_flags_vertical = 0
	vbox.add_child(_choice_bottom_spacer)

	_apply_fonts()


func _apply_fonts() -> void:
	var font := UIFontTheme.get_font() if UIFontTheme else null
	if font == null:
		return
	for label in [_node_label, _title_label, _step_label, _hint_label, _continue_button]:
		if label is Label or label is Button:
			label.add_theme_font_override("font", font)
	_body_label.add_theme_font_override("normal_font", font)


func _card_stylebox() -> StyleBoxFlat:
	var style := StyleBoxFlat.new()
	style.bg_color = Color(1.0, 0.97, 0.91, 0.97)
	style.border_color = Color(0.72, 0.55, 0.36, 0.7)
	style.set_border_width_all(2)
	style.border_width_top = 3
	style.set_corner_radius_all(20)
	style.content_margin_left = 36
	style.content_margin_top = 28
	style.content_margin_right = 36
	style.content_margin_bottom = 24
	style.shadow_color = Color(0.08, 0.05, 0.02, 0.3)
	style.shadow_size = 18
	style.shadow_offset = Vector2(0, 6)
	return style


func _apply_button_style(button: Button) -> void:
	var normal := StyleBoxFlat.new()
	normal.bg_color = Color(0.93, 0.78, 0.52, 0.98)
	normal.border_color = Color(0.62, 0.48, 0.30, 0.7)
	normal.set_border_width_all(2)
	normal.set_corner_radius_all(14)
	normal.content_margin_left = 18
	normal.content_margin_top = 10
	normal.content_margin_right = 18
	normal.content_margin_bottom = 10
	var hover := normal.duplicate()
	hover.bg_color = Color(0.98, 0.86, 0.62, 1.0)
	button.add_theme_stylebox_override("normal", normal)
	button.add_theme_stylebox_override("hover", hover)
	button.add_theme_stylebox_override("pressed", hover)


func _apply_choice_button_style(button: Button) -> void:
	var ink := Color(0.28, 0.18, 0.10, 1.0)
	var normal := StyleBoxFlat.new()
	normal.bg_color = Color(0.98, 0.90, 0.72, 1.0)
	normal.border_color = Color(0.62, 0.42, 0.22, 0.9)
	normal.set_border_width_all(2)
	normal.set_corner_radius_all(14)
	normal.content_margin_left = 22
	normal.content_margin_top = 14
	normal.content_margin_right = 22
	normal.content_margin_bottom = 14
	var hover := normal.duplicate()
	hover.bg_color = Color(1.0, 0.94, 0.78, 1.0)
	hover.border_color = Color(0.55, 0.36, 0.16, 1.0)
	hover.shadow_color = Color(0.55, 0.35, 0.12, 0.28)
	hover.shadow_size = 8
	hover.shadow_offset = Vector2(0, 3)
	var pressed := hover.duplicate()
	pressed.bg_color = Color(0.94, 0.84, 0.62, 1.0)
	button.add_theme_stylebox_override("normal", normal)
	button.add_theme_stylebox_override("hover", hover)
	button.add_theme_stylebox_override("pressed", pressed)
	button.add_theme_stylebox_override("focus", hover)
	button.add_theme_color_override("font_color", ink)
	button.add_theme_color_override("font_hover_color", ink)
	button.add_theme_color_override("font_pressed_color", Color(0.2, 0.12, 0.06, 1.0))
	button.add_theme_color_override("font_focus_color", ink)
	button.add_theme_color_override("font_disabled_color", Color(0.45, 0.38, 0.3, 0.7))


func _sync_viewport_layout() -> void:
	set_anchors_preset(Control.PRESET_FULL_RECT)
	set_offsets_preset(Control.PRESET_FULL_RECT)
	var center := get_node_or_null("Center") as CenterContainer
	if center:
		center.set_anchors_preset(Control.PRESET_FULL_RECT)
		center.set_offsets_preset(Control.PRESET_FULL_RECT)
	if _dim:
		_dim.set_anchors_preset(Control.PRESET_FULL_RECT)
		_dim.set_offsets_preset(Control.PRESET_FULL_RECT)
	if _card:
		_card.pivot_offset = _card.custom_minimum_size * 0.5
