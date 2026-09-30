extends "res://tests/ui_polish_m1_runner.gd"
## Reuses every M1 assertion; all artifacts and user data stay in this batch.
var phase := "after"

func _fixture(screen, entity: Dictionary) -> void:
	var cell: Vector2i = screen.game.position()
	entity.pos = [cell.x, cell.y]
	screen.game.floor_data().entities[Core.cell_key(cell)] = entity
	screen.game.state.pending = {}
	screen.game.interact(cell)
	screen.selected = cell
	screen._render(true)

func _button_named(node: Node, caption: String) -> Button:
	for button in node.find_children("*", "Button", true, false):
		if button.text.contains(caption):
			return button
	return null

func _sheet_bounds(screen, label: String) -> void:
	_check(screen.body.size.x <= screen.scroll.size.x, "sheet content width " + label)
	_check(screen.overlay_panel.get_global_rect().end.y <= screen.size.y, "sheet fits " + label)
	var button_bounds := true
	for button in screen.body.find_children("*", "Button", true, false):
		button_bounds = button_bounds and button.size.y >= 44 and button.get_global_rect().end.x <= screen.size.x - 12
	_check(button_bounds, "wrapped actions fit with 44px targets " + label)
	_check(screen.overlay_close.is_visible_in_tree() and screen.overlay_close.get_global_rect().end.y <= screen.size.y, "fixed close available " + label)

func _other_panels(screen, suffix: String) -> void:
	screen._start("42")
	screen.game.state.player.hp = 80
	_fixture(screen, {"type": "potion", "name": "疗愈药剂", "amount": 45})
	await _frames()
	_sheet_bounds(screen, "potion " + suffix)
	await _capture("potion_" + suffix)
	_button_named(screen.body, "使用药剂").pressed.emit()
	await _frames()
	_check(screen.game.state.player.hp == 100 and screen.game.state.pending.is_empty(), "potion button applies exact healing " + suffix)
	_fixture(screen, {"type": "door", "name": "银门", "key_kind": "silver", "cost": 1})
	await _frames()
	_check(_button_named(screen.body, "银钥匙不足").disabled, "door explains missing matching key " + suffix)
	await _capture("door_disabled_" + suffix)
	screen._close_overlay()
	screen.game.state.pending = {"kind": "floor_choice"}
	screen._render(true)
	await _frames()
	_sheet_bounds(screen, "floor choice " + suffix)
	await _capture("floor_choice_" + suffix)
	_button_named(screen.body, "进入").pressed.emit()
	await _frames()
	_check(int(screen.game.state.floor) == 2 and not screen.overlay.visible, "theme card enters next floor " + suffix)
	screen.game.state.pending = {"kind": "stairs", "destination": 1}
	screen._render(true)
	await _frames()
	_sheet_bounds(screen, "stairs " + suffix)
	await _capture("stairs_" + suffix)
	_button_named(screen.body, "通过楼梯").pressed.emit()
	await _frames()
	_check(int(screen.game.state.floor) == 1, "stairs button returns to visited floor " + suffix)
	screen.game.state.objective_complete = true
	screen._render()
	await _frames()
	_check(screen.game.active() and not screen.direction_buttons[0].disabled, "objective completion permits continued exploration " + suffix)
	await _capture("objective_complete_" + suffix)

