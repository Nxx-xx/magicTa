extends "res://tests/phase3_ui_host_test_runner.gd"
const DIR := "res://build/verification/art-polish-d/regression/compact-ui/"

func _snap(label: String) -> void:
	if not capture: return
	await RenderingServer.frame_post_draw
	_check(root.get_texture().get_image().save_png(DIR+label+".png") == OK,"capture "+label)

func _fits(label: String) -> void:
	_check(ui.scroll.get_global_rect().end.y <= ui.size.y+1,label+" viewport stays on screen")
	_check(not ui.scroll.get_v_scroll_bar().visible and not ui.scroll.get_h_scroll_bar().visible,label+" no scrolling")
	_check(ui.body.size.y <= ui.scroll.size.y+1,label+" content fits height: %s / %s" % [ui.body.size,ui.scroll.size])
	_check(ui.body.size.x <= ui.scroll.size.x+1,label+" content fits width")
	for button in ui.body.find_children("*","Button",true,false):
		if not button.is_visible_in_tree(): continue
		_check(button.get_global_rect().end.y <= ui.scroll.get_global_rect().end.y+1,label+" button visible "+button.name)
		_check(button.get_global_rect().end.x <= ui.size.x,label+" button within width "+button.name)
	if ui.page == "map" and ui.overlay_close.visible:
		_check(ui.overlay_close.get_global_rect().end.y <= ui.size.y,label+" fixed footer")

func _inspect(panel, label: String) -> void:
	var original: Dictionary = ui.game.state.duplicate(true)
	for entry in panel._entries:
		if entry.get("navigate",false): continue
		var button: Button = panel.option_button(str(entry.id))
		if button != null and button.is_visible_in_tree():
			for pressed in [true,false]:
				var click := InputEventMouseButton.new()
				click.button_index = MOUSE_BUTTON_LEFT
				click.pressed = pressed
				click.position = button.get_global_rect().get_center()
				root.push_input(click)
		else: panel._show_detail(str(entry.id))
		await _frames()
		_check(panel._selected == str(entry.id),label+" icon click opens matching details")
		_fits(label+" details")
		_check("".join(panel._pages) == panel._full_text,label+" all detail text retained")
		_check(panel._detail.get_line_count()*panel._detail.get_line_height() <= panel._detail.get_parent().size.y+2,label+" text fits")
		_check(Contract.same_json(original,ui.game.state),label+" inspection immutable")
		await _snap(label+"_detail")
		panel.show_overview()
		break

