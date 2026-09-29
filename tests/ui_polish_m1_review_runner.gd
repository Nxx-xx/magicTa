extends SceneTree
## Independent M1 review. Deliberate failures remain failures; no product fixes.
## -- --write-saves / -- --read-saves run in separate Godot processes.
const Screen = preload("res://scripts/ui/map_screen.gd")
const Core = preload("res://scripts/core/map_engine.gd")
var checks := 0
var failures := 0
var records: Array = []
var evidence_prefix := ""

func _initialize() -> void:
	_run.call_deferred()

func _path(file: String) -> String:
	return ProjectSettings.globalize_path("res://").path_join("build/verification/m1_review").path_join(file)

func _check(value: bool, label: String) -> void:
	checks += 1
	records.append({"check": label, "passed": value})
	print("PASS " + label if value else "FAIL " + label)
	if not value:
		failures += 1

func _frames() -> void:
	for frame in 8:
		await process_frame

func _button(node: Node, text: String) -> Button:
	for child in node.get_children():
		if child is Button and child.text.contains(text):
			return child
		var found := _button(child, text)
		if found != null:
			return found
	return null

func _rect(control: Control) -> Array:
	var bounds := control.get_global_rect()
	return [bounds.position.x, bounds.position.y, bounds.size.x, bounds.size.y]

func _capture(screen, name: String) -> void:
	name = evidence_prefix + name
	await _frames()
	await RenderingServer.frame_post_draw
	var result := root.get_texture().get_image().save_png(_path("screenshots/" + name + ".png"))
	_check(result == OK, "capture " + name)
	var entry := {"sample": name, "window": str(root.size), "viewport": str(root.get_visible_rect()), "scale_mode": root.content_scale_mode, "scale_size": str(root.content_scale_size)}
	if screen.get_script() == Screen and is_instance_valid(screen.map_root):
		entry.merge({"title": screen.detail_title.text, "title_lines": screen.detail_title.get_line_count(), "title_visible_lines": screen.detail_title.get_visible_line_count(), "title_rect": _rect(screen.detail_title), "title_font_size": screen.detail_title.get_theme_font_size("font_size"), "detail_rect": _rect(screen.detail_panel), "board_rect": _rect(screen.board), "controls_rect": _rect(screen.controls), "button_rect": _rect(screen.direction_buttons[0]), "overlay": screen.overlay_kind, "save_error": screen.game.save_error})
	records.append(entry)

func _new_screen(path: String, persistent: bool = false):
	var screen = Screen.new()
	screen.game = Core.new(path)
	screen.game.persistence_enabled = persistent
	root.add_child(screen)
	screen.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	return screen

func _dispose(screen) -> void:
	# Free while still attached: exercise the production _exit_tree hook.
	screen.queue_free()
	await _frames()

func _fixture(screen, entity: Dictionary) -> Vector2i:
	var cell: Vector2i = screen.game.position()
	entity.pos = [cell.x, cell.y]
	entity.name = entity.get("name", "review fixture")
	screen.game.floor_data().entities[Core.cell_key(cell)] = entity
	screen.game.state.pending = {}
	screen.selected = cell
	return cell

func _key(code: int, reverse: bool = false) -> void:
	var event := InputEventKey.new()
	event.keycode = code
	event.physical_keycode = code
	event.shift_pressed = reverse
	event.pressed = true
	root.push_input(event)
	await _frames()
	event = event.duplicate()
	event.pressed = false
	root.push_input(event)
	await _frames()

func _focus_record(label: String) -> void:
	var owner := root.gui_get_focus_owner()
	var entry := {"focus_sample": label, "owner": str(owner.get_path()) if owner != null else "null"}
	if owner is Button:
		entry["text"] = owner.text
		entry["disabled"] = owner.disabled
		entry["visible"] = owner.is_visible_in_tree()
	records.append(entry)
	print("FOCUS ", JSON.stringify(entry))

