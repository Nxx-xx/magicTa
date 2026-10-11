extends SceneTree
## Editable independent-view rigs. This tool bakes review assets, never accepts them.
const ROOT := "res://assets/characters/hero/phase3/source/rig_v03/"
const OUT := "res://build/verification/phase3/07-completion/"
const DIRECTIONS := ["down", "up", "left", "right"]
var failures := 0
var rig: Node2D
var bones: Dictionary
var base: Dictionary
var atlas: Image
var direction := ""

func _initialize() -> void:
	if not ProjectSettings.globalize_path("user://").replace("\\", "/").contains("phase3/07-completion/"):
		quit(2)
		return
	_run.call_deferred()

func _run() -> void:
	DirAccess.make_dir_recursive_absolute(OUT)
	var review := {"status":"draft", "source":"imagegen independent views; Godot editable joint/animation scenes", "actions":{}}
	for facing in DIRECTIONS:
		direction = facing
		atlas = Image.load_from_file(ROOT + "components_" + direction + ".png")
		rig = Node2D.new()
		rig.name = "Hero_" + direction
		bones = {"root":rig}
		base = {}
		_build()
		var player := AnimationPlayer.new()
		player.name = "AnimationPlayer"
		rig.add_child(player)
		player.owner = rig
		var library := AnimationLibrary.new()
		var specs := {"idle":[4,6,true], "walk":[6,12,true], "interact":[4,10,false]}
		if direction == "right":
			specs.merge({"combat_idle":[6,6,true],"attack":[8,16,false],"guard":[4,12,false],"hit":[3,12,false],"victory":[8,12,false],"defeat":[6,10,false]})
		var viewport := SubViewport.new()
		viewport.size = Vector2i(768,768)
		viewport.transparent_bg = true
		viewport.render_target_update_mode = SubViewport.UPDATE_ALWAYS
		root.add_child(viewport)
		viewport.add_child(rig)
		for action in specs:
			var spec: Array = specs[action]
			var poses := []
			var foot_contacts := []
			var animation := Animation.new()
			animation.length = float(spec[0])/float(spec[1])
			animation.loop_mode = Animation.LOOP_LINEAR if spec[2] else Animation.LOOP_NONE
			for frame in int(spec[0]):
				_pose(action, frame, int(spec[0]))
				foot_contacts.append({"right":[bones.right_ankle.global_position.x/6.0,bones.right_ankle.global_position.y/6.0],"left":[bones.left_ankle.global_position.x/6.0,bones.left_ankle.global_position.y/6.0]})
				var pose := {}
				for id in base:
					pose[id] = {"position":bones[id].position,"rotation":bones[id].rotation,"scale":bones[id].scale,"modulate":bones[id].modulate}
				poses.append(pose)
			for id in base:
				for property in ["position","rotation","scale","modulate"]:
					var track := animation.add_track(Animation.TYPE_VALUE)
					animation.track_set_path(track, NodePath(str(rig.get_path_to(bones[id]))+":"+property))
					for frame in poses.size(): animation.track_insert_key(track, float(frame)/float(spec[1]), poses[frame][id][property])
			library.add_animation(action,animation)
			var combat: bool = action not in ["idle","walk","interact"]
			var size := 384 if combat else 128
			var action_id: String = "combat_" + action.trim_prefix("combat_") if combat else "map_"+action+"_"+direction
			DirAccess.make_dir_recursive_absolute(ROOT+"frames/"+action_id)
			var contact := Image.create(size*int(spec[0]),size,false,Image.FORMAT_RGBA8)
			var frames := []
			var bounds := []
			for frame in poses.size():
				for id in base:
					for property in poses[frame][id]: bones[id].set(property,poses[frame][id][property])
				await process_frame
				await RenderingServer.frame_post_draw
				var baked := viewport.get_texture().get_image()
				baked.resize(size,size,Image.INTERPOLATE_LANCZOS)
				var path := ROOT+"frames/"+action_id+"/%02d.png" % frame
				baked.save_png(path)
				frames.append(path)
				contact.blit_rect(baked,Rect2i(0,0,size,size),Vector2i(frame*size,0))
				var used := baked.get_used_rect()
				bounds.append([used.position.x,used.position.y,used.end.x,used.end.y])
				if used.position.x < 4 or used.position.y < 4 or used.end.x > size-4 or used.end.y > size-4: failures += 1
			contact.save_png(OUT+action_id+"_v03.png")
			review.actions[action_id] = {"status":"draft","frames":frames,"fps":spec[1],"loop":spec[2],"size":[size,size],"anchor":[size/2,size*116/128],"bounds":bounds,"foot_contacts_map_px":foot_contacts,"events":{"hit":3} if action == "attack" else {}}
		player.add_animation_library("",library)
		var scene := PackedScene.new()
		scene.pack(rig)
		ResourceSaver.save(scene,ROOT+"hero_"+direction+"_editable.tscn")
		var restored: Node = load(ROOT+"hero_"+direction+"_editable.tscn").instantiate()
		if restored.get_node("AnimationPlayer").get_animation_list().size() != specs.size(): failures += 1
		restored.free()
		viewport.queue_free()
		await process_frame
	FileAccess.open(ROOT+"review_manifest.json",FileAccess.WRITE).store_string(JSON.stringify(review,"\t"))
	print("HERO_V03 %d actions; %d boundary/reload failures; draft only" % [review.actions.size(),failures])
	quit(1 if failures else 0)

