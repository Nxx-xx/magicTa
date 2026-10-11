extends RefCounted
const Catalog = preload("res://scripts/ui/paged_catalog.gd")
const Floors = preload("res://scripts/ui/floor_browser.gd")
const GrowthTree = preload("res://scripts/ui/camp_growth_tree.gd")
const Progress = preload("res://scripts/core/campaign_progress.gd")
const Build = preload("res://scripts/ui/phase3_build_summary.gd")
const RelicTrail = preload("res://scripts/core/relic_trail.gd")

static func mount(ui, name: String = "ScreenCatalog"):
	var panel := Catalog.new()
	panel.name = name
	ui._mount_choices(panel)
	return panel

static func entry(id: String, name: String, detail: String, icon: String = "book") -> Dictionary:
	return {"id":id,"name":name,"detail":detail,"icon":icon,"readonly":true}

static func inventory(ui) -> void:
	var categories := [{"name":"装备", "entries":[]},{"name":"遗物", "entries":[]}]
	var counts := {}
	for id in ui.game.state.player.equipment_ids + ui.game.state.player.relic_ids: counts[id] = int(counts.get(id,0)) + 1
	var notes := {}
	if ui._is_phase3():
		var summary := Build.describe(ui.game.state.player, ui.game.db.data)
		if summary.ok:
			for row in summary.rows: notes[row.id] = "；".join(row.notes)
	for id in counts:
		var item: Dictionary = ui.game.db.item(id)
		var detail := "%s ×%d\n%s\n%s" % [item.name,counts[id],item.get("description",""),notes.get(id,"")]
		var value := entry(id, "%s ×%d" % [item.name,counts[id]],detail,"relic")
		value.item = item
		value.brief = "%d阶 · 获得即生效" % int(item.get("tier",1))
		categories[1 if item.get("kind","") == "relic" else 0].entries.append(value)
	var stats: Dictionary = ui.game.stats()
	var trail := RelicTrail.journal(ui.game.state)
	if not trail.is_empty(): categories.append({"name":"旅途拾遗", "entries":trail})
	categories.append({"name":"属性与联动", "entries":[entry("stats","当前属性", "生命 %d/%d\n攻击 %d · 防御 %d\n击杀恢复 %d HP\n击杀额外金币 %d\n种子 %s\n%s" % [ui.game.state.player.hp,stats.max_hp,stats.attack,stats.defense,stats.kill_heal,stats.gold_bonus,ui.game.state.seed,ui.game.floor_data().name],"shield")]})
	var panel = mount(ui,"InventoryCatalog")
	panel.back_label = "‹  返回行囊"
	panel.empty_title = "行囊尚轻，旅途未尽"
	panel.present_categories(categories,"获得即生效 · 点击查看效果")

static func floors(ui) -> void:
	var panel := Floors.new()
	panel.name = "FloorBrowser"
	ui._mount_choices(panel)
	panel.setup(ui)

static func records(ui) -> void:
	var entries: Array = RelicTrail.journal(ui.game.state)
	var records: Array = ui.game.meta.get("records",[])
	for index in range(records.size()-1,-1,-1):
		var record: Dictionary = records[index]
		var label: String = {"victory":"已通关","death":"战败归营","abandoned":"主动放弃"}.get(str(record.get("result","")),"旅程结束")
		var copy := "%s · 第 %d 层\n灵魂 +%d\n种子 %s" % [label,record.get("floor",1),record.get("souls",0),record.get("seed","")]
		var value := entry(str(index),"第 %d 次 · %s" % [index+1,label],copy,"log")
		value.brief = "第 %d 层 · 灵魂 +%d" % [record.get("floor",1),record.get("souls",0)]
		entries.append(value)
	var panel = mount(ui,"RecordsCatalog")
	panel.present_choices(entries,"","通关 %d 次 · 王子回声 %d 次" % [ui.game.meta.get("wins",0),ui.game.meta.get("failure_count",0)])
	if not ui.game.state.is_empty() and not ui.game.active(): ui._button(ui.body,"查看上次探索",ui._open_map)

