extends RefCounted
## Campaign-specific sheets use the host's established accessible widgets.
const Art = preload("res://scripts/ui/runtime_art.gd")
const Combat = preload("res://scripts/core/combat.gd")
const Progress = preload("res://scripts/core/campaign_progress.gd")
const Board = preload("res://scripts/ui/grid_board.gd")

static func story(ui, event: Dictionary) -> void:
	var lines: Array = event.get("lines", [])
	if lines.is_empty():
		ui._text(ui.body, "传声石恢复了安静。", 18)
		return
	var line: Dictionary = lines[mini(ui.story_line, lines.size() - 1)]
	var speaker := str(line.get("speaker", "旁白"))
	var path := ""
	if "公主" in speaker:
		path = "res://assets/characters/hero/dialogue/textures/hero_dialogue_neutral_v01.png"
	elif "王子" in speaker:
		path = "res://assets/story/phase2/prince_dialogue.png"
	elif "魔王" in speaker:
		path = "res://assets/story/phase2/demon_dialogue.png"
	var texture: Texture2D = Art.texture(path) if not path.is_empty() else null
	if texture != null:
		var portrait := TextureRect.new()
		portrait.texture = texture
		portrait.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
		portrait.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
		portrait.custom_minimum_size.y = 160 if ui.compact else 300
		portrait.mouse_filter = Control.MOUSE_FILTER_IGNORE
		ui.body.add_child(portrait)
	ui._text(ui.body, "%s  ·  %d / %d" % [speaker, ui.story_line + 1, lines.size()], 17, ui.GOLD)
	ui._text(ui.body, str(line.get("text", "")), 19)
	if event.get("static_summary", false):
		ui._text(ui.body, "上次旅程的回声 · 仅回顾，不重复结算", 13, ui.MUTED)

static func floor_index(ui) -> void:
	ui._text(ui.body, "登上第十层，击败魔王并救出王子。" if ui._is_campaign() else "取得王权指环，完成两层回溯试炼。", 17, ui.GOLD)
	ui._text(ui.body, "楼层索引只展示信息。沿已打通的楼梯返回；金点表示你标记的目标。", 14, ui.MUTED)
	var floors: Dictionary = ui.game.state.floors
	for number in range(1, 11 if ui._is_campaign() else 3):
		var id := str(number)
		if not floors.has(id):
			ui._text(ui.body, "%02d 层 · 尚未到达" % number, 14, ui.MUTED)
			continue
		var floor_data: Dictionary = floors[id]
		var enemies := 0
		var rewards := 0
		var shops := 0
		var sold := 0
		var rests := 0
		for entity in floor_data.entities.values():
			match str(entity.get("type", "")):
				"enemy": enemies += 1
				"choice", "chest", "event": rewards += 1
				"rest": rests += 1
				"shop":
					shops += 1
					if entity.get("purchased", false): sold += 1
		var card = ui._panel(ui.body)
		ui._text(card, "%02d 层 · %s%s" % [number, floor_data.get("name", "魔塔"), " · 当前" if number == int(ui.game.state.floor) else ""], 17, ui.GOLD)
		ui._text(card, "未清守卫 %d · 待领 %d · 休息点剩余 %d\n商人 %d / 已售罄 %d" % [enemies, rewards, rests, shops, sold], 14, ui.MUTED)
		var pinned: Dictionary = ui._floor_pins(number)
		for key in pinned:
			var entity: Dictionary = floor_data.entities.get(key, {})
			var pin: Dictionary = pinned[key]
			var copy := "已完成"
			if not entity.is_empty():
				copy = "尚未领取"
				if entity.get("type", "") == "enemy":
					var report := Combat.simulate(ui.game.state.player, ui.game.db.enemy(entity.enemy_id), ui.game.stats())
					copy = "当前致死" if report.lethal else "损失 %d → %d HP" % [int(pin.get("loss", report.loss)), int(report.loss)]
			ui._text(card, "◆ %s (%s) · %s" % [pin.get("name", "目标"), key, copy], 14, ui.TEAL)
		ui._button(card, "查看本层地图" if ui.index_floor != number else "收起地图", func():
			ui.index_floor = -1 if ui.index_floor == number else number
			ui._populate_sheet()
		)
		if ui.index_floor == number:
			var preview = Board.new()
			preview.custom_minimum_size = Vector2(220, 240)
			preview.size_flags_horizontal = Control.SIZE_EXPAND_FILL
			card.add_child(preview)
			preview.mouse_filter = Control.MOUSE_FILTER_IGNORE
			preview.setup(floor_data, ui.game.position() if number == int(ui.game.state.floor) else Vector2i(-5,-5), Vector2i(-1,-1), true, ui.game.db.data.enemies)
			preview.marked_cells = pinned.keys()

