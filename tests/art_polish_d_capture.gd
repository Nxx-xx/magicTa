extends SceneTree
## Production screens with an isolated seed-42 visual fixture, not a playthrough.
const Screen = preload("res://scripts/ui/map_screen.gd")
const Core = preload("res://scripts/core/campaign_engine.gd")
var out := "res://build/verification/art-polish-d/before/"
var ui
var checks := 0

func _initialize() -> void: _run.call_deferred()
func frames() -> void:
	for i in 12: await process_frame
func shot(label: String) -> void:
	await RenderingServer.frame_post_draw
	assert(root.get_texture().get_image().save_png(out + label + ".png") == OK)
	checks += 1

func _run() -> void:
	assert(ProjectSettings.globalize_path("user://").replace("\\", "/").contains("art-polish-d/"))
	if "--after" in OS.get_cmdline_user_args(): out = out.replace("before/", "after/")
	DirAccess.make_dir_recursive_absolute(out)
	root.min_size = Vector2i(320,640)
	for dimensions in [Vector2i(320,640),Vector2i(390,700),Vector2i(540,960)]:
		root.size = dimensions
		ui = Screen.new()
		ui.game = Core.new("user://d_%d.json" % Time.get_ticks_usec())
		ui.game.persistence_enabled = false
		root.add_child(ui)
		ui.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
		await frames()
		ui.settings.muted = true
		ui.settings.reduce_motion = true
		assert(ui.scroll.get_v_scroll_bar().max_value <= ui.scroll.size.y + 1)
		await shot("menu_%d" % dimensions.x)
		ui._show_camp()
		await frames()
		await shot("camp_%d" % dimensions.x)
		ui._start_phase3("42")
		await frames()
		await shot("story_%d" % dimensions.x)
		ui.story_line = 2
		ui._refresh_map(true)
		await frames()
		await shot("story_portrait_%d" % dimensions.x)
		assert(ui.story_stage.portrait.get_global_rect().position.y > 100)
		for line_index in ui._story_event().get("lines", []).size():
			ui.story_line = line_index
			ui._refresh_map(true)
			await frames()
			assert(ui.scroll.get_v_scroll_bar().max_value <= ui.scroll.size.y + 1, "Authored intro dialogue fits")
			assert(ui.overlay_next.get_global_rect().end.y <= ui.size.y + 1)
			if line_index in [7,13]: await shot("story_line%d_%d" % [line_index, dimensions.x])
		while not ui._story_event().is_empty(): ui._finish_story()
		ui._tutorial_event({"type":"skip_all"})
		await frames()
		ui.board.set_overview(true)
		await frames()
		await shot("hud_%d" % dimensions.x)
		assert(ui.controls.get_global_rect().end.y <= ui.size.y + 1)
		var snapshot: Dictionary = ui.game.state.duplicate(true)
		ui._open_overlay("inventory")
		await frames()
		await shot("inventory_%d" % dimensions.x)
		ui._close_overlay()
		ui._open_overlay("settings")
		await frames()
		await shot("settings_%d" % dimensions.x)
		ui._close_overlay()
		assert(snapshot == ui.game.state)
		ui.settings.reduce_motion = false
		ui._refresh_map()
		await frames()
		await shot("hud_motion_%d" % dimensions.x)
		var cell: Vector2i = ui.game.position()
		ui.game.floor_data().entities[Core.cell_key(cell)] = {"id":"d-shop", "type":"shop", "name":"烛火商人", "pos":[cell.x,cell.y], "offers":["buy_steel","buy_plate","buy_potion"]}
		ui.game.state.player.gold = 207
		ui.game.state.pending = {"kind":"entity", "pos":[cell.x,cell.y]}
		ui._render(true)
		await frames()
		await shot("shop_%d" % dimensions.x)
		var choices = ui.find_child("RewardChoices",true,false)
		choices.option_button("0").pressed.emit()
		await frames()
		await shot("shop_detail_%d" % dimensions.x)
		assert(not ui.scroll.get_v_scroll_bar().visible)
		ui._confirm("确认替换旅程？", "当前旅程将结束，新旅程会从营地出发。取消后保留当前进度。\n" + "1234567890".repeat(8), func(): pass)
		await frames()
		await shot("confirmation_%d" % dimensions.x)
		ui.queue_free()
		await frames()
	print("ART POLISH D: %d production captures; menu fit, controls and read-only overlays passed" % checks)
	quit()