static func log(ui) -> void:
	var report: Dictionary = ui.game.state.last_report
	var panel = mount(ui,"ReportCatalog")
	var entries := RelicTrail.journal(ui.game.state)
	if report.is_empty():
		panel.present_choices(entries,"","尚未发生战斗" if entries.is_empty() else "旅途拾遗 · 已找到的证据与遗物去向")
		return
	var copy := ""
	if ui._is_phase3(): copy = ui.Phase3Player.report_text(report)
	else:
		for turn in report.get("log",[]): copy += "第 %d 击：造成 %d，敌人剩 %d HP；反击 %d。\n" % [turn.turn,turn.hit,turn.enemy_hp,turn.counter]
	var summary := "战斗结果：%s\n战后生命 %d\n生命损失 %d\n总回合 %d" % ["获胜" if report.get("won",false) else "战败",report.get("hp_after",report.get("final_hp",report.get("hp",0))),report.get("loss",0),report.get("log",[]).size()]
	entries.append_array([entry("summary","战斗摘要",summary,"shield"),entry("full","完整战斗过程",copy,"log")])
	panel.present_choices(entries,"","探索证据与最近一战 · 点击查看详情")

static func result(ui) -> void:
	var state: Dictionary = ui.game.state
	var result_id := str(state.get("result","death"))
	ui.overlay_title.text = {"victory":"终章 · 新的主宰","death":"归途灯亮了","abandoned":"旅程已结束"}.get(result_id,"旅程回顾")
	var settlement: Dictionary = state.get("settlement",{})
	var metrics: Dictionary = state.get("metrics",{})
	var detail := "%s\n\n本次灵魂 +%d · 账户 %d\n普通 %d ×2 / 精英 %d ×2 / Boss %d ×5 / 通关 +%d\n\n到达 %d 层 · 击败 %d 名守卫\n累计受伤 %d · 治疗 %d · 溢出 %d\n步数 %d · 回溯 %d · 消费 %d 金币\n种子 %s" % [state.last_message,settlement.get("souls",0),ui.game.meta.get("souls",0),settlement.get("regular",0),settlement.get("elite",0),settlement.get("boss",0),settlement.get("victory_bonus",0),state.floor,state.get("defeated_entities",[]).size(),metrics.get("damage_taken",0),metrics.get("healing",0),metrics.get("overflow",0),metrics.get("steps",0),metrics.get("backtrack_steps",0),metrics.get("gold_spent",0),state.seed]
	var route: Array[String] = []
	for number in range(1,11):
		if state.floors.has(str(number)): route.append("%d 层 · %s" % [number,state.floors[str(number)].get("name","魔塔")])
	detail += "\n\n探索路线\n" + "\n".join(route)
	var record := entry("statistics","本局统计",detail,"log")
	if result_id == "victory": record.image = ui.CampaignPanels.ENDING_REVEAL
	var unlock_copy := "本次没有新增解锁。\n灵魂可在营地升级，也能免费重置。"
	if ui._is_phase3() and not state.get("phase3_new_unlocks",[]).is_empty():
		unlock_copy = "新的旅程选择\n"
		var definitions: Dictionary = state.progress_rules_snapshot
		for id in state.phase3_new_unlocks:
			var definition: Dictionary = definitions.challenges.challenges.get(id,definitions.challenges.start_configs.get(id,state.reward_content.items.get(id,{})))
			unlock_copy += str(definition.get("name","新的旅程纪念")) + "\n"
		unlock_copy += "\n已保存。新难度、起点与藏品池从下一局开始生效。"
	var entries := [record,entry("unlocks","奖励与解锁",unlock_copy,"relic"),{"id":"floors","name":"地图复盘","icon":"map","navigate":true},{"id":"inventory","name":"本局装备","icon":"shield","navigate":true}]
	var panel = mount(ui,"ResultCatalog")
	panel.back_label = "‹  返回结算概况"
	panel.page_size = 4
	panel.present_choices(entries,"","到达 %d 层 · 本次灵魂 +%d\n账户灵魂 %d" % [state.floor,settlement.get("souls",0),ui.game.meta.get("souls",0)])
	panel.option_selected.connect(func(id): ui._open_overlay(id))
	var row := HBoxContainer.new()
	ui.body.add_child(row)
	ui._button(row,"同种子再战",ui._retry_journey,ui._transaction_pending(),"PrimaryButton")
	ui._button(row,"新旅程",func(): ui._start_phase3(""),ui._transaction_pending())
	ui._button(ui.body,"返回营地 · 调整火种",func():
		ui._tutorial_event({"type":"result_hint_closed"},false)
		ui.page = "menu"
		ui.camp_view = ""
		ui._render(true)
	)

