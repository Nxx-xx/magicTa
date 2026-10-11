extends "res://scripts/ui/paged_catalog.gd"
## Keep discovery filtering in view_rows; only discovered entries reach the widgets.
const Progress = preload("res://scripts/core/phase3_progress.gd")
const ChallengePanel = preload("res://scripts/ui/phase3_challenge_panel.gd")
const EnemyMapArt = preload("res://scripts/ui/phase3_enemy_map_art.gd")
const RuinArt = preload("res://scripts/ui/phase3_ruin_art.gd")
var enemy_art := EnemyMapArt.new()
var ruin_art := RuinArt.new()
var account: Dictionary = {}
var catalog: Dictionary = {}
var challenge_id := "p3_c0"
var rows: Array = []
var category_ids: Array = []

func setup(meta: Dictionary, content: Dictionary, challenge: String = "p3_c0") -> void:
	account = Progress.migrate_meta(meta)
	catalog = content.duplicate(true)
	challenge_id = challenge
	var values: Array = []
	category_ids = Progress.definitions().unlocks.codex_categories.keys()
	for category in category_ids:
		var entries: Array = []
		var source := view_rows(account,catalog,category,challenge_id)
		for index in source.size():
			var row: Dictionary = source[index]
			var value := {"id":str(index),"name":row.title,"detail":row.detail,"readonly":true,
				"icon":{"enemies":"sword","items":"relic","ruins":"lamp","story":"book","achievements":"shield"}.get(category,"book"),
				"image":row.get("illustration",""),"thumbnail":row.get("illustration","")}
			if category == "items" and row.has("entry_id"):
				value.item = catalog.items[row.entry_id]
			elif category == "enemies" and row.has("entry_id"):
				value.preview_texture = enemy_art.texture(str(row.entry_id), 0.0, true)
				if value.preview_texture == null:
					value.preview_texture = Art.enemy_static(str(row.entry_id))
			elif category == "ruins" and row.has("entry_id"):
				value.preview_texture = ruin_art.texture({"ruin_id":row.entry_id,"status":"available"}, 0.0, true)
			elif not row.has("entry_id"):
				value.icon = "book"
			if row.get("icon", "") in ["p3_c0", "p3_c1", "p3_c2", "default", "p3_vanguard", "p3_keeper", "p3_trader"]:
				value.thumbnail = "res://assets/ui/phase3/progression/%s.png" % row.icon
			entries.append(value)
		values.append({"name":Progress.definitions().unlocks.codex_categories[category].name,"entries":entries})
	present_categories(values,"旅途图鉴 · 点击条目查看详情")
	rows = view_rows(account,catalog,"enemies",challenge_id)

func show_category(category: String) -> void:
	var index := category_ids.find(category)
	if index < 0: return
	category_index = index
	_entries = categories[index].entries.duplicate(true)
	rows = view_rows(account,catalog,category,challenge_id)
	_list_page = 0
	show_overview()

static func view_rows(meta: Dictionary, content: Dictionary, category: String, challenge: String = "p3_c0") -> Array:
	var account_meta := Progress.migrate_meta(meta)
	if not Progress.validate_meta_extensions(account_meta).ok:
		return [{"title":"图鉴暂不可用", "detail":"账户扩展校验失败。"}]
	var codex: Dictionary = account_meta.codex
	var result: Array = []
	var defs := Progress.definitions()
	if category == "achievements":
		for id in defs.unlocks.unlocks:
			var rule: Dictionary = defs.unlocks.unlocks[id]
			var rec: Dictionary = account_meta.achievement_records.get(id, {})
			var complete: bool = id in account_meta.achievement_ids
			result.append({"title":rule.name + (" · 已完成" if complete else " · 未完成"),
				"detail":rule.description + ("\n%s · 旅程 %s" % [rec.get("completed_at", "日期未记录"), rec.get("run_id", "旧账户认可")] if complete else ""), "icon":rule.icon})
		return result
	var field: String = {"enemies":"seen_enemies", "items":"seen_items", "ruins":"seen_ruins", "story":"seen_story_nodes"}.get(category, "")
	if field.is_empty():
		return []
	var entries: Dictionary = content.get(category, {})
	var hidden := 0
	var scaled: Dictionary = Progress.apply_challenge({"enemies":content.get("enemies", {})}, challenge)
	for id in entries:
		if id not in codex[field]:
			hidden += 1
			continue
		var entry: Dictionary = entries[id]
		var detail := str(entry.get("description", entry.get("text", "")))
		if category == "story" and entry.get("lines") is Array:
			for line in entry.lines:
				if line is Dictionary:
					detail += "\n%s：%s" % [line.get("speaker", "旁白"), line.get("text", "")]
		if category == "enemies":
			detail += "\n基准：生命 %d / 攻击 %d / 防御 %d" % [entry.get("hp",0),entry.get("attack",0),entry.get("defense",0)]
			if scaled.ok:
				var enemy: Dictionary = scaled.content.enemies[id]
				detail += "\n当前难度：生命 %d / 攻击 %d / 防御 %d" % [enemy.hp, enemy.attack, enemy.get("defense",0)]
			for rec in codex.enemy_records.values():
				if rec.enemy_id == id:
					var challenge_name: String = defs.challenges.challenges.get(rec.challenge_id, {}).get("name", "旅程")
					detail += "\n%s%s：击败 %d 次，%d 次受伤记录" % ["旧旅程 · " if rec.combat_rules_version == 1 else "", challenge_name, rec.count, rec.samples]
					if rec.samples > 0:
						detail += "，最低原始受伤 %d" % rec.min_incoming
		elif category == "items":
			var rec: Dictionary = codex.item_records.get(id, {"count":0,"sources":[]})
			var sources: Array[String] = []
			for source in rec.sources:
				sources.append({"chest":"宝箱","choice":"奖励选择","shop":"商店","boss":"首领奖励"}.get(source,"探索"))
			detail += "\n取得 %d 次 · 来源 %s" % [rec.count, "、".join(sources)]
			if entry.has("tags"):
				detail += "\n联动：" + "、".join(entry.tags)
		elif category == "ruins":
			var rec: Dictionary = codex.ruin_records.get(id, {"count":0,"options":[]})
			var inscriptions: Array[String] = []
			for selected in rec.options:
				for option in entry.get("options", []):
					if option.id == selected: inscriptions.append(str(option.name))
			detail += "\n使用 %d 次 · 历史铭文 %s" % [rec.count, "、".join(inscriptions)]
		var row := {"entry_id":id,"title":str(entry.get("name", "已发现条目")), "detail":detail}
		if entry.get("illustration", "") is String and not str(entry.get("illustration", "")).is_empty():
			row.illustration = entry.illustration
		result.append(row)
	if hidden > 0:
		result.append({"title":defs.unlocks.codex_categories[category].hidden, "detail":"还有 %d 项尚未发现。" % hidden})
	if result.is_empty():
		result.append({"title":"旅途尚待书写", "detail":"发现后会在这里留下记录。"})
	return result
