extends Control
## Resolution-independent symbols shared by choice cards.
const ItemRegistry = preload("res://scripts/ui/item_icon_registry.gd")
const ItemArt = preload("res://scripts/ui/runtime_art.gd")
var kind := "sword"
var tint := Color("e4c783")

func _ready() -> void:
	mouse_filter = Control.MOUSE_FILTER_IGNORE

func _draw() -> void:
	var scale_factor := minf(size.x, size.y) / 48.0
	draw_set_transform(size * 0.5, 0, Vector2.ONE * scale_factor)
	draw_circle(Vector2(0,1), 23, Color("080f14"))
	draw_circle(Vector2.ZERO, 21, Color("1b3038"))
	draw_arc(Vector2.ZERO, 21, 0, TAU, 40, Color("786e53"), 1, true)
	draw_arc(Vector2.ZERO, 19, PI * 1.05, PI * 1.70, 16, Color("425255"), 1, true)
	# Only named ruin interactions use paintings; retain the shared base and functional symbols.
	if ItemRegistry.ACTION_PATHS.has(kind):
		var painting := ItemArt.texture(ItemRegistry.ACTION_PATHS[kind])
		if painting != null:
			draw_texture_rect(painting, Rect2(-24, -24, 48, 48), false)
			return
	match kind:
		"book", "log", "settings", "map":
			draw_rect(Rect2(-14,-15,28,30), tint, false, 2)
			if kind == "map":
				draw_polyline(PackedVector2Array([Vector2(-9,9),Vector2(-5,-5),Vector2(6,3),Vector2(10,-10)]), tint, 2, true)
			else:
				for y in [-8, 0, 8]:
					draw_line(Vector2(-9,y), Vector2(9,y), tint, 2, true)
					if kind == "settings": draw_circle(Vector2(4 if y == 0 else -4,y), 3, tint)
		"gold":
			for x in [-5, 5]:
				draw_circle(Vector2(x, 2 if x < 0 else -3), 11, tint.darkened(0.4))
				draw_arc(Vector2(x, 2 if x < 0 else -3), 11, 0, TAU, 32, tint, 2, true)
			draw_line(Vector2(5,-9), Vector2(5,3), tint, 2, true)
		"shield":
			draw_colored_polygon(PackedVector2Array([Vector2(-13,-13),Vector2(13,-13),Vector2(11,6),Vector2(0,16),Vector2(-11,6)]), tint)
			draw_line(Vector2(0,-9), Vector2(0,10), Color("243b48"), 3, true)
		"heal", "heart":
			draw_circle(Vector2(-6,-6), 8, tint)
			draw_circle(Vector2(6,-6), 8, tint)
			draw_colored_polygon(PackedVector2Array([Vector2(-14,-4),Vector2(14,-4),Vector2(0,15)]), tint)
			if kind == "heal":
				draw_line(Vector2(-6,0), Vector2(6,0), Color("243b48"), 3, true)
				draw_line(Vector2(0,-6), Vector2(0,6), Color("243b48"), 3, true)
		"lamp":
			draw_arc(Vector2(0,-9), 7, PI, TAU, 16, tint, 2, true)
			draw_rect(Rect2(-11,-8,22,23), tint, false, 2)
			draw_colored_polygon(PackedVector2Array([Vector2(0,-5),Vector2(5,6),Vector2(0,10),Vector2(-5,6)]), Color("82d7ba"))
			draw_line(Vector2(-14,16), Vector2(14,16), tint, 3, true)
		"relic":
			draw_colored_polygon(PackedVector2Array([Vector2(0,-17),Vector2(13,0),Vector2(0,17),Vector2(-13,0)]), tint)
			draw_circle(Vector2.ZERO, 5, Color("243b48"))
		_:
			draw_colored_polygon(PackedVector2Array([Vector2(0,-18),Vector2(5,-10),Vector2(3,6),Vector2(-3,6),Vector2(-5,-10)]), tint)
			draw_line(Vector2(-10,7), Vector2(10,7), tint, 3, true)
			draw_line(Vector2(0,7), Vector2(0,17), tint, 4, true)

static func for_reward(reward: Dictionary) -> String:
	var action_id := str(reward.get("id", ""))
	if ItemRegistry.ACTION_PATHS.has(action_id): return action_id
	var effects: Dictionary = reward.get("effects", {})
	if effects.has("attack"): return "sword"
	if effects.has("defense"): return "shield"
	if effects.has("heal"): return "heal"
	if effects.has("max_hp"): return "heart"
	if effects.has("gold"): return "gold"
	return "relic"
