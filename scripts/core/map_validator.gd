class_name MapValidator
extends RefCounted
## Validates freshly generated maps. Cleared/saved maps keep their original links
## for diagnostics, but are not re-generated or revalidated as fresh maps.

const SIZE := 11
const DB = preload("res://scripts/core/content_db.gd")
const Keys = preload("res://scripts/core/map_keys.gd")
const Enemies = preload("res://scripts/core/enemy_rules.gd")
const Rewards = preload("res://scripts/core/rewards.gd")
var db = DB.new()

func validate(floor_state: Dictionary) -> Array[String]:
	var problems: Array[String] = []
	for field in ["rows", "entities", "entry", "exit", "guard_links"]:
		if not floor_state.has(field):
			problems.append("地图缺少字段：" + field)
	if not problems.is_empty():
		return problems
	if not floor_state.rows is Array or floor_state.rows.size() != SIZE:
		return ["地图行数必须为 11。"]
	var walkable: Dictionary = {}
	for y in SIZE:
		var row := str(floor_state.rows[y])
		if row.length() != SIZE:
			return ["地图列数必须为 11。"]
		for x in SIZE:
			var tile := row.substr(x, 1)
			if tile not in ["#", "."]:
				return ["地图含未知地形。"]
			if x in [0, SIZE - 1] or y in [0, SIZE - 1]:
				if tile != "#":
					return ["地图边界必须闭合。"]
			if tile == ".":
				walkable[key(Vector2i(x, y))] = true
	if not valid_position(floor_state.entry) or not valid_position(floor_state.exit):
		return ["楼梯坐标无效。"]
	var entrance := key(point(floor_state.entry))
	var exit_key := key(point(floor_state.exit))
	if entrance == exit_key or not walkable.has(entrance) or not walkable.has(exit_key):
		return ["入口和出口必须处于不同的通路格。"]
	if flood(floor_state, {}).size() != walkable.size():
		problems.append("存在与入口不连通的通路。")
	if not floor_state.entities is Dictionary:
		return ["实体列表无效。"]
	var blockers: Dictionary = {}
	var enemy_count := 0
	var roles: Dictionary = {}
	var key_count := {"copper": 0, "silver": 0, "gold": 0}
	var door_cost := {"copper": 0, "silver": 0, "gold": 0}
	for cell in floor_state.entities:
		var entity: Dictionary = floor_state.entities[cell]
		if not valid_position(entity.get("pos", [])) or cell != key(point(entity.pos)) or not walkable.has(cell):
			problems.append("物件坐标无效：" + str(cell))
			continue
		var role := str(entity.get("role", ""))
		if roles.has(role):
			problems.append("地图用途标签重复：" + role)
		roles[role] = entity
		match str(entity.get("type", "")):
			"enemy":
				enemy_count += 1
				blockers[cell] = true
				if not db.data.enemies.has(str(entity.get("enemy_id", ""))):
					problems.append("未知敌人。")
				elif not Enemies.valid_placement(db.enemy(str(entity.enemy_id)), entity):
					problems.append("怪物与支路职责或强度档不匹配：" + role)
			"door":
				blockers[cell] = true
				var key_kind := Keys.kind(entity)
				if key_kind not in Keys.TYPES:
					problems.append("未知门类型。")
				else:
					door_cost[key_kind] += int(entity.get("cost", 0))
				if int(entity.get("cost", 0)) != 1:
					problems.append("当前版本的门应消耗一把钥匙。")
			"key":
				var key_kind := Keys.kind(entity)
				if key_kind not in Keys.TYPES:
					problems.append("未知钥匙类型。")
				elif int(entity.get("amount", 0)) <= 0:
					problems.append("钥匙数量必须大于零。")
				else:
					key_count[key_kind] += int(entity.get("amount", 0))
			"chest":
				if not db.data.items.has(str(entity.get("item_id", ""))):
					problems.append("未知宝箱奖励。")
			"choice":
				var choices: Array = entity.get("choices", [])
				if choices.size() != 2 or choices[0] == choices[1]:
					problems.append("奖励需要两个不同候选。")
				for id in choices:
					if not db.data.items.has(str(id)):
						problems.append("未知选择奖励。")
				if not Rewards._count(entity.get("gold", -1)):
					problems.append("奖励金币无效。")
			"event":
				if not db.data.events.has(str(entity.get("event_id", ""))):
					problems.append("未知事件。")
			"rest":
				if not entity.get("options") is Array or entity.options.size() != 2:
					problems.append("休息点选项无效。")
			"shop":
				var offers: Array = entity.get("offers", [])
				var unique: Dictionary = {}
				for id in offers:
					unique[id] = true
					if not db.data.shop.has(id):
						problems.append("未知商店商品。")
				if offers.size() != 3 or unique.size() != 3:
					problems.append("商店需要三件不同商品。")
			"gold", "potion":
				if int(entity.get("amount", 0)) <= 0:
					problems.append("补给数量必须大于零。")
			"camp", "up", "down", "summit":
				pass
			_:
				problems.append("未知地图物件。")
	var theme_id := str(floor_state.get("theme", ""))
	if enemy_count != int(Enemies.THEME_COUNTS.get(theme_id, -1)):
		problems.append("怪物数量不符合当前楼层主题。")
	if theme_id == "entrance":
		if roles.get("return_guard_gate", {}).get("enemy_id", "") != "knight":
			problems.append("入口层必须保留回溯骑士。")
		if roles.get("return_guard_reward", {}).get("item_id", "") != "sovereign_ring" or not roles.get("return_guard_reward", {}).get("objective", false):
			problems.append("回溯骑士必须守护试炼目标宝箱。")
	else:
		if roles.get("weapon_trial_gate", {}).get("enemy_id", "") != "slime" or roles.get("weapon_trial_reward", {}).get("item_id", "") != "dawn_spear":
			problems.append("第二层必须保留史莱姆守护的成长长枪。")
		if roles.get("armor_trial_gate", {}).get("type", "") != "door" or roles.get("armor_trial_reward", {}).get("item_id", "") != "knight_plate":
			problems.append("第二层必须保留锁门板甲支路。")
	var safe := flood(floor_state, blockers)
	if not safe.has(exit_key):
		problems.append("普通层的楼梯路线被怪物或门堵住。")
	for key_kind in Keys.TYPES:
		if int(key_count[key_kind]) < int(door_cost[key_kind]):
			problems.append("本层%s数量不足，无法开启对应的门。" % Keys.key_name(key_kind))
	for cell in floor_state.entities:
		var entity: Dictionary = floor_state.entities[cell]
		if entity.get("type", "") in ["key", "shop"] and not safe.has(cell):
			problems.append("钥匙或商人不在安全可达区域。")
		if blockers.has(cell):
			var gate := point(entity.pos)
			var approachable := false
			for direction in [Vector2i.UP, Vector2i.RIGHT, Vector2i.DOWN, Vector2i.LEFT]:
				approachable = approachable or safe.has(key(gate + direction))
			if not approachable:
				problems.append("支路守卫无法从主路安全接近。")
	var linked_gates: Dictionary = {}
	for link in floor_state.guard_links:
		var gate_key := key(point(link.gate))
		var reward_key := key(point(link.reward))
		linked_gates[gate_key] = true
		if not blockers.has(gate_key) or not floor_state.entities.has(reward_key):
			problems.append("守卫与奖励的关联丢失。")
		var role := str(link.get("role", ""))
		if floor_state.entities.get(gate_key, {}).get("role", "") != role + "_gate" or floor_state.entities.get(reward_key, {}).get("role", "") != role + "_reward":
			problems.append("守卫与奖励必须属于同一支路。")
		if flood(floor_state, {gate_key: true}).has(reward_key):
			problems.append("可以绕过守卫直接领取奖励。")
	if linked_gates.size() != blockers.size():
		problems.append("存在未关联奖励的怪物或门。")
	var expected_entry := "camp" if int(floor_state.get("floor", 1)) == 1 else "down"
	var expected_exit := "up" if int(floor_state.get("floor", 1)) == 1 else "summit"
	if floor_state.entities.get(entrance, {}).get("type", "") != expected_entry:
		problems.append("入口标记不正确。")
	if floor_state.entities.get(exit_key, {}).get("type", "") != expected_exit:
		problems.append("出口标记不正确。")
	return problems

