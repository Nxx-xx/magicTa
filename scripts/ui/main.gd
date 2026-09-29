extends Control

const EngineCore = preload("res://scripts/core/run_engine.gd")
const TowerArt = preload("res://scripts/ui/tower_art.gd")
const FONT = preload("res://assets/fonts/NotoSansSC.ttf")
const INK := Color("e6e7e3")
const MUTED := Color("9aabba")
const GOLD := Color("dbbb7d")
const TEAL := Color("80d6bd")
const RED := Color("f18b8c")
const PANEL := Color("141e2e")
const ROOM_NAMES := {"normal": "战斗", "elite": "精英", "boss": "首领", "chest": "宝箱",
	"shop": "商店", "event": "事件", "rest": "休息"}

var game = EngineCore.new()
var shell: VBoxContainer
var body: VBoxContainer
var page := "menu"
var seed_input: LineEdit
var outer_margin: MarginContainer
var notice := ""
var _input_generation := 0

func _ready() -> void:
	_build_theme()
	game.load_game()
	get_tree().auto_accept_quit = false
	resized.connect(_fit_width)
	_render()

func _notification(what: int) -> void:
	if what == NOTIFICATION_WM_CLOSE_REQUEST:
		game.save_game()
		get_tree().quit()
	elif what == NOTIFICATION_APPLICATION_PAUSED or what == NOTIFICATION_APPLICATION_FOCUS_OUT:
		if is_instance_valid(game):
			game.save_game()

func _build_theme() -> void:
	var style := Theme.new()
	style.default_font = FONT
	style.default_font_size = 16
	style.set_color("font_color", "Label", INK)
	style.set_color("font_color", "Button", INK)
	style.set_color("font_hover_color", "Button", Color.WHITE)
	style.set_color("font_disabled_color", "Button", Color("637081"))
	style.set_constant("outline_size", "Button", 0)
	style.set_stylebox("normal", "Button", _box(Color("223248"), Color("3b5064"), 10, 14))
	style.set_stylebox("hover", "Button", _box(Color("2c4258"), TEAL, 10, 14))
	style.set_stylebox("pressed", "Button", _box(Color("192838"), GOLD, 10, 14))
	style.set_stylebox("disabled", "Button", _box(Color("17202c"), Color("293341"), 10, 14))
	style.set_stylebox("focus", "Button", _box(Color(0, 0, 0, 0), GOLD, 10, 0))
	style.set_stylebox("normal", "LineEdit", _box(Color("0c1522"), Color("354659"), 8, 12))
	style.set_color("font_color", "LineEdit", INK)
	style.set_color("font_placeholder_color", "LineEdit", MUTED)
	style.set_constant("separation", "VBoxContainer", 10)
	style.set_constant("separation", "HBoxContainer", 10)
	theme = style

func _box(fill: Color, border: Color, radius: int, padding: int) -> StyleBoxFlat:
	var style := StyleBoxFlat.new()
	style.bg_color = fill
	style.border_color = border
	style.set_border_width_all(1)
	style.set_corner_radius_all(radius)
	style.content_margin_left = padding
	style.content_margin_right = padding
	style.content_margin_top = padding
	style.content_margin_bottom = padding
	return style

