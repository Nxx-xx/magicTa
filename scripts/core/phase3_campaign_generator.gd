extends RefCounted
## v2 adapter: frozen inputs -> legacy geometry copy -> Phase 3 decoration -> heal copy.
## No player/save mutations, global RNG, animation, or implicit Phase 3 definitions.
const VERSION := 2
const Contract = preload("res://scripts/core/phase3_contract.gd")
const Recipe = preload("res://scripts/core/phase3_map_recipe.gd")
const Ruins = preload("res://scripts/core/phase3_ruins.gd")
const EVENTS := {"2":"p3_oath_ruin","6":"p3_oath_forge","9":"p3_lantern_sanctuary"}
const OLD_EVENTS := {"2":"library","6":"forge","9":"hermit"}
const BUDGET := {"equipment_opportunities":14,"relic_opportunities":17,"merchants":2,"rests":2,"events":3}
const FIXED := {"1":["iron_sword","iron_armor"],"3":["steel_blade"],"4":["knight_plate"],"7":["vital_crown"]}
const UNIQUE := ["p3_dawn_sigil","p3_lantern_aegis","p3_bounty_ledger","p3_rhythm_blade","p3_thorn_clasp","p3_gilded_lantern"]

# The parent constructor reads the initial base config only. Its per-floor counter
# is overridden so it cannot instantiate ContentDB and read the current global table.
class FrozenGeometry:
	extends "res://scripts/core/campaign_generator.gd"
	var count_error := ""
	func count_opportunities(map: Dictionary) -> Dictionary:
		var ledger := preload("res://scripts/core/phase3_map_recipe.gd").opportunity_counts(map,content_snapshot)
		count_error = ledger.error
		if ledger.ok: return ledger.counts
		return {"equipment":1000000000,"relic":1000000000,"merchants":0,"rests":0,"events":0}

var config: Dictionary = {}
var content_snapshot: Dictionary = {}
var phase3_context: Dictionary = {}
var errors: Array[String] = []
var last_error := ""
var _legacy = FrozenGeometry.new()

func _init(frozen_config: Dictionary = {}) -> void:
	if not frozen_config.is_empty():
		config = frozen_config.duplicate(true)
	else:
		config = _legacy.config.duplicate(true)
		errors.append_array(_legacy.errors)
		if not config.is_empty():
			config.version = VERSION
			config.event_floors = EVENTS.duplicate(true)
			config.ruin_geometry = "ruin_spokes"

func plan(seed_text: String) -> Dictionary:
	last_error = _configuration_error()
	if last_error.is_empty(): last_error = _context_error(false)
	if not last_error.is_empty(): return {}
	_prepare_legacy(false)
	var planned: Dictionary = _legacy.plan(seed_text)
	if planned.is_empty(): return _fail(_legacy.last_error)
	planned.version = VERSION
	var checked := validate_plan(planned)
	if not checked.ok: return _fail(checked.error)
	return planned

func generate(plan_data: Dictionary, number: int, theme: String, boss_choice: String = "") -> Dictionary:
	last_error = _context_error(true)
	if not last_error.is_empty(): return {}
	var checked := validate_plan(plan_data)
	if not checked.ok: return _fail(checked.error)
	if number < 1 or number > 10: return _fail("战役楼层必须在1到10。")
	if theme not in ["entrance","battle","treasure","shop","boss"] or (theme == "entrance" and number != 1) or (theme == "boss") != (number in [5,10]):
		return _fail("主题与楼层职责不匹配。")
	if boss_choice not in ["","dawn_spear","obsidian_mail"]:
		return _fail("未知第五层军械选择。")
	_prepare_legacy(true)
	var legacy_plan := plan_data.duplicate(true)
	legacy_plan.version = 1
	var base: Dictionary = _legacy.generate(legacy_plan,number,theme,boss_choice)
	if base.is_empty(): return _fail(_legacy.count_error if not _legacy.count_error.is_empty() else _legacy.last_error)
	var context := phase3_context.duplicate(true)
	context.floor = number
	context.theme = theme
	context.freshly_generated = true
	# Missing key means an already saved v2 journey: keep its original geometry,
	# including floors it has not visited yet. New journeys freeze the opt-in.
	context.geometry = config.get("ruin_geometry", "existing") if EVENTS.has(str(number)) else "existing"
	context.orientation = posmod(str(plan_data.floors[str(number)].floor_seed).to_int(), 8)
	var decorated := Recipe.decorate_floor(base,content_snapshot,context)
	if not decorated.ok: return _fail(decorated.error)
	var healing := apply_healing_snapshot(decorated.floor_map,phase3_context.challenge_snapshot)
	if not healing.ok: return _fail(healing.error)
	var result: Dictionary = healing.floor_map
	result.generator_version = VERSION
	result.phase3_new_unique_ids = decorated.new_unique_ids.duplicate()
	return result

## Original count_opportunities shape: a flat five-field ledger, {} on failure.
func count_opportunities(map: Dictionary) -> Dictionary:
	last_error = _context_error(true)
	if not last_error.is_empty(): return {}
	var ledger := Recipe.opportunity_counts(map,content_snapshot)
	if not ledger.ok: return _fail(ledger.error)
	return ledger.counts

