extends SceneTree
## Standalone visual harness: raw PNG decoding needs no project import or player saves.
const Ruins = preload("res://scripts/core/phase3_ruins.gd")
const Recipe = preload("res://scripts/core/phase3_map_recipe.gd")
const Generator = preload("res://scripts/core/campaign_generator.gd")
const Items = preload("res://scripts/core/phase3_items.gd")
const RuinPanel = preload("res://scripts/ui/phase3_ruin_panel.gd")
const OUT := "res://build/verification/phase3/02-ruins/"
var panel: PanelContainer
var gallery: VBoxContainer
var container: HBoxContainer
var root_control: Control
var player := {"hp":88,"max_hp":100,"attack":10,"defense":5,"gold":30,"keys":0,"silver_keys":0,"gold_keys":0,"equipment_ids":[],"relic_ids":[]}
var content := {}
var manifest := {}
var current_id := "p3_oath_ruin"
var animation := "idle"
var elapsed := 0.0
var frame_textures := {}
var sprite: TextureRect
var small_sprite: TextureRect
var frame_label: Label
var status: Label
var map_view: Control
var capture := false
var animation_paused := false

class MapView:
	extends Control
	var map := {}
	func _draw() -> void:
		if map.is_empty(): return
		var step := minf(size.x / 11.0, size.y / 11.0)
		for y in range(11):
			for x in range(11):
				var rect := Rect2(x*step,y*step,step-1,step-1)
				draw_rect(rect,Color("172333") if map.rows[y][x] == "#" else Color("405166"))
		for entity in map.entities.values():
			var symbol: String = {"enemy":"G","door":"D","key":"K","choice":"T","chest":"F","event":"R","up":"U","down":"V","rest":"H","shop":"S","potion":"+","gold":"$"}.get(entity.type,"?")
			var pos := Vector2(entity.pos[0]*step,entity.pos[1]*step)
			draw_rect(Rect2(pos+Vector2(3,3),Vector2(step-7,step-7)),Color("b67948") if entity.type == "enemy" else Color("497d79"))
			draw_string(ThemeDB.fallback_font,pos+Vector2(9,step-10),symbol,HORIZONTAL_ALIGNMENT_LEFT,-1,18,Color.WHITE)

func _initialize() -> void:
	call_deferred("_run")

func _run() -> void:
	capture = "--capture" in OS.get_cmdline_user_args()
	root.content_scale_size = Vector2i.ZERO
	root.min_size = Vector2i(320,600)
	root.size = Vector2i(1160,780)
	root.title = "第三阶段 · 遗迹模块独立预览（动画草稿）"
	content = Items.merge_content(JSON.parse_string(FileAccess.get_file_as_string("res://data/content.json")))
	manifest = JSON.parse_string(FileAccess.get_file_as_string("res://assets/environment/ruins/phase3/manifest.json"))
	_load_atlases()
	root_control = Control.new()
	root.add_child(root_control)
	root_control.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	var background := ColorRect.new()
	background.color = Color("101925")
	background.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	root_control.add_child(background)
	container = HBoxContainer.new()
	root_control.add_child(container)
	container.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	container.add_theme_constant_override("separation",16)
	panel = RuinPanel.new()
	panel.custom_minimum_size.x = 380
	panel.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	container.add_child(panel)
	panel.option_selected.connect(func(id): status.text = "只读信号 option_selected(\"%s\")；未提交奖励。" % id)
	panel.leave_requested.connect(func(): status.text = "只读信号 leave_requested；遗迹仍可用。")
	gallery = VBoxContainer.new()
	gallery.custom_minimum_size.x = 680
	container.add_child(gallery)
	var title := Label.new()
	title.text = "遗迹 / 几何 / 动画审阅"
	title.add_theme_font_size_override("font_size",26)
	gallery.add_child(title)
	var selectors := HBoxContainer.new()
	gallery.add_child(selectors)
	for id in Ruins.IDS:
		var button := Button.new()
		button.text = Ruins.definitions()[id].name
		button.pressed.connect(func(): _present(id))
		selectors.add_child(button)
	var controls := HBoxContainer.new()
	gallery.add_child(controls)
	for mode in ["idle","resolve","spent"]:
		var button := Button.new()
		button.text = mode
		button.pressed.connect(func(): animation = mode; elapsed = 0.0; _update_frame())
		controls.add_child(button)
	var still := CheckButton.new()
	still.text = "减动效 / 静帧"
	still.toggled.connect(func(value): animation_paused = value)
	controls.add_child(still)
	var advance := Button.new()
	advance.text = "下一帧"
	advance.pressed.connect(func(): animation_paused = true; elapsed += 1.0 / float(manifest.ruins[current_id][animation].fps); _update_frame())
	controls.add_child(advance)
	var row := HBoxContainer.new()
	gallery.add_child(row)
	sprite = TextureRect.new()
	sprite.custom_minimum_size = Vector2(256,256)
	sprite.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	sprite.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
	row.add_child(sprite)
	small_sprite = TextureRect.new()
	small_sprite.custom_minimum_size = Vector2(48,48)
	small_sprite.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	small_sprite.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
	row.add_child(small_sprite)
	frame_label = Label.new()
	frame_label.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	frame_label.custom_minimum_size.x = 250
	row.add_child(frame_label)
	var bottom := HBoxContainer.new()
	gallery.add_child(bottom)
	map_view = MapView.new()
	map_view.custom_minimum_size = Vector2(330,330)
	bottom.add_child(map_view)
	var explanation := Label.new()
	explanation.custom_minimum_size.x = 330
	explanation.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	explanation.text = "几何样板：四条奖励支路＋独立遗迹支路\nR 遗迹 · G 守卫 · T 候选\nF 固定军械 · U/V 楼梯\n\n生产生成器 seed=2，主题=战斗。\n每个守卫都是对应奖励的割点。\n\n动画素材是生成草稿：\n帧锚点、连续性与小尺寸可读性未验收。\n不接入主游戏、不写存档。"
	bottom.add_child(explanation)
	status = Label.new()
	status.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	gallery.add_child(status)
	_present(current_id)
	animation_paused = false
	if capture:
		await _capture_all()
		quit()

