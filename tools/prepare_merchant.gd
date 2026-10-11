extends SceneTree
## Preserve generated alpha and downsample the complete square canvas for runtime.
func _initialize() -> void:
	var sprite := Image.load_from_file("res://assets/characters/candlelight_merchant/source/merchant_v01.png")
	if sprite == null or sprite.is_empty() or not sprite.detect_alpha():
		push_error("Merchant source must have a transparent background.")
		quit(1)
		return
	sprite.resize(256, 256, Image.INTERPOLATE_LANCZOS)
	var error := sprite.save_png("res://assets/characters/candlelight_merchant/textures/idle.png")
	print("Merchant sprite export: ", error)
	quit(0 if error == OK else 1)
