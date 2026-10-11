extends Control
## Three compact paths; node buttons only select, never spend souls.
signal node_selected(kind: String, level: int)
const KINDS := ["hp", "attack", "gold"]
const TITLES := ["生命", "锋芒", "财富"]
const COLORS := [Color("80ccb5"), Color("dca68c"), Color("e5c582")]
var levels: Dictionary = {}
var selected_kind := ""
var selected_level := 0
var font: Font
var nodes: Array[Button] = []

func _ready() -> void:
	custom_minimum_size = Vector2(210, 238)
	mouse_filter = Control.MOUSE_FILTER_PASS
	for column in 3:
		for rank in range(1, 4):
			var button := Button.new()
			button.name = "GrowthNode_%s_%d" % [KINDS[column], rank]
			button.tooltip_text = "%s火种 · %d级" % [TITLES[column], rank]
			button.custom_minimum_size = Vector2(56, 56)
			for state in ["normal", "hover", "pressed", "focus"]:
				var style := StyleBoxFlat.new()
				style.bg_color = Color(1, 1, 1, .06 if state == "hover" else 0)
				style.set_corner_radius_all(28)
				if state == "focus":
					style.set_border_width_all(2)
					style.border_color = Color("f7e2b0")
				button.add_theme_stylebox_override(state, style)
			add_child(button)
			nodes.append(button)
			button.pressed.connect(func():
				selected_kind = KINDS[column]
				selected_level = rank
				queue_redraw()
				node_selected.emit(KINDS[column], rank)
			)
	resized.connect(_layout_nodes)
	_layout_nodes()

func _center(column: int, rank: int) -> Vector2:
	return Vector2(size.x * (column + .5) / 3.0, 58 + (rank - 1) * ((size.y - 118) / 2.0))

func _layout_nodes() -> void:
	for column in 3:
		for rank in range(1, 4):
			nodes[column * 3 + rank - 1].position = _center(column, rank) - Vector2(28, 28)
	queue_redraw()

func reveal_details(detail: Control, scroll: ScrollContainer) -> void:
	# Nested containers need a layout pass before their full height is known.
	await get_tree().process_frame
	await get_tree().process_frame
	if is_instance_valid(detail) and is_instance_valid(scroll):
		scroll.ensure_control_visible(detail)

func _caption(at: Vector2, copy: String, tint: Color, pixels: int = 14) -> void:
	var width := font.get_string_size(copy, HORIZONTAL_ALIGNMENT_LEFT, -1, pixels).x
	draw_string(font, at - Vector2(width / 2, 0), copy, HORIZONTAL_ALIGNMENT_LEFT, -1, pixels, tint)

func _draw() -> void:
	if font == null: return
	for column in 3:
		var kind: String = KINDS[column]
		var current := int(levels.get(kind, 0))
		var accent: Color = COLORS[column]
		_caption(Vector2(_center(column, 1).x, 22), TITLES[column], accent, 17)
		for rank in range(1, 4):
			var point := _center(column, rank)
			var lit := rank <= current
			var next := rank == current + 1
			var selected := selected_kind == kind and selected_level == rank
			var ink := accent if lit or next else Color("606d79")
			if rank < 3:
				var start := point + Vector2(0, 29)
				var end := _center(column, rank + 1) - Vector2(0, 29)
				draw_line(start, end, accent.darkened(.3) if rank < current else Color("394653"), 2, true)
				draw_circle((start + end) / 2, 2, accent if rank < current else Color("67717a"))
			if selected: draw_circle(point, 32, Color(accent, .14))
			draw_circle(point, 26, Color("263e40") if lit else Color("17232d"))
			draw_arc(point, 26, 0, TAU, 64, ink, 2 if lit or next else 1, true)
			if selected: draw_arc(point, 31, 0, TAU, 64, accent, 2, true)
			_emblem(point, column, ink)
			var badge := point + Vector2(18, 18)
			draw_circle(badge, 9, Color("17232d"))
			_caption(badge + Vector2(0, 4), str(rank), ink, 12)
			if lit:
				draw_polyline(PackedVector2Array([point + Vector2(-23, 16), point + Vector2(-19, 20), point + Vector2(-12, 12)]), accent, 2, true)
		_caption(Vector2(_center(column, 1).x, size.y - 8), "%d / 3" % current, accent if current else Color("89949d"))

func _emblem(point: Vector2, column: int, tint: Color) -> void:
	draw_set_transform(point)
	match column:
		0:
			draw_circle(Vector2(-6, -4), 7, tint)
			draw_circle(Vector2(6, -4), 7, tint)
			draw_colored_polygon(PackedVector2Array([Vector2(-13, -2), Vector2(13, -2), Vector2(0, 14)]), tint)
		1:
			draw_colored_polygon(PackedVector2Array([Vector2(0, -17), Vector2(5, -9), Vector2(3, 6), Vector2(-3, 6), Vector2(-5, -9)]), tint)
			draw_line(Vector2(-9, 7), Vector2(9, 7), tint, 3, true)
			draw_line(Vector2(0, 7), Vector2(0, 16), tint, 4, true)
		2:
			draw_circle(Vector2.ZERO, 13, tint)
			draw_arc(Vector2.ZERO, 9, 0, TAU, 32, Color("17232d"), 1.5, true)
			draw_colored_polygon(PackedVector2Array([Vector2(0, -6), Vector2(4, 0), Vector2(0, 6), Vector2(-4, 0)]), Color("17232d"))
	draw_set_transform(Vector2.ZERO)
