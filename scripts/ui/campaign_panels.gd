extends RefCounted
const CompactScreens = preload("res://scripts/ui/compact_screens.gd")
const SettingsPanel = preload("res://scripts/ui/settings_panel.gd")
## Campaign-specific sheets use the host's established accessible widgets.
const Art = preload("res://scripts/ui/runtime_art.gd")
const Progress = preload("res://scripts/core/campaign_progress.gd")
const Board = preload("res://scripts/ui/grid_board.gd")
const P3Challenges = preload("res://scripts/ui/phase3_challenge_panel.gd")
const P3Codex = preload("res://scripts/ui/phase3_codex_panel.gd")
const P3Items = preload("res://scripts/core/phase3_items.gd")
const P3Enemies = preload("res://scripts/core/phase3_enemies.gd")
const P3Ruins = preload("res://scripts/core/phase3_ruins.gd")
const RelicTrail = preload("res://scripts/core/relic_trail.gd")
const ENDING_REVEAL := "res://assets/story/phase2/prince_monster_reveal_v01.png"
const GrowthTree = preload("res://scripts/ui/camp_growth_tree.gd")
const CampKnightArt = preload("res://scripts/ui/camp_knight_art.gd")
const StoryExpressionArt = preload("res://scripts/ui/story_expression_art.gd")

static func story(ui, event: Dictionary) -> void:
	var lines: Array = event.get("lines", [])
	if lines.is_empty():
		ui._text(ui.body, "传声石恢复了安静。", 18)
		return
	var line: Dictionary = lines[mini(ui.story_line, lines.size() - 1)]
	var speaker := str(line.get("speaker", "旁白"))
	var path := str(line.get("illustration", ""))
	if path.is_empty():
		if "公主" in speaker:
			path = "res://assets/characters/hero/dialogue/textures/hero_dialogue_neutral_v01.png"
		elif "王子" in speaker:
			path = "res://assets/story/phase2/prince_dialogue.png"
		elif "魔王" in speaker:
			path = "res://assets/story/phase2/demon_dialogue.png"
		elif "老骑士" in speaker:
			path = CampKnightArt.PORTRAIT.resource_path
	if is_instance_valid(ui.story_stage) and ui.story_stage.active:
		ui.story_stage.present(event, line, path)
		ui._text(ui.body, speaker, 20, ui.GOLD)
		var dialogue: Label = ui._text(ui.body, str(line.get("text", "")), 19 if ui.compact else 22)
		dialogue.add_theme_font_override("font", ui.FONT)
		dialogue.add_theme_constant_override("line_spacing", 5)
	else:
		_illustration(ui, path, line.has("illustration"), event, line)
		ui._text(ui.body, "%s  ·  %d / %d" % [speaker, ui.story_line + 1, lines.size()], 17, ui.GOLD)
		ui._text(ui.body, str(line.get("text", "")), 19)
	if event.get("static_summary", false):
		ui._text(ui.body, "上次旅程的回声 · 仅回顾，不重复结算", 13, ui.MUTED)

static func _illustration(ui, path: String, scene: bool = false, event: Dictionary = {}, line: Dictionary = {}) -> void:
	var texture: Texture2D = Art.texture(path) if not path.is_empty() else null
	if texture != null:
		var portrait := TextureRect.new()
		portrait.name = "StoryPortrait"
		portrait.texture = texture
		portrait.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
		portrait.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
		portrait.custom_minimum_size.y = (200 if ui.compact else 340) if scene else (160 if ui.compact else 300)
		if not scene and path in [StoryExpressionArt.HERO,StoryExpressionArt.PRINCE,StoryExpressionArt.DEMON]:
			portrait.custom_minimum_size.y = 214 if ui.compact else 300
		portrait.mouse_filter = Control.MOUSE_FILTER_IGNORE
		ui.body.add_child(portrait)
		StoryExpressionArt.present(portrait,path,event,line,ui.story_line,not scene)

static func floor_index(ui) -> void:
	CompactScreens.floors(ui)

static func result(ui) -> void:
	CompactScreens.result(ui)

