extends "res://tools/story_test_runner.gd"
## 仅跑 fallback / 无 API 全流程相关断言。
## godot --headless --path <项目根> res://tools/fallback_smoke_runner.tscn


func _ready() -> void:
	call_deferred("_run_smoke")


func _run_smoke() -> void:
	print("=== Fallback smoke ===")
	_test_fallback_speech_matrix()
	_test_fallback_keep_path_d1_d10()
	_test_fallback_expel_path_d1_d6()
	_test_ten_day_smoke_keep_path()
	_test_ten_day_smoke_expel_path()
	_print_report()
	get_tree().quit(_failures.size())
