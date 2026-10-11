extends "res://tests/phase3_ui_host_test_runner.gd"
## All authored histories in production widgets; controlled fixtures, not playthroughs.
const Pool = preload("res://scripts/core/relic_story_pool.gd")
const Ruins = preload("res://scripts/core/phase3_ruins.gd")
const Trail = preload("res://scripts/core/relic_trail.gd")
const REVIEW_OUT := "res://build/verification/relic-pool/"

func _shot(label: String) -> void:
	await RenderingServer.frame_post_draw
	_check(root.get_texture().get_image().save_png(REVIEW_OUT+label+".png") == OK,label)

func _run() -> void:
	if not ProjectSettings.globalize_path("user://").replace("\\", "/").contains("verification/relic-pool/"):
		quit(2)
		return
	DirAccess.make_dir_recursive_absolute(REVIEW_OUT)
	root.min_size = Vector2i(320,640)
	var stories := Pool.catalog()
	for dimensions in [Vector2i(320,640),Vector2i(540,960)]:
		root.size = dimensions
		for story_id in Pool.STORY_IDS:
			ui = Screen.new()
			ui.game = Core.new("user://capture_%d.json" % Time.get_ticks_usec())
			ui.game.persistence_enabled = false
			root.add_child(ui)
			ui.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
			await _frames()
			ui.settings.muted = true
			ui.settings.reduce_motion = true
			ui._start_phase3("42")
			while not ui._story_event().is_empty(): ui._finish_story()
			ui._tutorial_event({"type":"skip_all"})
			var mode := 0 if dimensions.x == 320 else 1
			var definitions := Pool.materialize(Ruins.definitions(),story_id,[mode,mode,mode],stories)
			ui.game.state.ruin_definitions_snapshot = definitions
			ui.game.state.reward_content.events.merge(Ruins.event_definitions(definitions),true)
			ui.game._sync_runtime()
			for number in [2,6,9]:
				var floor_map: Dictionary = ui.game.campaign_generator.generate(ui.game.state.campaign_plan,number,"battle")
				ui.game._accept_generated_floor(number,floor_map)
				ui.game.state.floor = number
				var entity: Dictionary = {}
				for candidate in floor_map.entities.values():
					if candidate.has("ruin_id"): entity = candidate
				ui.game.state.position = entity.pos.duplicate()
				ui.game.state.pending = {"kind":"entity","pos":entity.pos.duplicate()}
				ui.selected = Vector2i(entity.pos[0],entity.pos[1])
				ui._render(true)
				await _frames()
				var panel = ui.find_child("Phase3Ruin",true,false)
				_check(panel != null,"selected story mounted")
				if panel == null: continue
				_check(panel.leave_button().get_global_rect().end.y <= ui.size.y+1,"leave control visible")
				await _shot("%s_floor%d_choices_%d" % [story_id,number,dimensions.x])
				panel._show_detail("__intro")
				await _frames()
				_check("".join(panel._pages) == panel._full_text,"all narrative text retained by pagination")
				_check(panel._full_text.contains(definitions[entity.ruin_id].description),"correct scene shown")
				await _shot("%s_floor%d_story_%d" % [story_id,number,dimensions.x])
				panel._show_detail("ward" if number == 9 else "salvage")
				await _frames()
				_check(panel._action.get_global_rect().end.y <= ui.size.y+1,"claim button visible")
				_check("".join(panel._pages) == panel._full_text,"item story and numeric reward both retained")
				_check(ui.game.choose_ruin("ward" if number == 9 else "salvage").is_empty(),"real selected reward")
				ui._close_overlay()
			ui._open_overlay("log")
			await _frames()
			var journal = ui.find_child("ReportCatalog",true,false)
			_check(journal != null and journal._entries.size() == 4,"four earned journal entries")
			await _shot("%s_journal_%d" % [story_id,dimensions.x])
			journal._show_detail("trail_complete")
			await _frames()
			_check(journal._full_text == stories[story_id].conclusion,"selected history has its own conclusion")
			await _shot("%s_conclusion_%d" % [story_id,dimensions.x])
			ui.queue_free()
			await _frames()
	print("RELIC_POOL_UI checks=%d failures=%d; six histories at 320/540" % [checks,failures])
	quit(1 if failures else 0)
