extends RefCounted
## Presentation-only architecture. All props stay on blocked cells; rows own traversal.
const Art = preload("res://scripts/ui/runtime_art.gd")
const Masonry = preload("res://scripts/ui/tower_masonry.gd")
const GATEWAY = preload("res://assets/environment/tower_v02/gateway.png")
var layout_key := ""
var lamps: Array[Vector2i] = []
var banners: Array[Vector2i] = []
var visible_lamps: Dictionary = {}

func prepare(map: Dictionary) -> void:
	var key := str(map.get("rows", [])) + str(map.get("floor", 1))
	if key == layout_key: return
	layout_key = key
	lamps.clear()
	banners.clear()
	for y in range(0, 10):
		for x in range(1, 10):
			var cell := Vector2i(x, y)
			if not wall(map, cell) or wall(map, cell + Vector2i.DOWN): continue
			# Never place props in a passage. Thin south-facing walls become readable facades.
			if (x + y * 3) % 5 == 1:
				lamps.append(cell)
			elif (x * 3 + y) % 13 == 4:
				banners.append(cell)
	if lamps.is_empty():
		for y in range(0, 10):
			for x in range(1, 10):
				if wall(map, Vector2i(x,y)) and not wall(map, Vector2i(x,y+1)):
					lamps.append(Vector2i(x,y))
					_cache_lighting(map)
					return
	_cache_lighting(map)

func _cache_lighting(map: Dictionary) -> void:
	visible_lamps.clear()
	for y in 11:
		for x in 11:
			var cell := Vector2i(x,y)
			if wall(map,cell): continue
			var sources: Array[Vector2i] = []
			for source in lamps:
				if _light_visible(map,source,cell): sources.append(source)
			visible_lamps[cell] = sources

static func wall(map: Dictionary, cell: Vector2i) -> bool:
	return cell.x < 0 or cell.y < 0 or cell.x >= 11 or cell.y >= 11 or str(map.rows[cell.y]).substr(cell.x, 1) == "#"

func draw(board: CanvasItem, map: Dictionary, origin: Vector2, tile: float, seconds: float, reduced: bool) -> void:
	prepare(map)
	for y in 11:
		for x in 11:
			var cell := Vector2i(x,y)
			var rect := Rect2(origin + Vector2(cell)*tile, Vector2.ONE*tile)
			if wall(map,cell):
				Masonry.edges(board,map,cell,rect)
			else:
				_floor_depth(board,map,cell,rect)
				_floor_light(board,map,cell,rect,seconds,reduced)
	for cell in banners:
		var texture := Art.environment("banner")
		if texture != null:
			var pos := origin+(Vector2(cell)+Vector2(.5,.57))*tile
			board.draw_texture_rect(texture,Rect2(pos-Vector2(.27,.30)*tile,Vector2(.54,.6)*tile),false,Color("c1c8bb"))
	for cell in lamps:
		var pos := origin+(Vector2(cell)+Vector2(.5,.62))*tile
		var texture := Art.environment("torch")
		# The metal wall bracket and warm stone reflection ground the existing torch art.
		board.draw_line(pos+Vector2(0,.04)*tile,pos+Vector2(0,.27)*tile,Color("111c24"),maxf(2,tile*.08),true)
		if texture != null:
			board.draw_texture_rect(texture,Rect2(pos-Vector2(.27,.28)*tile,Vector2.ONE*tile*.54),false)
		var flame := pos+Vector2(0,-.075)*tile
		board.draw_circle(flame,maxf(1,tile*.025),Color("ffe0a0"))
	# A narrow continuous boundary separates the board from the surrounding UI void.
	board.draw_rect(Rect2(origin,Vector2.ONE*tile*11),Color(.40,.49,.52,.4),false,1)