func _render() -> void:
	_input_generation += 1
	for child in get_children():
		remove_child(child)
		child.queue_free()
	var background := ColorRect.new()
	background.color = Color("0b111c")
	background.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	background.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(background)
	var margin := MarginContainer.new()
	add_child(margin)
	margin.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	outer_margin = margin
	_fit_width()
	for side in ["left", "right", "top", "bottom"]:
		margin.add_theme_constant_override("margin_" + side, 18)
	shell = VBoxContainer.new()
	shell.add_theme_constant_override("separation", 14)
	margin.add_child(shell)
	if page == "run" and not game.run.is_empty():
		_status()
	else:
		var header := HBoxContainer.new()
		shell.add_child(header)
		_label(header, "T A J I N G   /   塔境", 16, GOLD).size_flags_horizontal = Control.SIZE_EXPAND_FILL
		_label(header, "V 0.1", 13, MUTED)
	var scroll := ScrollContainer.new()
	scroll.size_flags_vertical = Control.SIZE_EXPAND_FILL
	scroll.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	scroll.horizontal_scroll_mode = ScrollContainer.SCROLL_MODE_DISABLED
	shell.add_child(scroll)
	body = VBoxContainer.new()
	body.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	body.add_theme_constant_override("separation", 14)
	scroll.add_child(body)
	if not game.db.errors.is_empty():
		_label(body, "内容加载失败\n" + "\n".join(game.db.errors), 18, RED)
		return
	if not game.message.is_empty():
		_label(body, game.message, 14, RED)
	if not notice.is_empty():
		_label(body, notice, 14, GOLD)
	match page:
		"menu": _menu()
		"upgrades": _upgrades()
		"log": _combat_log()
		"history": _history()
		"run":
			if game.run.completed:
				_ending()
			else:
				_run_body()
	_label(shell, "确定性战斗  ·  自动保存  ·  每层选择不可返回", 11, MUTED).horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER

func _fit_width() -> void:
	if is_instance_valid(outer_margin):
		var gutter := maxf(0.0, (size.x - 660.0) * 0.5)
		outer_margin.offset_left = gutter
		outer_margin.offset_right = -gutter

func _label(parent: Node, text: String, font_size: int = 16, color: Color = INK) -> Label:
	var label := Label.new()
	label.text = text
	label.add_theme_font_size_override("font_size", font_size)
	label.add_theme_color_override("font_color", color)
	label.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	label.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	parent.add_child(label)
	return label

func _button(parent: Node, text: String, action: Callable, disabled: bool = false) -> Button:
	var button := Button.new()
	button.text = text
	button.custom_minimum_size.y = 48
	button.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	button.disabled = disabled
	button.mouse_default_cursor_shape = Control.CURSOR_POINTING_HAND
	parent.add_child(button)
	var generation := _input_generation
	button.pressed.connect(func() -> void:
		if generation == _input_generation:
			action.call()
	)
	return button

func _panel(parent: Node, accent: Color = Color("324153")) -> VBoxContainer:
	var panel := PanelContainer.new()
	panel.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	panel.add_theme_stylebox_override("panel", _box(PANEL, accent.darkened(0.45), 12, 16))
	parent.add_child(panel)
	var box := VBoxContainer.new()
	box.add_theme_constant_override("separation", 9)
	panel.add_child(box)
	return box

func _navigate(destination: String) -> void:
	page = destination
	notice = ""
	_render()

func _perform(action: Callable) -> void:
	var result = action.call()
	notice = str(result) if result is String else ""
	_render()

func _menu() -> void:
	var art := Control.new()
	art.set_script(TowerArt)
	art.custom_minimum_size.y = 200
	body.add_child(art)
	_label(body, "塔 境", 48, GOLD).horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	_label(body, "看清代价，选择命运。", 18, MUTED).horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	_label(body, "十层高塔，三扇门，一次不能回头的选择。\n积攒力量，穿过守卫，抵达深渊之心。", 16).horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	var controls := _panel(body, GOLD)
	if game.active():
		_button(controls, "继续旅程  ·  第 %d 层" % int(game.run.floor), func(): _navigate("run"))
	elif not game.run.is_empty():
		_button(controls, "查看上一局结算", func(): _navigate("run"))
	seed_input = LineEdit.new()
	seed_input.placeholder_text = "种子（可留空，或输入数字 / 文字）"
	seed_input.custom_minimum_size.y = 48
	controls.add_child(seed_input)
	_button(controls, "点燃火把  ·  开始新旅程", _start_from_menu)
	_button(controls, "灵魂火种  ·  %d 灵魂" % int(game.meta.souls), func(): _navigate("upgrades"))
	_button(controls, "旅程档案", func(): _navigate("history"))
	_button(controls, "返回新版方格地图原型", func():
		game.save_game()
		get_tree().change_scene_to_file("res://scenes/map_prototype.tscn")
	)
	var guide := _panel(body)
	_label(guide, "登塔须知", 18, GOLD)
	_label(guide, "① 先看房间代价与奖励，再点击进入。\n② 你总是先手，最后一击不会受到反击。\n③ 第 5、10 层必须挑战首领。\n④ 装备自动生效，可叠加；生命归零即结束。\n⑤ 商店只买一件；事件与休息只能二选一。", 14, MUTED)
	_label(guide, "这是可试玩原型。房间、节奏和数值仍需实际试玩校准。", 13, MUTED)

