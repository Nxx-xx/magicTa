extends SceneTree

const Screen = preload("res://scripts/ui/map_screen.gd")
const Core = preload("res://scripts/core/campaign_engine.gd")
const LegacyCore = preload("res://tests/legacy_map_core_fixture.gd")
const ItemIcon = preload("res://scripts/ui/item_icon.gd")
var checks := 0
var failures := 0

class RejectStore:
	extends RefCounted
	var last_error := "Chest test: save rejected"
	func write(_run: Dictionary, _meta: Dictionary) -> bool: return false

func _initialize() -> void: _run.call_deferred()

func check(ok: bool, label: String) -> void:
	checks += 1
	if not ok:
		failures += 1
		push_error("FAIL: " + label)

func frames() -> void:
	for i in 8: await process_frame

func copy(node: Node) -> String:
	var value := str(node.text) + "\n" if node is Label or node is Button else ""
	for child in node.get_children(): value += copy(child)
	return value

func fixture(ui, item_id: String, gold: int) -> void:
	ui.game.state.position = [2,5]
	ui.game.state.pending = {}
	ui.game.floor_data().entities.clear()
	for y in range(1,10): ui.game.floor_data().rows[y] = "#.........#"
	ui.game.floor_data().entities["3,5"] = {"id":"test_chest", "type":"chest", "name":"宝箱", "pos":[3,5], "item_id":item_id, "gold":gold}
	ui.game.save_game()
	ui._render(true)

func _run() -> void:
	root.min_size = Vector2i(320,640)
	for mode in ["legacy", "campaign", "phase3"]:
		for dimensions in [Vector2i(320,640), Vector2i(540,960)]:
			root.size = dimensions
			var ui = Screen.new()
			var path := "user://chest_test_%d.json" % Time.get_ticks_usec()
			ui.game = LegacyCore.new(path) if mode == "legacy" else Core.new(path)
			ui.game.persistence_enabled = false
			root.add_child(ui)
			ui.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
			ui.settings.muted = true
			ui.settings.reduce_motion = true
			var result: String
			match mode:
				"legacy": result = ui.game.start("42")
				"campaign": result = ui.game.start_campaign("42")
				_: result = ui.game.start_phase3("42")
			check(result.is_empty(), "start " + mode + ": " + result)
			if not result.is_empty():
				ui.queue_free()
				await frames()
				continue
			while not ui.game.story_event().is_empty(): ui.game.acknowledge_story()
			ui._open_map()
			var item_id := "iron_sword"
			if mode == "phase3":
				for id in ui.game.db.data.items:
					if ui.game.db.item(id).kind == "equipment":
						item_id = id
						break
			fixture(ui, item_id, 17)
			await frames()
			var before: int = ui.game.state.player.gold
			ui.held_move_keys.append(KEY_RIGHT)
			ui._move_direction(Vector2i.RIGHT)
			await frames()
			check(ui.overlay_kind == "chest_reward" and ui.overlay.visible, "opening chest shows receipt " + mode)
			var text := copy(ui.body)
			check(text.contains(ui.game.db.item(item_id).name) and text.contains(ui.game.db.item(item_id).description) and text.contains("金币 +17"), "receipt identifies item, effect and gold")
			check(ui.body.find_children("*", "Control", true, false).any(func(child): return child is ItemIcon), "receipt includes item icon")
			check(not ui._can_walk() and ui.held_move_keys.is_empty(), "receipt blocks walking and clears held input")
			check(ui.game.state.player.gold == before + 17 and ui.game.entity_at(Vector2i(3,5)).is_empty(), "reward granted exactly once")
			check(ui.overlay_panel.get_global_rect().end.x <= dimensions.x and ui.overlay_panel.get_global_rect().end.y <= dimensions.y, "receipt fits viewport")
			check(ui.overlay_close.is_visible_in_tree() and ui.overlay_close.get_global_rect().end.y <= dimensions.y, "continue action remains visible")
			if mode == "phase3" and dimensions.x == 540 and "--capture" in OS.get_cmdline_user_args():
				await RenderingServer.frame_post_draw
				root.get_texture().get_image().save_png("res://build/verification/chest-reward/popup.png")
			var story_waiting: bool = not ui.game.story_event().is_empty()
			ui.overlay_close.pressed.emit()
			await frames()
			check(ui.chest_receipt.is_empty() and ui.overlay_kind == ("story" if story_waiting else ""), "dismiss receipt before queued story")
			while not ui.game.story_event().is_empty(): ui._finish_story()
			ui._act(func(): return ui.game.interact(Vector2i(3,5)))
			check(ui.overlay_kind == "" and ui.game.state.player.gold == before + 17, "revisit does not repeat reward")
			fixture(ui, "missing_item", 17)
			ui._act(func(): return ui.game.interact(Vector2i(3,5)))
			check(ui.chest_receipt.is_empty() and ui.overlay_kind == "" and not ui.notice.is_empty(), "invalid reward never shows success")
			fixture(ui, item_id, 0)
			var store = ui.game.store
			ui.game.store = RejectStore.new()
			ui.game.persistence_enabled = true
			ui._act(func(): return ui.game.interact(Vector2i(3,5)))
			check(ui.overlay_kind == "save_blocked" and not ui.chest_receipt.is_empty(), "failed save defers receipt")
			ui.game.store = store
			ui.game.persistence_enabled = false
			ui._retry_save()
			await frames()
			check(ui.overlay_kind == "chest_reward" and not copy(ui.body).contains("金币 +0"), "save retry shows receipt without zero gold noise")
			ui._close_overlay()
			ui.queue_free()
			await frames()
	print("Chest reward UI: %d checks, %d failures" % [checks, failures])
	quit(1 if failures else 0)
