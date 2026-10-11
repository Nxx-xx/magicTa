extends "res://tests/campaign_test_runner.gd"
## Render checkpoints obtained through a real zero-upgrade production route.
const Screen = preload("res://scripts/ui/map_screen.gd")
var checkpoints: Dictionary = {}

func _initialize() -> void:
	_capture_journey.call_deferred()

func _reload(core, label: String):
	var resumed = super._reload(core, label)
	if label == "Boss pending confirmation":
		checkpoints[str(int(core.state.floor))] = {"run":core.state.duplicate(true), "meta":core.meta.duplicate(true)}
	return resumed

func _frames() -> void:
	for i in 6:
		await process_frame

func _shot(label: String) -> void:
	await RenderingServer.frame_post_draw
	var output := ProjectSettings.globalize_path("res://build/verification/phase2-journey/")
	DirAccess.make_dir_recursive_absolute(output)
	_check(root.get_texture().get_image().save_png(output.path_join(label + ".png")) == OK, "real route screenshot " + label)

func _capture_journey() -> void:
	if not ProjectSettings.globalize_path("user://").replace("\\", "/").contains("phase2-journey"):
		push_error("This capture requires isolated phase2-journey APPDATA / LOCALAPPDATA.")
		quit(2)
		return
	_route("42", "attack", true)
	if failures > 0:
		quit(1)
		return
	var finished = Core.new(path)
	finished.load_game()
	_check(finished.state.result == "victory" and finished.state.floor == 10, "genuine completed journey")
	var report := FileAccess.open("res://build/verification/phase2-journey/route_summary.json", FileAccess.WRITE)
	report.store_string(JSON.stringify({"seed":"42", "build":"attack", "zero_upgrades":finished.state.meta_snapshot.upgrades,
		"metrics":finished.state.metrics, "settlement":finished.state.settlement, "floor_count":finished.state.floors.size()}, "  "))
	report.close()
	var screen = Screen.new()
	screen.game = finished
	root.add_child(screen)
	screen.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	await _frames()
	for dimensions in [Vector2i(540,960), Vector2i(360,640)]:
		root.size = dimensions
		for floor_id in ["5", "10"]:
			var snapshot: Dictionary = checkpoints[floor_id]
			var checkpoint_path := "user://checkpoint_%s.json" % floor_id
			var checkpoint_store = Core.CampaignSave.new(checkpoint_path)
			_check(checkpoint_store.write(snapshot.run, snapshot.meta), "checkpoint valid before rendering")
			screen.game = Core.new(checkpoint_path)
			screen.game.load_game()
			screen.page = "map"
			screen.overlay_kind = ""
			screen.selected = screen.game.pending_cell()
			screen._render(true)
			await _frames()
			await _shot("boss_%s_%dx%d" % [floor_id,dimensions.x,dimensions.y])
		screen.game = Core.new(path)
		screen.game.load_game()
		screen.page = "map"
		screen.overlay_kind = ""
		screen._render(true)
		await _frames()
		while not screen._story_event().is_empty():
			screen._finish_story()
		await _frames()
		await _shot("victory_%dx%d" % [dimensions.x,dimensions.y])
		screen._open_overlay("floors")
		screen.index_floor = 10
		screen._populate_sheet()
		await _frames()
		await _shot("review_%dx%d" % [dimensions.x,dimensions.y])
	screen.queue_free()
	await _frames()
	print("Actual journey capture: %d checks, %d failures" % [checks,failures])
	quit(1 if failures else 0)
