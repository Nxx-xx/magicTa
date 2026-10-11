extends Control
## Runtime art with readable semantic badges and a vector fallback for missing assets.
signal cell_selected(cell: Vector2i)
signal view_changed
signal arrived
signal footstep
signal pan_started

const WALK_SECONDS := 0.22
const WalkArt = preload("res://scripts/ui/hero_walk.gd")
const TouchScroll = preload("res://scripts/ui/touch_scroll.gd")
const HeroCatalog = preload("res://scripts/ui/phase3_animation_catalog.gd")
const HeroGait = preload("res://scripts/ui/hero_gait.gd")
const RuinArt = preload("res://scripts/ui/phase3_ruin_art.gd")
const EnemyMapArt = preload("res://scripts/ui/phase3_enemy_map_art.gd")
const TowerEnvironment = preload("res://scripts/ui/tower_environment.gd")
const EncounterArt = preload("res://scripts/ui/encounter_art.gd")
const RETURN_MARKERS := [preload("res://assets/ui/phase3/return_marker_0.svg"),preload("res://assets/ui/phase3/return_marker_1.svg")]

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
var moving := false
var move_from := Vector2.ZERO
var move_progress := 0.0
var walk_phase := 0.0
var settle_seconds := -1.0
var hero_idle_started := 0.0
var walk_art: MeshInstance2D
var hero_catalog := HeroCatalog.new()
var idle_seconds := 0.0
var interaction_started := -1.0
var ruin_art := RuinArt.new()
var enemy_map_art := EnemyMapArt.new()
var tower_environment := TowerEnvironment.new()
var exploration := false
var lock_to_hero := false
var overview := false
var following := true
var safe_top := 12.0
var safe_bottom := 12.0
var camera_center := Vector2(5.5, 5.5)
var camera_target := Vector2(5.5, 5.5)
var pointer_down := false
var dragging := false
var press_position := Vector2.ZERO
var pointer_id := -2
var last_position := Vector2.ZERO

func _ready() -> void:
	set_meta("map_surface", true)
	mouse_filter = Control.MOUSE_FILTER_STOP
	mouse_default_cursor_shape = Control.CURSOR_POINTING_HAND
	texture_filter = CanvasItem.TEXTURE_FILTER_LINEAR_WITH_MIPMAPS
	clip_contents = true
	resized.connect(queue_redraw)
	walk_art = WalkArt.new()
	add_child(walk_art)
	hero_catalog.configure_runtime()
	HeroGait.warm()

func setup(floor_state: Dictionary, player_position: Vector2i, selection: Vector2i, is_alive: bool, enemy_definitions: Dictionary = {}) -> void:
	var same_floor: bool = not map.is_empty() and int(map.get("floor", 0)) == int(floor_state.get("floor", 0)) and map.get("floor_seed", "") == floor_state.get("floor_seed", "")
	# Snapshot observation happens only after the host refreshes committed state.
	ruin_art.observe(floor_state,same_floor,idle_seconds)
	map = floor_state
	enemies = enemy_definitions
	var delta := player_position - hero
	if absi(delta.x) + absi(delta.y) == 1:
		facing = "right" if delta.x > 0 else ("left" if delta.x < 0 else ("down" if delta.y > 0 else "up"))
	hero = player_position
	if not same_floor:
		enemy_map_art.clear()
		interaction_started = -1.0
		recenter()
	elif following:
		_follow_hero()
	if same_floor and absi(delta.x) + absi(delta.y) == 1 and is_inside_tree():
		move_from = hero_visual
		move_progress = 0.0
		moving = true
		settle_seconds = -1.0
	elif not same_floor or delta != Vector2i.ZERO:
		moving = false
		move_progress = 0.0
		hero_visual = Vector2(hero)
		walk_phase = 0.0
		settle_seconds = -1.0
	# A HUD/selection refresh at the same position must not snap an in-flight walk.
	selected = selection
	alive = is_alive
	queue_redraw()

func _cell_size() -> float:
	if exploration and not overview:
		return clampf(size.x / 5.0, 60.0, 144.0) if lock_to_hero else clampf(size.x / 7.5, 44.0, 80.0)
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
	camera_target = (hero_visual if moving else Vector2(hero)) + Vector2.ONE * 0.5
	if not lock_to_hero: camera_target = _bounded_center(camera_target)
	camera_center = camera_target
	view_changed.emit()
	queue_redraw()

func set_overview(value: bool) -> void:
	overview = value
	recenter()

func refit_view() -> void:
	if following:
		_follow_hero()
		if lock_to_hero: camera_center = camera_target
	if not lock_to_hero:
		camera_target = _bounded_center(camera_target)
		camera_center = _bounded_center(camera_center)
	queue_redraw()

func _follow_hero() -> void:
	# Follow the animated position, including at the floor edges. The walk itself
	# supplies smooth motion; camera lag would move the hero away from the center.
	var target := hero_visual + Vector2.ONE * 0.5
	if lock_to_hero:
		camera_target = target
	else:
		var dead_zone := Vector2.ONE * 0.7
		camera_target = _bounded_center(Vector2(clampf(camera_target.x, target.x - dead_zone.x, target.x + dead_zone.x), clampf(camera_target.y, target.y - dead_zone.y, target.y + dead_zone.y)))

