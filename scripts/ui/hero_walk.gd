extends MeshInstance2D
## Deform the approved four-facing sprite at runtime; keep source textures intact.
const COLUMNS := 12
const ROWS := 16

func _ready() -> void:
	var vertices := PackedVector3Array()
	var uv := PackedVector2Array()
	var indices := PackedInt32Array()
	for y in ROWS + 1:
		for x in COLUMNS + 1:
			var point := Vector2(float(x) / COLUMNS, float(y) / ROWS)
			vertices.append(Vector3(point.x - 0.5, point.y - 0.47625, 0))
			uv.append(point)
	for y in ROWS:
		for x in COLUMNS:
			var start := y * (COLUMNS + 1) + x
			indices.append_array(PackedInt32Array([start, start + 1, start + COLUMNS + 1, start + 1, start + COLUMNS + 2, start + COLUMNS + 1]))
	var arrays := []
	arrays.resize(Mesh.ARRAY_MAX)
	arrays[Mesh.ARRAY_VERTEX] = vertices
	arrays[Mesh.ARRAY_TEX_UV] = uv
	arrays[Mesh.ARRAY_INDEX] = indices
	var geometry := ArrayMesh.new()
	geometry.add_surface_from_arrays(Mesh.PRIMITIVE_TRIANGLES, arrays)
	mesh = geometry
	var shader := Shader.new()
	shader.code = """
shader_type canvas_item;
uniform float phase = 0.0;
uniform float walking = 0.0;
uniform float profile = 0.0;
void vertex() {
    float beat = sin(phase);
    float lower = smoothstep(0.55, 0.90, UV.y);
    float leg = smoothstep(0.44, 0.56, UV.x) * 2.0 - 1.0;
    float swing = beat * leg;
    // Alternate boots, with a stronger fore/aft stride in the side views.
    VERTEX.x += walking * lower * swing * mix(0.018, 0.055, abs(profile));
    VERTEX.y += walking * lower * (swing * 0.025 - max(0.0, swing) * 0.025);
    // Keep the head stable, let the cape and carried equipment follow the gait.
    float body = 1.0 - lower;
    VERTEX.y -= walking * abs(beat) * body * 0.018;
    VERTEX.x += walking * beat * sin(UV.y * 3.14159) * body * 0.012;
}
"""
	var shader_material := ShaderMaterial.new()
	shader_material.shader = shader
	material = shader_material
	visible = false

func pose(sprite: Texture2D, facing: String, phase: float, walking: bool, alive: bool) -> void:
	texture = sprite
	modulate = Color.WHITE if alive else Color("897b85")
	material.set_shader_parameter("phase", phase)
	material.set_shader_parameter("walking", 1.0 if walking else 0.0)
	material.set_shader_parameter("profile", 1.0 if facing in ["left", "right"] else 0.0)
