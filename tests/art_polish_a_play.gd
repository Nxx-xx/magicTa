extends SceneTree
## Playable production camp and menus, isolated from the player's real save.
const Screen = preload("res://scripts/ui/map_screen.gd")
const Core = preload("res://scripts/core/campaign_engine.gd")
func _initialize() -> void: _run.call_deferred()
func _run() -> void:
	assert(ProjectSettings.globalize_path("user://").replace("\\","/").contains("08-parallel/art-polish-a/"))
	root.size = Vector2i(390,700)
	var ui := Screen.new()
	ui.page = "menu"
	ui.game = Core.new("user://art_polish_a_play.json")
	root.add_child(ui)
	ui.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
