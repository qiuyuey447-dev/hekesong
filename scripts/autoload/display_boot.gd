extends Node
## Web / 触屏：横屏 Adaptive 铺满；竖屏窄设备由 export/web_shell.html 提示旋转。

const DESIGN_SIZE := Vector2i(1920, 1080)


func _ready() -> void:
	_apply_display_profile()
	var tree := get_tree()
	if tree != null and tree.root != null:
		if not tree.root.size_changed.is_connected(_apply_display_profile):
			tree.root.size_changed.connect(_apply_display_profile)
	if OS.has_feature("web"):
		set_process_input(true)


func _notification(what: int) -> void:
	if what == NOTIFICATION_WM_SIZE_CHANGED and _use_editor_layout():
		call_deferred("_apply_display_profile")


func _apply_display_profile() -> void:
	if not _use_editor_layout():
		return
	var win := get_tree().root as Window
	if win == null:
		return
	win.content_scale_mode = Window.CONTENT_SCALE_MODE_CANVAS_ITEMS
	win.content_scale_aspect = Window.CONTENT_SCALE_ASPECT_EXPAND
	win.content_scale_size = DESIGN_SIZE


func _use_editor_layout() -> bool:
	return OS.has_feature("web") or DisplayServer.is_touchscreen_available()


func _input(event: InputEvent) -> void:
	if not OS.has_feature("web"):
		return
	if event is InputEventScreenTouch and event.pressed:
		_unlock_web_audio()
	elif event is InputEventMouseButton and event.pressed:
		_unlock_web_audio()


func _unlock_web_audio() -> void:
	AmbientAudio.ensure_unlocked()
	BgmDirector.ensure_unlocked()
