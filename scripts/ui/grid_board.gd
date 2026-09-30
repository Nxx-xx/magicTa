extends Control
## Runtime art with readable semantic badges and a vector fallback for missing assets.
signal cell_selected(cell: Vector2i)
signal view_changed

const FONT = preload("res://assets/fonts/ui_font.tres")
const Keys = preload("res://scripts/core/map_keys.gd")
const Art = preload("res://scripts/ui/runtime_art.gd")
const EnemyRules = preload("res://scripts/core/enemy_rules.gd")
const Monsters = preload("res://scripts/ui/monster_art.gd")
var map: Dictionary = {}
var enemies: Dictionary = {}
var hero := Vector2i(1, 9)
var selected := Vector2i(-1, -1)
var alive := true
var facing := "down"
var marked_cells: Array = []
var reduce_motion := false
var hero_visual := Vector2(1,9)
var move_tween: Tween
var exploration := false
var overview := false
var following := true
var safe_top := 12.0
var safe_bottom := 164.0
var camera_center := Vector2(5.5, 5.5)
var camera_target := Vector2(5.5, 5.5)
var pointer_down := false
var dragging := false
var press_position := Vector2.ZERO

func _ready() -> void:
	mouse_filter = Control.MOUSE_FILTER_STOP
	mouse_default_cursor_shape = Control.CURSOR_POINTING_HAND
	texture_filter = CanvasItem.TEXTURE_FILTER_LINEAR_WITH_MIPMAPS
	clip_contents = true
	resized.connect(queue_redraw)

func setup(floor_state: Dictionary, player_position: Vector2i, selection: Vector2i, is_alive: bool, enemy_definitions: Dictionary = {}) -> void:
	var same_floor := not map.is_empty() and int(map.get("floor", 0)) == int(floor_state.get("floor", 0))
	map = floor_state
	enemies = enemy_definitions
	var delta := player_position - hero
	if absi(delta.x) + absi(delta.y) == 1:
		facing = "right" if delta.x > 0 else ("left" if delta.x < 0 else ("down" if delta.y > 0 else "up"))
	hero = player_position
	if not same_floor:
		recenter()
	elif following:
		_follow_hero()
	if is_instance_valid(move_tween):
		move_tween.kill()
	if not reduce_motion and same_floor and absi(delta.x) + absi(delta.y) == 1 and is_inside_tree():
		move_tween = create_tween()
		move_tween.tween_method(_set_hero_visual, hero_visual, Vector2(hero), 0.10)
	else:
		hero_visual = Vector2(hero)
	selected = selection
	alive = is_alive
	queue_redraw()

func _cell_size() -> float:
	if exploration and not overview:
		return clampf(size.x / 7.5, 44.0, 80.0)
	return minf(size.x, size.y) / 11.0

func _origin() -> Vector2:
	if exploration and not overview:
		return _safe_rect().get_center() - camera_center * _cell_size()
	return (size - Vector2.ONE * _cell_size() * 11.0) * 0.5

func _safe_rect() -> Rect2:
	return Rect2(Vector2(8, safe_top), Vector2(maxf(1, size.x - 16), maxf(44, size.y - safe_top - safe_bottom)))

func _bounded_center(value: Vector2) -> Vector2:
	if not exploration or size.x <= 0 or size.y <= 0:
		return Vector2(5.5, 5.5)
	var half := _safe_rect().size / _cell_size() * 0.5
	return Vector2(clampf(value.x, minf(half.x, 5.5), maxf(11 - half.x, 5.5)), clampf(value.y, minf(half.y, 5.5), maxf(11 - half.y, 5.5)))

func recenter() -> void:
	following = true
	cancel_pointer()
	camera_target = _bounded_center(Vector2(hero) + Vector2.ONE * 0.5)
	camera_center = camera_target
	view_changed.emit()
	queue_redraw()

func set_overview(value: bool) -> void:
	overview = value
	recenter()

func refit_view() -> void:
	if following:
		_follow_hero()
	camera_target = _bounded_center(camera_target)
	camera_center = _bounded_center(camera_center)
	queue_redraw()

func _follow_hero() -> void:
	var target := Vector2(hero) + Vector2.ONE * 0.5
	# A small dead zone avoids moving the camera on every grid step.
	var dead_zone := Vector2.ONE * 0.7
	camera_target = _bounded_center(Vector2(clampf(camera_target.x, target.x - dead_zone.x, target.x + dead_zone.x), clampf(camera_target.y, target.y - dead_zone.y, target.y + dead_zone.y)))

func _process(delta: float) -> void:
	if not exploration or overview or camera_center.is_equal_approx(camera_target):
		return
	camera_center = camera_target if reduce_motion else camera_center.lerp(camera_target, 1.0 - exp(-18.0 * delta))
	queue_redraw()

func cancel_pointer() -> void:
	pointer_down = false
	dragging = false

