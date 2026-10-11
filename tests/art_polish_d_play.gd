extends SceneTree
## Isolated playable entrance using the real main menu, camp and full game UI.
func _initialize() -> void: _start.call_deferred()
func _start() -> void:
	assert(ProjectSettings.globalize_path("user://").replace("\\", "/").contains("art-polish-d/"))
	root.min_size = Vector2i(320,640)
	root.size = Vector2i(390,700)
	var ui = load("res://scripts/ui/map_screen.gd").new()
	ui.game = load("res://scripts/core/campaign_engine.gd").new("user://art_polish_d_play.json")
	root.add_child(ui)
	ui.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
