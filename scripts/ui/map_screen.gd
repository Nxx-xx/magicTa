extends Control

const Core = preload("res://scripts/core/map_engine.gd")
const Board = preload("res://scripts/ui/grid_board.gd")
const FONT = preload("res://assets/fonts/ui_font.tres")
const GOLD := Color("e0bf80")
const TEAL := Color("83d5bf")
const MUTED := Color("a2b3c3")
const RED := Color("ed9395")
var game = Core.new()
var page := "menu"
var selected := Vector2i(-1, -1)
var notice := ""
var shell: VBoxContainer
var body: VBoxContainer
var margin: MarginContainer
var scroll: ScrollContainer
var seed_input: LineEdit
var generation := 0
var modal_open := false
var show_log := false

func _ready() -> void:
	var ui_theme := Theme.new()
	ui_theme.default_font = FONT
	ui_theme.default_font_size = 16
	ui_theme.set_color("font_color", "Label", Color("e5e9e8"))
	ui_theme.set_color("font_color", "Button", Color("e5e9e8"))
	ui_theme.set_color("font_disabled_color", "Button", Color("68798b"))
	ui_theme.set_stylebox("normal", "Button", _box(Color("24384b"), Color("4d6574")))
	ui_theme.set_stylebox("hover", "Button", _box(Color("2d4c5d"), TEAL))
	ui_theme.set_stylebox("pressed", "Button", _box(Color("192b3a"), GOLD))
	ui_theme.set_stylebox("disabled", "Button", _box(Color("19232e"), Color("364454")))
	ui_theme.set_stylebox("normal", "LineEdit", _box(Color("152333"), Color("536476")))
	ui_theme.set_color("font_color", "LineEdit", Color("e5e9e8"))
	ui_theme.set_color("font_placeholder_color", "LineEdit", MUTED)
	ui_theme.set_constant("separation", "VBoxContainer", 10)
	ui_theme.set_constant("separation", "HBoxContainer", 8)
	theme = ui_theme
	game.load_game()
	get_tree().auto_accept_quit = false
	resized.connect(_fit_width)
	_render()

func _notification(what: int) -> void:
	if what == NOTIFICATION_WM_CLOSE_REQUEST:
		game.save_game()
		get_tree().quit()
	elif what in [NOTIFICATION_APPLICATION_PAUSED, NOTIFICATION_APPLICATION_FOCUS_OUT]:
		game.save_game()

func _input(event: InputEvent) -> void:
	if page != "map" or modal_open or not game.active() or not game.state.pending.is_empty():
		return
	if not event is InputEventKey or not event.pressed or event.echo or event.ctrl_pressed or event.alt_pressed:
		return
	var direction := Vector2i.ZERO
	match event.keycode:
		KEY_W, KEY_UP: direction = Vector2i.UP
		KEY_S, KEY_DOWN: direction = Vector2i.DOWN
		KEY_A, KEY_LEFT: direction = Vector2i.LEFT
		KEY_D, KEY_RIGHT: direction = Vector2i.RIGHT
	if direction != Vector2i.ZERO:
		get_viewport().set_input_as_handled()
		_act(func(): return game.step(direction))

func _box(fill: Color, border: Color) -> StyleBoxFlat:
	var box := StyleBoxFlat.new()
	box.bg_color = fill
	box.border_color = border
	box.set_border_width_all(1)
	box.set_corner_radius_all(9)
	box.content_margin_left = 12
	box.content_margin_right = 12
	box.content_margin_top = 10
	box.content_margin_bottom = 10
	return box

func _text(parent: Node, text: String, size_px: int = 16, color: Color = Color("e5e9e8")) -> Label:
	var label := Label.new()
	label.text = text
	label.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	label.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	label.add_theme_font_size_override("font_size", size_px)
	label.add_theme_color_override("font_color", color)
	parent.add_child(label)
	return label

func _button(parent: Node, text: String, action: Callable, disabled: bool = false) -> Button:
	var button := Button.new()
	button.text = text
	button.custom_minimum_size.y = 48
	button.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	button.disabled = disabled
	parent.add_child(button)
	var token := generation
	button.pressed.connect(func():
		if token == generation:
			action.call()
	)
	return button

func _panel(parent: Node) -> VBoxContainer:
	var panel := PanelContainer.new()
	panel.add_theme_stylebox_override("panel", _box(Color("172434"), Color("3f5365")))
	parent.add_child(panel)
	var box := VBoxContainer.new()
	panel.add_child(box)
	return box

