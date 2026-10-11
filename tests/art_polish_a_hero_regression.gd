extends SceneTree
const Catalog = preload("res://scripts/ui/phase3_animation_catalog.gd")
const SOURCE := "res://assets/characters/hero/phase3/source/refine_v06/"
const OUT := "res://build/verification/art-polish-a/regression/hero_regression/"
var checks := 0
var failures := 0
func check(ok: bool,label: String) -> void:
	checks += 1
	if not ok:
		failures += 1
		push_error("FAIL "+label)
func _initialize() -> void:
	if not ProjectSettings.globalize_path("user://").replace("\\","/").contains("phase3/08-parallel/art-polish-a/"):
		quit(2)
		return
	_run.call_deferred()
func digest(texture: Texture2D) -> String:
	var hash := HashingContext.new()
	hash.start(HashingContext.HASH_SHA256)
	var image := texture.get_image()
	image.convert(Image.FORMAT_RGBA8)
	hash.update(image.get_data())
	return hash.finish().hex_encode()
func _run() -> void:
	var result := Catalog.read_manifest()
	check(result.ok and result.get("complete",false),"complete published manifest")
	if not result.ok:
		print(result.error)
		quit(1)
		return
	var catalog := Catalog.new()
	check(catalog.configure(result.manifest).ok,"production configure")
	var peak := 0
	for id in result.manifest.actions:
		var action: Dictionary = result.manifest.actions[id]
		for i in action.frames.size():
			var frame := catalog.frame_at(id,float(i)/float(action.fps)+.00001)
			check(frame.ok and not frame.fallback and frame.frame == i,"published frame "+id+" #"+str(i))
			var measured := 0
			for entry in catalog._cache.values(): measured += entry.texture.get_image().get_data_size()
			check(measured == catalog.cache_bytes and measured <= catalog.max_cache_bytes,"actual image-data LRU accounting")
			peak = maxi(peak,measured)
	var action: Dictionary = result.manifest.actions.combat_attack
	var on := digest(catalog.frame_at("combat_attack",3.0/16.0+.00001).texture)
	catalog.effects_enabled = false
	check(catalog.cache_bytes == 0,"effect toggle releases composed cache")
	var body := catalog.frame_at("combat_attack",3.0/16.0+.00001)
	var expected := Catalog._read_texture(action.frames[3])
	check(digest(body.texture) == digest(expected) and on != digest(expected),"effects off preserves exact reviewed body; on contains optional FX")
	catalog.effects_enabled = true
	var reduced := catalog.frame_at("combat_attack",.4,true)
	check(reduced.frame == 0 and digest(reduced.texture) == digest(Catalog._read_texture(action.frames[0])),"reduced mode keeps body pose zero without FX")
	catalog.clear_cache()
	catalog.manifest.actions.combat_attack.effects_frames[3] = "res://assets/characters/hero/phase3/textures/missing_effect.png"
	check(digest(catalog.frame_at("combat_attack",3.0/16.0+.00001).texture) == digest(expected),"missing optional effect retains body")
	catalog.manifest.actions.combat_attack.frames[3] = "res://assets/characters/hero/phase3/textures/missing_body.png"
	catalog.clear_cache()
	check(catalog.frame_at("combat_attack",3.0/16.0+.00001).fallback,"missing body uses visible static fallback")
	catalog.configure(result.manifest)
	catalog.max_cache_bytes = 2*384*384*4
	for id in result.manifest.actions:
		var data: Dictionary = result.manifest.actions[id]
		for i in data.frames.size():
			catalog.frame_at(id,float(i)/float(data.fps)+.00001)
			check(catalog.cache_bytes <= catalog.max_cache_bytes,"pressure evicts instead of exceeding budget")
	# Read and exercise editable source hierarchy, not just baked metadata.
	for facing in Catalog.DIRECTIONS:
		var rig := load(SOURCE+"hero_"+facing+"_editable.tscn").instantiate() as Node2D
		root.add_child(rig)
		var player := rig.get_node("AnimationPlayer") as AnimationPlayer
		for id in ["map_idle_"+facing,"map_walk_"+facing,"map_interact_"+facing]:
			player.play(id)
			for i in result.manifest.actions[id].frames.size():
				player.seek(float(i)/float(result.manifest.actions[id].fps),true)
				player.advance(0)
				for limb in ["right","left"]:
					var thigh: Node2D = rig.find_child(limb+"_thigh",true,false)
					var shin: Node2D = rig.find_child(limb+"_shin",true,false)
					var foot: Node2D = rig.find_child(limb+"_foot",true,false)
					var contact: Node2D = rig.find_child(limb+"_contact",true,false)
					check(shin.get_parent()==thigh and foot.get_parent()==shin and contact.get_parent()==foot,"independent knee/ankle/sole source hierarchy")
					if id.begins_with("map_walk_") and i in [0,3]: check(absf(contact.global_position.y/6-116)<1,"native planted foot contact")
			player.stop()
		rig.queue_free()
		await process_frame
	FileAccess.open(OUT+"hero-specific-results.json",FileAccess.WRITE).store_string(JSON.stringify({"checks":checks,"failures":failures,"peak_hero_cache_actual_image_bytes":peak,"scope":"Published hero frame protocol, exact body/FX-off/reduced/missing frame fallback, actual Image.get_data_size LRU pressure, native independent wrists/knees/ankles/sole hierarchy."},"\t"))
	print("Hero v06 specific: %d checks; %d failures; actual cache peak %d" % [checks,failures,peak])
	quit(1 if failures else 0)
