extends SceneTree
const Screen = preload("res://scripts/ui/map_screen.gd")
const Core = preload("res://scripts/core/campaign_engine.gd")
var out := "res://build/verification/npc-polish/before/"
var ui
var checks := 0
var motion_checks := 0

func _tap(widget: Control) -> void:
	await _touch_at(widget.get_global_rect().get_center())

func _touch_at(point: Vector2) -> void:
	for pressed in [true,false]:
		var event := InputEventScreenTouch.new()
		event.index = 0
		event.position = point
		event.pressed = pressed
		Input.parse_input_event(event)
		await process_frame
	await _frames()

func _portrait_motion(portrait: Control, label: String) -> void:
	assert(portrait.mouse_filter == Control.MOUSE_FILTER_IGNORE)
	var snapshot: Dictionary = ui.game.state.duplicate(true)
	ui.settings.reduce_motion = true
	await _frames()
	await RenderingServer.frame_post_draw
	var rect := Rect2i(portrait.get_global_rect())
	var still := root.get_texture().get_image().get_region(rect)
	await create_timer(.3).timeout
	await RenderingServer.frame_post_draw
	assert(still.get_data() == root.get_texture().get_image().get_region(rect).get_data(),label+" reduced motion is static")
	ui.settings.reduce_motion = false
	portrait.seconds = .5
	await _frames()
	await _capture(label+"_motion_a")
	var moving := root.get_texture().get_image().get_region(rect)
	portrait.seconds = 2.4
	await _frames()
	await _capture(label+"_motion_b")
	assert(moving.get_data() != root.get_texture().get_image().get_region(rect).get_data(),label+" motion renders")
	assert(ui.game.state == snapshot,label+" presentation cannot alter gameplay")
	ui.settings.reduce_motion = true
	await _frames()
	await RenderingServer.frame_post_draw
	assert(still.get_data() == root.get_texture().get_image().get_region(rect).get_data(),label+" live preference returns to neutral")
	motion_checks += 4

func _initialize() -> void:
	create_timer(90).timeout.connect(func(): push_error("FAIL: NPC capture timed out"); quit(1))
	_run.call_deferred()
func _frames() -> void:
	for i in 12: await process_frame
func _capture(label: String) -> void:
	await RenderingServer.frame_post_draw
	assert(root.get_texture().get_image().save_png(out+label+".png") == OK)
	checks += 1