func _layout_and_focus() -> void:
	root.size = Vector2i(360, 640)
	var screen = _new_screen("user://review_layout.json")
	screen._start("42")
	await _capture(screen, "360_explore")
	_check(root.get_visible_rect().size == Vector2(360, 640), "minimum window uses physical pixels")
	_check(screen.direction_buttons[0].size.y >= 44, "minimum direction target at least 44px")
	# Actual seed-42 monster; no entity or attributes changed.
	for entity in screen.game.floor_data().entities.values():
		if entity.get("enemy_id", "") == "skeleton":
			screen._select_cell(Vector2i(entity.pos[0], entity.pos[1]))
	await _capture(screen, "360_natural_skeleton")
	_check(screen.detail_title.get_line_count() <= screen.detail_title.max_lines_visible, "natural monster full summary fits two visible lines")
	for enemy in screen.game.db.data.enemies.values():
		if enemy.rank != "normal":
			continue
		_fixture(screen, {"type": "enemy", "enemy_id": enemy.id})
		screen._render(true)
		await _capture(screen, "360_summary_" + str(enemy.id))
		_check(screen.detail_title.get_line_count() <= 2, "two-line summary not clipped: " + str(enemy.id))
	# Use routed key events, not direct calls to _input, to include GUI focus.
	screen.detail_button.grab_focus()
	await _key(KEY_ENTER)
	_check(screen.overlay_kind == "target" and screen.overlay_close.has_focus(), "Enter opens details and focuses visible close")
	var position: Vector2i = screen.game.position()
	await _key(KEY_RIGHT)
	_check(screen.game.position() == position, "detail sheet blocks routed movement key")
	for index in 6:
		await _key(KEY_TAB)
		var owner := root.gui_get_focus_owner()
		_focus_record("detail_tab_" + str(index))
		_check(owner != null and screen.overlay.is_ancestor_of(owner), "detail Tab focus stays in sheet %d" % index)
	await _capture(screen, "360_detail_focus")
	await _key(KEY_ESCAPE)
	_check(not screen.overlay.visible and screen.detail_button.has_focus(), "Escape closes sheet and restores details focus")
	await _key(KEY_ENTER)
	await _key(KEY_ENTER)
	_check(not screen.overlay.visible and screen.detail_button.has_focus(), "Enter close restores details focus")
	# Pending shop has several focusable actions; Tab must scroll focused items into view.
	var cell := _fixture(screen, {"type": "shop", "offers": ["buy_steel", "buy_plate", "buy_potion"], "purchased": false})
	screen.game.state.player.gold = 100
	screen.direction_buttons[0].grab_focus()
	screen._act(func(): return screen.game.interact(cell))
	await _frames()
	_check(screen.overlay_close.has_focus(), "pending interaction focuses close")
	for index in 8:
		await _key(KEY_TAB)
		var owner := root.gui_get_focus_owner()
		_focus_record("shop_tab_" + str(index))
		_check(owner != null and screen.overlay.is_ancestor_of(owner), "shop Tab focus stays in sheet %d" % index)
	await _capture(screen, "360_shop_keyboard_focus")
	await _key(KEY_ESCAPE)
	_check(screen.game.state.pending.is_empty() and screen.direction_buttons[0].has_focus(), "pending Escape cancels and restores initiating focus")
	await _dispose(screen)

func _has_visible_error(screen) -> bool:
	for label in screen.find_children("*", "Label", true, false):
		if label.text.contains("无法写入存档") and label.is_visible_in_tree():
			if screen.overlay.visible and not screen.overlay.is_ancestor_of(label):
				# A persistent alert drawn after the sheet is above its shade.
				# The old summary was below it. Do not confuse tree membership
				# with actual occlusion when reviewing a new alert layer.
				var layer: Node = label
				while layer.get_parent() != screen.map_root and layer.get_parent() != null:
					layer = layer.get_parent()
				if layer.get_parent() != screen.map_root or layer.get_index() < screen.overlay.get_index():
					continue
			if root.get_visible_rect().encloses(label.get_global_rect()):
				var ancestor: Node = label.get_parent()
				var unclipped := true
				while ancestor != null:
					if ancestor is Control and ancestor.clip_contents and not ancestor.get_global_rect().encloses(label.get_global_rect()):
						unclipped = false
					ancestor = ancestor.get_parent()
				if unclipped:
					return true
	return false

