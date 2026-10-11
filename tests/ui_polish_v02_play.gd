extends SceneTree
## Interactive production UI; sample data and saves never touch player storage.
func _initialize() -> void: _start.call_deferred()

func _start() -> void:
	assert(ProjectSettings.globalize_path("user://").replace("\\", "/").contains("ui-polish-v02/"))
	root.min_size = Vector2i(320, 600)
	root.size = Vector2i(390, 700)
	var ui = load("res://scripts/ui/map_screen.gd").new()
	var Core = load("res://scripts/core/campaign_engine.gd")
	ui.game = Core.new("user://ui_polish_v02_play.json")
	root.add_child(ui)
	ui.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	if "--shop" not in OS.get_cmdline_user_args() and "--inventory" not in OS.get_cmdline_user_args(): return
	ui.game.persistence_enabled = false
	ui.settings.muted = true
	ui._start_phase3("42")
	while not ui._story_event().is_empty(): ui._finish_story()
	ui._tutorial_event({"type":"skip_all"})
	if "--inventory" in OS.get_cmdline_user_args():
		for id in ui.game.db.data.items:
			var item: Dictionary = ui.game.db.item(id)
			ui.game.state.player["relic_ids" if item.get("kind", "") == "relic" else "equipment_ids"].append(id)
		ui._open_overlay("inventory")
	else:
		var cell: Vector2i = ui.game.position()
		ui.game.floor_data().entities[Core.cell_key(cell)] = {"id":"ui-sample-shop", "type":"shop", "name":"烛火商人", "pos":[cell.x,cell.y], "offers":["buy_steel","buy_plate","buy_potion"]}
		ui.game.state.player.gold = 207
		ui.game.state.pending = {"kind":"entity", "pos":[cell.x,cell.y]}
		ui._render(true)
