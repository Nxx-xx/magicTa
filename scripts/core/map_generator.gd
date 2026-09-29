class_name MapGenerator
extends RefCounted
## A local RNG per (version, run seed, floor, theme); walking and previous choices
## never consume this RNG. Persist the returned map, never regenerate on re-entry.

const Validator = preload("res://scripts/core/map_validator.gd")
const VERSION := 1
const SIZE := 11
var config: Dictionary = {}
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
	if int(config.version) != VERSION or int(config.size) != SIZE or config.templates.is_empty():
		errors.append("不支持的随机地图版本或尺寸。")

func generate(run_seed: String, floor_number: int, theme_id: String) -> Dictionary:
	last_error = ""
	if not errors.is_empty():
		last_error = "\n".join(errors)
		return {}
	if floor_number not in [1, 2] or not config.themes.has(theme_id):
		last_error = "当前生成器只用于两层地图原型。"
		return {}
	if (floor_number == 1) != (theme_id == "entrance"):
		last_error = "楼层与主题不匹配。"
		return {}
	var random := RandomNumberGenerator.new()
	var seed_value := floor_seed(run_seed, floor_number, theme_id)
	random.seed = seed_value
	var attempts := clampi(int(config.max_attempts), 1, 32)
	for attempt in attempts:
		var template: Dictionary = _pick(config.templates, random)
		var symmetry := random.randi_range(0, 7)
		var candidate := _build(template, floor_number, theme_id, symmetry, random)
		if candidate.is_empty():
			continue
		var problems: Array[String] = validator.validate(candidate)
		if problems.is_empty():
			candidate.generator = {"version": VERSION, "seed": str(seed_value),
				"template": template.id, "symmetry": symmetry, "attempt": attempt + 1}
			return candidate
		last_error = "；".join(problems)
	last_error = "随机地图未通过检查（%d 次）：%s" % [attempts, last_error]
	return {}

static func floor_seed(run_seed: String, number: int, theme_id: String) -> int:
	# Explicit 31-bit hash; no floating point or process-randomized hash function.
	var text := "%d|%s|%d|%s" % [VERSION, run_seed, number, theme_id]
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

func _build(template: Dictionary, number: int, theme_id: String, symmetry: int, random: RandomNumberGenerator) -> Dictionary:
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
	var needed_keys := 0
	for index in recipes.size():
		var role := str(recipes[index])
		var recipe: Dictionary = config.recipes[role]
		var branch: Dictionary = branches[index]
		var gate_pos: Array = _pick(branch.gates, random)
		var reward_pos: Array = _pick(branch.rewards, random)
		var gate: Dictionary = {}
		if recipe.gate == "door":
			gate = {"type": "door", "name": "支路铜锁门", "cost": 1}
			needed_keys += 1
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
	if safe_slots.size() < needed_keys + 2:
		last_error = "安全补给位置不足。"
		return {}
	for index in needed_keys:
		if not _place(result, {"type": "key", "name": "通用钥匙", "amount": 1,
			"role": "safe_key_%d" % index}, safe_slots.pop_back(), symmetry):
			return {}
	if not _place(result, {"type": "gold", "name": "散落钱币", "role": "safe_gold",
		"amount": _roll(config.safe_gold, random)}, safe_slots.pop_back(), symmetry):
		return {}
	if not _place(result, {"type": "potion", "name": "小型药剂", "role": "safe_potion",
		"amount": _roll(config.safe_heal, random)}, safe_slots.pop_back(), symmetry):
		return {}
	return result

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