func _floor_depth(board: CanvasItem, map: Dictionary, cell: Vector2i, r: Rect2) -> void:
	var d := r.size.x*.24
	var dark := Color(.02,.035,.055,.48)
	var clear := Color(.02,.035,.055,0)
	if wall(map,cell+Vector2i.UP):
		_quad(board,PackedVector2Array([r.position,r.position+Vector2(r.size.x,0),r.position+Vector2(r.size.x,d),r.position+Vector2(0,d)]),PackedColorArray([dark,dark,clear,clear]))
	if wall(map,cell+Vector2i.LEFT):
		_quad(board,PackedVector2Array([r.position,r.position+Vector2(d,0),r.position+Vector2(d,r.size.y),r.position+Vector2(0,r.size.y)]),PackedColorArray([dark,clear,clear,dark]))
	if wall(map,cell+Vector2i.RIGHT):
		_quad(board,PackedVector2Array([r.position+Vector2(r.size.x-d,0),r.position+Vector2(r.size.x,0),r.end,r.end-Vector2(d,0)]),PackedColorArray([clear,dark,dark,clear]))
	if wall(map,cell+Vector2i.DOWN):
		board.draw_line(r.position+Vector2(0,r.size.y-1),r.end-Vector2(0,1),Color(.02,.04,.06,.30),maxf(1,r.size.x*.045))

func _floor_light(board: CanvasItem, map: Dictionary, cell: Vector2i, r: Rect2, seconds: float, reduced: bool) -> void:
	var points := PackedVector2Array([r.position,r.position+Vector2(r.size.x,0),r.end,r.position+Vector2(0,r.size.y)])
	var colors := PackedColorArray()
	for offset in [Vector2.ZERO,Vector2.RIGHT,Vector2.ONE,Vector2.DOWN]:
		var power := 0.0
		for source: Vector2i in visible_lamps.get(cell, []):
			var delta: Vector2 = Vector2(cell)+offset-(Vector2(source)+Vector2(.5,1.0))
			var flicker := 1.0 if reduced else 1.0+sin(seconds*2.8+source.x)*.035+sin(seconds*4.7+source.y)*.02
			power = maxf(power,maxf(0,1.0-delta.length()/2.35)*.27*flicker)
		colors.append(Color(.95,.65,.29,power))
	_quad(board,points,colors)

static func _light_visible(map: Dictionary, source: Vector2i, cell: Vector2i) -> bool:
	var start := Vector2(source)+Vector2(.5,1.02)
	var end := Vector2(cell)+Vector2.ONE*.5
	if start.distance_to(end) > 3.1: return false
	for step in range(1,13):
		if wall(map,Vector2i(start.lerp(end,float(step)/12.0).floor())): return false
	return true

static func _quad(board: CanvasItem, points: PackedVector2Array, colors: PackedColorArray) -> void:
	board.draw_polygon(points,colors)

static func entity_foundation(board: CanvasItem, entity: Dictionary, center: Vector2, tile: float) -> void:
	var kind := str(entity.get("type", ""))
	if kind == "door": Masonry.door_frame(board,center,tile)
	if kind in ["door", "up", "down", "summit", "camp"]:
		# Shallow plinth, side bevels and foot shadow; original center artwork stays intact.
		var base := Rect2(center+Vector2(-.46,.28)*tile,Vector2(.92,.18)*tile)
		board.draw_rect(base,Color(.015,.025,.04,.65))
		board.draw_line(base.position,base.position+Vector2(base.size.x,0),Color("7b858b"),maxf(1,tile*.025))
	elif entity.has("ruin_id") or (kind == "enemy" and str(entity.get("enemy_id","")) in ["minotaur","golem"]):
		var ruin := entity.has("ruin_id")
		var tint := Color("75b8b0") if ruin else Color("c39b61")
		tint.a = .34
		board.draw_set_transform(center+Vector2(0,tile*.24),0,Vector2(1,.55))
		board.draw_circle(Vector2.ZERO,tile*.46,Color(.025,.04,.05,.45))
		board.draw_arc(Vector2.ZERO,tile*.41,0,TAU,32,tint,maxf(1,tile*.02),true)
		board.draw_arc(Vector2.ZERO,tile*.32,.2,PI-.2,16,tint,maxf(1,tile*.012),true)
		board.draw_set_transform(Vector2.ZERO)

static func gateway(board: CanvasItem, kind: String) -> void:
	# Original generated painting; imported at 256px, rendered inside one 44px cell.
	board.draw_texture_rect(GATEWAY,Rect2(-22,-22,44,44),false,Color("ece2cf") if kind == "camp" else Color.WHITE)

