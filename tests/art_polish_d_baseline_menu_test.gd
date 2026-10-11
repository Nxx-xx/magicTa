extends SceneTree
const Screen = preload("res://tests/art_polish_d_baseline_screen.gd")
const Core = preload("res://scripts/core/campaign_engine.gd")
const Contract = preload("res://scripts/core/phase3_contract.gd")
const OUT := "res://build/verification/art-polish-d/regression/main-menu/"
var failures := 0
var checks := 0
var capture := false

func _initialize() -> void: _run.call_deferred()

func check(ok: bool, label: String) -> void:
	checks += 1
	if not ok:
		failures += 1
		push_error("FAIL " + label)

func frames() -> void:
	for i in 8: await process_frame

func shot(label: String) -> void:
	if not capture: return
	await RenderingServer.frame_post_draw
	check(root.get_texture().get_image().save_png(OUT + label + ".png") == OK, "capture " + label)

func _run() -> void:
	if not ProjectSettings.globalize_path("user://").replace("\\", "/").contains("phase3/08-parallel/art-polish-d/"):
		quit(2)
		return
	DirAccess.make_dir_recursive_absolute(OUT)
	capture = "--capture" in OS.get_cmdline_user_args()
	root.min_size = Vector2i(320, 640)
	for dimensions in [Vector2i(360,640), Vector2i(540,960), Vector2i(900,960), Vector2i(320,640)]:
		root.size = dimensions
		var ui = Screen.new()
		var save_path := "user://menu_%d_%d.json" % [dimensions.x, Time.get_ticks_usec()]
		ui.game = Core.new(save_path)
		root.add_child(ui)
		ui.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
		await frames()
		ui.settings.muted = true
		check(ui.page == "title" and ui.find_child("MainMenu",true,false) != null, "startup shows main menu")
		check(ui.find_child("TitleIllustration",true,false).texture != null, "illustration imported")
		check(ui.find_child("ContinueGame",true,false).disabled, "empty save disables continue")
		check(ui.scroll.get_h_scroll_bar().max_value <= ui.scroll.size.x + 1, "no horizontal overflow")
		check(ui.scroll.get_v_scroll_bar().max_value <= ui.scroll.size.y + 1, "all main menu actions fit")
		await shot("title_%d" % dimensions.x)
		for section in ["records", "guide", "settings", "codex"]:
			ui._open_section(section)
			await frames()
			check(ui.page == section and ui.find_child("CampMap",true,false) == null, "secondary page isolates " + section)
			check(ui.scroll.get_h_scroll_bar().max_value <= ui.scroll.size.x + 1, "secondary fits " + section)
			if dimensions.x == 540: await shot(section)
			ui._back_section()
			await frames()
			check(ui.page == "title", "secondary returns to title")
		ui.find_child("StartGame",true,false).pressed.emit()
		await frames()
		check(ui.page == "menu" and ui.camp_view.is_empty() and ui.game.state.is_empty(), "start opens camp without mutating run")
		check(is_instance_valid(ui.camp_map), "start shows walkable camp map")
		check(ui.find_child("CampHome",true,false).size.x >= 84, "camp home label has usable width")
		for removed in ["Camp_records", "Camp_guide", "Camp_settings"]:
			check(ui.find_child(removed,true,false) == null, "camp has no expanded section " + removed)
		ui._open_section("guide")
		ui._back_section()
		await frames()
		check(ui.page == "menu" and is_instance_valid(ui.camp_map), "secondary returns to originating camp")
		if dimensions.x == 540: await shot("camp")
		ui._start_phase3("MENU-RESUME")
		await frames()
		var before: Dictionary = ui.game.state.duplicate(true)
		var resumed = Core.new(save_path)
		resumed.load_game()
		check(resumed.active() and resumed.state.run_id == before.run_id, "current journey reloads from disk")
		ui._show_title()
		await frames()
		check(not ui.find_child("ContinueGame",true,false).disabled, "active run enables continue")
		ui.find_child("ContinueGame",true,false).pressed.emit()
		await frames()
		check(ui.page == "map" and ui.overlay_kind == "story", "continue preserves pending story")
		check(Contract.same_json(before, ui.game.state), "continue does not replace saved run")
		ui._show_title()
		ui.find_child("StartGame",true,false).pressed.emit()
		await frames()
		check(ui.page == "menu" and ui.camp_view.is_empty() and is_instance_valid(ui.camp_map), "start with active run also opens camp")
		check(Contract.same_json(before, ui.game.state), "entering camp preserves active run")
		ui._request_start("REPLACE")
		check(ui.modal_open and Contract.same_json(before, ui.game.state), "overwrite waits for confirmation")
		await frames()
		for child in ui.get_children():
			if child is ConfirmationDialog:
				check(child.get_label().get_line_count() > 3, "confirmation body wraps")
				child.dialog_text += "\n" + "1234567890".repeat(8)
				await frames()
				print("CONFIRM ",dimensions," lines=",child.get_label().get_line_count()," rect=",child.get_label().get_rect()," text=",child.dialog_text)
				check(child.get_label().get_line_count() > 6, "unbroken confirmation text wraps")
				root.size = Vector2i(320, 640)
				await frames()
				check(child.position.x >= 0 and child.position.x + child.size.x <= root.size.x, "open confirmation fits after window narrows")
				check(child.get_label().get_visible_line_count() == child.get_label().get_line_count(), "confirmation text fully visible")
				check(child.get_label().get_rect().end.y <= child.get_ok_button().get_global_rect().position.y, "wrapped text stays above confirmation buttons")
				child.canceled.emit()
		root.size = dimensions
		await frames()
		check(not ui.modal_open and Contract.same_json(before, ui.game.state), "cancel keeps existing run")
		ui.game.transaction_pending = true
		ui.game.save_error = "测试保存失败"
		ui._show_title()
		await frames()
		check(ui.find_child("StartGame",true,false).disabled, "save failure blocks new run")
		ui.game.transaction_pending = false
		ui.game.save_error = ""
		root.remove_child(ui)
		ui.free()
		await frames()
	print("Main menu: %d checks, %d failures" % [checks, failures])
	quit(1 if failures else 0)
