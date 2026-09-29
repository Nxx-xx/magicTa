extends Control
## Art-only presentation; never instantiates MapEngine or accesses player saves.
const ROOT = "res://assets/environment/tower_v01/"
const FONT = preload("res://assets/fonts/ui_font.tres")
const Generator = preload("res://scripts/core/map_generator.gd")
const MonsterArt = preload("res://scripts/ui/monster_art.gd")
var textures: Dictionary = {}
var floor_data: Dictionary = {}
var compact := false
var phone := false
var gallery := false
var doors_open := false
var hero_texture: Texture2D
var selected := Vector2i(-1, -1)
var board_rect := Rect2()
var snapshot: Dictionary = {}

func _ready() -> void:
	get_window().content_scale_mode = Window.CONTENT_SCALE_MODE_DISABLED
	get_window().content_scale_size = Vector2i.ZERO
	compact = "--small" in OS.get_cmdline_user_args()
	phone = "--phone" in OS.get_cmdline_user_args()
	doors_open = "--open" in OS.get_cmdline_user_args()
	gallery = "--gallery" in OS.get_cmdline_user_args()
	get_window().size = Vector2i(360, 640) if compact else (Vector2i(540, 960) if phone else Vector2i(1280, 960))
	texture_filter = CanvasItem.TEXTURE_FILTER_LINEAR
	var manifest: Dictionary = JSON.parse_string(FileAccess.get_file_as_string(ROOT + "asset_manifest.json"))
	for id in manifest:
		textures[id] = load(ROOT + manifest[id].file)
	var generator = Generator.new()
	floor_data = generator.generate("MAP-ART-V01", 1, "entrance")
	assert(not floor_data.is_empty(), generator.last_error)
	snapshot = floor_data.duplicate(true)
	var hero_path := "res://assets/characters/hero/textures/idle_down.png"
	if ResourceLoader.exists(hero_path):
		hero_texture = load(hero_path)
	# Existing entity drawing functions are reused read-only for non-environment content.
	resized.connect(queue_redraw)
	queue_redraw()
	if "--capture" in OS.get_cmdline_user_args():
		_capture.call_deferred()

func _capture() -> void:
	await get_tree().process_frame
	await get_tree().process_frame
	await RenderingServer.frame_post_draw
	var filename := "small_360x640.png" if compact else ("asset_qa_1280x960.png" if gallery else "map_1280x960.png")
	if phone: filename = "phone_540x960.png"
	if doors_open: filename = filename.replace(".png", "_open.png")
	var error := get_viewport().get_texture().get_image().save_png(ROOT + "previews/" + filename)
	assert(error == OK)
	FileAccess.open(ROOT + "layout_snapshot.json", FileAccess.WRITE).store_string(JSON.stringify(snapshot, "\t"))
	var walls := 0
	var entity_count := 0
	for y in 11:
		assert(str(floor_data.rows[y]).length() == 11)
		for x in 11:
			if _wall(Vector2i(x, y)):
				walls += 1
	for key in floor_data.entities:
		var xy := str(key).split(",")
		assert(not _wall(Vector2i(int(xy[0]), int(xy[1]))))
		entity_count += 1
	print("MAP_ART_RENDER_OK ", filename, " wall_cells=", walls, " entities=", entity_count, " board=", board_rect.size, " hero=", hero_texture != null)
	get_tree().quit()

func _input(event: InputEvent) -> void:
	if event is InputEventKey and event.pressed:
		if event.keycode == KEY_SPACE:
			doors_open = not doors_open
		if event.keycode == KEY_TAB:
			gallery = not gallery
		queue_redraw()
	if event is InputEventMouseButton and event.pressed and event.button_index == MOUSE_BUTTON_LEFT:
		if board_rect.has_point(event.position):
			selected = Vector2i((event.position - board_rect.position) / (board_rect.size.x / 11.0))
			queue_redraw()

func _text(p: Vector2, text: String, px: int = 18, color: Color = Color("b7c8cd")) -> void:
	draw_string(FONT, p, text, HORIZONTAL_ALIGNMENT_LEFT, -1, px, color)

