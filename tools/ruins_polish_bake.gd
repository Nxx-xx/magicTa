extends SceneTree
## Invariant painted bases + editable native rune/light layers. No gameplay writes.
const SOURCE := "res://assets/environment/ruins/phase3/source/polish_v03/"
const TARGET := "res://assets/environment/ruins/phase3/textures/v02/"
const OUT := "res://build/verification/ruins-polish/"
const IDS := {"oath":"p3_oath_ruin","forge":"p3_oath_forge","sanctuary":"p3_lantern_sanctuary"}
const OPTIONS := {"oath":["edge","guard","salvage"],"forge":["temper","sacrifice","salvage"],"sanctuary":["restore","ward","reserve"]}
var failures := 0

func _initialize() -> void:
	if not ProjectSettings.globalize_path("user://").replace("\\","/").contains("ruins-polish/"):
		quit(2)
		return
	_run.call_deferred()

func _run() -> void:
	var manifest := {"version":2,"status":"accepted","storage":"shared-base-overlay-v1","anchor":[128,224],"size":[256,256],"ruins":{}}
	for name in IDS:
		var rig := Node2D.new()
		rig.name = name.capitalize()+"Ruin"
		var image := Image.load_from_file(SOURCE+name+".png")
		image = image.get_region(image.get_used_rect())
		var texture := ImageTexture.create_from_image(image)
		ResourceSaver.save(texture,SOURCE+name+"_base.res",ResourceSaver.FLAG_CHANGE_PATH)
		texture.take_over_path(SOURCE+name+"_base.res")
		var base := Sprite2D.new()
		base.name = "FixedStoneBase"
		base.texture = texture
		base.centered = false
		var scale_factor := minf(448.0/image.get_width(),410.0/image.get_height())
		base.scale = Vector2.ONE*scale_factor
		base.position = Vector2(256-image.get_width()*scale_factor/2,448-image.get_height()*scale_factor)
		rig.add_child(base)
		base.owner = rig
		var light := Polygon2D.new()
		light.name = "LanternFlame" if name == "sanctuary" else "RuneFlame"
		light.polygon = PackedVector2Array([Vector2(-12,4),Vector2(-18,-7),Vector2(-7,-25),Vector2(0,-46),Vector2(10,-21),Vector2(17,-6),Vector2(9,6)])
		light.position = Vector2(256,278 if name == "sanctuary" else (280 if name == "forge" else 220))
		light.color = Color("79ddca") if name == "oath" else Color("ffba64")
		if name == "oath": light.polygon = PackedVector2Array([Vector2(0,-39),Vector2(7,-25),Vector2(0,11),Vector2(-7,-25)])
		if name == "sanctuary": light.polygon = PackedVector2Array([Vector2(-6,1),Vector2(-7,-8),Vector2(0,-23),Vector2(6,-10),Vector2(6,1)])
		rig.add_child(light)
		light.owner = rig
		var glyph := Polygon2D.new()
		glyph.name = "ChosenResultGlyph"
		glyph.position = Vector2(256,150 if name == "forge" else 165)
		glyph.color = Color("ffe3a2")
		rig.add_child(glyph)
		glyph.owner = rig
		var ring := Line2D.new()
		ring.name = "ActivationRing"
		ring.position = Vector2(256,348)
		ring.width = 4
		ring.default_color = Color("b5e0c8")
		for i in 33: ring.add_point(Vector2(cos(TAU*i/32.0)*150,sin(TAU*i/32.0)*40))
		rig.add_child(ring)
		ring.owner = rig
		var viewport := SubViewport.new()
		viewport.size = Vector2i(512,512)
		viewport.transparent_bg = true
		viewport.render_target_update_mode = SubViewport.UPDATE_ALWAYS
		root.add_child(viewport)
		viewport.add_child(rig)
		# Shared painted base is rendered once; only native light/result layers animate.
		light.visible = false
		glyph.visible = false
		ring.visible = false
		await process_frame
		await RenderingServer.frame_post_draw
		var painted := viewport.get_texture().get_image()
		painted.resize(256,256,Image.INTERPOLATE_LANCZOS)
		var base_path: String = TARGET+name+"/base.png"
		DirAccess.make_dir_recursive_absolute(TARGET+name)
		painted.save_png(base_path)
		light.visible = true
		glyph.visible = true
		ring.visible = true
		var library := AnimationLibrary.new()
		var actions := {}
		var names := ["idle","spent"]
		for option in OPTIONS[name]: names.append("resolve_"+option)
		for action_id in names:
			var resolves: bool = action_id.begins_with("resolve_")
			var option: String = action_id.trim_prefix("resolve_") if resolves else ""
			var count := (8 if name == "forge" else 6) if resolves else (4 if action_id == "idle" else 1)
			var fps := (12 if name == "forge" else 10) if resolves else (4 if action_id == "idle" else 1)
			var animation := Animation.new()
			animation.length = float(count)/fps
			animation.loop_mode = Animation.LOOP_LINEAR if action_id == "idle" else Animation.LOOP_NONE
			var tracks := {}
			for node in [light,glyph,ring,base]:
				for property in (["modulate","scale"] if node == light else (["polygon","modulate"] if node == glyph else ["modulate"])):
					var track := animation.add_track(Animation.TYPE_VALUE)
					animation.track_set_path(track,NodePath(str(rig.get_path_to(node))+":"+property))
					tracks[str(node.name)+":"+property] = {"node":node,"property":property,"track":track}
			var frames := []
			var contact := Image.create(256*count,256,false,Image.FORMAT_RGBA8)
			DirAccess.make_dir_recursive_absolute(TARGET+name+"/"+action_id)
			for i in count:
				var progress := float(i)/maxi(1,count-1)
				var power := sin(PI*progress) if resolves else .35+float(i%3)*.12
				if action_id == "spent": power = 0
				base.modulate = Color(.48,.54,.60,1) if action_id == "spent" else Color.WHITE
				light.modulate.a = power
				light.scale = Vector2(1+power*.18, .85+power*.4)
				glyph.modulate.a = power if resolves else 0
				glyph.polygon = _symbol(option)
				ring.modulate.a = power*.6 if resolves else 0
				for definition in tracks.values(): animation.track_insert_key(definition.track,float(i)/fps,definition.node.get(definition.property))
				await process_frame
				await RenderingServer.frame_post_draw
				var frame := viewport.get_texture().get_image()
				frame.resize(256,256,Image.INTERPOLATE_LANCZOS)
				var path: String = TARGET+name+"/"+action_id+"/%02d.png" % i
				# Capture overlay independently to avoid repeating the painted stone 25 times.
				base.visible = false
				await process_frame
				await RenderingServer.frame_post_draw
				var overlay := viewport.get_texture().get_image()
				overlay.resize(256,256,Image.INTERPOLATE_LANCZOS)
				overlay.save_png(path)
				base.visible = true
				frames.append(path)
				contact.blit_rect(frame,Rect2i(0,0,256,256),Vector2i(i*256,0))
				var bounds := frame.get_used_rect()
				if bounds.position.x < 4 or bounds.position.y < 4 or bounds.end.x > 252 or bounds.end.y > 252: failures += 1
			contact.save_png(OUT+"ruin_"+name+"_"+action_id+".png")
			actions[action_id] = {"frames":frames,"fps":fps,"loop":action_id=="idle"}
			library.add_animation(action_id,animation)
		var player := AnimationPlayer.new()
		player.name = "AnimationPlayer"
		rig.add_child(player)
		player.owner = rig
		player.add_animation_library("",library)
		var packed := PackedScene.new()
		packed.pack(rig)
		ResourceSaver.save(packed,SOURCE+name+"_editable.tscn")
		manifest.ruins[IDS[name]] = {"source":SOURCE+name+"_editable.tscn","base":base_path,"spent_tint":[0.48,0.54,0.60],"actions":actions}
		viewport.queue_free()
		await process_frame
	FileAccess.open(SOURCE+"review_manifest.json",FileAccess.WRITE).store_string(JSON.stringify(manifest,"\t"))
	FileAccess.open("res://assets/environment/ruins/phase3/runtime_v02.json",FileAccess.WRITE).store_string(JSON.stringify(manifest,"\t"))
	print("RUIN_BAKE three editable bases, option-specific results; %d boundary failures" % failures)
	quit(1 if failures else 0)

func _symbol(option: String) -> PackedVector2Array:
	if option in ["guard","ward"]:
		return PackedVector2Array([Vector2(-25,-24),Vector2(25,-24),Vector2(21,10),Vector2(0,32),Vector2(-21,10)])
	if option == "restore":
		return PackedVector2Array([Vector2(-8,-27),Vector2(8,-27),Vector2(8,-8),Vector2(27,-8),Vector2(27,8),Vector2(8,8),Vector2(8,27),Vector2(-8,27),Vector2(-8,8),Vector2(-27,8),Vector2(-27,-8),Vector2(-8,-8)])
	if option in ["edge","temper","sacrifice"]:
		return PackedVector2Array([Vector2(0,-36),Vector2(10,-20),Vector2(6,13),Vector2(21,13),Vector2(21,20),Vector2(5,20),Vector2(5,32),Vector2(-5,32),Vector2(-5,20),Vector2(-21,20),Vector2(-21,13),Vector2(-6,13),Vector2(-10,-20)])
	var points := PackedVector2Array()
	for i in 16: points.append(Vector2(cos(TAU*i/16.0),sin(TAU*i/16.0))*24)
	return points
