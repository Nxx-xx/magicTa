extends SceneTree
## Painterly continuation of the original planted-sword idle: feet and grip stay fixed.
const BASE := "res://assets/characters/mysterious_knight/art_polish_a_v03/"
var rig: Node2D
var cape: Node2D
var head: Node2D
var player: AnimationPlayer
func _initialize() -> void: _run.call_deferred()

func layer(label: String, region: Rect2i, pivot: Vector2, offset: Vector2, scale_value: Vector2) -> Node2D:
	var original := Image.load_from_file(BASE+"source/art_polish_a_components.png")
	var texture := ImageTexture.create_from_image(original.get_region(region))
	var path := BASE+"source/art_polish_a_"+label+".res"
	assert(ResourceSaver.save(texture,path)==OK)
	var joint := Node2D.new()
	joint.name = label
	rig.add_child(joint)
	joint.owner = rig
	joint.position = pivot
	var sprite := Sprite2D.new()
	sprite.name = "Paint"
	sprite.texture = load(path)
	sprite.centered = false
	sprite.position = offset
	sprite.scale = scale_value
	joint.add_child(sprite)
	sprite.owner = rig
	return joint

func _run() -> void:
	DirAccess.make_dir_recursive_absolute(BASE+"source/draft/")
	rig = Node2D.new()
	rig.name = "ArtPolishAKnight"
	cape = layer("Cape",Rect2i(80,640,547,590),Vector2(256,151),Vector2(-99,-8),Vector2(.37,.47))
	layer("BodySwordHandsFeet",Rect2i(723,66,364,692),Vector2.ZERO,Vector2(174,136),Vector2(.45,.446))
	head = layer("Head",Rect2i(195,143,319,417),Vector2(256,157),Vector2(-60,-135),Vector2(.34,.34))
	player = AnimationPlayer.new()
	player.name = "AnimationPlayer"
	rig.add_child(player)
	player.owner = rig
	var library := AnimationLibrary.new()
	var idle := Animation.new()
	idle.length = 2.0
	idle.loop_mode = Animation.LOOP_LINEAR
	for spec in [["Head:rotation",.009],["Cape:skew",.012],["Cape:scale:x",.009]]:
		var track := idle.add_track(Animation.TYPE_VALUE)
		idle.track_set_path(track,NodePath(spec[0]))
		for i in 17:
			var t := float(i)/16.0
			var wave := cos(t*TAU)-1.0 if spec[0]=="Cape:skew" else sin(t*TAU)
			idle.track_insert_key(track,t*2.0,(1.0 if spec[0]=="Cape:scale:x" else 0.0)+float(spec[1])*wave)
	library.add_animation("idle",idle)
	player.add_animation_library("",library)
	player.autoplay = "idle"
	var packed := PackedScene.new()
	assert(packed.pack(rig)==OK)
	assert(ResourceSaver.save(packed,BASE+"source/art_polish_a_knight_editable.tscn")==OK)
	var viewport := SubViewport.new()
	viewport.size = Vector2i(512,512)
	viewport.transparent_bg = true
	viewport.render_target_update_mode = SubViewport.UPDATE_ALWAYS
	root.add_child(viewport)
	viewport.add_child(rig)
	player.play("idle")
	player.pause()
	var manifest := {"status":"draft","fps":4,"loop":true,"size":[256,256],"anchor":[128,217.389022827148],"events":{},"frames":[],"source":"source/art_polish_a_knight_editable.tscn","human_signoff":false}
	for i in 8:
		player.seek(float(i)/4.0,true)
		await process_frame
		await RenderingServer.frame_post_draw
		var img := viewport.get_texture().get_image()
		if i==0: assert(img.save_png(BASE+"source/draft/portrait.png")==OK)
		img.resize(256,256,Image.INTERPOLATE_LANCZOS)
		var path := "idle_%02d.png" % i
		assert(img.save_png(BASE+"source/draft/"+path)==OK)
		manifest.frames.append("source/draft/"+path)
	var file := FileAccess.open(BASE+"source/draft_manifest.json",FileAccess.WRITE)
	file.store_string(JSON.stringify(manifest,"\t"))
	print("A layered knight: native joints, original 8 frames / 4 fps, planted grip/feet; draft only")
	quit()

