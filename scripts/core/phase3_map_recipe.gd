extends RefCounted
## Apply only to a freshly generated, uncommitted map. No RNG or content mutation.
const Validator = preload("res://scripts/core/campaign_validator.gd")
const Ruins = preload("res://scripts/core/phase3_ruins.gd")
const EVENTS := {2:["library","p3_oath_ruin"],6:["forge","p3_oath_forge"],9:["hermit","p3_lantern_sanctuary"]}
const VARIANTS := {
	"p3_shield_sentinel":{"floors":[3,4],"source":"sentinel"},
	"p3_ember_channeler":{"floors":[6,7],"source":"warlock"},
	"p3_vault_knight":{"floors":[8,9],"source":"knight"}}
const FIRST := ["p3_dawn_sigil","p3_lantern_aegis","p3_bounty_ledger"]
const FALLBACK := ["sun_emblem","guardian_oath","spring_seed"]
const FLOOR_BUDGETS := [[3,2],[2,2],[3,0],[1,2],[2,0],[1,4],[1,2],[1,3],[0,2],[0,0]]

static func decorate_floor(floor_map: Dictionary, content: Dictionary, context: Dictionary) -> Dictionary:
	var error := _input_error(floor_map, content, context)
	if not error.is_empty():
		return _error(error)
	var map: Dictionary = floor_map.duplicate(true)
	var number := int(context.floor)
	var defs: Dictionary = context.get("ruin_definitions", {})
	if defs.is_empty():
		defs = Ruins.definitions()
	var valid := Ruins.validate_definitions(defs)
	if not valid.ok:
		return valid
	var reserved: Array = context.used_unique_ids.duplicate()
	var new_unique: Array = []
	var report := {"event":"","theme_choices":[],"variant":"","variant_skip":"","geometry":"existing","geometry_fallback":""}
	if EVENTS.has(number):
		var key := _key(map.safe_slots.event)
		var event: Dictionary = map.entities.get(key, {})
		if event.get("type") != "event" or event.get("event_id") != EVENTS[number][0]:
			return _error("原事件安全槽不匹配；禁止覆盖其他实体。")
		var ruin_id: String = EVENTS[number][1]
		event.event_id = ruin_id
		event.name = defs[ruin_id].name
		event.ruin_id = ruin_id
		event.rules_version = 1
		event.status = "available"
		event.selected_option = ""
		event.transaction_id = ""
		report.event = ruin_id
	if number in [2,6] and context.theme in ["battle","treasure"]:
		var branch: Array = map.branch_paths[2]
		var reward: Dictionary = map.entities.get(_key(branch[-1]), {})
		if reward.get("type") != "choice" or reward.get("fixed_growth", false) or reward.get("choices", []).size() != 2:
			return _error("主题支路原两候选槽无效。")
		var desired: Array
		if number == 2:
			desired = ["p3_dawn_sigil" if context.theme == "battle" else "p3_lantern_aegis", "p3_bounty_ledger"]
		else:
			desired = ["p3_rhythm_blade" if context.theme == "battle" else "p3_thorn_clasp", "p3_gilded_lantern"]
		var choices := []
		for id in desired:
			if (id in FIRST or id in context.unlocked_ids) and id not in reserved and _relic(content, id):
				choices.append(id)
				reserved.append(id)
				new_unique.append(id)
			else:
				for fallback in FALLBACK:
					if fallback not in choices and _relic(content, fallback):
						choices.append(fallback)
						break
		if choices.size() != 2:
			return _error("缺少合法的两件遗物候选，不能删除奖励以凑预算。")
		reward.choices = choices
		report.theme_choices = choices.duplicate()
	var plan: Dictionary = context.variant_plan
	var variant: String = plan.get(str(number), "")
	if not variant.is_empty():
		if not content.enemies.get(variant) is Dictionary:
			return _error("变体不在本局内容快照中。")
		# Only the two theme branches qualify, and only their original guard role.
		for index in [2,3]:
			var guard: Dictionary = map.entities.get(_key(map.branch_paths[index][0]), {})
			if guard.get("type") == "enemy" and guard.get("role") == "campaign_branch" and guard.get("enemy_id") == VARIANTS[variant].source and not guard.get("guardian", false):
				guard.enemy_id = variant
				guard.name = content.enemies[variant].get("name", variant)
				report.variant = variant
				break
		if report.variant.is_empty():
			report.variant_skip = "主题没有符合原敌人类型的可选守卫槽。"
	if context.get("geometry", "existing") == "ruin_spokes":
		var geometry := _spokes(map, int(context.get("orientation", 0)))
		if geometry.ok:
			map = geometry.floor_map
			report.geometry = "ruin_spokes"
		else:
			report.geometry_fallback = geometry.error
	var issues: Array = Validator.validate(map)
	issues.append_array(_guard_errors(map))
	if not issues.is_empty():
		return _error("变换后几何非法：" + "; ".join(issues))
	var merged := content.duplicate(true)
	merged.events.merge(Ruins.event_definitions(defs), true)
	var budget := opportunity_counts(map, merged)
	if not budget.ok:
		return budget
	if budget.counts.equipment > FLOOR_BUDGETS[number - 1][0] or budget.counts.relic > FLOOR_BUDGETS[number - 1][1]:
		return _error("变换后物品机会超过原楼层预算。")
	map.phase3_recipe = {"version":1,"report":report,"new_unique_ids":new_unique,
		"opportunities":budget.counts,"direct_effect_budget":Ruins.direct_effect_budget(defs).per_ruin.get(report.event, {})}
	return {"ok":true,"error":"","floor_map":map,"new_unique_ids":new_unique,"report":report}