func _joint(id: String, parent: String, at: Vector2) -> void:
	var node := Node2D.new()
	node.name = id
	bones[parent].add_child(node)
	node.owner = rig
	node.position = at - (bones[parent].global_position if parent != "root" else Vector2.ZERO)
	bones[id] = node
	base[id] = {"position":node.position,"rotation":0.0,"scale":Vector2.ONE,"modulate":Color.WHITE}

func _part(id: String, part_index: int, parent: String, at: Vector2, pin: Vector2, height: float, z: int) -> void:
	_joint(id,parent,at)
	var rects: Array
	if direction == "right":
		rects = [[15,10,310,365],[400,40,230,350],[650,0,310,395],[1020,70,225,285],[80,410,185,250],[390,415,225,255],[660,405,310,290],[1030,415,190,260],[65,700,210,250],[410,700,160,260],[690,690,230,255],[1020,685,220,275],[60,960,220,260],[365,960,220,280]]
	elif direction == "left":
		rects = [[0,0,338,340],[360,0,265,380],[670,0,350,380],[1020,0,260,375],[65,380,205,270],[345,390,260,280],[630,380,345,300],[1030,380,210,260],[45,680,245,250],[400,675,180,280],[700,680,240,280],[990,670,245,290],[45,950,245,295],[320,965,250,285]]
	else:
		rects = [[15,5,335,340],[375,0,255,352],[645,0,315,358],[962,15,308,325],[60,350,230,278],[385,352,225,285],[690,352,215,288],[1000,345,242,280],[70,640,205,279],[390,642,220,277],[680,640,260,281],[1015,635,223,285],[65,925,225,285],[370,925,220,285]]
	var r: Array = rects[part_index]
	var cropped := atlas.get_region(Rect2i(r[0],r[1],r[2],r[3]))
	var used := cropped.get_used_rect()
	cropped = cropped.get_region(used)
	var texture := ImageTexture.create_from_image(cropped)
	DirAccess.make_dir_recursive_absolute(ROOT+direction+"_layers")
	cropped.save_png(ROOT+direction+"_layers/"+id+".png")
	ResourceSaver.save(texture,ROOT+direction+"_layers/"+id+".res",ResourceSaver.FLAG_CHANGE_PATH)
	texture.take_over_path(ROOT+direction+"_layers/"+id+".res")
	var sprite := Sprite2D.new()
	sprite.name = "Paint"
	sprite.texture = texture
	sprite.centered = false
	sprite.scale = Vector2.ONE*height/float(cropped.get_height())
	sprite.position = -pin*Vector2(cropped.get_size())*sprite.scale
	sprite.z_index = z
	sprite.z_as_relative = false
	bones[id].add_child(sprite)
	sprite.owner = rig