func _start_from_menu() -> void:
	var value := seed_input.text.strip_edges()
	if game.active():
		_confirm("替换当前旅程？", "当前旅程会按放弃结算，不发放灵魂。已获得的局外火种会保留。", func():
			game.abandon()
			_start(value)
		)
	else:
		_start(value)

func _start(seed_text: String) -> void:
	game.start(seed_text)
	page = "run"
	notice = ""
	_render()

func _status() -> void:
	var row := HBoxContainer.new()
	shell.add_child(row)
	_label(row, "塔境  /  第 %02d 层" % int(game.run.floor), 24, GOLD)
	var menu_button := _button(row, "营地", func(): _navigate("menu"))
	menu_button.size_flags_horizontal = Control.SIZE_SHRINK_END
	var p: Dictionary = game.run.player
	var s: Dictionary = game.stats()
	var bar := ProgressBar.new()
	bar.custom_minimum_size.y = 24
	bar.max_value = s.max_hp
	bar.value = p.hp
	bar.show_percentage = false
	bar.add_theme_stylebox_override("background", _box(Color("252632"), Color("252632"), 6, 0))
	bar.add_theme_stylebox_override("fill", _box(TEAL.darkened(0.22) if int(p.hp) > int(s.max_hp) * 0.3 else RED, Color.TRANSPARENT, 6, 0))
	shell.add_child(bar)
	_label(shell, "生命  %d / %d     攻击  %d     防御  %d" % [p.hp, s.max_hp, s.attack, s.defense], 17)
	_label(shell, "金币  %d     钥匙  %d     击杀回血  %d" % [p.gold, p.keys, s.kill_heal], 14, GOLD)
	var route := HBoxContainer.new()
	route.add_theme_constant_override("separation", 4)
	shell.add_child(route)
	for floor_number in range(1, 11):
		var marker := Label.new()
		marker.text = str(floor_number) + (" ◆" if floor_number in [5, 10] else "")
		marker.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
		marker.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		marker.add_theme_font_size_override("font_size", 12)
		marker.add_theme_color_override("font_color", GOLD if floor_number == int(game.run.floor) else (TEAL if floor_number < int(game.run.floor) else MUTED.darkened(0.4)))
		route.add_child(marker)

func _run_body() -> void:
	_label(body, str(game.run.last_message), 14, TEAL)
	match str(game.run.phase):
		"rooms":
			_label(body, "封印之前" if int(game.run.floor) in [5, 10] else "门后的命运", 25, GOLD)
			_label(body, "首领层：击败守卫才能继续。" if int(game.run.floor) in [5, 10] else "选择 1 个房间，结算后前往下一层。向下滚动查看全部选项。", 13, MUTED)
			for index in game.run.room_options.size():
				_room_card(game.run.room_options[index], index)
		"shop": _shop()
		"event", "rest": _event()
		"reward": _rewards()
	_inventory()
	if not game.run.last_report.is_empty():
		_button(body, "查看最近一次战斗详情", func(): _navigate("log"))
	_label(body, "本局种子  " + str(game.run.seed), 12, MUTED)

