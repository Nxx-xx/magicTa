extends SceneTree
## Headless smoke checks. Add -- --capture with a graphical renderer to save
## the actual Godot-drawn monster atlas and map/detail previews under build/.
const Screen = preload("res://scripts/ui/map_screen.gd")
const Core = preload("res://scripts/core/map_engine.gd")
const Enemies = preload("res://scripts/core/enemy_rules.gd")
const OUTPUT_DIR := "build/verification"
var failures := 0
var checks := 0

class Atlas extends Control:
	const Art = preload("res://scripts/ui/monster_art.gd")
	const FONT = preload("res://assets/fonts/ui_font.tres")
	const Rules = preload("res://scripts/core/enemy_rules.gd")
	var enemies: Array = []
	func _draw() -> void:
		draw_rect(Rect2(Vector2.ZERO, size), Color("0b111c"))
		draw_string(FONT, Vector2(32, 48), "塔境 · 怪物设计", HORIZONTAL_ALIGNMENT_LEFT, -1, 28, Color("e0bf80"))
		draw_string(FONT, Vector2(32, 80), "6 种普通怪 / 2 种精英 / 2 个 Boss · 图标由游戏绘制代码直接渲染", HORIZONTAL_ALIGNMENT_LEFT, -1, 17, Color("a2b3c3"))
		for index in enemies.size():
			var enemy: Dictionary = enemies[index]
			var origin := Vector2(24 + (index % 5) * 214, 110 + (index / 5) * 234)
			draw_rect(Rect2(origin, Vector2(200, 216)), Color("172434"))
			draw_set_transform(origin + Vector2(100, 68), 0, Vector2.ONE * 2.0)
			Art.draw(self, enemy, {"guardian": enemy.id == "knight"})
			draw_set_transform(Vector2.ZERO)
			var title := str(enemy.name).replace("精英 · ", "")
			draw_string(FONT, origin + Vector2(12, 136), title, HORIZONTAL_ALIGNMENT_LEFT, -1, 20, Color("e5e9e8"))
			draw_string(FONT, origin + Vector2(12, 164), Rules.classification(enemy), HORIZONTAL_ALIGNMENT_LEFT, -1, 14, Color("e0bf80"))
			draw_string(FONT, origin + Vector2(12, 192), "生命 %d · 攻 %d · 防 %d" % [enemy.hp, enemy.attack, enemy.defense], HORIZONTAL_ALIGNMENT_LEFT, -1, 14, Color("a2b3c3"))
		draw_string(FONT, Vector2(32, 610), "角标：1 / 2 / 3 为普通怪强度档；回＝回溯守卫，精＝精英，王＝Boss。", HORIZONTAL_ALIGNMENT_LEFT, -1, 17, Color("a2b3c3"))

func _initialize() -> void:
	_run.call_deferred()

func _check(condition: bool, label: String) -> void:
	checks += 1
	if not condition:
		failures += 1
		push_error("FAIL: " + label)

func _labels(node: Node) -> String:
	var text := str(node.text) + "\n" if node is Label else ""
	for child in node.get_children():
		text += _labels(child)
	return text

func _frames() -> void:
	for frame in 4:
		await process_frame

func _capture(name: String) -> void:
	await RenderingServer.frame_post_draw
	var output := ProjectSettings.globalize_path("res://").path_join(OUTPUT_DIR).path_join(name + ".png")
	var result := root.get_texture().get_image().save_png(output)
	_check(result == OK, "saved engine rendering: " + name)

func _run() -> void:
	root.size = Vector2i(540, 960)
	var screen = Screen.new()
	screen.game = Core.new("user://monster_ui_test_%d.json" % OS.get_process_id())
	screen.game.persistence_enabled = false
	root.add_child(screen)
	screen.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	screen._start("42")
	_check(screen.game.errors.is_empty() and screen.game.active(), "map UI starts with valid content")
	var cell: Vector2i = screen.game.position()
	var old_entity: Dictionary = screen.game.entity_at(cell).duplicate(true)
	for enemy in screen.game.db.data.enemies.values():
		var entity := {"type": "enemy", "name": "测试守卫", "enemy_id": enemy.id, "guardian": enemy.id == "knight", "pos": [cell.x, cell.y]}
		screen.game.floor_data().entities[Core.cell_key(cell)] = entity
		var details := VBoxContainer.new()
		screen._describe(details, cell)
		var text := _labels(details)
		_check(text.contains(str(enemy.name)) and text.contains(Enemies.classification(enemy)), "name and rank visible: " + str(enemy.id))
		_check(text.contains(str(enemy.combat_hint)) and text.contains("击杀奖励：%d 金币" % int(enemy.gold_reward)), "tactics and independent reward visible: " + str(enemy.id))
		if enemy.id == "knight":
			_check(text.contains("回溯守卫") and text.contains("会死亡"), "return guard can be recognized without color")
		if not str(enemy.ability_id).is_empty():
			_check(text.contains(str(enemy.description)), "boss mechanic visible: " + str(enemy.id))
		details.free()
	screen.game.floor_data().entities[Core.cell_key(cell)] = old_entity
	for entity in screen.game.floor_data().entities.values():
		if entity.get("guardian", false):
			screen.selected = Vector2i(int(entity.pos[0]), int(entity.pos[1]))
	screen._render(true)
	await _frames()
	var capturing := OS.get_cmdline_user_args().has("--capture")
	if capturing:
		DirAccess.make_dir_recursive_absolute(ProjectSettings.globalize_path("res://").path_join(OUTPUT_DIR))
		await _capture("monster_map")
		screen.scroll.scroll_vertical = 300
		await _frames()
		await _capture("monster_detail")
	var atlas := Atlas.new()
	atlas.enemies = screen.game.db.data.enemies.values()
	root.remove_child(screen)
	screen.free()
	root.content_scale_mode = Window.CONTENT_SCALE_MODE_DISABLED
	root.content_scale_size = Vector2i.ZERO
	root.size = Vector2i(1120, 640)
	root.add_child(atlas)
	atlas.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	await _frames()
	if capturing:
		await _capture("monster_atlas")
	print("Monster UI tests: %d checks, %d failures" % [checks, failures])
	quit(1 if failures > 0 else 0)
