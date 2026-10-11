extends SceneTree
const Screen = preload("res://scripts/ui/map_screen.gd")
const Core = preload("res://scripts/core/campaign_engine.gd")
const Art = preload("res://scripts/ui/runtime_art.gd")
const OUT := "res://build/verification/merchant/"

func _initialize() -> void:
	_run.call_deferred()

func _capture(name: String) -> void:
	for frame in 24: await process_frame
	await RenderingServer.frame_post_draw
	root.get_texture().get_image().save_png(OUT + name + ".png")

func _run() -> void:
	root.content_scale_mode = Window.CONTENT_SCALE_MODE_DISABLED
	root.content_scale_size = Vector2i.ZERO
	root.size = Vector2i(540, 960)
	DirAccess.make_dir_recursive_absolute(OUT)
	var ui := Screen.new()
	ui.game = Core.new("user://merchant_preview.json")
	ui.game.persistence_enabled = false
	root.add_child(ui)
	ui.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	ui.settings.muted = true
	ui.settings.reduce_motion = true
	assert(ui.game.start_phase3("42").is_empty())
	for number in [2, 3]:
		var exit_pos: Array = ui.game.floor_data().exit
		ui.game.state.position = exit_pos.duplicate()
		assert(ui.game.interact(Vector2i(exit_pos[0], exit_pos[1])).is_empty())
		assert(ui.game.confirm_interaction().is_empty())
	while not ui.game.story_event().is_empty(): ui.game.acknowledge_story()
	var merchant := {}
	for entity in ui.game.floor_data().entities.values():
		if entity.type == "shop": merchant = entity
	assert(not merchant.is_empty())
	assert(Art.entity_texture(merchant) != null)
	var cell := Vector2i(int(merchant.pos[0]), int(merchant.pos[1]))
	for offset in [Vector2i.DOWN, Vector2i.UP, Vector2i.LEFT, Vector2i.RIGHT]:
		var adjacent: Vector2i = cell + offset
		if not ui.game.is_wall(adjacent) and ui.game.entity_at(adjacent).is_empty():
			ui.game.state.position = [adjacent.x, adjacent.y]
			break
	ui.selected = cell
	ui._open_map()
	await _capture("merchant_map")
	ui.game.state.player.gold = 200
	ui.game.state.player.hp = 30
	ui.game.interact(cell)
	ui._render(true)
	assert(ui.find_child("MerchantPortrait", true, false) != null)
	await _capture("merchant_shop")
	root.min_size = Vector2i(320, 600)
	root.size = Vector2i(320, 600)
	ui._render(true)
	await _capture("merchant_shop_mobile")
	assert(ui.overlay_close.get_global_rect().end.y <= root.size.y)
	assert(ui.find_child("RewardChoices", true, false).get_global_rect().end.y <= ui.overlay_close.global_position.y)
	root.size = Vector2i(540, 960)
	for index in merchant.offers.size():
		assert(ui.game.buy(index).is_empty())
	ui._render(true)
	await _capture("merchant_sold_out")
	ui.game.cancel_pending()
	ui.game.state.position = [cell.x, cell.y]
	for offset in [Vector2i.DOWN, Vector2i.UP, Vector2i.LEFT, Vector2i.RIGHT]:
		var adjacent: Vector2i = cell + offset
		if not ui.game.is_wall(adjacent) and ui.game.entity_at(adjacent).is_empty():
			ui.game.state.position = [adjacent.x, adjacent.y]
			break
	ui._open_map()
	await _capture("merchant_map_sold_out")
	ui.free()
	print("Merchant production map, shop, mobile and sold-out captures completed.")
	quit()
