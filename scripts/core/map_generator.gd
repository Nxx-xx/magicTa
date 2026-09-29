class_name MapGenerator
extends RefCounted
## A local RNG per (version, run seed, floor, theme); walking and previous choices
## never consume this RNG. Persist the returned map, never regenerate on re-entry.

const Validator = preload("res://scripts/core/map_validator.gd")
const Keys = preload("res://scripts/core/map_keys.gd")
const VERSION := 3
const SUPPORTED_VERSIONS := [1, 2, 3]
const SIZE := 11
var config: Dictionary = {}
var reward_config: Dictionary = {}
var errors: Array[String] = []
var last_error := ""
var validator = Validator.new()

func _init() -> void:
	var file := FileAccess.open("res://data/random_maps.json", FileAccess.READ)
	if file == null:
		errors.append("无法读取随机地图配置。")
		return
	var parsed = JSON.parse_string(file.get_as_text())
	if not parsed is Dictionary:
		errors.append("随机地图配置不是有效 JSON。")
		return
	config = parsed
	for field in ["version", "size", "templates", "recipes", "themes", "shop_pools", "safe_gold", "safe_heal", "max_attempts"]:
		if not config.has(field):
			errors.append("随机配置缺少字段：" + field)
	if not errors.is_empty():
		return
	if int(config.version) != 2 or int(config.size) != SIZE or config.templates.is_empty():
		errors.append("不支持的随机地图版本或尺寸。")
	var reward_file := FileAccess.open("res://data/reward_rules.json", FileAccess.READ)
	if reward_file == null:
		errors.append("无法读取奖励配置。")
		return
	var rewards = JSON.parse_string(reward_file.get_as_text())
	if not rewards is Dictionary:
		errors.append("奖励配置格式错误。")
		return
	reward_config = rewards
	for field in ["relic_choices", "direct_relics", "vault_choices", "event_pool", "shop_supply", "rest_options"]:
		if not reward_config.get(field) is Array or reward_config[field].is_empty():
			errors.append("奖励配置缺少有效列表：" + field)
	if not errors.is_empty():
		return
	for field in ["relic_choices", "direct_relics", "vault_choices"]:
		var unique: Dictionary = {}
		for id in reward_config[field]:
			unique[id] = true
			if not validator.db.data.items.has(str(id)):
				errors.append("未知奖励物品：" + str(id))
		if unique.size() != reward_config[field].size() or unique.size() < 2:
			errors.append("奖励候选不足或重复：" + field)
	for id in reward_config.direct_relics:
		if id not in reward_config.relic_choices:
			errors.append("直接属性遗物必须属于遗物候选池。")
	for id in reward_config.event_pool:
		if not validator.db.data.events.has(str(id)):
			errors.append("未知奖励事件。")
	for id in reward_config.shop_supply:
		if not validator.db.data.shop.has(str(id)):
			errors.append("未知补给商品。")

func generate(run_seed: String, floor_number: int, theme_id: String, generation_version: int = VERSION) -> Dictionary:
	last_error = ""
	if not errors.is_empty():
		last_error = "\n".join(errors)
		return {}
	if generation_version not in SUPPORTED_VERSIONS:
		last_error = "不支持的地图生成器版本。"
		return {}
	if floor_number not in [1, 2] or not config.themes.has(theme_id):
		last_error = "当前生成器只用于两层地图原型。"
		return {}
	if (floor_number == 1) != (theme_id == "entrance"):
		last_error = "楼层与主题不匹配。"
		return {}
	var random := RandomNumberGenerator.new()
	var seed_value := floor_seed(run_seed, floor_number, theme_id, generation_version)
	random.seed = seed_value
	var attempts := clampi(int(config.max_attempts), 1, 32)
	for attempt in attempts:
		var template: Dictionary = _pick(config.templates, random)
		var symmetry := random.randi_range(0, 7)
		var candidate := _build(template, floor_number, theme_id, symmetry, random, generation_version)
		if candidate.is_empty():
			continue
		var problems: Array[String] = validator.validate(candidate)
		if problems.is_empty():
			last_error = ""
			candidate.generator = {"version": generation_version, "seed": str(seed_value),
				"template": template.id, "symmetry": symmetry, "attempt": attempt + 1}
			return candidate
		last_error = "；".join(problems)
	last_error = "随机地图未通过检查（%d 次）：%s" % [attempts, last_error]
	return {}

