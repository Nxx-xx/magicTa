extends Control
## Drawn placeholders keep the map legible without an external sprite pack.
signal cell_selected(cell: Vector2i)

const FONT = preload("res://assets/fonts/ui_font.tres")
const Keys = preload("res://scripts/core/map_keys.gd")
const Monsters = preload("res://scripts/ui/monster_art.gd")
var map: Dictionary = {}
var enemies: Dictionary = {}
var hero := Vector2i(1, 9)
var selected := Vector2i(-1, -1)
var alive := true

func _ready() -> void:
	mouse_filter = Control.MOUSE_FILTER_STOP
	mouse_default_cursor_shape = Control.CURSOR_POINTING_HAND
	resized.connect(queue_redraw)

func setup(floor_state: Dictionary, player_position: Vector2i, selection: Vector2i, is_alive: bool, enemy_definitions: Dictionary = {}) -> void:
	map = floor_state
	enemies = enemy_definitions
	hero = player_position
	selected = selection
	alive = is_alive
	queue_redraw()

func _cell_size() -> float:
	return minf(size.x, size.y) / 11.0

func _origin() -> Vector2:
	return (size - Vector2.ONE * _cell_size() * 11.0) * 0.5

func _gui_input(event: InputEvent) -> void:
	if event is InputEventMouseButton and event.button_index == MOUSE_BUTTON_LEFT and event.pressed:
		var local: Vector2 = event.position - _origin()
		var tile := _cell_size()
		if tile > 0 and local.x >= 0 and local.y >= 0 and local.x < tile * 11 and local.y < tile * 11:
			cell_selected.emit(Vector2i(int(local.x / tile), int(local.y / tile)))
			accept_event()

func _draw() -> void:
	if map.is_empty():
		return
	var tile := _cell_size()
	var origin := _origin()
	for y in 11:
		for x in 11:
			var cell := Vector2i(x, y)
			var rect := Rect2(origin + Vector2(cell) * tile + Vector2.ONE, Vector2.ONE * (tile - 2))
			var wall := str(map.rows[y]).substr(x, 1) == "#"
			draw_rect(rect, Color("253346") if wall else Color("14212d"))
			if wall:
				draw_line(rect.position + Vector2(3, tile * 0.35), rect.position + Vector2(tile - 5, tile * 0.35), Color("3b4b60"), 1)
				draw_line(rect.position + Vector2(tile * 0.5, 2), rect.position + Vector2(tile * 0.5, tile * 0.35), Color("3b4b60"), 1)
			else:
				draw_rect(rect, Color("223443"), false, 1)
				if absi(cell.x - hero.x) + absi(cell.y - hero.y) == 1:
					draw_rect(rect.grow(-1), Color("406965"), false, 1)
			var entity: Dictionary = map.entities.get("%d,%d" % [x, y], {})
			if not entity.is_empty():
				_draw_entity(entity, rect.get_center(), tile)
			if cell == selected:
				draw_rect(rect.grow(-1), Color("f0d596"), false, 2)
	_draw_hero(origin + (Vector2(hero) + Vector2.ONE * 0.5) * tile, tile)