static func opportunity_counts(map: Dictionary, content: Dictionary) -> Dictionary:
	var counts := {"equipment":0,"relic":0,"merchants":0,"rests":0,"events":0}
	for entity in map.entities.values():
		var ids := []
		match str(entity.type):
			"chest": ids.append(entity.get("item_id", ""))
			"choice": ids.append_array(entity.get("choices", []))
			"rest": counts.rests += 1
			"shop":
				counts.merchants += 1
				for offer_id in entity.get("offers", []):
					var offer: Dictionary = content.shop.get(offer_id, {})
					if offer.is_empty():
						return _error("未知商店报价。")
					if offer.has("item_id"): ids.append(offer.item_id)
			"event":
				counts.events += 1
				var event: Dictionary = content.events.get(entity.event_id, {})
				if event.is_empty(): return _error("未知事件引用。")
				for option in event.get("options", []):
					if option.has("item_id"): ids.append(option.item_id)
		for id in ids:
			var kind: String = content.items.get(id, {}).get("kind", "")
			if kind not in ["equipment","relic"]:
				return _error("未知奖励物品：" + str(id))
			counts[kind] += 1
	return {"ok":true,"error":"","counts":counts}

static func _input_error(map: Dictionary, content: Dictionary, context: Dictionary) -> String:
	if context.get("freshly_generated", false) != true:
		return "必须显式声明 freshly_generated=true；禁止修改已访问楼层。"
	for field in ["items","enemies","events","shop"]:
		if not content.get(field) is Dictionary: return "内容快照缺少字典：" + field
		for definition in content[field].values():
			if not definition is Dictionary: return "内容定义必须为字典：" + field
	for event in content.events.values():
		if not event.get("options", []) is Array: return "事件选项列表无效。"
		for option in event.get("options", []):
			if not option is Dictionary: return "事件选项必须为字典。"
	for field in ["floor","theme","unlocked_ids","used_unique_ids","variant_plan"]:
		if not context.has(field): return "生成上下文缺少：" + field
	if not _integer(context.floor, 1, 10) or map.get("floor") != context.floor or map.get("theme") != context.theme:
		return "上下文楼层或主题不匹配。"
	if context.theme not in ["battle","treasure","shop","boss","entrance"] or not context.unlocked_ids is Array or not context.used_unique_ids is Array or not context.variant_plan is Dictionary:
		return "生成上下文类型无效。"
	if context.theme == "entrance" and int(context.floor) != 1: return "入口主题仅适用于第一层。"
	for field in ["unlocked_ids","used_unique_ids"]:
		for id in context[field]:
			if not id is String: return "预留与解锁 ID 必须为字符串。"
	var seen := []
	for floor_key in context.variant_plan:
		var id = context.variant_plan[floor_key]
		if not floor_key is String or not id is String or not VARIANTS.has(id) or floor_key not in ["3","4","6","7","8","9"]:
			return "非法变体计划。"
		if int(floor_key) not in VARIANTS[id].floors or id in seen:
			return "变体楼层越界或全塔重复。"
		seen.append(id)
	if context.get("geometry", "existing") not in ["existing","ruin_spokes"] or not _integer(context.get("orientation", 0), 0, 7):
		return "未知几何样板或方向。"
	if context.has("ruin_definitions") and not context.ruin_definitions is Dictionary:
		return "遗迹冻结定义无效。"
	if map.has("phase3_recipe") or map.get("visited", false): return "楼层已装饰或已访问。"
	if not map.get("rows") is Array or map.rows.size() != 11 or not map.get("entities") is Dictionary:
		return "楼层地图结构无效。"
	for row in map.rows:
		if not row is String or row.length() != 11: return "楼层行尺寸无效。"
	for field in ["entry","exit"]:
		if not _point(map.get(field)): return "楼梯坐标无效。"
	if not map.get("boss_floor") is bool or not map.get("branch_paths") is Array:
		return "缺少生产生成器的支路关系。"
	if map.boss_floor != (int(context.floor) in [5,10]): return "Boss 楼层标记不匹配。"
	if not map.boss_floor:
		if not map.get("safe_slots") is Dictionary or map.branch_paths.size() != 4:
			return "缺少生产生成器的安全槽或四支路。"
		for field in ["event","shop","rest","key"]:
			if not _point(map.safe_slots.get(field)): return "安全槽无效。"
	for branch in map.branch_paths:
		if not branch is Array or branch.size() < 2: return "支路结构无效。"
		for point in branch:
			if not _point(point): return "支路坐标无效。"
	var ids := []
	for key in map.entities:
		var entity = map.entities[key]
		if not entity is Dictionary or not _point(entity.get("pos")) or key != _key(entity.pos) or not entity.get("type") is String or not entity.get("id") is String or entity.id in ids:
			return "实体坐标、类型或唯一 ID 无效。"
		ids.append(entity.id)
		if entity.type in ["choice","shop"]:
			var field: String = "choices" if entity.type == "choice" else "offers"
			if not entity.get(field) is Array: return "候选/商店列表无效。"
			for id in entity[field]:
				if not id is String: return "奖励引用 ID 无效。"
		if entity.type in ["chest","event","enemy"]:
			var field: String = {"chest":"item_id","event":"event_id","enemy":"enemy_id"}[entity.type]
			if not entity.get(field) is String: return "实体内容引用无效。"
		for field in ["resolved","taken","defeated","opened","purchased","used"]:
			if entity.get(field, false): return "楼层包含已经消费的实体。"
		if entity.has("status") or entity.has("selected_option"): return "楼层包含旧遗迹状态。"
	var errors: Array = Validator.validate(map)
	errors.append_array(_guard_errors(map))
	return "原生成结果未通过校验：" + "; ".join(errors) if not errors.is_empty() else ""