static func camp_knight(ui) -> void:
	var copy := "塔中每击败一名守卫，归途便会记住你的勇气。旅程结束时，你带回的灵魂能在这里点亮火种。"
	if ui.game.active() and ui._is_campaign():
		copy = "你的旅程还未结束。回到塔里继续探索吧；归营结算后，我才能为你调整火种。"
	elif int(ui.game.meta.get("runs",0)) > 0:
		copy = "你又回来了。生命、锋芒、财富，三条路都可修炼。火种只在下次出发时生效；若想换路，我会免费返还已投入的灵魂。"
	var memory := "你母亲留给你的灯有两根芯。外头那根照路，底下那根记名字。擦灯时，别把它当成灰挑掉。"
	if ui.game.active() and ui._is_campaign() and ui.game.state.get("floors",{}).has("6"):
		memory = "你看见兵库的断剑刻痕了？那是我留下的。我守过那座塔，后来跟着你母亲离开。旧誓里‘归者留名’的下一句，在九层楼梯旁。读完，再决定把灯交给谁。"
	var panel = CompactScreens.mount(ui,"CampKnightDialogue")
	var trail_memory := RelicTrail.knight_memory(ui.game.state)
	if not trail_memory.is_empty(): memory = trail_memory
	var conversation := CompactScreens.entry("story","听老骑士讲述",copy+"\n\n"+memory,"book")
	conversation.image = CampKnightArt.PORTRAIT.resource_path
	conversation.thumbnail = conversation.image
	panel.present_choices([conversation,
		{"id":"growth","name":"修炼火种","icon":"lamp","navigate":true},
		CompactScreens.entry("souls","如何获得灵魂","普通与精英守卫各 2 灵魂，Boss 各 5 灵魂，通关另加 20；战败也结算已击败守卫，主动放弃不获得灵魂。\n\n准备好后，回到营地地图，走向北侧塔口。","gold")],"","神秘的老骑士 · 归途的守望者")
	panel.option_selected.connect(func(_id):
		ui.camp_view = "growth"
		ui.camp_growth_level = 0
		ui._tutorial_event({"type":"camp_embers_viewed"},false)
		ui._render(true)
	)

static func upgrades(ui) -> void:
	CompactScreens.growth(ui)

static func _growth_detail(ui, parent: Node, kind: String, rank: int, blocked: bool) -> void:
	var meta: Dictionary = ui.game.meta
	var level := int(meta.get("upgrades",{}).get(kind,0))
	var souls := int(meta.get("souls",0))
	var names := {"hp":"生命火种", "attack":"锋芒火种", "gold":"财富火种"}
	var effects := {"hp":"初始生命", "attack":"初始攻击", "gold":"初始金币"}
	var base: int = {"hp":100,"attack":10,"gold":0}[kind]
	var step: int = {"hp":5,"attack":1,"gold":5}[kind]
	var cost: int = Progress.COSTS[rank-1]
	var node = ui._panel(parent)
	ui._text(node,"%s · %d 级" % [names[kind],rank],19,ui.GOLD)
	ui._text(node,"%s %d → %d" % [effects[kind],base+step*(rank-1),base+step*rank],17)
	if rank <= level:
		ui._text(node,"已点亮 · 下次出发生效",14,ui.TEAL)
	elif rank > level+1:
		ui._text(node,"尚未解锁 · 先点亮 %d 级" % (rank-1),14,ui.MUTED)
		ui._text(node,"本级费用 %d 灵魂" % cost,14,ui.MUTED)
	else:
		if blocked:
			ui._text(node,"保存完成、旅程结束后可点亮。",14,ui.GOLD)
		elif souls < cost:
			ui._text(node,"灵魂不足 · 还差 %d" % (cost-souls),14,ui.MUTED)
		else:
			ui._text(node,"点亮后剩余 %d 灵魂" % (souls-cost),14,ui.MUTED)
		var buy = ui._button(node,"点亮 %d 级 · %d 灵魂" % [rank,cost],func(): ui._camp_purchase(kind),blocked or souls < cost,"PrimaryButton")
		buy.name = "Purchase_" + kind
	ui._button(node,"收起详情",func():
		ui.camp_growth_level = 0
		var tree = ui.find_child("GrowthTree",true,false)
		if tree != null:
			tree.selected_level = 0
			tree.queue_redraw()
		ui._clear(parent)
	,false,"QuietButton")

