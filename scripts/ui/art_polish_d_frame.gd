extends Control
## Resolution-independent engraved trim. Decorative only; never consumes input.
var kind := "panel"

func _ready() -> void:
	mouse_filter = Control.MOUSE_FILTER_IGNORE
	resized.connect(queue_redraw)

func _draw() -> void:
	var edge := Color("867756")
	var shadow := Color(0.01, 0.025, 0.035, 0.8)
	var w := size.x
	var h := size.y
	if w < 20 or h < 20: return
	if kind == "backdrop":
		# Architectural courses, kept at the edges behind the reading area.
		for y in range(120, int(h), 72):
			draw_line(Vector2(0,y), Vector2(w,y), Color(0.28,0.39,0.43,0.045))
			draw_line(Vector2(0,y+1), Vector2(w,y+1), Color(0,0,0,0.15))
		for x in [5.0,w-6.0]: draw_line(Vector2(x,8),Vector2(x,h-8),Color(0.52,0.46,0.33,0.20))
		return
	for x in [5.0, w-5.0]:
		var direction := 1.0 if x < w*0.5 else -1.0
		for y in [5.0,h-5.0]:
			var down := 1.0 if y < h*0.5 else -1.0
			draw_line(Vector2(x,y),Vector2(x+direction*14,y),edge,1)
			draw_line(Vector2(x,y),Vector2(x,y+down*10),edge,1)
			draw_circle(Vector2(x+direction*3,y+down*3),1.2,shadow)
	if kind == "menu":
		var center := Vector2(w*0.5,6)
		draw_colored_polygon(PackedVector2Array([center+Vector2(0,-3),center+Vector2(3,0),center+Vector2(0,3),center+Vector2(-3,0)]),Color("d4b67c"))
		draw_line(Vector2(26,6),center-Vector2(12,0),edge)
		draw_line(center+Vector2(12,0),Vector2(w-26,6),edge)

static func attach(parent: Control, style: String = "panel") -> Control:
	var trim := load("res://scripts/ui/art_polish_d_frame.gd").new() as Control
	trim.kind = style
	trim.name = "ArtPolishDTrim"
	parent.add_child(trim)
	trim.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	return trim