func _sprite(id: String, rect: Rect2, tint: Color = Color.WHITE) -> void:
	draw_texture_rect(textures[id], rect, false, tint)

func _wall(cell: Vector2i) -> bool:
	return cell.x >= 0 and cell.x < 11 and cell.y >= 0 and cell.y < 11 and str(floor_data.rows[cell.y])[cell.x] == "#"

func _mask(cell: Vector2i) -> int:
	var value := 0
	for i in 4:
		if _wall(cell + [Vector2i.UP, Vector2i.RIGHT, Vector2i.DOWN, Vector2i.LEFT][i]):
			value |= 1 << i
	return value

func _board(p: Vector2, extent: float) -> void:
	board_rect = Rect2(p, Vector2.ONE * extent)
	var step := extent / 11.0
	draw_rect(board_rect.grow(5), Color("080f17"))
	draw_rect(board_rect.grow(4), Color("ac9363"), false, 1)
	for y in 11:
		for x in 11:
			var cell := Vector2i(x, y)
			var rect := Rect2(p + Vector2(cell) * step, Vector2.ONE * step)
			draw_rect(rect, Color("12222d"))
			if _wall(cell):
				_sprite("wall_%02d" % _mask(cell), rect)
			else:
				var variant := (x * 7 + y * 11) % 13
				var id := 2 if variant > 3 else variant
				_sprite("floor_%d" % id, rect, Color(0.64, 0.72, 0.78))
				draw_rect(rect, Color(0.07, 0.12, 0.16, 0.7), false, maxf(0.6, step / 90))
	# Decorative objects are confined to blocking cells, never replace playable entities.
	for spec in [[Vector2i(0, 3), "torch"], [Vector2i(10, 7), "torch"], [Vector2i(5, 0), "banner"]]:
		if _wall(spec[0]):
			var rect := Rect2(p + Vector2(spec[0]) * step, Vector2.ONE * step)
			_sprite(spec[1], rect.grow(-step * 0.1))
	for key in floor_data.entities:
		var xy := str(key).split(",")
		var cell := Vector2i(int(xy[0]), int(xy[1]))
		var e: Dictionary = floor_data.entities[key]
		var rect := Rect2(p + Vector2(cell) * step, Vector2.ONE * step)
		_entity(e, rect)
	var entry := Vector2i(int(floor_data.entry[0]), int(floor_data.entry[1]))
	var hero_rect := Rect2(p + Vector2(entry) * step, Vector2.ONE * step)
	if hero_texture:
		draw_texture_rect(hero_texture, hero_rect.grow(-step * 0.025), false)
	else:
		draw_circle(hero_rect.get_center(), step * 0.23, Color("74cbb5"))
	if selected.x >= 0:
		draw_rect(Rect2(p + Vector2(selected) * step, Vector2.ONE * step).grow(-1), Color("f4df9f"), false, 2)

func _entity(e: Dictionary, rect: Rect2) -> void:
	var id := ""
	match str(e.type):
		"door": id = "door_%s_%s" % [e.get("key_kind", "copper"), "open" if doors_open else "closed"]
		"key": id = "key_" + str(e.get("key_kind", "copper"))
		"chest", "choice": id = "chest"
		"potion": id = "potion"
		"gold": id = "coins"
		"up", "summit": id = "stairs_up"
		"down": id = "stairs_down"
		"camp": return
		"enemy":
			draw_set_transform(rect.get_center(), 0, Vector2.ONE * rect.size.x / 44.0)
			MonsterArt.draw(self, {"id": e.enemy_id}, e)
			draw_set_transform(Vector2.ZERO)
		_:
			# Semantic event/rest placeholders are explicitly marked and stay out of this art scope.
			draw_circle(rect.get_center(), rect.size.x * 0.29, Color("485267"))
			_text(rect.get_center() + Vector2(-rect.size.x * 0.19, rect.size.x * 0.17), "事" if e.type == "event" else "休", maxi(10, int(rect.size.x * 0.42)))
	if id != "":
		_sprite(id, rect)
		if e.type in ["key", "door"]:
			_badge(rect, str(e.get("key_kind", "copper")))
		if e.type in ["up", "down", "summit"]:
			_text(rect.position + Vector2(rect.size.x * 0.65, rect.size.y * 0.92), "↑" if e.type != "down" else "↓", maxi(10, int(rect.size.x * 0.3)), Color("b3ebd7"))

