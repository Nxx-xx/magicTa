extends SceneTree
## Playable production game using B candidate, isolated from real user saves.
const Preview = preload("res://tests/art_polish_b_preview_loader.gd")
const Screen = preload("res://scripts/ui/map_screen.gd")
const Core = preload("res://scripts/core/campaign_engine.gd")
func _initialize() -> void:
	Preview.enable()
	_run.call_deferred()
func _run() -> void:
	root.size = Vector2i(390,700)
	var screen := Screen.new()
	screen.game = Core.new("user://art_polish_b_playable.json")
	root.add_child(screen)
	screen.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	for i in 4: await process_frame
	screen.settings.muted = true
	screen._start_phase3("42")
	if "--smoke" in OS.get_cmdline_user_args():
		for i in 12: await process_frame
		assert(screen.game.state.floor == 1)
		print("B isolated playable production entry opened seed 42")
		quit(0)
