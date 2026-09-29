extends Control
## Independent art gallery: never instantiates gameplay or reads/writes player saves.
const ROOT := "res://assets/monsters/v01/"
const FONT = preload("res://assets/fonts/ui_font.tres")
const IDS := ["slime", "skeleton", "bat", "sentinel", "knight", "warlock"]
const NAMES := ["苔原史莱姆", "锈剑骷髅", "赤翼蝠", "石壳卫兵", "空心骑士", "余烬术士"]
var textures: Dictionary = {}
var floor_texture: Texture2D
var light := false

func _ready() -> void:
	get_window().content_scale_mode = Window.CONTENT_SCALE_MODE_DISABLED
	get_window().content_scale_size = Vector2i.ZERO
	get_window().size = Vector2i(1440, 1000)
	texture_filter = CanvasItem.TEXTURE_FILTER_LINEAR_WITH_MIPMAPS
	light = "--light" in OS.get_cmdline_user_args()
	for id in IDS:
		textures[id] = load(ROOT + "textures/" + id + ".png")
		assert(textures[id] != null and textures[id].get_size() == Vector2(256, 256))
	var floor_path := "res://assets/environment/tower_v01/textures/floor_0.png"
	if ResourceLoader.exists(floor_path): floor_texture = load(floor_path)
	queue_redraw()
	if "--capture" in OS.get_cmdline_user_args(): _capture.call_deferred()

func _capture() -> void:
	await get_tree().process_frame
	await get_tree().process_frame
	await RenderingServer.frame_post_draw
	var path := ROOT + "previews/" + ("gallery_light.png" if light else "gallery_dark.png")
	assert(get_viewport().get_texture().get_image().save_png(path) == OK)
	print("MONSTER_RENDER_OK ", path, " six imported textures; 256/44/28px; floor=", floor_texture != null)
	get_tree().quit()

func _input(event: InputEvent) -> void:
	if event is InputEventKey and event.pressed and event.keycode == KEY_SPACE:
		light = not light
		queue_redraw()

func _text(at: Vector2, value: String, px: int = 18, tint: Color = Color("b6c8cc")) -> void:
	draw_string(FONT, at, value, HORIZONTAL_ALIGNMENT_LEFT, -1, px, tint)

func _tile(at: Vector2, px: float, id: String, use_floor: bool = true) -> void:
	var rect := Rect2(at, Vector2.ONE * px)
	draw_rect(rect, Color("14212d"))
	if use_floor and floor_texture: draw_texture_rect(floor_texture, rect, false)
	draw_rect(rect, Color("63727a"), false, 1)
	draw_texture_rect(textures[id], rect, false)

func _draw() -> void:
	draw_rect(Rect2(0, 0, 1440, 1000), Color("101a24"))
	_text(Vector2(34, 46), "塔境  /  普通怪物图鉴", 30, Color("e5ca94"))
	_text(Vector2(34, 78), "独立素材预览 · 统一 256×256 透明画布 · 暖色左上光 · 微俯视 · 空格切换深浅底", 18)
	for i in 6:
		var col: int = i % 3
		var row: int = i / 3
		var p := Vector2(28 + col * 470, 101 + row * 408)
		draw_rect(Rect2(p, Vector2(454, 391)), Color("1b2935"))
		_text(p + Vector2(16, 30), "%02d  %s" % [i + 1, NAMES[i]], 23, Color("e5ca94"))
		_text(p + Vector2(16, 54), IDS[i] + ("  /  素材储备" if IDS[i] == "warlock" else "  /  当前随机池"), 15)
		var art_at := p + Vector2(16, 66)
		var bg := Color("eadfca") if light else Color("0b121c")
		draw_rect(Rect2(art_at, Vector2(256, 256)), bg)
		draw_texture_rect(textures[IDS[i]], Rect2(art_at, Vector2(256, 256)), false)
		# Second backdrop makes halos and unintended opaque backgrounds obvious.
		draw_rect(Rect2(p + Vector2(292, 68), Vector2(142, 142)), Color("101924") if light else Color("e9e0cf"))
		draw_texture_rect(textures[IDS[i]], Rect2(p + Vector2(293, 69), Vector2(140, 140)), false)
		_text(p + Vector2(291, 237), "44 px", 15)
		_tile(p + Vector2(292, 250), 44, IDS[i])
		_text(p + Vector2(364, 237), "28 px", 15)
		_tile(p + Vector2(371, 258), 28, IDS[i])
		_text(p + Vector2(16, 345), "256 px  /  原生尺寸细节与透明边缘", 15)
		_text(p + Vector2(16, 374), "地面锚点 (128,224)" + (" · 悬浮上移 34 px" if i == 2 else ""), 15)
	_text(Vector2(34, 943), "540×960", 17, Color("e5ca94"))
	_text(Vector2(34, 969), "格宽 46.91 px", 15)
	for i in 6: _tile(Vector2(172 + i * (516.0 / 11.0), 920), 516.0 / 11.0, IDS[i])
	_text(Vector2(512, 943), "360×640", 17, Color("e5ca94"))
	_text(Vector2(512, 969), "格宽 26.18 px", 15)
	for i in 6: _tile(Vector2(668 + i * (288.0 / 11.0), 930), 288.0 / 11.0, IDS[i])
	_text(Vector2(913, 943), "静态六种 / 无邻格遮挡", 18)
	_text(Vector2(913, 970), "美术验证场景，尚未接入主游戏", 16)