func validate_plan(plan_data: Dictionary) -> Dictionary:
	var problem := _configuration_error()
	if not problem.is_empty(): return _error(problem)
	if plan_data.get("version") != VERSION or not plan_data.get("floors") is Dictionary or plan_data.floors.size() != 10 or not plan_data.get("budget") is Dictionary or not Contract.same_json(plan_data.budget,config.budget):
		return _error("v2楼层计划版本、预算或十层结构无效。")
	for number in range(1,11):
		var recipe = plan_data.floors.get(str(number))
		if not recipe is Dictionary or not _integer(recipe.get("template_id"),0,5) or not recipe.get("floor_seed") is String or not recipe.floor_seed.is_valid_int():
			return _error("楼层种子或模板无效。")
		if not Contract.same_json(recipe.get("reward_budget"),config.floor_budgets[number-1]) or recipe.get("fixed_equipment") != config.fixed_equipment.get(str(number),[]):
			return _error("楼层计划与冻结规则的固定军械/预算矛盾。")
	return {"ok":true,"error":""}

func _prepare_legacy(with_content: bool) -> void:
	_legacy.config = config.duplicate(true)
	_legacy.config.version = 1
	_legacy.config.event_floors = OLD_EVENTS.duplicate(true)
	_legacy.errors.clear()
	_legacy.last_error = ""
	_legacy.count_error = ""
	_legacy.content_snapshot = {}
	if with_content:
		_legacy.content_snapshot = content_snapshot.duplicate(true)
		# Temporary original IDs are geometry placeholders; replaced before return.
		# No old event options/rewards are needed, loaded, or exposed by this adapter.
		for id in OLD_EVENTS.values():
			_legacy.content_snapshot.events[id] = {"options":[]}

func _configuration_error() -> String:
	if config.get("version") != VERSION: return "生成器需要冻结的v2战役规则。"
	if config.get("ruin_geometry", "existing") not in ["existing", "ruin_spokes"]:
		return "未知的冻结遗迹布局规则。"
	for field in ["floor_names","normal_templates","floor_budgets"]:
		if not config.get(field) is Array or config[field].size() != (6 if field == "normal_templates" else 10):
			return "战役规则缺少完整的" + field
	for field in ["floor_names","normal_templates"]:
		for value in config[field]:
			if not value is String or value.is_empty(): return "楼层/模板名称无效。"
	if config.get("event_floors") != EVENTS or config.get("fixed_equipment") != FIXED:
		return "遗迹位置或固定军械与v2布局协议不符。"
	if not Contract.same_json(config.get("budget"), BUDGET) or not Contract.same_json(config.floor_budgets, Recipe.FLOOR_BUDGETS):
		return "v2预算必须保持既定全塔与楼层机会额度。"
	for field in ["merchant_floors","rest_floors","theme_relic_floors"]:
		var expected: Array = {"merchant_floors":[3,8],"rest_floors":[4,9],"theme_relic_floors":[2,6,9]}[field]
		if not Contract.same_json(config.get(field), expected): return "必要设施或主题机会楼层被改动。"
	if config.get("elite_floors") != {"4":"berserker","8":"warden"}:
		return "固定精英楼层被改动。"
	if not config.get("themes") is Dictionary or not config.get("enemy_overrides") is Dictionary:
		return "主题/怪物覆盖结构无效。"
	for theme in ["battle","treasure","shop"]:
		if not config.themes.get(theme) is Dictionary or not config.themes[theme].get("name") is String or not config.themes[theme].get("description") is String:
			return "主题显示定义无效。"
	for override in config.enemy_overrides.values():
		if not override is Dictionary: return "怪物覆盖必须为字典。"
		for field in override:
			if field == "name":
				if not override[field] is String: return "怪物覆盖名称无效。"
			elif field not in ["hp","attack","defense","gold_reward"] or not _integer(override[field],0,1000000000):
				return "怪物覆盖数值无效。"
	return ""

