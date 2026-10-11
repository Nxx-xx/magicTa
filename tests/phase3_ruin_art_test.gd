extends SceneTree
const Art = preload("res://scripts/ui/phase3_ruin_art.gd")
const OUT := "res://build/verification/phase3/07-completion/"
var checks := 0
var failures := 0

func _initialize() -> void:
	var isolated := ProjectSettings.globalize_path("user://").replace("\\","/")
	if not (isolated.contains("phase3/07-completion/") or isolated.contains("phase3/08-parallel/coordinator/")):
		quit(2)
		return
	var art := Art.new()
	check(not art.manifest.is_empty(),"accepted runtime manifest")
	for id in art.manifest.get("ruins",{}):
		var actions: Dictionary = art.manifest.ruins[id].actions
		for action in actions:
			for path in actions[action].frames:
				var image := Image.load_from_file(path)
				check(image != null and image.get_size() == Vector2i(256,256) and image.detect_alpha() != Image.ALPHA_NONE,"RGBA frame "+path)
		var entity := {"id":"f2:1,3","ruin_id":id,"status":"available","selected_option":""}
		var map := {"entities":{"1,3":entity}}
		check(art.observe(map,false,0).is_empty() and art.playing.is_empty(),"enter available no solve animation")
		check(art.texture(entity,0) != null,"idle texture available")
		for action in actions:
			if not action.begins_with("resolve_"): continue
			entity.status = "available"
			art.observe(map,false,0)
			entity.status = "resolved"
			entity.selected_option = action.trim_prefix("resolve_")
			check(art.observe(map,true,1).size() == 1 and art.playing.size() == 1,"committed transition starts result")
			var before := map.duplicate(true)
			check(art.texture(entity,1.25) != null,"selected result texture exists")
			check(art.observe(map,true,1.3).is_empty(),"repeated UI refresh does not replay")
			check(art.texture(entity,3) != null and art.playing.is_empty(),"result finishes in spent")
			check(map == before,"read only rendering")
			art.observe(map,false,5)
			check(art.playing.is_empty(),"reload or backtracking shows spent without solve replay")
		entity.status = "available"
		art.observe(map,false,0)
		entity.status = "resolved"
		art.observe(map,true,1)
		check(art.texture(entity,1.1,true) != null and art.playing.is_empty(),"reduced motion skips solve")
		check(art.cache_bytes <= Art.LIMIT,"bounded 6 MiB cache")
	check(art.texture({"ruin_id":"unknown","status":"available"},0) == null,"unknown or unavailable art falls back")
	print("RUIN_ART %d checks, %d failures" % [checks,failures])
	quit(1 if failures else 0)

func check(ok: bool, label: String) -> void:
	checks += 1
	if not ok:
		failures += 1
		push_error("FAIL "+label)
