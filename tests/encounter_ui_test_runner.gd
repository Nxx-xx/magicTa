extends "res://tests/phase3_ui_host_test_runner.gd"
const Preferences = preload("res://scripts/ui/presentation_settings.gd")
const ENCOUNTER_OUT := "res://build/verification/encounter/"

func _copy(node: Node) -> String:
	var result := ""
	if node is Label and node.is_visible_in_tree(): result += node.text + "\n"
	for child in node.get_children(): result += _copy(child)
	return result

func _snap(label: String) -> void:
	if not capture: return
	await RenderingServer.frame_post_draw
	_check(root.get_texture().get_image().save_png(ENCOUNTER_OUT + label + ".png") == OK, "capture " + label)

func _run() -> void:
	if not ProjectSettings.globalize_path("user://").replace("\\", "/").contains("verification/encounter/"):
		quit(2)
		return
	capture = "--capture" in OS.get_cmdline_user_args()
	DirAccess.make_dir_recursive_absolute(ENCOUNTER_OUT)
	root.min_size = Vector2i(320,640)
	for dimensions in [Vector2i(320,640), Vector2i(360,640), Vector2i(540,960), Vector2i(900,960)]:
		root.size = dimensions
		ui = Screen.new()
		ui.game = Core.new("user://encounter_%d_%d.json" % [dimensions.x,Time.get_ticks_usec()])
		root.add_child(ui)
		ui.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
		await _frames()
		ui.settings.muted = true
		ui.settings.reduce_motion = true
		ui.settings.seen_mechanics.clear()
		ui.settings.fought_mechanics.clear()
		ui._start_phase3("42")
		while not ui._story_event().is_empty(): ui._finish_story()
		var branch: Array = ui.game.floor_data().branch_paths[0]
		var cell := Vector2i(branch[0][0], branch[0][1])
		_check(_walk(cell), "approach ordinary enemy")
		ui._render(true)
		await _frames()
		var preview: Dictionary = ui.game.preview(cell)
		_check(_copy(ui.body).contains("可战胜") and _copy(ui.body).contains("战后生命"), "default card contains decision facts")
		_check(not _copy(ui.body).contains("敌方：") and not _copy(ui.body).contains("总受伤"), "attributes and calculation collapsed")
		_check(ui.encounter_action.visible and not ui.encounter_action.disabled, "challenge accessible outside scroll")
		_check(ui.encounter_action.get_global_rect().end.y < ui.size.y and ui.overlay_close.get_global_rect().end.y <= ui.size.y, "footer within viewport")
		_check(ui.overlay_panel.position.y > ui.board.position.y + 50, "compact card preserves visible map")
		_check(ui.scroll.get_v_scroll_bar().max_value <= ui.scroll.size.y + 1, "ordinary card needs no scrolling")
		await _snap("compact_%d" % dimensions.x)
		var toggle = ui.find_child("EncounterDetailsToggle", true, false)
		toggle.pressed.emit()
		await _frames()
		_check(_copy(ui.body).contains("敌方：") and _copy(ui.body).contains("总受伤"), "details reveal stats and calculation")
		_check(ui.encounter_action.get_global_rect().end.y < ui.size.y, "challenge stays reachable in long details")
		await _snap("details_%d" % dimensions.x)
		toggle.pressed.emit()
		await _frames()
		var original_store = ui.game.store
		ui.game.store = RejectStore.new()
		ui._fight()
		_check(ui.game.transaction_pending and not is_instance_valid(ui.combat_view) and not is_instance_valid(ui.combat_feedback), "save failure never shows success feedback")
		ui.game.store = original_store
		ui._retry_save()
		var committed: Dictionary = ui.game.state.duplicate(true)
		await _frames()
		_check(not is_instance_valid(ui.combat_view) and ui.overlay_kind == "", "ordinary victory automatically returns to map")
		_check(is_instance_valid(ui.combat_feedback) and ui.combat_feedback.mouse_filter == Control.MOUSE_FILTER_IGNORE, "short nonblocking feedback")
		_check(int(ui.game.state.last_report.loss) == int(preview.loss), "compact cost matches real settlement")
		_check(Contract.same_json(committed, ui.game.state), "automatic close never settles twice")
		await _snap("feedback_%d" % dimensions.x)
		ui._open_overlay("log")
		_check(not _copy(ui.body).is_empty(), "full report remains accessible")
		ui._close_overlay()
		# Use another existing enemy cell to exercise special mechanics and risk.
		ui.game.persistence_enabled = false # Synthetic content is not a legal generated save.
		for entity in ui.game.floor_data().entities.values():
			if entity.get("type", "") == "enemy":
				cell = Vector2i(entity.pos[0], entity.pos[1])
				break
		ui.game.floor_data().entities[Core.cell_key(cell)].enemy_id = "p3_shield_sentinel"
		ui.selected = cell
		ui._open_overlay("target")
		await _frames()
		_check(_copy(ui.body).contains("新机制"), "new ability explained once")
		ui._close_overlay()
		ui._open_overlay("target")
		await _frames()
		_check(not _copy(ui.body).contains("新机制") and _copy(ui.body).contains("盾壳减伤"), "repeated ability keeps label only")
		var saved := Preferences.new()
		saved.read()
		_check(saved.seen_mechanics.has("v2:p3_shield"), "mechanic familiarity survives reload")
		ui._close_overlay()
		ui.game.state.player.hp = 1
		ui.game.state.pending = {"kind":"entity", "pos":[cell.x,cell.y]}
		ui._render(true)
		await _frames()
		_check(_copy(ui.body).contains("预计战败"), "lethal outcome clearly visible")
		var before: Dictionary = ui.game.state.duplicate(true)
		ui._request_fight()
		_check(ui.modal_open and Contract.same_json(before,ui.game.state), "lethal challenge requires second confirmation")
		for child in ui.get_children():
			if child is ConfirmationDialog: child.canceled.emit()
		ui._close_overlay()
		ui.game.state.player.hp = 6
		ui.game.state.player.attack = 20
		ui.game.state.player.defense = 12
		ui.game.state.player.relic_ids.append("blood_sword")
		ui.game.state.pending = {"kind":"entity", "pos":[cell.x,cell.y]}
		ui._render(true)
		await _frames()
		_check(_copy(ui.body).contains("战中最低生命 2") and _copy(ui.body).contains("获胜后才恢复 3"), "near-death risk survives small net loss after healing")
		await _snap("risk_%d" % dimensions.x)
		ui.game.db.data.items.blood_sword.effects.kill_heal = 4
		ui._render(true)
		_check(_copy(ui.body).contains("战后生命不变") and not _copy(ui.body).contains("无伤"), "healing offset never mislabels damage as no damage")
		ui.game.db.data.items.blood_sword.effects.kill_heal = 3
		var previous: Dictionary = ui.game.preview(cell).duplicate(true)
		previous.won = false
		ui.equipment_comparison = {"changed":true, "enemy_id":"p3_shield_sentinel", "report":previous}
		ui._render(true)
		_check(_copy(ui.body).contains("现在可以战胜"), "meaningful equipment improvement shown")
		ui._close_overlay()
		_check(ui.equipment_comparison.is_empty(), "growth reminder consumed after inspection")
		# A safe, high-stat fixture validates first-mechanic replay retention.
		ui.game.state.player.hp = 100
		ui.game.state.player.attack = 100
		ui.game.state.player.defense = 100
		ui.game.state.pending = {"kind":"entity", "pos":[cell.x,cell.y]}
		var repeat_enemy: Dictionary = ui.game.entity_at(cell).duplicate(true)
		ui._render(true)
		ui._fight()
		await _frames()
		_check(is_instance_valid(ui.combat_view), "first ability battle keeps complete result")
		if is_instance_valid(ui.combat_view):
			_check(not ui.combat_context.auto_close, "new mechanic excludes quick close")
			ui.combat_view.close()
		await _frames()
		_check(ui.settings.fought_mechanics.has("v2:p3_shield"), "committed mechanic encounter remembered")
		repeat_enemy.id += "_repeat"
		ui.game.floor_data().entities[Core.cell_key(cell)] = repeat_enemy
		ui.game.state.pending = {"kind":"entity", "pos":[cell.x,cell.y]}
		ui.settings.reduce_motion = false
		ui._render(true)
		ui._fight()
		_check(is_instance_valid(ui.combat_view), "ordinary battle still plays its animation")
		if is_instance_valid(ui.combat_view): ui.combat_view.advance(ui.combat_view._plan.duration + 0.01)
		await _frames()
		_check(not is_instance_valid(ui.combat_view) and ui.overlay_kind == "", "familiar mechanic returns to ordinary quick flow")
		# Historical prototype fixtures receive the same concise card and quick result.
		ui.game = preload("res://tests/legacy_map_core_fixture.gd").new("user://legacy_encounter.json")
		ui.game.persistence_enabled = false
		ui.game.start("42")
		ui.game.state.pending = {"kind":"entity", "pos":[6,5]}
		ui.game.floor_data().entities["6,5"] = {"type":"enemy", "enemy_id":"slime", "id":"legacy-slime", "name":"史莱姆", "pos":[6,5]}
		ui.game.state.player.attack = 100
		ui.settings.reduce_motion = true
		ui._render(true)
		ui._fight()
		await _frames()
		_check(not is_instance_valid(ui.combat_view) and ui.overlay_kind == "", "legacy ordinary victory auto closes")
		root.remove_child(ui)
		ui.queue_free()
		await _frames()
	print("ENCOUNTER_UI checks=%d failures=%d" % [checks,failures])
	quit(1 if failures else 0)
