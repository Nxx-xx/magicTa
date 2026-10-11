extends SceneTree
## Packaging only: keep generated originals intact, size runtime textures for phones.
func _initialize() -> void:
	var audit := {}
	for id in ["stone_hall", "moonlit_ruins", "boss_sanctum"]:
		var source := "res://assets/environment/battle_v02/source/%s_original.png" % id
		var image := Image.load_from_file(source)
		if image == null:
			quit(1)
			return
		var original := image.get_size()
		image.resize(576, 768, Image.INTERPOLATE_LANCZOS)
		image.convert(Image.FORMAT_RGB8)
		var target := "res://assets/environment/battle_v02/textures/%s.png" % id
		if image.save_png(target) != OK:
			quit(1)
			return
		audit[id] = {"source":source, "source_size":[original.x,original.y], "runtime":target, "size":[576,768], "rgb_bytes":576*768*3}
	FileAccess.open("res://build/verification/battle-polish/texture-audit.json",FileAccess.WRITE).store_string(JSON.stringify(audit,"\t"))
	print("BATTLE_POLISH packaged 3 runtime backgrounds; originals preserved")
	quit()