func _present(id: String) -> void:
	current_id = id
	elapsed = 0
	var previews := Ruins.preview_options(id,player,content,Callable(Items,"resolve"))
	panel.present(Ruins.definitions()[id],previews.options)
	var generator := Generator.new()
	var floor_number: int = Ruins.IDS[id]
	var map: Dictionary = generator.generate(generator.plan("2"),floor_number,"battle","dawn_spear")
	var output := Recipe.decorate_floor(map,content,{"freshly_generated":true,"floor":floor_number,"theme":"battle","unlocked_ids":Items.UNIQUE_IDS.duplicate(),"used_unique_ids":[],"variant_plan":{},"geometry":"ruin_spokes"})
	map_view.map = output.floor_map
	map_view.queue_redraw()
	status.text = "生成样板可运行；玩家输入夹具 HP=88/100、金币=30。"
	_update_frame()

func _process(delta: float) -> bool:
	if sprite == null or animation_paused: return false
	elapsed += delta
	_update_frame()
	return false

func _update_frame() -> void:
	var clip: Dictionary = manifest.ruins[current_id][animation]
	var index: int = int(elapsed * int(clip.fps)) % clip.frames.size()
	var texture: Texture2D = frame_textures[current_id][int(clip.frames[index])]
	sprite.texture = texture
	small_sprite.texture = texture
	frame_label.text = "草稿 · 禁止视为已验收动画\n%s %d / %d · %d fps\n左 256 px / 中 48 px\n%s" % [animation,index+1,clip.frames.size(),clip.fps,manifest.ruins[current_id].acceptance]

func _load_atlases() -> void:
	var audit := {"accepted":false,"frames_declared":35,"atlases":{}}
	for id in manifest.ruins:
		var definition: Dictionary = manifest.ruins[id]
		var source := Image.load_from_file(definition.atlas)
		var texture := ImageTexture.create_from_image(source)
		var columns := int(definition.grid[0])
		var rows := int(definition.grid[1])
		var width := float(source.get_width()) / columns
		var height := float(source.get_height()) / rows
		frame_textures[id] = []
		var hashes := []
		var bounds := []
		var frame_count := 13 if id == "p3_oath_forge" else 11
		for index in range(frame_count):
			var atlas := AtlasTexture.new()
			atlas.atlas = texture
			atlas.region = Rect2((index % columns)*width,(index / columns)*height,width,height)
			atlas.filter_clip = true
			frame_textures[id].append(atlas)
			var region := source.get_region(Rect2i(int((index % columns)*width),int((index / columns)*height),int(width),int(height)))
			var hash_context := HashingContext.new()
			hash_context.start(HashingContext.HASH_SHA256)
			hash_context.update(region.get_data())
			hashes.append(hash_context.finish().hex_encode())
			var used := region.get_used_rect()
			bounds.append([used.position.x,used.position.y,used.size.x,used.size.y])
		audit.atlases[id] = {"size":[source.get_width(),source.get_height()],"alpha":source.detect_alpha(),
			"cell_size":[width,height],"square_integer_grid":width == height and width == floorf(width),"frame_hashes":hashes,"alpha_bounds":bounds,
			"accepted":false,"reason":definition.acceptance}
	var file := FileAccess.open(OUT + "atlas-audit.json",FileAccess.WRITE)
	file.store_string(JSON.stringify(audit,"\t"))

func _capture_all() -> void:
	animation_paused = true
	for id in Ruins.IDS:
		_present(id)
		await process_frame
		await process_frame
		await RenderingServer.frame_post_draw
		root.get_texture().get_image().save_png(OUT + id + "-preview.png")
	gallery.hide()
	panel.custom_minimum_size.x = 280
	root.size = Vector2i(320,640)
	for id in Ruins.IDS:
		_present(id)
		await process_frame
		await process_frame
		await RenderingServer.frame_post_draw
		root.get_texture().get_image().save_png(OUT + id + "-320.png")
	print("PHASE3_RUINS_PREVIEW captured six screenshots and atlas-audit.json; all animation assets remain DRAFT.")
