extends SceneTree
## Standalone sample renderer. Does not load the game or its saves.

const IDS = ["floor", "wall", "player_front", "slime", "key_copper"]
var base: String

class Sheet extends Node2D:
	var textures: Dictionary = {}
	var font: FontFile
	var gold := Color("e0bd7c")
	var ink := Color("b7c5d0")
	var layout := ["###########", "#.........#", "#.###.###.#", "#...#...#.#", "###.#.#.#.#", "#...#.#...#", "#.###.###.#", "#.........#", "#.###.###.#", "#.........#", "###########"]
	func label_at(p: Vector2, text: String, size_px: int = 18, color: Color = Color("b7c5d0")) -> void:
		draw_string(font, p, text, HORIZONTAL_ALIGNMENT_LEFT, -1, size_px, color)
	func sprite(id: String, rect: Rect2) -> void:
		draw_texture_rect(textures[id], rect, false)
	func checker(rect: Rect2) -> void:
		for y in range(int(rect.size.y / 8)):
			for x in range(int(rect.size.x / 8)):
				draw_rect(Rect2(rect.position + Vector2(x, y) * 8, Vector2(8, 8)), Color("2d3947") if (x+y)%2 else Color("394858"))
	func board(p: Vector2, extent: float) -> void:
		var cell := extent / 11.0
		draw_rect(Rect2(p - Vector2.ONE * 3, Vector2.ONE * (extent+6)), gold, false, 1)
		for y in 11:
			for x in 11:
				var rect := Rect2(p + Vector2(x, y)*cell + Vector2.ONE, Vector2.ONE*(cell-2))
				sprite("wall" if layout[y][x] == "#" else "floor", rect)
		for entry in [["player_front", Vector2(3, 7)], ["slime", Vector2(5, 7)], ["key_copper", Vector2(7, 7)]]:
			sprite(entry[0], Rect2(p + entry[1]*cell + Vector2.ONE, Vector2.ONE*(cell-2)))
		draw_rect(Rect2(p+Vector2(5, 7)*cell+Vector2.ONE*2, Vector2.ONE*(cell-4)), gold, false, 2)
	func _draw() -> void:
		draw_rect(Rect2(0,0,1200,1390), Color("0c1420"))
		label_at(Vector2(36,48), "塔境 / 美术样品 01", 30, gold)
		label_at(Vector2(36,79), "暗色石砖 · 青绿玩家 · 暖铜物件   /   风格评审，未接入游戏", 18)
		var names := ["地板 / FLOOR", "墙体 / WALL", "玩家 / FRONT", "史莱姆 / SLIME", "铜钥匙 / KEY"]
		for i in 5:
			var x := 36+i*232
			label_at(Vector2(x,119), names[i], 17, gold)
			checker(Rect2(x,136,128,128))
			sprite(IDS[i], Rect2(x,136,128,128))
			checker(Rect2(x+152,136,32,32))
			sprite(IDS[i], Rect2(x+152,136,32,32))
			label_at(Vector2(x,287), "32×32 → 4× / 1×", 15)
		label_at(Vector2(36,332), "11×11 组合预览 / 固定构图，不代表真实关卡", 23, gold)
		label_at(Vector2(36,363), "540 宽参考：498 地图 / 45.27 格 / 43.27 绘图区", 16)
		label_at(Vector2(594,363), "360 宽参考：318 地图 / 28.91 格 / 26.91 绘图区", 16)
		board(Vector2(36,383),498)
		board(Vector2(594,383),318)
		label_at(Vector2(594,742), "青绿直立轮廓：玩家", 18)
		label_at(Vector2(594,777), "橙色宽轮廓：史莱姆", 18)
		label_at(Vector2(594,812), "空心环 + 单齿：铜钥匙", 18)
		label_at(Vector2(594,855), "金框为查看示意；不承担美术识别。", 16)
		label_at(Vector2(36,931), "无间隙铺排 / 原生 32 像素格", 23, gold)
		for y in 3:
			for x in 6:
				sprite("floor", Rect2(36+x*32,954+y*32,32,32))
				sprite("wall", Rect2(276+x*32,954+y*32,32,32))
		label_at(Vector2(36,1079), "地板 6×3",16)
		label_at(Vector2(276,1079), "墙体 6×3",16)
		label_at(Vector2(530,971), "局部 2× 整数缩放 / 三物件同格对照",18)
		for i in 3:
			sprite("floor", Rect2(530+i*88,994,64,64))
			sprite(IDS[i+2], Rect2(530+i*88,994,64,64))
		label_at(Vector2(36,1140), "导入建议",23,gold)
		label_at(Vector2(36,1177), "PNG RGBA · Nearest · 无 mipmap · Lossless · 统一 32×32 画布",18)
		label_at(Vector2(36,1210), "非整数缩放会产生像素宽度不均；本图按现有格子公式显示，供主界面定尺评审。",17)
		label_at(Vector2(36,1259), "限制：原图仍有渐变与半透明边缘；地形可铺排，重复裂纹及边缝尚待精修。",17,Color("d6a18a"))
		label_at(Vector2(36,1292), "玩家、史莱姆、铜钥匙可用于静态样板试接；量产前仍需像素清理与形状规范。",17,Color("d6a18a"))
		label_at(Vector2(36,1350), "SOURCE  OpenAI image_gen / 2026-09-29    ·    RENDER  Godot 4.7.2 / nearest",15)