func _room_card(room: Dictionary, index: int) -> void:
	var accent := RED if room.type in ["elite", "boss"] else (TEAL if room.type == "rest" else GOLD)
	var box := _panel(body, accent)
	_label(box, "%02d  /  %s" % [index + 1, ROOM_NAMES[room.type]], 12, accent)
	var report: Dictionary = game.preview(room)
	var title := str(room.name)
	if not report.is_empty():
		title = str(game.db.enemy(room.enemy_id).name)
	_label(box, title, 22)
	var button_text := "进入房间"
	var disabled := false
	if not report.is_empty():
		var enemy: Dictionary = game.db.enemy(room.enemy_id)
		_label(box, "生命 %d   /   攻击 %d   /   防御 %d" % [enemy.hp, enemy.attack, enemy.defense], 14, MUTED)
		if not str(enemy.ability_id).is_empty():
			_label(box, str(enemy.description), 13, MUTED)
		var hp_text := "会死亡 · 生命归零" if report.lethal else ("净恢复 %d HP" % -int(report.loss) if int(report.loss) < 0 else "预计损失 %d HP" % int(report.loss))
		_label(box, hp_text + "  /  %d 次攻击" % int(report.turns), 18, RED if report.lethal else TEAL)
		_label(box, "胜利奖励：%d 金币" % (int(enemy.gold_reward) + int(game.stats().gold_bonus)), 14, GOLD)
		if not room.get("rewards", []).is_empty():
			_label(box, "胜利后二选一：" + _reward_names(room.rewards), 13, GOLD)
		if room.type == "boss" and int(room.floor) == 5:
			_label(box, "额外奖励：恢复 45 HP（不计入上方战斗净损失）", 13, TEAL)
		if room.type == "boss" and int(room.floor) == 10:
			_label(box, "击败魔像即通关，并获得额外 20 灵魂。", 13, GOLD)
		button_text = "确认挑战 · 会死亡" if report.lethal else "挑战  ·  " + hp_text
	elif room.type == "chest":
		_label(box, room.reward_text, 16, GOLD)
		_label(box, "消耗 %d 把钥匙" % int(room.lock_cost) if int(room.lock_cost) > 0 else "无需钥匙 · 直接领取", 14, MUTED)
		disabled = int(game.run.player.keys) < int(room.lock_cost)
		button_text = "钥匙不足" if disabled else "开启宝箱"
	elif room.type == "shop":
		_label(box, "只可购买 1 件，也可不买离开。进入即锁定本层。", 13, MUTED)
		for id in room.offers:
			var offer: Dictionary = game.db.shop_item(id)
			_label(box, "%s · %s · %d 金币" % [offer.name, offer.description, offer.price], 14, GOLD)
	elif room.type == "event":
		var event: Dictionary = game.db.event(room.event_id)
		_label(box, event.description, 14, MUTED)
		for option in event.options:
			_label(box, "%s：%s" % [option.name, option.description], 14, GOLD)
	else:
		_label(box, "营火仍然温暖。恢复生命，或为接下来的战斗磨砺自己。", 14, MUTED)
		_label(box, "恢复 40 HP  /  或攻击 +3、防御 +1", 16, TEAL)
	_button(box, button_text, func(): _enter_room(index), disabled)

func _reward_names(ids: Array) -> String:
	var names: PackedStringArray = []
	for id in ids:
		var item: Dictionary = game.db.item(id)
		names.append("%s（%s）" % [item.name, item.description])
	return " / ".join(names)

func _enter_room(index: int) -> void:
	var result: String = game.enter_room(index)
	if result == "confirm_lethal":
		_confirm("这场战斗会死亡", "根据当前属性与首领机制，你无法存活。仍要挑战并结束本局吗？", func():
			_perform(func(): return game.enter_room(index, true))
		)
	else:
		notice = result
		_render()