func _run() -> void:
	if not ProjectSettings.globalize_path("user://").replace("\\","/").contains("phase3/08-parallel/art-polish-d/"):
		quit(2)
		return
	capture = "--capture" in OS.get_cmdline_user_args()
	root.min_size = Vector2i(320,600)
	for dimensions in [Vector2i(320,600),Vector2i(360,640),Vector2i(540,960),Vector2i(900,960)]:
		root.size = dimensions
		ui = Screen.new()
		ui.game = Core.new("user://compact_%d.json" % dimensions.x)
		ui.game.persistence_enabled = false
		root.add_child(ui)
		ui.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
		await _frames()
		ui.settings.muted = true
		ui.settings.reduce_motion = true
		for camp_section in ["", "knight", "tower", "death"]:
			ui.page = "menu"
			ui.camp_view = camp_section
			ui._render(true)
			await _frames()
			_fits("camp "+camp_section)
			await _snap("camp_%s_%d" % [camp_section,dimensions.x])
			if camp_section == "death":
				var preparation = ui.find_child("Phase3Departure",true,false)
				_check(not is_instance_valid(preparation.seed_input),"Death has no seed input")
				preparation.find_child("PreparationDetails",true,false).pressed.emit()
				await _frames()
				_fits("preparation details")
				preparation.back_to_overview()
				_check(not is_instance_valid(preparation.seed_input),"detail navigation does not restore seed input")
		ui._show_title()
		await _frames()
		_fits("title")
		await _snap("title_%d" % dimensions.x)
		ui._start_phase3("42")
		while not ui._story_event().is_empty(): ui._finish_story()
		for id in ui.game.db.data.items:
			var item: Dictionary = ui.game.db.item(id)
			var field := "relic_ids" if item.get("kind","") == "relic" else "equipment_ids"
			ui.game.state.player[field].append(id)
		ui.game.meta.codex.seen_items = ui.game.db.data.items.keys()
		ui.game.meta.codex.seen_enemies = ui.game.db.data.enemies.keys()
		ui.game.meta.records = []
		for i in 12: ui.game.meta.records.append({"result":"death","floor":i%10+1,"souls":i*2,"seed":str(i)})
		ui.game.state.last_report = {"won":true,"hp_after":71,"loss":29,"log":[]}
		for i in 45: ui.game.state.last_report.log.append({"turn":i+1,"hit":4,"enemy_hp":300-i*4,"counter":1,"hp":100-i,"note":"机制触发说明"})
		for overlay_name in ["inventory","floors","log","settings"]:
			ui._open_overlay(overlay_name)
			await _frames()
			_fits(overlay_name+str(dimensions))
			await _snap("%s_%d" % [overlay_name,dimensions.x])
			var panel = ui.body.get_child(0)
			if overlay_name == "floors":
				_check(panel._buttons.size() == 10,"all ten floors visible")
				_check(panel._buttons["2"].disabled,"undiscovered floor disabled")
				panel._show_floor(1)
				await _frames()
				_fits("floor map")
				await _snap("floor_map_%d" % dimensions.x)
				panel._show_information(1)
				await _frames()
				_fits("floor targets")
			elif overlay_name == "settings":
				for tab in 3:
					panel._show(tab)
					await _frames()
					_fits("settings tab "+str(tab))
			else: await _inspect(panel,"%s_%d" % [overlay_name,dimensions.x])
			ui._close_overlay()
		for page_name in ["codex","records","settings"]:
			ui._open_section(page_name)
			await _frames()
			_fits(page_name)
			await _snap("%s_%d" % [page_name,dimensions.x])
			var panel = ui.body.get_child(0)
			if page_name == "codex":
				panel.show_category("story")
				await _frames()
				_check(not str(panel._entries).contains("secret"),"undiscovered story not shown")
				panel.show_category("items")
				await _frames()
				_fits("codex items")
				await _inspect(panel,"codex_items_%d" % dimensions.x)
			elif page_name in ["records"]: await _inspect(panel,"%s_%d" % [page_name,dimensions.x])
		ui.page = "menu"
		ui.camp_view = "growth"
		ui.camp_growth_level = 0
		ui._render(true)
		await _frames()
		_fits("growth overview")
		await _snap("growth_%d" % dimensions.x)
		var frozen: Dictionary = ui.game.meta.duplicate(true)
		ui.find_child("GrowthNode_hp_1",true,false).pressed.emit()
		await _frames()
		_fits("growth detail")
		var growth = ui.find_child("GrowthDetail",true,false)
		_check(growth._action.disabled,"active run cannot purchase")
		_check(Contract.same_json(frozen,ui.game.meta),"select growth never spends")
		await _snap("growth_detail_%d" % dimensions.x)
		ui.game.abandon_run()
		ui.game.meta.souls = 100
		ui.game.meta.souls_earned_total = 100
		ui._render(true)
		await _frames()
		growth = ui.find_child("GrowthDetail",true,false)
		_check(not growth._action.disabled,"funded ended run can upgrade")
		growth._action.pressed.emit()
		growth.option_selected.emit("hp")
		await _frames()
		_check(ui.game.meta.upgrades.hp == 1,"upgrade settles once")
		_check(ui.find_child("GrowthDetail",true,false)._action.disabled,"purchased rank cannot repeat")
		ui._open_map()
		await _frames()
		_fits("result")
		await _snap("result_%d" % dimensions.x)
		await _inspect(ui.find_child("ResultCatalog",true,false),"result_%d" % dimensions.x)
		ui._open_overlay("floors")
		ui._close_overlay()
		_check(ui.overlay_kind == "result","review returns to result")
		ui.game.state.result = "victory"
		ui._render(true)
		await _frames()
		await _inspect(ui.find_child("ResultCatalog",true,false),"victory_%d" % dimensions.x)
		var player = preload("res://scripts/ui/phase3_combat_player.gd").new()
		var report: Dictionary = preload("res://tests/phase3_animation_fixture.gd").report(24)
		player.configure(report,true,{"reduce_motion":true,"enemy_name":"守卫","enemy_id":"slime"})
		ui.add_child(player)
		player.position = Vector2(8,120)
		player.size = Vector2(dimensions.x-16,dimensions.y-132)
		await _frames()
		_check(player._report_pages.visible,"reduced motion opens paged report")
		player._report_pages._show_detail("full")
		await _frames()
		_check(player._primary.get_global_rect().end.y <= dimensions.y,"combat report footer fits")
		_check("".join(player._report_pages._pages) == player.report_text(report),"combat full report preserved")
		await _snap("combat_report_%d" % dimensions.x)
		player._log_toggle.pressed.emit()
		_check(not player._report_pages.visible,"can return to replay")
		ui.remove_child(player)
		player.queue_free()
		root.remove_child(ui)
		ui.queue_free()
		await _frames()
	print("COMPACT_SCREENS checks=%d failures=%d" % [checks,failures])
	quit(1 if failures else 0)
