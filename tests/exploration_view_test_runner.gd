extends SceneTree
const Screen = preload("res://scripts/ui/map_screen.gd")
const Core = preload("res://scripts/core/campaign_engine.gd")
var checks := 0
var failures := 0
var capture := false
const OUT := "res://build/verification/exploration-view/"

func _initialize() -> void: _run.call_deferred()

func _check(ok: bool, label: String) -> void:
	checks += 1
	if not ok:
		failures += 1
		push_error("FAIL: " + label)

func _frames() -> void:
	for i in 8: await process_frame

func _capture(label: String) -> void:
	if not capture: return
	await RenderingServer.frame_post_draw
	_check(root.get_texture().get_image().save_png(OUT + label + ".png") == OK, "capture " + label)

func _centered(ui) -> bool:
	var point: Vector2 = ui.board._origin() + (ui.board.hero_visual + Vector2.ONE * 0.5) * ui.board._cell_size()
	return point.distance_to(ui.board.size * 0.5) < 1

func _run() -> void:
	if not "exploration-view" in ProjectSettings.globalize_path("user://"):
		quit(2)
		return
	capture = "--capture" in OS.get_cmdline_user_args()
	DirAccess.make_dir_recursive_absolute(OUT)
	root.min_size = Vector2i.ZERO
	for dimensions in [Vector2i(320,640), Vector2i(390,700), Vector2i(540,960), Vector2i(900,960)]:
		root.size = dimensions
		var ui = Screen.new()
		ui.game = Core.new("user://view_%d.json" % dimensions.x)
		ui.game.persistence_enabled = false
		root.add_child(ui)
		ui.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
		await _frames()
		ui.settings.muted = true
		ui._start_phase3("42")
		while not ui._story_event().is_empty(): ui._finish_story()
		ui._tutorial_event({"type":"skip_all"})
		await _frames()
		_check(not ui.detail_panel.visible and ui.overlay_kind == "", "new run has no automatic detail")
		_check(_centered(ui), "entry centers hero")
		_check(ui.board.get_global_rect().encloses(ui.minimap.get_global_rect()), "minimap fits board")
		await _capture("entry_%d" % dimensions.x)
		# Use the real stair transaction in both directions, with the normal host refresh.
		var exit_cell: Array = ui.game.floor_data().exit
		ui.game.state.position = exit_cell.duplicate()
		ui._act(func(): return ui.game.interact(ui.game.position()))
		_check(ui.overlay_kind == "pending", "stairs still require confirmation")
		ui._act(func(): return ui.game.confirm_interaction())
		while not ui._story_event().is_empty(): ui._finish_story()
		await _frames()
		_check(int(ui.game.state.floor) == 2, "ascended through real staircase")
		_check(not ui.detail_panel.visible and ui.overlay_kind == "", "arrival stair has no detail card")
		_check(_centered(ui), "new floor centers hero")
		await _capture("floor2_%d" % dimensions.x)
		ui._act(func(): return ui.game.interact(ui.game.position()))
		ui._act(func(): return ui.game.confirm_interaction())
		await _frames()
		_check(int(ui.game.state.floor) == 1 and not ui.detail_panel.visible, "descending also hides arrival detail")
		# Verify every rendered movement sample, including normal/reduced motion.
		ui.game.floor_data().entities.clear()
		for y in range(1,10): ui.game.floor_data().rows[y] = "#.........#"
		ui.game.state.position = [5,5]
		ui._refresh_map()
		await _frames()
		for reduced in [false,true]:
			ui.settings.reduce_motion = reduced
			ui._select_cell(ui.game.position() + Vector2i.RIGHT)
			while ui.board.moving:
				await process_frame
				_check(_centered(ui), "animated hero stays centered")
		await _capture("near_%d" % dimensions.x)
		ui._toggle_overview()
		await _frames()
		_check(not ui.minimap.visible, "overview hides redundant minimap")
		await _capture("overview_%d" % dimensions.x)
		ui._toggle_overview()
		ui._open_overlay("inventory")
		await _frames()
		_check(not ui.minimap.visible and ui.minimap.disabled, "overlay blocks minimap")
		ui._close_overlay()
		await _frames()
		_check(ui.minimap.visible and _centered(ui), "closing overlay restores centered exploration")
		ui.queue_free()
		await _frames()
	print("EXPLORATION VIEW: %d checks, %d failures" % [checks,failures])
	quit(0 if failures == 0 else 1)
