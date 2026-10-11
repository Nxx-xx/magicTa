extends SceneTree
## Real pointer routing, click routes and camera transforms in isolated user data.
const Screen = preload("res://tests/legacy_map_screen_fixture.gd")
const Core = preload("res://tests/legacy_map_core_fixture.gd")
var checks := 0
var failures := 0
var capture := false

func _initialize() -> void:
	_run.call_deferred()

func _check(value: bool, label: String) -> void:
	checks += 1
	if not value:
		failures += 1
		push_error("FAIL: " + label)

func _frames() -> void:
	for i in 8:
		await process_frame

func _settle(screen) -> void:
	var deadline := Time.get_ticks_msec() + 1500
	while screen.board.moving and Time.get_ticks_msec() < deadline:
		await process_frame
	await _frames()

func _mouse(position: Vector2, pressed: bool) -> void:
	var event := InputEventMouseButton.new()
	event.button_index = MOUSE_BUTTON_LEFT
	event.position = position
	event.pressed = pressed
	Input.parse_input_event(event)
	await process_frame

func _click(position: Vector2) -> void:
	await _mouse(position, true)
	await _mouse(position, false)
	await _frames()

func _touch(position: Vector2, pressed: bool, index: int = 0, canceled: bool = false) -> void:
	var event := InputEventScreenTouch.new()
	event.index = index
	event.canceled = canceled
	event.position = position
	event.pressed = pressed
	Input.parse_input_event(event)
	await process_frame

func _drag_pointer(position: Vector2, relative: Vector2, touch: bool = false, index: int = 0) -> void:
	var event: InputEvent
	if touch:
		event = InputEventScreenDrag.new()
		event.index = index
	else:
		event = InputEventMouseMotion.new()
		event.button_mask = MOUSE_BUTTON_MASK_LEFT
	event.position = position
	event.relative = relative
	Input.parse_input_event(event)
	await process_frame

func _capture(label: String) -> void:
	if not capture:
		return
	await RenderingServer.frame_post_draw
	var directory := ProjectSettings.globalize_path("res://build/verification/mobile-map")
	DirAccess.make_dir_recursive_absolute(directory)
	_check(root.get_texture().get_image().save_png(directory.path_join(label + ".png")) == OK, "capture " + label)

