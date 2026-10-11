extends Control
## Small, editable architectural accents; all content remains native controls.
var kind := "card"

func _ready() -> void:
	mouse_filter = Control.MOUSE_FILTER_IGNORE
	resized.connect(queue_redraw)

func _draw() -> void:
	var w := size.x
	var h := size.y
	if w < 16 or h < 16: return
	var gold := Color("a38a59")
	var teal := Color("28434b")
	match kind:
		"menu":
			# A light pool rising from the action shelf, without enclosing the art.
			for i in 32:
				var t := float(i) / 32
				draw_rect(Rect2(0, h * t, w, h / 32 + 1), Color(0.02, 0.045, 0.055, 0.78 + t * 0.2))
			draw_line(Vector2(24, 0), Vector2(w - 24, 0), gold.darkened(0.3))
			_diamond(Vector2(w / 2, 0), 4, Color("dfc28a"))
		"card", "compact_card", "tall_card":
			# Display alcove above the caption, a single shelf instead of nested frames.
			var shelf := 87 if kind == "tall_card" else 63 if kind == "card" else 47
			for i in 12:
				var t := float(i) / 12
				draw_rect(Rect2(1, 1 + 58 * t, w - 2, 6), Color(0.13, 0.24, 0.27, 0.18 * (1-t)))
			draw_line(Vector2(10, shelf), Vector2(w - 10, shelf), teal)
			draw_line(Vector2(10, shelf), Vector2(30, shelf), gold)
		"offer":
			draw_rect(Rect2(0, 10, 3, h - 20), gold.darkened(0.2))
			draw_line(Vector2(72, h - 1), Vector2(w - 12, h - 1), teal)
		"empty":
			var c := Vector2(w / 2, minf(64, h / 2))
			draw_arc(c, 34, 0, TAU, 48, teal, 1, true)
			draw_arc(c, 40, 0.3, PI-0.3, 24, gold.darkened(0.4), 1, true)
			_diamond(c, 14, teal)
			_diamond(c, 5, gold)
			draw_line(c + Vector2(-72,0), c + Vector2(-46,0), teal)
			draw_line(c + Vector2(46,0), c + Vector2(72,0), teal)
		"footer":
			# A faint recessed arch gives long pages an intentional quiet ending.
			if h > 180:
				var center := Vector2(w / 2, h - 72)
				var stone := Color(0.18, 0.32, 0.34, 0.16)
				draw_arc(center, 48, PI, TAU, 36, stone, 1, true)
				for x in [-48, 48]: draw_line(center+Vector2(x,0),center+Vector2(x,42),stone)
				_diamond(center+Vector2(0,10),7,stone)
			var y := h - 18
			draw_line(Vector2(12,y),Vector2(w/2-12,y),teal)
			draw_line(Vector2(w/2+12,y),Vector2(w-12,y),teal)
			_diamond(Vector2(w/2,y),3,gold.darkened(0.35))

func _diamond(center: Vector2, radius: float, color: Color) -> void:
	draw_colored_polygon(PackedVector2Array([center+Vector2(0,-radius),center+Vector2(radius,0),center+Vector2(0,radius),center+Vector2(-radius,0)]),color)

static func attach(parent: Control, style: String) -> Control:
	var surface := load("res://scripts/ui/ui_polish_surface.gd").new() as Control
	surface.kind = style
	surface.name = "PolishSurface"
	surface.mouse_filter = Control.MOUSE_FILTER_IGNORE
	parent.add_child(surface)
	surface.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	return surface
