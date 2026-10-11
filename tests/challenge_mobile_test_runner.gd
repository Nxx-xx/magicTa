extends "res://tests/phase3_ui_host_test_runner.gd"
const DIR := "res://build/verification/challenge-mobile/"

func _pointer_event(position: Vector2, pressed: bool) -> void:
	var event := InputEventMouseButton.new()
	event.button_index = MOUSE_BUTTON_LEFT
	event.pressed = pressed
	event.position = position
	Input.parse_input_event(event)

func _click(widget: Control) -> void:
	for pressed in [true, false]:
		_pointer_event(widget.get_global_rect().get_center(), pressed)
		await process_frame
	await _frames()

func _popup_fits(popup: PopupMenu, label: String) -> void:
	var bounds := Rect2(Vector2(popup.position), Vector2(popup.size))
	_check(Rect2(Vector2.ZERO, root.get_visible_rect().size).encloses(bounds), label + " popup fits viewport: " + str(bounds))
	_check(popup.size.y <= 200, label + " popup has compact, touch-sized rows")

func _choose(widget: OptionButton, index: int) -> void:
	await _click(widget)
	var popup := widget.get_popup()
	_check(popup.visible, "tap opens selector")
	_popup_fits(popup, str(widget.get_item_metadata(index)))
	# Use the actual menu input path rather than manually emitting item_selected.
	await create_timer(0.25).timeout
	var position := Vector2(popup.size.x / 2.0, 4 + 44 * index + 22)
	var motion := InputEventMouseMotion.new()
	motion.position = position
	motion.position += Vector2(popup.position)
	Input.parse_input_event(motion)
	for pressed in [true, false]:
		_pointer_event(position + Vector2(popup.position), pressed)
		await process_frame
	await _frames()
	_check(widget.selected == index, "tap selects " + str(widget.get_item_metadata(index)))
	_check(not popup.visible, "selection closes popup")
	popup.hide()

func _run() -> void:
	if not ProjectSettings.globalize_path("user://").replace("\\", "/").contains("verification/challenge-mobile/"):
		quit(2)
		return
	DirAccess.make_dir_recursive_absolute(DIR)
	root.gui_embed_subwindows = true
	root.min_size = Vector2i(320,600)
	for dimensions in [Vector2i(320,600),Vector2i(360,640),Vector2i(390,844),Vector2i(540,960)]:
		root.size = dimensions
		ui = Screen.new()
		ui.game = Core.new("user://challenge_%d.json" % dimensions.x)
		ui.game.persistence_enabled = false
		root.add_child(ui)
		ui.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
		await _frames()
		ui.settings.muted = true
		ui._show_camp("death")
		await _frames()
		var choices = ui.find_child("Phase3Departure",true,false)
		_check(choices._challenge.is_item_disabled(1), "fresh account keeps C1 locked")
		_check(choices._config.is_item_disabled(1), "fresh account keeps vanguard locked")
		for widget in [choices._challenge, choices._config]:
			await _click(widget)
			_check(widget.get_popup().visible, "fresh account can open choices")
			_popup_fits(widget.get_popup(), "locked choices")
			widget.get_popup().hide()
		await _click(choices.find_child("PreparationDetails",true,false))
		_check(choices._details.visible, "tap opens unlock details")
		_check(choices._details._full_text.contains("解锁条件：通关标准旅程。"), "difficulty unlock requirement visible without hover")
		_check(choices._details._full_text.contains("击败第五层牛头"), "config unlock requirement included")
		_check("".join(choices._details._pages) == choices._details._full_text, "paged details preserve all conditions")
		_check(ui.body.size.y <= ui.scroll.size.y + 1, "details fit small phone")
		choices.back_to_overview()
		ui.game.meta = choices.account.duplicate(true)
		ui.game.meta.unlocked_ids.append_array(["p3_c1", "p3_c2", "p3_vanguard", "p3_keeper", "p3_trader"])
		ui._render(true)
		await _frames()
		choices = ui.find_child("Phase3Departure",true,false)
		for index in [1,2,0]:
			await _choose(choices._challenge,index)
			_check(ui.phase3_challenge == choices._challenge.get_item_metadata(index), "host receives challenge selection")
		for index in [1,2,3,0]:
			await _choose(choices._config,index)
			_check(ui.phase3_config == choices._config.get_item_metadata(index), "host receives config selection")
		await _choose(choices._challenge,1)
		await _choose(choices._config,1)
		_check(choices.selection.player.attack == 12, "selected config updates player preview")
		_check(ui.body.size.y <= ui.scroll.size.y + 1, "preparation fits phone")
		if "--capture" in OS.get_cmdline_user_args():
			await _click(choices._config)
			await RenderingServer.frame_post_draw
			root.get_texture().get_image().save_png(DIR + "config_%d.png" % dimensions.x)
			choices._config.get_popup().hide()
		await _click(choices._start)
		_check(ui.camp_view.is_empty(), "confirm returns to camp")
		ui._show_camp("death")
		await _frames()
		choices = ui.find_child("Phase3Departure",true,false)
		_check(choices.challenge_id == "p3_c1" and choices.config_id == "p3_vanguard", "choices survive reopening")
		ui.queue_free()
		await _frames()
	print("CHALLENGE MOBILE: %d checks, %d failures" % [checks, failures])
	quit(0 if failures == 0 else 1)


