extends SceneTree
## M1-specific fixture and real-render capture. Does not overwrite the M0 baseline runner.
## Run with -- --capture using a graphical renderer to write PNGs.
const Screen = preload("res://tests/legacy_map_screen_fixture.gd")
# Keep this legacy save-layout suite on its original trial transaction rules.
class Core extends "res://scripts/core/map_engine.gd":
	var meta: Dictionary = {"runs": 0}
var checks := 0
var failures := 0
var capturing := false

func _initialize() -> void:
	_run.call_deferred()

func _check(value: bool, label: String) -> void:
	checks += 1
	if not value:
		failures += 1
		push_error("FAIL: " + label)

func _frames() -> void:
	for frame in 6:
		await process_frame

func _capture(label: String) -> void:
	if not capturing:
		return
	await RenderingServer.frame_post_draw
	var path := ProjectSettings.globalize_path("res://").path_join("build/verification/m1")
	DirAccess.make_dir_recursive_absolute(path)
	_check(root.get_texture().get_image().save_png(path.path_join(label + ".png")) == OK, "capture " + label)

func _error_visible(screen, label: String) -> void:
	_check(screen.save_error_panel.is_visible_in_tree() and screen.save_error_label.text == screen.game.save_error, "persistent error text " + label)
	_check(screen.save_error_panel.get_index() > screen.overlay.get_index(), "error drawn above sheet " + label)
	_check(screen.save_error_panel.get_global_rect().end.y <= screen.board.position.y, "error does not overlap map " + label)
	_check(screen.save_error_panel.get_global_rect().end.y <= screen.overlay_panel.position.y, "error does not overlap sheet " + label)
	_check(screen.save_error_label.size.x <= screen.save_error_scroll.size.x, "error wraps without horizontal overflow " + label)
	_check(screen.board.size.x >= 180 and screen.board.size.y >= 180, "map viewport retained " + label)
	_check(screen.controls.get_global_rect().end.y <= screen.size.y, "error leaves controls on screen " + label)
	if screen.overlay.visible and screen.overlay_close.visible:
		_check(screen.overlay_close.get_global_rect().end.y <= screen.size.y, "error leaves cancel on screen " + label)

func _keyboard(keycode: int, shift: bool = false) -> void:
	var event := InputEventKey.new()
	event.keycode = keycode
	event.physical_keycode = keycode
	event.shift_pressed = shift
	event.pressed = true
	# Send through Godot's input pipeline, including GUI Tab traversal, not screen._input.
	Input.parse_input_event(event)
	await process_frame
	event = event.duplicate()
	event.pressed = false
	Input.parse_input_event(event)
	await _frames()

func _focus_regression(screen) -> void:
	root.size = Vector2i(360, 640)
	screen.game.persistence_enabled = false
	screen._start("42")
	await _frames()
	for kind in ["target", "inventory", "pending"]:
		screen.overview_button.grab_focus()
		if kind == "pending":
			var cell: Vector2i = screen.game.position() + Vector2i.DOWN
			screen.game.floor_data().entities[Core.cell_key(cell)] = {"type": "enemy", "name": "史莱姆", "enemy_id": "slime", "pos": [cell.x, cell.y]}
			screen.game.interact(cell)
			screen._render(true)
		else:
			screen._open_overlay(kind)
		await _frames()
		for region in [screen.hud, screen.detail_panel, screen.controls]:
			for button in region.find_children("*", "Button", true, false):
				_check(button.disabled and button.focus_mode == Control.FOCUS_NONE, "background excluded from focus " + kind + ": " + button.text)
		for step in 8:
			await _keyboard(KEY_TAB, step >= 4)
			var focused: Control = root.gui_get_focus_owner()
			_check(is_instance_valid(focused) and screen.overlay.is_ancestor_of(focused), "real Tab stays in sheet " + kind + " step %d" % step)
		await _keyboard(KEY_ESCAPE)
		_check(not screen.overlay.visible and screen.game.state.pending.is_empty(), "real Escape closes sheet " + kind)
		_check(screen.overview_button.has_focus() and screen.overview_button.focus_mode == Control.FOCUS_ALL, "Escape restores initiating focus " + kind)
		await _keyboard(KEY_TAB)
		var focused: Control = root.gui_get_focus_owner()
		_check(is_instance_valid(focused) and not screen.overlay.is_ancestor_of(focused), "map Tab resumes after close " + kind)

