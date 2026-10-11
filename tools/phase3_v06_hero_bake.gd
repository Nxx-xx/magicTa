extends SceneTree
## Native source authoring and draft bake only. Approval/publication are separate.
const SOURCE := "res://assets/characters/hero/phase3/source/refine_v06/"
const OUT := "res://build/verification/phase3/09-refinement/hero/"
const PARTS := ["head","hair_front","hair_back","torso","cape","collar","skirt","right_upper_arm","right_forearm","right_hand","left_upper_arm","left_forearm","left_hand","sword","lantern","right_thigh","right_shin","right_foot","left_thigh","left_shin","left_foot","brooch","lamp_light","blade_glint","cape_hem"]
var directions := ["right"]
var rig: Node2D
var joints: Dictionary
var base: Dictionary
var atlas: Image
var facing := "right"
var failures := 0
var layer_records := {}

func _initialize() -> void:
	if not ProjectSettings.globalize_path("user://").replace("\\","/").contains("08-parallel/hero_refine/"):
		quit(2)
		return
	for arg in OS.get_cmdline_user_args():
		if arg == "--all": directions = ["right","down","up","left"]
	_run.call_deferred()

func _run() -> void:
	DirAccess.make_dir_recursive_absolute(OUT)
	var draft := {"version":1,"status":"draft","handedness":"right_sword_left_lantern","mirrored":false,"human_signoff":false,"actions":{},"source_canvas":[768,768]}
	for direction in directions:
		facing = direction
		atlas = Image.load_from_file(SOURCE+"components_"+facing+".png")
		rig = Node2D.new()
		rig.name = "Hero_"+facing
		joints = {"root":rig}
		base = {}
		layer_records = {}
		_build()
		var player := AnimationPlayer.new()
		player.name = "AnimationPlayer"
		rig.add_child(player)
		player.owner = rig
		var library := AnimationLibrary.new()
		var specs := {"idle":[4,6,true],"walk":[6,12,true],"interact":[4,10,false]}
		if facing == "right": specs.merge({"combat_idle":[6,6,true],"attack":[8,16,false],"guard":[4,12,false],"hit":[3,12,false],"victory":[8,12,false],"defeat":[6,10,false]})
		var viewport := SubViewport.new()
		viewport.size = Vector2i(768,768)
		viewport.transparent_bg = true
		viewport.render_target_update_mode = SubViewport.UPDATE_ALWAYS
		root.add_child(viewport)
		viewport.add_child(rig)
		for action in specs:
			var spec: Array = specs[action]
			var size: int = 128 if action in ["idle","walk","interact"] else 384
			var id: String = "map_"+action+"_"+facing if size == 128 else "combat_"+action.trim_prefix("combat_")
			var folder := SOURCE+"frames/"+id+"/"
			DirAccess.make_dir_recursive_absolute(folder)
			DirAccess.make_dir_recursive_absolute(SOURCE+"effects/"+id+"/")
			var poses := []
			var contacts := []
			var grips := []
			for frame in int(spec[0]):
				_pose(action,frame,int(spec[0]))
				var pose := {}
				for joint in base:
					pose[joint] = {}
					for property in base[joint]: pose[joint][property] = joints[joint].get(property)
				poses.append(pose)
				var right_contact: Vector2 = joints.right_contact.global_position/6
				var left_contact: Vector2 = joints.left_contact.global_position/6
				contacts.append({"right":[right_contact.x,right_contact.y],"left":[left_contact.x,left_contact.y]})
				grips.append({"sword_error":joints.sword.global_position.distance_to(joints.right_grip.global_position),"lamp_error":joints.lantern.global_position.distance_to(joints.left_grip.global_position)})
			var animation := Animation.new()
			animation.length = float(spec[0])/float(spec[1])
			animation.loop_mode = Animation.LOOP_LINEAR if spec[2] else Animation.LOOP_NONE
			for joint in base:
				for property in base[joint]:
					var track := animation.add_track(Animation.TYPE_VALUE)
					animation.track_set_path(track,NodePath(str(rig.get_path_to(joints[joint]))+":"+property))
					for frame in poses.size(): animation.track_insert_key(track,float(frame)/float(spec[1]),poses[frame][joint][property])
			library.add_animation(id,animation)
			var frames := []
			var effects := []
			var bounds := []
			for frame in poses.size():
				for joint in base:
					for property in poses[frame][joint]: joints[joint].set(property,poses[frame][joint][property])
				for name in ["lamp_light","blade_glint"]: joints[name].visible = false
				await process_frame
				await RenderingServer.frame_post_draw
				var image := viewport.get_texture().get_image()
				image.resize(size,size,Image.INTERPOLATE_LANCZOS)
				var path := folder+"%02d.png" % frame
				image.save_png(path)
				frames.append(path)
				var used := image.get_used_rect()
				bounds.append([used.position.x,used.position.y,used.end.x,used.end.y])
				if used.position.x < 4 or used.position.y < 4 or used.end.x > size-4 or used.end.y > size-4: failures += 1
				# Render optional light separately; transparent unused frames are valid.
				for name in PARTS:
					if joints.has(name): joints[name].get_node("Paint").visible = name in ["lamp_light","blade_glint"]
				for name in ["lamp_light","blade_glint"]: joints[name].visible = poses[frame][name].visible
				await process_frame
				await RenderingServer.frame_post_draw
				image = viewport.get_texture().get_image()
				image.resize(size,size,Image.INTERPOLATE_LANCZOS)
				path = SOURCE+"effects/"+id+"/%02d.png" % frame
				image.save_png(path)
				effects.append(path)
				for name in PARTS:
					if joints.has(name): joints[name].get_node("Paint").visible = true
			draft.actions[id] = {"status":"draft","frames":frames,"effects_frames":effects,"fps":spec[1],"loop":spec[2],"size":[size,size],"anchor":[size/2,348 if size == 384 else 116],"events":{"hit":3} if action == "attack" else {},"source":"source/refine_v06/hero_"+facing+"_editable.tscn","review":"source/refine_v06/REVIEW.md","bounds":bounds,"foot_contacts_map_px":contacts,"grip_errors_source_px":grips,"pose_holds":{}}
		player.add_animation_library("",library)
		_pose("idle",0,4)
		var scene := PackedScene.new()
		scene.pack(rig)
		ResourceSaver.save(scene,SOURCE+"hero_"+facing+"_editable.tscn")
		FileAccess.open(SOURCE+"rig_"+facing+".json",FileAccess.WRITE).store_string(JSON.stringify({"canvas":[768,768],"facing":facing,"mirrored":false,"layers":layer_records,"solver":"two-bone IK; independent wrists and foot rotation; contact at sole, not ankle","actions":specs,"author":"res://tools/phase3_v06_hero_bake.gd"},"\t"))
		viewport.queue_free()
		await process_frame
	FileAccess.open(SOURCE+"draft_manifest.json",FileAccess.WRITE).store_string(JSON.stringify(draft,"\t"))
	print("HERO_V06 draft only: %d actions; %d boundary failures" % [draft.actions.size(),failures])
	quit(1 if failures else 0)