func _visual_states() -> void:
	root.min_size = Vector2i.ZERO
	var original_mode := root.content_scale_mode
	var original_size := root.content_scale_size
	var screen = Screen.new()
	screen.game = Core.new("user://visual_states.json")
	screen.game.persistence_enabled = false
	root.add_child(screen)
	screen.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	for dimensions in [Vector2i(320, 640), Vector2i(360, 640), Vector2i(540, 960), Vector2i(900, 960)]:
		root.size = dimensions
		var suffix := "%dx%d" % [dimensions.x, dimensions.y]
		screen._start("42")
		await _frames()
		_check(screen.health.size.y >= 8, "health bar visible " + suffix)
		for kind in screen.Keys.TYPES:
			_check(screen.key_labels[kind].text.contains(screen.Keys.LABELS[kind]), "key text identity " + kind + suffix)
		if dimensions.x == 320:
			for enemy in screen.game.db.data.enemies.values():
				if enemy.rank != "normal":
					continue
				_fixture(screen, {"type": "enemy", "name": enemy.name, "enemy_id": enemy.id})
				screen._close_overlay()
				await _frames()
				_check(screen.detail_copy.is_visible_in_tree() and screen.detail_copy.get_line_count() == 1, "320 cost has a dedicated complete line " + str(enemy.id))
				_check(screen.detail_copy.get_global_rect().end.y <= screen.detail_panel.get_global_rect().end.y, "320 cost inside summary " + str(enemy.id))
				await _capture("summary_320_" + str(enemy.id))
		_fixture(screen, {"type": "choice", "name": "遗物二选一", "choices": ["blood_sword", "stone_heart"], "gold": 25})
		await _frames()
		_sheet_bounds(screen, "choice " + suffix)
		await _capture("choice_" + suffix)
		var second := _button_named(screen.body, "选择 · 岩心")
		second.grab_focus()
		await _frames()
		_check(second.has_focus() and screen.scroll.get_global_rect().intersects(second.get_global_rect()), "focus scrolls second choice into view " + suffix)
		await _capture("choice_focus_" + suffix)
		screen.game.state.player.gold = 100
		screen.game._grant_item("gold_sword")
		screen.game._grant_item("merchant_seal")
		_fixture(screen, {"type": "shop", "name": "烛火商人", "offers": ["buy_steel", "buy_plate", "buy_potion"], "purchased": false})
		await _frames()
		_sheet_bounds(screen, "shop " + suffix)
		await _capture("shop_" + suffix)
		screen.game.state.player.gold = 0
		screen._render(true)
		await _frames()
		_check(_button_named(screen.body, "购买").disabled, "unaffordable offer disabled " + suffix)
		await _capture("shop_disabled_" + suffix)
		_fixture(screen, {"type": "event", "name": "血色祭坛", "event_id": "altar"})
		await _frames()
		_sheet_bounds(screen, "event " + suffix)
		await _capture("event_" + suffix)
		_fixture(screen, {"type": "rest", "name": "旅人休息点", "options": screen.game.generator.reward_config.rest_options.duplicate(true)})
		await _frames()
		_sheet_bounds(screen, "rest " + suffix)
		await _capture("rest_" + suffix)
		screen._close_overlay()
		screen.game._grant_item("iron_sword")
		screen.game._grant_item("iron_sword")
		screen._open_overlay("inventory")
		await _frames()
		_sheet_bounds(screen, "inventory " + suffix)
		await _capture("inventory_" + suffix)
		screen._close_overlay()
		_fixture(screen, {"type": "enemy", "name": "骑士", "enemy_id": "knight"})
		# General confirmation dialogs still need focus/layout coverage; encounters
		# now resolve after the single challenge button without forecasting defeat.
		screen._confirm("返回营地", "是否返回营地？", func(): pass)
		await _frames()
		var dialog: ConfirmationDialog
		for child in screen.get_children():
			if child is ConfirmationDialog:
				dialog = child
		_check(is_instance_valid(dialog) and screen.modal_open, "confirmation dialog exists " + suffix)
		if is_instance_valid(dialog):
			_check(dialog.get_cancel_button().has_focus(), "dialog defaults to cancel " + suffix)
			_check(dialog.size.x <= dimensions.x and dialog.size.y <= dimensions.y, "dialog fits window " + suffix)
			await _capture("confirmation_" + suffix)
			var pos: Vector2i = screen.game.position()
			await _keyboard(KEY_RIGHT)
			_check(screen.game.position() == pos, "modal blocks movement " + suffix)
			for index in 4:
				var key := InputEventKey.new()
				key.keycode = KEY_TAB
				key.pressed = true
				dialog.push_input(key)
				await _frames()
				var focused := dialog.gui_get_focus_owner()
				_check(focused == dialog.get_ok_button() or focused == dialog.get_cancel_button(), "modal Tab contained " + suffix)
			# Check a simultaneous persistent failure without closing the modal.
			screen.game.save_error = "无法保存本次探索。请检查目录权限；当前进度尚未写入磁盘。"
			screen._refresh_save_error()
			await _frames()
			_check(screen.save_error_panel.get_global_rect().end.y <= dialog.position.y, "save warning clear of confirmation " + suffix)
			await _capture("confirmation_save_error_" + suffix)
			dialog.get_cancel_button().pressed.emit()
			await _frames()
			_check(not screen.modal_open and screen.game.active(), "real cancel button preserves run " + suffix)
		screen.game.save_error = ""
		screen._close_overlay()
		screen.game.state.player.hp = 1
		_fixture(screen, {"type": "enemy", "name": "骑士", "enemy_id": "knight"})
		screen._act(func(): return screen.game.confirm_interaction(true))
		await _frames()
		_check(_button_named(screen.body, "相同种子重新开始").has_focus(), "result focuses visible action " + suffix)
		await _capture("result_" + suffix)
		_button_named(screen.body, "返回营地").pressed.emit()
		await _frames()
		_check(screen.page == "menu", "result returns to camp " + suffix)
		screen._start("42")
		var before: String = JSON.stringify(screen.game.state)
		_button_named(screen.hud, "营地").pressed.emit()
		await _frames()
		await _capture("menu_" + suffix)
		if not screen.seed_input.is_visible_in_tree():
			_button_named(screen.body, "出发选项").pressed.emit()
		_check(screen.seed_input.is_visible_in_tree(), "departure options expose seed " + suffix)
		screen.seed_input.text = "84"
		_button_named(screen.body, "开始两层地图试炼").pressed.emit()
		await _frames()
		for child in screen.get_children():
			if child is ConfirmationDialog:
				_check(child.get_cancel_button().has_focus(), "new-run confirmation defaults to cancel " + suffix)
				await _capture("menu_confirmation_" + suffix)
				child.get_cancel_button().pressed.emit()
		await _frames()
		_check(not screen.modal_open and JSON.stringify(screen.game.state) == before, "cancel new run preserves exploration " + suffix)
		_button_named(screen.body, "继续探索").pressed.emit()
		await _frames()
		_check(screen.page == "map" and JSON.stringify(screen.game.state) == before, "camp resume keeps state " + suffix)
		# Long Chinese option text: content and action remain reachable in local scrolling.
		_fixture(screen, {"type": "rest", "name": "旅人的临时避风营地", "options": [{"name": "沿着古老石阶寻找失落的回溯印记并带回营地", "description": "这是一段用于检查窄屏换行的长中文说明。".repeat(6), "effects": {"heal": 40}}]})
		await _frames()
		_sheet_bounds(screen, "long Chinese " + suffix)
		await _capture("long_copy_" + suffix)
		screen._close_overlay()
		await _other_panels(screen, suffix)
		if dimensions.x == 360:
			await _frames()
			var button: Button = screen.direction_buttons[2]
			button.grab_focus()
			var motion := InputEventMouseMotion.new()
			motion.position = button.get_global_rect().get_center()
			root.push_input(motion)
			await _frames()
			_check(button.is_hovered(), "direction hover from pointer event")
			await _capture("button_hover_focus_" + suffix)
			var click := InputEventMouseButton.new()
			click.position = motion.position
			click.button_index = MOUSE_BUTTON_LEFT
			click.pressed = true
			root.push_input(click)
			await _frames()
			_check(button.is_pressed(), "direction pressed state from pointer event")
			await _capture("button_pressed_" + suffix)
			click = click.duplicate()
			click.pressed = false
			root.push_input(click)
	screen.queue_free()
	await _frames()
	_check(root.content_scale_mode == original_mode and root.content_scale_size == original_size, "scene exit restores original scaling")

func _capture(label: String) -> void:
	if not capturing:
		return
	await RenderingServer.frame_post_draw
	var folder := ProjectSettings.globalize_path("res://").path_join("build/verification/ui_visual_v01/screenshots/" + phase)
	DirAccess.make_dir_recursive_absolute(folder)
	_check(root.get_texture().get_image().save_png(folder.path_join(label + ".png")) == OK, "capture " + label)

func _run() -> void:
	if not OS.get_user_data_dir().replace("\\", "/").contains("/build/verification/ui_visual_v01/"):
		push_error("Use isolated ui_visual_v01 APPDATA and LOCALAPPDATA")
		quit(2)
		return
	phase = "before" if OS.get_cmdline_user_args().has("--baseline") else "after"
	capturing = OS.get_cmdline_user_args().has("--capture")
	if phase == "after":
		await _visual_states()
		print("Visual V01 additional checks: %d, failures: %d" % [checks, failures])
	await super._run()
