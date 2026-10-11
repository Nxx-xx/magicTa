extends SceneTree
const BASE := "res://assets/characters/mysterious_knight/art_polish_a_v03/"
const OUT := "res://build/verification/art-polish-a/native/"
func _initialize() -> void: _run.call_deferred()
func _run() -> void:
	assert(ProjectSettings.globalize_path("user://").replace("\\","/").contains("08-parallel/art-polish-a/"))
	DirAccess.make_dir_recursive_absolute(OUT)
	var viewport := SubViewport.new()
	viewport.size = Vector2i(512,512)
	viewport.transparent_bg = true
	viewport.render_target_update_mode = SubViewport.UPDATE_ALWAYS
	root.add_child(viewport)
	var rig: Node2D = load(BASE+"source/art_polish_a_knight_editable.tscn").instantiate()
	viewport.add_child(rig)
	var player: AnimationPlayer = rig.get_node("AnimationPlayer")
	for i in 5: await process_frame
	var samples := []
	for speed in [1.0,.25]:
		player.stop()
		player.speed_scale = speed
		player.play("idle")
		player.seek(0,true)
		var start := Time.get_ticks_usec()
		for i in 8:
			var target: float = (float(i)+.05)/4.0/speed
			while float(Time.get_ticks_usec()-start)/1000000.0 < target: await process_frame
			await RenderingServer.frame_post_draw
			var path := OUT+"knight_%s_%02d.png" % [str(speed),i]
			assert(viewport.get_texture().get_image().save_png(path)==OK)
			samples.append({"speed":speed,"sample":i,"animation_seconds":player.current_animation_position,"wall_seconds":float(Time.get_ticks_usec()-start)/1000000.0,"path":path})
		player.pause()
	FileAccess.open(OUT+"timing.json",FileAccess.WRITE).store_string(JSON.stringify({"source_sha256":FileAccess.get_sha256(BASE+"source/art_polish_a_knight_editable.tscn"),"samples":samples,"human_signoff":false},"\t"))
	print("A knight: 16 timed native samples, original and quarter speed")
	quit()
