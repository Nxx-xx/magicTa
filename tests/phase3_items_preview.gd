extends SceneTree
## Standalone review fixture. Raw PNG cache avoids any global editor import.
const Items = preload("res://scripts/core/phase3_items.gd")
const Summary = preload("res://scripts/ui/phase3_build_summary.gd")
var retained_textures: Array[Texture2D] = []

func _initialize() -> void:
	call_deferred("_show")

func _show() -> void:
	var compact := "--compact" in OS.get_cmdline_user_args()
	root.content_scale_size = Vector2i(540 if compact else 1120, 980)
	root.content_scale_mode = Window.CONTENT_SCALE_MODE_DISABLED
	root.content_scale_aspect = Window.CONTENT_SCALE_ASPECT_IGNORE
	root.size = Vector2i(540 if compact else 1120, 980)
	var content: Dictionary = JSON.parse_string(FileAccess.get_file_as_string("res://data/content.json"))
	content = Items.merge_content(content)
	for id in Items.UNIQUE_IDS:
		var path: String = content.items[id].icon
		var image := Image.load_from_file(path)
		var texture := ImageTexture.create_from_image(image)
		texture.take_over_path(path)
		retained_textures.append(texture)
	var background := ColorRect.new()
	background.color = Color("142234")
	background.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	root.add_child(background)
	var margin := MarginContainer.new()
	margin.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	for side in ["left", "right", "top", "bottom"]:
		margin.add_theme_constant_override("margin_" + side, 24)
	root.add_child(margin)
	var font := FontFile.new()
	font.load_dynamic_font("res://assets/fonts/NotoSansSC.ttf")
	var theme := Theme.new()
	var readable := FontVariation.new()
	readable.base_font = font
	readable.variation_opentype = {2003265652: 500}
	theme.default_font = readable
	theme.default_font_size = 17
	margin.theme = theme
	var columns := HBoxContainer.new()
	columns.add_theme_constant_override("separation", 36)
	margin.add_child(columns)
	var p := {"hp": 100, "max_hp": 100, "attack": 15, "defense": 5, "gold": 100,
		"keys": 0, "silver_keys": 0, "gold_keys": 0, "equipment_ids": [], "relic_ids": Items.UNIQUE_IDS.duplicate()}
	var left := Summary.new()
	left.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	columns.add_child(left)
	left.present(p, content)
	if not compact:
		var right := VBoxContainer.new()
		right.custom_minimum_size.x = 448
		right.add_theme_constant_override("separation", 20)
		columns.add_child(right)
		p.relic_ids = ["gold_sword", "merchant_seal", "p3_gilded_lantern"]
		var wealth := Summary.new()
		right.add_child(wealth)
		wealth.present(p, content, Summary.reward_comparison(content, p, {"cost": {"gold": 42}, "item_id": "steel_blade"}))
		var cap := Label.new()
		cap.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
		cap.text = "断誓锻台 · 熔铸生命纹\n" + Summary.reward_comparison(content, p, {"cost": {"max_hp": 10}, "effects": {"attack": 4}}).text
		right.add_child(cap)
		var note := Label.new()
		note.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
		note.text = "独立输入夹具预览\n所有数值来自 phase3_items.resolve。\n当前图标通过 PNG 临时缓存显示，未执行工程导入。"
		note.modulate = Color("b9c8d3")
		right.add_child(note)
	for frame in 5:
		await process_frame
	await RenderingServer.frame_post_draw
	var screenshot := root.get_texture().get_image()
	var path := "res://build/verification/phase3/01-items/build-summary-%s.png" % ("compact" if compact else "wide")
	var error := screenshot.save_png(path)
	print("Phase3 item preview: ", path, " save=", error)
	quit(0 if error == OK else 1)
