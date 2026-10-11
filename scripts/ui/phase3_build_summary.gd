extends VBoxContainer
## Read-only build explanation; combat comparisons use the caller's frozen simulator.
const Items = preload("res://scripts/core/phase3_items.gd")
const TAG_NAMES := {"assault": "强攻", "guard": "守御", "wealth": "财富"}

static func describe(player: Dictionary, content: Dictionary) -> Dictionary:
	var stats := Items.player_stats(player, content)
	if not stats.ok:
		return stats
	var rows: Array = []
	var tags := {"assault": 0, "guard": 0, "wealth": 0}
	for id in player.equipment_ids + player.relic_ids:
		var item: Dictionary = content.items[id]
		var item_tags: Array = item.get("build_tags", []).duplicate()
		# Old content has no tags: classify its declared effects, never recompute stats.
		if item_tags.is_empty():
			var effects: Dictionary = item.get("effects", {})
			if effects.has("attack"):
				item_tags.append("assault")
			if effects.has("defense") or effects.has("kill_heal") or effects.has("max_hp"):
				item_tags.append("guard")
			if effects.has("gold_attack_step") or effects.has("gold_bonus"):
				item_tags.append("wealth")
		for tag in item_tags:
			tags[tag] += 1
		var notes: Array[String] = []
		for source in stats.effect_sources:
			if source.source_item_id != id:
				continue
			if source.id == "gold_defense_threshold":
				notes.append("当前已生效：防御 +%d" % source.amount if source.active else "当前未生效：需持有 %d 金币" % source.threshold)
			elif source.id == "gold_attack_step":
				var note := "当前持币攻击 +%d；消费后重新计算" % source.amount
				if note not in notes:
					notes.append(note)
		rows.append({"id": id, "name": item.name, "description": item.description,
			"tags": item_tags, "notes": notes, "icon": item.get("icon", "")})
	return {"ok": true, "error": "", "stats": stats, "tags": tags, "rows": rows}

static func reward_comparison(content: Dictionary, player: Dictionary, reward: Dictionary,
		enemy: Dictionary = {}, simulator: Callable = Callable()) -> Dictionary:
	var transaction := Items.resolve(content, player, reward)
	if not transaction.ok:
		return transaction
	var result := {"ok": true, "error": "", "transaction": transaction,
		"text": "攻击 %d（%+d） · 防御 %d（%+d）\n生命 %d/%d（当前 %+d / 上限 %+d） · 金币 %d（%+d）\n实际治疗 %d · 溢出 %d" % [
		transaction.after.attack, transaction.attack_delta, transaction.after.defense, transaction.defense_delta,
		transaction.player.hp, transaction.after.max_hp, transaction.hp_delta, transaction.max_hp_delta,
		transaction.player.gold, transaction.gold_delta, transaction.healing, transaction.overflow]}
	if not enemy.is_empty():
		if not simulator.is_valid():
			return {"ok": false, "error": "标记敌人比较需要本局战斗模拟器。"}
		var before: Variant = simulator.call(player.duplicate(true), enemy.duplicate(true), transaction.before.duplicate(true))
		var after: Variant = simulator.call(transaction.player.duplicate(true), enemy.duplicate(true), transaction.after.duplicate(true))
		if not before is Dictionary or not after is Dictionary:
			return {"ok": false, "error": "战斗预览返回格式无效。"}
		if not before.get("ok", true) or not after.get("ok", true):
			return {"ok": false, "error": str(before.get("error", "")) + str(after.get("error", ""))}
		for field in ["won", "counterattacks", "incoming"]:
			if not before.has(field) or not after.has(field):
				return {"ok": false, "error": "战斗预览缺少比较字段。"}
		result["combat_before"] = before
		result["combat_after"] = after
		result.text += "\n标记敌人：%s → %s\n反击 %d → %d · 受伤 %d → %d" % [
			"可胜" if before.won else "致命", "可胜" if after.won else "致命",
			before.counterattacks, after.counterattacks, before.incoming, after.incoming]
	return result

func present(player: Dictionary, content: Dictionary, comparison: Dictionary = {}) -> void:
	for child in get_children():
		remove_child(child)
		child.queue_free()
	add_theme_constant_override("separation", 12)
	var model := describe(player, content)
	if not model.ok:
		_text(model.error, 18)
		return
	_text("这一局的构筑", 24)
	var directions: Array[String] = []
	for tag in TAG_NAMES:
		if model.tags[tag] > 0:
			directions.append("%s %d" % [TAG_NAMES[tag], model.tags[tag]])
	_text(" · ".join(directions) if not directions.is_empty() else "尚未取得物品", 17)
	_text("标签仅帮助理解已有物品，可以自由混搭。", 14)
	_text("攻击 %d · 防御 %d · 生命 %d/%d" % [model.stats.attack, model.stats.defense, player.hp, model.stats.max_hp], 18)
	for row in model.rows:
		var line := HBoxContainer.new()
		line.add_theme_constant_override("separation", 12)
		add_child(line)
		if not row.icon.is_empty() and ResourceLoader.exists(row.icon):
			var icon := TextureRect.new()
			icon.texture = load(row.icon)
			icon.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
			icon.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
			icon.custom_minimum_size = Vector2(48, 48)
			line.add_child(icon)
		var copy := Label.new()
		copy.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		copy.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
		copy.text = "%s\n%s" % [row.name, row.description]
		if not row.notes.is_empty():
			copy.text += "\n" + "\n".join(row.notes)
		line.add_child(copy)
	if not comparison.is_empty():
		_text("领取预览", 22)
		_text(str(comparison.get("text", comparison.get("error", ""))), 17)

func _text(value: String, font_size: int) -> void:
	var label := Label.new()
	label.text = value
	label.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	label.add_theme_font_size_override("font_size", font_size)
	add_child(label)
