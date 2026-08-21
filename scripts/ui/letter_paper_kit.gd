extends RefCounted
class_name LetterPaperKit
## 剧情 / 觉醒 / 结局共用信纸视觉 token（设计稿 §6–§7）。

const PAPER := Color(0.9686, 0.9412, 0.9020, 0.985) ## #F7F0E6
const PAPER_MOODY := Color(0.93, 0.89, 0.82, 0.985)
const INK := Color(0.278, 0.220, 0.149, 1.0) ## #473826
const INK_SOFT := Color(0.549, 0.482, 0.408, 0.85) ## #8C7B68
const LINE := Color(0.722, 0.580, 0.420, 0.55) ## #B8946B
const RULE := Color(0, 0, 0, 0.031) ## #00000008
const STICKY := Color(0.980, 0.941, 0.847, 1.0) ## #FAF0D8
const DIM_SOFT := Color(0.08, 0.06, 0.04, 0.36)
const DIM_MOODY := Color(0.06, 0.05, 0.04, 0.48)

const TYPEWRITER_SEC_PER_CHAR := 0.07
const PAGE_FADE_SEC := 0.22
const MAX_CHARS_PER_PAGE := 78
const SHORT_PAGE_CHARS := 52
const CARD_RATIO := 0.62


static func paper_style(moody: bool = false) -> StyleBoxFlat:
	var style := StyleBoxFlat.new()
	style.bg_color = PAPER_MOODY if moody else PAPER
	style.border_color = Color(0.72, 0.55, 0.36, 0.55)
	style.set_border_width_all(1)
	style.border_width_top = 2
	style.set_corner_radius_all(6)
	style.corner_radius_top_left = 4
	style.corner_radius_top_right = 10
	style.corner_radius_bottom_left = 10
	style.corner_radius_bottom_right = 4
	style.content_margin_left = 40
	style.content_margin_top = 36
	style.content_margin_right = 40
	style.content_margin_bottom = 28
	style.shadow_color = Color(0.08, 0.05, 0.02, 0.28)
	style.shadow_size = 20
	style.shadow_offset = Vector2(0, 8)
	return style


static func sticky_style(accent: Color = Color(0.86, 0.70, 0.42, 1.0)) -> Dictionary:
	## 便签：暖纸底 + 加厚顶边近似胶带。
	var normal := StyleBoxFlat.new()
	normal.bg_color = STICKY
	normal.border_color = accent.darkened(0.05)
	normal.set_border_width_all(1)
	normal.border_width_top = 5
	normal.set_corner_radius_all(4)
	normal.content_margin_left = 22
	normal.content_margin_top = 12
	normal.content_margin_right = 22
	normal.content_margin_bottom = 12
	normal.shadow_color = Color(0.35, 0.22, 0.08, 0.16)
	normal.shadow_size = 4
	normal.shadow_offset = Vector2(0, 2)
	var hover := normal.duplicate()
	hover.bg_color = Color(1.0, 0.96, 0.88, 1.0)
	hover.shadow_size = 8
	hover.shadow_offset = Vector2(0, 4)
	var pressed := hover.duplicate()
	pressed.bg_color = Color(0.94, 0.88, 0.74, 1.0)
	return {"normal": normal, "hover": hover, "pressed": pressed}


static func apply_sticky_button(button: Button, accent: Color = Color(0.86, 0.70, 0.42, 1.0)) -> void:
	var styles := sticky_style(accent)
	button.add_theme_stylebox_override("normal", styles["normal"])
	button.add_theme_stylebox_override("hover", styles["hover"])
	button.add_theme_stylebox_override("pressed", styles["pressed"])
	button.add_theme_stylebox_override("focus", styles["hover"])
	button.add_theme_color_override("font_color", INK)
	button.add_theme_color_override("font_hover_color", INK)
	button.add_theme_color_override("font_pressed_color", Color(0.22, 0.14, 0.08, 1.0))
	button.focus_mode = Control.FOCUS_NONE
	button.mouse_default_cursor_shape = Control.CURSOR_POINTING_HAND


static func apply_font(node: Control) -> void:
	var font := UIFontTheme.get_font() if UIFontTheme else null
	if font == null or node == null:
		return
	if node is Label or node is Button:
		node.add_theme_font_override("font", font)
	elif node is RichTextLabel:
		node.add_theme_font_override("normal_font", font)


static func card_size_for_viewport(vp_size: Vector2, taller: bool = false) -> Vector2:
	var w := clampf(vp_size.x * CARD_RATIO, 560.0, 820.0)
	var h := 460.0 if taller else 420.0
	h = minf(h, vp_size.y * 0.78)
	return Vector2(w, h)


static func prettify_body(text: String) -> String:
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


static func paginate_body(text: String, max_chars: int = MAX_CHARS_PER_PAGE) -> PackedStringArray:
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
	var current := ""
	for para in paragraphs:
		if current == "":
			current = para
			continue
		if current.length() + 2 + para.length() <= max_chars:
			current += "\n\n" + para
			continue
		if current.length() <= 80 and para.length() <= 80 and current.length() + 2 + para.length() <= 140:
			current += "\n\n" + para
			continue
		if current.length() <= max_chars:
			pages.append(current)
		else:
			for chunk in _split_long(current, max_chars):
				pages.append(chunk)
		current = para
	if current != "":
		if current.length() <= 140:
			pages.append(current)
		else:
			for chunk in _split_long(current, max_chars):
				pages.append(chunk)
	if pages.is_empty():
		pages.append(cleaned)
	return pages


static func should_typewrite(body: String) -> bool:
	return body.strip_edges().length() > SHORT_PAGE_CHARS


static func _split_long(para: String, max_chars: int) -> PackedStringArray:
	var chunks: PackedStringArray = []
	var remaining := para
	while remaining.length() > max_chars:
		var cut := _soft_cut(remaining, max_chars)
		chunks.append(remaining.substr(0, cut).strip_edges())
		remaining = remaining.substr(cut).strip_edges()
	if remaining != "":
		chunks.append(remaining)
	return chunks


static func _soft_cut(text: String, limit: int) -> int:
	var soft_limit := mini(limit, text.length())
	var punct := "。！？；…\n"
	for i in range(soft_limit - 1, maxi(soft_limit - 36, 0), -1):
		if punct.find(text[i]) >= 0:
			return i + 1
	for i in range(soft_limit - 1, maxi(soft_limit - 24, 0), -1):
		if text[i] == "，" or text[i] == ",":
			return i + 1
	return soft_limit


static func make_ruled_overlay() -> Control:
	var overlay := LetterRuledOverlay.new()
	overlay.name = "RuledOverlay"
	return overlay
