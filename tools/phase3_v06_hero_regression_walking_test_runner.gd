extends SceneTree
## Real held inputs and frame-by-frame continuity, independent of OS key repeat.
const Screen = preload("res://scripts/ui/map_screen.gd")
const Core = preload("res://scripts/core/map_engine.gd")
const Audio = preload("res://scripts/ui/audio_feedback.gd")
var checks := 0
var failures := 0
var screen
var landings := 0

func _initialize() -> void:
	_run.call_deferred()

func _check(value: bool, label: String) -> void:
	checks += 1
	if not value:
		failures += 1
		push_error("FAIL: " + label)

func _key(code: int, pressed: bool, echo: bool = false) -> void:
	var event := InputEventKey.new()
	event.keycode = code
	event.pressed = pressed
	event.echo = echo
	Input.parse_input_event(event)

func _touch(position: Vector2, pressed: bool) -> void:
	var event := InputEventScreenTouch.new()
	event.index = 0
	event.position = position
	event.pressed = pressed
	Input.parse_input_event(event)

func _drag(position: Vector2) -> void:
	var event := InputEventScreenDrag.new()
	event.index = 0
	event.position = position
	Input.parse_input_event(event)

func _reset(position: Vector2i = Vector2i(2, 5)) -> void:
	screen._stop_movement_input()
	screen._close_overlay()
	screen.game.state.pending = {}
	screen.game.state.position = [position.x, position.y]
	screen.game.floor_data().entities.clear()
	for y in range(1, 10):
		screen.game.floor_data().rows[y] = "#.........#"
	screen.board.map = {}
	screen.settings.reduce_motion = false
	screen.settings.muted = false
	screen.board.set_overview(false)
	screen._refresh_map()
	screen.board.recenter()
	landings = 0