func _process(delta: float) -> void:
	idle_seconds += minf(delta, .06)
	if not moving and settle_seconds >= 0:
		settle_seconds += minf(delta, .06)
		if settle_seconds >= HeroGait.SETTLE_SECONDS:
			settle_seconds = -1.0
			hero_idle_started = idle_seconds
		queue_redraw()
	if interaction_started >= 0:
		queue_redraw()
		if idle_seconds-interaction_started >= .4: interaction_started = -1.0
	if not ruin_art.playing.is_empty(): queue_redraw()
	if not marked_cells.is_empty() and not reduce_motion and int(idle_seconds*2) != int((idle_seconds-minf(delta,.06))*2): queue_redraw()
	if not moving and not reduce_motion and int(idle_seconds*6) != int((idle_seconds-minf(delta,.06))*6): queue_redraw()
	# Advance across boundaries in the same frame, retaining fractional time.
	# Cap only long suspended frames; never fast-forward through the map on resume.
	var remaining := minf(delta, 0.06)
	while moving and remaining > 0:
		var used := minf(remaining, (1.0 - move_progress) * WALK_SECONDS)
		move_progress = minf(1.0, move_progress + used / WALK_SECONDS)
		walk_phase += used / WALK_SECONDS * PI
		hero_visual = move_from.lerp(Vector2(hero), move_progress)
		remaining -= used
		if move_progress >= 0.99999:
			hero_visual = Vector2(hero)
			moving = false
			settle_seconds = 0.0
			footstep.emit()
			arrived.emit()
		queue_redraw()
	if exploration and not overview:
		if following:
			_follow_hero()
		if not camera_center.is_equal_approx(camera_target):
			camera_center = camera_target if lock_to_hero or reduce_motion else camera_center.lerp(camera_target, 1.0 - exp(-18.0 * delta))
			queue_redraw()

func cancel_pointer() -> void:
	pointer_down = false
	dragging = false
	pointer_id = -2

func _emit_cell(position: Vector2) -> void:
	var local := position - _origin()
	var tile := _cell_size()
	if tile > 0 and Rect2(Vector2.ZERO, Vector2.ONE * tile * 11).has_point(local):
		cell_selected.emit(Vector2i(int(local.x / tile), int(local.y / tile)))

func _begin_pointer(position: Vector2, id: int) -> void:
	pointer_down = true
	pointer_id = id
	dragging = false
	press_position = position
	last_position = position

func _drag_pointer(position: Vector2) -> void:
	if not dragging and position.distance_to(press_position) > 10:
		dragging = true
		if exploration and not overview and not lock_to_hero:
			following = false
		pan_started.emit()
		view_changed.emit()
	if dragging and exploration and not overview and not lock_to_hero:
		camera_center = _bounded_center(camera_center - (position - last_position) / _cell_size())
		camera_target = camera_center
		queue_redraw()
	# A swipe cancels a tap/route without detaching the exploration camera.
	# Distant targets remain accessible through the minimap's full-floor view.
	last_position = position

func _end_pointer(position: Vector2, canceled: bool = false) -> void:
	var was_dragging := dragging
	cancel_pointer()
	if not canceled and not was_dragging and Rect2(Vector2.ZERO, size).has_point(position):
		_emit_cell(position)

func _pointer_surface_hit(position: Vector2) -> bool:
	# Include ancestor scroll clipping and overlays outside this board's parent.
	var input_root: Node = get_parent()
	while input_root.get_parent() is Control:
		input_root = input_root.get_parent()
	return TouchScroll.hit_control(input_root, position) == self

func _input(event: InputEvent) -> void:
	if event.device == InputEvent.DEVICE_ID_EMULATION or mouse_filter != Control.MOUSE_FILTER_STOP or not is_visible_in_tree():
		return
	if event is InputEventScreenTouch:
		var local: Vector2 = get_global_transform_with_canvas().affine_inverse() * event.position
		if event.canceled and pointer_down and pointer_id == -1:
			cancel_pointer()
			pan_started.emit()
			get_viewport().set_input_as_handled()
			return
		if event.pressed and not event.canceled and not pointer_down and _pointer_surface_hit(event.position):
			_begin_pointer(local, event.index)
		elif pointer_down and pointer_id == event.index and (not event.pressed or event.canceled):
			_end_pointer(local, event.canceled)
		else:
			return
		get_viewport().set_input_as_handled()
	elif event is InputEventScreenDrag and pointer_down and pointer_id == event.index:
		_drag_pointer(get_global_transform_with_canvas().affine_inverse() * event.position)
		get_viewport().set_input_as_handled()

func _gui_input(event: InputEvent) -> void:
	if event.device == InputEvent.DEVICE_ID_EMULATION:
		return
	if event is InputEventMouseButton and event.button_index == MOUSE_BUTTON_LEFT:
		if event.pressed and not pointer_down:
			_begin_pointer(event.position, -1)
		elif pointer_down and pointer_id == -1 and not event.pressed:
			_end_pointer(event.position)
		accept_event()
	elif event is InputEventMouseMotion and pointer_down and pointer_id == -1:
		_drag_pointer(event.position)
		accept_event()

