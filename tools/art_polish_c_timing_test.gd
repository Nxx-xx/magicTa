extends "res://tests/phase3_replay_timing_test.gd"
func _initialize() -> void:
	if not ProjectSettings.globalize_path("user://").replace("\\","/").contains("08-parallel/art-polish-c/"):
		quit(2)
		return
	_run.call_deferred()
