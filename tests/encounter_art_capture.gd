extends SceneTree
## Render production GridBoard with a generated legacy floor (both ordinary
## event and rest), plus a close view. Does not touch the player's saves.
const Board = preload("res://scripts/ui/grid_board.gd")
const Generator = preload("res://scripts/core/campaign_generator.gd")
const Content = preload("res://scripts/core/content_db.gd")
const OUT := "res://build/verification/encounter-art/"
var board

func _initialize() -> void: _run.call_deferred()

func _frames() -> void:
	for i in 6: await process_frame

func _capture(label: String) -> Image:
	await RenderingServer.frame_post_draw
	var shot := root.get_texture().get_image()
	assert(shot.save_png(OUT + label + ".png") == OK)
	return shot

func _run() -> void:
	DirAccess.make_dir_recursive_absolute(OUT)
	var generator := Generator.new()
	var floor_map := generator.generate(generator.plan("42"), 9, "battle")
	assert(not floor_map.is_empty())
	var before := floor_map.duplicate(true)
	var db := Content.new()
	board = Board.new()
	root.add_child(board)
	board.reduce_motion = true
	board.setup(floor_map, Vector2i(floor_map.entry[0], floor_map.entry[1]), Vector2i(-1,-1), true, db.data.enemies)
	root.min_size = Vector2i(320, 640)
	root.content_scale_mode = Window.CONTENT_SCALE_MODE_DISABLED
	root.content_scale_size = Vector2i.ZERO
	for width in [320, 390, 540]:
		root.size = Vector2i(width, 740)
		board.size = Vector2(width, 740)
		board.exploration = false
		await _frames()
		await _capture("floor9_overview_%d" % width)
		board.exploration = true
		board.following = false
		board.camera_center = Vector2(floor_map.safe_slots.rest[0], floor_map.safe_slots.rest[1]) + Vector2(.5, 1.5)
		board.camera_target = board.camera_center
		board.queue_redraw()
		await _frames()
		await _capture("floor9_near_%d" % width)
	# Exercise the isolated board animation: stable accessibility setting,
	# visible live motion, and no mutation of the authoritative map snapshot.
	var frozen := await _capture("frozen_a")
	await create_timer(.4).timeout
	var still := await _capture("frozen_b")
	assert(frozen.get_data() == still.get_data(), "Reduced motion freezes every pixel")
	board.reduce_motion = false
	await create_timer(.35).timeout
	var live := await _capture("motion")
	assert(live.get_data() != still.get_data(), "Ember light animates")
	assert(before == floor_map, "Rendering preserves map state")
	for kind in ["event", "rest"]:
		var texture = Board.Art.entity_texture({"type":kind})
		assert(texture != null and texture.get_size() == Vector2(256,256))
		assert(texture.get_image().detect_alpha() != Image.ALPHA_NONE)
	assert(Board.Art.entity_texture({"type":"event", "ruin_id":"r1"}) == null, "Dedicated ruins keep their art")
	print("ENCOUNTER ART PASS: 320/390/540 overview and near; alpha, 256px imports, reduced motion, animation, state preservation, ruin routing")
	quit()