## Four guarded reward spurs plus one independent ruin spur. Never drops entities.
## Unsupported/interior entities cause a deterministic fallback to the input geometry.
static func _spokes(source: Dictionary, orientation: int) -> Dictionary:
	if source.boss_floor: return _error("Boss 几何保持原样。")
	var map := source.duplicate(true)
	var cells := {}
	for y in range(1,10): cells[Vector2i(5,y)] = true
	for x in range(1,5): cells[Vector2i(x,3)] = true
	var branches := []
	var mapping := {}
	for i in range(4):
		var branch := []
		for x in range(6,10):
			branch.append([x,8-i*2])
			cells[Vector2i(x,8-i*2)] = true
		branches.append(branch)
		mapping[_key(source.branch_paths[i][0])] = branch[0]
		mapping[_key(source.branch_paths[i][-1])] = branch[-1]
	var slots := {"event":[1,3],"shop":[5,5],"rest":[5,3],"key":[5,4]}
	for field in slots: mapping[_key(source.safe_slots[field])] = slots[field]
	mapping[_key(source.entry)] = [5,9]
	mapping[_key(source.exit)] = [5,1]
	var entities := {}
	for old_key in source.entities:
		if not mapping.has(old_key): return _error("样板不容纳支路内部实体：" + str(old_key))
		var entity: Dictionary = source.entities[old_key].duplicate(true)
		entity.pos = _orient(mapping[old_key], orientation)
		var key := _key(entity.pos)
		if entities.has(key): return _error("样板槽冲突，保留原几何。")
		entity.id = "f%d:%s" % [int(map.floor),key]
		entities[key] = entity
	map.entities = entities
	map.entry = _orient([5,9], orientation)
	map.exit = _orient([5,1], orientation)
	map.branch_paths = []
	for branch in branches:
		var transformed := []
		for point in branch: transformed.append(_orient(point, orientation))
		map.branch_paths.append(transformed)
	map.safe_slots = {}
	for field in slots: map.safe_slots[field] = _orient(slots[field], orientation)
	var transformed_cells := {}
	for cell in cells:
		var point := _orient([cell.x,cell.y], orientation)
		transformed_cells[Vector2i(point[0],point[1])] = true
	map.rows = []
	for y in range(11):
		var row := ""
		for x in range(11): row += "." if transformed_cells.has(Vector2i(x,y)) else "#"
		map.rows.append(row)
	map.template_id = "p3_ruin_spokes_%d" % orientation
	var errors: Array = Validator.validate(map)
	errors.append_array(_guard_errors(map))
	return {"ok":true,"error":"","floor_map":map} if errors.is_empty() else _error("; ".join(errors))

