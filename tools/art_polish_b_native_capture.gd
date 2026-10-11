extends SceneTree
## Actual timed AnimationPlayer rendering, isolated from approvals/publication.
var draft_path := ""
var evidence := ""

func _initialize() -> void:
	_run.call_deferred()

func _run() -> void:
	assert(ProjectSettings.globalize_path("user://").replace("\\","/").contains("08-parallel/art-polish-b/"))
	var routes_path := "res://assets/monsters/phase3/source/art_polish_b_v07/art_polish_b_routes.json"
	var evidence_root := "res://build/verification/art-polish-b/native/"
	for argument in OS.get_cmdline_user_args():
		if argument.begins_with("--routes="): routes_path = argument.trim_prefix("--routes=")
		if argument.begins_with("--evidence="): evidence_root = argument.trim_prefix("--evidence=").trim_suffix("/")+"/"
	var routes: Dictionary = JSON.parse_string(FileAccess.get_file_as_string(routes_path))
	for path in routes.values():
		var rig: Dictionary = JSON.parse_string(FileAccess.get_file_as_string(path))
		draft_path = str(path).get_base_dir()+"/"+str(rig.entity)+"_draft_manifest.json"
		evidence = evidence_root+str(rig.entity)+"/"
		await capture()
	quit(0)

func capture() -> void:
	var draft: Dictionary = JSON.parse_string(FileAccess.get_file_as_string(draft_path))
	var source: Dictionary = JSON.parse_string(FileAccess.get_file_as_string(draft.source))
	var scene_path: String = str(draft.source).get_base_dir()+"/"+str(source.entity)+"_editable_draft.tscn"
	var scene := load(scene_path).instantiate() as Node2D
	var viewport := SubViewport.new()
	viewport.size = Vector2i(source.canvas,source.canvas)
	viewport.transparent_bg = true
	viewport.render_target_update_mode = SubViewport.UPDATE_ALWAYS
	root.add_child(viewport)
	viewport.add_child(scene)
	var player := scene.get_node("AnimationPlayer") as AnimationPlayer
	var observations: Array = []
	evidence = evidence.trim_suffix("/")+"/"
	for speed in [1.0,.25]:
		for action_id in draft.actions:
			var action: Dictionary = draft.actions[action_id]
			var dest: String = evidence+str(action_id)+"_"+str(speed)+"/"
			DirAccess.make_dir_recursive_absolute(dest)
			player.stop()
			player.speed_scale = speed
			player.play(action_id)
			player.seek(0,true)
			var started := Time.get_ticks_usec()
			for frame in action.frames.size():
				var target: float = float(frame)/float(action.fps)/float(speed)
				while float(Time.get_ticks_usec()-started)/1000000.0 < target:
					await process_frame
				await RenderingServer.frame_post_draw
				var image := viewport.get_texture().get_image()
				image.resize(int(draft.size[0]),int(draft.size[1]),Image.INTERPOLATE_LANCZOS)
				var path: String = dest+"%02d.png" % frame
				image.save_png(path)
				observations.append({"action":action_id,"sample":frame,"speed":speed,"wall_seconds":float(Time.get_ticks_usec()-started)/1000000.0,"animation_seconds":player.current_animation_position,"path":path})
			player.pause()
	FileAccess.open(evidence+"timing.json",FileAccess.WRITE).store_string(JSON.stringify({"draft":draft_path,"draft_sha256":FileAccess.get_sha256(draft_path),"rig":draft.source,"rig_sha256":FileAccess.get_sha256(draft.source),"scene":scene_path,"scene_sha256":FileAccess.get_sha256(scene_path),"observations":observations},"\t"))
	print("Actual native playback: %d timed original/.25 samples; no review approvals written" % observations.size())
	viewport.queue_free()
	await process_frame