static func key(cell: Vector2i) -> String:
	return "%d,%d" % [cell.x, cell.y]

static func point(value: Array) -> Vector2i:
	return Vector2i(int(value[0]), int(value[1]))

static func valid_position(value: Variant) -> bool:
	return value is Array and value.size() == 2 and int(value[0]) >= 0 and int(value[0]) < SIZE and int(value[1]) >= 0 and int(value[1]) < SIZE

static func flood(floor_state: Dictionary, blocked: Dictionary) -> Dictionary:
	var start := point(floor_state.entry)
	var visited: Dictionary = {}
	if blocked.has(key(start)):
		return visited
	var queue: Array[Vector2i] = [start]
	visited[key(start)] = true
	var index := 0
	while index < queue.size():
		var current: Vector2i = queue[index]
		index += 1
		for direction in [Vector2i.UP, Vector2i.RIGHT, Vector2i.DOWN, Vector2i.LEFT]:
			var next: Vector2i = current + direction
			var next_key := key(next)
			if next.x < 0 or next.y < 0 or next.x >= SIZE or next.y >= SIZE:
				continue
			if visited.has(next_key) or blocked.has(next_key) or str(floor_state.rows[next.y]).substr(next.x, 1) == "#":
				continue
			visited[next_key] = true
			queue.append(next)
	return visited
