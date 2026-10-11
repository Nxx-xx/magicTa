extends SceneTree
const Screen = preload("res://scripts/ui/map_screen.gd")
const Core = preload("res://scripts/core/campaign_engine.gd")
const Layout = preload("res://scripts/core/camp_layout.gd")
const Progress = preload("res://scripts/core/campaign_progress.gd")
const P3Progress = preload("res://scripts/core/phase3_progress.gd")
const Store = preload("res://scripts/core/campaign_save.gd")
const Contract = preload("res://scripts/core/phase3_contract.gd")
const KnightArt = preload("res://scripts/ui/camp_knight_art.gd")
const DeathArt = preload("res://scripts/ui/camp_death_art.gd")
const OUT := "res://build/verification/phase3/08-parallel/art-polish-a/"
var checks := 0
var failures := 0
var capture := false
var ui

class RejectStore:
	extends RefCounted
	var last_error := "camp test save rejected"
	func write(_run: Dictionary,_meta: Dictionary) -> bool: return false

func _initialize() -> void: _run.call_deferred()

func check(ok: bool,label: String) -> void:
	checks += 1
	if not ok:
		failures += 1
		push_error("FAIL " + label)

func frames() -> void:
	for i in 8: await process_frame

func growth_overview() -> void:
	ui.camp_growth_level = 0
	ui._render(true)
	await frames()

func growth_action() -> Button:
	return ui.find_child("GrowthDetail",true,false)._action

func screenshot(label: String) -> void:
	if not capture: return
	await RenderingServer.frame_post_draw
	check(root.get_texture().get_image().save_png(OUT + label + ".png") == OK,"capture " + label)

func finish_walk(kind: String = "") -> void:
	for i in 150:
		if not is_instance_valid(ui.camp_map): break
		ui.camp_map.board._process(.06)
		if not is_instance_valid(ui.camp_map): break
		if ui.camp_map.route.is_empty() and not ui.camp_map.board.moving: break
	if not kind.is_empty(): check(ui.camp_view == kind,"arriving opens " + kind)

func mouse(position: Vector2,pressed: bool) -> void:
	var event := InputEventMouseButton.new()
	event.button_index = MOUSE_BUTTON_LEFT
	event.position = position
	event.pressed = pressed
	root.push_input(event)

func touch(position: Vector2,pressed: bool) -> void:
	var event := InputEventScreenTouch.new()
	event.index = 0
	event.position = position
	event.pressed = pressed
	root.push_input(event)