func _badge(rect: Rect2, kind: String) -> void:
	var radius := maxf(2.2, rect.size.x * 0.075)
	var p := rect.position + rect.size * Vector2(0.82, 0.8)
	var color: Color = {"copper": Color("df9369"), "silver": Color("d3e7f1"), "gold": Color("f3d274")}[kind]
	draw_circle(p, radius + 1.5, Color("101b25"))
	if kind == "copper":
		draw_arc(p, radius, 0, TAU, 16, color, 1.4, true)
	elif kind == "silver":
		draw_polyline(PackedVector2Array([p + Vector2(0,-radius), p + Vector2(radius,0), p + Vector2(0,radius), p + Vector2(-radius,0), p + Vector2(0,-radius)]), color, 1.3, true)
	else:
		draw_polyline(PackedVector2Array([p + Vector2(0,-radius), p + Vector2(radius,radius), p + Vector2(-radius,radius), p + Vector2(0,-radius)]), color, 1.3, true)

func _draw() -> void:
	if floor_data.is_empty(): return
	draw_rect(Rect2(Vector2.ZERO, size), Color("0c1620"))
	if compact:
		_text(Vector2(22, 36), "塔境 / 地图美术样板", 22, Color("e1c38a"))
		_text(Vector2(22, 62), "真实布局 · 非可玩关卡", 13)
		_text(Vector2(22, 96), "360 × 640  /  单格 26.18 px", 13, Color("7bc2b5"))
		_board(Vector2(36, 130), 288)
		_text(Vector2(24, 454), "铜 ○    银 ◇    金 △", 17, Color("e1c38a"))
		for i in 3:
			_sprite("key_" + ["copper", "silver", "gold"][i], Rect2(25 + i * 54, 468, 44, 44))
		_text(Vector2(24, 548), "怪物 / 事件沿用现有占位绘制", 13)
		_text(Vector2(24, 575), "空格：门开闭样态   ·   仅美术预览", 12)
		_text(Vector2(24, 610), "环境 V01   /   正交方格 · 独立资源", 12, Color("798e9b"))
		return
	if phone:
		_text(Vector2(24, 42), "塔境 / 地图美术样板", 28, Color("e1c38a"))
		_text(Vector2(24, 76), "540 × 960  /  单格 46.91 px  /  非可玩关卡", 16)
		_board(Vector2(12, 130), 516)
		_text(Vector2(24, 692), "铜 ○    银 ◇    金 △", 20, Color("e1c38a"))
		for i in 6:
			_sprite(["key_copper", "key_silver", "key_gold", "stairs_up", "stairs_down", "potion"][i], Rect2(20+i*84,720,72,72))
		_text(Vector2(24, 845), "固定种子 MAP-ART-V01 · 原始墙格与物件布局", 16)
		_text(Vector2(24, 880), "空格切换门样态 · 点击检查占格", 16)
		_text(Vector2(24, 920), "英雄只读复用；怪物、事件为现有占位绘制。", 15)
		return
	_text(Vector2(40, 58), "塔境 / 回声石庭", 34, Color("e5c58a"))
	_text(Vector2(42, 92), "环境美术 V01    ·    11 × 11 正交地图    ·    实际生成布局 / MAP-ART-V01    ·    非可玩关卡", 17)
	if gallery:
		_gallery()
		return
	_board(Vector2(40, 146), 704)
	_text(Vector2(40, 899), "只读复用站姿人物；怪物与事件仍用现有占位绘制。", 16)
	_text(Vector2(40, 927), "单击查看占格  /  空格切换门开闭  /  Tab 查看素材与拼接检验", 15, Color("7f9b9e"))
	_text(Vector2(790, 152), "锁与通路", 24, Color("e1c38a"))
	var kinds := ["copper", "silver", "gold"]
	for i in 3:
		_sprite("door_" + kinds[i] + "_closed", Rect2(786 + i * 146, 177, 122, 122))
		_sprite("door_" + kinds[i] + "_open", Rect2(786 + i * 146, 302, 122, 122))
		_sprite("key_" + kinds[i], Rect2(813 + i * 146, 436, 68, 68))
		_text(Vector2(808 + i * 146, 534), ["铜 / 圆环", "银 / 菱形", "金 / 三角"][i], 16)
	_text(Vector2(790, 594), "石阶与补给", 24, Color("e1c38a"))
	for i in 4:
		_sprite(["stairs_up", "stairs_down", "chest", "potion"][i], Rect2(784 + i * 111, 621, 102, 102))
		_text(Vector2(805 + i * 111, 754), ["上楼", "下楼", "宝箱", "药剂"][i], 16)
	_text(Vector2(790, 811), "蓝灰石材 / 青绿布饰 / 古金金属", 17)
	_text(Vector2(790, 841), "4 地砖变体 · 16 墙连接 · 18 物件", 16)
	_text(Vector2(790, 879), "装饰仅落在墙格，光照限制于单格。", 15, Color("7f9b9e"))
	if selected.x >= 0:
		_text(Vector2(790, 920), "选中 %s  /  %s" % [selected, "阻挡墙" if _wall(selected) else "可走格 / 物件格"], 15, Color("e1c38a"))