func _final_focus() -> void:
	root.size = Vector2i(360, 640)
	var screen = _new_screen("user://review_final_focus.json")
	screen._start("42")
	_fixture(screen, {"type": "enemy", "enemy_id": "knight"})
	screen._render(true)
	await _frames()
	for kind in ["target", "shop"]:
		if kind == "target":
			screen.detail_button.grab_focus()
			await _key(KEY_ENTER)
		else:
			var cell := _fixture(screen, {"type": "shop", "offers": ["buy_steel", "buy_plate", "buy_potion"], "purchased": false})
			screen.game.state.player.gold = 100
			screen.direction_buttons[0].grab_focus()
			screen._act(func(): return screen.game.interact(cell))
			await _frames()
		_check(screen.overlay.visible and screen.overlay_close.has_focus(), str(kind) + " opening focuses visible close")
		for reverse in [false, true]:
			var direction := "shift_tab" if reverse else "tab"
			for index in 8:
				await _key(KEY_TAB, reverse)
				var owner := root.gui_get_focus_owner()
				_focus_record(str(kind) + "_" + direction + "_" + str(index))
				_check(owner != null and screen.overlay.is_ancestor_of(owner), str(kind) + " " + direction + " stays inside sheet %d" % index)
			await _capture(screen, "360_" + str(kind) + "_" + direction)
		await _key(KEY_ESCAPE)
		_check(not screen.overlay.visible and screen.game.state.pending.is_empty(), str(kind) + " Escape closes and cancels pending")
		_check(screen.detail_button.has_focus() if kind == "target" else screen.direction_buttons[0].has_focus(), str(kind) + " closing restores initiating focus")
	await _dispose(screen)

func _save_errors() -> void:
	for dimensions in [Vector2i(540, 960), Vector2i(360, 640)]:
		root.size = dimensions
		var suffix := str(dimensions.x)
		var save_path := "user://review_write_blocked_" + suffix + ".json"
		# A directory at the temporary file path deterministically prevents writing.
		DirAccess.make_dir_recursive_absolute(ProjectSettings.globalize_path(save_path + ".tmp"))
		var screen = _new_screen(save_path, true)
		screen._start("42")
		_check(not screen.game.save_error.is_empty(), suffix + " real failed write sets error")
		await _capture(screen, suffix + "_save_error_explore")
		_check(_has_visible_error(screen), suffix + " save error visible during exploration")
		var cell := _fixture(screen, {"type": "enemy", "enemy_id": "knight"})
		screen._render(true)
		await _capture(screen, suffix + "_save_error_enemy")
		_check(_has_visible_error(screen), suffix + " save error visible with selected enemy")
		screen.game.interact(cell)
		screen._render(true)
		await _capture(screen, suffix + "_save_error_pending")
		_check(_has_visible_error(screen), suffix + " save error visible during pending interaction")
		await _dispose(screen)

func _save_cases(writing: bool) -> void:
	root.size = Vector2i(360, 640)
	for kind in ["choice", "shop"]:
		var screen = _new_screen("user://review_persist_" + kind + ".json", true)
		if writing:
			screen._start("42")
			screen.game.state.player.gold = 100
			var entity: Dictionary = {"type": "choice", "choices": ["blood_sword", "stone_heart"], "gold": 25} if kind == "choice" else {"type": "shop", "offers": ["buy_steel", "buy_plate", "buy_potion"], "purchased": false}
			var cell := _fixture(screen, entity)
			screen.game.interact(cell)
			_check(screen.game.save_game(), kind + " pending save written")
			var expected := FileAccess.open(_path(kind + "_expected.json"), FileAccess.WRITE)
			expected.store_string(JSON.stringify(screen.game.state))
			expected.close()
			screen._render(true)
			await _capture(screen, kind + "_before_process_exit")
		else:
			var expected: Variant = JSON.parse_string(FileAccess.get_file_as_string(_path(kind + "_expected.json")))
			_check(JSON.parse_string(JSON.stringify(screen.game.state)) == expected, kind + " full pending state survives new process")
			screen._open_map()
			await _capture(screen, kind + "_after_process_restart")
			_check(screen.overlay_kind == "pending" and screen.overlay_close.is_visible_in_tree(), kind + " restart opens cancellable pending sheet")
			_check(screen.body.size.x <= screen.scroll.size.x, kind + " restart sheet fits narrow width")
			var before_gold: int = screen.game.state.player.gold
			var action := _button(screen.body, "选择 · 嗜血剑" if kind == "choice" else "购买 淬钢刃")
			_check(action != null and not action.disabled, kind + " restored choice actionable")
			if action != null:
				action.pressed.emit()
				await _frames()
				_check(screen.game.state.pending.is_empty(), kind + " restored transaction resolves")
				_check(screen.game.state.player.gold == before_gold + (25 if kind == "choice" else -42), kind + " restored transaction settles exact gold")
				var loaded = Core.new("user://review_persist_" + kind + ".json")
				loaded.load_game()
				_check(JSON.parse_string(JSON.stringify(loaded.state)) == JSON.parse_string(JSON.stringify(screen.game.state)), kind + " settled state saved without duplication")
		await _dispose(screen)

