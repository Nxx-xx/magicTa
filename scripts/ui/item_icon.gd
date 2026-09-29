extends Control
## Small code-drawn inventory symbols, independent of imported textures.
var item: Dictionary = {}

func _draw() -> void:
	var tint := Color("e0bf80") if item.get("kind", "") == "equipment" else Color("bf9fe3")
	var id := str(item.get("id", ""))
	draw_style_box(_background(), Rect2(Vector2.ZERO, size))
	draw_set_transform(size * 0.5)
	if item.get("kind", "") == "relic":
		draw_colored_polygon(PackedVector2Array([Vector2(0,-17),Vector2(13,0),Vector2(0,17),Vector2(-13,0)]), tint.darkened(0.4))
		draw_circle(Vector2.ZERO, 7, tint)
		draw_line(Vector2(-4,0), Vector2(4,0), Color("172434"), 2)
	elif "armor" in id or "plate" in id or "mail" in id or "shield" in id:
		draw_colored_polygon(PackedVector2Array([Vector2(-14,-14),Vector2(14,-14),Vector2(11,8),Vector2(0,17),Vector2(-11,8)]), tint)
		draw_line(Vector2(0,-11), Vector2(0,12), tint.darkened(0.5), 3)
	elif "ring" in id or "pendant" in id or "crown" in id or "gloves" in id:
		draw_arc(Vector2(0,3), 11, 0, TAU, 24, tint, 3, true)
		draw_colored_polygon(PackedVector2Array([Vector2(0,-17),Vector2(6,-10),Vector2(0,-4),Vector2(-6,-10)]), Color("83d5bf"))
	else:
		draw_colored_polygon(PackedVector2Array([Vector2(0,-19),Vector2(5,-11),Vector2(3,6),Vector2(-3,6),Vector2(-5,-11)]), tint.lightened(0.2))
		draw_line(Vector2(-10,7), Vector2(10,7), tint, 3)
		draw_line(Vector2(0,7), Vector2(0,18), tint.darkened(0.25), 4)
	draw_set_transform(Vector2.ZERO)

func _background() -> StyleBoxFlat:
	var box := StyleBoxFlat.new()
	box.bg_color = Color("24384b")
	box.set_corner_radius_all(6)
	return box