func _emit_cell(position: Vector2) -> void:
	var local := position - _origin()
	var tile := _cell_size()
	if tile > 0 and Rect2(Vector2.ZERO, Vector2.ONE * tile * 11).has_point(local):
		cell_selected.emit(Vector2i(int(local.x / tile), int(local.y / tile)))

func _gui_input(event: InputEvent) -> void:
	# The project emulates mouse events from touch. Use one path to avoid double steps.
	if event is InputEventMouseButton and event.button_index == MOUSE_BUTTON_LEFT:
		if event.pressed:
			pointer_down = true
			dragging = false
			press_position = event.position
		elif pointer_down:
			var was_dragging := dragging
			cancel_pointer()
			if not was_dragging and Rect2(Vector2.ZERO, size).has_point(event.position):
				_emit_cell(event.position)
		accept_event()
	elif event is InputEventMouseMotion and pointer_down and exploration and not overview:
		if not dragging and event.position.distance_to(press_position) > 10:
			dragging = true
			following = false
			view_changed.emit()
		if dragging:
			camera_center = _bounded_center(camera_center - event.relative / _cell_size())
			camera_target = camera_center
			queue_redraw()
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
			var tile_rect := Rect2(origin + Vector2(cell) * tile, Vector2.ONE * tile)
			var texture: Texture2D = Art.environment("wall_%02d" % _wall_mask(cell) if wall else "floor_%d" % (2 if (x + y * 3) % 4 < 2 else (x * 7 + y * 3) % 4))
			if texture != null:
				draw_texture_rect(texture, tile_rect, false, (Color("505e74") if int(map.get("floor", 1)) >= 6 else Color("66717c")) if wall else Color.WHITE)
			else:
				draw_rect(rect, Color("253346") if wall else Color("14212d"))
			if not wall and absi(cell.x - hero.x) + absi(cell.y - hero.y) == 1:
				draw_rect(rect.grow(-1), Color("83d5bf"), false, 1)
			var entity: Dictionary = map.entities.get("%d,%d" % [x, y], {})
			if not entity.is_empty():
				_draw_entity(entity, rect.get_center(), tile)
			if "%d,%d" % [x,y] in marked_cells:
				draw_circle(rect.position + Vector2(4,4), 3, Color("e0bf80"))
			if cell == selected:
				draw_rect(rect.grow(-1), Color("f0d596"), false, 2)
	_draw_hero(origin + (hero_visual + Vector2.ONE * 0.5) * tile, tile)

func _draw_entity(entity: Dictionary, center: Vector2, tile: float) -> void:
	var s := tile / 44.0
	draw_set_transform(center, 0, Vector2.ONE * s)
	var texture: Texture2D = Art.entity_texture(entity)
	if texture != null:
		draw_texture_rect(texture, Rect2(-22, -22, 44, 44), false, Color("8a919b") if entity.get("purchased", false) else Color.WHITE)
		if entity.type == "enemy":
			var badge := EnemyRules.badge(enemies.get(str(entity.enemy_id), {"id": entity.enemy_id}), entity)
			draw_rect(Rect2(6, 5, 15, 17), Color("14212d"))
			draw_string(FONT, Vector2(7, 18), badge, HORIZONTAL_ALIGNMENT_LEFT, -1, 13, Color("f3deaa"))
		elif entity.type in ["key", "door"]:
			_key_badge(Keys.kind(entity))
		elif entity.type in ["up", "down", "choice"]:
			draw_rect(Rect2(4, 4, 18, 18), Color("14212d"))
			draw_string(FONT, Vector2(5, 18), {"up":"上", "down":"下", "choice":"选"}[entity.type], HORIZONTAL_ALIGNMENT_LEFT, -1, 13, Color("f3deaa"))
		draw_set_transform(Vector2.ZERO)
		return
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
	var texture: Texture2D = Art.hero(facing)
	if texture != null:
		draw_circle(center + Vector2(0, tile * 0.32), tile * 0.22, Color(0,0,0,0.35))
		draw_texture_rect(texture, Rect2(center + Vector2(-tile * 0.5, -tile * 0.47625), Vector2.ONE * tile), false, Color.WHITE if alive else Color("897b85"))
		return
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

func _wall_mask(cell: Vector2i) -> int:
	var mask := 0
	var offsets := [Vector2i.UP, Vector2i.RIGHT, Vector2i.DOWN, Vector2i.LEFT]
	for index in 4:
		var adjacent: Vector2i = cell + offsets[index]
		if adjacent.x < 0 or adjacent.y < 0 or adjacent.x >= 11 or adjacent.y >= 11 or str(map.rows[adjacent.y]).substr(adjacent.x, 1) == "#":
			mask |= 1 << index
	return mask

func _set_hero_visual(value: Vector2) -> void:
	hero_visual = value
	queue_redraw()