## Test each guard alone as a cut point, not just the union of all blockers.
static func _guard_errors(map: Dictionary) -> Array[String]:
	var errors: Array[String] = []
	for branch in map.branch_paths:
		var key := _key(branch[0])
		var guard: Dictionary = map.entities.get(key, {})
		if guard.get("type", "") not in ["enemy","door"]: continue
		var isolated := map.duplicate(true)
		isolated.entities = {key:guard}
		var reached := Validator.reachable(isolated, Vector2i(map.entry[0],map.entry[1]), true)
		if reached.has(Vector2i(branch[-1][0],branch[-1][1])): errors.append("守卫不是对应奖励割点：" + key)
	return errors

static func _orient(point: Array, orientation: int) -> Array:
	var x := int(point[0])
	var y := int(point[1])
	if orientation >= 4: x = 10 - x
	for i in range(orientation % 4):
		var old_x := x
		x = 10 - y
		y = old_x
	return [x,y]

static func _key(point: Array) -> String:
	return "%d,%d" % [int(point[0]),int(point[1])]

static func _point(value: Variant) -> bool:
	return value is Array and value.size() == 2 and _integer(value[0], 0, 10) and _integer(value[1], 0, 10)

static func _integer(value: Variant, low: int, high: int) -> bool:
	return (value is int or value is float) and is_finite(float(value)) and float(value) == floorf(float(value)) and float(value) >= low and float(value) <= high

static func _relic(content: Dictionary, id: String) -> bool:
	return content.items.get(id, {}).get("kind", "") == "relic"

static func _error(message: String) -> Dictionary:
	return {"ok":false,"error":message}
