extends TextureRect
## Shared painted close-up. Pure presentation: no input, timers, RNG, or save writes.
const LANTERN = preload("res://scripts/ui/npc_portrait.gdshader")
const MERCHANT = preload("res://assets/characters/candlelight_merchant/textures/conversation.png")
var settings: RefCounted
var seconds := 0.0
var reduced := true

static func merchant(preferences: RefCounted, compact: bool = false) -> TextureRect:
	var portrait = load("res://scripts/ui/npc_portrait.gd").new()
	portrait.name = "MerchantPortrait"
	portrait.texture = MERCHANT
	portrait.configure(preferences, Vector2(80,68) if compact else Vector2(96,88), Vector2(.155,.635), false)
	return portrait

func configure(preferences: RefCounted, extent: Vector2, lamp: Vector2, death: bool) -> void:
	settings = preferences
	expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
	custom_minimum_size = extent
	size_flags_vertical = Control.SIZE_SHRINK_CENTER
	mouse_filter = Control.MOUSE_FILTER_IGNORE
	texture_filter = CanvasItem.TEXTURE_FILTER_LINEAR
	var paint := ShaderMaterial.new()
	paint.shader = LANTERN
	paint.set_shader_parameter("lamp",lamp)
	paint.set_shader_parameter("spirit",death)
	material = paint
	_sync_motion(0.0)

func _sync_motion(delta: float) -> void:
	reduced = settings == null or settings.reduce_motion
	seconds = 0.0 if reduced else fmod(seconds+delta,TAU*10.0)
	material.set_shader_parameter("seconds",seconds)
	material.set_shader_parameter("motion",not reduced)

func _process(delta: float) -> void:
	if is_visible_in_tree(): _sync_motion(delta)