func _save_error_regression(screen) -> void:
	# A directory at the temporary-file path causes a real FileAccess WRITE failure.
	# All paths remain in this runner's isolated user:// verification environment.
	var failed_path := "user://m1_save_failure_%d.json" % OS.get_process_id()
	_check(DirAccess.make_dir_recursive_absolute(ProjectSettings.globalize_path(failed_path + ".tmp")) == OK, "create isolated unwritable file target")
	for dimensions in [Vector2i(540, 960), Vector2i(360, 640)]:
		root.size = dimensions
		screen.game.persistence_enabled = false
		screen._start("42")
		screen.game.save_error = ""
		screen._render(true)
		await _frames()
		var normal_board: Rect2 = screen.board.get_global_rect()
		var normal_sheet: Rect2 = screen.overlay_panel.get_global_rect()
		var suffix := "%dx%d" % [dimensions.x, dimensions.y]
		screen.game.store.path = failed_path
		screen.game.persistence_enabled = true
		# Exercise the background-autosave path; do not call _render to expose the error.
		screen._notification(MainLoop.NOTIFICATION_APPLICATION_FOCUS_OUT)
		await _frames()
		_check(not screen.game.save_error.is_empty() and not FileAccess.file_exists(failed_path), "real write failure " + suffix)
		_error_visible(screen, "explore " + suffix)
		await _capture("save_error_explore_" + suffix)
		var cell: Vector2i = screen.game.position() + Vector2i.DOWN
		screen.game.floor_data().entities[Core.cell_key(cell)] = {"type": "enemy", "name": "史莱姆", "enemy_id": "slime", "pos": [cell.x, cell.y]}
		screen.selected = cell
		screen._render(true)
		await _frames()
		_error_visible(screen, "selected enemy " + suffix)
		_check(screen.detail_copy.text.contains("攻击"), "save error does not replace enemy attributes " + suffix)
		await _capture("save_error_selected_" + suffix)
		screen._open_overlay("target")
		await _frames()
		_error_visible(screen, "target details " + suffix)
		await _capture("save_error_details_" + suffix)
		screen._close_overlay()
		screen.game.interact(cell)
		screen._render(true)
		await _frames()
		_error_visible(screen, "pending " + suffix)
		await _capture("save_error_pending_" + suffix)
		screen._close_overlay()
		screen._open_overlay("inventory")
		await _frames()
		_error_visible(screen, "inventory " + suffix)
		await _capture("save_error_inventory_" + suffix)
		# Supplemental long-message layout fixture; the earlier cases use unmodified engine errors.
		var actual_error: String = screen.game.save_error
		screen.game.save_error = actual_error + "\n" + "详细诊断：临时存档无法创建，请检查目标目录的可写权限。".repeat(8)
		screen._render()
		await _frames()
		_error_visible(screen, "long error " + suffix)
		_check(screen.save_error_scroll.get_v_scroll_bar().max_value > screen.save_error_scroll.size.y, "long error scrolls locally " + suffix)
		await _capture("save_error_long_" + suffix)
		screen.save_error_scroll.scroll_vertical = int(screen.save_error_scroll.get_v_scroll_bar().max_value)
		await _frames()
		_check(screen.save_error_scroll.scroll_vertical > 0, "long diagnostics remain reachable " + suffix)
		screen._close_overlay()
		screen.game.state.player.hp = 1
		screen.game.floor_data().entities[Core.cell_key(cell)].enemy_id = "knight"
		screen.game.interact(cell)
		screen._act(func(): return screen.game.confirm_interaction(true))
		await _frames()
		_check(screen.overlay_kind == "result", "failed save does not change death result " + suffix)
		_error_visible(screen, "result " + suffix)
		await _capture("save_error_result_" + suffix)
		# A successful real write clears the engine error, including while a sheet is open.
		var recovered_path := "user://m1_save_recovered_%d_%s.json" % [OS.get_process_id(), suffix]
		screen.game.store.path = recovered_path
		screen._notification(MainLoop.NOTIFICATION_APPLICATION_FOCUS_OUT)
		await _frames()
		_check(FileAccess.file_exists(recovered_path) and screen.game.save_error.is_empty(), "real recovery writes file " + suffix)
		_check(not screen.save_error_panel.visible and screen.save_error_label.text.is_empty(), "recovery removes stale error " + suffix)
		_check(screen.board.get_global_rect() == normal_board and screen.overlay_panel.get_global_rect() == normal_sheet, "error clear restores layout " + suffix)
		_check(not screen.detail_title.text.contains("保存成功") and not screen.detail_hint.text.contains("保存成功"), "no invented save-success message " + suffix)
		await _capture("save_error_cleared_" + suffix)
		screen.game.persistence_enabled = false

