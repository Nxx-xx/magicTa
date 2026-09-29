extends SceneTree
const Screen = preload("res://scripts/ui/map_screen.gd")
const Core = preload("res://scripts/core/map_engine.gd")
var failures := 0
var checks := 0
var capturing := false

func _initialize() -> void:
	_run.call_deferred()

func _check(value: bool, label: String) -> void:
	checks += 1
	if not value:
		failures += 1
		push_error("FAIL: " + label)

func _text(node: Node) -> String:
	var value := str(node.text) + "\n" if node is Label or node is Button else ""
	for child in node.get_children():
		value += _text(child)
	return value

func _frames() -> void:
	for frame in 4:
		await process_frame

func _capture(name: String) -> void:
	if not capturing:
		return
	await RenderingServer.frame_post_draw
	var folder := ProjectSettings.globalize_path("res://").path_join("build/verification")
	DirAccess.make_dir_recursive_absolute(folder)
	_check(root.get_texture().get_image().save_png(folder.path_join(name + ".png")) == OK, "capture " + name)

func _fixture(screen, entity: Dictionary) -> void:
	var cell: Vector2i = screen.game.position()
	entity.pos = [cell.x, cell.y]
	entity.name = entity.get("name", "奖励")
	screen.game.floor_data().entities[Core.cell_key(cell)] = entity
	screen.game.state.pending = {}
	screen.game.interact(cell)
	screen.selected = cell
	screen._render(true)

func _run() -> void:
	capturing = OS.get_cmdline_user_args().has("--capture")
	root.size = Vector2i(540, 960)
	var screen = Screen.new()
	screen.game = Core.new("user://reward_ui_%d.json" % OS.get_process_id())
	screen.game.persistence_enabled = false
	root.add_child(screen)
	screen.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	screen._start("42")
	screen.game.state.player.hp = 80
	_fixture(screen, {"type": "potion", "name": "疗愈药剂", "amount": 45})
	await _frames()
	_check(_text(screen).contains("实际恢复 20，溢出 25") and _text(screen).contains("使用药剂"), "potion shows actual recovery and confirm")
	await _capture("reward_potion")
	screen.game.state.player.gold = 100
	screen.game._grant_item("gold_sword")
	screen.game._grant_item("merchant_seal")
	_fixture(screen, {"type": "shop", "name": "烛火商人", "offers": ["buy_steel", "buy_plate", "buy_potion"], "purchased": false})
	await _frames()
	_check(_text(screen).contains("购买后：攻击 20（+4）") and _text(screen).contains("金币 58"), "shop displays gold-aware final attack and balance")
	await _capture("reward_shop")
	_fixture(screen, {"type": "choice", "name": "遗物二选一", "choices": ["blood_sword", "stone_heart"], "gold": 25})
	await _frames()
	_check(_text(screen).contains("选择 · 嗜血剑") and _text(screen).contains("选择 · 岩心") and _text(screen).contains("另获 25 金币"), "choice shows both items and attached gold")
	await _capture("reward_choice")
	_fixture(screen, {"type": "event", "name": "血色祭坛", "event_id": "altar"})
	await _frames()
	_check(_text(screen).contains("选择 · 献祭") and _text(screen).contains("选择 · 绕行"), "event options render")
	_fixture(screen, {"type": "rest", "name": "旅人休息点", "options": screen.game.generator.reward_config.rest_options.duplicate(true)})
	await _frames()
	_check(_text(screen).contains("选择 · 休息") and _text(screen).contains("选择 · 磨砺"), "rest options render")
	screen.game.cancel_pending()
	screen.game._grant_item("iron_sword")
	screen.game._grant_item("iron_sword")
	screen._render(true)
	await _frames()
	_check(_text(screen).contains("铁剑 ×2"), "inventory groups duplicate copies")
	root.content_scale_mode = Window.CONTENT_SCALE_MODE_DISABLED
	root.content_scale_size = Vector2i.ZERO
	for width in [320, 540, 900]:
		root.size = Vector2i(width, 960)
		_fixture(screen, {"type": "shop", "name": "烛火商人", "offers": ["buy_steel", "buy_plate", "buy_potion"], "purchased": false})
		await _frames()
		_check(screen.body.size.x <= screen.scroll.size.x, "content fits viewport width %d" % width)
		if width == 320:
			await _capture("reward_mobile")
	root.remove_child(screen)
	screen.free()
	print("Reward UI tests: %d checks, %d failures" % [checks, failures])
	quit(1 if failures else 0)
