extends SceneTree
## Deterministic packaging/rendering of imagegen layers; never promotes draft art.
const OUT := "res://build/verification/phase3/06-animation-balance/"
const SOURCES := ["res://assets/characters/hero/phase3/source/rig_v02/hero_rig.json", "res://assets/monsters/phase3/source/rig_v02/slime_rig.json", "res://assets/monsters/phase3/source/rig_v02/minotaur_rig.json"]
var review: Array = []
var failures := 0
var output_root := OUT
var source_paths: Array = SOURCES.duplicate()

func _initialize() -> void:
	var isolated := ProjectSettings.globalize_path("user://").replace("\\", "/")
	if not isolated.contains("phase3/06-animation-balance/") and not isolated.contains("phase3/07-completion/") and not isolated.contains("phase3/08-parallel/"):
		quit(2)
		return
	for argument in OS.get_cmdline_user_args():
		if argument.begins_with("--source="): source_paths = [argument.trim_prefix("--source=")]
		if argument == "--completion": output_root = "res://build/verification/phase3/07-completion/"
		if argument.begins_with("--output=res://build/verification/phase3/08-parallel/") and not ".." in argument:
			output_root = argument.trim_prefix("--output=").trim_suffix("/")+"/"
	DirAccess.make_dir_recursive_absolute(output_root)
	_run.call_deferred()

func vec(value: Array) -> Vector2:
	return Vector2(float(value[0]),float(value[1]))

func _run() -> void:
	for path in source_paths:
		await bake(path)
	FileAccess.open(output_root+"rig-review.json",FileAccess.WRITE).store_string(JSON.stringify(review,"\t"))
	print("Draft rigs baked: %d; %d source reload failures; no production manifest changes" % [review.size(),failures])
	quit(0 if failures == 0 else 1)

