extends SceneTree
var entity := "skeleton"
var evidence := "res://build/verification/phase3/08-parallel/base_a/"
func _initialize():
	if not ProjectSettings.globalize_path("user://").replace("\\","/").contains("08-parallel/base_a/"):
		quit(2)
		return
	for arg in OS.get_cmdline_user_args():
		if arg.begins_with("--entity="): entity=arg.trim_prefix("--entity=")
	run.call_deferred()
func run():
	var folder="res://assets/monsters/phase3/source/parallel_v05/battle/"+entity+"/"
	var data=JSON.parse_string(FileAccess.get_file_as_string(folder+entity+"_rig.json"))
	var scene=load(folder+entity+"_editable_draft.tscn").instantiate()
	var viewport=SubViewport.new()
	viewport.size=Vector2i(512,512)
	viewport.transparent_bg=true
	viewport.render_target_update_mode=SubViewport.UPDATE_ALWAYS
	root.add_child(viewport)
	viewport.add_child(scene)
	var player=scene.get_node("AnimationPlayer")
	var observations=[]
	for speed in [1.0,0.25]:
		for action in ["idle","attack","hit","defeat"]:
			var a=data.actions[action]
			var dest=evidence+entity+"_native_"+action+"_"+str(speed)+"/"
			DirAccess.make_dir_recursive_absolute(dest)
			player.speed_scale=speed
			player.play(action)
			player.seek(0,true)
			var start=Time.get_ticks_usec()
			for frame in a.poses.size():
				var target=float(frame)/float(a.fps)/speed
				while float(Time.get_ticks_usec()-start)/1000000.0<target:
					await process_frame
				await RenderingServer.frame_post_draw
				var actual=float(Time.get_ticks_usec()-start)/1000000.0
				var im=viewport.get_texture().get_image()
				im.resize(256,256,Image.INTERPOLATE_LANCZOS)
				im.save_png(dest+"%02d.png"%frame)
				observations.append({"action":action,"speed":speed,"sample":frame,"wall_seconds":actual,"animation_seconds":player.current_animation_position,"path":dest+"%02d.png"%frame})
			player.pause()
	FileAccess.open(evidence+entity+"_native_timing.json",FileAccess.WRITE).store_string(JSON.stringify(observations,"\t"))
	print("Native timed playback captured: ",entity," ",observations.size()," samples, original and 0.25 speed; not automatic visual approval")
	quit()
