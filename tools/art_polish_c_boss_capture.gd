extends "res://tests/phase3_minotaur_host_capture.gd"
func _initialize() -> void:
	if not ProjectSettings.globalize_path("user://").replace("\\","/").contains("08-parallel/art-polish-c/"):
		quit(2)
		return
	if "--golem" in OS.get_cmdline_user_args():
		boss_id = "golem"
		target_floor = 10
		mechanism = "armor"
	capture_out = "res://build/verification/art-polish-c/host-"+boss_id+"/"
	evidence_out = capture_out
	suite_started = Time.get_ticks_msec()
	DirAccess.make_dir_recursive_absolute(evidence_out)
	run_folder = "user://art_polish_c_%d"%Time.get_ticks_usec()
	DirAccess.make_dir_recursive_absolute(run_folder)
	Core = load("res://scripts/core/campaign_engine.gd")
	core = Core.new(run_folder+"/probe.json")
	_suite.call_deferred()