static func result(ui) -> void:
	var result_id := str(ui.game.state.get("result", "death"))
	ui.overlay_title.text = {"victory":"营救成功 · 一起回家", "death":"归途灯亮了", "abandoned":"旅程已结束"}.get(result_id, "旅程回顾")
	if result_id == "victory":
		var texture := Art.texture("res://assets/story/phase2/rescue_ending.png")
		if texture != null:
			var illustration := TextureRect.new()
			illustration.texture = texture
			illustration.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
			illustration.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
			illustration.custom_minimum_size.y = 140 if ui.compact else 240
			ui.body.add_child(illustration)
	ui._text(ui.body, str(ui.game.state.last_message), 17, ui.TEAL)
	var settlement: Dictionary = ui.game.state.get("settlement", {})
	if not settlement.is_empty():
		ui._text(ui.body, "本次灵魂 +%d · 账户 %d" % [settlement.get("souls", 0), ui.game.meta.get("souls", 0)], 20, ui.GOLD)
		ui._text(ui.body, "普通 %d ×2 / 精英 %d ×2 / Boss %d ×5 / 通关 +%d" % [settlement.get("regular", 0), settlement.get("elite", 0), settlement.get("boss", 0), settlement.get("victory_bonus", 0)], 13, ui.MUTED)
	var metrics: Dictionary = ui.game.state.get("metrics", {})
	ui._text(ui.body, "到达 %d 层 · 击败 %d 名守卫\n累计受伤 %d · 治疗 %d · 溢出 %d\n步数 %d · 回溯 %d · 消费 %d 金币" % [int(ui.game.state.floor), ui.game.state.get("defeated_entities", []).size(), metrics.get("damage_taken", 0), metrics.get("healing", 0), metrics.get("overflow", 0), metrics.get("steps", 0), metrics.get("backtrack_steps", 0), metrics.get("gold_spent", 0)], 15)
	ui._text(ui.body, "种子 " + str(ui.game.state.seed), 13, ui.MUTED)
	var route: Array[String] = []
	for number in range(1, 11):
		if ui.game.state.floors.has(str(number)):
			var theme_id := str(ui.game.state.floors[str(number)].get("theme", ""))
			route.append("%d层 %s" % [number, {"entrance":"王庭入口", "battle":"战斗", "treasure":"宝藏", "shop":"商店", "boss":"首领"}.get(theme_id, "固定")])
	ui._text(ui.body, " → ".join(route), 13, ui.MUTED)
	ui._button(ui.body, "查看地图复盘", func(): ui._open_overlay("floors"))
	ui._button(ui.body, "查看本局装备", func(): ui._open_overlay("inventory"))
	ui._button(ui.body, "同种子再次营救", func(): ui._start_campaign(str(ui.game.state.seed)), ui._transaction_pending(), "PrimaryButton")
	ui._button(ui.body, "新旅程 · 随机种子", func(): ui._start_campaign(""), ui._transaction_pending())
	ui._button(ui.body, "返回营地 · 调整火种", func():
		ui.page = "menu"
		ui._render(true)
	)

