extends RefCounted
## Independent versioned campaign recipes. Theme never replaces fixed growth.
const VERSION := 1
const Validator = preload("res://scripts/core/campaign_validator.gd")
const Content = preload("res://scripts/core/content_db.gd")
var config: Dictionary = {}
var content_snapshot: Dictionary = {}
var errors: Array[String] = []
var last_error := ""

func _init() -> void:
	var file := FileAccess.open("res://data/campaign_rules.json", FileAccess.READ)
	if file == null:
		errors.append("无法读取十层规则。")
		return
	var parsed = JSON.parse_string(file.get_as_text())
	if parsed is Dictionary:
		config = parsed
	else:
		errors.append("十层规则格式错误。")

func plan(seed_text: String) -> Dictionary:
	last_error = _configuration_error()
	if not last_error.is_empty():
		return {}
	var random := RandomNumberGenerator.new()
	random.seed = (seed_text + ":campaign:1").hash()
	var floors := {}
	var previous := -1
	for number in range(1, 11):
		var template := random.randi_range(0, 5)
		if template == previous:
			template = (template + 1) % 6
		previous = template
		floors[str(number)] = {"template_id": template, "floor_seed": str(random.randi()),
			"fixed_equipment": config.fixed_equipment.get(str(number), []).duplicate(),
			"reward_budget":config.floor_budgets[number-1].duplicate()}
	return {"version": VERSION, "floors": floors, "budget": config.budget.duplicate(true)}

func generate(plan_data: Dictionary, number: int, theme: String, boss_choice: String = "") -> Dictionary:
	last_error = _configuration_error()
	if not last_error.is_empty():
		return {}
	if number < 1 or number > 10 or not plan_data.get("floors", {}).has(str(number)):
		last_error = "战役楼层计划不存在。"
		return {}
	var recipe: Dictionary = plan_data.floors[str(number)]
	if not recipe.get("reward_budget") is Array or recipe.reward_budget.size() != 2:
		last_error = "战役楼层奖励预算无效。"
		return {}
	var floor_map := {"floor": number, "name": config.floor_names[number - 1], "theme": theme,
		"entry": [5,9], "exit": [5,1], "entities": {}, "rows": [], "branch_paths": [],
		"generator_version": VERSION, "floor_seed": recipe.floor_seed,
		"template_id": int(recipe.template_id), "boss_floor": number in [5,10]}
	var cells: Dictionary = {}
	if number in [5,10]:
		_boss(floor_map, cells, number)
	else:
		_geometry(floor_map,cells,int(recipe.template_id))
		_put(floor_map, [5,9], {"type":"camp" if number == 1 else "down", "name":"营地入口" if number == 1 else "下行楼梯", "description":"提灯照亮来路。"})
		_put(floor_map, [5,1], {"type":"up", "name":"上行楼梯"})
		_normal(floor_map, recipe, number, theme, boss_choice)
	for y in range(11):
		var row := ""
		for x in range(11):
			row += "." if cells.has(Vector2i(x,y)) else "#"
		floor_map.rows.append(row)
	var problems: Array = Validator.validate(floor_map)
	var opportunities := count_opportunities(floor_map)
	if opportunities.equipment > int(recipe.reward_budget[0]) or opportunities.relic > int(recipe.reward_budget[1]):
		problems.append("楼层奖励超过全塔预留预算。")
	if not problems.is_empty():
		last_error = "; ".join(problems)
		return {}
	return floor_map

func _geometry(map: Dictionary, cells: Dictionary, variant: int) -> void:
	map.safe_slots = {"event":[5,7],"shop":[5,5],"rest":[5,3],"key":[5,4]}
	var anchors: Array = [[5,8,-1,4],[5,6,1,4],[5,4,-1,4],[5,2,1,4]]
	if variant == 4:
		_line(cells,Vector2i(5,9),Vector2i(7,9))
		_line(cells,Vector2i(7,9),Vector2i(7,1))
		_line(cells,Vector2i(7,1),Vector2i(5,1))
		anchors = [[7,8,1,2],[7,6,-1,6],[7,4,-1,6],[7,2,1,2]]
		map.safe_slots = {"event":[7,7],"shop":[7,5],"rest":[7,3],"key":[7,4]}
	elif variant == 5:
		_line(cells,Vector2i(5,9),Vector2i(5,7))
		_line(cells,Vector2i(5,7),Vector2i(3,7))
		_line(cells,Vector2i(3,7),Vector2i(3,3))
		_line(cells,Vector2i(3,3),Vector2i(5,3))
		_line(cells,Vector2i(5,3),Vector2i(5,1))
		anchors = [[5,8,1,4],[3,6,-1,2],[3,4,-1,2],[5,2,1,4]]
		map.safe_slots = {"event":[5,7],"shop":[3,5],"rest":[5,3],"key":[3,4]}
	else:
		_line(cells,Vector2i(5,9),Vector2i(5,1))
		if variant in [1,2,3]:
			anchors = [[5,8,-1,4],[5,6,-1,4],[5,4,-1,4],[5,2,-1,4]]
			var rings: Array = [[1,3]] if variant == 1 else ([[1,3],[7,9]] if variant == 2 else [[3,7]])
			for ring in rings:
				_line(cells,Vector2i(5,ring[0]),Vector2i(9,ring[0]))
				_line(cells,Vector2i(9,ring[0]),Vector2i(9,ring[1]))
				_line(cells,Vector2i(9,ring[1]),Vector2i(5,ring[1]))
	for anchor in anchors:
		var branch: Array = []
		for distance in range(1,int(anchor[3])+1):
			var cell := Vector2i(int(anchor[0])+int(anchor[2])*distance,int(anchor[1]))
			cells[cell] = true
			branch.append([cell.x,cell.y])
		map.branch_paths.append(branch)