func _draw_entity(entity: Dictionary, center: Vector2, tile: float) -> void:
	var s := tile / 44.0
	draw_set_transform(center, 0, Vector2.ONE * s)
	match str(entity.type):
		"enemy":
			Monsters.draw(self, enemies.get(str(entity.enemy_id), {"id": entity.enemy_id}), entity)
		"door":
			var key_kind := Keys.kind(entity)
			var tint: Color = Keys.COLORS.get(key_kind, Keys.COLORS.copper)
			draw_rect(Rect2(-13, -17, 26, 34), tint)
			draw_rect(Rect2(-10, -14, 20, 28), tint.darkened(0.55))
			draw_line(Vector2(0, -14), Vector2(0, 14), tint, 2)
			draw_circle(Vector2(0, 0), 4, tint.lightened(0.15))
			_key_badge(key_kind)
		"key":
			var key_kind := Keys.kind(entity)
			var tint: Color = Keys.COLORS.get(key_kind, Keys.COLORS.copper)
			draw_arc(Vector2(-5, -6), 6, 0, TAU, 20, tint, 3, true)
			draw_line(Vector2(-1, -1), Vector2(10, 12), tint, 3, true)
			draw_line(Vector2(5, 6), Vector2(10, 2), tint, 3, true)
			_key_badge(key_kind)
		"chest", "choice":
			var color := Color("e4c883") if not entity.get("objective", false) else Color("cfaae8")
			draw_rect(Rect2(-14, -10, 28, 24), color)
			draw_line(Vector2(-14, -1), Vector2(14, -1), Color("604f34"), 2)
			draw_rect(Rect2(-3, -4, 6, 9), Color("604f34"))
			if entity.type == "choice":
				_text("选", Color("493e2e"))
		"event":
			draw_rect(Rect2(-13, -16, 26, 32), Color("ba9cd9"))
			draw_line(Vector2(-8, -8), Vector2(8, -8), Color("544263"), 2)
			_text("事", Color("372e44"))
		"rest":
			draw_line(Vector2(-13, 14), Vector2(13, 14), Color("c89b70"), 4)
			draw_colored_polygon(PackedVector2Array([Vector2(-12,10),Vector2(0,-17),Vector2(12,10)]), Color("e2ac6d"))
			_text("休", Color("4e392c"))
		"gold":
			draw_circle(Vector2.ZERO, 12, Color("e5c573"))
			draw_arc(Vector2.ZERO, 8, 0, TAU, 24, Color("967541"), 2, true)
			_text("金", Color("493e2e"))
		"potion":
			draw_circle(Vector2(0, 5), 12, Color("72cdbd"))
			draw_rect(Rect2(-5, -14, 10, 16), Color("72cdbd"))
			draw_rect(Rect2(-6, -15, 12, 4), Color("d6ccaa"))
		"shop":
			var color := Color("b497db") if not entity.get("purchased", false) else Color("697684")
			draw_rect(Rect2(-14, -2, 28, 16), color)
			draw_colored_polygon(PackedVector2Array([Vector2(-17, -2), Vector2(-10, -15), Vector2(10, -15), Vector2(17, -2)]), color.lightened(0.15))
			_text("店", Color("202135"))
		"up", "down", "summit", "camp":
			draw_rect(Rect2(-16, -17, 32, 34), Color("30566a"))
			var text := {"up": "上", "down": "下", "summit": "终", "camp": "营"}
			_text(text[entity.type], Color("a7d9de"))
	draw_set_transform(Vector2.ZERO)

func _key_badge(key_kind: String) -> void:
	draw_rect(Rect2(3, 3, 18, 17), Color("101925"))
	draw_string(FONT, Vector2(5, 16), str(Keys.LABELS.get(key_kind, "?")), HORIZONTAL_ALIGNMENT_LEFT, -1, 13, Keys.COLORS.get(key_kind, Color.WHITE))

func _text(text: String, color: Color) -> void:
	draw_string(FONT, Vector2(-10, 7), text, HORIZONTAL_ALIGNMENT_LEFT, -1, 20, color)

func _draw_hero(center: Vector2, tile: float) -> void:
	var s := tile / 44.0
	draw_set_transform(center, 0, Vector2.ONE * s)
	draw_circle(Vector2(0, 8), 16, Color(0, 0, 0, 0.35))
	var cloak := Color("82d9c1") if alive else Color("897b85")
	draw_colored_polygon(PackedVector2Array([Vector2(-12, 14), Vector2(-9, -1), Vector2(9, -1), Vector2(12, 14)]), cloak)
	draw_circle(Vector2(0, -8), 9, Color("ead1ad"))
	draw_arc(Vector2(0, -9), 9, PI, TAU, 16, cloak.darkened(0.3), 5, true)
	draw_rect(Rect2(-5, -9, 10, 3), Color("263849"))
	draw_line(Vector2(14, 12), Vector2(14, -12), Color("d9e4e4"), 3, true)
	draw_line(Vector2(10, 4), Vector2(18, 4), Color("d9b576"), 3, true)
	draw_set_transform(Vector2.ZERO)
