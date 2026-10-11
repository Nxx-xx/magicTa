extends "res://tests/phase3_ui_host_test_runner.gd"
const Ruins = preload("res://scripts/core/phase3_ruins.gd")
const Items = preload("res://scripts/core/phase3_items.gd")
const CAPTURE_DIR := "res://build/verification/art-polish-d/regression/action-choices/"

func _snap(label: String) -> void:
	if not capture: return
	await RenderingServer.frame_post_draw
	_check(root.get_texture().get_image().save_png(CAPTURE_DIR + label + ".png") == OK, "capture " + label)

func _fits(panel: Control, label: String) -> void:
	_check(panel.get_global_rect().end.y <= ui.overlay_close.global_position.y + 1, label + " content above exit")
	_check(ui.overlay_close.get_global_rect().end.y <= ui.size.y, label + " exit on screen")
	_check(not ui.scroll.get_v_scroll_bar().visible and not ui.scroll.get_h_scroll_bar().visible, label + " no scrollbars")
	_check(panel.get_combined_minimum_size().y <= panel.size.y + 1, label + " minimum height fits")
	for button in panel.find_children("*", "Button", true, false):
		if not button.is_visible_in_tree(): continue
		_check(button.get_global_rect().end.x <= ui.size.x and button.get_global_rect().end.y <= ui.overlay_close.global_position.y, label + " visible button fits")

