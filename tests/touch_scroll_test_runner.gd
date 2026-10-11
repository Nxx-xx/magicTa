extends SceneTree
const Screen = preload("res://tests/legacy_map_screen_fixture.gd")
const Core = preload("res://tests/legacy_map_core_fixture.gd")
var screen
var checks := 0
var failures := 0
var clicks := 0

func _initialize() -> void:
	_run.call_deferred()

func _check(value: bool, label: String) -> void:
	checks += 1
	if not value:
		failures += 1
		push_error("FAIL: " + label)

func _frames() -> void:
	for i in 8: await process_frame

func _event(position: Vector2, phase: String, touch: bool, id: int = 0) -> void:
	var event: InputEvent
	if phase == "move":
		event = InputEventScreenDrag.new() if touch else InputEventMouseMotion.new()
		if touch: event.index = id
		else: event.button_mask = MOUSE_BUTTON_MASK_LEFT
		event.relative = Vector2(0,-80)
	else:
		event = InputEventScreenTouch.new() if touch else InputEventMouseButton.new()
		if touch: event.index = id
		else: event.button_index = MOUSE_BUTTON_LEFT
		event.pressed = phase == "down"
	event.position = position
	Input.parse_input_event(event)
	await process_frame

func _fill(list: ScrollContainer) -> Button:
	screen._clear(list)
	var body := VBoxContainer.new()
	body.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	list.add_child(body)
	if list == screen.scroll: screen.body = body
	var first: Button
	for i in 16:
		# Deliberately use STOP panels and buttons, the original failure case.
		var card := PanelContainer.new()
		body.add_child(card)
		var button := Button.new()
		button.text = "可拖动的内容 %d" % i
		button.custom_minimum_size.y = 90
		card.add_child(button)
		button.pressed.connect(func(): clicks += 1)
		if i == 0: first = button
	list.scroll_vertical = 0
	return first

func _swipe(list: ScrollContainer, button: Button, mode: String, label: String) -> void:
	list.scroll_vertical = 0
	await _frames()
	var before: Array = screen.game.state.get("position",[]).duplicate()
	var count := clicks
	var start := button.get_global_rect().get_center()
	var touch := mode == "touch"
	await _event(start,"down",touch)
	if mode == "wechat": await _event(start,"down",true)
	await _event(start-Vector2(0,80),"move",touch)
	if mode == "wechat": await _event(start-Vector2(0,80),"move",true)
	await _event(start-Vector2(0,80),"up",touch)
	if mode == "wechat": await _event(start-Vector2(0,80),"up",true)
	await _frames()
	_check(list.scroll_vertical >= 70 and list.scroll_vertical <= 90, label + " scrolls once by finger displacement")
	_check(clicks == count, label + " cancels pressed button")
	_check(screen.game.state.get("position",[]) == before and screen.click_route.is_empty(), label + " never moves map")
	_check(not screen.touch_scroll.dragging and screen.touch_scroll.pointer == -2, label + " releases gesture")