func _draw() -> void:
	if map.is_empty():
		return
	var tile := _cell_size()
	var origin := _origin()
	TowerEnvironment.Masonry.terrain(self,map,origin,tile)
	# Architecture and light sit below every entity, badge and interaction marker.
	# CampBoard overrides _draw and therefore keeps its painted environment unchanged.
	tower_environment.draw(self,map,origin,tile,idle_seconds,reduce_motion)
	for y in 11:
		for x in 11:
			var cell := Vector2i(x, y)
			var rect := Rect2(origin + Vector2(cell) * tile + Vector2.ONE, Vector2.ONE * (tile - 2))
			var entity: Dictionary = map.entities.get("%d,%d" % [x, y], {})
			if not entity.is_empty():
				TowerEnvironment.entity_foundation(self,entity,rect.get_center(),tile)
				_draw_entity(entity, rect.get_center(), tile)
			if "%d,%d" % [x,y] in marked_cells:
				var marker_size := clampf(tile*.36,12,20)
				var marker_frame := 0 if reduce_motion else int(idle_seconds*2)%2
				draw_texture_rect(RETURN_MARKERS[marker_frame],Rect2(rect.position,Vector2.ONE*marker_size),false)
			if cell == selected and cell != hero:
				draw_rect(rect.grow(-1), Color("f0d596"), false, 2)
	_draw_hero(origin + (hero_visual + Vector2.ONE * 0.5) * tile, tile)

func _draw_entity(entity: Dictionary, center: Vector2, tile: float) -> void:
	var s := tile / 44.0
	draw_set_transform(center, 0, Vector2.ONE * s)
	if entity.get("type") in ["summit", "camp"]:
		TowerEnvironment.gateway(self,str(entity.type))
		draw_rect(Rect2(4, 4, 18, 18), Color("14212d"))
		draw_string(FONT, Vector2(5, 18), "终" if entity.type == "summit" else "营", HORIZONTAL_ALIGNMENT_LEFT, -1, 13, Color("f3deaa"))
		draw_set_transform(Vector2.ZERO)
		return
	var texture: Texture2D = Art.entity_texture(entity)
	if entity.get("type") in ["up","down"]:
		texture = TowerEnvironment.Masonry.staircase(str(entity.type))
	if entity.has("ruin_id"):
		texture = ruin_art.texture(entity,idle_seconds,reduce_motion)
	elif entity.get("type") == "enemy" and map.has("phase3_recipe"):
		var animated := enemy_map_art.texture(str(entity.enemy_id),idle_seconds,reduce_motion)
		if animated != null: texture = animated
	if texture != null:
		if entity.get("type") in ["event", "rest"] and not entity.has("ruin_id"):
			EncounterArt.draw(self, str(entity.type), texture, idle_seconds, reduce_motion)
			draw_set_transform(Vector2.ZERO)
			return
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

func play_interaction() -> void:
	if map.has("phase3_recipe") and not reduce_motion:
		interaction_started = idle_seconds
		queue_redraw()

func hero_pose() -> Dictionary:
	# Interaction and reduced-motion poses retain the catalog's existing policy.
	if not reduce_motion and (moving or interaction_started < 0) and hero_catalog.manifest.get("actions", {}).has("map_walk_" + facing):
		if moving: return HeroGait.pose(facing, walk_phase)
		if settle_seconds >= 0: return HeroGait.pose(facing, walk_phase, settle_seconds)
	var action := "map_walk_"+facing if moving and not reduce_motion else "map_idle_"+facing
	var seconds := walk_phase/TAU*.5 if moving else idle_seconds - hero_idle_started
	if not moving and not reduce_motion and interaction_started >= 0:
		action = "map_interact_"+facing
		seconds = idle_seconds-interaction_started
	return hero_catalog.frame_at(action,seconds,reduce_motion)

func _draw_hero(center: Vector2, tile: float) -> void:
	if map.has("phase3_recipe"):
		# The existing movement clock and interpolation own position and cadence.
		var frame := hero_pose()
		if frame.ok and not frame.fallback:
			walk_art.visible = false
			draw_circle(center+Vector2(0,tile*.32),tile*.22,Color(0,0,0,.35))
			var size := Vector2.ONE*tile
			var foot := center+Vector2(0,tile*.43)
			draw_texture_rect(frame.texture,Rect2(foot-frame.anchor/128.0*tile,size),false,Color.WHITE if alive else Color("897b85"))
			return
	var texture: Texture2D = Art.hero(facing)
	if texture != null:
		draw_circle(center + Vector2(0, tile * 0.32), tile * 0.22, Color(0,0,0,0.35))
		walk_art.visible = true
		walk_art.position = center
		walk_art.scale = Vector2.ONE * tile
		walk_art.pose(texture, facing, walk_phase, moving and not reduce_motion, alive)
		return
	walk_art.visible = false
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