static func upgrades(ui) -> void:
	var meta: Dictionary = ui.game.meta
	var card = ui._panel(ui.body)
	ui._text(card, "归途火种 · 灵魂 %d" % meta.get("souls", 0), 21, ui.GOLD)
	ui._text(card, "旅程结束后可调整，下一次十层旅程生效。两层试炼不应用火种。", 14, ui.MUTED)
	ui._text(card, "王子回声记录 %d 次 · 营救成功 %d 次" % [meta.get("failure_count", 0), meta.get("wins", 0)], 14, ui.TEAL)
	var initial: Dictionary = Progress.initial_player(meta)
	ui._text(card, "下次出发：生命 %d · 攻击 %d · 防御 %d · 金币 %d" % [initial.hp, initial.attack, initial.defense, initial.gold], 14)
	var blocked: bool = (ui._is_campaign() and ui.game.active()) or ui._transaction_pending()
	if ui._is_campaign() and ui.game.active():
		ui._text(card, "本局进行中，结束后可购买或重置。", 14, ui.GOLD)
	for kind in ["hp", "attack", "gold"]:
		var level := int(meta.get("upgrades", {}).get(kind, 0))
		var cost := 8 * (level + 1)
		ui._text(card, "%s %d / 3" % [{"hp":"生命火种 · 每级 +5 生命", "attack":"锋芒火种 · 每级 +1 攻击", "gold":"财富火种 · 每级 +5 金币"}[kind], level], 15)
		var caption := "已满级" if level >= 3 else "消耗 %d 灵魂 · 升至 %d 级（余额 %d）" % [cost, level + 1, maxi(0, int(meta.get("souls",0)) - cost)]
		ui._button(card, caption, func():
			ui.notice = ui.game.purchase_upgrade(kind)
			ui._render(true)
		, blocked or level >= 3 or int(meta.get("souls",0)) < cost)
	var spend: Dictionary = meta.get("upgrade_spend", {})
	var refund := int(spend.get("hp", 0)) + int(spend.get("attack", 0)) + int(spend.get("gold", 0))
	ui._button(card, "免费重置全部火种 · 返还 %d 灵魂" % refund, func():
		ui._confirm("重置火种？", "返还 %d 灵魂，账户余额变为 %d。下一局恢复为 100 生命 / 10 攻 / 5 防 / 0 金币。" % [refund, int(meta.get("souls",0)) + refund], func():
			ui.notice = ui.game.reset_upgrades()
			ui._render(true)
		)
	, blocked or refund == 0)
	var records: Array = meta.get("records", [])
	if not records.is_empty():
		ui._text(card, "最近旅程", 17, ui.GOLD)
		for index in range(records.size() - 1, maxi(-1, records.size() - 6), -1):
			var record: Dictionary = records[index]
			var label: String = {"victory":"营救成功", "death":"战败归营", "abandoned":"主动放弃"}.get(str(record.get("result", "")), "旅程结束")
			ui._text(card, "%s · 第 %d 层 · 灵魂 +%d\n种子 %s" % [label, record.get("floor", 1), record.get("souls", 0), record.get("seed", "")], 13, ui.MUTED)

static func settings(ui, parent: Node) -> void:
	var card = ui._panel(parent)
	ui._text(card, "声音与显示", 19, ui.GOLD)
	_toggle(ui, card, "全部静音", "muted")
	_toggle(ui, card, "播放受罚语音", "punishment_voice")
	_toggle(ui, card, "减少动效", "reduce_motion")
	for kind in ["effects_volume", "voice_volume"]:
		ui._text(card, "效果音音量" if kind == "effects_volume" else "语音音量", 14, ui.MUTED)
		var slider := HSlider.new()
		slider.min_value = 0
		slider.max_value = 1
		slider.step = 0.05
		slider.value = ui.settings.get(kind)
		slider.custom_minimum_size.y = 36
		card.add_child(slider)
		slider.value_changed.connect(func(value):
			ui.settings.set(kind, value)
			ui._save_preferences()
		)
	ui._text(card, "剧情始终保留字幕。效果音与受罚人声均为合成原型；可独立调节音量或关闭受罚语音。", 13, ui.MUTED)

static func _toggle(ui, parent: Node, label: String, property: String) -> void:
	var checkbox := CheckButton.new()
	checkbox.text = label
	checkbox.custom_minimum_size.y = 44
	checkbox.button_pressed = ui.settings.get(property)
	parent.add_child(checkbox)
	checkbox.toggled.connect(func(value):
		ui.settings.set(property, value)
		if (property == "muted" and value) or (property == "punishment_voice" and not value):
			ui.audio.stop()
		if property == "reduce_motion" and value and is_instance_valid(ui.board):
			if is_instance_valid(ui.feedback_tween):
				ui.feedback_tween.kill()
			ui.board.modulate = Color.WHITE
		ui._save_preferences()
	)
