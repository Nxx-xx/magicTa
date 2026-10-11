extends SceneTree
const Board = preload("res://scripts/ui/grid_board.gd")
const Gait = preload("res://scripts/ui/hero_gait.gd")
const Audio = preload("res://scripts/ui/audio_feedback.gd")
const Preferences = preload("res://scripts/ui/presentation_settings.gd")
var checks := 0
var failures := 0
var contacts := 0

func _initialize() -> void:
	_run.call_deferred()

func check(value: bool, label: String) -> void:
	checks += 1
	if not value:
		failures += 1
		push_error("FAIL: " + label)

func _run() -> void:
	Gait.warm()
	for facing in ["down", "left", "up", "right"]:
		var hashes := {}
		for i in 24:
			var pose := Gait.pose(facing, (i + 0.01) / 24.0 * TAU)
			var image: Image = pose.texture.get_image()
			check(image.get_size() == Vector2i(128, 128) and image.get_used_rect().has_area(), "nonempty gait " + facing)
			hashes[image.get_data().hex_encode().sha256_text()] = true
		check(hashes.size() == 24, "24 distinct rig poses " + facing)
		check(Gait.pose(facing, TAU).texture == Gait.pose(facing, 0).texture, "seamless phase wrap " + facing)
		check(Gait.pose(facing, PI, 0).frame == 30 and Gait.pose(facing, TAU, 0).frame == 24, "settle starts on correct foot " + facing)
	var board := Board.new()
	root.add_child(board)
	board.set_process(false)
	board.footstep.connect(func(): contacts += 1)
	var floor_data := {"floor": 1, "floor_seed": "gait-test", "phase3_recipe": {}}
	floor_data.rows = []
	floor_data.entities = {}
	for row in 11: floor_data.rows.append("...........")
	for fps in [30, 60, 120]:
		board.map = {}
		board.setup(floor_data, Vector2i(1, 1), Vector2i(-1, -1), true)
		board.setup(floor_data, Vector2i(2, 1), Vector2i(-1, -1), true)
		contacts = 0
		var elapsed := 0.0
		while board.moving:
			var previous := board.hero_visual.x
			board._process(1.0 / fps)
			elapsed += 1.0 / fps
			check(board.hero_visual.x > previous and board.hero_visual.x <= 2.0, "monotonic travel at %d FPS" % fps)
		check(elapsed < Board.WALK_SECONDS + 1.0 / fps + .001 and contacts == 1, "one sound per landing at %d FPS" % fps)
		check(board.hero_pose().frame == 30, "landing uses contact pose")
		var clock := board.idle_seconds
		for i in 12: board._process(1.0 / 120)
		check(not board.moving and board.settle_seconds < 0 and contacts == 1, "settle does not move or add sounds")
		check(board.idle_seconds > clock, "settling cannot reset world animation clocks")
	board.setup(floor_data, Vector2i(3, 1), Vector2i(-1, -1), true)
	board._process(.06)
	var before := board.hero_visual
	var phase := board.walk_phase
	board.setup(floor_data, Vector2i(3, 1), Vector2i(-1, -1), true)
	check(board.hero_visual == before and board.walk_phase == phase, "HUD refresh preserves pose and travel")
	board.reduce_motion = true
	check(board.hero_pose().frame == 0, "reduced motion freezes sprite")
	board.reduce_motion = false
	for i in 5: board._process(.06)
	board.play_interaction()
	check(board.hero_pose().texture == board.hero_catalog.frame_at("map_interact_right", 0).texture, "interaction takes priority over settle")
	board.queue_free()
	var audio := Audio.new()
	audio.prepare_steps()
	var settings := Preferences.new()
	settings.muted = false
	settings.effects_volume = 1.0
	audio.play_step(self, settings)
	check(is_instance_valid(audio.footstep_player) and audio.footstep_player.volume_db < -10, "footsteps stay under interface effects")
	var channel := audio.footstep_player
	audio.play_step(self, settings)
	check(channel == audio.footstep_player, "footsteps reuse audio channel")
	settings.muted = true
	audio.play_step(self, settings)
	check(not is_instance_valid(audio.footstep_player), "mute stops the step channel")
	for cue in ["step", "step_alt"]:
		var sound := Audio._tone(cue)
		var peak := 0
		for sample in sound.data.size() / 2: peak = maxi(peak, absi(sound.data.decode_s16(sample * 2)))
		check(peak > 1000 and peak < 20000, "audible unclipped footfall " + cue)
		check(sound.data.decode_s16(0) == 0 and absi(sound.data.decode_s16(sound.data.size() - 2)) <= 1, "click-free endpoints " + cue)
		check(sound.get_length() < .10, "short footfall tail " + cue)
		if "--samples" in OS.get_cmdline_user_args(): sound.save_to_wav("res://build/analysis/walking/" + cue + ".wav")
	await process_frame
	print("WALKING POLISH: %d checks, %d failures" % [checks, failures])
	quit(1 if failures else 0)
