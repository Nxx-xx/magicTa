extends SceneTree
## Real input routing, camera transforms and floating controls in isolated user data.
const Screen = preload("res://scripts/ui/map_screen.gd")
const Core = preload("res://scripts/core/map_engine.gd")
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

func _touch(position: Vector2, pressed: bool) -> void:
	var event := InputEventScreenTouch.new()
	event.index = 0
	event.position = position
	event.pressed = pressed
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
		_check(screen.board._cell_size() >= 44, "readable exploration cells " + suffix)
		_check(not screen.detail_panel.visible, "no empty detail card " + suffix)
		_check(screen.board.get_global_rect().encloses(screen.floating_controls.get_global_rect()), "pad floats over map " + suffix)
		for button in screen.direction_buttons:
			_check(button.size.x >= 48 and button.size.y >= 48, "touch target " + suffix)
		await _capture("explore_" + suffix)
		# Use a clear corridor and real GUI events; the pad must not click through.
		screen.game.state.position = [5,5]
		screen.game.floor_data().rows[5] = "#.........#"
		screen.game.floor_data().entities.erase("4,5")
		screen.game.floor_data().entities.erase("3,5")
		screen._refresh_map()
		screen.board.recenter()
		await _frames()
		await _click(screen.direction_buttons[0].get_global_rect().get_center())
		_check(screen.game.position() == Vector2i(4,5), "pad moves exactly one cell " + suffix)
		var cell_position: Vector2 = screen.board.global_position + screen.board._origin() + Vector2(3.5,5.5) * screen.board._cell_size()
		await _click(cell_position)
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
		_check(not screen.board.following and screen.recenter_button.visible, "drag pauses following " + suffix)
		_check(screen.selected == selected_before and screen.game.position() == position_before, "drag never selects or moves " + suffix)
		await _click(screen.recenter_button.get_global_rect().get_center())
		_check(screen.board.following and not screen.recenter_button.visible, "recenter restores following " + suffix)
		var pad_center: Vector2 = screen.direction_buttons[3].get_global_rect().get_center()
		await _touch(pad_center, true)
		await _touch(pad_center, false)
		await _frames()
		_check(screen.game.position() == Vector2i(4,5), "touch pad produces exactly one step " + suffix)
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
		_check(not screen.board.following and screen.game.position() == Vector2i(4,5), "touch drag inspects without moving " + suffix)
		screen.board.recenter()
		# Follow bounds must protect the hero from the pad even at map corners.
		for corner in [Vector2i(1,1), Vector2i(9,1), Vector2i(1,9), Vector2i(9,9)]:
			screen.game.state.position = [corner.x, corner.y]
			screen._refresh_map()
			screen.board.recenter()
			await _frames()
			var hero_rect := Rect2(screen.board.global_position + screen.board._origin() + Vector2(corner) * screen.board._cell_size(), Vector2.ONE * screen.board._cell_size())
			_check(screen.board.get_global_rect().encloses(hero_rect), "hero stays visible " + suffix + str(corner))
			_check(not hero_rect.intersects(screen.floating_controls.get_global_rect()), "pad clear of hero " + suffix + str(corner))
		await _click(screen.overview_button.get_global_rect().get_center())
		_check(screen.board.overview and not screen.floating_controls.visible, "overview hides pad " + suffix)
		var map_rect := Rect2(screen.board._origin(), Vector2.ONE * screen.board._cell_size() * 11)
		_check(Rect2(Vector2.ZERO, screen.board.size).encloses(map_rect), "overview fits all 121 cells " + suffix)
		await _capture("overview_" + suffix)
		position_before = screen.game.position()
		cell_position = screen.board.global_position + screen.board._origin() + (Vector2(position_before) + Vector2(-0.5,0.5)) * screen.board._cell_size()
		await _click(cell_position)
		_check(screen.game.position() == position_before and screen.overlay_kind == "target", "overview selects without acting " + suffix)
		screen._close_overlay()
		await _frames()
		await _click(screen.overview_button.get_global_rect().get_center())
		_check(not screen.board.overview and screen.floating_controls.visible, "return to exploration " + suffix)
		screen.selected = Vector2i(8,9)
		screen.game.floor_data().entities["8,9"] = {"type":"enemy", "name":"史莱姆", "enemy_id":"slime", "pos":[8,9]}
		screen._refresh_map()
		await _frames()
		_check(screen.detail_panel.visible and screen.detail_copy.text.contains("生命") and screen.detail_copy.text.contains("攻击") and screen.detail_copy.text.contains("防御"), "enemy attributes stay visible " + suffix)
		_check(screen.detail_copy.get_global_rect().end.y <= screen.detail_panel.get_global_rect().end.y, "summary fits " + suffix)
		_check(screen.detail_title.get_visible_line_count() == 1 and screen.detail_copy.get_visible_line_count() == 1, "summary text renders a complete line " + suffix)
		await _capture("target_" + suffix)
		screen._open_overlay("inventory")
		await _frames()
		_check(not screen.floating_controls.visible, "sheet hides pad " + suffix)
		for button in screen.direction_buttons:
			_check(button.disabled and button.focus_mode == Control.FOCUS_NONE, "sheet blocks pad input and focus " + suffix)
		screen._close_overlay()
	print("MOBILE MAP: %d checks, %d failures" % [checks, failures])
	quit(0 if failures == 0 else 1)
