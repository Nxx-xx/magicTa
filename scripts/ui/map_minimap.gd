extends Button
## Lightweight floor navigation: no duplicated character textures or game state.
const FONT = preload("res://assets/fonts/ui_font.tres")
var board: Control
var last_center := Vector2.INF
var last_hero := Vector2.INF
var caption := "全图"

func _ready() -> void:
	name = "FloorMinimap"
	tooltip_text = "小地图 · 点击查看全图\n白点：主角  蓝色：楼梯  红色：敌人  金色：物品"
	mouse_default_cursor_shape = Control.CURSOR_POINTING_HAND
	for state in ["normal", "hover", "pressed", "disabled", "focus"]:
		add_theme_stylebox_override(state, StyleBoxEmpty.new())

func _process(_delta: float) -> void:
	if is_visible_in_tree() and is_instance_valid(board) and (last_center != board.camera_center or last_hero != board.hero_visual):
		last_center = board.camera_center
		last_hero = board.hero_visual
		queue_redraw()

func map_rect() -> Rect2:
	return Rect2(Vector2(7, 7), Vector2.ONE * (size.x - 14))

func _draw() -> void:
	if not is_instance_valid(board) or board.map.is_empty(): return
	var frame := Rect2(Vector2.ZERO, size)
	draw_style_box(_frame(), frame)
	var area := map_rect()
	var tile := area.size.x / 11.0
	for y in 11:
		for x in 11:
			var rect := Rect2(area.position + Vector2(x,y) * tile, Vector2.ONE * tile)
			var wall: bool = board.map.rows[y][x] == "#"
			draw_rect(rect.grow(-0.4), Color("344653") if wall else Color("14212b"))
			var entity: Dictionary = board.map.entities.get("%d,%d" % [x,y], {})
			if entity.is_empty(): continue
			var tint := Color("dfbf78")
			match str(entity.get("type", "")):
				"enemy": tint = Color("ed9395")
				"up", "down", "camp_tower": tint = Color("78cce8")
				"door", "camp_death": tint = Color("bc8ce0")
				"camp_decor", "camp_fire": continue
			draw_rect(rect.grow(-tile * 0.23), tint)
	var view := Rect2(-board._origin() / board._cell_size(), board.size / board._cell_size())
	view = view.intersection(Rect2(0,0,11,11))
	if view.has_area():
		draw_rect(Rect2(area.position + view.position * tile, view.size * tile), Color(0.51,0.84,0.75,0.65), false, 1)
	var hero_point: Vector2 = area.position + (board.hero_visual + Vector2.ONE * 0.5) * tile
	draw_circle(hero_point, maxf(3.0, tile * 0.43), Color("0c131b"))
	draw_circle(hero_point, maxf(2.0, tile * 0.28), Color.WHITE)
	draw_string(FONT, Vector2(0,size.y - 7), caption, HORIZONTAL_ALIGNMENT_CENTER, size.x, 12, Color("c2d3de"))

func _frame() -> StyleBoxFlat:
	var style := StyleBoxFlat.new()
	style.bg_color = Color(0.025,0.05,0.075,0.94)
	style.border_color = Color("e0bf80") if has_focus() or is_hovered() else Color("526777")
	style.set_border_width_all(1)
	style.set_corner_radius_all(6)
	return style
