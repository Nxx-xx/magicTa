extends SceneTree
const Screen = preload("res://scripts/ui/map_screen.gd")
const Core = preload("res://scripts/core/campaign_engine.gd")
const IDS := ["p3_oath_ruin", "p3_oath_forge", "p3_lantern_sanctuary"]
var out := "res://build/verification/ruins-polish/before/"
var ui
func _initialize() -> void: _run.call_deferred()
func _frames() -> void:
	for i in 12: await process_frame
func _capture(label: String) -> void:
	await RenderingServer.frame_post_draw
	assert(root.get_texture().get_image().save_png(out+label+".png") == OK)
func _run() -> void:
	assert(ProjectSettings.globalize_path("user://").replace("\\", "/").contains("ruins-polish"))
	if "--after" in OS.get_cmdline_user_args(): out = out.replace("/before/", "/after/")
	DirAccess.make_dir_recursive_absolute(out)
	root.content_scale_size = Vector2i.ZERO
	root.min_size = Vector2i(320,640)
	for dimensions in [Vector2i(320,640), Vector2i(390,844), Vector2i(540,960)]:
		root.size = dimensions
		ui = Screen.new()
		ui.game = Core.new("user://ruins_capture.json")
		ui.game.persistence_enabled = false
		root.add_child(ui)
		ui.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
		await _frames()
		ui.settings.muted = true
		ui.settings.reduce_motion = true
		ui._start_phase3("42")
		while not ui._story_event().is_empty(): ui._finish_story()
		ui._tutorial_event({"type":"skip_all"})
		var map: Dictionary = ui.game.state.floors[str(ui.game.state.floor)]
		# Controlled visual fixture in the real production screen, not progression proof.
		for y in range(3,8):
			for x in range(3,8):
				map.entities.erase("%d,%d" % [x,y])
				map.rows[y][x] = "."
		for i in 3:
			var key := "%d,5" % (4+i)
			map.entities[key] = {"id":"review_"+str(i), "type":"event", "pos":[4+i,5], "ruin_id":IDS[i], "status":"available", "selected_option":""}
		ui.game.state.position = [5,6]
		ui._render(true)
		await _frames()
		ui.board.reduce_motion = true
		ui.board.following = false
		ui.board.camera_center = Vector2(5.5,5.5)
		ui.board.camera_target = ui.board.camera_center
		ui.board.queue_redraw()
		await _frames()
		assert(root.get_texture().get_size() == Vector2(dimensions))
		await _capture("available_%d" % dimensions.x)
		var state_before: Dictionary = ui.game.state.duplicate(true)
		await _frames()
		assert(state_before == ui.game.state)
		for entity in map.entities.values():
			if entity.has("ruin_id"): entity.status = "resolved"
		ui._render(true)
		await _frames()
		await _capture("spent_%d" % dimensions.x)
		if "--after" in OS.get_cmdline_user_args():
			for i in 3:
				map.entities["%d,5" % (4+i)].status = "available"
			ui._render(true)
			await _frames()
			ui.board.reduce_motion = false
			for i in 3:
				var entity: Dictionary = map.entities["%d,5" % (4+i)]
				entity.status = "resolved"
				entity.selected_option = ["guard", "temper", "restore"][i]
			ui._render(true)
			ui.board.reduce_motion = false
			ui.board.set_process(false)
			for replay in ui.board.ruin_art.playing.values(): replay.start = ui.board.idle_seconds - .25
			assert(ui.board.ruin_art.playing.size() == 3)
			ui.board.queue_redraw()
			await _frames()
			await _capture("triggered_%d" % dimensions.x)
		ui.queue_free()
		await _frames()
	print("RUINS_POLISH_CAPTURE actual viewport 320x640 / 390x844 / 540x960, production map fixture, rendering state preserved")
	quit()
