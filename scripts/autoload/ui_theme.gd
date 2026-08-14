extends Node
## 全局中文字体：Web 上 RichTextLabel 不会可靠继承 default_font，需逐个控件绑定字体。
## 主字体优先「圆润 / 可爱 / 偏粗」中文字体（默认站酷快乐体），缺失或损坏时回退 zpix。
##
## 想更换主字体：把合法 .ttf/.otf 放进 assets/fonts/，路径加入 PRIMARY_FONT_CANDIDATES。

const PRIMARY_FONT_CANDIDATES := [
	"res://assets/fonts/ZCOOLKuaiLe-Regular.ttf",
	"res://assets/fonts/SmileySans-Oblique.ttf",
]
const FALLBACK_FONT_PATH := "res://assets/fonts/zpix.ttf"
const MIN_PRIMARY_FONT_BYTES := 100_000 # 真·中文字体通常数 MB；过小多半是 HTML 错误页

const DEFAULT_FONT_SIZE := 16
const LINE_SPACING := 6
const RICH_LINE_SEPARATION := 6
const EMBOLDEN := 0.04
const GLYPH_SPACING := 1
const SPACE_SPACING := 1

var _font: Font
var _using_fallback := true


func _ready() -> void:
	_font = _build_font()
	if _font == null:
		push_warning("UIFontTheme: 未能加载任何字体（主字体与 zpix 均缺失）")
		return
	if _using_fallback:
		push_warning(
			"UIFontTheme: 主字体不可用，已回退 zpix。请运行 tools/download_ui_font.ps1 下载合法字体到 %s"
			% PRIMARY_FONT_CANDIDATES[0]
		)
	_apply_root_theme()
	var tree := get_tree()
	if not tree.node_added.is_connected(_on_node_added):
		tree.node_added.connect(_on_node_added)
	if not tree.scene_changed.is_connected(_on_scene_changed):
		tree.scene_changed.connect(_on_scene_changed)
	call_deferred("_apply_tree", tree.root)


func get_font() -> Font:
	return _font


func is_using_fallback() -> bool:
	return _using_fallback


func apply_control(node: Control) -> void:
	if _font == null or node == null:
		return
	if node is RichTextLabel:
		node.add_theme_font_override("normal_font", _font)
	elif node is Label or node is Button or node is LineEdit:
		node.add_theme_font_override("font", _font)


func _build_font() -> Font:
	for path in PRIMARY_FONT_CANDIDATES:
		var primary := _try_load_primary_font(path)
		if primary != null:
			_using_fallback = false
			return primary
	return _load_fallback_font()


func _try_load_primary_font(path: String) -> Font:
	if not FileAccess.file_exists(path):
		return null
	if not _looks_like_real_font_file(path):
		push_warning("UIFontTheme: 跳过损坏/过小的字体文件 %s（请重新下载）" % path)
		return null

	# 1) 已导入的资源优先
	if ResourceLoader.exists(path):
		var imported: Resource = ResourceLoader.load(path, "", ResourceLoader.CACHE_MODE_REUSE)
		if imported is FontFile:
			return _wrap_primary_font(imported as FontFile)

	# 2) 未导入时用动态加载，避免 "No loader found" 红错
	var abs_path := ProjectSettings.globalize_path(path)
	var dynamic := FontFile.new()
	var err := dynamic.load_dynamic_font(abs_path)
	if err != OK:
		push_warning("UIFontTheme: load_dynamic_font 失败 path=%s err=%d" % [path, err])
		return null
	return _wrap_primary_font(dynamic)


func _wrap_primary_font(base: FontFile) -> Font:
	_tune_dynamic_font(base)
	var fv := FontVariation.new()
	fv.base_font = base
	fv.variation_embolden = EMBOLDEN
	fv.spacing_glyph = GLYPH_SPACING
	fv.spacing_space = SPACE_SPACING
	return fv


func _load_fallback_font() -> Font:
	if not FileAccess.file_exists(FALLBACK_FONT_PATH):
		return null
	var fb: Resource = null
	if ResourceLoader.exists(FALLBACK_FONT_PATH):
		fb = ResourceLoader.load(FALLBACK_FONT_PATH, "", ResourceLoader.CACHE_MODE_REUSE)
	if not (fb is FontFile):
		var dynamic := FontFile.new()
		if dynamic.load_dynamic_font(ProjectSettings.globalize_path(FALLBACK_FONT_PATH)) != OK:
			return null
		fb = dynamic
	(fb as FontFile).oversampling = 1.0
	_using_fallback = true
	return fb as Font


func _looks_like_real_font_file(path: String) -> bool:
	var f := FileAccess.open(path, FileAccess.READ)
	if f == null:
		return false
	var size := f.get_length()
	if size < MIN_PRIMARY_FONT_BYTES:
		f.close()
		return false
	# TTF: 00 01 00 00 · OTF: OTTO · WOFF: wOFF · WOFF2: wOF2 · TrueType collection: ttcf
	var b0 := f.get_8()
	var b1 := f.get_8()
	var b2 := f.get_8()
	var b3 := f.get_8()
	f.close()
	if b0 == 0x00 and b1 == 0x01 and b2 == 0x00 and b3 == 0x00:
		return true
	if b0 == 0x4F and b1 == 0x54 and b2 == 0x54 and b3 == 0x4F: # OTTO
		return true
	if b0 == 0x77 and b1 == 0x4F and b2 == 0x46 and b3 == 0x46: # wOFF
		return true
	if b0 == 0x77 and b1 == 0x4F and b2 == 0x46 and b3 == 0x32: # wOF2
		return true
	if b0 == 0x74 and b1 == 0x74 and b2 == 0x63 and b3 == 0x66: # ttcf
		return true
	# HTML / 文本错误页
	if b0 == 0x3C: # '<'
		return false
	return false


func _tune_dynamic_font(f: FontFile) -> void:
	f.antialiasing = TextServer.FONT_ANTIALIASING_GRAY
	f.hinting = TextServer.HINTING_LIGHT
	f.subpixel_positioning = TextServer.SUBPIXEL_POSITIONING_AUTO
	f.oversampling = 0.0
	f.generate_mipmaps = true
	f.allow_system_fallback = true


func _apply_root_theme() -> void:
	if _font == null:
		return
	var theme := Theme.new()
	theme.default_font = _font
	theme.default_font_size = DEFAULT_FONT_SIZE
	theme.set_font("font", "Button", _font)
	theme.set_font("font", "Label", _font)
	theme.set_font("font", "LineEdit", _font)
	theme.set_font("normal_font", "RichTextLabel", _font)
	theme.set_font_size("normal_font_size", "RichTextLabel", DEFAULT_FONT_SIZE)
	theme.set_constant("line_spacing", "Label", LINE_SPACING)
	theme.set_constant("line_separation", "RichTextLabel", RICH_LINE_SEPARATION)
	get_tree().root.theme = theme


func _on_node_added(node: Node) -> void:
	if node is Control:
		call_deferred("_apply_control_deferred", node)


func _on_scene_changed() -> void:
	call_deferred("_apply_tree", get_tree().root)


func _apply_control_deferred(node: Control) -> void:
	if not is_instance_valid(node):
		return
	apply_control(node)


func _apply_tree(node: Node) -> void:
	if node is Control:
		apply_control(node)
	for child in node.get_children():
		_apply_tree(child)