func _run() -> void:
	if not ProjectSettings.globalize_path("user://").replace("\\","/").contains("verification/phase3/08-parallel/art-polish-a/"):
		push_error("camp tests require isolated APPDATA")
		quit(2)
		return
	capture = "--capture" in OS.get_cmdline_user_args()
	DirAccess.make_dir_recursive_absolute(OUT)
	var knight_scene = load("res://assets/characters/mysterious_knight/source/mysterious_old_knight.tscn").instantiate()
	check(knight_scene is Node3D and knight_scene.get_node("AnimationPlayer").has_animation("idle"),"editable 3D knight model and idle animation load")
	knight_scene.free()
	check(KnightArt.PORTRAIT.get_image().get_pixel(0,0).a == 0,"model portrait has real transparent background")
	check(DeathArt.TEXTURE.get_image().get_pixel(0,0).a == 0,"Death sprite has real transparent background")
	check(not Layout.walkable(Layout.DEATH) and Layout.interaction(Layout.DEATH) == "death","Death occupies an interaction cell")
	for frame in KnightArt.FRAMES:
		check(frame.get_width() == 256 and frame.get_image().get_used_rect().size.y > 128,"baked model frame is present and nonempty")
	check(not Layout.walkable(Vector2i(2,6)) and not Layout.walkable(Vector2i(8,2)) and not Layout.walkable(Vector2i(9,5)) and not Layout.walkable(Vector2i(6,6)),"painted tents pond and fire ring block walking")
	var legacy_path := "user://legacy_camp_%d.json" % Time.get_ticks_usec()
	var legacy_meta := Progress.default_meta()
	legacy_meta.souls = 8
	legacy_meta.souls_earned_total = 16
	legacy_meta.upgrades.hp = 1
	legacy_meta.upgrade_spend.hp = 8
	var legacy_file := FileAccess.open(legacy_path,FileAccess.WRITE)
	legacy_file.store_string(JSON.stringify({"version":1,"run":{},"meta":legacy_meta}))
	legacy_file.close()
	var legacy = Core.new(legacy_path)
	legacy.load_game()
	check(legacy.meta.upgrades.hp == 1 and legacy.meta.souls == 8,"old account keeps purchased level and currency")
	check(Progress.initial_player(legacy.meta).hp == 105,"old account still uses original growth")
	check(legacy.purchase_upgrade("attack").is_empty() and Store.new(legacy_path).read().meta.upgrades.attack == 1,"old account can purchase and save through existing migration")
	for y in 11:
		for x in 11:
			var cell := Vector2i(x,y)
			if not Layout.walkable(cell): continue
			var previous := Layout.SPAWN
			var route := Layout.path(previous,cell)
			check(cell == previous or not route.is_empty(),"camp floor reachable %s" % cell)
			for step in route:
				check(Layout.walkable(step) and absi(step.x-previous.x)+absi(step.y-previous.y) == 1,"route avoids obstacles")
				previous = step
	for target in [Layout.KNIGHT,Layout.DEATH,Layout.TOWER]:
		var route := Layout.path(Layout.SPAWN,target)
		check(not route.is_empty() and absi(route.back().x-target.x)+absi(route.back().y-target.y) == 1,"approach interaction without stepping onto NPC/tower")
	check(Layout.path(Layout.SPAWN,Vector2i(0,0)).is_empty(),"wall rejected")
	for dimensions in [Vector2i(320,640),Vector2i(390,700),Vector2i(540,960),Vector2i(900,960)]:
		root.size = dimensions
		ui = Screen.new()
		ui.page = "menu"
		ui.game = Core.new("user://camp_ui_%d_%d.json" % [dimensions.x,Time.get_ticks_usec()])
		root.add_child(ui)
		ui.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
		await frames()
		ui.settings.muted = true
		ui.settings.reduce_motion = true
		check(ui.game.errors.is_empty(),"production content ready")
		check(is_instance_valid(ui.camp_map),"camp page shows camp map")
		var shortcuts := 0
		for button in ui.camp_map.find_children("*","Button",true,false):
			if button.text.begins_with("前往"): shortcuts += 1
		check(shortcuts == 0,"camp has no travel shortcut buttons")
		check(not ui.body.get_node("Camp_departure").visible,"departure accessed through tower")
		check(ui.scroll.get_h_scroll_bar().max_value <= ui.scroll.size.x+1,"camp width fits %d" % dimensions.x)
		await screenshot("camp_%d" % dimensions.x)
		check(ui.find_child("Phase3Departure",true,false) == null,"camp overview has no departure form")
		check(not ui.camp_map.hint.visible,"camp has no persistent instruction text")
		var saved_run: Dictionary = ui.game.state.duplicate(true)
		var board = ui.camp_map.board
		var goal := Vector2i(5,7)
		var point: Vector2 = board.global_position + board._origin()+(Vector2(goal)+Vector2.ONE*.5)*board._cell_size()
		mouse(point,true)
		mouse(point,false)
		finish_walk()
		check(ui.camp_position == goal,"mouse click walks to floor")
		check(Contract.same_json(saved_run,ui.game.state),"camp walk never changes tower run")
		board.set_overview(false)
		var scroll_before: int = ui.scroll.scroll_vertical
		var start: Vector2 = board.get_global_rect().get_center()
		mouse(start,true)
		var drag := InputEventMouseMotion.new()
		drag.position = start + Vector2(30,-40)
		drag.relative = Vector2(30,-40)
		drag.button_mask = MOUSE_BUTTON_MASK_LEFT
		root.push_input(drag)
		mouse(drag.position,false)
		check(not board.following and ui.scroll.scroll_vertical == scroll_before,"camp pan owns gesture without menu scroll")
		board.recenter()
		goal = Vector2i(5,6)
		point = board.global_position + board._origin()+(Vector2(goal)+Vector2.ONE*.5)*board._cell_size()
		touch(point,true)
		touch(point,false)
		finish_walk()
		check(ui.camp_position == goal,"native touch walks once along legal floor")
		# The overlaid view button must not also send the player walking.
		var toggle: Button = ui.find_child("CampViewToggle",true,false)
		var toggle_position: Vector2i = ui.camp_position
		point = toggle.get_global_rect().get_center()
		mouse(point,true)
		mouse(point,false)
		await frames()
		check(ui.camp_position == toggle_position and board.overview,"view overlay toggles without moving player")
		ui._confirm("camp test modal","背景地图应停止接收点击。",func(): pass)
		var stopped_position: Vector2i = ui.camp_position
		var blocked_goal := Vector2i(5,7)
		point = board.global_position + board._origin()+(Vector2(blocked_goal)+Vector2.ONE*.5)*board._cell_size()
		mouse(point,true)
		mouse(point,false)
		touch(point,true)
		touch(point,false)
		finish_walk()
		check(ui.camp_position == stopped_position,"modal blocks mouse and native touch on background camp")
		for child in ui.get_children():
			if child is ConfirmationDialog: child.canceled.emit()
		await frames()
		ui.camp_map.walk_to(Vector2i(2,8))
		ui.camp_map._notification(Node.NOTIFICATION_APPLICATION_FOCUS_OUT)
		check(ui.camp_map.route.is_empty() and ui.camp_map.destination.is_empty(),"focus loss cancels pending camp route")
		ui.camp_map.walk_to(Vector2i(2,8))
		ui.camp_map.walk_to(Layout.KNIGHT)
		check(ui.camp_map.destination == "knight","retarget during walking updates destination")
		board.set_overview(true)
		point = board.global_position+board.knight_rect().get_center()
		mouse(point,true)
		mouse(point,false)
		finish_walk("knight")
		await frames()
		check(ui.find_child("CampKnightDialogue",true,false) != null,"named knight dialogue exists")
		await screenshot("knight_%d" % dimensions.x)
		ui.camp_view = "growth"
		ui._render(true)
		await frames()
		check(ui.find_child("GrowthTree",true,false) != null,"three icon paths exist")
		check(ui.find_child("GrowthDetail",true,false) == null,"details hidden before node selection")
		check(ui.find_child("Purchase_hp",true,false) == null,"no purchase before selection")
		await screenshot("growth_overview_%d" % dimensions.x)
		var first_node: Button = ui.find_child("GrowthNode_hp_1",true,false)
		point = first_node.get_global_rect().get_center()
		mouse(point,true)
		mouse(point,false)
		await frames()
		check(ui.camp_growth_level == 1,"mouse click opens node details")
		var details: Control = ui.find_child("GrowthDetail",true,false)
		check(ui.scroll.get_global_rect().end.y >= details.get_global_rect().end.y - 2,"selected detail scrolls into view")
		await screenshot("growth_detail_%d" % dimensions.x)
		check(growth_action().disabled,"zero balance cannot buy")
		for kind in Progress.KINDS:
			await growth_overview()
			var locked: Button = ui.find_child("GrowthNode_%s_3" % kind,true,false)
			check(locked != null and locked.size.x >= 48,"all paths have touch-sized nodes")
			locked.pressed.emit()
			check(growth_action().disabled,"locked node only shows details")
		check(ui.game.meta.souls == 0 and ui.game.meta.upgrades.gold == 0,"selecting nodes never spends souls")
		await growth_overview()
		ui.find_child("GrowthNode_gold_1",true,false).pressed.emit()
		check(ui.scroll.get_h_scroll_bar().max_value <= ui.scroll.size.x+1,"growth width fits %d" % dimensions.x)
		ui.game.meta.souls = 100
		ui.game.meta.souls_earned_total = 100
		check(ui.game.save_game(),"isolated funded account saves")
		ui._render(true)
		ui._camp_purchase("gold")
		check(ui.game.meta.upgrades.gold == 1 and ui.game.meta.souls == 92,"purchase uses existing fee and level")
		check(ui.camp_view == "growth" and ui.camp_upgrade_tab == 2,"purchase preserves NPC and selected path")
		var saved := Store.new(ui.game.store.path).read()
		check(not saved.is_empty() and saved.meta.upgrades.gold == 1,"purchase persisted")
		await frames()
		await screenshot("growth_%d" % dimensions.x)
		var original_store = ui.game.store
		await growth_overview()
		ui.find_child("GrowthNode_gold_2",true,false).pressed.emit()
		ui.game.store = RejectStore.new()
		ui._camp_purchase("gold")
		check(ui.game.transaction_pending and ui.game.meta.upgrades.gold == 1 and ui.game.meta.souls == 92,"failed purchase rolls back visible balance")
		check(growth_action().disabled,"save-pending blocks another purchase")
		ui.game.store = original_store
		check(ui.game.retry_save() and ui.game.meta.upgrades.gold == 2 and ui.game.meta.souls == 76,"retry commits pending purchase once")
		check(ui.game.reset_upgrades().is_empty() and ui.game.meta.souls == 100 and ui.game.meta.upgrades.gold == 0,"reset refunds existing total")
		for level in 3: check(ui.game.purchase_upgrade("hp").is_empty(),"purchase each sequential level")
		check(ui.game.meta.souls == 52 and ui.game.meta.upgrades.hp == 3,"full path costs 8+16+24")
		check(not ui.game.purchase_upgrade("hp").is_empty(),"max level rejected")
		ui.camp_upgrade_tab = 0
		ui._render(true)
		check(ui.find_child("Purchase_hp",true,false) == null,"full path has no fourth purchase")
		check(ui.game.reset_upgrades().is_empty() and ui.game.meta.souls == 100,"full path reset refund")
		ui.camp_upgrade_tab = 2
		ui.camp_growth_level = 1
		ui.camp_view = ""
		ui._render(true)
		await frames()
		point = ui.camp_map.board.global_position+ui.camp_map.board.death_rect().get_center()
		touch(point,true)
		touch(point,false)
		finish_walk("death")
		await frames()
		var choices = ui.find_child("Phase3Departure",true,false)
		check(choices != null and choices.preparation_only,"Death opens preparation rather than starting a run")
		check(not is_instance_valid(choices.seed_input) and choices._challenge.is_item_disabled(1),"Death has no seed input and locked difficulty stays locked")
		check(ui.scroll.get_h_scroll_bar().max_value <= ui.scroll.size.x+1,"Death dialogue fits %d" % dimensions.x)
		check(choices._start.get_global_rect().end.y <= ui.scroll.get_global_rect().end.y,"confirm preparation stays visible on narrow screens")
		await screenshot("death_%d" % dimensions.x)
		choices._start.pressed.emit()
		await frames()
		check(ui.camp_view.is_empty() and not ui.game.active(),"confirm returns to camp without starting a run")
		ui.game.meta = P3Progress.migrate_meta(ui.game.meta)
		ui.game.meta.unlocked_ids.append_array(["p3_c1","p3_vanguard"])
		ui._camp_interact("death")
		await frames()
		choices = ui.find_child("Phase3Departure",true,false)
		check(not is_instance_valid(choices.seed_input),"reopening Death does not create seed input")
		check(choices.select_ids("p3_c1","p3_vanguard").ok,"unlocked challenge and loadout can be prepared")
		ui._render(true)
		await frames()
		choices = ui.find_child("Phase3Departure",true,false)
		check(choices.challenge_id == "p3_c1" and choices.config_id == "p3_vanguard","preparation survives UI reconstruction")
		choices._start.pressed.emit()
		await frames()
		point = ui.camp_map.board.global_position+ui.camp_map.board.tower_rect().get_center()
		touch(point,true)
		touch(point,false)
		finish_walk("tower")
		await frames()
		check(ui.body.get_node("Camp_departure").is_visible_in_tree(),"tower arrival opens departure")
		check(ui.find_child("Phase3Departure",true,false) == null,"tower does not duplicate Death configuration")
		await screenshot("tower_%d" % dimensions.x)
		ui.find_child("CampStartJourney",true,false).pressed.emit()
		await frames()
		check(ui.page == "map" and ui.game.is_phase3() and ui.overlay_kind == "story","tower entry starts real phase3 story")
		check(ui.camp_view.is_empty(),"returning from tower will restore camp map")
		check(str(ui.game.state.seed).is_valid_int(),"tower generates a random journey seed")
		check(ui.game.state.challenge_id == "p3_c1" and ui.game.state.start_config_snapshot.id == "p3_vanguard","tower uses prepared challenge and loadout")
		var committed: Dictionary = ui.game.state.duplicate(true)
		ui._show_camp("death")
		await frames()
		choices = ui.find_child("Phase3Departure",true,false)
		choices._start.pressed.emit()
		await frames()
		check(Contract.same_json(committed,ui.game.state),"preparing next journey leaves active run unchanged")
		ui._camp_interact("tower")
		ui.find_child("CampStartJourney",true,false).pressed.emit()
		check(ui.modal_open,"starting over still requires abandoning active journey confirmation")
		for child in ui.get_children():
			if child is ConfirmationDialog: child.canceled.emit()
		check(Contract.same_json(committed,ui.game.state),"cancel keeps active run")
		for button in ui.body.find_children("*","Button",true,false):
			if button.text.begins_with("继续探索"):
				button.pressed.emit()
				break
		await frames()
		check(ui.page == "map" and Contract.same_json(committed,ui.game.state),"continue preserves existing journey")
		ui.page = "menu"
		ui.camp_view = "growth"
		ui._render(true)
		await frames()
		check(growth_action().disabled,"active journey prevents growth change")
		check(not ui.game.purchase_upgrade("hp").is_empty() and Contract.same_json(committed,ui.game.state),"active journey snapshot unchanged")
		ui.queue_free()
		await frames()
	print("CAMP MAP: %d checks, %d failures" % [checks,failures])
	quit(1 if failures else 0)