func _shop() -> void:
	_label(body, "烛火商店", 28, GOLD)
	_label(body, "购买后自动前往下一层。黄金剑等效果按购买后的金币重新计算。", 14, MUTED)
	var offers: Array = game.run.selected_room.offers
	for index in offers.size():
		var offer: Dictionary = game.db.shop_item(offers[index])
		var box := _panel(body, GOLD)
		_label(box, offer.name, 21)
		_label(box, offer.description, 15, MUTED)
		var can_buy := int(game.run.player.gold) >= int(offer.price)
		_button(box, "%d 金币 · %s" % [offer.price, "购买并离开" if can_buy else "金币不足"], func(): _perform(func(): return game.buy(index)), not can_buy)
	_button(body, "不购买，前往下一层", func():
		game.leave_shop()
		_render()
	)

func _event() -> void:
	_label(body, str(game.run.selected_room.name), 28, GOLD)
	if game.run.phase == "event":
		_label(body, game.db.event(game.run.selected_room.event_id).description, 16, MUTED)
	var options: Array = game.available_options()
	for index in options.size():
		var option: Dictionary = options[index]
		var box := _panel(body, TEAL)
		_label(box, option.name, 22)
		_label(box, option.description, 16, GOLD)
		var blocked: String = game.option_blocked(option)
		if not blocked.is_empty():
			_label(box, blocked, 13, RED)
		_button(box, "选择并前往下一层", func(): _perform(func(): return game.choose_option(index)), not blocked.is_empty())

func _rewards() -> void:
	_label(body, "战利品 · 二选一", 27, GOLD)
	_label(body, "奖励已经保存，领取后进入下一层。", 14, MUTED)
	for index in game.run.pending_choices.size():
		var item: Dictionary = game.db.item(game.run.pending_choices[index])
		var box := _panel(body, GOLD)
		_label(box, item.name, 22)
		_label(box, item.description, 16, TEAL)
		_button(box, "收下「%s」" % item.name, func(): _perform(func(): return game.choose_reward(index)))

func _inventory() -> void:
	var box := _panel(body)
	_label(box, "行囊与遗物", 17, GOLD)
	var player: Dictionary = game.run.player
	var ids: Array = player.equipment_ids + player.relic_ids
	if ids.is_empty():
		_label(box, "行囊尚空。每一件装备都会自动生效。", 13, MUTED)
	else:
		var counts: Dictionary = {}
		for id in ids:
			counts[id] = int(counts.get(id, 0)) + 1
		for id in counts:
			var item: Dictionary = game.db.item(id)
			_label(box, "%s%s · %s" % [item.name, " ×%d" % counts[id] if counts[id] > 1 else "", item.description], 13, MUTED)
	_label(box, "装备与遗物均可叠加，无槽位限制。最大生命类物品同时恢复增加的生命值。", 11, MUTED)

func _ending() -> void:
	var won := game.run.result == "victory"
	_label(body, "黎明，终于抵达。" if won else ("火把暂时熄灭。" if game.run.result == "death" else "你返回了营地。"), 31, GOLD)
	_label(body, "你穿过了十层高塔。下一次，试试另一条道路。" if won else "留下的灵魂会成为下一次旅程的火种。" if game.run.result == "death" else "放弃旅程不发放灵魂。", 16, MUTED)
	var box := _panel(body, GOLD)
	_label(box, "获得 %d 灵魂" % int(game.run.soul_reward), 26, TEAL)
	_label(box, "抵达第 %d 层  ·  击杀 %d  ·  用时 %.1f 分钟" % [game.run.floor, game.run.kills, float(game.run.played_seconds) / 60.0], 15)
	_label(box, "种子 " + str(game.run.seed), 13, MUTED)
	_button(body, "灵魂火种 · 永久升级", func(): _navigate("upgrades"))
	_button(body, "再试一次 · 相同种子", func(): _start(str(game.run.seed)))
	_button(body, "返回营地 · 新的旅程", func(): _navigate("menu"))
	_label(body, "本局足迹", 19, GOLD)
	for entry in game.run.history:
		_label(body, "%02d 层 · %s" % [entry.floor, entry.summary], 14, MUTED)
	_inventory()
	if not game.run.last_report.is_empty():
		_button(body, "最后一战 · 逐回合记录", func(): _navigate("log"))

