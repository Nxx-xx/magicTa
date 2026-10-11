extends SceneTree
## Review native rig proportions without changing published textures.
const OUT := "res://build/verification/hero-proportions/"

func _initialize() -> void:
	_run.call_deferred()

func _run() -> void:
	DirAccess.make_dir_recursive_absolute(OUT)
	var viewport := SubViewport.new()
	viewport.size = Vector2i(1152, 768)
	viewport.transparent_bg = false
	viewport.render_target_update_mode = SubViewport.UPDATE_ALWAYS
	root.add_child(viewport)
	var background := ColorRect.new()
	background.color = Color("24323b")
	background.size = Vector2(1152, 768)
	viewport.add_child(background)
	for row in 2:
		var facing := "right" if row == 0 else "down"
		for column in 3:
			var holder := Node2D.new()
			holder.position = Vector2(column * 384, row * 384)
			holder.scale = Vector2.ONE * .5
			viewport.add_child(holder)
			var rig: Node2D = load("res://assets/characters/hero/phase3/source/refine_v06/hero_" + facing + "_editable.tscn").instantiate()
			holder.add_child(rig)
			var player: AnimationPlayer = rig.get_node("AnimationPlayer")
			player.callback_mode_process = AnimationMixer.ANIMATION_CALLBACK_MODE_PROCESS_MANUAL
			player.play("map_idle_" + facing)
			player.seek(0, true)
			if column > 0:
				var head: Node2D = rig.get_node("pelvis/torso/head")
				head.scale *= .80 if column == 1 else .70
				head.position.y += 10
				var chest: Sprite2D = rig.get_node("pelvis/torso/Paint")
				chest.scale.x *= 1.12
				chest.position.x *= 1.12
			var label := Label.new()
			label.text = ["Current", "Head 80% / chest +12%", "Head 70% / chest +12%"][column]
			label.position = Vector2(column * 384 + 18, row * 384 + 12)
			viewport.add_child(label)
	await process_frame
	await RenderingServer.frame_post_draw
	viewport.get_texture().get_image().save_png(OUT + "comparison.png")
	quit()
