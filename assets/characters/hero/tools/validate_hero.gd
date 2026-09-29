extends SceneTree
const BASE := "res://assets/characters/hero/"
const FRAMES = preload("res://assets/characters/hero/hero_idle.tres")
const Screen = preload("res://scripts/ui/map_screen.gd")
const Core = preload("res://scripts/core/map_engine.gd")
var records: Array = []
var failures := 0

func _initialize() -> void:
	_run.call_deferred()

func _check(passed: bool, label: String, data: Dictionary = {}) -> void:
	records.append({"passed": passed, "check": label, "data": data})
	print("PASS " + label if passed else "FAIL " + label)
	if not passed: failures += 1

func _run() -> void:
	if not OS.get_user_data_dir().replace("\\", "/").contains("/build/verification/hero/"):
		push_error("Validation requires isolated APPDATA and LOCALAPPDATA")
		quit(2)
		return
	_check(FRAMES.get_animation_names().size() == 4, "Only four idle animations released; no rejected walk clips")
	for direction in ["down", "left", "up", "right"]:
		var name: String = "idle_" + direction
		_check(FRAMES.has_animation(name) and FRAMES.get_frame_count(name) == 1, name + " resource")
		var image := FRAMES.get_frame_texture(name, 0).get_image()
		_check(image.get_size() == Vector2i(128, 128), name + " 128x128")
		var boundary_empty := true
		var zero := 0
		var partial := 0
		var solid_end_y := 0
		for y in 128:
			for x in 128:
				var a := image.get_pixel(x,y).a
				if a == 0: zero += 1
				elif a < 1: partial += 1
				if a >= 0.5: solid_end_y = maxi(solid_end_y, y+1)
				if x < 3 or y < 3 or x >= 125 or y >= 125:
					if a != 0: boundary_empty = false
		_check(zero > 8000 and partial > 0, name + " true transparent alpha", {"fully_transparent_pixels":zero, "partial_pixels":partial})
		_check(boundary_empty, name + " transparent 3px perimeter prevents adjacent texture leakage")
		_check(absi(solid_end_y - 116) <= 1, name + " registered sole baseline", {"solid_end_y":solid_end_y,"target":116})
	_check(FileAccess.file_exists(BASE + "source/.gdignore") and FileAccess.file_exists(BASE + "reports/.gdignore"), "Source and QA images excluded from Godot imports")
	# Read actual current M1 board geometry in isolated, nonpersistent fixtures.
	for viewport in [Vector2i(540,960),Vector2i(384,720),Vector2i(360,640)]:
		root.size = viewport
		var screen = Screen.new()
		screen.game = Core.new("user://hero_layout_fixture.json")
		screen.game.persistence_enabled = false
		root.add_child(screen)
		screen.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
		screen._start("42")
		for f in 8: await process_frame
		var tile: float = screen.board._cell_size()
		var expected := 516.0 / 11.0 if viewport.x == 540 else (360.0 / 11.0 if viewport.x == 384 else 288.0 / 11.0)
		_check(absf(tile - expected) < 0.01, "Actual grid_board at %s" % viewport, {"board":str(screen.board.size),"tile":tile,"viewport":str(viewport)})
		screen.queue_free()
		for f in 2: await process_frame
	var output := {"engine":Engine.get_version_info().string,"user_data":OS.get_user_data_dir(),"checks":records.size(),"failures":failures,"records":records,"walk_status":"REJECTED: repeated leading leg, incomplete passing poses, unstable local registration"}
	FileAccess.open(BASE + "reports/validation.json",FileAccess.WRITE).store_string(JSON.stringify(output,"\t"))
	print("HERO_VALIDATION checks=",records.size()," failures=",failures)
	quit(0 if failures == 0 else 1)