func _build() -> void:
	var side: bool = direction in ["left","right"]
	var s := -1.0 if direction == "left" else 1.0
	var rx := 357.0 if direction == "down" else 411.0
	var lx := 411.0 if direction == "down" else 357.0
	if side:
		rx = 394 if direction == "right" else 374
		lx = 374 if direction == "right" else 394
	_joint("pelvis","root",Vector2(384,495))
	_part("torso",1,"pelvis",Vector2(384,495),Vector2(.5,.9),215,0)
	_part("cape",2,"torso",Vector2(384-s*12 if side else 384,290),Vector2(.5,.1),310,6 if direction == "up" else -6)
	_part("head",0,"torso",Vector2(394 if direction == "right" else (374 if side else 384),300),Vector2(.57 if direction == "right" else (.43 if side else .5),.9),230,8)
	if direction != "up": _part("collar",3,"torso",Vector2(384,306),Vector2(.5,.1),110,7)
	for limb in ["right","left"]:
		var x: float = rx if limb == "right" else lx
		var near: bool = (limb == "right") == (direction == "right") if side else true
		var index := 10 if limb == "right" else 12
		_part(limb+"_hip",index,"pelvis",Vector2(x,488),Vector2(.5,.12),112,1 if near else -4)
		_part(limb+"_knee",index+1,limb+"_hip",Vector2(x,584),Vector2(.52,.08),122,2 if near else -3)
		_joint(limb+"_ankle",limb+"_knee",Vector2(x,696))
		var shoulder_x: float = (x + (14 if limb == "left" else -14)) if not side else (382 if near else 404)
		if direction == "up": shoulder_x = x+(14 if limb == "right" else -14)
		var elbow := Vector2(shoulder_x + (s*3 if side else (shoulder_x-384)*.25),413)
		var hand := elbow + Vector2(s*22 if side else (shoulder_x-384)*.3,85)
		var arm_index := 4 if limb == "right" else 7
		_part(limb+"_shoulder",arm_index,"torso",Vector2(shoulder_x,323),Vector2(.5,.13),112,4 if near else -3)
		var upper: Sprite2D = bones[limb+"_shoulder"].get_node("Paint")
		var elbow_uv := Vector2(.38 if limb == "right" else .65,.9)
		elbow = bones[limb+"_shoulder"].global_position+upper.position+elbow_uv*upper.texture.get_size()*upper.scale
		_part(limb+"_elbow",5 if limb == "right" else 8,limb+"_shoulder",elbow,Vector2(.3 if direction == "right" and limb == "right" else (.7 if direction == "left" else .5),.1),115,5 if near else -2)
		var forearm: Sprite2D = bones[limb+"_elbow"].get_node("Paint")
		var grip := Vector2(.64 if limb == "right" else .38,.86)
		if direction == "right": grip.x = .84 if limb == "right" else .24
		elif direction == "left": grip.x = .23
		hand = bones[limb+"_elbow"].global_position+forearm.position+grip*forearm.texture.get_size()*forearm.scale
		_joint(limb+"_wrist",limb+"_elbow",hand)
		if limb == "right":
			_part("sword",6,limb+"_wrist",hand,Vector2(.22 if direction == "right" else (.8 if direction == "left" else .5),.20),145,4 if near else -2)
		else:
			# Separate silhouette beside the body; far arm remains anatomically left.
			_part("lantern",9,limb+"_wrist",hand,Vector2(.5,.08),128,5 if near else -1)

