extends "res://scripts/ui/grid_board.gd"
## Painted environment with independently animated model renders and grid-safe picking.
const Layout = preload("res://scripts/core/camp_layout.gd")
const KnightArt = preload("res://scripts/ui/camp_knight_art.gd")
const DeathArt = preload("res://scripts/ui/camp_death_art.gd")
const CAMP_BACKGROUND = preload("res://assets/environment/camp/v3/woodland_camp.png")
const ENVIRONMENT_SHADER = preload("res://scripts/ui/camp_environment.gdshader")
var environment: TextureRect
var backdrop: TextureRect
var environment_material: ShaderMaterial

func _ready() -> void:
	super._ready()
	backdrop = _environment_layer("ForestBackdrop")
	var backdrop_material := ShaderMaterial.new()
	backdrop_material.shader = ENVIRONMENT_SHADER
	backdrop_material.set_shader_parameter("backdrop", true)
	backdrop.material = backdrop_material
	environment = _environment_layer("PaintedCamp")
	environment_material = ShaderMaterial.new()
	environment_material.shader = ENVIRONMENT_SHADER
	environment.material = environment_material
	resized.connect(_fit_environment)
	_fit_environment()

func _environment_layer(layer_name: String) -> TextureRect:
	var layer := TextureRect.new()
	layer.name = layer_name
	layer.texture = CAMP_BACKGROUND
	layer.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	layer.mouse_filter = Control.MOUSE_FILTER_IGNORE
	layer.show_behind_parent = true
	add_child(layer)
	return layer

func _fit_environment() -> void:
	if not is_instance_valid(environment): return
	environment.position = _origin()
	environment.size = Vector2.ONE * _cell_size() * 11
	var side := maxf(size.x, size.y)
	backdrop.position = (size - Vector2.ONE * side) * .5
	backdrop.size = Vector2.ONE * side

func _input(event: InputEvent) -> void:
	# This embedded map owns its gestures before the enclosing menu scroll observes them.
	var host: Node = self
	while host.get_parent() is Control: host = host.get_parent()
	if host.get("modal_open") == true:
		cancel_pointer()
		pan_started.emit()
		return
	if event is InputEventScreenTouch or event is InputEventScreenDrag:
		if event is InputEventScreenTouch and event.pressed and TouchScroll.hit_control(host,event.position) != self: return
		super._input(event)
		return
	if mouse_filter != Control.MOUSE_FILTER_STOP or not is_visible_in_tree() or event.device == InputEvent.DEVICE_ID_EMULATION: return
	if event is InputEventMouseButton and event.button_index == MOUSE_BUTTON_LEFT:
		var local: Vector2 = get_global_transform_with_canvas().affine_inverse()*event.position
		if event.pressed and TouchScroll.hit_control(host,event.position) == self:
			_begin_pointer(local,-1)
		elif pointer_down and pointer_id == -1 and not event.pressed:
			_end_pointer(local)
		else: return
		get_viewport().set_input_as_handled()
	elif event is InputEventMouseMotion and pointer_down and pointer_id == -1:
		_drag_pointer(get_global_transform_with_canvas().affine_inverse()*event.position)
		get_viewport().set_input_as_handled()

func _process(delta: float) -> void:
	var previous := int(idle_seconds*24)
	super._process(delta)
	_fit_environment()
	if environment_material != null:
		environment_material.set_shader_parameter("seconds", 0.0 if reduce_motion else idle_seconds)
	if not reduce_motion and previous != int(idle_seconds*24): queue_redraw()

func knight_rect() -> Rect2:
	var tile := _cell_size()
	var foot := _origin()+(Vector2(Layout.KNIGHT)+Vector2(.5,.68))*tile
	var sprite_size := Vector2.ONE*tile*1.95
	return Rect2(foot-KnightArt.ANCHOR*sprite_size,sprite_size)

func tower_rect() -> Rect2:
	return Rect2(_origin()+Vector2(4.7,.55)*_cell_size(),Vector2(1.6,1.4)*_cell_size())

