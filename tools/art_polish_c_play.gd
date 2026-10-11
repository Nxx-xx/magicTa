extends SceneTree
## Dedicated real-game entry. Launch through art-polish-c lock for isolated saves.
const Screen = preload("res://scripts/ui/map_screen.gd")
const Core = preload("res://scripts/core/campaign_engine.gd")
func _initialize() -> void:
	if not ProjectSettings.globalize_path("user://").replace("\\","/").contains("08-parallel/art-polish-c/"):
		quit(2)
		return
	_start.call_deferred()
func _start() -> void:
	root.min_size = Vector2i(320,640)
	root.size = Vector2i(390,700)
	var ui := Screen.new()
	ui.game = Core.new("user://art_polish_c_play.json")
	root.add_child(ui)
	ui.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	ui._start_phase3("42")