static func records(ui) -> void:
	CompactScreens.records(ui)

static func settings(ui, parent: Node, _collapsible: bool = false) -> void:
	ui._fit_single_screen()
	var panel := SettingsPanel.new()
	panel.name = "SettingsPanel"
	parent.add_child(panel)
	panel.setup(ui)

static func phase3_departure(ui, parent: Node) -> void:
	var heading := HBoxContainer.new()
	parent.add_child(heading)
	var portrait := TextureRect.new()
	portrait.texture = preload("res://scripts/ui/camp_death_art.gd").TEXTURE
	portrait.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	portrait.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
	portrait.custom_minimum_size = Vector2(48,48)
	portrait.mouse_filter = Control.MOUSE_FILTER_IGNORE
	heading.add_child(portrait)
	var title = ui._text(heading,"死神 · 旅程准备",19,ui.GOLD)
	title.size_flags_vertical = Control.SIZE_SHRINK_CENTER
	var choices := P3Challenges.new()
	choices.name = "Phase3Departure"
	choices.preparation_only = true
	parent.add_child(choices)
	choices.setup(ui.game.meta)
	choices.select_ids(ui.phase3_challenge, ui.phase3_config)
	ui.phase3_challenge = choices.challenge_id
	ui.phase3_config = choices.config_id
	choices.selection_changed.connect(func(selection):
		ui.phase3_challenge = str(selection.challenge_snapshot.id)
		ui.phase3_config = str(selection.start_config_snapshot.id)
	)
	choices.start_requested.connect(func(_selection, _seed):
		ui._show_camp()
	)
	choices._start.disabled = ui._transaction_pending() or not choices.selection.get("ok", false)

static func codex(ui) -> void:
	# Codex expects an unscaled baseline. Never feed current C1/C2 content back through scaling.
	var baseline: Dictionary = preload("res://scripts/core/content_db.gd").new().data.duplicate(true)
	var rules: Variant = JSON.parse_string(FileAccess.get_file_as_string("res://data/campaign_rules.json"))
	if rules is Dictionary:
		for id in rules.get("enemy_overrides", {}):
			if baseline.enemies.has(id): baseline.enemies[id].merge(rules.enemy_overrides[id], true)
	baseline = P3Items.merge_content(baseline)
	baseline = P3Enemies.merge_content(baseline)
	baseline.ruins = P3Ruins.definitions()
	# Facility discovery is account-wide; never reveal a new run's unvisited story
	# through a ruin ID discovered in a different expedition. Evidence lives in the journal.
	for id in baseline.ruins:
		baseline.ruins[id].description = "第 %d 层的旧远征遗址。每次新旅程可能留下不同勇者的物资与记录；本局已查明的往事可在「记录 / 行囊·旅途拾遗」回看。" % int(baseline.ruins[id].floor)
		for option in baseline.ruins[id].options:
			option.name = {"edge":"冒险改造兵刃","guard":"修整防具","salvage":"回收物资","temper":"付费锻造","sacrifice":"以生命淬炼","restore":"使用救急补给","ward":"装配护具","reserve":"冒险搜集路费","leave":"暂时离开"}.get(option.id,"探索旧物")
	var story: Variant = JSON.parse_string(FileAccess.get_file_as_string("res://data/story.json"))
	baseline.story = story.get("events", {}) if story is Dictionary else {}
	for id in baseline.story:
		baseline.story[id]["name"] = baseline.story[id].get("title", "旅途回声")
	var panel := P3Codex.new()
	panel.name = "Phase3Codex"
	ui._mount_choices(panel)
	panel.setup(ui.game.meta, baseline, ui.phase3_challenge)

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