func _run() -> void:
	capturing = OS.get_cmdline_user_args().has("--capture")
	root.min_size = Vector2i.ZERO
	var screen = Screen.new()
	screen.game = Core.new("user://m1_fixture.json")
	screen.game.persistence_enabled = false
	root.add_child(screen)
	screen.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	for dimensions in [Vector2i(540, 960), Vector2i(360, 640), Vector2i(900, 960), Vector2i(320, 640)]:
		root.size = dimensions
		screen._start("42")
		await _frames()
		var suffix := "%dx%d" % [dimensions.x, dimensions.y]
		print("LAYOUT ", suffix, " hud=", screen.hud.get_global_rect(), " board=", screen.board.get_global_rect(), " detail=", screen.detail_panel.get_global_rect(), " controls=", screen.controls.get_global_rect())
		_check(screen.board.size.y >= screen.size.y * 0.65, "map fills available height " + suffix)
		_check(screen.board.get_global_rect().encloses(screen.detail_panel.get_global_rect()), "summary floats within map " + suffix)
		_check(screen.hud.get_global_rect().end.y <= screen.board.position.y, "HUD clear of map " + suffix)
		_check(screen.detail_panel.get_global_rect().end.y <= screen.controls.position.y, "details clear of controls " + suffix)
		_check(screen.controls.get_global_rect().end.y <= screen.size.y, "controls within screen " + suffix)
		_check(not screen.overlay.visible, "exploration has no overlay " + suffix)
		await _capture("explore_" + suffix)
		var board_id: int = screen.board.get_instance_id()
		var control_id: int = screen.overview_button.get_instance_id()
		screen.overview_button.grab_focus()
		screen._act(func(): return screen.game.step(Vector2i.ZERO))
		await _frames()
		_check(board_id == screen.board.get_instance_id() and control_id == screen.overview_button.get_instance_id(), "stable map and controls " + suffix)
		_check(screen.overview_button.has_focus(), "focus survives refresh " + suffix)
		# Controlled adjacent fixture: keep both the player and monster visible in captures.
		var cell: Vector2i = screen.game.position() + Vector2i.DOWN
		screen.game.floor_data().entities[Core.cell_key(cell)] = {"type": "enemy", "name": "史莱姆", "enemy_id": "slime", "pos": [cell.x, cell.y]}
		screen.selected = cell
		screen._render(true)
		await _frames()
		await _capture("selected_monster_" + suffix)
		screen.game.interact(cell)
		screen._render(true)
		await _frames()
		_check(screen.overlay.visible and screen.overlay_kind == "pending", "interaction opens bounded sheet " + suffix)
		_check(screen.body.size.x <= screen.scroll.size.x, "sheet has no horizontal overflow " + suffix)
		_check(screen.overlay_close.get_global_rect().end.y < screen.size.y, "cancel remains visible " + suffix)
		var original: Vector2i = screen.game.position()
		var selection: Vector2i = screen.selected
		screen._select_cell(cell + Vector2i.RIGHT)
		var key := InputEventKey.new()
		key.keycode = KEY_RIGHT
		key.pressed = true
		screen._input(key)
		_check(screen.selected == selection and screen.game.position() == original, "sheet blocks board and keyboard " + suffix)
		await _capture("monster_preview_" + suffix)
		screen._close_overlay()
		_check(screen.game.state.pending.is_empty() and not screen.overlay.visible, "cancel releases input " + suffix)
		screen.game.floor_data().entities[Core.cell_key(cell)].enemy_id = "knight"
		screen.game.floor_data().entities[Core.cell_key(cell)].guardian = true
		screen._render(true)
		await _frames()
		_check(screen.detail_copy.text.contains("攻击") and not screen.detail_copy.text.contains("会死亡"), "enemy facts without outcome " + suffix)
		await _capture("lethal_selected_" + suffix)
		screen.game.interact(cell)
		screen._render(true)
		await _frames()
		await _capture("lethal_preview_" + suffix)
		var hp_before: int = screen.game.state.player.hp
		screen._close_overlay()
		await _frames()
		_check(not screen.modal_open and screen.game.active() and screen.game.state.player.hp == hp_before, "leaving encounter preserves health " + suffix)
		screen._open_overlay("inventory")
		_check(not screen._can_walk(), "inventory blocks movement " + suffix)
		screen._close_overlay()
		_check(screen._can_walk(), "inventory close restores movement " + suffix)
	# Confirm through the real button signal. A stale double activation must not pay twice.
	screen._start("42")
	var cell: Vector2i = screen.game.position()
	screen.game.floor_data().entities[Core.cell_key(cell)] = {"type": "enemy", "name": "史莱姆", "enemy_id": "slime", "pos": [cell.x, cell.y]}
	screen.game.interact(cell)
	screen._render(true)
	await _frames()
	var expected: Dictionary = screen.game.preview(cell)
	var before_gold: int = screen.game.state.player.gold
	for button in screen.body.find_children("*", "Button", true, false):
		if button.text == "确认挑战":
			button.pressed.emit()
			button.pressed.emit()
			break
	_check(screen.game.state.player.gold == before_gold + int(expected.gold_reward), "double activation grants combat reward once")
	_check(screen.game.state.player.hp == expected.hp_after and screen.game.state.pending.is_empty(), "button uses exact combat preview")
	_check(not screen.overlay.visible and is_instance_valid(screen.combat_view), "successful fight opens combat presentation")
	screen.combat_view.settle()
	screen.combat_view.primary.pressed.emit()
	_check(screen.overlay_kind == "", "continue returns to map")
	screen.game.state.player.hp = 1
	screen.game.floor_data().entities[Core.cell_key(cell)] = {"type": "enemy", "name": "骑士", "enemy_id": "knight", "pos": [cell.x, cell.y]}
	screen.game.interact(cell)
	screen._render(true)
	screen._fight()
	screen.combat_view.settle()
	screen.combat_view.primary.pressed.emit()
	_check(not screen.modal_open and not screen.game.active() and screen.overlay_kind == "result", "one challenge confirmation resolves defeat without prediction")
	screen._start("42")
	_check(screen.game.active() and not screen.overlay.visible, "restart clears result sheet")
	screen.page = "menu"
	screen._render(true)
	await _frames()
	screen._open_map()
	await _frames()
	_check(screen.game.active() and is_instance_valid(screen.board), "menu continue rebuilds usable map shell")
	await _focus_regression(screen)
	await _save_error_regression(screen)
	root.remove_child(screen)
	screen.free()
	print("M1 UI tests: %d checks, %d failures" % [checks, failures])
	quit(1 if failures else 0)
