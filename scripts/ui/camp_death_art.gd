extends RefCounted
## Transparent NPC sprite; placement stays independent of the woodland background.
const TEXTURE = preload("res://assets/characters/camp_death/death.png")
const ANCHOR := Vector2(.44, .87)
const Portrait = preload("res://scripts/ui/npc_portrait.gd")
static var _poses: Dictionary = {}

static func portrait(preferences: RefCounted) -> TextureRect:
	var view = Portrait.new()
	view.name = "DeathPortrait"
	var close := AtlasTexture.new()
	close.atlas = TEXTURE
	# Hood, face, clasp, scythe blade, and green lantern remain in the composition.
	close.region = Rect2(Vector2(.225,.14)*TEXTURE.get_size(),Vector2(.67,.555)*TEXTURE.get_size())
	view.texture = close
	view.configure(preferences,Vector2(88,80),Vector2(.70,.61),true)
	return view

static func draw(canvas: CanvasItem, area: Rect2, seconds: float, reduced: bool) -> void:
	# An indexed mesh moves existing painted pixels; no duplicate frame textures.
	# Quantized 48-pose cache is bounded and shared by all camp views.
	var frame := 0 if reduced else int(fposmod(seconds,TAU/1.5)/(TAU/1.5)*48.0)
	if not _poses.has(frame): _poses[frame] = _mesh(float(frame)/48.0*TAU)
	canvas.draw_set_transform(area.position,0,area.size)
	canvas.draw_mesh(_poses[frame],TEXTURE)
	canvas.draw_set_transform(Vector2.ZERO)

static func _mesh(phase: float) -> ArrayMesh:
	var vertices := PackedVector3Array()
	var uv := PackedVector2Array()
	var colors := PackedColorArray()
	var indices := PackedInt32Array()
	for y in 17:
		for x in 17:
			var p := Vector2(float(x)/16.0,float(y)/16.0)
			var upper := clampf((.88-p.y)/.72,0.0,1.0)
			var shift := Vector2(sin(phase)*.0025*upper,-sin(phase)*.0035*upper)
			# A second, slower cape fold wave never changes the foot anchor or hitbox.
			shift.x += sin(phase+p.y*5.0)*.0015*sin(p.y*PI)*sin(phase)
			vertices.append(Vector3(p.x+shift.x,p.y+shift.y,0))
			uv.append(p)
			var lamp := exp(-p.distance_squared_to(Vector2(.70,.61))*230.0)
			var pulse := .06*sin(phase*2.0)+.025*sin(phase*5.0)
			colors.append(Color("cbdedc")+Color(.4,.7,.25,0)*lamp*pulse)
	for y in 16:
		for x in 16:
			var a := y*17+x
			indices.append_array(PackedInt32Array([a,a+1,a+18,a,a+18,a+17]))
	var arrays := []
	arrays.resize(Mesh.ARRAY_MAX)
	arrays[Mesh.ARRAY_VERTEX] = vertices
	arrays[Mesh.ARRAY_TEX_UV] = uv
	arrays[Mesh.ARRAY_COLOR] = colors
	arrays[Mesh.ARRAY_INDEX] = indices
	var mesh := ArrayMesh.new()
	mesh.add_surface_from_arrays(Mesh.PRIMITIVE_TRIANGLES,arrays)
	return mesh
