extends SceneTree
const SOURCE := "res://assets/characters/hero/phase3/source/refine_v06/"
const OUT := "res://build/verification/phase3/09-refinement/hero/native/"
func _initialize() -> void:
	if not ProjectSettings.globalize_path("user://").replace("\\","/").contains("08-parallel/hero_refine/"):
		quit(2)
		return
	_run.call_deferred()
func _run() -> void:
	var draft: Dictionary = JSON.parse_string(FileAccess.get_file_as_string(SOURCE+"draft_manifest.json"))
	var records := []
	var scenes := {}
	for facing in ["right","down","up","left"]:
		var scene_path: String = SOURCE+"hero_"+str(facing)+"_editable.tscn"
		if not FileAccess.file_exists(scene_path): continue
		var rig := load(scene_path).instantiate() as Node2D
		var viewport := SubViewport.new()
		viewport.size = Vector2i(768,768)
		viewport.transparent_bg = true
		viewport.render_target_update_mode = SubViewport.UPDATE_ALWAYS
		root.add_child(viewport)
		viewport.add_child(rig)
		var player := rig.get_node("AnimationPlayer") as AnimationPlayer
		# Warm the newly loaded scene before its clock starts. Loading the next
		# view may enlarge the previous engine delta and skip initial poses.
		for warm in 3:
			await process_frame
			await RenderingServer.frame_post_draw
		scenes[scene_path] = FileAccess.get_sha256(scene_path)
		for id in draft.actions:
			if not player.has_animation(id): continue
			var action: Dictionary = draft.actions[id]
			for speed in [1.0,.25]:
				var folder: String = OUT+str(id)+"_"+str(speed)+"/"
				DirAccess.make_dir_recursive_absolute(folder)
				player.stop()
				player.speed_scale = speed
				player.play(id)
				player.seek(0,true)
				player.pause()
				await process_frame
				await RenderingServer.frame_post_draw
				player.play(id)
				player.seek(0,true)
				var start := Time.get_ticks_usec()
				for frame in action.frames.size():
					var target: float = (float(frame)+.05)/float(action.fps)/float(speed)
					while float(Time.get_ticks_usec()-start)/1000000.0 < target: await process_frame
					await RenderingServer.frame_post_draw
					var picture := viewport.get_texture().get_image()
					picture.resize(int(action.size[0]),int(action.size[1]),Image.INTERPOLATE_LANCZOS)
					var path: String = folder+"%02d.png" % frame
					picture.save_png(path)
					records.append({"action":id,"sample":frame,"speed":speed,"wall_seconds":float(Time.get_ticks_usec()-start)/1000000.0,"animation_seconds":player.current_animation_position,"path":path})
				player.pause()
		viewport.queue_free()
		await process_frame
	FileAccess.open(OUT+"timing.json",FileAccess.WRITE).store_string(JSON.stringify({"draft":SOURCE+"draft_manifest.json","draft_sha256":FileAccess.get_sha256(SOURCE+"draft_manifest.json"),"scenes":scenes,"author_sha256":FileAccess.get_sha256("res://tools/phase3_v06_hero_bake.gd"),"capture_sha256":FileAccess.get_sha256("res://tools/phase3_v06_hero_playback.gd"),"observations":records,"scope":"Actual AnimationPlayer timed original/.25 sampling. No human signoff or continuous video perception claimed."},"\t"))
	print("Hero native: %d actual timed samples; no approval mutation" % records.size())
	quit(0)