func _joint(id: String,parent: String,position: Vector2) -> void:
	var node := Node2D.new()
	node.name = id
	joints[parent].add_child(node)
	node.owner = rig
	node.position = position
	joints[id] = node
	base[id] = {"position":position,"rotation":0.0,"scale":Vector2.ONE,"modulate":Color.WHITE,"visible":true}

func _part(id: String,parent: String,position: Vector2,pivot: Vector2,height: float,z: int) -> void:
	_joint(id,parent,position)
	var rects := [[22,28,265,281],[302,58,185,217],[515,62,228,224],[795,45,195,202],[1000,10,239,320],[20,330,249,215],[290,330,222,222],[548,310,177,235],[817,330,151,219],[1030,370,179,178],[62,550,160,231],[333,570,133,221],[570,586,153,177],[815,540,130,264],[1060,538,137,260],[49,786,195,252],[302,786,174,247],[539,822,202,191],[794,786,194,252],[1040,786,157,247],[60,1050,197,183],[307,1041,191,189],[492,1021,274,259],[797,1023,188,249],[1030,1011,193,224]]
	var r: Array = rects[PARTS.find(id)]
	# Other views use an explicit crop table, never image mirroring.
	if facing != "right":
		var config: Dictionary = JSON.parse_string(FileAccess.get_file_as_string(SOURCE+"crops_"+facing+".json"))
		r = config[id]
	var cropped := atlas.get_region(Rect2i(r[0],r[1],r[2],r[3]))
	cropped = cropped.get_region(cropped.get_used_rect())
	DirAccess.make_dir_recursive_absolute(SOURCE+facing+"_layers/")
	cropped.save_png(SOURCE+facing+"_layers/"+id+".png")
	var texture := ImageTexture.create_from_image(cropped)
	ResourceSaver.save(texture,SOURCE+facing+"_layers/"+id+".res",ResourceSaver.FLAG_CHANGE_PATH)
	texture.take_over_path(SOURCE+facing+"_layers/"+id+".res")
	var sprite := Sprite2D.new()
	sprite.name = "Paint"
	sprite.texture = texture
	sprite.centered = false
	sprite.scale = Vector2.ONE*height/float(cropped.get_height())
	sprite.position = -pivot*Vector2(cropped.get_size())*sprite.scale
	sprite.z_index = z
	sprite.z_as_relative = false
	joints[id].add_child(sprite)
	sprite.owner = rig
	layer_records[id] = {"parent":parent,"joint_position":[position.x,position.y],"pivot_uv":[pivot.x,pivot.y],"paint_height":height,"z":z,"crop":r,"texture":SOURCE+facing+"_layers/"+id+".png"}

