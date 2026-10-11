extends Control
## Shared inventory art for catalog, choices, shop, rewards and details.
const Registry = preload("res://scripts/ui/item_icon_registry.gd")
var item: Dictionary = {}:
	set(value):
		item = value
		queue_redraw()
const Art = preload("res://scripts/ui/runtime_art.gd")

func _draw() -> void:
	var tint := Color("e0bf80") if item.get("kind", "") == "equipment" else Color("bf9fe3")
	draw_style_box(_background(), Rect2(Vector2.ZERO, size))
	var icon_path := Registry.path_for(item)
	if not icon_path.is_empty():
		var icon := Art.texture(icon_path)
		if icon != null:
			var edge := minf(size.x, size.y)
			# Art already contains transparent safety margins; preserve its aspect.
			draw_texture_rect(icon, Rect2((size - Vector2.ONE * edge) * 0.5, Vector2.ONE * edge), false)
			return
	# Only unregistered/missing art uses the generic symbol, scaled for small cells.
	draw_set_transform(size * 0.5, 0.0, Vector2.ONE * minf(size.x, size.y) / 48.0)
	draw_colored_polygon(PackedVector2Array([Vector2(0,-16),Vector2(14,0),Vector2(0,16),Vector2(-14,0)]), tint.darkened(0.4))
	draw_circle(Vector2.ZERO, 6, tint)
	draw_set_transform(Vector2.ZERO)

func _background() -> StyleBoxFlat:
	var box := StyleBoxFlat.new()
	box.bg_color = Color("17282f")
	box.border_color = Color("655c49")
	box.set_border_width_all(1)
	box.border_width_bottom = 2
	box.set_corner_radius_all(3)
	return box