func _line(cells: Dictionary, from: Vector2i, to: Vector2i) -> void:
	var step := Vector2i(signi(to.x-from.x),signi(to.y-from.y))
	var cell := from
	cells[cell] = true
	while cell != to:
		cell += step
		cells[cell] = true

func count_opportunities(map: Dictionary) -> Dictionary:
	var content = Content.new()
	if not content_snapshot.is_empty():
		content.data = content_snapshot
	var result := {"equipment":0,"relic":0,"merchants":0,"rests":0,"events":0}
	for entity in map.entities.values():
		var ids: Array = []
		match str(entity.type):
			"chest": ids.append(entity.item_id)
			"choice": ids.append_array(entity.choices)
			"shop":
				result.merchants += 1
				for id in entity.offers:
					var offer: Dictionary = content.shop_item(str(id))
					if offer.has("item_id"): ids.append(offer.item_id)
			"rest": result.rests += 1
			"event":
				result.events += 1
				for option in content.event(entity.event_id).get("options", []):
					if option.has("item_id"): ids.append(option.item_id)
		for id in ids:
			var kind: String = str(content.item(str(id)).get("kind", ""))
			if kind in result: result[kind] += 1
	return result

func _configuration_error() -> String:
	# Validate shapes before indexing. Full references and plan consistency are checked
	# by CampaignSave before a candidate replaces the previous run.
	if config.get("version", -1) != VERSION:
		return "不支持的战役规则版本。"
	for field in ["floor_names","floor_budgets","normal_templates"]:
		if not config.get(field) is Array or config[field].size() != (6 if field == "normal_templates" else 10):
			return "战役规则缺少完整的 %s。" % field
	for pair in config.floor_budgets:
		if not pair is Array or pair.size() != 2:
			return "战役楼层奖励预算无效。"
		for amount in pair:
			if not _count(amount):
				return "战役楼层奖励预算必须为非负整数。"
	for field in ["budget","fixed_equipment","event_floors","elite_floors","themes","enemy_overrides"]:
		if not config.get(field) is Dictionary:
			return "战役规则字典无效：%s。" % field
	for ids in config.fixed_equipment.values():
		if not ids is Array:
			return "固定成长列表无效。"
	for field in ["merchant_floors","rest_floors","theme_relic_floors"]:
		if not config.get(field) is Array:
			return "战役设施位置列表无效。"
	for enemy_id in config.enemy_overrides:
		if not config.enemy_overrides[enemy_id] is Dictionary:
			return "战役怪物覆盖配置无效。"
		for field in config.enemy_overrides[enemy_id]:
			var value = config.enemy_overrides[enemy_id][field]
			if (field == "name" and not value is String) or (field != "name" and (field not in ["hp","attack","defense","gold_reward"] or not _count(value))):
				return "战役怪物属性配置无效。"
	return ""

func _count(value: Variant) -> bool:
	return (value is int or value is float) and is_finite(float(value)) and float(value) >= 0 and float(value) == floorf(float(value))

