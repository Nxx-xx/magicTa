extends SceneTree
const SOURCE := "res://assets/characters/hero/phase3/source/motion_v07/"
const OUT := "res://build/verification/hero-motion/native/"
var checks := 0
var failures := 0
func check(ok: bool, label: String) -> void:
	checks += 1
	if not ok:
		failures += 1
		push_error("FAIL "+label)
func _initialize() -> void:
	if not ProjectSettings.globalize_path("user://").replace("\\","/").contains("hero-motion/"):
		quit(2)
		return
	_run.call_deferred()
func _run() -> void:
	DirAccess.make_dir_recursive_absolute(OUT)
	var rig: Node2D = load(SOURCE+"hero_right_editable.tscn").instantiate()
	var viewport := SubViewport.new()
	viewport.size = Vector2i(768,768)
	viewport.transparent_bg = true
	viewport.render_target_update_mode = SubViewport.UPDATE_ALWAYS
	root.add_child(viewport)
	viewport.add_child(rig)
	var player: AnimationPlayer = rig.get_node("AnimationPlayer")
	player.callback_mode_process = AnimationMixer.ANIMATION_CALLBACK_MODE_PROCESS_MANUAL
	var manifest: Dictionary = JSON.parse_string(FileAccess.get_file_as_string(SOURCE+"draft_manifest.json"))
	var observations := []
	var maximum_contact_error := 0.0
	for speed in [1.0,.25]:
		player.speed_scale = speed
		for action in manifest.actions:
			var entry: Dictionary = manifest.actions[action]
			player.play(action)
			player.advance(0)
			for frame in entry.frames.size():
				if frame > 0: player.advance(1.0/float(entry.fps)/speed)
				check(absf(player.current_animation_position-float(frame)/float(entry.fps)) < .0001,"native timed position")
				for limb in ["left","right"]:
					var contact: Node2D = rig.find_child(limb+"_contact",true,false)
					var expected := Vector2(399 if limb=="right" else 369,696)
					var error := contact.global_position.distance_to(expected)/2
					maximum_contact_error = maxf(maximum_contact_error,error)
					check(error < .01,"planted source sole "+action)
					var grip: Node2D = rig.find_child(limb+"_grip",true,false)
					var held: Node2D = rig.find_child("sword" if limb=="right" else "lantern",true,false)
					check(held.get_parent()==grip and held.global_position.distance_to(grip.global_position)<.001,"attached grip hierarchy")
				check(rig.scale==Vector2.ONE,"no mirror or scale change")
				await process_frame
				await RenderingServer.frame_post_draw
				var path := OUT+"%s_%s_%02d.png" % [str(speed),action,frame]
				viewport.get_texture().get_image().save_png(path)
				observations.append({"speed":speed,"action":action,"frame":frame,"position":player.current_animation_position,"path":path})
			player.stop()
	FileAccess.open(OUT+"results.json",FileAccess.WRITE).store_string(JSON.stringify({"checks":checks,"failures":failures,"maximum_sole_error_runtime_px":maximum_contact_error,"observations":observations,"scope":"Native AnimationPlayer advanced at 1x/0.25x; 46 captures from editable layered source. Production remains catalog-driven baked poses."},"\t"))
	print("HERO_MOTION_NATIVE checks=%d failures=%d max_sole_error=%f" % [checks,failures,maximum_contact_error])
	quit(1 if failures else 0)
