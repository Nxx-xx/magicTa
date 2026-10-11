extends SceneTree
## Explicit source crop; preserve the existing painted identity, no generated shapes.
func _initialize() -> void:
	var source := Image.load_from_file("res://assets/characters/candlelight_merchant/source/merchant_v01.png")
	assert(source != null and source.detect_alpha())
	var crop := source.get_region(Rect2i(192,0,896,832))
	crop.resize(192,178,Image.INTERPOLATE_LANCZOS)
	assert(crop.save_png("res://assets/characters/candlelight_merchant/textures/conversation.png") == OK)
	print("NPC: source upper-body crop 896x832 -> 192x178, original preserved")
	quit()
