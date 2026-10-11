extends SceneTree
## Editable native 3D character, orthographic sprites and a dialogue portrait.
const SOURCE := "res://assets/characters/mysterious_knight/source/"
const TEX := "res://assets/characters/mysterious_knight/textures/"
var rig: Node3D
var body: Node3D
var head: Node3D
var cape: Node3D
var materials := {}

func _initialize() -> void: _run.call_deferred()

func material(id: String, color: String, metal: float = 0.0, rough: float = 0.65) -> StandardMaterial3D:
	var m := StandardMaterial3D.new()
	m.resource_name = id
	m.albedo_color = Color(color)
	m.metallic = metal
	m.roughness = rough
	if id in ["WeatheredSteel","ShadowSteel","AntiqueBrass"]:
		var noise := FastNoiseLite.new()
		noise.frequency = .075
		noise.fractal_octaves = 3
		var texture := NoiseTexture2D.new()
		texture.width = 128
		texture.height = 128
		texture.noise = noise
		var ramp := Gradient.new()
		ramp.colors = PackedColorArray([Color(.48,.53,.55),Color(.96,.97,.94)])
		texture.color_ramp = ramp
		m.albedo_texture = texture
		m.uv1_triplanar = true
		m.uv1_scale = Vector3.ONE*2
	materials[id] = m
	return m

func part(parent: Node3D, name_text: String, mesh: Mesh, pos: Vector3, scale_value: Vector3, mat: String) -> MeshInstance3D:
	var item := MeshInstance3D.new()
	item.name = name_text
	item.mesh = mesh
	item.material_override = materials[mat]
	item.position = pos
	item.scale = scale_value
	parent.add_child(item)
	item.owner = rig
	return item

func sphere(parent: Node3D, name_text: String, pos: Vector3, size_value: Vector3, mat: String) -> MeshInstance3D:
	var mesh := SphereMesh.new()
	mesh.radius = .5
	mesh.height = 1.0
	mesh.radial_segments = 24
	mesh.rings = 12
	return part(parent,name_text,mesh,pos,size_value,mat)

func box(parent: Node3D, name_text: String, pos: Vector3, size_value: Vector3, mat: String) -> MeshInstance3D:
	return part(parent,name_text,BoxMesh.new(),pos,size_value,mat)

func cone(parent: Node3D, name_text: String, pos: Vector3, size_value: Vector3, mat: String, top: float = 0.0) -> MeshInstance3D:
	var mesh := CylinderMesh.new()
	mesh.top_radius = top
	mesh.bottom_radius = .5
	mesh.height = 1.0
	mesh.radial_segments = 16
	return part(parent,name_text,mesh,pos,size_value,mat)

func rod(parent: Node3D, name_text: String, a: Vector3, b: Vector3, radius: float, mat: String) -> MeshInstance3D:
	var mesh := CylinderMesh.new()
	mesh.top_radius = radius
	mesh.bottom_radius = radius
	mesh.height = a.distance_to(b)
	mesh.radial_segments = 12
	var item := part(parent,name_text,mesh,(a+b)*.5,Vector3.ONE,mat)
	item.quaternion = Quaternion(Vector3.UP,(b-a).normalized())
	return item

func shape(parent: Node3D, name_text: String, points: PackedVector3Array, triangles: Array, mat: String) -> MeshInstance3D:
	var tool := SurfaceTool.new()
	tool.begin(Mesh.PRIMITIVE_TRIANGLES)
	for triangle in triangles:
		for index in triangle: tool.add_vertex(points[index])
	tool.generate_normals()
	return part(parent,name_text,tool.commit(),Vector3.ZERO,Vector3.ONE,mat)

func group(parent: Node3D, name_text: String, pos: Vector3 = Vector3.ZERO) -> Node3D:
	var item := Node3D.new()
	item.name = name_text
	item.position = pos
	parent.add_child(item)
	item.owner = rig
	return item

