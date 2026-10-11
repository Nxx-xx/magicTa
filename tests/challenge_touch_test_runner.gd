extends "res://tests/challenge_mobile_test_runner.gd"

func _pointer_event(position: Vector2, pressed: bool) -> void:
	# WeChat dispatches a mouse stream followed by native touch for one gesture.
	if not "--touch-only" in OS.get_cmdline_user_args():
		super._pointer_event(position, pressed)
	var touch := InputEventScreenTouch.new()
	touch.index = 0
	touch.pressed = pressed
	touch.position = position
	Input.parse_input_event(touch)

func _initialize() -> void:
	Input.emulate_touch_from_mouse = false
	create_timer(60).timeout.connect(func():
		push_error("Challenge touch regression timed out")
		quit(1)
	)
	super._initialize()