func _render(reset_scroll: bool = false) -> void:
	var previous_scroll := scroll.scroll_vertical if is_instance_valid(scroll) and not reset_scroll else 0
	generation += 1
	for child in get_children():
		remove_child(child)
		child.queue_free()
	var bg := ColorRect.new()
	bg.color = Color("0b111c")
	bg.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(bg)
	bg.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	margin = MarginContainer.new()
	add_child(margin)
	margin.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	for side in ["left", "right", "top", "bottom"]:
		margin.add_theme_constant_override("margin_" + side, 16)
	_fit_width()
	shell = VBoxContainer.new()
	margin.add_child(shell)
	var row := HBoxContainer.new()
	shell.add_child(row)
	_text(row, "塔境 / 地图试炼", 25, GOLD)
	if page == "map":
		_button(row, "营地", func():
			page = "menu"
			_render(true)
		).size_flags_horizontal = Control.SIZE_SHRINK_END
	if page == "map" and not game.state.is_empty():
		_hud()
	scroll = ScrollContainer.new()
	scroll.size_flags_vertical = Control.SIZE_EXPAND_FILL
	scroll.horizontal_scroll_mode = ScrollContainer.SCROLL_MODE_DISABLED
	shell.add_child(scroll)
	body = VBoxContainer.new()
	body.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	scroll.add_child(body)
	if not game.errors.is_empty():
		_text(body, "\n".join(game.errors), 18, RED)
		return
	if not game.save_error.is_empty():
		_text(body, game.save_error, 14, RED)
	if not notice.is_empty():
		_text(body, notice, 14, GOLD)
	if page == "menu":
		_menu()
	else:
		_map_view()
		_controls()
	_text(shell, "两层地图原型 · 自动保存 · 已探索楼层可往返", 11, MUTED).horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	scroll.set_deferred("scroll_vertical", previous_scroll)

func _fit_width() -> void:
	if is_instance_valid(margin):
		var gutter := maxf(0.0, (size.x - 640.0) / 2.0)
		margin.offset_left = gutter
		margin.offset_right = -gutter

func _menu() -> void:
	_text(body, "先绕行，再归来。", 36, GOLD)
	_text(body, "在方格地图里走动、开门、拾取奖励。\n一层的骑士现在很强；二层的补给会改变这场战斗。", 18)
	var info := _panel(body)
	_text(info, "本次地图设计", 21, TEAL)
	_text(info, "两层均为 11×11 格，手工设计主路与支路。首次上楼可选战斗、宝藏或商店主题，支路内容按种子抽取一次。", 15, MUTED)
	_text(info, "怪物被击败后不刷新；开过的门、拿过的宝箱、商店售出记录都会保留。", 15, MUTED)
	if not game.state.is_empty():
		_button(body, "继续探索 · 第 %d 层" % int(game.state.floor) if game.active() else "查看上次探索", _open_map)
	seed_input = LineEdit.new()
	seed_input.custom_minimum_size.y = 48
	seed_input.placeholder_text = "地图种子（留空随机）"
	body.add_child(seed_input)
	_button(body, "开始两层地图试炼", func():
		var seed_text := seed_input.text.strip_edges()
		if game.active():
			_confirm("重新生成地图？", "将替换本次地图试炼进度。旧版卡片模式的存档不受影响。", func(): _start(seed_text))
		else:
			_start(seed_text)
	)
	_text(body, "操作：方向键 / WASD / 下方方向按钮移动；点击相邻格也可移动，点击远处目标可查看属性。战斗和开门先预览再确认。", 14, MUTED)
	_text(body, "这是地图玩法原型，暂不连接十层随机迷宫和灵魂升级。完成回溯目标后仍能继续探索。", 13, MUTED)
	_button(body, "打开旧版十层卡片原型", func():
		game.save_game()
		get_tree().change_scene_to_file("res://scenes/main.tscn")
	)

func _start(seed_text: String) -> void:
	game.start(seed_text)
	selected = Vector2i(-1, -1)
	notice = ""
	show_log = false
	_open_map()

func _open_map() -> void:
	page = "map"
	_render(true)