func _run() -> void:
	assert(ProjectSettings.globalize_path("user://").replace("\\","/").contains("verification/npc-polish/"))
	if "--after" in OS.get_cmdline_user_args(): out = out.replace("/before/","/after/")
	DirAccess.make_dir_recursive_absolute(out)
	root.gui_embed_subwindows = true
	root.min_size = Vector2i(320,600)
	for dimensions in [Vector2i(320,600),Vector2i(390,700),Vector2i(540,960)]:
		root.size = dimensions
		ui = Screen.new()
		ui.page = "menu"
		ui.game = Core.new("user://npc_%d_%d.json" % [dimensions.x,Time.get_ticks_usec()])
		ui.game.persistence_enabled = false
		root.add_child(ui)
		ui.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
		await _frames()
		ui.settings.muted = true
		ui.settings.reduce_motion = true
		ui.camp_map.board.reduce_motion = true
		ui.camp_map.board.following = false
		ui.camp_map.board.camera_center = Vector2(5.5,5.5)
		ui.camp_map.board.camera_target = Vector2(5.5,5.5)
		ui.camp_map.board.queue_redraw()
		await _frames()
		await _capture("camp_%d" % dimensions.x)
		if out.contains("/after/") and not "--baseline-packed" in OS.get_cmdline_user_args():
			ui.camp_map.board.camera_center = Vector2(7,4)
			ui.camp_map.board.camera_target = Vector2(7,4)
			ui.camp_map.board.queue_redraw()
			await _frames()
			await _capture("camp_death_near_%d" % dimensions.x)
			if dimensions.x == 390:
				var board = ui.camp_map.board
				var region := Rect2i(board.death_rect().grow(2))
				region.position += Vector2i(board.global_position)
				await RenderingServer.frame_post_draw
				var still := root.get_texture().get_image().get_region(region)
				board.idle_seconds = 1.0
				board.queue_redraw()
				await _frames()
				await RenderingServer.frame_post_draw
				assert(still.get_data() == root.get_texture().get_image().get_region(region).get_data(),"camp death reduced motion")
				board.reduce_motion = false
				board.idle_seconds = 2.8
				await _frames()
				await _capture("camp_death_motion")
				assert(still.get_data() != root.get_texture().get_image().get_region(region).get_data(),"camp death mesh animates")
				board.reduce_motion = true
				motion_checks += 2
		if out.contains("/after/") and not "--baseline-packed" in OS.get_cmdline_user_args():
			var board = ui.camp_map.board
			await _touch_at(board.global_position+board.death_rect().get_center())
			for step in 200:
				if not is_instance_valid(ui.camp_map): break
				ui.camp_map.board._process(.06)
			assert(ui.camp_view == "death","native touch on visible death walks to NPC and opens preparation")
		else:
			ui._camp_interact("death")
		await _frames()
		await _capture("death_%d" % dimensions.x)
		if out.contains("/after/") and not "--baseline-packed" in OS.get_cmdline_user_args():
			# Apply the separate integration patch only to this live test tree.
			# The owned campaign_panels.gd source remains untouched.
			var panel = ui.find_child("CampDeathDialogue",true,false)
			var old = panel.find_children("*","TextureRect",true,false)[0]
			var heading = old.get_parent()
			heading.remove_child(old)
			old.queue_free()
			var portrait = preload("res://scripts/ui/camp_death_art.gd").portrait(ui.settings)
			heading.add_child(portrait)
			heading.move_child(portrait,0)
			await _frames()
			await _capture("death_integration_preview_%d" % dimensions.x)
			assert(ui.body.size.y <= ui.scroll.size.y+1,"death close-up fits phone")
			var choices = ui.find_child("Phase3Departure",true,false)
			await _tap(choices._challenge)
			assert(choices._challenge.get_popup().visible,"death portrait leaves touch selector available")
			choices._challenge.get_popup().hide()
			if dimensions.x == 390: await _portrait_motion(portrait,"death_preview")
		ui._start_phase3("42")
		while not ui._story_event().is_empty(): ui._finish_story()
		ui._tutorial_event({"type":"skip_all"})
		var floor_map: Dictionary = ui.game.campaign_generator.generate(ui.game.state.campaign_plan,3,"battle","")
		ui.game.state.floors["3"] = floor_map
		ui.game.state.floor = 3
		var merchant: Dictionary = {}
		for entity in floor_map.entities.values():
			if entity.type == "shop": merchant = entity
		assert(not merchant.is_empty())
		ui.game.state.position = merchant.pos.duplicate()
		ui.game.state.player.gold = 500
		assert(ui.game.interact(Vector2i(merchant.pos[0],merchant.pos[1])).is_empty())
		ui._render(true)
		await _frames()
		await _capture("shop_%d" % dimensions.x)
		assert(ui.find_child("MerchantPortrait",true,false) != null)
		if out.contains("/after/"):
			print("SHOP LAYOUT %s: body=%s scroll=%s" % [dimensions,ui.body.size,ui.scroll.size])
			assert(ui.body.size.y <= ui.scroll.size.y+1,"shop contents fit without clipped overflow")
			assert(Rect2(Vector2.ZERO,Vector2(dimensions)).encloses(ui.find_child("MerchantPortrait",true,false).get_global_rect()),"shop close-up fits phone")
			if dimensions.x == 390 and not "--baseline-packed" in OS.get_cmdline_user_args(): await _portrait_motion(ui.find_child("MerchantPortrait",true,false),"merchant")
			var reward = ui.find_child("RewardChoices",true,false)
			await _tap(reward._buttons["0"])
			assert(reward._action != null and reward._action.is_visible_in_tree(),"touch opens offer details")
			assert(Rect2(Vector2.ZERO,Vector2(dimensions)).encloses(reward._action.get_global_rect()),"purchase action fits phone")
			await _capture("shop_detail_%d" % dimensions.x)
			var price := int(ui.game.shop_offer(str(merchant.offers[0])).price)
			await _tap(reward._action)
			assert(int(ui.game.state.player.gold) == 500-price,"touch purchase exact price")
			assert(ui.game.shop_offer_sold(merchant,str(merchant.offers[0])),"touch purchase marks only selected stock")
			var snapshot: Dictionary = ui.game.state.duplicate(true)
			assert(not ui.game.buy(0).is_empty() and ui.game.state == snapshot,"repeat purchase cannot charge twice")
		ui.queue_free()
		await _frames()
	print("NPC CAPTURE: %d captures; %d motion invariants; native touch shop purchases at 320/390/540; death picking/selector tested in after runs" % [checks,motion_checks])
	quit()