func _pose(action: String, frame: int, count: int) -> void:
	for id in base:
		for property in base[id]: bones[id].set(property,base[id][property])
	var phase := TAU*float(frame)/float(count)
	var side: bool = direction in ["left","right"]
	var s := -1.0 if direction == "left" else 1.0
	if action in ["idle","combat_idle","interact","walk"]:
		bones.head.rotation = deg_to_rad(sin(phase)*.7)
		bones.cape.rotation = deg_to_rad(sin(phase+.3)*1.2)
		bones.lantern.rotation = deg_to_rad(sin(phase)*2)
	if action == "walk":
		bones.pelvis.position.y -= abs(sin(phase))*5
		for limb in ["right","left"]:
			var p: float = phase + (PI if limb == "left" else 0)
			var neutral: Vector2 = Vector2(384,495)+base[limb+"_hip"].position+base[limb+"_knee"].position+base[limb+"_ankle"].position
			# Plant during the backwards relative stroke; lift only on forward recovery.
			var lift := maxf(0,-sin(p))*23
			var target := neutral+Vector2(cos(p)*25*s if side else cos(p)*4, -lift)
			_leg(limb,target,1.0 if direction != "left" else -1.0)
			bones[limb+"_shoulder"].rotation = deg_to_rad(sin(p)*9*s)
	if action == "interact":
		var reach: float = [0.0,.5,1.0,.25][frame]
		bones.left_shoulder.rotation = deg_to_rad(-32*s*reach)
		bones.left_elbow.rotation = deg_to_rad(-20*s*reach)
		bones.lantern.rotation = deg_to_rad(52*s*reach)
	if action in ["attack","guard","hit","victory","defeat"]:
		var values: Array
		match action:
			"attack":
				values = [0.0,-.3,-1.0,1.0,.75,.35,.1,0.0]
				var v: float = values[frame]
				bones.torso.rotation = deg_to_rad(v*10)
				bones.right_shoulder.rotation = deg_to_rad(-v*65)
				bones.right_elbow.rotation = deg_to_rad(v*10)
				bones.head.rotation = deg_to_rad(-v*6)
				bones.cape.rotation = deg_to_rad(-v*8)
				bones.pelvis.position += Vector2(v*8,-abs(v)*4)
			"guard":
				var v: float = [0.0,.8,1.0,.15][frame]
				bones.left_shoulder.rotation = deg_to_rad(-v*38)
				bones.left_elbow.rotation = deg_to_rad(-v*25)
				bones.lantern.rotation = deg_to_rad(v*63)
			"hit":
				var v: float = [0.0,1.0,.25][frame]
				bones.torso.rotation = deg_to_rad(-v*12)
				bones.head.rotation = deg_to_rad(-v*7)
				bones.pelvis.position.x -= v*7
			"victory":
				var v: float = [0.0,.25,.6,1.0,1.0,.9,.85,.8][frame]
				bones.left_shoulder.rotation = deg_to_rad(-v*125)
				bones.left_elbow.rotation = deg_to_rad(v*25)
				bones.lantern.rotation = deg_to_rad(v*100)
				bones.right_shoulder.rotation = deg_to_rad(v*15)
			"defeat":
				var v := float(frame)/float(count-1)
				bones.pelvis.position += Vector2(-v*12,v*60)
				bones.torso.rotation = deg_to_rad(v*24)
				bones.head.rotation = deg_to_rad(v*12)
				bones.lantern.modulate = Color(1-v*.65,1-v*.65,1-v*.65,1)
		for limb in ["right","left"]:
			var neutral: Vector2 = Vector2(384,495)+base[limb+"_hip"].position+base[limb+"_knee"].position+base[limb+"_ankle"].position
			if action == "defeat": neutral.x += (45 if limb == "right" else -25)*float(frame)/float(count-1)
			_leg(limb,neutral,1.0)

func _leg(limb: String, foot: Vector2, bend: float) -> void:
	var hip: Node2D = bones[limb+"_hip"]
	var knee: Node2D = bones[limb+"_knee"]
	var thigh: float = base[limb+"_knee"].position.length()
	var shin: float = base[limb+"_ankle"].position.length()
	var delta := foot-hip.global_position
	var distance := clampf(delta.length(),absf(thigh-shin)+.01,thigh+shin-.01)
	var offset := acos(clampf((thigh*thigh+distance*distance-shin*shin)/(2*thigh*distance),-1,1))*bend
	hip.rotation = delta.angle()-PI/2-offset
	var joint := hip.global_position+Vector2.DOWN.rotated(hip.rotation)*thigh
	knee.rotation = (foot-joint).angle()-PI/2-hip.rotation
