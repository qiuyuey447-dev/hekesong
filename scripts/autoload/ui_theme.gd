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
## Web 无系统字体回退；启动时预热常用字，避免首屏豆腐块。
const WEB_GLYPH_WARMUP := (
	"去狸的岛继续新游戏退出确定取消开始这将删除当前存档从第一天重新开始"
	+ "十日完整故事……（轻声对小狸说）发送知道了你是谁记性不好先睡吧"
	+ "阿松小狸田边廊下树洞浇水萝卜约定记忆本子"
)

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
	if OS.has_feature("web"):
		call_deferred("_warm_web_font_cache")


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
	# Web/导出包：ResourceLoader 可靠；FileAccess 对 res:// 常不可用。
	if ResourceLoader.exists(path):
		var imported: Resource = ResourceLoader.load(path, "", ResourceLoader.CACHE_MODE_REUSE)
		if imported is FontFile:
			return _finalize_primary_font((imported as FontFile).duplicate(true) as FontFile)

	if OS.has_feature("web"):
		return null

	if not FileAccess.file_exists(path):
		return null
	if not _looks_like_real_font_file(path):
		push_warning("UIFontTheme: 跳过损坏/过小的字体文件 %s（请重新下载）" % path)
		return null

	var abs_path := ProjectSettings.globalize_path(path)
	var dynamic := FontFile.new()
	var err := dynamic.load_dynamic_font(abs_path)
	if err != OK:
		push_warning("UIFontTheme: load_dynamic_font 失败 path=%s err=%d" % [path, err])
		return null
	return _finalize_primary_font(dynamic)


func _finalize_primary_font(base: FontFile) -> Font:
	_tune_dynamic_font(base)
	# Web 上 FontVariation + 大字号 CJK 易出豆腐块；桌面也统一用 FontFile 保一致。
	if OS.has_feature("web"):
		base.allow_system_fallback = false
		return base
	var fv := FontVariation.new()
	fv.base_font = base
	fv.variation_embolden = EMBOLDEN
	fv.spacing_glyph = GLYPH_SPACING
	fv.spacing_space = SPACE_SPACING
	return fv


func _load_fallback_font() -> Font:
	push_warning("UIFontTheme: 主字体未加载，回退 zpix（不含中文，Web 会显示方框）")
	var fb: Resource = null
	if ResourceLoader.exists(FALLBACK_FONT_PATH):
		fb = ResourceLoader.load(FALLBACK_FONT_PATH, "", ResourceLoader.CACHE_MODE_REUSE)
	if not (fb is FontFile) and not OS.has_feature("web"):
		if not FileAccess.file_exists(FALLBACK_FONT_PATH):
			return null
		var dynamic := FontFile.new()
		if dynamic.load_dynamic_font(ProjectSettings.globalize_path(FALLBACK_FONT_PATH)) != OK:
			return null
		fb = dynamic
	if not (fb is FontFile):
		return null
	var copy := (fb as FontFile).duplicate(true) as FontFile
	copy.oversampling = 1.0
	_using_fallback = true
	return copy


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
	f.generate_mipmaps = not OS.has_feature("web")
	# Web 无系统字体；桌面 CJK 靠打包字体，不依赖系统回退。
	f.allow_system_fallback = false


func _warm_web_font_cache() -> void:
	if _font == null or not OS.has_feature("web"):
		return
	var probe := Label.new()
	probe.visible = false
	probe.add_theme_font_override("font", _font)
	add_child(probe)
	for size in [18, 28, 42, 78]:
		probe.add_theme_font_size_override("font_size", size)
		probe.text = WEB_GLYPH_WARMUP
		probe.get_minimum_size()
	probe.queue_free()


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
		call_deferred("_apply_control_by_id", node.get_instance_id())


func _on_scene_changed() -> void:
	call_deferred("_apply_tree", get_tree().root)


func _apply_control_by_id(instance_id: int) -> void:
	var node := instance_from_id(instance_id)
	if not is_instance_valid(node) or not (node is Control):
		return
	apply_control(node as Control)


func _apply_control_deferred(node: Control) -> void:
	if not is_instance_valid(node):
		return
	apply_control(node)


func _apply_tree(node: Node) -> void:
	if node is Control:
		apply_control(node)
	for child in node.get_children():
		_apply_tree(child)