func _initialize() -> void:
	base = OS.get_cmdline_user_args()[0].replace("\\", "/")
	root.size = Vector2i(1200,1390)
	root.content_scale_size = Vector2i(1200,1390)
	root.title = "MagicTa art sample review"
	var sheet := Sheet.new()
	sheet.texture_filter = CanvasItem.TEXTURE_FILTER_NEAREST
	sheet.font = FontFile.new()
	sheet.font.load_dynamic_font(base + "/assets/fonts/NotoSansSC.ttf")
	var report: Dictionary = {"method": "Godot Image.resize(32,32,INTERPOLATE_NEAREST); no artistic retouch or alpha threshold", "assets": {}}
	for id in IDS:
		var version: String = "v02" if id in ["floor", "wall"] else "v01"
		var original := Image.load_from_file(base + "/assets/art_samples/source/" + id + "_concept_" + version + ".png")
		assert(original != null)
		var original_size := original.get_size()
		original.convert(Image.FORMAT_RGBA8)
		original.resize(32,32,Image.INTERPOLATE_NEAREST)
		var path: String = base + "/assets/art_samples/candidate32/" + id + "_32_" + version + ".png"
		assert(original.save_png(path) == OK)
		var transparent := 0
		var partial := 0
		var colors: Dictionary = {}
		var luma := 0.0
		for y in 32:
			for x in 32:
				var c := original.get_pixel(x,y)
				if c.a == 0: transparent += 1
				elif c.a < 1: partial += 1
				colors[c.to_rgba32()] = true
				luma += c.srgb_to_linear().get_luminance()
		report.assets[id] = {"source_size": [original_size.x, original_size.y], "size": [32,32], "transparent_pixels": transparent, "partial_alpha_pixels": partial, "distinct_rgba": colors.size(), "bounds": str(original.get_used_rect()), "mean_linear_luminance": luma/1024.0}
		sheet.textures[id] = ImageTexture.create_from_image(original)
	var json_file := FileAccess.open(base + "/build/verification/art_samples/metrics.json", FileAccess.WRITE)
	json_file.store_string(JSON.stringify(report,"\t"))
	json_file.close()
	root.add_child(sheet)
	_capture.call_deferred()

func _capture() -> void:
	await process_frame
	await process_frame
	await RenderingServer.frame_post_draw
	var screenshot := root.get_texture().get_image()
	assert(screenshot.save_png(base + "/assets/art_samples/previews/review_sheet_v02.png") == OK)
	print("ART_SAMPLE_OK ", screenshot.get_size())
	quit()
