extends Control
## Painted v02 backdrop, editable contact shadows and committed-cue feedback layers.
const FONT = preload("res://assets/ui/visual_v01/body_font.tres")
const BACKGROUNDS := {
	"stone_hall": preload("res://assets/environment/battle_v02/textures/stone_hall.png"),
	"moonlit_ruins": preload("res://assets/environment/battle_v02/textures/moonlit_ruins.png"),
	"boss_sanctum": preload("res://assets/environment/battle_v02/textures/boss_sanctum.png")
}
@export_enum("stone_hall", "moonlit_ruins", "boss_sanctum") var environment_kind := "stone_hall":
	set(value):
		environment_kind = value if BACKGROUNDS.has(value) else "stone_hall"
		queue_redraw()
@export var show_contact_shadows := true
const GOLD := Color("e9c17e")
const TEAL := Color("8bbdbb")
var foreground := false
var timeline: Array = []
var seconds := 0.0
var reduced := false
var finished := false
var hero_foot := Vector2.ZERO
var enemy_foot := Vector2.ZERO
var enemy_number_height := .49
var _last_size := Vector2(-1,-1)

func _ready() -> void:
	mouse_filter = Control.MOUSE_FILTER_IGNORE
	clip_contents = true

func sample(cues: Array, time: float, quiet: bool, settled: bool) -> void:
	timeline = cues
	seconds = time
	reduced = quiet
	finished = settled
	if foreground or _last_size != size:
		_last_size = size
		queue_redraw()

static func _ellipse(canvas: CanvasItem, center: Vector2, radii: Vector2, tint: Color) -> void:
	var points := PackedVector2Array()
	for i in 48: points.append(center + Vector2(cos(i*TAU/48),sin(i*TAU/48))*radii)
	canvas.draw_colored_polygon(points,tint)

func _draw() -> void:
	if size.x < 1 or size.y < 1: return
	if foreground:
		_draw_feedback()
		return
	draw_environment(self,size,hero_foot,enemy_foot,environment_kind,show_contact_shadows)

static func select_environment(enemy_id: String, rank: String = "normal", requested: String = "") -> String:
	# Optional presentation-only override; old reports and saves need no new fields.
	if BACKGROUNDS.has(requested): return requested
	if rank == "boss" or enemy_id in ["minotaur", "golem"]: return "boss_sanctum"
	if enemy_id in ["skeleton", "bat", "warlock", "p3_ember_channeler"]: return "moonlit_ruins"
	return "stone_hall"

static func draw_environment(canvas: CanvasItem, bounds: Vector2, hero: Vector2, foe: Vector2, kind: String = "stone_hall", shadows: bool = true) -> void:
	var texture: Texture2D = BACKGROUNDS.get(kind,BACKGROUNDS.stone_hall)
	# Cover without stretching architecture. Anchor the crop to the actor floor.
	var source_size := texture.get_size()
	var scale_factor := maxf(bounds.x/source_size.x,bounds.y/source_size.y)
	var crop_size := bounds/scale_factor
	var crop_origin := Vector2((source_size.x-crop_size.x)*.5,(source_size.y-crop_size.y)*.78)
	canvas.draw_texture_rect_region(texture,Rect2(Vector2.ZERO,bounds),Rect2(crop_origin,crop_size))
	# Subtle edge shade and rim are editable independently of the painting.
	for edge in 8:
		var alpha := .014 * (1.0-edge/8.0)
		canvas.draw_rect(Rect2(edge*2,0,2,bounds.y),Color(0.02,0.04,0.06,alpha))
		canvas.draw_rect(Rect2(bounds.x-(edge+1)*2,0,2,bounds.y),Color(0.02,0.04,0.06,alpha))
	canvas.draw_line(Vector2(0,1),Vector2(bounds.x,1),Color(.55,.65,.65,.28),1)
	canvas.draw_line(Vector2(0,bounds.y-1),Vector2(bounds.x,bounds.y-1),Color(.55,.65,.65,.20),1)
	if shadows:
		for foot in [hero,foe]:
			for ring in range(7,0,-1):
				_ellipse(canvas,foot+Vector2(0,2),Vector2(bounds.x*.010*ring,1+ring*1.25),Color(.015,.025,.03,.065))

func _number(copy: String, point: Vector2, tint: Color, pixels: int) -> void:
	var width := FONT.get_string_size(copy,HORIZONTAL_ALIGNMENT_LEFT,-1,pixels).x
	point.x -= width*.5
	draw_string_outline(FONT,point,copy,HORIZONTAL_ALIGNMENT_LEFT,-1,pixels,4,Color("0c151c"))
	draw_string(FONT,point,copy,HORIZONTAL_ALIGNMENT_LEFT,-1,pixels,tint)

