extends "res://tools/story_test_runner.gd"
## 亲密度档文案 diff smoke。
## godot --headless --path <项目根> res://tools/tier_diff_smoke_runner.tscn


func _ready() -> void:
	call_deferred("_run_smoke")


func _run_smoke() -> void:
	print("=== Tier diff smoke ===")
	_test_ten_day_mid_profile_copy()
	_test_ten_day_tier_copy_diff()
	_print_report()
	get_tree().quit(_failures.size())
