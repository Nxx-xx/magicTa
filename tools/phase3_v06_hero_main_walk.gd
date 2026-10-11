extends "res://tools/phase3_v06_hero_regression_phase3_ui_host_test_runner.gd"
const WALK_OUT := "res://build/verification/phase3/09-refinement/hero/main-walk/"
func _key(code: int,pressed: bool) -> void:
	var event := InputEventKey.new()
	event.keycode = code
	event.pressed = pressed
	Input.parse_input_event(event)
func _run() -> void:
	if not ProjectSettings.globalize_path("user://").replace("\\","/").contains("08-parallel/hero_refine/"):
		quit(2)
		return
	DirAccess.make_dir_recursive_absolute(WALK_OUT)
	root.min_size = Vector2i(320,640)
	root.size = Vector2i(540,960)
	ui = Screen.new()
	ui.game = Core.new("user://hero_v06_held_%d.json" % Time.get_ticks_usec())
	root.add_child(ui)
	ui.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	await _frames()
	ui.settings.muted = true
	ui.settings.reduce_motion = false
	ui._start_phase3("42")
	await _frames()
	while not ui._story_event().is_empty(): ui._finish_story()
	ui._close_overlay()
	await _frames()
	var origin: Vector2i = ui.game.position()
	var direction := Vector2i.ZERO
	var code := 0
	for candidate in [[Vector2i.UP,KEY_UP],[Vector2i.RIGHT,KEY_RIGHT],[Vector2i.DOWN,KEY_DOWN],[Vector2i.LEFT,KEY_LEFT]]:
		var d: Vector2i = candidate[0]
		if not ui.game.is_wall(origin+d) and not ui.game.is_wall(origin+d*2) and ui.game.entity_at(origin+d).is_empty() and ui.game.entity_at(origin+d*2).is_empty():
			direction = d
			code = candidate[1]
			break
	_check(direction != Vector2i.ZERO,"two real empty tiles from public seed42 departure")
	if direction == Vector2i.ZERO:
		quit(1)
		return
	var samples := []
	_key(code,true)
	var previous_visual: Vector2 = ui.board.hero_visual
	for i in 60:
		await process_frame
		await RenderingServer.frame_post_draw
		var pose: Dictionary = ui.board.hero_pose()
		_check(not pose.fallback,"v06 walking renders reviewed production frame")
		_check(ui.board.hero_visual.distance_to(previous_visual)<.6,"continuous interpolated step; no visual teleport")
		previous_visual = ui.board.hero_visual
		if i % 3 == 0:
			root.get_texture().get_image().save_png(WALK_OUT+"%02d.png" % i)
			samples.append({"render_frame":i,"logical":[ui.game.position().x,ui.game.position().y],"visual":[ui.board.hero_visual.x,ui.board.hero_visual.y],"action_frame":pose.frame,"moving":ui.board.moving})
		if ui.game.position().distance_to(origin)>=2:
			_key(code,false)
			break
	_key(code,false)
	_check(ui.game.position().distance_to(origin)>=2,"held input continues two legal tiles without second press")
	# process_frame counts are not elapsed seconds, especially without PNG work.
	await create_timer(.5).timeout
	await RenderingServer.frame_post_draw
	_check(not ui.board.moving and ui.board.hero_visual==Vector2(ui.game.position()),"release finishes current step at exact map landing")
	_check(ui.held_move_keys.is_empty(),"release clears held key")
	var before: Dictionary = ui.game.state.duplicate(true)
	ui.board.play_interaction()
	for i in 24:
		await process_frame
		await RenderingServer.frame_post_draw
	_check(ui.game.state==before,"interaction presentation is read-only")
	FileAccess.open(WALK_OUT+"results.json",FileAccess.WRITE).store_string(JSON.stringify({"checks":checks,"failures":failures,"samples":samples,"scope":"Real main UI, C0 seed42 public departure, two legal empty tiles using held InputEventKey; no gameplay state injection."},"\t"))
	print("Hero main held movement: %d checks, %d failures" % [checks,failures])
	quit(1 if failures else 0)
