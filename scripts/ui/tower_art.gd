extends Control
## Original vector-like placeholder art drawn by Godot; no external art dependencies.

func _ready() -> void:
	mouse_filter = Control.MOUSE_FILTER_IGNORE
	resized.connect(queue_redraw)

func _draw() -> void:
	var center := Vector2(size.x * 0.5, size.y * 0.53)
	var scale_factor := minf(size.y / 210.0, size.x / 320.0)
	draw_set_transform(center, 0.0, Vector2.ONE * scale_factor)
	draw_circle(Vector2(0, -22), 83, Color("172539"))
	draw_arc(Vector2(0, -22), 89, 0.15, TAU - 0.3, 80, Color("4a493b"), 1.2, true)
	for i in 16:
		var angle := float(i) * TAU / 16.0
		var point := Vector2(cos(angle), sin(angle)) * 100 + Vector2(0, -22)
		draw_circle(point, 1.3, Color("81978f"))
	var tower := PackedVector2Array([Vector2(-40, 70), Vector2(-40, 8),
		Vector2(-51, 8), Vector2(-51, -3), Vector2(-29, -3), Vector2(-29, -42),
		Vector2(-39, -42), Vector2(0, -89), Vector2(39, -42), Vector2(29, -42),
		Vector2(29, -3), Vector2(51, -3), Vector2(51, 8), Vector2(40, 8), Vector2(40, 70)])
	draw_colored_polygon(tower, Color("af945f"))
	draw_colored_polygon(PackedVector2Array([Vector2(0, -89), Vector2(39, -42),
		Vector2(29, -42), Vector2(29, -3), Vector2(51, -3), Vector2(51, 8),
		Vector2(40, 8), Vector2(40, 70), Vector2(0, 70)]), Color("74664b"))
	for y in [-34, -11, 21]:
		draw_rect(Rect2(-5, y, 10, 13), Color("0b1420"))
	draw_rect(Rect2(-9, 46, 18, 24), Color("0b1420"))
	draw_line(Vector2(-68, 72), Vector2(68, 72), Color("c9b176"), 2, true)
	draw_set_transform(Vector2.ZERO)