func _run() -> void:
	if not "touch-scroll" in ProjectSettings.globalize_path("user://"):
		push_error("Requires isolated APPDATA/LOCALAPPDATA under build/verification/touch-scroll")
		quit(2)
		return
	root.size = Vector2i(360,640)
	screen = Screen.new()
	screen.page = "menu"
	screen.game = Core.new("user://scroll_fixture.json")
	screen.game.persistence_enabled = false
	root.add_child(screen)
	screen.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	await _frames()
	# Compact camp no longer overflows far enough to clip the board under the header.
	# Add fixture-only space so the clipping regression still exercises that boundary.
	var camp_spacer := Control.new()
	camp_spacer.custom_minimum_size.y = 240
	screen.body.add_child(camp_spacer)
	await _frames()
	screen.scroll.scroll_vertical = int(screen.camp_map.board.global_position.y - screen.scroll.global_position.y + 40)
	await _frames()
	var camp_hits := [0]
	screen.camp_map.board.cell_selected.connect(func(_cell): camp_hits[0] += 1)
	var clipped_point: Vector2 = screen.scroll.get_global_rect().position + Vector2(80,-15)
	_check(screen.camp_map.board.get_global_rect().has_point(clipped_point),"clipped camp board lies behind header fixture")
	await _event(clipped_point,"down",true)
	await _event(clipped_point,"up",true)
	_check(camp_hits[0] == 0,"touch on header never activates board clipped behind it")
	screen.scroll.scroll_vertical = 0
	await _frames()
	screen.camp_map.walk_to(Vector2i(8,8))
	var menu_point: Vector2 = screen.scroll.get_global_rect().position + Vector2(80,60)
	await _event(menu_point,"down",true)
	await _event(menu_point-Vector2(0,40),"move",true)
	await _event(menu_point-Vector2(0,40),"up",true)
	_check(screen.camp_map.route.is_empty(),"dragging menu stops camp route after current stride")
	await create_timer(0.3).timeout
	var button := _fill(screen.scroll)
	await _frames()
	for mode in ["mouse","touch","wechat"]:
		await _swipe(screen.scroll,button,mode,"menu " + mode)
	screen._start("42")
	await _frames()
	for sheet in ["inventory","log","floors","settings"]:
		screen._open_overlay(sheet)
		button = _fill(screen.scroll)
		await _frames()
		for mode in ["mouse","touch","wechat"]:
			await _swipe(screen.scroll,button,mode,sheet + " " + mode)
		screen._close_overlay()
	# Nested lists choose the innermost clipped list, not the outer page.
	screen._open_overlay("inventory")
	screen._clear(screen.body)
	var nested := ScrollContainer.new()
	nested.custom_minimum_size.y = 160
	nested.horizontal_scroll_mode = ScrollContainer.SCROLL_MODE_DISABLED
	screen.body.add_child(nested)
	button = _fill(nested)
	var spacer := Control.new()
	spacer.custom_minimum_size.y = 1400
	screen.body.add_child(spacer)
	await _frames()
	for mode in ["mouse","touch","wechat"]:
		await _swipe(nested,button,mode,"nested " + mode)
		_check(screen.scroll.scroll_vertical == 0,"nested swipe leaves parent stationary")
	# A tap remains a tap; only motion beyond the threshold cancels it.
	nested.scroll_vertical = 0
	await _frames()
	var count := clicks
	var point := button.get_global_rect().get_center()
	await _event(point,"down",false)
	await _event(point,"up",false)
	_check(clicks == count+1,"ordinary button tap still works")
	count = clicks
	await _event(point,"down",true)
	await _event(point,"up",true)
	_check(clicks == count+1,"native touch button tap still works")
	count = clicks
	await _event(point,"down",false)
	await _event(point,"down",true)
	await _event(point,"up",false)
	await _event(point,"up",true)
	_check(clicks == count+1,"WeChat dual-stream tap activates button once")
	await _event(point,"down",true)
	await _event(point-Vector2(0,80),"move",true,1)
	await _event(point,"up",true,1)
	_check(nested.scroll_vertical == 0,"second finger cannot scroll or release owner")
	await _event(point,"up",true)
	await _event(point,"down",false)
	await _event(point-Vector2(0,80),"move",false)
	screen.notification(Node.NOTIFICATION_APPLICATION_FOCUS_OUT)
	_check(not screen.touch_scroll.dragging,"background cancels scroll gesture")
	await _event(point-Vector2(0,80),"up",false)
	screen._close_overlay()
	# The combat report owns a separate ScrollContainer under the modal player.
	screen.game.state.pending = {}
	screen.game.state.position = [5,5]
	screen.game.floor_data().rows[5] = "#.........#"
	screen.game.floor_data().entities["6,5"] = {"type":"enemy","name":"骑士","enemy_id":"knight","pos":[6,5]}
	screen.game.state.player.attack = 100
	screen.game.interact(Vector2i(6,5))
	screen._render(true)
	screen._fight()
	await _frames()
	screen.combat_view.settle()
	screen.combat_view.secondary.pressed.emit()
	await _frames()
	var report_scroll: ScrollContainer = screen.combat_view.log_scroll
	button = _fill(report_scroll)
	await _frames()
	for mode in ["mouse","touch","wechat"]:
		await _swipe(report_scroll,button,mode,"combat report " + mode)
	screen._finish_combat()
	screen.game.save_error = "测试存档错误：".repeat(200)
	screen._refresh_map()
	await _frames()
	button = _fill(screen.save_error_scroll)
	await _frames()
	await _swipe(screen.save_error_scroll,button,"touch","save diagnostics touch")
	if "--capture" in OS.get_cmdline_user_args():
		await RenderingServer.frame_post_draw
		root.get_texture().get_image().save_png("res://build/verification/touch-scroll/nested-and-diagnostics.png")
	screen.queue_free()
	await _frames()
	print("TOUCH SCROLL: %d checks, %d failures" % [checks,failures])
	quit(0 if failures == 0 else 1)