func _scene_cycle(suffix: String = "") -> void:
	root.size = Vector2i(360, 640)
	var original_mode := root.content_scale_mode
	var original_size := root.content_scale_size
	_check(change_scene_to_file("res://scenes/map_prototype.tscn") == OK, "load production map scene")
	await _frames()
	var screen = current_scene
	_check(root.content_scale_mode == Window.CONTENT_SCALE_MODE_DISABLED, "production map disables stretch")
	_check(_button(screen, "打开旧版十层卡片原型") == null, "retired card mode entry removed")
	screen._start("42")
	await _frames()
	var expected: String = JSON.stringify(screen.game.state)
	var camp := _button(screen.hud, "营地")
	_check(camp != null, "map exposes camp entry")
	if camp != null:
		camp.pressed.emit()
	await _frames()
	_check(screen.page == "menu", "camp opens current menu")
	var resume := _button(screen.body, "继续探索")
	_check(resume != null, "camp exposes resume entry")
	if resume != null:
		resume.pressed.emit()
	await _frames()
	_check(screen.page == "map" and JSON.stringify(screen.game.state) == expected, "resume preserves exploration state")
	await _capture(screen, "360_resumed_map" + suffix)
	await _dispose(screen)
	_check(root.content_scale_mode == original_mode and root.content_scale_size == original_size, "map exit restores original stretch")
	_check(change_scene_to_file("res://scenes/map_prototype.tscn") == OK, "reload production map scene")
	await _frames()
	_check(root.content_scale_mode == Window.CONTENT_SCALE_MODE_DISABLED, "reloaded map enables responsive viewport")
	_check(JSON.parse_string(JSON.stringify(current_scene.game.state)) == JSON.parse_string(expected), "production scene reload restores saved exploration")
	await _dispose(current_scene)
	_check(root.content_scale_mode == original_mode and root.content_scale_size == original_size, "second map exit restores original stretch")

func _run() -> void:
	if not OS.get_user_data_dir().replace("\\", "/").contains("/build/verification/m1_review/"):
		push_error("Set isolated APPDATA / LOCALAPPDATA before review")
		quit(2)
		return
	DirAccess.make_dir_recursive_absolute(_path("screenshots"))
	root.gui_embed_subwindows = true
	var arguments := OS.get_cmdline_user_args()
	var phase := "write" if arguments.has("--write-saves") else ("read" if arguments.has("--read-saves") else "review")
	if arguments.has("--scene-only"):
		phase = "scene_fixed"
	if arguments.has("--final-risks"):
		phase = "final_risks"
		evidence_prefix = "final_"
	print("M1 independent review phase=", phase, " engine=", Engine.get_version_info().string, " user_data=", OS.get_user_data_dir())
	if phase == "final_risks":
		await _final_focus()
		await _save_errors()
		await _scene_cycle()
	elif phase == "scene_fixed":
		await _scene_cycle("_fixed")
	elif phase != "review":
		await _save_cases(phase == "write")
	else:
		await _layout_and_focus()
		await _save_errors()
		await _scene_cycle()
	var output := FileAccess.open(_path(phase + "_observations.json"), FileAccess.WRITE)
	output.store_string(JSON.stringify({"checks": checks, "failures": failures, "records": records}, "\t"))
	output.close()
	print("M1 independent %s: %d checks, %d failures" % [phase, checks, failures])
	quit(1 if failures else 0)
