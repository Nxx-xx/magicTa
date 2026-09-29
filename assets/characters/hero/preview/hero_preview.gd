extends Control
## Isolated art preview. Never loads game state or save modules.
const FRAMES = preload("res://assets/characters/hero/hero_idle.tres")
const FONT = preload("res://assets/fonts/ui_font.tres")
const BASE := "res://assets/characters/hero/"
const DIRS := ["down", "left", "up", "right"]
const NAMES := ["下 / DOWN", "左 / LEFT", "上 / UP", "右 / RIGHT"]
var draft: Array[Texture2D] = []
var sprites: Array[AnimatedSprite2D] = []
var show_draft := false
var paused := false
var elapsed := 0.0
var phase := 0

func _ready() -> void:
	get_window().content_scale_mode = Window.CONTENT_SCALE_MODE_DISABLED
	get_window().content_scale_size = Vector2i.ZERO
	get_window().size = Vector2i(1060, 900)
	get_window().title = "塔境 · 主角素材独立预览"
	texture_filter = CanvasItem.TEXTURE_FILTER_LINEAR
	for i in 4:
		var actor := AnimatedSprite2D.new()
		actor.sprite_frames = FRAMES
		actor.centered = false
		actor.offset = Vector2(-64, -116)
		actor.position = Vector2(145 + i * 255, 312)
		actor.scale = Vector2.ONE * 1.8
		actor.play("idle_" + DIRS[i])
		add_child(actor)
		sprites.append(actor)
		for f in 4:
			# QA-only drafts deliberately bypass the importer and stay under .gdignore.
			var img := Image.load_from_file(BASE + "reports/draft_frames/%s_%d.png" % [DIRS[i], f])
			draft.append(ImageTexture.create_from_image(img))
	if OS.get_cmdline_user_args().has("--capture"):
		_capture_all.call_deferred()

func _process(delta: float) -> void:
	if not paused:
		elapsed += delta
		phase = int(elapsed * 6.0) % 4
	queue_redraw()

func _unhandled_key_input(event: InputEvent) -> void:
	if not event.is_pressed() or event.is_echo(): return
	if event.keycode == KEY_1: show_draft = false
	if event.keycode == KEY_2: show_draft = true
	if event.keycode == KEY_SPACE: paused = not paused
	if event.keycode == KEY_RIGHT:
		paused = true
		phase = (phase + 1) % 4
	for actor in sprites: actor.visible = not show_draft
	queue_redraw()

func _label(pos: Vector2, value: String, size_px: int = 18, tint: Color = Color("d9e4e6")) -> void:
	draw_string(FONT, pos, value, HORIZONTAL_ALIGNMENT_LEFT, -1, size_px, tint)

func _checker(rect: Rect2, light: bool = false) -> void:
	for y in range(0, int(rect.size.y), 12):
		for x in range(0, int(rect.size.x), 12):
			var even := (x / 12 + y / 12) % 2 == 0
			var color := Color("d7d6cd") if even else Color("f4f1e7")
			if not light: color = Color("22313b") if even else Color("2e3e49")
			draw_rect(Rect2(rect.position + Vector2(x,y), Vector2(mini(12,int(rect.size.x)-x),mini(12,int(rect.size.y)-y))), color)

func _tile(texture: Texture2D, at: Vector2, tile: float, light: bool) -> void:
	var color := Color("deddd2") if light else Color("14212d")
	draw_rect(Rect2(at, Vector2.ONE * tile), color)
	draw_rect(Rect2(at, Vector2.ONE * tile), Color("708c88"), false, 1)
	var anchor := at + Vector2(tile * 0.5, tile * 0.93)
	draw_texture_rect(texture, Rect2(anchor - Vector2(64,116) * tile / 128.0, Vector2.ONE * tile), false)