func plate(parent: Node3D, name_text: String, pos: Vector3, dimensions: Vector3, mat: String) -> MeshInstance3D:
	# Broad planes with narrow chamfers read as forged plates, not inflated spheres.
	var vertices := PackedVector3Array()
	var faces: Array = []
	var outline := [Vector2(-.32,-.5),Vector2(.32,-.5),Vector2(.5,-.3),Vector2(.5,.3),Vector2(.32,.5),Vector2(-.32,.5),Vector2(-.5,.3),Vector2(-.5,-.3)]
	var bands := [Vector2(-.5,.78),Vector2(-.34,1),Vector2(.30,1),Vector2(.5,.72)]
	for band in bands:
		for p in outline: vertices.append(Vector3(p.x*band.y,band.x,p.y*band.y))
	for y in 3:
		for x in 8:
			var a := y*8+x
			var b := y*8+(x+1)%8
			faces.append([a,b,a+8])
			faces.append([b,b+8,a+8])
	for i in range(1,7):
		faces.append([0,i+1,i])
		faces.append([24,24+i,25+i])
	var item := shape(parent,name_text,vertices,faces,mat)
	item.position = pos
	item.scale = dimensions
	return item

func _build() -> void:
	rig = Node3D.new()
	rig.name = "MysteriousOldKnight"
	material("WeatheredSteel","647b88",.58,.57)
	material("PolishedEdges","b5c8cb",.7,.43)
	material("ShadowSteel","263d4c",.7,.5)
	material("AntiqueBrass","b59a5d",.64,.52)
	material("AgedLeather","42332e")
	material("MidnightCloak","243a46")
	material("CloakFold","172b35")
	material("CloakLining","58646a")
	material("LinenTabard","9c9a84")
	material("Skin","c49e7c",0,.88)
	material("FaceShadow","8c6753",0,.86)
	material("SilverHair","d3d5c7",0,.9)
	material("HairShade","8e9b96",0,.9)
	material("Eye","192b32",0,.55)
	material("EmberGem","ddaa58",.45,.25)
	for side in [-1,1]:
		var sign_name := "Left" if side < 0 else "Right"
		var x: float = .23*side
		sphere(rig,sign_name+"Boot",Vector3(x,.12,.085),Vector3(.29,.25,.49),"AgedLeather")
		sphere(rig,sign_name+"Sabatons",Vector3(x,.20,.16),Vector3(.3,.16,.34),"WeatheredSteel")
		for i in 3:
			box(rig,sign_name+"ToeRidge%d" % i,Vector3(x,.26,.13+i*.08),Vector3(.25,.025,.018),"PolishedEdges")
		cone(rig,sign_name+"Greave",Vector3(x,.49,0),Vector3(.30,.55,.30),"WeatheredSteel",.39)
		rod(rig,sign_name+"ShinRidge",Vector3(x,.29,.16),Vector3(x,.71,.14),.018,"PolishedEdges")
		plate(rig,sign_name+"Knee",Vector3(x,.78,.08),Vector3(.31,.23,.29),"PolishedEdges")
		sphere(rig,sign_name+"Thigh",Vector3(x,.99,-.03),Vector3(.36,.43,.36),"ShadowSteel")
		for i in 3:
			var armor := plate(rig,sign_name+"Tasset%d" % i,Vector3(side*(.25+i*.015),1.17-i*.10,.10),Vector3(.35,.17,.36),"WeatheredSteel")
			armor.rotation.z = side*-.13
	body = group(rig,"Torso")
	# Layered convex plates, a cloth tabard, and a belt with real relief details.
	sphere(body,"Gambeson",Vector3(0,1.45,0),Vector3(.86,.74,.48),"ShadowSteel")
	shape(body,"ForgedBreastplate",PackedVector3Array([Vector3(-.30,1.77,.21),Vector3(.30,1.77,.21),Vector3(.405,1.55,.22),Vector3(.29,1.28,.23),Vector3(-.29,1.28,.23),Vector3(-.405,1.55,.22),Vector3(0,1.57,.34)]),[[0,1,6],[1,2,6],[2,3,6],[3,4,6],[4,5,6],[5,0,6]],"WeatheredSteel")
	rod(body,"CentralArmorRidge",Vector3(0,1.30,.27),Vector3(0,1.57,.35),.013,"PolishedEdges")
	rod(body,"UpperArmorRidge",Vector3(0,1.57,.35),Vector3(0,1.77,.23),.012,"PolishedEdges")
	for side in [-1,1]:
		rod(body,"GoldChestInlay",Vector3(side*.06,1.40,.32),Vector3(side*.27,1.66,.29),.012,"AntiqueBrass")
		rod(body,"GorgetRim",Vector3(0,1.775,.23),Vector3(side*.30,1.775,.23),.017,"AntiqueBrass")
		for i in 3:
			sphere(body,"ArmorRivet",Vector3(side*(.16+i*.085),1.7-i*.045,.24),Vector3.ONE*.031,"AntiqueBrass")
	box(body,"LeatherBelt",Vector3(0,1.22,.02),Vector3(.78,.105,.49),"AgedLeather")
	box(body,"Buckle",Vector3(0,1.22,.278),Vector3(.16,.12,.035),"AntiqueBrass")
	box(body,"BuckleInset",Vector3(0,1.22,.299),Vector3(.09,.064,.011),"AgedLeather")
	shape(body,"SplitTabard",PackedVector3Array([Vector3(-.2,1.17,.19),Vector3(.2,1.17,.19),Vector3(.22,.66,.23),Vector3(.035,.71,.25),Vector3(0,.86,.26),Vector3(-.04,.71,.25),Vector3(-.22,.65,.23)]),[[0,1,4],[1,2,3],[1,3,4],[0,4,5],[0,5,6]],"LinenTabard")
	for side in [-1,1]:
		var arm := group(body,"ArmLeft" if side < 0 else "ArmRight")
		sphere(arm,"UpperArm",Vector3(side*.46,1.47,0),Vector3(.28,.52,.3),"ShadowSteel")
		for i in 3:
			var shoulder := plate(arm,"Pauldron%d" % i,Vector3(side*(.43+i*.035),1.75-i*.07,.005),Vector3(.37-i*.025,.135,.43-i*.022),"WeatheredSteel")
			shoulder.rotation.z = side*.18
		rod(arm,"GoldShoulderRim",Vector3(side*.29,1.79,.18),Vector3(side*.59,1.65,.17),.018,"AntiqueBrass")
		sphere(arm,"Elbow",Vector3(side*.49,1.21,.045),Vector3(.27,.24,.27),"PolishedEdges")
		var gauntlet := plate(arm,"Vambrace",Vector3(side*.33,1.27,.27),Vector3(.21,.36,.23),"WeatheredSteel")
		gauntlet.rotation.z = side*-.9
		sphere(arm,"Glove",Vector3(side*.125,1.30,.41),Vector3(.24,.145,.20),"AgedLeather")
		for i in 4:
			box(arm,"FingerPlate%d" % i,Vector3(side*.13,1.348,.35+i*.036),Vector3(.17,.048,.026),"PolishedEdges")
	# Cloak is a formed, pleated mesh rather than a flat billboard.
	cape = group(body,"Cloak")
	var columns := 14
	var rows := 10
	var points := PackedVector3Array()
	var faces: Array = []
	for y in rows+1:
		var t := float(y)/rows
		for x in columns+1:
			var u := float(x)/columns
			points.append(Vector3((u-.5)*lerpf(.65,1.20,t),lerpf(1.78,.24,t)+.045*sin(u*PI*5)*t,-.25-.17*t-.07*sin(u*PI*8)*t))
	for y in rows:
		for x in columns:
			var i := y*(columns+1)+x
			faces.append([i,i+columns+1,i+1])
			faces.append([i+1,i+columns+1,i+columns+2])
	materials.MidnightCloak.cull_mode = BaseMaterial3D.CULL_DISABLED
	shape(cape,"PleatedWool",points,faces,"MidnightCloak")
	for side in [-1,1]:
		rod(cape,"CloakEmbroideredHem",Vector3(side*.32,1.77,-.23),Vector3(side*.58,.26,-.42),.021,"AntiqueBrass")
		sphere(body,"CloakClasp",Vector3(side*.29,1.74,.21),Vector3(.13,.13,.045),"AntiqueBrass")
	for i in 10:
		var x: float = -.25+i*.055
		sphere(body,"ClaspChain",Vector3(x,1.70-.06*sin(float(i)/9*PI),.28),Vector3(.048,.035,.025),"AntiqueBrass")
	cone(body,"Gorget",Vector3(0,1.82,0),Vector3(.40,.18,.39),"ShadowSteel",.38)
	head = group(body,"Head",Vector3(0,2.02,.03))
	sphere(head,"Face",Vector3(0,.025,.05),Vector3(.37,.46,.34),"Skin")
	sphere(head,"HairCap",Vector3(0,.10,-.045),Vector3(.415,.40,.34),"HairShade")
	for side in [-1,1]:
		sphere(head,"Ear",Vector3(side*.18,.014,.035),Vector3(.065,.105,.06),"Skin")
		sphere(head,"Cheek",Vector3(side*.11,-.04,.16),Vector3(.10,.09,.035),"FaceShadow")
		sphere(head,"EyeSocket",Vector3(side*.081,.065,.188),Vector3(.107,.048,.035),"FaceShadow")
		sphere(head,"Eye",Vector3(side*.08,.064,.210),Vector3(.042,.024,.018),"Eye")
		var brow := sphere(head,"SilverBrow",Vector3(side*.077,.10,.211),Vector3(.145,.033,.032),"SilverHair")
		brow.rotation.z = side*.15
		for i in 4:
			var lock := sphere(head,"SweptHair",Vector3(side*(.13+i*.012),.15-i*.055,-.038),Vector3(.12,.18,.23),"SilverHair")
			lock.rotation.z = side*-.3
	sphere(head,"NoseBridge",Vector3(0,.018,.217),Vector3(.07,.13,.065),"Skin")
	sphere(head,"NoseTip",Vector3(0,-.027,.252),Vector3(.09,.06,.08),"Skin")
	sphere(head,"BeardFoundation",Vector3(0,-.15,.10),Vector3(.32,.31,.25),"HairShade")
	for i in 13:
		var u := float(i)/12
		var x: float = (u-.5)*.28
		var beard := cone(head,"BeardStrand%02d" % i,Vector3(x,-.20+absf(x)*.27,.185-absf(x)*.19),Vector3(.068,.24-absf(x)*.45,.076),"SilverHair",.0)
		beard.rotation.z = PI+(u-.5)*.35
	for side in [-1,1]:
		var moustache := sphere(head,"Moustache",Vector3(side*.053,-.069,.227),Vector3(.14,.065,.059),"SilverHair")
		moustache.rotation.z = side*-.25
	# Sword tip rests on the ground; both hands remain on the pommel in all idle poses.
	var sword := group(rig,"OathkeeperSword",Vector3(.02,0,.46))
	shape(sword,"DiamondBlade",PackedVector3Array([Vector3(0,.055,0),Vector3(-.07,.95,0),Vector3(0,1.03,.026),Vector3(.07,.95,0),Vector3(0,.055,.015),Vector3(0,.95,-.026)]),[[0,1,2],[0,2,3],[0,3,5],[0,5,1]],"PolishedEdges")
	rod(sword,"Fuller",Vector3(0,.21,.02),Vector3(0,.95,.03),.007,"ShadowSteel")
	rod(sword,"Crossguard",Vector3(-.20,1.02,0),Vector3(.20,1.02,0),.026,"AntiqueBrass")
	rod(sword,"LeatherGrip",Vector3(0,1.03,0),Vector3(0,1.28,0),.031,"AgedLeather")
	for i in 5:
		rod(sword,"GripBinding",Vector3(-.025,1.06+i*.041,.015),Vector3(.025,1.08+i*.041,.015),.008,"AntiqueBrass")
	sphere(sword,"Pommel",Vector3(0,1.33,0),Vector3(.115,.13,.10),"AntiqueBrass")
	sphere(sword,"AmberStone",Vector3(0,1.34,.053),Vector3(.05,.07,.02),"EmberGem")
	# A travel-worn heater shield hangs at the left hip.
	var shield := group(rig,"HeaterShield",Vector3(-.57,.85,-.02))
	shield.rotation.z = -.12
	shape(shield,"BrassRim",PackedVector3Array([Vector3(-.22,.31,0),Vector3(.22,.31,0),Vector3(.22,-.08,.035),Vector3(0,-.4,.06),Vector3(-.22,-.08,.035)]),[[0,1,2],[0,2,3],[0,3,4]],"AntiqueBrass")
	shape(shield,"EnamelFace",PackedVector3Array([Vector3(-.19,.28,.012),Vector3(.19,.28,.012),Vector3(.18,-.07,.05),Vector3(0,-.35,.075),Vector3(-.18,-.07,.05)]),[[0,1,2],[0,2,3],[0,3,4]],"MidnightCloak")
	rod(shield,"HeraldicStem",Vector3(0,-.19,.076),Vector3(0,.22,.04),.014,"AntiqueBrass")
	for side in [-1,1]:
		rod(shield,"HeraldicBranch",Vector3(0,.05,.06),Vector3(side*.12,.17,.04),.013,"AntiqueBrass")
		rod(shield,"HeraldicBranch",Vector3(0,-.06,.065),Vector3(side*.13,.07,.052),.013,"AntiqueBrass")
	var player := AnimationPlayer.new()
	player.name = "AnimationPlayer"
	rig.add_child(player)
	player.owner = rig
	var library := AnimationLibrary.new()
	var idle := Animation.new()
	idle.length = 2.0
	idle.loop_mode = Animation.LOOP_LINEAR
	for property in ["Torso:position:y","Torso/Head:rotation:y","Torso/Cloak:rotation:x"]:
		var track := idle.add_track(Animation.TYPE_VALUE)
		idle.track_set_path(track,NodePath(property))
		for i in 9:
			var t := float(i)/8
			var amount: float = (.008 if property.contains("position") else .017)*sin(t*TAU)
			idle.track_insert_key(track,t*2.0,amount)
	library.add_animation("idle",idle)
	player.add_animation_library("",library)
	player.autoplay = "idle"