func _gallery() -> void:
	_text(Vector2(40, 137), "墙连接 / N=1 E=2 S=4 W=8", 21, Color("e1c38a"))
	for i in 16:
		var p := Vector2(40 + (i % 8) * 94, 160 + (i / 8) * 124)
		_sprite("wall_%02d" % i, Rect2(p, Vector2(88,88)))
		_text(p + Vector2(4,110), "%02d" % i, 14)
	_text(Vector2(838, 137), "透明边缘 / 深浅底", 21, Color("e1c38a"))
	for y in 8:
		for x in 12:
			draw_rect(Rect2(834+x*30,160+y*30,30,30), Color("bec6c8") if (x+y)%2 else Color("344657"))
	_sprite("door_silver_open", Rect2(852,175,190,190))
	_sprite("torch", Rect2(1040,208,120,120))
	_text(Vector2(40, 450), "连续墙与地砖 / 无跨格遮挡", 21, Color("e1c38a"))
	for y in 4:
		for x in 11:
			var mask := 10 if y == 0 else (5 if x == 0 or x == 10 else -1)
			if y == 0 and x == 0: mask = 6
			if y == 0 and x == 10: mask = 12
			_sprite("wall_%02d" % mask if mask >= 0 else "floor_%d" % ((x+y)%3), Rect2(40+x*64,477+y*64,64,64), Color.WHITE if mask >= 0 else Color(0.64,0.72,0.78))
	_text(Vector2(838, 450), "26 px / 真实小屏物件", 21, Color("e1c38a"))
	var ids := ["door_copper_closed", "door_silver_closed", "door_gold_closed", "key_copper", "key_silver", "key_gold", "stairs_up", "stairs_down", "chest", "potion", "torch", "banner"]
	for i in ids.size():
		var p := Vector2(845 + (i % 6)*56, 490 + (i/6)*64)
		_sprite(ids[i], Rect2(p, Vector2(26,26)))
	_text(Vector2(40, 795), "装饰 / 墙格限定", 21, Color("e1c38a"))
	for i in 4:
		_sprite(["torch", "banner", "rubble", "pillar"][i], Rect2(40+i*120,815,100,100))
	_text(Vector2(550, 836), "墙端、转角与连接使用同一材质段定尺组装。", 17)
	_text(Vector2(550, 869), "开门仅用于样态检验；当前游戏开门后删除门实体。", 17)
	_text(Vector2(550, 902), "Tab 返回地图 / 空格切换状态", 16, Color("7f9b9e"))

