extends SceneTree
## Actual timed AnimationPlayer rendering, isolated from approvals/publication.
var draft_path := ""
var evidence := ""

func _initialize() -> void:
	for arg in OS.get_cmdline_user_args():
		if arg.begins_with("--draft="): draft_path = arg.trim_prefix("--draft=")
		if arg.begins_with("--evidence="): evidence = arg.trim_prefix("--evidence=")
	if not draft_path.begins_with("res://assets/monsters/phase3/source/parallel_v05/") or ".." in draft_path or not evidence.begins_with("res://build/verification/phase3/08-parallel/coordinator/native/") or ".." in evidence:
		quit(2)
		return
	_run.call_deferred()

func _run() -> void:
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
	quit(0)
