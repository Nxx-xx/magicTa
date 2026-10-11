extends SceneTree
const Player = preload("res://scripts/ui/phase3_combat_player.gd")
const Tutorial = preload("res://scripts/ui/phase3_tutorial.gd")
const Fixture = preload("res://tests/phase3_animation_fixture.gd")
var canvas: Control
var player: Control
var prompt: PanelContainer
var lesson: Dictionary = Tutorial.initial_state()
var controls: HBoxContainer
var event_index := 0
var sizes := [Vector2i(320, 640), Vector2i(360, 640), Vector2i(540, 960), Vector2i(900, 960)]

func _initialize() -> void:
	_start.call_deferred()

func _start() -> void:
	if not "05-animation" in OS.get_environment("APPDATA"):
		push_error("Use phase3_animation_verify.ps1 for isolated preview")
		quit(1)
		return
	root.min_size = Vector2i(0, 0)
	root.size = Vector2i(540, 960)
	root.content_scale_mode = Window.CONTENT_SCALE_MODE_DISABLED
	root.content_scale_size = Vector2i.ZERO
	canvas = Control.new()
	root.add_child(canvas)
	canvas.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	var background := ColorRect.new()
	background.color = Color("102330")
	background.mouse_filter = Control.MOUSE_FILTER_IGNORE
	canvas.add_child(background)
	background.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	var title := Label.new()
	title.text = "PHASE 3 · 独立协议夹具预览"
	title.position = Vector2(12, 8)
	canvas.add_child(title)
	controls = HBoxContainer.new()
	controls.position = Vector2(12, 36)
	canvas.add_child(controls)
	for text in ["重播", "减动效", "教学"]:
		var button := Button.new()
		button.text = text
		button.custom_minimum_size = Vector2(88, 44)
		controls.add_child(button)
		if text == "重播": button.pressed.connect(func(): _replay(false))
		elif text == "减动效": button.pressed.connect(func(): _replay(true))
		else: button.pressed.connect(_show_tutorial)
	_replay(false)
	if "--capture" in OS.get_cmdline_user_args(): await _capture()

func _replay(reduced: bool) -> void:
	if is_instance_valid(player):
		player.free()
	if is_instance_valid(prompt): prompt.free()
	player = Player.new()
	player.configure(Fixture.report(), true, {"rank": "boss", "reduce_motion": reduced})
	canvas.add_child(player)
	player.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	player.offset_top = 86
	player.dismissed.connect(func(): _show_tutorial())

func _show_tutorial() -> void:
	if is_instance_valid(prompt): prompt.free()
	player.visible = false
	lesson = Tutorial.reduce(Tutorial.initial_state(), {"type": "ruin_viewed", "ruin_id": "p3_oath_ruin"}).state
	prompt = Tutorial.create_prompt(Tutorial.prompt(lesson))
	canvas.add_child(prompt)
	prompt.set_anchors_and_offsets_preset(Control.PRESET_TOP_WIDE)
	prompt.offset_left = 12
	prompt.offset_right = -12
	prompt.offset_top = 160
	prompt.offset_bottom = 160
	prompt.dismissed.connect(func(id):
		lesson = Tutorial.reduce(lesson, {"type": "dismiss", "id": id}).state
		prompt.set_prompt(Tutorial.prompt(lesson))
	)
	prompt.skip_requested.connect(func():
		lesson = Tutorial.reduce(lesson, {"type": "skip_all"}).state
		prompt.set_prompt(Tutorial.prompt(lesson))
	)

func _capture() -> void:
	for viewport_size in sizes:
		root.size = viewport_size
		_replay(true)
		await process_frame
		await process_frame
		await RenderingServer.frame_post_draw
		root.get_texture().get_image().save_png("res://build/verification/phase3/05-animation/combat_%dx%d.png" % [viewport_size.x, viewport_size.y])
		_show_tutorial()
		await process_frame
		await RenderingServer.frame_post_draw
		root.get_texture().get_image().save_png("res://build/verification/phase3/05-animation/tutorial_%dx%d.png" % [viewport_size.x, viewport_size.y])
	root.size = Vector2i(540, 960)
	_replay(false)
	player.set_process(false)
	player.advance(0.2)
	await process_frame
	await RenderingServer.frame_post_draw
	root.get_texture().get_image().save_png("res://build/verification/phase3/05-animation/static_fallback.png")
	quit()