func death_rect() -> Rect2:
	var tile := _cell_size()
	var foot := _origin()+(Vector2(Layout.DEATH)+Vector2(.5,.68))*tile
	var sprite_size := Vector2(DeathArt.TEXTURE.get_size()).normalized()*tile*2.65
	return Rect2(foot-DeathArt.ANCHOR*sprite_size,sprite_size)

func _emit_cell(point: Vector2) -> void:
	# A tall sprite may cover several floor tiles. Its visible body is the NPC target.
	var tile := _cell_size()
	var font_size := 12 if tile < 36 else 14
	var knight_label := _label_rect("老骑士",_origin()+(Vector2(Layout.KNIGHT)+Vector2(.5,1.12))*tile,font_size)
	var death_label := _label_rect("死神",_origin()+(Vector2(Layout.DEATH)+Vector2(.5,1.12))*tile,font_size)
	var tower_label := _label_rect("魔塔入口",_origin()+Vector2(5.5,2.16)*tile,font_size)
	if knight_rect().grow(-tile*.28).has_point(point) or knight_label.has_point(point):
		cell_selected.emit(Layout.KNIGHT)
	elif death_rect().grow(-tile*.15).has_point(point) or death_label.has_point(point):
		cell_selected.emit(Layout.DEATH)
	elif tower_rect().has_point(point) or tower_label.has_point(point):
		cell_selected.emit(Layout.TOWER)
	else:
		super._emit_cell(point)

func _label_rect(copy: String, center: Vector2, font_size: int) -> Rect2:
	var text_size := FONT.get_string_size(copy,HORIZONTAL_ALIGNMENT_LEFT,-1,font_size)
	return Rect2(center-Vector2(text_size.x*.5,0)-Vector2(7,3),Vector2(text_size.x+14,font_size+9))

func _label_at(copy: String, center: Vector2, font_size: int, tint: Color) -> void:
	var text_size := FONT.get_string_size(copy,HORIZONTAL_ALIGNMENT_LEFT,-1,font_size)
	var rect := _label_rect(copy,center,font_size)
	var style := StyleBoxFlat.new()
	style.bg_color = Color(.025,.047,.052,.82)
	style.border_color = Color(tint,.28)
	style.set_border_width_all(1)
	style.set_corner_radius_all(3)
	style.shadow_color = Color(0,0,0,.24)
	style.shadow_size = 3
	draw_style_box(style,rect)
	draw_string(FONT,center+Vector2(-text_size.x*.5,font_size),copy,HORIZONTAL_ALIGNMENT_LEFT,-1,font_size,tint)

func _contact_shadow(foot: Vector2, radius: float) -> void:
	draw_set_transform(foot,0,Vector2(1,.32))
	for layer in range(6,0,-1):
		draw_circle(Vector2.ZERO,radius*float(layer)/6.0,Color(0.015,.025,.035,.045))
	draw_set_transform(Vector2.ZERO)

func _draw_hero(center: Vector2, tile: float) -> void:
	# Reuse the published four-facing rig and gait clock in camp as in the tower.
	# The feet, rather than the transparent canvas centre, own ground placement.
	var frame := hero_pose()
	if frame.ok and not frame.fallback:
		walk_art.visible = false
		var foot := center+Vector2(0,tile*.32)
		_contact_shadow(foot,tile*.18)
		var sprite_size := Vector2.ONE*tile*1.20
		draw_texture_rect(frame.texture,Rect2(foot-frame.anchor/128.0*sprite_size,sprite_size),false,Color.WHITE if alive else Color("897b85"))
		return
	var texture: Texture2D = Art.hero(facing)
	if texture == null:
		super._draw_hero(center,tile)
		return
	_contact_shadow(center+Vector2(0,tile*.32),tile*.25)
	walk_art.visible = true
	walk_art.position = center
	walk_art.scale = Vector2.ONE*tile
	walk_art.pose(texture,facing,walk_phase,moving and not reduce_motion,alive)
	var fire_distance := (hero_visual-Vector2(6.2,6.5)).length()
	var warmth := clampf(1.0-fire_distance/3.0,0.0,1.0)
	walk_art.modulate = Color("d4e0e2").lerp(Color("ffe4b8"),warmth*.65)