func _run() -> void:
	if not ProjectSettings.globalize_path("user://").replace("\\", "/").contains("phase3/08-parallel/art-polish-d/"):
		quit(2)
		return
	capture = "--capture" in OS.get_cmdline_user_args()
	DirAccess.make_dir_recursive_absolute(CAPTURE_DIR)
	root.min_size = Vector2i(320, 600)
	for dimensions in [Vector2i(320,600), Vector2i(360,640), Vector2i(540,960), Vector2i(412,820), Vector2i(900,960)]:
		root.size = dimensions
		ui = Screen.new()
		ui.game = Core.new("user://choices_%d.json" % dimensions.x)
		ui.game.persistence_enabled = false
		root.add_child(ui)
		ui.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
		await _frames()
		ui.settings.muted = true
		ui.settings.reduce_motion = true
		ui._start_phase3("42")
		while not ui._story_event().is_empty(): ui._finish_story()
		var cell: Vector2i = ui.game.position()
		for ruin_id in Ruins.IDS:
			var entity := {"id":"ui-ruin", "type":"event", "name":"遗迹", "pos":[cell.x,cell.y], "ruin_id":ruin_id, "status":"available", "selected_option":""}
			ui.game.floor_data().entities[Core.cell_key(cell)] = entity
			ui.game.state.pending = {"kind":"entity", "pos":[cell.x,cell.y]}
			ui.game.state.player.hp = 71
			ui.game.state.player.gold = 207
			ui._render(true)
			await _frames()
			var panel = ui.find_child("Phase3Ruin", true, false)
			_check(panel != null, "ruin panel mounted")
			if panel == null: continue
			_fits(panel, str(dimensions) + ruin_id)
			_check(panel._buttons.size() == 3 and not panel.leave_button().visible, "three icons and only one host exit")
			await _snap("%s_overview_%d" % [ruin_id, dimensions.x])
			var original: Dictionary = ui.game.state.duplicate(true)
			var first_id: String = panel._buttons.keys()[0]
			var icon_position: Vector2 = panel.option_button(first_id).global_position + Vector2(28, 34)
			for pressed in [true, false]:
				var click := InputEventMouseButton.new()
				click.button_index = MOUSE_BUTTON_LEFT
				click.pressed = pressed
				click.position = icon_position
				root.push_input(click)
			await _frames()
			_check(panel._selected == first_id, "click on icon opens details through actual input")
			panel.show_overview()
			await _frames()
			for id in panel._buttons.keys():
				panel.option_button(id).pressed.emit()
				await _frames()
				_check(Contract.same_json(original, ui.game.state), "inspection never mutates resources")
				_fits(panel, id + " detail")
				_check("".join(panel._pages) == panel._full_text, "all detail text retained across pages")
				_check(panel._detail.get_line_count() * panel._detail.get_line_height() <= panel._detail.get_parent().size.y + 2, "detail text fits")
				await _snap("%s_%s_detail_%d" % [ruin_id, id, dimensions.x])
				panel._action.pressed.emit()
				await _frames()
				_check(ui.modal_open and Contract.same_json(original, ui.game.state), "explicit selection opens confirmation without spending")
				for child in ui.get_children():
					if child is ConfirmationDialog: child.canceled.emit()
				panel.show_overview()
				await _frames()
			panel._show_detail("__intro")
			await _frames()
			_check("".join(panel._pages) == panel._intro, "lore remains available without scroll")
			_fits(panel, "lore")
			panel.show_overview()
			# Long discovered comparisons are paged; no text is silently cut off.
			panel._entries[0].detail = "完整说明。永久上限变化不会治疗，选择前查看最终数值。\n".repeat(100)
			panel._show_detail(str(panel._entries[0].id))
			await _frames()
			_check(panel._pages.size() > 1 and "".join(panel._pages) == panel._full_text, "long detail pagination preserves text")
			while not panel._next.disabled: panel._next.pressed.emit()
			_check(panel._text_page == panel._pages.size() - 1, "last detail page reachable")
			ui._close_overlay()
			_check(ui.game.entity_at(cell).status == "available", "leave keeps ruin available")
		# Unavailable entries still explain why; their commit control stays disabled.
		ui.game.state.player.hp = 1
		ui.game.state.player.gold = 0
		ui.game.floor_data().entities[Core.cell_key(cell)].ruin_id = "p3_oath_ruin"
		ui.game.state.pending = {"kind":"entity", "pos":[cell.x,cell.y]}
		ui._render(true)
		var unavailable = ui.find_child("Phase3Ruin", true, false)
		unavailable.option_button("edge").pressed.emit()
		await _frames()
		_check(unavailable._action.disabled and unavailable._full_text.contains("生命"), "unavailable cost explained")
		# Shared shop and reward screens keep every option reachable.
		for kind in ["shop", "choice", "event", "rest"]:
			var fixture := {"id":"ui-reward", "type":kind, "name":"烛火商人" if kind == "shop" else "选择奖励", "pos":[cell.x,cell.y],
				"offers":["buy_steel","buy_plate","buy_potion"], "choices":["blood_sword","stone_heart"], "gold":25, "event_id":"altar",
				"options":ui.game.generator.reward_config.rest_options.duplicate(true)}
			ui.game.floor_data().entities[Core.cell_key(cell)] = fixture
			ui.game.state.player.hp = 71
			ui.game.state.player.gold = 207
			ui.game.state.pending = {"kind":"entity", "pos":[cell.x,cell.y]}
			ui._render(true)
			await _frames()
			var panel = ui.find_child("RewardChoices", true, false)
			_fits(panel, kind + " overview")
			await _snap("%s_overview_%d" % [kind, dimensions.x])
			var original: Dictionary = ui.game.state.duplicate(true)
			panel.option_button("0").pressed.emit()
			await _frames()
			_fits(panel, kind + " details")
			_check(Contract.same_json(original, ui.game.state), "reward inspection never spends")
			await _snap("%s_detail_%d" % [kind, dimensions.x])
			panel._action.pressed.emit()
			await _frames()
			_check(not Contract.same_json(original, ui.game.state), "explicit reward action settles")
			if kind == "shop":
				panel = ui.find_child("RewardChoices", true, false)
				panel.option_button("0").pressed.emit()
				await _frames()
				_check(panel._action.disabled, "sold offer inspectable but cannot buy twice")
		root.remove_child(ui)
		ui.queue_free()
		await _frames()
	print("ACTION_CHOICES checks=%d failures=%d" % [checks, failures])
	quit(1 if failures else 0)