func _build() -> void:
	var side := facing in ["right","left"]
	var s := -1.0 if facing == "left" else 1.0
	_joint("pelvis","root",Vector2(384,492))
	_part("torso","pelvis",Vector2(0,-10),Vector2(.5,.92),176,0)
	_part("cape","torso",Vector2(-s*12 if side else 0,-169),Vector2(.5,.08),326,7 if facing == "up" else -8)
	_part("cape_hem","cape",Vector2(-s*14,224),Vector2(.5,.02),94,8 if facing == "up" else -7)
	_part("skirt","pelvis",Vector2(0,-18),Vector2(.5,.05),121,2)
	_part("head","torso",Vector2(s*10 if side else 0,-180),Vector2(.58 if facing == "right" else (.42 if facing == "left" else .5),.90),213,9)
	if facing == "up":
		_part("hair_back","head",Vector2(12,-6),Vector2(.5,.05),42,8)
		_part("hair_front","head",Vector2(-12,-8),Vector2(.5,.05),42,8)
	else:
		_part("hair_back","head",Vector2(-s*17 if side else 0,-49),Vector2(.5,.7),117,8)
		_part("hair_front","head",Vector2(s*42 if side else 0,-91),Vector2(.5,.56),144,10)
	_part("collar","torso",Vector2(0,-178),Vector2(.5,.12),95,11 if facing != "up" else 3)
	_part("brooch","collar",Vector2(s*28 if side else 0,29),Vector2(.5,.5),22,12)
	for limb in ["right","left"]:
		var near: bool = (limb == "right") == (facing == "right") if side else true
		var x: float = 15 if limb == "right" else -15
		if facing == "down": x = -26 if limb == "right" else 26
		if facing == "up": x = 26 if limb == "right" else -26
		_part(limb+"_thigh","pelvis",Vector2(x,4),Vector2(.5,.10),107,1 if near else -5)
		_part(limb+"_shin",limb+"_thigh",Vector2(0,92),Vector2(.5,.08),99,2 if near else -4)
		_part(limb+"_foot",limb+"_shin",Vector2(0,82),Vector2(.32 if facing == "right" else (.68 if facing == "left" else .5),.17),39,3 if near else -3)
		_joint(limb+"_contact",limb+"_foot",Vector2(0,26))
		var sx: float = (16 if near else -17) if side else x*1.7
		_part(limb+"_upper_arm","torso",Vector2(sx,-158),Vector2(.5,.12),109,5 if near else -4)
		_part(limb+"_forearm",limb+"_upper_arm",Vector2(0,86),Vector2(.5,.07),90,6 if near else -3)
		_part(limb+"_hand",limb+"_forearm",Vector2(0,77),Vector2(.42 if facing == "right" else (.58 if facing == "left" else .5),.1),43,8 if near else -2)
		_joint(limb+"_grip",limb+"_hand",Vector2(s*7 if side else 0,24))
	_part("sword","right_grip",Vector2.ZERO,Vector2(.5,.20),160,7)
	_part("lantern","left_grip",Vector2.ZERO,Vector2(.5,.09),112,7)
	_part("lamp_light","lantern",Vector2(0,61),Vector2(.5,.5),65,13)
	_part("blade_glint","sword",Vector2(0,82),Vector2(.5,.5),44,13)
	base.blade_glint.visible = false

