extends "res://tests/compact_screens_test_runner.gd"
const Registry = preload("res://scripts/ui/item_icon_registry.gd")
const Art = preload("res://scripts/ui/runtime_art.gd")
const Icon = preload("res://scripts/ui/item_icon.gd")
const ICON_DIR := "res://build/verification/item-icons/"

func _snap(label: String) -> void:
	if not capture: return
	await RenderingServer.frame_post_draw
	_check(root.get_texture().get_image().save_png(ICON_DIR+label+".png") == OK,"capture "+label)

func _click_item(panel, id: String, expected: String) -> void:
	var button: Button = panel.option_button(id)
	var before: Dictionary = ui.game.state.duplicate(true)
	var icons := button.find_children("*", "Control", true, false).filter(func(node): return node.get_script() == Icon)
	_check(icons.size() == 1, "one icon in " + expected)
	if icons.is_empty(): return
	_check(icons[0].item.id == expected, "overview identity " + expected)
	for pressed in [true,false]:
		var event := InputEventMouseButton.new()
		event.button_index = MOUSE_BUTTON_LEFT
		event.pressed = pressed
		event.position = icons[0].get_global_rect().get_center()
		root.push_input(event)
	await _frames()
	_check(panel._selected == id, "real icon click " + expected)
	var detail = panel.find_child("DetailItemIcon",true,false)
	_check(detail != null and detail.item.id == expected, "detail identity " + expected)
	_check(Contract.same_json(before,ui.game.state), "inspection immutable " + expected)
	_check("".join(panel._pages) == panel._full_text, "lossless details " + expected)
	_fits(expected)
	if expected in ["hunter_bow","iron_armor","p3_lantern_aegis"]: await _snap(expected+"_detail_"+str(root.size.x))
	panel.show_overview()
	await _frames()

func _run() -> void:
	if not ProjectSettings.globalize_path("user://").replace("\\","/").contains("verification/item-icons/"):
		quit(2)
		return
	capture = "--capture" in OS.get_cmdline_user_args()
	DirAccess.make_dir_recursive_absolute(ICON_DIR)
	root.min_size = Vector2i(320,600)
	for dimensions in [Vector2i(320,600),Vector2i(360,640)]:
		root.size = dimensions
		ui = Screen.new()
		ui.game = Core.new("user://icons.json")
		ui.game.persistence_enabled = false
		root.add_child(ui)
		ui.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
		await _frames()
		ui.settings.muted = true
		ui.settings.reduce_motion = true
		ui._start_phase3("42")
		while not ui._story_event().is_empty(): ui._finish_story()
		_check(ui.game.db.data.items.size() == Registry.PATHS.size(),"all items registered")
		for id in ui.game.db.data.items:
			var item: Dictionary = ui.game.db.item(id)
			_check(Registry.PATHS.has(id),"registered " + id)
			var texture := Art.texture(Registry.path_for(item))
			_check(texture != null and texture.get_size() == Vector2(128,128),"loaded " + id)
			var field := "relic_ids" if item.kind == "relic" else "equipment_ids"
			ui.game.state.player[field].append(id)
		_check(Registry.path_for({"id":"unknown"}).is_empty(),"unknown fallback")
		ui.game.meta.codex.seen_items = ui.game.db.data.items.keys()
		ui._open_overlay("inventory")
		await _frames()
		var inventory = ui.find_child("InventoryCatalog",true,false)
		for category in 2:
			inventory.category_index = category
			inventory._entries = inventory.categories[category].entries.duplicate(true)
			for page in ceili(inventory._entries.size()/4.0):
				inventory._list_page = page
				inventory.show_overview()
				await _frames()
				_fits("inventory")
				await _snap("inventory_%d_%d_%d" % [dimensions.x,category,page])
				for id in inventory._buttons.keys(): await _click_item(inventory,id,id)
		ui._close_overlay()
		ui._open_section("codex")
		await _frames()
		var codex = ui.body.get_child(0)
		codex.show_category("items")
		for page in ceili(codex._entries.size()/4.0):
			codex._list_page = page
			codex.show_overview()
			await _frames()
			for id in codex._buttons.keys():
				var entry: Dictionary = codex._entries[int(id)]
				await _click_item(codex,id,entry.item.id)
		ui._open_map()
		var cell: Vector2i = ui.game.position()
		for kind in ["shop","choice"]:
			var fixture := {"id":"icons-reward","type":kind,"name":"图标验证","pos":[cell.x,cell.y],"offers":["buy_bow","buy_armor","buy_shield"],"choices":["blood_sword","stone_heart","p3_rhythm_blade"],"gold":25}
			ui.game.floor_data().entities[Core.cell_key(cell)] = fixture
			ui.game.state.pending = {"kind":"entity","pos":[cell.x,cell.y]}
			ui._render(true)
			await _frames()
			var panel = ui.find_child("RewardChoices",true,false)
			await _snap(kind+"_"+str(dimensions.x))
			for entry in panel._entries:
				await _click_item(panel,str(entry.id),str(entry.item.id))
		root.remove_child(ui)
		ui.queue_free()
		await _frames()
	print("ITEM_ICONS_UI checks=%d failures=%d" % [checks,failures])
	quit(1 if failures else 0)
