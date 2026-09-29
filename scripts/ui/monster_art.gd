extends RefCounted
## Small, distinct silhouettes in the board's 44-unit tile coordinates.
const FONT = preload("res://assets/fonts/ui_font.tres")
const Enemies = preload("res://scripts/core/enemy_rules.gd")
const INK := Color("14212d")
const COLORS := {
	"slime": Color("87c998"), "skeleton": Color("e4d5ba"),
	"bat": Color("dc8797"), "sentinel": Color("a1b3c4"),
	"warlock": Color("ecaa70"), "knight": Color("b590d9"),
	"berserker": Color("e89368"), "warden": Color("8ca9bd"),
	"minotaur": Color("d5a66e"), "golem": Color("b7a1d7")
}

static func draw(canvas: CanvasItem, enemy: Dictionary, entity: Dictionary) -> void:
	var id := str(enemy.get("id", ""))
	var tint: Color = COLORS.get(id, Color("df797e"))
	match id:
		"slime":
			canvas.draw_circle(Vector2(0, 2), 13, tint)
			canvas.draw_rect(Rect2(-15, 4, 30, 10), tint)
			_eyes(canvas, 1)
		"skeleton":
			canvas.draw_circle(Vector2(0, -7), 11, tint)
			canvas.draw_rect(Rect2(-6, -3, 12, 10), tint)
			canvas.draw_line(Vector2(0, 5), Vector2(0, 17), tint, 3)
			canvas.draw_line(Vector2(-9, 10), Vector2(9, 10), tint, 3)
			_eyes(canvas, -7)
		"bat":
			_polygon(canvas, [Vector2(-19, -12), Vector2(-5, -5), Vector2(0, 5), Vector2(-8, 13), Vector2(-12, 3), Vector2(-19, 6)], tint)
			_polygon(canvas, [Vector2(19, -12), Vector2(5, -5), Vector2(0, 5), Vector2(8, 13), Vector2(12, 3), Vector2(19, 6)], tint)
			canvas.draw_circle(Vector2(0, 0), 7, tint.lightened(0.2))
			_eyes(canvas, -1)
		"sentinel":
			canvas.draw_rect(Rect2(-13, -13, 26, 27), tint)
			canvas.draw_line(Vector2(-13, 4), Vector2(13, 4), INK, 2)
			canvas.draw_line(Vector2(0, 4), Vector2(0, 14), INK, 2)
			_eyes(canvas, -5)
		"warlock":
			_polygon(canvas, [Vector2(0, -18), Vector2(-15, 15), Vector2(12, 15)], tint)
			canvas.draw_circle(Vector2(-1, -2), 6, INK)
			canvas.draw_line(Vector2(15, -9), Vector2(15, 17), tint, 2)
			canvas.draw_circle(Vector2(15, -11), 4, Color("f5dc89"))
		"knight":
			canvas.draw_rect(Rect2(-10, -16, 20, 21), tint)
			canvas.draw_rect(Rect2(-7, -7, 14, 3), INK)
			_polygon(canvas, [Vector2(-12, 4), Vector2(12, 4), Vector2(9, 16), Vector2(0, 19), Vector2(-9, 16)], tint.darkened(0.2))
			canvas.draw_line(Vector2(16, -9), Vector2(16, 16), tint.lightened(0.3), 2)
		"berserker":
			canvas.draw_circle(Vector2(-3, -9), 8, tint)
			canvas.draw_rect(Rect2(-12, 0, 20, 16), tint)
			canvas.draw_line(Vector2(14, -15), Vector2(14, 17), tint.lightened(0.3), 3)
			_polygon(canvas, [Vector2(11, -15), Vector2(20, -12), Vector2(20, -3), Vector2(11, -7)], tint)
			_eyes(canvas, -9)
		"warden":
			canvas.draw_rect(Rect2(-11, -16, 22, 18), tint)
			_polygon(canvas, [Vector2(-16, 0), Vector2(13, 0), Vector2(13, 12), Vector2(-2, 19), Vector2(-16, 12)], tint.darkened(0.15))
			for x in [-8, -1, 6]:
				canvas.draw_line(Vector2(x, 4), Vector2(x, 13), INK, 2)
			_eyes(canvas, -8)
		"minotaur":
			canvas.draw_circle(Vector2.ZERO, 13, tint)
			_polygon(canvas, [Vector2(-10, -5), Vector2(-20, -17), Vector2(-17, 0)], tint.lightened(0.25))
			_polygon(canvas, [Vector2(10, -5), Vector2(20, -17), Vector2(17, 0)], tint.lightened(0.25))
			canvas.draw_rect(Rect2(-8, 7, 16, 9), tint.darkened(0.2))
			_eyes(canvas, -3)
		"golem":
			canvas.draw_rect(Rect2(-9, -17, 18, 13), tint)
			canvas.draw_rect(Rect2(-12, -2, 24, 20), tint)
			canvas.draw_rect(Rect2(-20, -2, 6, 16), tint.darkened(0.2))
			canvas.draw_rect(Rect2(14, -2, 6, 16), tint.darkened(0.2))
			canvas.draw_circle(Vector2(0, 7), 4, Color("f5dc89"))
			_eyes(canvas, -11)
		_:
			canvas.draw_circle(Vector2.ZERO, 13, tint)
			_eyes(canvas, -3)
	var badge := Enemies.badge(enemy, entity)
	canvas.draw_rect(Rect2(6, 5, 15, 17), INK)
	canvas.draw_string(FONT, Vector2(7, 18), badge, HORIZONTAL_ALIGNMENT_LEFT, -1, 13, Color("f3deaa"))

static func _eyes(canvas: CanvasItem, y: float) -> void:
	canvas.draw_circle(Vector2(-4, y), 2, INK)
	canvas.draw_circle(Vector2(4, y), 2, INK)

static func _polygon(canvas: CanvasItem, points: Array, color: Color) -> void:
	canvas.draw_colored_polygon(PackedVector2Array(points), color)