func _pose(action: String,frame: int,count: int) -> void:
	for id in base:
		for property in base[id]: joints[id].set(property,base[id][property])
	var p := TAU*float(frame)/float(count)
	var side := facing in ["right","left"]
	var s := -1.0 if facing == "left" else 1.0
	var breath := sin(p)
	var body := Vector2(0,-breath*1.4)
	var torso_angle := breath*.35
	var left_reach := 0.0
	var sword_angle := 0.0
	var foot_targets := {"right":Vector2(399,696),"left":Vector2(369,696)}
	if facing == "down": foot_targets = {"right":Vector2(358,696),"left":Vector2(410,696)}
	if facing == "up": foot_targets = {"right":Vector2(410,696),"left":Vector2(358,696)}
	if action == "walk":
		body = Vector2(sin(p)*1.5 if not side else 0,-absf(sin(p))*7)
		torso_angle = sin(p)*1.8
		for limb in ["right","left"]:
			var phase: float = p+(PI if limb == "left" else 0)
			foot_targets[limb] += Vector2(cos(phase)*27*s if side else cos(phase)*5,-maxf(0,-sin(phase))*31)
	if action == "interact":
		left_reach = [0.0,.55,1.0,.12][frame]
		body.x += s*left_reach*3
		torso_angle = s*left_reach*3
	if action == "attack":
		var v: float = [0.0,-.28,-.8,1.0,.72,.32,.08,0.0][frame]
		body = Vector2(v*17,-absf(v)*9)
		torso_angle = v*8
		sword_angle = [8.0,28.0,88.0,-92.0,-65.0,-25.0,2.0,8.0][frame]
		foot_targets.right += Vector2(maxf(v,0)*18,0)
	if action == "guard":
		left_reach = [0.0,.65,1.0,.1][frame]
		body = Vector2(-left_reach*10,left_reach*11)
		torso_angle = -left_reach*5
		sword_angle = -left_reach*20
	if action == "hit":
		var v: float = [0.0,1.0,.12][frame]
		body = Vector2(-v*17,v*13)
		torso_angle = -v*13
		sword_angle = v*17
	if action == "victory":
		left_reach = [0.0,.18,.5,.88,1.0,.94,.89,.85][frame]
		body.y = -left_reach*4
		torso_angle = -left_reach*2
		sword_angle = left_reach*12
	if action == "defeat":
		var v := float(frame)/float(count-1)
		body = Vector2(-v*16,v*94)
		torso_angle = v*19
		sword_angle = v*35
		foot_targets.right += Vector2(v*37,0)
		foot_targets.left += Vector2(-v*17,0)
		joints.lamp_light.modulate.a = 1-v*.94
		joints.head.rotation = deg_to_rad(v*13)
	joints.pelvis.position += body
	joints.torso.rotation = deg_to_rad(torso_angle)
	for limb in ["right","left"]:
		var phase: float = p+(PI if limb == "left" else 0)
		var tilt := (maxf(0,-sin(phase))*-10*s) if action == "walk" else 0.0
		_leg(limb,foot_targets[limb],tilt)
		var shoulder: Vector2 = joints[limb+"_upper_arm"].global_position
		var lateral: float = s*14 if side else ((18 if limb == "left" else -18)*(-1 if facing == "up" else 1))
		var target := shoulder+Vector2(lateral,158)
		if action == "walk": target.x += sin(phase)*s*19
		if limb == "left":
			if action == "victory": target += Vector2(left_reach*95,-left_reach*250)
			elif facing == "up": target += Vector2(-left_reach*20,-left_reach*94)
			elif facing == "down": target += Vector2(left_reach*20,-left_reach*54)
			else: target += Vector2(s*left_reach*93,-left_reach*86)
		elif action == "attack":
			var reach: float = [0.0,-.25,-.65,1.0,.65,.18,.05,0.0][frame]
			target += Vector2(reach*111,-absf(reach)*76)
		_arm(limb,target,-1.0 if limb == "right" else 1.0)
		# Hands and held objects have their own true wrist tracks.
		joints[limb+"_hand"].rotation = -joints[limb+"_forearm"].global_rotation+deg_to_rad(sword_angle if limb == "right" else 0.0)
	# Lamp stays upright; physical ring remains at grip, swing is secondary.
	joints.lantern.rotation = -joints.left_grip.global_rotation+deg_to_rad(sin(p-.4)*2.0 if action != "defeat" else 4.0*float(frame)/float(count-1))
	joints.cape.rotation = deg_to_rad(-torso_angle*.6+sin(p-.65)*1.8)
	joints.cape_hem.rotation = deg_to_rad(sin(p-1.05)*3.0-torso_angle*.4)
	joints.hair_front.rotation = deg_to_rad(-torso_angle*.22+sin(p-.45)*1.4)
	joints.hair_back.rotation = deg_to_rad(-torso_angle*.4+sin(p-.8)*2.0)
	joints.head.rotation += deg_to_rad(-torso_angle*.35)
	joints.skirt.rotation = deg_to_rad(sin(p-.2)*1.1 if action == "walk" else -torso_angle*.2)
	joints.lamp_light.modulate.a *= .84+sin(p)*.08
	joints.blade_glint.visible = action == "attack" and frame in [3,4]

func _ik(first: Node2D,second: Node2D,target: Vector2,l1: float,l2: float,bend: float) -> void:
	var delta := target-first.global_position
	var distance := clampf(delta.length(),absf(l1-l2)+.01,l1+l2-.01)
	var offset := acos(clampf((l1*l1+distance*distance-l2*l2)/(2*l1*distance),-1,1))*bend
	first.global_rotation = delta.angle()-PI/2-offset
	var elbow := first.global_position+Vector2.DOWN.rotated(first.global_rotation)*l1
	second.global_rotation = (target-elbow).angle()-PI/2

func _leg(limb: String,contact: Vector2,tilt: float) -> void:
	var ankle := contact-Vector2(0,26).rotated(deg_to_rad(tilt))
	_ik(joints[limb+"_thigh"],joints[limb+"_shin"],ankle,92,82,-1.0 if facing == "left" else 1.0)
	joints[limb+"_foot"].global_rotation = deg_to_rad(tilt)

func _arm(limb: String,target: Vector2,bend: float) -> void:
	_ik(joints[limb+"_upper_arm"],joints[limb+"_forearm"],target,86,77,bend)