func _normal(map: Dictionary, recipe: Dictionary, number: int, theme: String, boss_choice: String) -> void:
	var fixed: Array = recipe.fixed_equipment
	for i in range(fixed.size()):
		_guarded(map, i, "slime" if number == 1 else "sentinel", {"type":"chest", "name":"固定军械", "item_id":fixed[i], "gold":0, "fixed_growth":true})
	if number == 1:
		_guarded(map, 2, "knight", {"type":"chest", "name":"王权指环", "item_id":"sovereign_ring", "gold":10, "objective":true})
		_guarded(map, 3, "bat", _choice(["blood_sword","gold_sword"]))
		return
	if number == 2:
		_guarded(map, 0, "skeleton", _choice(["hunter_bow","tower_shield"]))
	if number == 6:
		_guarded(map, 0, "warlock", {"type":"chest", "name":"封印另一侧的军械", "item_id":"obsidian_mail" if boss_choice == "dawn_spear" else "dawn_spear", "gold":0, "fixed_growth":true})
	if _at_floor(config.merchant_floors,number):
		_put(map, map.safe_slots.shop, {"type":"shop", "name":"巡塔商人", "offers":["buy_bow","buy_shield","buy_potion"] if number == 3 else ["buy_chalice","buy_pendant","buy_potion"], "purchased":false})
	if _at_floor(config.rest_floors,number):
		_put(map, map.safe_slots.rest, {"type":"rest", "name":"提灯休息处", "options":[{"name":"养精蓄锐","description":"恢复 70 HP","effects":{"heal":70}},{"name":"加固提灯","description":"最大生命 +20，恢复 20 HP","effects":{"max_hp":20,"heal":20}}]})
	if config.event_floors.has(str(number)):
		_put(map, map.safe_slots.event, {"type":"event", "name":"塔中回声", "event_id":config.event_floors[str(number)]})
	if config.elite_floors.has(str(number)):
		_guarded(map, 1, config.elite_floors[str(number)], _choice(["wolf_fang","stone_heart"] if number == 4 else ["sun_emblem","guardian_oath"]))
	elif number in [6,7]:
		_guarded(map, 1, "warlock", _choice(["crimson_chalice","merchant_seal"]))
	else:
		_guarded(map, 1, "bat" if number < 5 else "warlock", {"type":"gold", "name":"守卫金币", "amount":35})
	if theme == "battle":
		var reward: Dictionary = _choice(["wolf_fang","blood_sword"] if number < 5 else ["sun_emblem","guardian_oath"]) if _at_floor(config.theme_relic_floors,number) else {"type":"gold", "name":"守军军饷", "amount":55}
		_guarded(map, 2, "sentinel" if number < 5 else "knight", reward)
		_guarded(map, 3, "skeleton" if number < 5 else "warlock", {"type":"gold", "name":"战利品", "amount":40})
	elif theme == "treasure":
		var kind: String = ["copper","silver","gold"][number % 3]
		_put(map, map.safe_slots.key, {"type":"key", "name":"宝库钥匙", "key_kind":kind, "amount":1})
		var branch: Array = map.branch_paths[2]
		_put(map, branch[0], {"type":"door", "name":"宝库门", "key_kind":kind, "cost":1})
		var reward: Dictionary = _choice(["gold_sword","stone_heart"] if number < 5 else ["merchant_seal","guardian_oath"]) if _at_floor(config.theme_relic_floors,number) else {"type":"gold", "name":"封印宝藏", "amount":55}
		_put(map, branch[-1], reward)
		_put(map, map.branch_paths[3][-1], {"type":"gold", "name":"古代金币", "amount":60})
	else:
		_put(map, map.branch_paths[2][-1], {"type":"potion", "name":"备用药剂", "amount":45})
		_put(map, map.branch_paths[3][-1], {"type":"gold", "name":"旅人补给金", "amount":45})
	if fixed.is_empty() and number not in [2,6]:
		_guarded(map, 0, "skeleton" if number < 5 else "sentinel", {"type":"potion", "name":"守卫补给", "amount":35})

func _boss(map: Dictionary, cells: Dictionary, number: int) -> void:
	var path: Array = []
	if number == 5:
		for y in range(9, 0, -1):
			path.append([5,y])
	else:
		path = [[5,9],[5,8],[4,8],[3,8],[3,7],[3,6],[3,5],[4,5],[5,5],[6,5],[7,5],[7,4],[7,3],[7,2],[6,2],[5,2],[5,1]]
	for point in path:
		cells[Vector2i(point[0],point[1])] = true
	map.template_id = "boss_gate" if number == 5 else "boss_seal"
	_put(map, [5,9], {"type":"down", "name":"撤退楼梯"})
	_put(map, [5,5], {"type":"enemy", "name":"牛头守卫" if number == 5 else "魔王 · 深渊魔像", "enemy_id":"minotaur" if number == 5 else "golem", "campaign_boss":true})
	_put(map, [5,1], {"type":"up" if number == 5 else "summit", "name":"封印出口" if number == 5 else "王子囚笼", "description":"公主与王子共同打破了封印。"})
	if number == 5:
		var reward := _choice(["dawn_spear","obsidian_mail"])
		reward.campaign_boss_reward = true
		_put(map, [5,3], reward)

func _choice(ids: Array) -> Dictionary:
	return {"type":"choice", "name":"封印宝匣 · 二选一", "choices":ids, "gold":0}

func _at_floor(numbers: Array, number: int) -> bool:
	for value in numbers:
		if int(value) == number:
			return true
	return false

func _guarded(map: Dictionary, branch_index: int, enemy: String, reward: Dictionary) -> void:
	var branch: Array = map.branch_paths[branch_index]
	_put(map, branch[0], {"type":"enemy", "name":"支路守卫", "enemy_id":enemy,
		"guardian":bool(reward.get("objective",false)),
		"role":"return_guard_gate" if reward.get("objective",false) else ("weapon_trial_gate" if reward.get("fixed_growth",false) else "campaign_branch")})
	_put(map, branch[-1], reward)

func _put(map: Dictionary, pos: Array, entity: Dictionary) -> void:
	entity.pos = pos.duplicate()
	entity.id = "f%d:%d,%d" % [int(map.floor),int(pos[0]),int(pos[1])]
	map.entities["%d,%d" % [int(pos[0]),int(pos[1])]] = entity