func bake(path: String) -> void:
	var data: Dictionary = JSON.parse_string(FileAccess.get_file_as_string(path))
	var folder := path.get_base_dir()+"/"
	var atlas := Image.load_from_file(folder+str(data.source))
	var rig := Node2D.new()
	rig.name = data.entity.capitalize()+"DraftRig"
	# Fixed framing transform shared by ALL poses; never per-frame recentering.
	rig.scale = Vector2.ONE*float(data.get("rest_scale",1))
	rig.position = vec(data.anchor)*(1-float(data.get("rest_scale",1)))
	var bones := {"root":rig}
	var pivots := {"root":Vector2.ZERO}
	var shapes := {}
	DirAccess.make_dir_recursive_absolute(folder+data.entity+"_layers")
	# Parents may occur after children in painter's order.
	for layer in data.layers:
		var bone := Node2D.new()
		bone.name = layer.name
		bones[layer.name] = bone
		pivots[layer.name] = vec(layer.pivot)
	for layer in data.layers:
		var bone: Node2D = bones[layer.name]
		var parent: Node2D = bones[layer.parent]
		parent.add_child(bone)
	for layer in data.layers:
		var bone: Node2D = bones[layer.name]
		bone.owner = rig
		bone.position = pivots[layer.name]-pivots[layer.parent]
		bone.z_index = int(layer.z)
		bone.z_as_relative = false
		if layer.get("joint_only",false): continue
		var rect := Rect2i(int(layer.crop[0]),int(layer.crop[1]),int(layer.crop[2]),int(layer.crop[3]))
		var layer_atlas := Image.load_from_file(folder+str(layer.source)) if layer.has("source") else atlas
		var cropped := layer_atlas.get_region(rect)
		var layer_path: String = folder+data.entity+"_layers/"+layer.name
		cropped.save_png(layer_path+".png")
		var texture := ImageTexture.create_from_image(cropped)
		if data.get("shape_layers",{}).has(layer.name):
			shapes[layer.name] = []
			for shape in data.shape_layers[layer.name]:
				var source := Image.load_from_file(folder+str(shape.source))
				var bounds: Array = shape.crop
				var shape_image := source.get_region(Rect2i(int(bounds[0]),int(bounds[1]),int(bounds[2]),int(bounds[3])))
				if shape.has("canvas"):
					var registered := Image.create(int(shape.canvas[0]),int(shape.canvas[1]),false,Image.FORMAT_RGBA8)
					registered.blit_rect(shape_image,Rect2i(Vector2i.ZERO,shape_image.get_size()),Vector2i(int(shape.offset[0]),int(shape.offset[1])))
					shape_image = registered
				var shape_texture := ImageTexture.create_from_image(shape_image)
				ResourceSaver.save(shape_texture,layer_path+"_shape%d.res" % shapes[layer.name].size(),ResourceSaver.FLAG_CHANGE_PATH)
				shape_texture.take_over_path(layer_path+"_shape%d.res" % shapes[layer.name].size())
				shape_image.save_png(layer_path+"_shape%d.png" % shapes[layer.name].size())
				shapes[layer.name].append(shape_texture)
			texture = shapes[layer.name][0]
		ResourceSaver.save(texture,layer_path+".res",ResourceSaver.FLAG_CHANGE_PATH)
		texture.take_over_path(layer_path+".res")
		var sprite := Sprite2D.new()
		sprite.name = "Paint"
		sprite.texture = texture
		sprite.centered = false
		sprite.position = -vec(layer.image_pivot)*float(layer.scale)
		sprite.scale = Vector2.ONE*float(layer.scale)
		bone.add_child(sprite)
		sprite.owner = rig
		if layer.name == "rage_rune": bone.modulate.a = 0
	var animator := AnimationPlayer.new()
	animator.name = "AnimationPlayer"
	rig.add_child(animator)
	animator.owner = rig
	var library := AnimationLibrary.new()
	for id in data.actions:
		var action: Dictionary = data.actions[id]
		var animation := Animation.new()
		animation.length = float(action.poses.size())/float(action.fps)
		animation.loop_mode = Animation.LOOP_LINEAR if action.loop else Animation.LOOP_NONE
		for layer in data.layers:
			var node_path := str(rig.get_path_to(bones[layer.name]))
			if shapes.has(layer.name):
				var track := animation.add_track(Animation.TYPE_VALUE)
				animation.track_set_path(track,NodePath(node_path+"/Paint:texture"))
				animation.value_track_set_update_mode(track,Animation.UPDATE_DISCRETE)
				for frame in action.poses.size():
					var pose: Dictionary = action.poses[frame].get(layer.name,{})
					animation.track_insert_key(track,float(frame)/float(action.fps),shapes[layer.name][int(pose.get("shape",0))])
			for property in ["rotation","position","modulate:a"]:
				var track := animation.add_track(Animation.TYPE_VALUE)
				animation.track_set_path(track,NodePath(node_path+":"+property))
				for frame in action.poses.size():
					var pose: Dictionary = action.poses[frame].get(layer.name,{})
					var value: Variant
					match property:
						"rotation": value = deg_to_rad(float(pose.get("r",0)))
						"position": value = pivots[layer.name]-pivots[layer.parent]+vec(pose.get("p",[0,0]))
						_: value = float(pose.get("a",0 if layer.name == "rage_rune" else 1))
					animation.track_insert_key(track,float(frame)/float(action.fps),value)
		library.add_animation(id,animation)
	animator.add_animation_library("",library)
	var packed := PackedScene.new()
	packed.pack(rig)
	ResourceSaver.save(packed,folder+data.entity+"_editable_draft.tscn")
	var roundtrip := ResourceLoader.load(folder+data.entity+"_editable_draft.tscn","PackedScene",ResourceLoader.CACHE_MODE_IGNORE) as PackedScene
	if roundtrip == null:
		failures += 1
		push_error("Editable scene failed to reload: "+str(data.entity))
	else:
		var restored := roundtrip.instantiate()
		var restored_player := restored.get_node("AnimationPlayer") as AnimationPlayer
		for id in data.actions:
			if not restored_player.has_animation(id):
				failures += 1
				push_error("Editable scene lost animation: "+str(id))
		restored.free()
	var viewport := SubViewport.new()
	viewport.size = Vector2i(data.canvas,data.canvas)
	viewport.transparent_bg = true
	viewport.render_target_update_mode = SubViewport.UPDATE_ALWAYS
	root.add_child(viewport)
	viewport.add_child(rig)
	var manifest := {"status":"draft","source":path,"size":[data.runtime_size,data.runtime_size],"anchor":[float(data.anchor[0])/2,float(data.anchor[1])/2],"actions":{}}
	var html := "<!doctype html><meta charset='utf-8'><title>Draft rig review</title><style>body{background:#17212c;color:#eee;font:16px sans-serif}section{display:inline-block;vertical-align:top;width:400px}img{background:repeating-conic-gradient(#37404a 0% 25%,#26303a 0% 50%) 0/20px 20px}button{padding:12px}strong{color:#ffba80}</style><h1>DRAFT — 分层绑定审查，未接入游戏</h1><p>原速/0.25速/暂停/逐帧；这里只证明源可编辑，不代表动作验收。</p><button onclick='speed=1'>原速</button><button onclick='speed=.25'>慢速</button><button onclick='paused=!paused'>暂停</button><button onclick='paused=true;step++'>逐帧</button>"
	var js_data := {}
	for id in data.actions:
		var action: Dictionary = data.actions[id]
		DirAccess.make_dir_recursive_absolute(folder+data.entity+"_frames/"+id)
		var frames: Array = []
		var effects_frames: Array = []
		var combined_frames: Array = []
		var metrics: Array = []
		var contact := Image.create(int(data.runtime_size)*4,int(data.runtime_size)*ceili(float(action.poses.size())/4),false,Image.FORMAT_RGBA8)
		for frame in action.poses.size():
			for layer in data.layers:
				var paint: Sprite2D = bones[layer.name].get_node_or_null("Paint")
				if paint != null: paint.visible = true
			animator.play(id)
			animator.seek(float(frame)/float(action.fps),true)
			animator.pause()
			await process_frame
			await RenderingServer.frame_post_draw
			var master := viewport.get_texture().get_image()
			var image := master.duplicate() as Image
			image.resize(int(data.runtime_size),int(data.runtime_size),Image.INTERPOLATE_LANCZOS)
			contact.blit_rect(image,Rect2i(Vector2i.ZERO,image.get_size()),Vector2i((frame%4)*int(data.runtime_size),int(frame/4)*int(data.runtime_size)))
			if id in data.get("effect_actions",[]):
				var combined: String = data.entity+"_frames/"+id+"/%02d_combined.png" % frame
				image.save_png(folder+combined)
				combined_frames.append(combined)
				for effect in data.get("effect_layers",[]): bones[effect].get_node("Paint").visible = false
				await process_frame
				await RenderingServer.frame_post_draw
				image = viewport.get_texture().get_image()
				image.resize(int(data.runtime_size),int(data.runtime_size),Image.INTERPOLATE_LANCZOS)
				for layer in data.layers:
					var paint: Sprite2D = bones[layer.name].get_node_or_null("Paint")
					if paint != null: paint.visible = layer.name in data.get("effect_layers",[])
				await process_frame
				await RenderingServer.frame_post_draw
				var effect_image := viewport.get_texture().get_image()
				effect_image.resize(int(data.runtime_size),int(data.runtime_size),Image.INTERPOLATE_LANCZOS)
				var effect_path: String = data.entity+"_frames/"+id+"/%02d_effect.png" % frame
				effect_image.save_png(folder+effect_path)
				effects_frames.append(effect_path)
			var relative: String = data.entity+"_frames/"+id+"/%02d.png" % frame
			image.save_png(folder+relative)
			frames.append(relative)
			var used := image.get_used_rect()
			metrics.append({"frame":frame,"bounds":[used.position.x,used.position.y,used.size.x,used.size.y],"edge_touch":used.position.x<4 or used.position.y<4 or used.end.x>int(data.runtime_size)-4 or used.end.y>int(data.runtime_size)-4})
		contact.save_png(output_root+data.entity+"_"+id+"_draft_contact.png")
		manifest.actions[id] = {"frames":frames,"fps":action.fps,"loop":action.loop,"events":action.events,"metrics":metrics}
		manifest.actions[id]["pose_holds"] = data.get("pose_holds",{}).get(id,{})
		if not effects_frames.is_empty():
			manifest.actions[id]["effects_frames"] = effects_frames
			manifest.actions[id]["combined_frames"] = combined_frames
		js_data[id] = {"frames":frames,"fps":action.fps}
		html += "<section><h2>"+data.entity+" / "+id+" <strong>draft</strong></h2><img id='"+id+"' width='384'><p>格子：<img id='"+id+"_47' width='47'><img id='"+id+"_33' width='33'><img id='"+id+"_26' width='26'></p></section>"
	html += "<script>let data="+JSON.stringify(js_data)+",speed=1,paused=false,step=0,t=0,last=performance.now();function loop(now){if(!paused)t+=(now-last)/1000*speed;last=now;for(let [id,a] of Object.entries(data)){let i=(Math.floor(t*a.fps)+step)%a.frames.length;for(let suffix of ['', '_47','_33','_26'])document.getElementById(id+suffix).src=a.frames[i]}requestAnimationFrame(loop)}requestAnimationFrame(loop)</script>"
	FileAccess.open(folder+data.entity+"_review.html",FileAccess.WRITE).store_string(html)
	FileAccess.open(folder+data.entity+"_draft_manifest.json",FileAccess.WRITE).store_string(JSON.stringify(manifest,"\t"))
	review.append({"entity":data.entity,"native_atlas":[atlas.get_width(),atlas.get_height()],"source":path,"status":"draft","actions":manifest.actions})
	viewport.queue_free()
	await process_frame