func _draw_knight(tile: float) -> void:
	var foot := _origin()+(Vector2(Layout.KNIGHT)+Vector2(.5,.68))*tile
	_contact_shadow(foot,tile*.36)
	draw_texture_rect(KnightArt.frame(idle_seconds,reduce_motion),knight_rect(),false,Color("ece0c5"))

func _draw_death(tile: float) -> void:
	var foot := _origin()+(Vector2(Layout.DEATH)+Vector2(.5,.68))*tile
	_contact_shadow(foot,tile*.32)
	DeathArt.draw(self,death_rect(),idle_seconds,reduce_motion)

func _draw() -> void:
	if map.is_empty(): return
	var tile := _cell_size()
	var origin := _origin()
	_fit_environment()
	var artwork := Rect2(origin,Vector2.ONE*tile*11)
	if overview:
		draw_rect(artwork.grow(1),Color(.64,.69,.55,.3),false,1)
		draw_rect(artwork.grow(4),Color(.05,.09,.10,.65),false,3)
	# A quiet destination ring replaces the old full-board grid overlay.
	if selected.x >= 0 and Layout.walkable(selected) and selected != hero:
		var center := origin+(Vector2(selected)+Vector2.ONE*.5)*tile
		draw_set_transform(center,0,Vector2(1,.55))
		draw_arc(Vector2.ZERO,tile*.27,0,TAU,32,Color("e5c58b"),1.6,true)
		draw_set_transform(Vector2.ZERO)
	var hero_center := origin+(hero_visual+Vector2.ONE*.5)*tile
	if hero_visual.y < Layout.KNIGHT.y:
		_draw_hero(hero_center-Vector2(0,tile*.26),tile*1.6)
		_draw_knight(tile)
		_draw_death(tile)
	elif hero_visual.y < Layout.DEATH.y:
		_draw_knight(tile)
		_draw_hero(hero_center-Vector2(0,tile*.26),tile*1.6)
		_draw_death(tile)
	else:
		_draw_knight(tile)
		_draw_death(tile)
		_draw_hero(hero_center-Vector2(0,tile*.26),tile*1.6)
	var font_size := 12 if tile < 36 else 14
	_label_at("老骑士",origin+(Vector2(Layout.KNIGHT)+Vector2(.5,1.12))*tile,font_size,Color("e4c78f"))
	_label_at("死神",origin+(Vector2(Layout.DEATH)+Vector2(.5,1.12))*tile,font_size,Color("e4c78f"))
	_label_at("魔塔入口",origin+Vector2(5.5,2.16)*tile,font_size,Color("ead6a8"))
	_draw_embers(origin,tile)

func _draw_embers(origin: Vector2, tile: float) -> void:
	if reduce_motion: return
	# Sparse sparks rise from the actual painted fire, never from the path.
	for i in 7:
		var age := fposmod(idle_seconds*.26+i*.143,1.0)
		var phase := idle_seconds*.9+i*2.1
		var point := origin+(Vector2(6.73,7.00)+Vector2(sin(phase)*(.07+age*.12),-age*.9))*tile
		var opacity := sin(age*PI)*.60
		draw_circle(point,maxf(.75,tile*.013),Color(1,.68,.24,opacity))
	# A few fireflies above the grass, away from the labels and main road.
	for i in 4:
		var phase := idle_seconds*.36+i*2.4
		var point := origin+(Vector2(3.5+i*.9,5.0+sin(i*2.0))+Vector2(sin(phase)*.18,cos(phase*.7)*.13))*tile
		var opacity := pow(maxf(0.0,sin(phase)),3.0)*.36
		draw_circle(point,2.7,Color(.68,.85,.38,opacity*.18))
		draw_circle(point,.9,Color(.9,1,.60,opacity))

