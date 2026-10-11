extends SceneTree
## Sample the existing editable rig, never blend raster silhouettes.
const SOURCE := "res://assets/characters/hero/phase3/source/refine_v06/"
const OUT := "res://assets/characters/hero/phase3/textures/gait/"
const COUNT := 24

func _initialize() -> void:
	_run.call_deferred()

func _capture(viewport: SubViewport) -> Image:
	await process_frame
	await RenderingServer.frame_post_draw
	var picture := viewport.get_texture().get_image()
	picture.resize(128, 128, Image.INTERPOLATE_LANCZOS)
	return picture

func _run() -> void:
	DirAccess.make_dir_recursive_absolute(OUT)
	for facing in ["down", "left", "up", "right"]:
		var rig: Node2D = load(SOURCE + "hero_" + facing + "_editable.tscn").instantiate()
		var viewport := SubViewport.new()
		viewport.size = Vector2i(768, 768)
		viewport.transparent_bg = true
		viewport.render_target_update_mode = SubViewport.UPDATE_ALWAYS
		root.add_child(viewport)
		viewport.add_child(rig)
		var player: AnimationPlayer = rig.get_node("AnimationPlayer")
		player.callback_mode_process = AnimationMixer.ANIMATION_CALLBACK_MODE_PROCESS_MANUAL
		var walk: String = "map_walk_" + facing
		var animation := player.get_animation(walk)
		var atlas := Image.create(768, 768, false, Image.FORMAT_RGBA8)
		for index in COUNT:
			player.play(walk)
			player.seek(animation.length * index / COUNT, true)
			var picture := await _capture(viewport)
			atlas.blit_rect(picture, Rect2i(0, 0, 128, 128), Vector2i(index % 6, index / 6) * 128)
		# Six true transform samples from each foot's contact to the idle pose.
		for side in 2:
			player.play(walk)
			player.seek(animation.length * side / 2.0, true)
			var contacts := []
			for track in animation.get_track_count():
				var path := animation.track_get_path(track)
				contacts.append(rig.get_node(NodePath(path.get_concatenated_names())).get(path.get_concatenated_subnames()))
			player.play("map_idle_" + facing)
			player.seek(0, true)
			var resting := []
			for track in animation.get_track_count():
				var path := animation.track_get_path(track)
				resting.append(rig.get_node(NodePath(path.get_concatenated_names())).get(path.get_concatenated_subnames()))
			for sample in 6:
				var weight := smoothstep(0.0, 1.0, float(sample) / 5.0)
				for track in animation.get_track_count():
					var path := animation.track_get_path(track)
					var value: Variant = resting[track] if contacts[track] is bool else lerp(contacts[track], resting[track], weight)
					rig.get_node(NodePath(path.get_concatenated_names())).set(path.get_concatenated_subnames(), value)
				var picture := await _capture(viewport)
				var index := COUNT + side * 6 + sample
				atlas.blit_rect(picture, Rect2i(0, 0, 128, 128), Vector2i(index % 6, index / 6) * 128)
		atlas.save_png(OUT + facing + ".png")
		viewport.queue_free()
		await process_frame
		print("Baked gait: ", facing)
	quit()