func _run() -> void:
	if not "mobile-map" in ProjectSettings.globalize_path("user://"):
		push_error("Run with isolated APPDATA/LOCALAPPDATA under build/verification/mobile-map")
		quit(2)
		return
	capture = "--capture" in OS.get_cmdline_user_args()
	root.min_size = Vector2i.ZERO
	var screen = Screen.new()
	screen.game = Core.new("user://mobile_fixture.json")
	screen.game.persistence_enabled = false
	root.add_child(screen)
	screen.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	await _frames()
	for dimensions in [Vector2i(320,640), Vector2i(360,640), Vector2i(540,960), Vector2i(900,960)]:
		root.size = dimensions
		screen._start("42")
		screen.board.reduce_motion = true
		await _frames()
		var suffix := "%dx%d" % [dimensions.x, dimensions.y]
		_check(screen.board.size.y >= screen.size.y * 0.70, "map height share " + suffix)
		_check(screen.board._cell_size() >= 60, "enlarged exploration cells " + suffix)
		_check(not screen.detail_panel.visible, "no empty detail card " + suffix)
		_check(screen.find_children("FloatingJoystick", "", true, false).is_empty(), "joystick removed " + suffix)
		_check(screen.board.safe_bottom <= 64, "map space returned to player " + suffix)
		await _capture("explore_" + suffix)
		# Use a clear corridor and real GUI events; the pad must not click through.
		screen.game.state.position = [5,5]
		screen.game.floor_data().rows[5] = "#.........#"
		screen.game.floor_data().entities.erase("4,5")
		screen.game.floor_data().entities.erase("3,5")
		screen._refresh_map()
		screen.board.recenter()
		await _frames()
		var target_position: Vector2 = screen.board.global_position + screen.board._origin() + Vector2(4.5,5.5) * screen.board._cell_size()
		await _click(target_position)
		await _settle(screen)
		_check(screen.game.position() == Vector2i(4,5), "click moves exactly one cell " + suffix)
		var cell_position: Vector2 = screen.board.global_position + screen.board._origin() + Vector2(3.5,5.5) * screen.board._cell_size()
		await _click(cell_position)
		await _settle(screen)
		_check(screen.game.position() == Vector2i(3,5), "zoomed tile hit mapping " + suffix)
		var selected_before: Vector2i = screen.selected
		var position_before: Vector2i = screen.game.position()
		var start: Vector2 = screen.board.get_global_rect().get_center()
		await _mouse(start, true)
		var drag := InputEventMouseMotion.new()
		drag.position = start + Vector2(60, -35)
		drag.relative = Vector2(60, -35)
		drag.button_mask = MOUSE_BUTTON_MASK_LEFT
		Input.parse_input_event(drag)
		await process_frame
		await _mouse(drag.position, false)
		await _frames()
		_check(screen.board.following and not screen.recenter_button.visible, "drag keeps hero follow " + suffix)
		_check(screen.selected == selected_before and screen.game.position() == position_before, "drag never selects or moves " + suffix)
		_check(screen.minimap.visible, "minimap remains available " + suffix)
		target_position = screen.board.global_position + screen.board._origin() + Vector2(4.5,5.5) * screen.board._cell_size()
		await _touch(target_position, true)
		await _touch(target_position, false)
		await _settle(screen)
		_check(screen.game.position() == Vector2i(4,5), "native touch produces exactly one step " + suffix)
		start = screen.board.get_global_rect().get_center()
		await _touch(start, true)
		var touch_drag := InputEventScreenDrag.new()
		touch_drag.index = 0
		touch_drag.position = start + Vector2(45,30)
		touch_drag.relative = Vector2(45,30)
		Input.parse_input_event(touch_drag)
		await process_frame
		await _touch(touch_drag.position, false)
		await _frames()
		_check(screen.board.following and screen.game.position() == Vector2i(4,5), "touch drag keeps follow without moving " + suffix)
		screen.board.recenter()
		# Follow bounds must protect the hero from the pad even at map corners.
		for corner in [Vector2i(1,1), Vector2i(9,1), Vector2i(1,9), Vector2i(9,9)]:
			screen.game.state.position = [corner.x, corner.y]
			screen._refresh_map()
			screen.board.recenter()
			await _frames()
			var hero_rect := Rect2(screen.board.global_position + screen.board._origin() + Vector2(corner) * screen.board._cell_size(), Vector2.ONE * screen.board._cell_size())
			_check(screen.board.get_global_rect().encloses(hero_rect), "hero stays visible " + suffix + str(corner))
			_check(screen.board._safe_rect().size.y > 0, "hero safe area is usable " + suffix + str(corner))
			_check(hero_rect.get_center().distance_to(screen.board.get_global_rect().get_center()) < 1, "hero centered at map edge " + suffix + str(corner))
		var before_minimap: Vector2i = screen.game.position()
		await _click(screen.minimap.get_global_rect().get_center())
		_check(screen.game.position() == before_minimap and not screen.minimap.visible, "minimap opens overview without map click-through " + suffix)
		_check(screen.board.overview, "overview active " + suffix)
		var map_rect := Rect2(screen.board._origin(), Vector2.ONE * screen.board._cell_size() * 11)
		_check(Rect2(Vector2.ZERO, screen.board.size).encloses(map_rect), "overview fits all 121 cells " + suffix)
		await _capture("overview_" + suffix)
		position_before = screen.game.position()
		cell_position = screen.board.global_position + screen.board._origin() + (Vector2(position_before) + Vector2(-0.5,0.5)) * screen.board._cell_size()
		await _click(cell_position)
		await _settle(screen)
		_check(screen.game.position() == position_before + Vector2i.LEFT, "overview click moves to floor " + suffix)
		screen._close_overlay()
		await _frames()
		await _click(screen.overview_button.get_global_rect().get_center())
		_check(not screen.board.overview and screen._can_walk(), "return to exploration " + suffix)
		var mini_point: Vector2 = screen.minimap.get_global_rect().get_center()
		position_before = screen.game.position()
		await _touch(mini_point, true)
		await _touch(mini_point, false)
		await _frames()
		_check(screen.board.overview and screen.game.position() == position_before, "native minimap tap opens full map only " + suffix)
		await _click(screen.overview_button.get_global_rect().get_center())
		await _mouse(mini_point, true)
		await _touch(mini_point, true)
		await _mouse(mini_point, false)
		await _touch(mini_point, false)
		await _frames()
		_check(screen.board.overview and screen.game.position() == position_before, "WeChat minimap tap toggles once " + suffix)
		await _click(screen.overview_button.get_global_rect().get_center())
		screen.selected = Vector2i(7,9)
		screen.game.floor_data().entities["7,9"] = {"type":"enemy", "name":"史莱姆", "enemy_id":"slime", "pos":[7,9]}
		screen._refresh_map()
		await _frames()
		_check(screen.detail_panel.visible and screen.detail_copy.text.contains("生命") and screen.detail_copy.text.contains("攻击") and screen.detail_copy.text.contains("防御"), "enemy attributes stay visible " + suffix)
		_check(screen.detail_copy.get_global_rect().end.y <= screen.detail_panel.get_global_rect().end.y, "summary fits " + suffix)
		_check(screen.detail_title.get_visible_line_count() == 1 and screen.detail_copy.get_visible_line_count() == 1, "summary text renders a complete line " + suffix)
		await _capture("target_" + suffix)
		screen._open_overlay("inventory")
		await _frames()
		_check(screen.click_route.is_empty(), "sheet clears route " + suffix)
		_check(not screen._can_walk(), "sheet blocks movement " + suffix)
		screen._close_overlay()
	await _click_safety(screen)
	screen.queue_free()
	await _frames()
	print("MOBILE MAP: %d checks, %d failures" % [checks, failures])
	quit(0 if failures == 0 else 1)

