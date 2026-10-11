extends RefCounted
## Material coordinates follow the map, not the camera or individual tile origins.
## Architecture is clipped by construction to blocked cells; rows still own movement.
const MATERIAL = preload("res://assets/environment/tower_v03/materials.png")
const STAIRS = preload("res://assets/environment/tower_v03/stairs.png")
static var stair_textures: Dictionary = {}

static func tier(map: Dictionary) -> int:
	var floor_number := int(map.get("floor", 1))
	return 2 if floor_number >= 8 else (1 if floor_number >= 4 else 0)

static func wall(map: Dictionary, cell: Vector2i) -> bool:
	return cell.x < 0 or cell.y < 0 or cell.x >= 11 or cell.y >= 11 or str(map.rows[cell.y]).substr(cell.x, 1) == "#"

static func _material(board: CanvasItem, rect: Rect2, quadrant: Vector2i, uv: Rect2, tint: Color) -> void:
	var half := Vector2(MATERIAL.get_size()) * .5
	# Half a texel inset prevents adjacent atlas panels leaking through at phone sizes.
	var source := Rect2(Vector2(quadrant) * half + uv.position * half, uv.size * half).grow(-.5)
	board.draw_texture_rect_region(MATERIAL, rect, source, tint)

static func terrain(board: CanvasItem, map: Dictionary, origin: Vector2, tile: float) -> void:
	var style := tier(map)
	for y in 11:
		for x in 11:
			var cell := Vector2i(x,y)
			var r := Rect2(origin + Vector2(cell)*tile, Vector2.ONE*tile)
			if wall(map,cell):
				_material(board,r,Vector2i(1,0),Rect2(Vector2(x%6,y%6)/6.0,Vector2.ONE/6.0),Color("9baab5"))
			else:
				var quadrant := Vector2i(1,1) if style == 2 else Vector2i.ZERO
				var tint := Color("8899a5") if style == 1 else Color("a4adb0")
				if style == 2: tint = Color("819a9e")
				_material(board,r,quadrant,Rect2(Vector2(x%4,y%4)/4.0,Vector2.ONE/4.0),tint)

static func edges(board: CanvasItem, map: Dictionary, cell: Vector2i, r: Rect2) -> void:
	var t := r.size.x
	var south := not wall(map,cell+Vector2i.DOWN)
	var west := not wall(map,cell+Vector2i.LEFT)
	var east := not wall(map,cell+Vector2i.RIGHT)
	var north := not wall(map,cell+Vector2i.UP)
	var style := tier(map)
	var cap := Color("526776")
	var edge := Color("85969a")
	var trim := Color("687879") if style == 0 else (Color("89754f") if style == 1 else Color("639792"))
	if south:
		var face := Rect2(r.position+Vector2(0,t*.65),Vector2(t,t*.35))
		_material(board,face,Vector2i(0,1),Rect2(Vector2(float(cell.x%4)/4.0,.115),Vector2(.25,.22)),Color("99a7ad"))
		# Continuous cornice and recessed lower course, with broad staggered joints.
		_material(board,Rect2(r.position+Vector2(0,t*.62),Vector2(t,t*.07)),Vector2i(0,1),Rect2(float(cell.x%4)/4.0,.012,.25,.06),Color("9aaaae"))
		board.draw_line(r.position+Vector2(0,t*.62),r.position+Vector2(t,t*.62),edge.darkened(.40),maxf(.6,t*.010),true)
		board.draw_line(r.position+Vector2(0,t*.70),r.position+Vector2(t,t*.70),Color("13222b"),maxf(1,t*.024))
		if cell.x%2 == 0:
			board.draw_line(r.position+Vector2(t*.28,t*.625),r.position+Vector2(t*.29,t*.69),Color("243842"),maxf(.65,t*.016))
		board.draw_rect(Rect2(r.position+Vector2(0,t*.92),Vector2(t,t*.08)),Color("182b32"))
		board.draw_line(r.position+Vector2(0,t*.92),r.position+Vector2(t,t*.92),trim.darkened(.24),maxf(.7,t*.014))
		if style > 0:
			board.draw_line(r.position+Vector2(0,t*.755),r.position+Vector2(t,t*.755),trim.darkened(.22),maxf(.7,t*.016))
		# End piers resolve exposed corners without extending into any passage.
		if west: _pier(board,r,false,style)
		if east: _pier(board,r,true,style)
		if style > 0 and not west and not east and (cell.x+cell.y)%4 == 1:
			var center := r.position+Vector2(t*.51,t*.81)
			board.draw_line(center-Vector2(0,t*.10),center+Vector2(0,t*.085),Color("263338"),maxf(1,t*.055))
			board.draw_circle(center-Vector2(0,t*.07),maxf(.65,t*.013),trim)
			board.draw_circle(center+Vector2(0,t*.06),maxf(.65,t*.013),trim)
	if west:
		board.draw_rect(Rect2(r.position,Vector2(t*.025,t*(.62 if south else 1))),cap.darkened(.22))
		board.draw_line(r.position+Vector2(t*.028,0),r.position+Vector2(t*.028,t*(.62 if south else 1)),edge.darkened(.52),maxf(.6,t*.010))
	if east:
		board.draw_rect(Rect2(r.position+Vector2(t*.93,0),Vector2(t*.07,t*(.62 if south else 1))),Color("14262f"))
	if north:
		board.draw_rect(Rect2(r.position,Vector2(t,t*.025)),cap.darkened(.30))
	# Fortified / ceremonial storeys also have buttresses along vertical passages.
	# Their footprint stays on the wall side of the actual collision boundary.
	if style > 0 and not south and (cell.y + int(map.get("floor",1)))%3 == 1:
		if west: _side_support(board,r,false,style)
		if east: _side_support(board,r,true,style)
	# Small carved crown only on solid masonry at boss floors, never on walkable tiles.
	if int(map.get("floor",1)) in [5,10] and south and not west and not east and cell.x%4 == 2:
		var c := r.position+Vector2(t*.5,t*.46)
		var ink := Color("7f775b") if style == 1 else Color("63918b")
		board.draw_polyline(PackedVector2Array([c+Vector2(-.13,-.07)*t,c+Vector2(-.10,.07)*t,c+Vector2(.10,.07)*t,c+Vector2(.13,-.07)*t]),ink,maxf(.7,t*.016),true)
		board.draw_line(c-Vector2(0,t*.11),c+Vector2(0,t*.07),ink,maxf(.7,t*.016),true)

