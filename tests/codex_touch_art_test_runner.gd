extends "res://tests/challenge_touch_test_runner.gd"
## Exercise the production catalog with real mouse/touch popup input.
const OUTPUT := "res://build/verification/codex-touch/"
var pointer_mode := "combined"

func _pointer_event(position: Vector2, pressed: bool) -> void:
	if pointer_mode != "touch":
		var mouse := InputEventMouseButton.new()
		mouse.button_index = MOUSE_BUTTON_LEFT
		mouse.pressed = pressed
		mouse.position = position
		Input.parse_input_event(mouse)
	if pointer_mode != "mouse":
		var touch := InputEventScreenTouch.new()
		touch.index = 0
		touch.pressed = pressed
		touch.position = position
		Input.parse_input_event(touch)

func _snapshot(label: String) -> void:
	if not capture: return
	await RenderingServer.frame_post_draw
	_check(root.get_texture().get_image().save_png(OUTPUT + label + ".png") == OK, "capture " + label)

func _run() -> void:
	if not ProjectSettings.globalize_path("user://").replace("\\", "/").contains("verification/codex-touch/"):
		quit(2)
		return
	DirAccess.make_dir_recursive_absolute(OUTPUT)
	capture = "--capture" in OS.get_cmdline_user_args()
	root.gui_embed_subwindows = true
	root.min_size = Vector2i(320,600)
	for dimensions in [Vector2i(320,600), Vector2i(390,844), Vector2i(540,960)]:
		root.size = dimensions
		root.content_scale_size = dimensions
		ui = Screen.new()
		ui.game = Core.new("user://codex_%d.json" % dimensions.x)
		ui.game.persistence_enabled = false
		root.add_child(ui)
		ui.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
		await _frames()
		ui.settings.muted = true
		ui.settings.reduce_motion = true
		ui._start_phase3("42")
		await _frames()
		for color_name in ["font_color", "font_hover_color", "font_pressed_color", "font_focus_color"]:
			_check(ui.overlay_next.get_theme_color(color_name).get_luminance() > 0.7, "continue stays readable: " + color_name)
		await _snapshot("story_%d" % dimensions.x)
		while not ui._story_event().is_empty(): ui._finish_story()
		_check(not ui.overlay_next.has_theme_color_override("font_focus_color"), "story restores ordinary button colors")
		for category in ["enemies", "items"]:
			ui.game.meta.codex["seen_" + category] = ui.game.db.data[category].keys()
		ui.game.meta.codex.seen_ruins = preload("res://scripts/core/phase3_ruins.gd").definitions().keys()
		ui._open_section("codex")
		await _frames()
		var panel = ui.body.get_child(0)
		var original: Dictionary = ui.game.meta.duplicate(true)
		for category in ["enemies", "ruins"]:
			panel.show_category(category)
			await _frames()
			var fingerprints := {}
			for entry in panel._entries:
				var texture: Texture2D = entry.get("preview_texture")
				_check(texture != null, category + " entry has game art: " + str(entry.name))
				if texture != null: fingerprints[hash(texture.get_image().get_data())] = true
			_check(fingerprints.size() == panel._entries.size(), category + " entries have distinct art")
			await _snapshot("%s_%d" % [category, dimensions.x])
			await _click(panel.option_button("0"))
			_check(panel.find_child("DetailPicture", true, false) != null, category + " detail preserves game art")
			panel.show_overview()
			await _frames()
		for mode in ["mouse", "touch", "combined"]:
			pointer_mode = mode
			for index in panel.categories.size():
				var widget: OptionButton = panel.find_child("CatalogCategory", true, false)
				await _click(widget)
				var popup := widget.get_popup()
				_check(popup.visible, mode + " opens category popup")
				_check(Rect2(Vector2.ZERO, Vector2(dimensions)).encloses(Rect2(Vector2(popup.position), Vector2(popup.size))), "category popup fits phone")
				if mode == "combined" and index == 0: await _snapshot("popup_%d" % dimensions.x)
				await create_timer(0.25).timeout
				var line_height := popup.get_theme_font("font").get_height(popup.get_theme_font_size("font_size")) + popup.get_theme_constant("v_separation")
				var top := popup.get_theme_stylebox("panel").get_content_margin(SIDE_TOP)
				var position := Vector2(popup.position) + Vector2(popup.size.x / 2.0, top + line_height * (index + 0.5))
				var motion := InputEventMouseMotion.new()
				motion.position = position
				Input.parse_input_event(motion)
				for pressed in [true, false]:
					_pointer_event(position, pressed)
					await process_frame
				await _frames()
				_check(panel.category_index == index, mode + " selects category " + str(index))
				_check(panel._list_page == 0, "category switch resets pagination")
		_check(Contract.same_json(original, ui.game.meta), "browsing codex never changes discoveries")
		root.remove_child(ui)
		ui.free()
	print("Codex touch/art: %d checks, %d failures" % [checks, failures])
	quit(1 if failures else 0)