func _context_error(require_content: bool) -> String:
	# No {} -> latest-file defaults are allowed at this generation boundary.
	if not phase3_context.get("ruin_definitions") is Dictionary or phase3_context.ruin_definitions.is_empty():
		return "缺少冻结的ruin_definitions，不允许热读当前遗迹表。"
	var ruins := Ruins.validate_definitions(phase3_context.ruin_definitions)
	if not ruins.ok: return ruins.error
	for field in ["unlocked_ids","used_unique_ids"]:
		if not phase3_context.get(field) is Array: return "缺少冻结的" + field
		var seen := {}
		for id in phase3_context[field]:
			if not id is String or id.is_empty() or seen.has(id): return "解锁/唯一预留包含非法或重复ID。"
			seen[id] = true
	if not phase3_context.get("variant_plan") is Dictionary: return "缺少冻结变体计划。"
	var variants := []
	for floor_id in phase3_context.variant_plan:
		var id = phase3_context.variant_plan[floor_id]
		if not floor_id is String or not id is String or not Recipe.VARIANTS.has(id) or floor_id not in ["3","4","6","7","8","9"]:
			return "冻结变体计划无效。"
		if int(floor_id) not in Recipe.VARIANTS[id].floors or id in variants: return "冻结变体重复或楼层越界。"
		variants.append(id)
	if not phase3_context.get("challenge_snapshot") is Dictionary: return "缺少冻结challenge_snapshot。"
	var challenge_error := _challenge_error(phase3_context.challenge_snapshot)
	if not challenge_error.is_empty(): return challenge_error
	if phase3_context.has("challenge_id") and phase3_context.challenge_id != phase3_context.challenge_snapshot.id:
		return "挑战ID与冻结快照不一致。"
	if phase3_context.has("geometry") and phase3_context.geometry != config.get("ruin_geometry", "existing"):
		return "遗迹布局上下文与冻结规则不一致。"
	if not require_content: return ""
	for field in ["items","enemies","events","shop"]:
		if not content_snapshot.get(field) is Dictionary: return "缺少冻结内容字典：" + field
		for definition in content_snapshot[field].values():
			if not definition is Dictionary: return "内容定义必须为字典：" + field
	# Compare the definitions actually used by events with their authoritative snapshot.
	var events := Ruins.event_definitions(phase3_context.ruin_definitions)
	for id in events:
		if not content_snapshot.events.get(id) is Dictionary: return "冻结内容缺少遗迹事件：" + id
		for field in ["name","description","options","ruin_id","rules_version"]:
			if not Contract.same_json(content_snapshot.events[id].get(field), events[id][field]): return "冻结遗迹与内容事件不一致：" + id
	for id in UNIQUE:
		if not content_snapshot.items.has(id) or content_snapshot.items[id].get("kind") != "relic": return "冻结内容缺少机制遗物：" + id
	for id in variants:
		if not content_snapshot.enemies.has(id): return "冻结内容缺少计划变体：" + id
	return ""

## Pure and explicitly once-only. Never touch shop, ruin, kill or max_hp healing.
static func apply_healing_snapshot(floor_map: Dictionary, challenge_snapshot: Dictionary) -> Dictionary:
	var problem := _challenge_error(challenge_snapshot)
	if not problem.is_empty(): return _error(problem)
	if floor_map.has("phase3_healing"): return _error("楼层治疗快照已应用，禁止二次缩放。")
	if not floor_map.get("entities") is Dictionary: return _error("楼层实体字典无效。")
	var map := floor_map.duplicate(true)
	var percent: int = int(challenge_snapshot.heal_percent) if challenge_snapshot.id == "p3_c2" else 100
	for entity in map.entities.values():
		if not entity is Dictionary: return _error("治疗实体结构无效。")
		if entity.has("phase3_heal_base"): return _error("药剂治疗已经缩放。")
		if entity.get("type") == "potion":
			if not _integer(entity.get("amount"),0,1000000000): return _error("药剂治疗数值无效。")
			entity.phase3_heal_base = int(entity.amount)
			entity.amount = _scaled_heal(int(entity.amount),percent)
			entity.description = "恢复 %d HP。" % int(entity.amount)
		elif entity.get("type") == "rest":
			if not entity.get("options") is Array: return _error("休息选项无效。")
			for option in entity.options:
				if not option is Dictionary or not option.get("effects") is Dictionary: return _error("休息效果结构无效。")
				if option.has("phase3_heal_base"): return _error("休息治疗已经缩放。")
				if not option.effects.has("heal"): continue
				for field in option.effects:
					if field not in ["heal","max_hp"] or not _integer(option.effects[field],0,1000000000): return _error("未知或非法休息效果。")
				option.phase3_heal_base = int(option.effects.heal)
				option.effects.heal = _scaled_heal(int(option.effects.heal),percent)
				option.description = ("最大生命 +%d，" % int(option.effects.max_hp) if option.effects.has("max_hp") else "") + "恢复 %d HP" % int(option.effects.heal)
	map.phase3_healing = {"version":1,"challenge_id":challenge_snapshot.id,"heal_percent":percent,
		"sources":["potion","rest"],"explicit_heal_only":true}
	return {"ok":true,"error":"","floor_map":map}

static func _scaled_heal(amount: int, percent: int) -> int:
	return maxi(1, int((amount * percent) / 100)) if amount > 0 else 0

static func _challenge_error(snapshot: Dictionary) -> String:
	if snapshot.get("version") != 1 or snapshot.get("id") not in ["p3_c0","p3_c1","p3_c2"]:
		return "挑战快照版本或ID无效。"
	if not _integer(snapshot.get("heal_percent"),1,100): return "冻结治疗百分比无效。"
	if snapshot.id != "p3_c2" and int(snapshot.heal_percent) != 100: return "C0/C1不允许缩放治疗。"
	return ""

static func _integer(value: Variant, low: int, high: int) -> bool:
	return (value is int or value is float) and is_finite(float(value)) and float(value) == floorf(float(value)) and float(value) >= low and float(value) <= high

func _fail(message: String) -> Dictionary:
	last_error = message
	return {}

static func _error(message: String) -> Dictionary:
	return {"ok":false,"error":message}