func _hud() -> void:
	var player: Dictionary = game.state.player
	var stats: Dictionary = game.stats()
	_text(shell, "第 %d 层 · %s" % [game.state.floor, game.floor_data().name], 17, TEAL)
	_text(shell, "生命 %d/%d    攻击 %d    防御 %d" % [player.hp, stats.max_hp, stats.attack, stats.defense], 17)
	_text(shell, "金币 %d    钥匙 %d    已探索 %d / 2 层" % [player.gold, player.keys, game.state.floors.size()], 14, GOLD)

func _map_view() -> void:
	if not game.active():
		_text(body, "火把熄灭了。", 28, RED)
		_button(body, "相同种子重新开始", func(): _start(str(game.state.seed)))
	elif game.state.objective_complete:
		_text(body, "回溯试炼完成！可以继续探索。", 19, TEAL)
	if not game.state.pending.is_empty():
		_pending_panel()
	_text(body, str(game.state.last_message), 14, MUTED)
	var square := AspectRatioContainer.new()
	square.ratio = 1.0
	square.stretch_mode = AspectRatioContainer.STRETCH_FIT
	square.custom_minimum_size.y = clampf(minf(size.x, 640) - 42, 240, 590)
	body.add_child(square)
	var board = Board.new()
	square.add_child(board)
	board.setup(game.floor_data(), game.position(), selected, game.active())
	board.cell_selected.connect(_select_cell)
	_text(body, "青色人物＝你　红怪／紫色强敌　金箱　铜门　钥匙　绿色药剂", 11, MUTED)
	if game.inside(selected):
		var box := _panel(body)
		_describe(box, selected)
	else:
		_text(body, "点击格子查看。主路无需战斗即可到楼梯，支路奖励可以稍后回来拿。", 13, MUTED)
	var inventory := _panel(body)
	_text(inventory, "行囊", 17, GOLD)
	var ids: Array = game.state.player.equipment_ids + game.state.player.relic_ids
	if ids.is_empty():
		_text(inventory, "尚未获得装备。", 13, MUTED)
	for id in ids:
		var item: Dictionary = game.db.item(str(id))
		_text(inventory, "%s · %s" % [item.name, item.description], 13, MUTED)
	if not game.state.last_report.is_empty():
		_button(body, "收起战斗记录" if show_log else "最近一次战斗记录", func():
			show_log = not show_log
			_render()
		)
		if show_log:
			for entry in game.state.last_report.get("log", []):
				_text(body, "第 %d 击：造成 %d，敌人剩 %d HP；反击 %d。" % [entry.turn, entry.hit, entry.enemy_hp, entry.counter], 13, MUTED)
	_text(body, "种子 " + str(game.state.seed) + " · 地图生成后不会重置", 11, MUTED)

func _describe(parent: Node, cell: Vector2i) -> void:
	var entity: Dictionary = game.entity_at(cell)
	if game.is_wall(cell):
		_text(parent, "石墙 · 无法通过", 16, MUTED)
		return
	if entity.is_empty():
		_text(parent, "通路（%d, %d）" % [cell.x, cell.y], 16, MUTED)
		return
	_text(parent, str(entity.name), 19, GOLD)
	match str(entity.type):
		"enemy":
			var enemy: Dictionary = game.db.enemy(entity.enemy_id)
			var report: Dictionary = game.preview(cell)
			_text(parent, "%s · 生命 %d / 攻击 %d / 防御 %d" % [enemy.name, enemy.hp, enemy.attack, enemy.defense], 14, MUTED)
			_text(parent, "当前挑战会死亡，可以变强后再来。" if report.lethal else "预计净损失 %d HP，胜利获得 %d 金币。" % [report.loss, report.gold_reward], 16, RED if report.lethal else TEAL)
		"door":
			_text(parent, "开启消耗 %d 把钥匙，之后永久畅通。" % int(entity.cost), 15, MUTED)
		"chest":
			var item: Dictionary = game.db.item(entity.item_id)
			_text(parent, "%s · %s；额外 %d 金币。" % [item.name, item.description, entity.gold], 15, TEAL)
		"potion":
			_text(parent, "恢复至多 %d HP，走到格子即消耗（满血也会拾取）。" % int(entity.amount), 15, TEAL)
		"gold", "key":
			_text(parent, "获得 %d %s，拾取后不会刷新。" % [entity.amount, "金币" if entity.type == "gold" else "把钥匙"], 15, GOLD)
		"shop":
			_text(parent, "已售出一件商品，本局不再补货。" if entity.purchased else "三件商品选购一件。不买可以离开，下次回来仍可购买。", 15, MUTED)
			for id in entity.offers:
				var offer: Dictionary = game.db.shop_item(id)
				_text(parent, "%s · %s · %d 金币" % [offer.name, offer.description, offer.price], 13, GOLD)
		_:
			_text(parent, str(entity.get("description", "")), 14, MUTED)