func _run() -> void:
	DirAccess.make_dir_recursive_absolute(SOURCE)
	DirAccess.make_dir_recursive_absolute(TEX)
	_build()
	var packed := PackedScene.new()
	assert(packed.pack(rig) == OK)
	assert(ResourceSaver.save(packed,SOURCE+"mysterious_old_knight.tscn") == OK)
	var viewport := SubViewport.new()
	viewport.size = Vector2i(512,512)
	viewport.transparent_bg = true
	viewport.own_world_3d = true
	viewport.msaa_3d = Viewport.MSAA_4X
	viewport.render_target_update_mode = SubViewport.UPDATE_ALWAYS
	root.add_child(viewport)
	viewport.add_child(rig)
	rig.get_node("AnimationPlayer").stop()
	var world := WorldEnvironment.new()
	world.environment = Environment.new()
	world.environment.background_mode = Environment.BG_COLOR
	world.environment.background_color = Color(0,0,0,0)
	world.environment.ambient_light_source = Environment.AMBIENT_SOURCE_COLOR
	world.environment.ambient_light_color = Color("a6bdcd")
	world.environment.ambient_light_energy = .55
	viewport.add_child(world)
	for spec in [[Vector3(-30,-35,0),Color("ffe7c2"),1.6],[Vector3(-10,130,0),Color("a0c4da"),1.1]]:
		var light := DirectionalLight3D.new()
		light.rotation_degrees = spec[0]
		light.light_color = spec[1]
		light.light_energy = spec[2]
		viewport.add_child(light)
	var camera := Camera3D.new()
	camera.projection = Camera3D.PROJECTION_ORTHOGONAL
	camera.size = 3.0
	viewport.add_child(camera)
	camera.position = Vector3(3.0,4.6,7.0)
	camera.look_at(Vector3(0,1.15,0))
	for i in 8: await process_frame
	var anchor := camera.unproject_position(Vector3.ZERO)/2.0
	var manifest := {"source":"source/mysterious_old_knight.tscn","map_size":[256,256],"anchor":[anchor.x,anchor.y],"frames":[],"fps":4}
	for i in 8:
		var phase := float(i)/8*TAU
		body.position.y = .008*sin(phase)
		head.rotation.y = .017*sin(phase)
		cape.rotation.x = .017*sin(phase)
		await process_frame
		await RenderingServer.frame_post_draw
		var frame := viewport.get_texture().get_image()
		frame.resize(256,256,Image.INTERPOLATE_LANCZOS)
		var path := "idle_%02d.png" % i
		assert(frame.save_png(TEX+path) == OK)
		manifest.frames.append("textures/"+path)
	viewport.size = Vector2i(640,768)
	camera.size = 2.85
	camera.position = Vector3(2.7,2.7,7.0)
	camera.look_at(Vector3(0,1.16,0))
	await process_frame
	await RenderingServer.frame_post_draw
	assert(viewport.get_texture().get_image().save_png(TEX+"portrait.png") == OK)
	var file := FileAccess.open("res://assets/characters/mysterious_knight/manifest.json",FileAccess.WRITE)
	file.store_string(JSON.stringify(manifest,"\t"))
	file.close()
	print("KNIGHT MODEL: native editable scene, 8 idle frames and portrait saved")
	quit()
