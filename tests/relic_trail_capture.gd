extends "res://tests/phase3_ui_host_test_runner.gd"
## Production UI with generated-floor fixtures, not a full gameplay traversal.
const Trail = preload("res://scripts/core/relic_trail.gd")
const TRAIL_OUT := "res://build/verification/relic-trail/"

func _shot(label: String) -> void:
	await RenderingServer.frame_post_draw
	_check(root.get_texture().get_image().save_png(TRAIL_OUT + label + ".png") == OK, label)

func _run() -> void:
	if not ProjectSettings.globalize_path("user://").replace("\\", "/").contains("verification/relic-trail/"):
		quit(2)
		return
	DirAccess.make_dir_recursive_absolute(TRAIL_OUT)
	root.min_size = Vector2i(320,640)
	for dimensions in [Vector2i(320,640),Vector2i(540,960)]:
		root.size = dimensions
		ui = Screen.new()
		ui.game = Core.new("user://ui_trail_%d.json" % Time.get_ticks_usec())
		ui.game.persistence_enabled = false
		root.add_child(ui)
		ui.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
		await _frames()
		ui.settings.muted = true
		ui.settings.reduce_motion = true
		ui._start_phase3("42")
		while not ui._story_event().is_empty(): ui._finish_story()
		ui._tutorial_event({"type":"skip_all"})
		for number in [2,6,9]:
			var floor_map: Dictionary = ui.game.campaign_generator.generate(ui.game.state.campaign_plan,number,"battle")
			ui.game._accept_generated_floor(number,floor_map)
			ui.game.state.floor = number
			var entity: Dictionary = {}
			for candidate in floor_map.entities.values():
				if candidate.has("ruin_id"): entity = candidate
			ui.game.state.position = entity.pos.duplicate()
			ui.game.state.pending = {"kind":"entity", "pos":entity.pos.duplicate()}
			ui.selected = Vector2i(entity.pos[0],entity.pos[1])
			ui._render(true)
			await _frames()
			var panel = ui.find_child("Phase3Ruin",true,false)
			_check(panel != null, "ruin UI mounted")
			if panel == null: continue
			_check(panel.leave_button().get_global_rect().end.y <= ui.size.y+1, "leave remains visible")
			await _shot("floor%d_choices_%d" % [number,dimensions.x])
			panel._show_detail("__intro")
			await _frames()
			_check(not panel._pages.is_empty() and "".join(panel._pages) == panel._full_text, "every narrative character survives pagination")
			_check(panel._detail.get_global_rect().end.y <= ui.size.y+1, "narrative stays on screen")
			await _shot("floor%d_story_%d" % [number,dimensions.x])
			_check(ui.game.choose_ruin("ward" if number == 9 else "salvage").is_empty(), "fixture commits real option")
			ui._close_overlay()
		_check(Trail.complete(ui.game.state), "UI fixture has full investigation")
		ui._open_overlay("log")
		await _frames()
		var journal = ui.find_child("ReportCatalog",true,false)
		_check(journal != null and journal._entries.size() == 4, "journal available before combat")
		await _shot("journal_%d" % dimensions.x)
		journal._show_detail("trail_p3_oath_ruin")
		await _frames()
		await _shot("evidence_%d" % dimensions.x)
		ui._close_overlay()
		ui._open_overlay("inventory")
		await _frames()
		var inventory = ui.find_child("InventoryCatalog",true,false)
		var found := false
		for category in inventory.categories:
			if category.name == "旅途拾遗": found = category.entries.size() == 4
		_check(found, "inventory exposes evidence and relic outcomes")
		await _shot("inventory_%d" % dimensions.x)
		ui._close_overlay()
		ui.page = "menu"
		ui.camp_view = "knight"
		ui._render(true)
		await _frames()
		var knight = ui.find_child("CampKnightDialogue",true,false)
		_check(knight != null, "knight conversation mounted")
		if knight != null:
			knight._show_detail("story")
			await _frames()
			_check(knight._full_text.contains(Trail.knight_memory(ui.game.state)), "knight responds to the selected expedition")
			await _shot("knight_%d" % dimensions.x)
		ui.queue_free()
		await _frames()
	print("RELIC_TRAIL_UI checks=%d failures=%d" % [checks,failures])
	quit(1 if failures else 0)