static func floor_seed(run_seed: String, number: int, theme_id: String, generation_version: int = VERSION) -> int:
	# Explicit 31-bit hash; no floating point or process-randomized hash function.
	var text := "%d|%s|%d|%s" % [generation_version, run_seed, number, theme_id]
	var value: int = 17
	for index in text.length():
		value = (value * 131 + text.unicode_at(index)) % 2147483647
	return value

static func transform(cell: Array, symmetry: int) -> Array:
	var x := int(cell[0])
	var y := int(cell[1])
	if symmetry >= 4:
		x = SIZE - 1 - x
	for turn in symmetry % 4:
		var previous_x := x
		x = SIZE - 1 - y
		y = previous_x
	return [x, y]

func _build(template: Dictionary, number: int, theme_id: String, symmetry: int, random: RandomNumberGenerator, generation_version: int) -> Dictionary:
	var theme: Dictionary = config.themes[theme_id]
	var result := {"rows": _transform_rows(template.rows, symmetry), "entities": {},
		"floor": number, "theme": theme_id, "name": theme.name + " · " + template.name,
		"entry": transform(template.entry, symmetry), "exit": transform(template.exit, symmetry),
		"guard_links": []}
	var incoming := {"type": "camp" if number == 1 else "down", "name": "入口营地" if number == 1 else "返回第一层",
		"description": "已探索的地图永久保存，可以自由往返。", "role": "entry"}
	var outgoing := {"type": "up" if number == 1 else "summit", "name": "通往第二层" if number == 1 else "未完的阶梯",
		"description": "首次上楼选择主题。" if number == 1 else "两层原型到此。可以回一层挑战强敌并领取奖励。", "role": "exit"}
	if not _place(result, incoming, template.entry, symmetry) or not _place(result, outgoing, template.exit, symmetry):
		return {}
	var branches := _shuffle(template.branches, random)
	var recipes: Array = theme.recipes
	if branches.size() != recipes.size():
		last_error = "支路数量与主题配方不符。"
		return {}
	var needed_keys: Array[String] = []
	for index in recipes.size():
		var role := str(recipes[index])
		var recipe: Dictionary = config.recipes[role]
		var branch: Dictionary = branches[index]
		var gate_pos: Array = _pick(branch.gates, random)
		var reward_pos: Array = _pick(branch.rewards, random)
		var gate: Dictionary = {}
		if recipe.gate == "door":
			var key_kind := str(recipe.get("key_kind", "copper")) if generation_version >= 2 else "copper"
			if key_kind not in Keys.TYPES:
				last_error = "未知钥匙类型：" + key_kind
				return {}
			gate = {"type": "door", "name": "支路铜锁门", "cost": 1}
			if generation_version >= 2:
				gate.key_kind = key_kind
				gate.name = Keys.door_name(key_kind)
			needed_keys.append(key_kind)
		elif recipe.gate == "enemy":
			gate = {"type": "enemy", "name": "回溯强敌" if recipe.get("guardian", false) else "支路守卫",
				"enemy_id": _pick(recipe.enemy_pool, random), "guardian": recipe.get("guardian", false)}
		if not gate.is_empty():
			gate.role = role + "_gate"
			if not _place(result, gate, gate_pos, symmetry):
				return {}
			result.guard_links.append({"gate": transform(gate_pos, symmetry), "reward": transform(reward_pos, symmetry), "role": role})
		var reward := {"type": recipe.reward, "name": "支路奖励", "role": role + "_reward"}
		if recipe.reward == "chest":
			reward.name = "回溯试炼宝箱" if recipe.get("objective", false) else "支路宝箱"
			reward.item_id = _pick(recipe.item_pool, random)
			reward.gold = _roll(recipe.gold, random)
			reward.objective = recipe.get("objective", false)
		else:
			reward.amount = _roll(recipe.amount, random)
			reward.name = "疗愈药剂" if recipe.reward == "potion" else "守卫钱袋"
		if not _place(result, reward, reward_pos, symmetry):
			return {}
	var safe_slots := _shuffle(template.safe_slots, random)
	if theme_id == "shop":
		var shop_pos: Array = _pick(template.shop_slots, random)
		safe_slots.erase(shop_pos)
		var offers: Array = []
		for pool in config.shop_pools:
			offers.append(_pick(pool, random))
		if not _place(result, {"type": "shop", "name": "烛火商人", "role": "merchant",
			"offers": offers, "purchased": false}, shop_pos, symmetry):
			return {}
	if safe_slots.size() < needed_keys.size() + 2:
		last_error = "安全补给位置不足。"
		return {}
	for index in needed_keys.size():
		var key_entity := {"type": "key", "name": "通用钥匙", "amount": 1, "role": "safe_key_%d" % index}
		if generation_version >= 2:
			key_entity.key_kind = needed_keys[index]
			key_entity.name = Keys.key_name(needed_keys[index])
		if not _place(result, key_entity, safe_slots.pop_back(), symmetry):
			return {}
	if not _place(result, {"type": "gold", "name": "散落钱币", "role": "safe_gold",
		"amount": _roll(config.safe_gold, random)}, safe_slots.pop_back(), symmetry):
		return {}
	if not _place(result, {"type": "potion", "name": "小型药剂", "role": "safe_potion",
		"amount": _roll(config.safe_heal, random)}, safe_slots.pop_back(), symmetry):
		return {}
	if generation_version >= 3:
		_upgrade_rewards(result, random)
	return result

