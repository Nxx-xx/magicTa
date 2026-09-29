extends SceneTree
const BASE := "res://assets/characters/hero/dialogue/"

func _initialize() -> void:
	var art := Image.load_from_file(BASE + "textures/hero_dialogue_neutral_v01.png")
	var transparent := 0
	var partial := 0
	var solid := 0
	for y in art.get_height():
		for x in art.get_width():
			var a := art.get_pixel(x,y).a
			if a == 0: transparent += 1
			elif a < 1: partial += 1
			else: solid += 1
	var data := {"width":art.get_width(),"height":art.get_height(),"transparent_pixels":transparent,"partial_alpha_pixels":partial,"opaque_pixels":solid,"has_alpha":art.detect_alpha()!=Image.ALPHA_NONE,"source":"built-in image_gen","crop":"waist/upper hips","expression":"neutral warm smile"}
	FileAccess.open(BASE + "reports/alpha_check.json",FileAccess.WRITE).store_string(JSON.stringify(data,"\t"))
	print(JSON.stringify(data))
	quit()
