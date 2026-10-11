extends SceneTree
## Actual rendered composition and motion review; uses an isolated save profile.
const Screen = preload("res://scripts/ui/map_screen.gd")
const Core = preload("res://scripts/core/campaign_engine.gd")
const OUT := "res://build/verification/camp-polish/"
var ui

func _initialize() -> void: _run.call_deferred()

func _frames() -> void:
	for i in 8: await process_frame

func _capture(label: String) -> void:
	await RenderingServer.frame_post_draw
	assert(root.get_texture().get_image().save_png(OUT+label+".png") == OK)

func _run() -> void:
	if not ProjectSettings.globalize_path("user://").replace("\\","/").contains("verification/camp-polish/"):
		push_error("Art review requires isolated camp-polish APPDATA")
		quit(2)
		return
	DirAccess.make_dir_recursive_absolute(OUT)
	for dimensions in [Vector2i(390,700),Vector2i(540,960)]:
		root.size = dimensions
		ui = Screen.new()
		ui.page = "menu"
		ui.game = Core.new("user://review_%d.json" % dimensions.x)
		root.add_child(ui)
		ui.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
		await _frames()
		ui.settings.muted = true
		var board = ui.camp_map.board
		board.reduce_motion = true
		await _frames()
		await _capture("overview_%d" % dimensions.x)
		board.set_overview(false)
		board.following = false
		board.camera_center = Vector2(5.5,5.5)
		board.camera_target = board.camera_center
		board.queue_redraw()
		await _frames()
		await _capture("near_%d" % dimensions.x)
		if dimensions.x == 540:
			var frozen: Image = root.get_texture().get_image()
			await create_timer(.3).timeout
			await RenderingServer.frame_post_draw
			assert(frozen.get_data() == root.get_texture().get_image().get_data(),"Reduced motion must keep the camp still")
			board.reduce_motion = false
			await create_timer(.4).timeout
			await _capture("motion_a")
			var moving: Image = root.get_texture().get_image()
			await create_timer(.5).timeout
			await _capture("motion_b")
			assert(moving.get_data() != root.get_texture().get_image().get_data(),"Environment and NPC motion should render")
		ui.queue_free()
		await _frames()
	print("CAMP POLISH: overview and near captures at 390/540; reduced motion frozen; animated frames differ")
	quit()