static func _side_support(board: CanvasItem, r: Rect2, right: bool, style: int) -> void:
	var t := r.size.x
	var p := r.position+Vector2(t*(.82 if right else .025),t*.26)
	_material(board,Rect2(p,Vector2(.15,.49)*t),Vector2i(0,1),Rect2(.12,.10,.17,.45),Color("91a3a9"))
	board.draw_rect(Rect2(p+Vector2(t*.10 if right else 0.0,0),Vector2(t*.05,t*.49)),Color(.05,.1,.13,.45))
	var metal := Color("887c5c") if style == 1 else Color("66938c")
	for y in [.06,.40]:
		board.draw_line(p+Vector2(0,t*y),p+Vector2(t*.15,t*y),metal.darkened(.15),maxf(1,t*.035))

static func _pier(board: CanvasItem, r: Rect2, right: bool, style: int) -> void:
	var t := r.size.x
	var p := r.position+Vector2(t*(.81 if right else .015),t*.62)
	var body := Rect2(p+Vector2(t*.025,t*.025),Vector2(t*.14,t*.30))
	_material(board,body,Vector2i(0,1),Rect2(.33,.115,.18,.22),Color("a0abad"))
	_material(board,Rect2(p,Vector2(t*.18,t*.065)),Vector2i(0,1),Rect2(.15,.012,.18,.06),Color("a0acad"))
	board.draw_line(p+Vector2(t*.012,t*.004),p+Vector2(t*.164,0),Color("718389"),maxf(.7,t*.012))
	board.draw_rect(Rect2(p+Vector2(0,t*.30),Vector2(t*.18,t*.07)),Color("374c57"))
	if style > 0:
		board.draw_line(p+Vector2(t*.04,t*.1),p+Vector2(t*.04,t*.26),Color("928261") if style == 1 else Color("6c9992"),maxf(.7,t*.017))

static func door_frame(board: CanvasItem, center: Vector2, tile: float) -> void:
	# Original coloured door and key badge remain in front of this stone surround.
	for side in [-1,1]:
		var r := Rect2(center+Vector2(float(side)*.43-.045,-.39)*tile,Vector2(.09,.81)*tile)
		_material(board,r,Vector2i(0,1),Rect2(.35,.12,.15,.78),Color("abb6b5"))
		board.draw_line(r.position,r.position+Vector2(0,r.size.y),Color("7f949a"),maxf(.7,tile*.014))
	var lintel := Rect2(center+Vector2(-.475,-.47)*tile,Vector2(.95,.10)*tile)
	_material(board,lintel,Vector2i(0,1),Rect2(.04,.02,.90,.09),Color("b7bfba"))
	board.draw_line(lintel.position,lintel.position+Vector2(lintel.size.x,0),Color("819599"),maxf(.7,tile*.014))

static func staircase(kind: String) -> Texture2D:
	if not stair_textures.has(kind):
		var texture := AtlasTexture.new()
		texture.atlas = STAIRS
		var size := Vector2(STAIRS.get_size())
		texture.region = Rect2(Vector2(size.x*.5 if kind == "down" else 0.0,0),Vector2(size.x*.5,size.y))
		texture.filter_clip = true
		stair_textures[kind] = texture
	return stair_textures[kind]