func _upgrade_rewards(result: Dictionary, random: RandomNumberGenerator) -> void:
	# Apply after legacy placement so versions 1/2 retain their exact draw order.
	for entity in result.entities.values():
		match str(entity.get("role", "")):
			"relic_fight_reward", "treasure_vault_reward":
				var pool: Array = reward_config.relic_choices if entity.role == "relic_fight_reward" else reward_config.vault_choices
				var first: String = str(_pick(reward_config.direct_relics if entity.role == "relic_fight_reward" else pool, random))
				var remaining := pool.duplicate()
				remaining.erase(first)
				entity.type = "choice"
				entity.name = "遗物二选一" if entity.role == "relic_fight_reward" else "宝库二选一"
				entity.choices = [first, _pick(remaining, random)]
				entity.erase("item_id")
			"open_chest_reward":
				entity.type = "event"
				entity.event_id = _pick(reward_config.event_pool, random)
				entity.name = validator.db.event(entity.event_id).get("name", "未知事件")
				entity.erase("item_id")
				entity.erase("gold")
			"healing_branch_reward":
				if result.theme == "shop":
					entity.type = "rest"
					entity.name = "旅人休息点"
					entity.options = reward_config.rest_options.duplicate(true)
					entity.erase("amount")
			"merchant":
				entity.offers[2] = _pick(reward_config.shop_supply, random)

func _place(result: Dictionary, entity: Dictionary, cell: Array, symmetry: int) -> bool:
	var pos := transform(cell, symmetry)
	var id := "%d,%d" % [int(pos[0]), int(pos[1])]
	if result.entities.has(id):
		last_error = "随机物件位置重叠。"
		return false
	entity.pos = pos
	result.entities[id] = entity
	return true

func _transform_rows(rows: Array, symmetry: int) -> Array:
	var output: Array = []
	for y in SIZE:
		output.append("#".repeat(SIZE))
	for y in SIZE:
		for x in SIZE:
			if str(rows[y]).substr(x, 1) == ".":
				var pos := transform([x, y], symmetry)
				var line := str(output[int(pos[1])])
				output[int(pos[1])] = line.substr(0, int(pos[0])) + "." + line.substr(int(pos[0]) + 1)
	return output

func _pick(values: Array, random: RandomNumberGenerator) -> Variant:
	return values[random.randi_range(0, values.size() - 1)]

func _roll(bounds: Array, random: RandomNumberGenerator) -> int:
	return random.randi_range(int(bounds[0]), int(bounds[1]))

func _shuffle(values: Array, random: RandomNumberGenerator) -> Array:
	var result := values.duplicate(true)
	for index in range(result.size() - 1, 0, -1):
		var swap := random.randi_range(0, index)
		var held = result[index]
		result[index] = result[swap]
		result[swap] = held
	return result
