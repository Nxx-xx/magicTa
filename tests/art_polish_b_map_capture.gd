extends SceneTree
## Actual production UI; generated-floor fixtures are visual review, not a playthrough.
const Screen = preload("res://scripts/ui/map_screen.gd")
const Core = preload("res://scripts/core/campaign_engine.gd")
var out := "res://build/verification/art-polish-b/before/map/"
var ui
var checks := 0
var layout_failures: Array = []

func _initialize() -> void: _run.call_deferred()

func _frames() -> void:
	for i in 12: await process_frame

func _capture(label: String) -> void:
	await RenderingServer.frame_post_draw
	assert(root.get_texture().get_image().save_png(out+label+".png") == OK)
	checks += 1

func _run() -> void:
	if "--after" in OS.get_cmdline_user_args(): preload("res://tests/art_polish_b_preview_loader.gd").enable()
	if not ProjectSettings.globalize_path("user://").replace("\\","/").contains("phase3/08-parallel/art-polish-b/"):
		push_error("Requires isolated tower-polish profile")
		quit(2)
		return
	if "--after" in OS.get_cmdline_user_args(): out = out.replace("/before/","/after/")
	if "--production" in OS.get_cmdline_user_args():
		assert(not "--after" in OS.get_cmdline_user_args())
		out = out.replace("/before/","/production/")
	if "--v08" in OS.get_cmdline_user_args(): out = out.replace("/art-polish-b/","/art-polish-b-v08/")
	DirAccess.make_dir_recursive_absolute(out)
	root.min_size = Vector2i(320,640)
	for dimensions in [Vector2i(320,640),Vector2i(390,700),Vector2i(540,960)]:
		root.size = dimensions
		ui = Screen.new()
		ui.game = Core.new("user://review_%d_%d.json" % [dimensions.x,Time.get_ticks_usec()])
		ui.game.persistence_enabled = false
		root.add_child(ui)
		ui.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
		await _frames()
		ui.settings.muted = true
		ui.settings.reduce_motion = true
		ui._start_phase3("42")
		while not ui._story_event().is_empty(): ui._finish_story()
		ui._tutorial_event({"type":"skip_all"})
		await _frames()
		for floor_number in [1,2,5,10]:
			if floor_number != 1:
				var theme_id := "boss" if floor_number in [5,10] else "battle"
				var floor_map: Dictionary = ui.game.campaign_generator.generate(ui.game.state.campaign_plan,floor_number,theme_id,"")
				assert(not floor_map.is_empty())
				ui.game.state.floors[str(floor_number)] = floor_map
				ui.game.state.floor = floor_number
				ui.game.state.position = floor_map.entry.duplicate()
			ui._render(true)
			await _frames()
			ui.board.reduce_motion = true
			ui.board.set_overview(true)
			await _frames()
			await _capture("floor%d_overview_%d" % [floor_number,dimensions.x])
			ui.board.set_overview(false)
			ui.board.following = false
			ui.board.camera_center = Vector2(5.5,5.5)
			ui.board.camera_target = ui.board.camera_center
			ui.board.queue_redraw()
			await _frames()
			await _capture("floor%d_near_%d" % [floor_number,dimensions.x])
			if ui.controls.get_global_rect().end.y > ui.size.y + 1:
				layout_failures.append({"width":dimensions.x,"floor":floor_number,"controls_bottom":ui.controls.get_global_rect().end.y,"viewport_bottom":ui.size.y})
			if floor_number == 1 and dimensions.x == 540:
				var snapshot: Dictionary = ui.game.state.duplicate(true)
				var frozen: Image = root.get_texture().get_image()
				await create_timer(.35).timeout
				await RenderingServer.frame_post_draw
				assert(frozen.get_data() == root.get_texture().get_image().get_data(),"Reduced motion freezes rendered board")
				ui.board.reduce_motion = false
				await create_timer(.25).timeout
				await _capture("motion_a")
				var animated: Image = root.get_texture().get_image()
				await create_timer(.3).timeout
				await _capture("motion_b")
				assert(animated.get_data() != root.get_texture().get_image().get_data(),"Motion is visible")
				assert(snapshot == ui.game.state,"Rendering does not mutate state")
				ui.board.reduce_motion = true
		ui.queue_free()
		await _frames()
	FileAccess.open(out+"results.json",FileAccess.WRITE).store_string(JSON.stringify({"captures":checks,"motion_freeze_state_preservation":true,"layout_failures":layout_failures},"\t"))
	print("Enemy map captures=%d; motion/freeze and state preservation passed; shared UI layout failures=%d" % [checks,layout_failures.size()])
	if not layout_failures.is_empty(): push_error("FAIL shared map controls exceed viewport; see map/results.json")
	quit(0 if layout_failures.is_empty() else 1)