func _reset_corridor(screen) -> Vector2:
	screen._stop_movement_input()
	screen._close_overlay()
	screen.game.state.pending = {}
	screen.game.state.position = [5,5]
	for y in range(1,10):
		screen.game.floor_data().rows[y] = "#.........#"
	screen.game.floor_data().entities.clear()
	screen.board.map = {}
	screen._refresh_map()
	screen.board.recenter()
	return screen.board.global_position + screen.board._origin() + Vector2(6.5,5.5) * screen.board._cell_size()

func _click_safety(screen) -> void:
	var target := _reset_corridor(screen)
	await _touch(target, true)
	await _touch(target + Vector2(10,0), true, 1)
	await _touch(target + Vector2(10,0), false, 1)
	_check(screen.game.position() == Vector2i(5,5) and screen.board.pointer_down, "second finger cannot release owner's tap")
	await _touch(target, false)
	await _settle(screen)
	_check(screen.game.position() == Vector2i(6,5), "owner's native tap moves exactly once")
	target = _reset_corridor(screen)
	await _touch(target, true)
	await _touch(target, false, 0, true)
	await _settle(screen)
	_check(screen.game.position() == Vector2i(5,5), "canceled touch never moves")
	target = _reset_corridor(screen)
	await _mouse(target, true)
	await _touch(target, true)
	await _touch(target, false, 0, true)
	await _mouse(target, false)
	await _settle(screen)
	_check(screen.game.position() == Vector2i(5,5) and not screen.board.pointer_down, "WeChat dual-stream cancellation never commits a tap")
	target = _reset_corridor(screen)
	await _touch(target, true)
	screen.notification(Node.NOTIFICATION_APPLICATION_FOCUS_OUT)
	await _touch(target, false)
	_check(screen.game.position() == Vector2i(5,5), "background cancels unfinished tap")
	for interruption in ["inventory", "overview", "background", "resize"]:
		_reset_corridor(screen)
		screen._select_cell(Vector2i(8,5))
		if interruption == "inventory": screen._open_overlay("inventory")
		elif interruption == "overview": screen._toggle_overview()
		elif interruption == "background": screen.notification(Node.NOTIFICATION_APPLICATION_FOCUS_OUT)
		else: screen.resized.emit()
		var stopped: Vector2i = screen.game.position()
		await _settle(screen)
		_check(screen.game.position() == stopped and screen.click_route.is_empty(), interruption + " cancels click route")
		screen._close_overlay()
		if screen.board.overview: screen._toggle_overview()
		await create_timer(0.25).timeout
		_check(screen.game.position() == stopped, interruption + " cannot resume old route")
	for kind in ["enemy", "door", "up", "down"]:
		_reset_corridor(screen)
		screen.game.floor_data().entities["7,5"] = {"type":kind,"name":"测试目标","enemy_id":"slime","key_type":"copper","cost":1,"pos":[7,5]}
		var hp: int = screen.game.state.player.hp
		var keys: int = screen.game.state.player.get("keys",0)
		screen._select_cell(Vector2i(7,5))
		await _settle(screen)
		_check(screen.game.position() == Vector2i(6,5), kind + " stops before target")
		_check(not screen.game.state.pending.is_empty() and screen.game.state.player.hp == hp and screen.game.state.player.get("keys",0) == keys, kind + " preserves confirmation and cost")
		_check(screen.click_route.is_empty(), kind + " clears old route")
	_reset_corridor(screen)
	screen._select_cell(Vector2i(8,5))
	screen._select_cell(Vector2i(5,6))
	await _settle(screen)
	_check(screen.game.position() == Vector2i(5,6), "mid-stride retarget lands then follows newest path")
	_reset_corridor(screen)
	screen.game.floor_data().rows[5] = "#.....#...#"
	screen._select_cell(Vector2i(7,5))
	await _settle(screen)
	_check(screen.game.position() == Vector2i(7,5), "distant floor route detours around wall")
	_reset_corridor(screen)
	for y in range(1,10): screen.game.floor_data().rows[y] = "#.....#...#"
	screen._select_cell(Vector2i(7,5))
	await _settle(screen)
	_check(screen.game.position() == Vector2i(5,5) and screen.notice.contains("不可达"), "unreachable target never moves")
	for stairs in ["up", "down"]:
		for first_stop in ["shop", "rest"]:
			_reset_corridor(screen)
			for y in range(1,10): screen.game.floor_data().rows[y] = "###########"
			screen.game.floor_data().rows[5] = "#.........#"
			var second_stop := "rest" if first_stop == "shop" else "shop"
			for entry in [[7,first_stop],[8,second_stop],[9,stairs]]:
				var x: int = entry[0]
				screen.game.floor_data().entities["%d,5" % x] = {"type":entry[1],"name":"路线交互","pos":[x,5],"offers":[],"used":false,"purchased":false}
			var hp: int = screen.game.state.player.hp
			var gold: int = screen.game.state.player.gold
			var floor_number: int = screen.game.state.floor
			screen.board.map = {}
			screen._refresh_map()
			screen._select_cell(Vector2i(9,5))
			await _settle(screen)
			_check(screen.game.position() == Vector2i(7,5), stairs + " walks onto first " + first_stop)
			_check(screen.game.state.pending.get("kind", "") == "entity" and screen.game.pending_cell() == Vector2i(7,5), stairs + " opens first " + first_stop)
			_check(screen.click_route.is_empty() and screen.game.state.floor == floor_number and screen.game.state.player.hp == hp and screen.game.state.player.gold == gold, "stair stop clears route without spending or traveling")
			screen.game.cancel_pending()
			screen._close_overlay()
			await create_timer(0.25).timeout
			_check(screen.game.position() == Vector2i(7,5), "closing interaction does not resume stair route")
			screen._select_cell(Vector2i(9,5))
			await _settle(screen)
			_check(screen.game.position() == Vector2i(8,5) and screen.game.pending_cell() == Vector2i(8,5), "next stair click reaches second " + second_stop)
	for blocker in ["enemy", "door"]:
		_reset_corridor(screen)
		for y in range(1,10): screen.game.floor_data().rows[y] = "###########"
		screen.game.floor_data().rows[5] = "#.........#"
		screen.game.floor_data().entities["6,5"] = {"type":"shop","pos":[6,5]}
		screen.game.floor_data().entities["7,5"] = {"type":blocker,"pos":[7,5],"enemy_id":"slime","key_type":"copper","cost":1}
		screen.game.floor_data().entities["9,5"] = {"type":"up","pos":[9,5]}
		screen._select_cell(Vector2i(9,5))
		await _settle(screen)
		_check(screen.game.position() == Vector2i(5,5) and screen.game.state.pending.is_empty(), "stair fallback still respects " + blocker)