func _upgrades() -> void:
	_label(body, "灵魂火种", 32, GOLD)
	_label(body, "可用灵魂  %d" % int(game.meta.souls), 22, TEAL)
	_label(body, "每项最多 3 级，仅对新旅程生效。每级费用依次为 8 / 16 / 24 灵魂。", 14, MUTED)
	if game.active():
		_label(body, "本局进行中。结束或放弃后可升级，避免改变正在进行的旅程。", 14, GOLD)
	var effects := {"hp": "每级：初始最大生命 +5", "attack": "每级：初始攻击 +1", "gold": "每级：初始金币 +5"}
	for id in ["hp", "attack", "gold"]:
		var level := int(game.meta.upgrades[id])
		var box := _panel(body, GOLD)
		_label(box, "%s  %d / 3" % [EngineCore.UPGRADE_NAMES[id], level], 21)
		_label(box, effects[id], 15, MUTED)
		var price: int = game.upgrade_cost(id)
		_button(box, "已达上限" if level >= 3 else "升级 · %d 灵魂" % price,
			func(): _perform(func(): return game.upgrade(id)), game.active() or level >= 3 or int(game.meta.souls) < price)
	_button(body, "返回营地", func(): _navigate("menu"))

func _combat_log() -> void:
	_label(body, "战斗推演", 29, GOLD)
	_button(body, "返回旅程", func(): _navigate("run"))
	var report: Dictionary = game.run.get("last_report", {})
	if report.is_empty():
		_label(body, "还没有战斗记录。", 16, MUTED)
		return
	_label(body, "承受伤害 %d  ·  击杀治疗 %d  ·  净损失 %d" % [report.incoming, report.healing, report.loss], 16, TEAL)
	_label(body, "先手进攻；敌人死亡立即结束。净损失包含击杀治疗，死亡不会触发治疗。", 14, MUTED)
	for entry in report.log:
		var text := "第 %d 击：造成 %d，敌人剩 %d HP。" % [entry.turn, entry.hit, entry.enemy_hp]
		if int(entry.enemy_hp) > 0:
			text += "\n反击 %d，你剩 %d HP。" % [entry.counter, entry.hp]
		if not str(entry.note).is_empty():
			text += "\n" + str(entry.note)
		_label(body, text, 14, MUTED)

func _history() -> void:
	_label(body, "旅程档案", 30, GOLD)
	_label(body, "完成 %d 局  ·  通关 %d 局  ·  最深第 %d 层" % [game.meta.runs, game.meta.wins, game.meta.best_floor], 16, TEAL)
	_label(body, "最近 30 局仅保存在本机，无网络统计。完整路线与用时保存在存档中。", 13, MUTED)
	_button(body, "返回营地", func(): _navigate("menu"))
	if game.meta.records.is_empty():
		_label(body, "塔还在等待第一位旅人。", 17, MUTED)
	var records: Array = game.meta.records.duplicate()
	records.reverse()
	for record in records:
		var box := _panel(body)
		var result_name: String = {"victory": "通关", "death": "倒下", "abandoned": "放弃"}.get(record.result, "结束")
		_label(box, "%s · 第 %d 层 · %d 灵魂" % [result_name, record.floor, record.souls], 18, GOLD)
		_label(box, "种子 %s  /  %.1f 分钟" % [record.seed, float(record.seconds) / 60.0], 13, MUTED)

func _confirm(title: String, text: String, action: Callable) -> void:
	var dialog := ConfirmationDialog.new()
	dialog.title = title
	dialog.dialog_text = text
	dialog.ok_button_text = "确认"
	dialog.cancel_button_text = "取消"
	dialog.dialog_autowrap = true
	add_child(dialog)
	dialog.confirmed.connect(func():
		dialog.queue_free()
		action.call()
	)
	dialog.canceled.connect(dialog.queue_free)
	dialog.popup_centered(Vector2i(mini(int(size.x) - 32, 440), 220))