func _pending_panel() -> void:
	var box := _panel(body)
	var pending: Dictionary = game.state.pending
	if pending.kind == "floor_choice":
		_text(box, "第二层 · 选择地图主题", 23, GOLD)
		_text(box, "只选择一次。三种主题均有长枪、板甲和泉水补给；以后往返不再重选。", 14, MUTED)
		for id in Core.THEMES:
			var choice: Dictionary = game.layouts.themes[id]
			_text(box, choice.name + "：" + choice.description, 14)
			_button(box, "进入" + choice.name, func(): _act(func(): return game.choose_floor(id)))
	elif pending.kind == "stairs":
		_text(box, "前往已探索的第 %d 层" % int(pending.destination), 22, GOLD)
		_text(box, "楼层布局、怪物、宝箱和商人状态都会保留。", 14, MUTED)
		_button(box, "通过楼梯", func(): _act(game.confirm_interaction))
	else:
		var cell: Vector2i = game.pending_cell()
		var entity: Dictionary = game.entity_at(cell)
		_describe(box, cell)
		if entity.get("type", "") == "shop":
			for index in entity.offers.size():
				var offer: Dictionary = game.db.shop_item(entity.offers[index])
				_button(box, "购买 %s · %d 金币" % [offer.name, offer.price], func(): _act(func(): return game.buy(index)), entity.purchased or int(game.state.player.gold) < int(offer.price))
		elif entity.get("type", "") == "door":
			_button(box, "消耗钥匙开门", func(): _act(game.confirm_interaction), int(game.state.player.keys) < int(entity.cost))
		else:
			_button(box, "确认挑战", _fight)
	_button(box, "暂时离开 · 返回地图", func():
		game.cancel_pending()
		notice = ""
		_render(true)
	)

func _fight() -> void:
	var result: String = game.confirm_interaction()
	if result == "confirm_lethal":
		_confirm("这场战斗会死亡", "可以先去其他楼层变强，再回来。仍要挑战并结束本次探索吗？", func(): _act(func(): return game.confirm_interaction(true)))
	else:
		notice = result
		_render(true)

func _controls() -> void:
	var row := HBoxContainer.new()
	shell.add_child(row)
	var directions := [Vector2i.LEFT, Vector2i.UP, Vector2i.DOWN, Vector2i.RIGHT]
	var labels := ["← 左", "↑ 上", "↓ 下", "→ 右"]
	for index in 4:
		_button(row, labels[index], func(): _act(func(): return game.step(directions[index])), not game.active() or not game.state.pending.is_empty())

func _select_cell(cell: Vector2i) -> void:
	selected = cell
	var delta: Vector2i = cell - game.position()
	if game.active() and game.state.pending.is_empty() and absi(delta.x) + absi(delta.y) <= 1:
		_act(func(): return game.interact(cell))
	else:
		var entity: Dictionary = game.entity_at(cell)
		notice = "已选中：" + str(entity.get("name", "通路")) + "。详细信息在地图下方。"
		_render()

func _act(action: Callable) -> void:
	var previous_floor := int(game.state.floor)
	var result = action.call()
	notice = str(result) if result is String else ""
	selected = game.pending_cell() if not game.state.pending.is_empty() else game.position()
	_render(previous_floor != int(game.state.floor) or not game.state.pending.is_empty())

func _confirm(title: String, text: String, action: Callable) -> void:
	modal_open = true
	var dialog := ConfirmationDialog.new()
	dialog.title = title
	dialog.dialog_text = text
	dialog.dialog_autowrap = true
	dialog.ok_button_text = "确认"
	dialog.cancel_button_text = "取消"
	add_child(dialog)
	dialog.confirmed.connect(func():
		modal_open = false
		dialog.queue_free()
		action.call()
	)
	dialog.canceled.connect(func():
		modal_open = false
		dialog.queue_free()
	)
	dialog.popup_centered(Vector2i(mini(440, int(size.x) - 32), 220))