static func growth(ui) -> void:
	ui._fit_single_screen()
	var meta: Dictionary = ui.game.meta
	var blocked: bool = (ui._is_campaign() and ui.game.active()) or ui._transaction_pending()
	var kind: String = Progress.KINDS[clampi(ui.camp_upgrade_tab,0,2)]
	var rank: int = ui.camp_growth_level
	if rank > 0:
		var level := int(meta.get("upgrades",{}).get(kind,0))
		var cost: int = Progress.COSTS[rank-1]
		var souls := int(meta.get("souls",0))
		var base: int = {"hp":100,"attack":10,"gold":0}[kind]
		var step: int = {"hp":5,"attack":1,"gold":5}[kind]
		var copy := "%s %d → %d\n本级费用 %d 灵魂\n持有灵魂 %d\n\n" % [{"hp":"初始生命","attack":"初始攻击","gold":"初始金币"}[kind],base+step*(rank-1),base+step*rank,cost,souls]
		var initial: Dictionary = Progress.initial_player(meta)
		copy += "下次出发：生命 %d · 攻击 %d\n防御 %d · 金币 %d\n\n" % [initial.hp,initial.attack,initial.defense,initial.gold]
		var disabled := blocked or rank != level+1 or souls < cost
		if rank <= level: copy += "已点亮 · 下次出发生效"
		elif rank > level+1: copy += "尚未解锁 · 先点亮 %d 级" % (rank-1)
		elif blocked: copy += "本局进行中或等待保存，旅程结束后可点亮。"
		elif souls < cost: copy += "灵魂不足 · 还差 %d" % (cost-souls)
		else: copy += "点亮后剩余 %d 灵魂。下次出发生效。" % (souls-cost)
		var panel = mount(ui,"GrowthDetail")
		panel.back_label = "‹  返回成长树"
		var value := entry(kind,"%s火种 · %d级" % [{"hp":"生命","attack":"锋芒","gold":"财富"}[kind],rank],copy)
		value.readonly = false
		value.disabled = disabled
		value.action = "点亮 %d 级 · %d 灵魂" % [rank,cost] if not disabled else "已点亮" if rank <= level else "暂不可点亮"
		panel.present_choices([value],"","")
		panel.on_back = func(): ui.camp_growth_level = 0; ui._render(true)
		panel._show_detail(kind)
		panel.option_selected.connect(func(_id):
			if ui.modal_open or ui._transaction_pending(): return
			if int(ui.game.meta.get("upgrades",{}).get(kind,0)) + 1 != rank: return
			ui._camp_purchase(kind)
		)
		return
	ui._text(ui.body,"归途火种 · 灵魂 %d" % int(meta.get("souls",0)),20,ui.GOLD)
	ui._text(ui.body,"三条路径可同时修炼 · 点击节点查看详情",13,ui.MUTED)
	var tree := GrowthTree.new()
	tree.name = "GrowthTree"
	tree.font = ui.FONT
	tree.levels = meta.get("upgrades",{}).duplicate()
	tree.size_flags_vertical = Control.SIZE_EXPAND_FILL
	ui.body.add_child(tree)
	tree.node_selected.connect(func(selected,selected_rank):
		ui.camp_upgrade_tab = Progress.KINDS.find(selected)
		ui.camp_growth_level = selected_rank
		ui._render(true)
	)
	var spend: Dictionary = meta.get("upgrade_spend",{})
	var refund := int(spend.get("hp",0))+int(spend.get("attack",0))+int(spend.get("gold",0))
	ui._button(ui.body,"重置火种 · 返还 %d 灵魂" % refund,func():
		ui._confirm("重置火种？","返还 %d 灵魂，账户余额变为 %d。下一局恢复为 100 生命 / 10 攻 / 5 防 / 0 金币。" % [refund,int(meta.get("souls",0))+refund],func():
			ui.notice = ui.game.reset_upgrades()
			ui._render(true)
		)
	,blocked or refund == 0)