func _draw() -> void:
	draw_rect(Rect2(Vector2.ZERO, Vector2(1060,900)), Color("0e1823"))
	_label(Vector2(28,40), "塔境 / 主角素材 · " + ("行走草稿未通过" if show_draft else "四向静态可用"), 26, Color("e5c78e"))
	_label(Vector2(28,69), "1 静态验收   2 行走草稿   空格 暂停   → 逐帧    |    正式资源仅包含 idle", 16)
	if show_draft:
		_draw_draft()
		return
	for i in 4:
		var x := 28 + i * 255
		_label(Vector2(x,101), NAMES[i], 18)
		_checker(Rect2(x,114,230,216), i % 2 == 1)
		draw_line(Vector2(x+12,312),Vector2(x+218,312),Color("ddc487"),1)
		draw_line(Vector2(x+117,300),Vector2(x+117,325),Color("ddc487"),1)
	_label(Vector2(28,365), "脚底锚点 (64,116) / 128×128 · 四向独立绘制，无镜像 · 暖光仅来自角色左手提灯", 17)
	_label(Vector2(28,402), "实际网格尺寸 / 深色与浅色边缘检查（无放大）", 20, Color("e5c78e"))
	var sizes := [46.91, 32.73, 26.18]
	var descriptions := ["540×960 → 516 / 11", "384×720 → 360 / 11", "360×640 → 288 / 11"]
	for r in 3:
		var y := 443 + r * 90
		_label(Vector2(28,y+20), "%.2f px" % sizes[r], 18)
		_label(Vector2(28,y+43), descriptions[r], 14)
		for i in 4:
			var tex: Texture2D = FRAMES.get_frame_texture("idle_" + DIRS[i],0)
			_tile(tex,Vector2(280+i*185,y),sizes[r],false)
			_tile(tex,Vector2(345+i*185,y),sizes[r],true)
	_label(Vector2(28,766), "验收范围：透明边缘、方向与左右手、统一脚底、47 / 33 / 26 px 小尺寸辨识。", 17)
	_label(Vector2(28,800), "行走：两轮生成仍重复领先腿；不作为正式循环，不随 idle 资源发布。", 17, Color("edb999"))
	_label(Vector2(28,842), "独立预览不读取游戏存档，不改变主场景或玩法。线性过滤；纹理留有透明边距。", 16)

func _draw_draft() -> void:
	_label(Vector2(28,102), "未通过：领先腿重复 / 接触与经过姿势不完整 / 侧面手臂有重叠 · 6 FPS 仅供审查", 18, Color("edb999"))
	for row in 4:
		var y := 130 + row * 180
		_label(Vector2(24,y+28), NAMES[row],16)
		for col in 4:
			var x := 170 + col * 160
			_checker(Rect2(x,y,146,148))
			draw_texture_rect(draft[row*4+col],Rect2(x,y,146,146),false)
			_label(Vector2(x,y+165),"帧 %d" % col,14)
			if phase == col: draw_rect(Rect2(x,y,146,148),Color("e7c482"),false,2)
		_checker(Rect2(842,y,174,148),true)
		draw_texture_rect(draft[row*4+phase],Rect2(856,y,146,146),false)
		_label(Vector2(842,y+165),"草稿播放 / %d" % phase,14)

func _capture_all() -> void:
	if not OS.get_user_data_dir().replace("\\", "/").contains("/build/verification/hero/"):
		push_error("Capture requires isolated APPDATA and LOCALAPPDATA")
		get_tree().quit(2)
		return
	paused = true
	print("HERO_PREVIEW user_data=", OS.get_user_data_dir())
	await get_tree().process_frame
	await RenderingServer.frame_post_draw
	var result := get_viewport().get_texture().get_image().save_png(BASE + "reports/idle_godot.png")
	assert(result == OK)
	show_draft = true
	for actor in sprites: actor.hide()
	for f in 4:
		phase = f
		queue_redraw()
		await get_tree().process_frame
		await RenderingServer.frame_post_draw
		assert(get_viewport().get_texture().get_image().save_png(BASE + "reports/walk_rejected_phase_%d.png" % f) == OK)
	print("HERO_PREVIEW captures=5 OK")
	get_tree().quit()
