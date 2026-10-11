extends SceneTree
const Art = preload("res://scripts/ui/phase3_ruin_art.gd")
func _initialize() -> void:
	var art := Art.new()
	var count := 0
	assert(art.manifest.get("storage") == "shared-base-overlay-v1")
	for id in art.manifest.ruins:
		var ruin: Dictionary = art.manifest.ruins[id]
		assert(not FileAccess.file_exists(ruin.base), "No raw PNG fallback present")
		for action in ruin.actions:
			var definition: Dictionary = ruin.actions[action]
			var contact := Image.create(256*definition.frames.size(),256,false,Image.FORMAT_RGBA8)
			for i in definition.frames.size():
				var entity := {"id":str(id),"ruin_id":id,"status":"available" if action == "idle" else "resolved"}
				if action.begins_with("resolve_"):
					art.playing[entity.id] = {"start":0.0,"option":action.trim_prefix("resolve_")}
				var texture := art.texture(entity,(float(i)+0.01)/float(definition.fps))
				assert(texture != null and texture.get_size() == Vector2(256,256))
				var image := texture.get_image()
				assert(image.get_used_rect().size != Vector2i.ZERO)
				contact.blit_rect(image,Rect2i(0,0,256,256),Vector2i(i*256,0))
				count += 1
			assert(contact.save_png("res://packed_"+str(id)+"_"+action+".png") == OK)
	assert(count == 75 and art.cache_bytes <= Art.LIMIT)
	print("PACKED_RUINS 75 frames loaded from exported remap/ctex only; cache <= 6 MiB; 15 rendered contact sheets")
	quit()