func _run() -> void:
	var isolated := ProjectSettings.globalize_path("user://").replace("\\", "/")
	if not ("walking" in isolated or isolated.contains("build/verification/phase3/08-parallel/hero_refine/")):
		push_error("Requires isolated APPDATA/LOCALAPPDATA under build/verification/walking")
		quit(2)
		return
	root.size = Vector2i(540, 960)
	screen = Screen.new()
	screen.game = Core.new("user://walking_fixture.json")
	screen.game.persistence_enabled = false
	root.add_child(screen)
	screen.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	screen._start("42")
	for i in 8:
		await process_frame
	screen.board.footstep.connect(func(): landings += 1)
	_reset()
	_key(KEY_RIGHT, true)
	await process_frame
	_check(screen.game.position() == Vector2i(3,5) and screen.board.hero_visual.x >= 2.0 and screen.board.hero_visual.x < 2.3, "input starts movement without teleporting visual")
	await create_timer(0.07).timeout
	_check(screen.board.hero_visual.x > 2.0 and screen.board.hero_visual.x < 3.0, "intermediate positions render during travel")
	var before_refresh: Vector2 = screen.board.hero_visual
	screen._refresh_map()
	_check(screen.board.moving and screen.board.hero_visual == before_refresh, "HUD refresh preserves active movement and position")
	# Measure several cell crossings: no stagnant frames or one-cell position jumps.
	var last: Vector2 = screen.board.hero_visual
	var max_stride := 0.0
	var stalled_frames := 0
	var deadline := Time.get_ticks_msec() + 610
	while Time.get_ticks_msec() < deadline:
		await process_frame
		var stride: float = screen.board.hero_visual.distance_to(last)
		max_stride = maxf(max_stride, stride)
		if stride < 0.00001:
			stalled_frames += 1
		last = screen.board.hero_visual
	_check(landings >= 3 and screen.game.position().x >= 5, "held key chains multiple cells without OS repeat")
	_check(stalled_frames <= 1 and max_stride < 0.30, "continuous positions across cell boundaries with no dwell")
	_check(is_instance_valid(screen.audio.footstep_player), "walking creates audible footstep channel")
	_key(KEY_RIGHT, false)
	var stop_cell: Vector2i = screen.game.position()
	await create_timer(0.30).timeout
	_check(screen.game.position() == stop_cell and not screen.board.moving and screen.board.hero_visual == Vector2(stop_cell), "release finishes current stride without adding a cell")
	var stopped_landings := landings
	await create_timer(0.30).timeout
	_check(landings == stopped_landings, "stationary hero has no repeated footsteps")
	_reset()
	_key(KEY_D, true)
	await create_timer(0.05).timeout
	_key(KEY_S, true)
	_key(KEY_D, false)
	_check(screen.game.position() == Vector2i(3,5) and screen.board.facing == "right", "mid-stride turn cannot cut diagonally")
	await create_timer(0.20).timeout
	_check(screen.game.position() == Vector2i(3,6) and screen.board.facing == "down", "buffered direction turns on cell boundary")
	_key(KEY_S, false)
	await create_timer(0.25).timeout
	_reset()
	_key(KEY_RIGHT, true)
	await create_timer(0.04).timeout
	_key(KEY_RIGHT, true, true)
	_key(KEY_RIGHT, true, true)
	_check(screen.game.position() == Vector2i(3,5), "OS repeat cannot accelerate walking")
	_key(KEY_RIGHT, false)
	await create_timer(0.24).timeout
	_reset()
	screen.settings.reduce_motion = true
	screen._refresh_map()
	_key(KEY_RIGHT, true)
	await create_timer(0.06).timeout
	_check(screen.board.hero_visual.x > 2 and screen.board.hero_visual.x < 3, "reduce motion still preserves readable travel")
	_key(KEY_RIGHT, false)
	await create_timer(0.24).timeout
	for interruption in ["wall", "enemy", "door", "inventory", "background", "overview"]:
		_reset()
		if interruption == "wall":
			screen.game.floor_data().rows[5] = "#...#.....#"
		elif interruption in ["enemy", "door"]:
			screen.game.floor_data().entities["4,5"] = {"type":interruption,"name":"目标","enemy_id":"slime","pos":[4,5],"key_type":"copper","cost":1}
		_key(KEY_RIGHT, true)
		await create_timer(0.07).timeout
		if interruption == "inventory":
			screen._open_overlay("inventory")
		elif interruption == "background":
			screen.notification(Node.NOTIFICATION_APPLICATION_FOCUS_OUT)
		elif interruption == "overview":
			screen._toggle_overview()
		await create_timer(0.42).timeout
		_check(screen.game.position() == Vector2i(3,5) and screen.held_move_keys.is_empty(), interruption + " cancels continuous keyboard input")
		_check(not screen.board.moving and screen.board.hero_visual == Vector2(3,5), interruption + " preserves final visual cell")
		if interruption in ["enemy", "door"]:
			_check(screen.game.state.pending.get("kind", "") == "entity" and int(screen.game.state.player.hp) == 100, interruption + " remains uncommitted")
		if interruption == "background":
			_check(not is_instance_valid(screen.audio.footstep_player), "background cannot restart a finishing footfall")
		_key(KEY_RIGHT, false)
	_reset()
	var center: Vector2 = screen.floating_controls.get_global_rect().get_center()
	_touch(center, true)
	_drag(center + Vector2(30,0))
	await create_timer(0.55).timeout
	_check(screen.game.position().x >= 5 and landings >= 2, "joystick uses same continuous walking clock")
	_touch(center, false)
	stop_cell = screen.game.position()
	await create_timer(0.28).timeout
	_check(screen.game.position() == stop_cell and not screen.board.moving, "joystick release clears held intention")
	_reset()
	screen.settings.muted = true
	screen.audio.stop_steps()
	_key(KEY_RIGHT, true)
	await create_timer(0.25).timeout
	_key(KEY_RIGHT, false)
	_check(not is_instance_valid(screen.audio.footstep_player), "mute prevents walking sound")
	await create_timer(0.25).timeout
	var left := Audio._tone("step")
	var right := Audio._tone("step_alt")
	_check(left.data != right.data and left.data.size() > 4000, "alternating boot contacts use distinct nonempty PCM")
	if "--capture" in OS.get_cmdline_user_args():
		await _capture_walk()
	screen.queue_free()
	for i in 8:
		await process_frame
	print("WALKING: %d checks, %d failures" % [checks, failures])
	quit(0 if failures == 0 else 1)

func _capture_walk() -> void:
	_reset(Vector2i(2,3))
	Engine.max_fps = 30
	var folder := ProjectSettings.globalize_path("res://build/verification/phase3/09-refinement/hero/regression/walking_frames")
	DirAccess.make_dir_recursive_absolute(folder)
	_key(KEY_RIGHT, true)
	for frame in 54:
		if frame == 21:
			_key(KEY_DOWN, true)
			_key(KEY_RIGHT, false)
		if frame == 39:
			_key(KEY_DOWN, false)
		await RenderingServer.frame_post_draw
		root.get_texture().get_image().save_png(folder.path_join("walk_%03d.png" % frame))
	_check(not screen.board.moving, "captured walk settles after release")