func _draw_feedback() -> void:
	if reduced or finished: return
	var w := size.x
	# Select the latest numeric hit per recipient so short rounds cannot stack text.
	var latest := {}
	for cue in timeline:
		var age := seconds-float(cue.at)
		if age < 0 or age > .44: continue
		var kind := str(cue.kind)
		var target := hero_foot if kind in ["counter","guard"] else enemy_foot
		var contact := target-Vector2(0,w*.26)
		var fade := 1.0-age/.44
		if kind in ["attack","counter","retaliation"]:
			latest["hero" if kind == "counter" else "enemy"] = cue
			if int(cue.amount) > 0 and age < .18:
				var impact := 1.0-age/.18
				var tint := GOLD if kind != "counter" else Color("e7a28e")
				for ray in 7:
					var direction := Vector2.from_angle(ray*TAU/7+.3)
					draw_line(contact+direction*w*.012,contact+direction*w*(.028+.065*(1-impact)),Color(tint,impact),2,true)
				if kind == "attack":
					draw_line(contact+Vector2(-w*.10,w*.07),contact+Vector2(w*.05,-w*.07),Color("fff0c5")*Color(1,1,1,impact),2,true)
			if int(cue.get("enemy_hp",1)) == 0:
				for mote in 9:
					var spread := (mote-4)*w*.012*(1+age*4)
					draw_circle(target+Vector2(spread,-sin(mote+1.0)*age*w*.055),1+mote%2,Color(.68,.68,.56,fade*.5))
		if kind == "guard" and int(cue.amount) > 0:
			draw_arc(contact,w*.12,-1.5,1.5,24,Color(GOLD,fade*.7),2,true)
		for effect in cue.get("effects",[]):
			var origin := hero_foot if effect.id == "counter_guard" else enemy_foot
			if int(effect.get("amount",0)) > 0: _mechanism(str(effect.id),origin-Vector2(0,w*.26),origin,age,fade)
	for side in latest:
		var cue: Dictionary = latest[side]
		var age := seconds-float(cue.at)
		var foot := hero_foot if side == "hero" else enemy_foot
		var tint := Color("f1b7a5") if side == "hero" else Color("fff0c9")
		var copy := "抵挡" if int(cue.amount) == 0 else "−%d"%int(cue.amount)
		_number(copy,foot-Vector2(0,w*(.58 if side == "hero" else enemy_number_height)+age*w*.035),Color(tint,minf(1,(.44-age)*10)),clampi(int(w*.062),20,32))

func _mechanism(id: String, point: Vector2, foot: Vector2, age: float, fade: float) -> void:
	var w := size.x
	match id:
		"p3_shield","counter_guard":
			var p := point+Vector2(-w*.065,0)
			var shield := PackedVector2Array([p+Vector2(-w*.04,-w*.075),p+Vector2(w*.04,-w*.075),p+Vector2(w*.035,w*.025),p+Vector2(0,w*.06),p+Vector2(-w*.035,w*.025),p+Vector2(-w*.04,-w*.075)])
			draw_polyline(shield,Color(TEAL,fade),2,true)
		"stone_armor":
			for i in 5:
				var p := foot+Vector2((i-2)*w*.035,-w*.03-age*w*.04)
				draw_rect(Rect2(p,Vector2(w*.024,w*.016)),Color(TEAL,fade*.7),false,1)
		"rage","p3_ember":
			for i in 5:
				var p := foot+Vector2((i-2)*w*.032,-w*.04)
				draw_polyline(PackedVector2Array([p,p+Vector2(-w*.008,-w*(.02+age*.08)),p+Vector2(w*.005,-w*(.04+age*.1))]),Color(GOLD,fade*.8),2,true)
		"p3_ambush":
			for side in [-1,1]:
				var p := point+Vector2(side*w*(.10-age*.1),0)
				draw_polyline(PackedVector2Array([p+Vector2(side*w*.02,-w*.045),p,p+Vector2(side*w*.02,w*.045)]),Color(GOLD,fade),2,true)
		"retaliation":
			draw_arc(point,w*(.025+age*.09),0,TAU,24,Color(TEAL,fade),2,true)
		"first_hit_bonus","periodic_hit_bonus":
			draw_arc(point,w*.055,-1.7,.8,20,Color(GOLD,fade),2,true)
