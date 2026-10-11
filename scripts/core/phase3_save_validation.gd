extends RefCounted
## Strict v2-only checks. Shared map/campaign invariants remain in their original validators.
const Contract = preload("res://scripts/core/phase3_contract.gd")
const Progress = preload("res://scripts/core/phase3_progress.gd")
const Items = preload("res://scripts/core/phase3_items.gd")
const Combat = preload("res://scripts/core/phase3_combat.gd")
const Enemies = preload("res://scripts/core/phase3_enemies.gd")
const Ruins = preload("res://scripts/core/phase3_ruins.gd")
const Recipe = preload("res://scripts/core/phase3_map_recipe.gd")
const Generation = preload("res://scripts/core/phase3_campaign_generator.gd")
const LIMIT := 1000000000

static func valid_meta(meta: Dictionary) -> bool:
	if not Progress.validate_meta_extensions(meta).ok: return false
	var known := ["p3_c0", "default"]
	var rules: Dictionary = Progress.definitions().unlocks.unlocks
	for rule in rules.values():
		for grant in rule.grants:
			if grant not in known: known.append(grant)
	for id in meta.unlocked_ids:
		if id not in known: return false
	for id in meta.achievement_ids:
		if not rules.has(id) or not meta.achievement_records.has(id): return false
		for grant in rules[id].grants:
			if grant not in meta.unlocked_ids: return false
	for id in meta.achievement_records:
		if id not in meta.achievement_ids: return false
		var record: Dictionary = meta.achievement_records[id]
		if record.get("source", "") not in ["run", "legacy_account"]: return false
		if record.source == "legacy_account":
			if id != "p3_c0_clear" or not record.run_id.is_empty(): return false
		elif not meta.phase3_settled_runs.has(record.run_id) or meta.phase3_settled_runs[record.run_id] == "abandoned": return false
	for key in meta.codex.enemy_records:
		var record: Dictionary = meta.codex.enemy_records[key]
		if not _integer(record.combat_rules_version, 1, 2) or record.challenge_id not in Contract.CHALLENGES: return false
	return true

static func valid_player(player: Dictionary, content: Dictionary) -> bool:
	if not Items.validate_player(player, content).ok: return false
	var stats := Items.player_stats(player, content)
	return stats.get("ok", false) and int(player.hp) <= int(stats.max_hp)

static func valid_reward(reward: Dictionary, items: Dictionary) -> bool:
	if reward.has("item_id") and (not reward.item_id is String or not items.has(reward.item_id)): return false
	return _effects(reward.get("cost", {}), Items.COST_FIELDS) and _effects(reward.get("effects", {}), Items.REWARD_FIELDS)

static func valid_content(content: Dictionary) -> bool:
	for field in ["items", "enemies", "events", "shop"]:
		if not content.get(field) is Dictionary or content[field].is_empty(): return false
	for item in content.items.values():
		if not item is Dictionary or not _text(item.get("id")) or not item.get("kind") is String: return false
		for list_key in ["combat_effects", "conditional_effects"]:
			if not item.get(list_key, []) is Array: return false
			for effect in item.get(list_key, []):
				if not effect is Dictionary or not _text(effect.get("id")): return false
	if not Items.validate_definitions(content.items).ok: return false
	for id in Items.UNIQUE_IDS:
		if not content.items.has(id): return false
	var variants := {}
	for id in content.enemies:
		var enemy: Variant = content.enemies[id]
		if not _text(id) or not enemy is Dictionary or not _text(enemy.get("id")) or enemy.id != id: return false
		for field in ["name", "description", "combat_hint"]:
			if not _text(enemy.get(field)): return false
		if enemy.get("rank") not in ["normal", "elite", "boss"]: return false
		if enemy.rank == "boss":
			if not _integer(enemy.get("boss_floor"), 5, 10) or int(enemy.boss_floor) not in [5,10] or enemy.has("tier"): return false
		elif not _integer(enemy.get("tier"), 1, 3) or enemy.has("boss_floor"): return false
		if not Combat.validate_inputs({"hp":1}, enemy, {"attack":1,"defense":0,"max_hp":1,"kill_heal":0,"gold_bonus":0}).ok: return false
		if not _integer(enemy.get("gold_reward"), 0, Combat.MAX_VALUE): return false
		if id in Enemies.VARIANTS: variants[id] = enemy
		elif enemy.ability_id not in ["", "rage", "stone_armor"]: return false
	if variants.size() != Enemies.VARIANTS.size() or not Enemies.validate_definitions(variants).ok: return false
	for id in content.shop:
		var offer: Variant = content.shop[id]
		if not _text(id) or not offer is Dictionary or not _text(offer.get("name")) or not offer.get("description") is String or not _count(offer.get("price")) or not valid_reward(offer, content.items): return false
		if offer.has("min_floor") and not _integer(offer.min_floor, 1, 10): return false
	for id in content.events:
		var event: Variant = content.events[id]
		if not _text(id) or not event is Dictionary or not _text(event.get("name")) or not event.get("description") is String or not event.get("options") is Array: return false
		if event.options.size() != (4 if id in Ruins.IDS else 2): return false
		if id in Ruins.IDS and (not _text(event.get("ruin_id")) or event.ruin_id != id or not _integer(event.get("rules_version"), 1, 1)): return false
		for option in event.options:
			if not option is Dictionary or not _text(option.get("name")) or not valid_reward(option, content.items): return false
	if content.has("phase3_challenge_applied") and content.phase3_challenge_applied not in Contract.CHALLENGES: return false
	return true

static func valid_report(report: Dictionary, content: Dictionary) -> bool:
	if not report.get("ok") is bool or not report.ok or not report.get("error") is String or report.error != "" or not _integer(report.get("combat_rules_version"), 2, 2): return false
	if not _count(report.get("min_hp")) or not report.get("effects_triggered") is Array or not report.get("log") is Array: return false
	if not _integer(report.get("turns"), 1, Combat.MAX_ENEMY_HP) or report.log.size() != int(report.turns): return false
	for key in ["incoming", "hp_after", "healing", "enemy_hp_after"]:
		if not _count(report.get(key)): return false
	if not _integer(report.get("loss"), -LIMIT, LIMIT): return false
	if not report.get("won") is bool or not _count(report.get("counterattacks")): return false
	var total := 0
	var counters := 0
	var minimum := int(report.hp_after) + int(report.loss)
	if minimum < 1: return false
	var flattened: Array = []
	var prior_enemy := -1
	var prior_hp := minimum
	for index in report.log.size():
		var row: Variant = report.log[index]
		if not row is Dictionary or not row.get("effect_events") is Array: return false
		for field in ["actual_hit", "enemy_hp", "enemy_hp_after_counter", "counter", "hp", "retaliation_damage", "guard_reduction"]:
			if not _count(row.get(field)): return false
		if int(row.enemy_hp_after_counter) != maxi(0, int(row.enemy_hp) - int(row.retaliation_damage)): return false
		if int(row.hp) != maxi(0, prior_hp - int(row.counter)): return false
		if prior_enemy >= 0 and int(row.actual_hit) != prior_enemy - int(row.enemy_hp): return false
		if int(row.enemy_hp_after_counter) == 0 and index != report.log.size() - 1: return false
		prior_enemy = int(row.enemy_hp_after_counter)
		prior_hp = int(row.hp)
		minimum = mini(minimum, prior_hp)
		total += int(row.counter)
		if int(row.enemy_hp) > 0: counters += 1
		for event in row.effect_events:
			if not _effect_event(event, content): return false
			var flat: Dictionary = event.duplicate(true)
			flat.turn = index + 1
			flattened.append(flat)
	if total != int(report.incoming) or minimum != int(report.min_hp): return false
	if counters != int(report.counterattacks) or report.won != (int(report.enemy_hp_after) == 0 and int(report.hp_after) > 0): return false
	if not report.won and (report.healing != 0 or report.get("gold_reward") != 0): return false
	if prior_hp + int(report.healing) != int(report.hp_after) or prior_enemy != int(report.enemy_hp_after): return false
	return Contract.same_json(flattened, report.effects_triggered)

static func _effect_event(event: Variant, content: Dictionary) -> bool:
	if not event is Dictionary or not _text(event.get("id")) or not _count(event.get("amount")): return false
	if event.has("source_item_id") == event.has("source_enemy_id"): return false
	if event.has("source_item_id"):
		if not _text(event.source_item_id) or not content.get("items", {}).has(event.source_item_id) or event.id not in Combat.EFFECT_FIELDS: return false
		var found := false
		for definition in content.items[event.source_item_id].get("combat_effects", []):
			if definition.id == event.id: found = true
		if not found: return false
	else:
		if not _text(event.source_enemy_id) or not content.get("enemies", {}).has(event.source_enemy_id): return false
		if event.id != content.enemies[event.source_enemy_id].ability_id or event.id == "": return false
	return event.size() == 3

static func valid_run(run: Dictionary, meta: Dictionary) -> bool:
	if not Contract.validate_snapshots(run).ok or not valid_meta(meta): return false
	if not Generation.new(run.campaign_rules_snapshot).validate_plan(run.campaign_plan).ok: return false
	for key in ["progress_rules_snapshot", "ruin_definitions_snapshot", "variant_plan", "metrics", "meta_snapshot"]:
		if not run.get(key) is Dictionary: return false
	if not valid_progress_rules(run.progress_rules_snapshot): return false
	if not valid_ruins(run.ruin_definitions_snapshot): return false
	var defs: Dictionary = run.progress_rules_snapshot
	var challenge: Dictionary = run.challenge_snapshot
	var start: Dictionary = run.start_config_snapshot
	if not _integer(run.get("challenge_rules_version"), 1, 1): return false
	if not _text(run.get("challenge_id")) or run.challenge_id != challenge.id or not defs.challenges.challenges.has(challenge.id) or not defs.challenges.start_configs.has(start.id): return false
	if not _matches_snapshot(challenge, defs.challenges.challenges[challenge.id]) or not _matches_snapshot(start, defs.challenges.start_configs[start.id]): return false
	if not valid_meta(run.meta_snapshot) or not Progress.initial_player(run.meta_snapshot, start.id, defs).ok: return false
	if not _ids(run.unlocked_pool_snapshot) or not _ids(run.get("reserved_unique_ids")) or not run.get("codex_events") is Array: return false
	if run.unlocked_pool_snapshot != run.meta_snapshot.unlocked_ids: return false
	if not _text(run.reward_content.get("phase3_challenge_applied")) or run.reward_content.phase3_challenge_applied != challenge.id: return false
	var events := Ruins.event_definitions(run.ruin_definitions_snapshot)
	for id in events:
		if not Contract.same_json(run.reward_content.events.get(id), events[id]): return false
	var used_variants := []
	for floor_id in run.variant_plan:
		var variant: Variant = run.variant_plan[floor_id]
		if not floor_id is String or not floor_id.is_valid_int() or not variant is String or not Enemies.VARIANTS.has(variant): return false
		if int(floor_id) not in Enemies.VARIANTS[variant].floors or variant in used_variants: return false
		used_variants.append(variant)
	for id in run.reserved_unique_ids:
		if id not in Items.UNIQUE_IDS or (id not in Recipe.FIRST and id not in run.unlocked_pool_snapshot): return false
	for id in run.player.relic_ids:
		if id in Items.UNIQUE_IDS and id not in run.reserved_unique_ids: return false
	for key in ["actual_kill_healing", "shop_gold_spent", "min_hp_in_combat"]:
		if not _count(run.metrics.get(key)): return false
	for key in ["midboss_turns", "lowest_elite_incoming"]:
		if run.metrics.has(key) and not _integer(run.metrics[key], 1 if key == "midboss_turns" else 0, LIMIT): return false
	for key in ["ruin_choices", "effect_counts", "effect_actual_values"]:
		if not run.metrics.get(key) is Dictionary: return false
	for field in ["effect_counts", "effect_actual_values"]:
		for id in run.metrics[field]:
			if not _text(id) or (id not in Combat.EFFECT_FIELDS and id not in ["rage","stone_armor","p3_shield","p3_ember","p3_ambush"]) or not _count(run.metrics[field][id]): return false
	if not Progress.record_discoveries(meta, run.run_id, run.codex_events).ok: return false
	for event in run.codex_events:
		var category: String = {"enemy_seen":"enemies", "item_seen":"items", "item_obtained":"items", "ruin_seen":"events", "ruin_choice":"events"}.get(event.kind, "")
		if not category.is_empty() and not run.reward_content[category].has(event.id): return false
	var selected := {}
	var reserved := []
	var ruin_ids := []
	var available_unique := []
	var variants_seen := []
	for floor_data in run.floors.values():
		if not valid_floor(floor_data, run, reserved, selected, ruin_ids): return false
		for entity in floor_data.entities.values():
			if entity.type == "enemy" and entity.enemy_id in Enemies.VARIANTS:
				if run.variant_plan.get(str(int(floor_data.floor))) != entity.enemy_id or entity.enemy_id in variants_seen: return false
				variants_seen.append(entity.enemy_id)
			var offered: Array = []
			if entity.type == "choice": offered = entity.choices
			elif entity.type == "chest": offered = [entity.item_id]
			elif entity.type == "shop" and not entity.purchased:
				for offer_id in entity.offers:
					if offer_id in entity.get("purchased_ids", []): continue
					var offer: Dictionary = run.reward_content.shop[offer_id]
					if offer.has("item_id"): offered.append(offer.item_id)
			for id in offered:
				if id in Items.UNIQUE_IDS:
					if id not in floor_data.phase3_new_unique_ids or id in available_unique or id in run.player.relic_ids: return false
					available_unique.append(id)
	if reserved.size() != run.reserved_unique_ids.size(): return false
	if selected != run.metrics.ruin_choices: return false
	for entity_id in selected:
		var found := false
		for event in run.codex_events:
			if event.kind == "ruin_choice" and event.option_id == selected[entity_id]:
				# The stable ruin ID, not a guessed entity-id substring, identifies the site.
				var floor_number: int = Ruins.IDS[event.id]
				if entity_id.begins_with("f%d:" % floor_number): found = true
		if not found: return false
	if not run.get("defeated_entities") is Array: return false
	for enemy in run.defeated_entities:
		if not enemy is Dictionary or not _integer(enemy.get("turns"), 1, Combat.MAX_ENEMY_HP) or not _count(enemy.get("incoming")): return false
		if enemy.get("enemy_id", "") in Enemies.VARIANTS:
			if not _integer(enemy.get("floor"), 1, 10) or run.variant_plan.get(str(int(enemy.floor))) != enemy.enemy_id or enemy.enemy_id in variants_seen: return false
			variants_seen.append(enemy.enemy_id)
	var result: Variant = run.get("result")
	if not result is String: return false
	if result.is_empty():
		if meta.phase3_settled_runs.has(run.run_id): return false
	elif meta.phase3_settled_runs.get(run.run_id) != result: return false
	return true

static func valid_progress_rules(defs: Dictionary) -> bool:
	for key in ["challenges", "unlocks"]:
		if not defs.get(key) is Dictionary or not _integer(defs[key].get("version"), 1, 1): return false
	var root: Dictionary = defs.challenges
	if not root.get("challenges") is Dictionary or root.challenges.size() != 3 or not root.get("start_configs") is Dictionary or root.start_configs.size() != 4: return false
	for id in Contract.CHALLENGES:
		var rule: Variant = root.challenges.get(id)
		if not rule is Dictionary or not _text(rule.get("id")) or rule.id != id or not _text(rule.get("name")) or not _text(rule.get("description")): return false
		for field in ["normal_hp_percent", "boss_hp_percent", "heal_percent"]:
			if not _integer(rule.get(field), 1, 1000): return false
		for field in ["normal_attack", "boss_attack"]:
			if not _integer(rule.get(field), 0, 1000): return false
		if rule.heal_percent > 100 or (id != "p3_c2" and rule.heal_percent != 100): return false
	for id in Contract.START_CONFIGS:
		var rule: Variant = root.start_configs.get(id)
		if not rule is Dictionary or not _text(rule.get("id")) or rule.id != id or not _text(rule.get("name")) or not _text(rule.get("description")): return false
		for field in ["hp_delta", "attack_delta", "defense_delta", "gold_delta"]:
			if not _integer(rule.get(field), -100, 100): return false
	var rules: Variant = defs.unlocks.get("unlocks")
	var canonical: Dictionary = Progress.definitions().unlocks.unlocks
	if not rules is Dictionary or rules.size() != canonical.size(): return false
	for id in canonical:
		var rule: Variant = rules.get(id)
		if not rule is Dictionary or not _text(rule.get("name")) or not _text(rule.get("description")) or not _ids(rule.get("grants")) or rule.grants != canonical[id].grants: return false
	return true

static func valid_ruins(defs: Dictionary) -> bool:
	for ruin in defs.values():
		if not ruin is Dictionary or not _integer(ruin.get("floor"), 1, 10) or not ruin.get("options") is Array: return false
		for option in ruin.options:
			if not option is Dictionary or not _text(option.get("id")): return false
	return Ruins.validate_definitions(defs).ok

static func valid_floor(floor_data: Dictionary, run: Dictionary, reserved: Array, selected: Dictionary, ruin_ids: Array) -> bool:
	if not _integer(floor_data.get("generator_version"), 2, 2) or not _integer(floor_data.get("floor"), 1, 10): return false
	var healing: Variant = floor_data.get("phase3_healing")
	var percent := int(run.challenge_snapshot.heal_percent) if run.challenge_id == "p3_c2" else 100
	if not healing is Dictionary or not Contract.same_json(healing, {"version":1,"challenge_id":run.challenge_id,"heal_percent":percent,"sources":["potion","rest"],"explicit_heal_only":true}): return false
	var number := int(floor_data.floor)
	if not _integer(floor_data.get("template_id"), 0, 5) and not floor_data.get("template_id") is String: return false
	if not _ids(floor_data.get("phase3_new_unique_ids")): return false
	for id in floor_data.phase3_new_unique_ids:
		if id not in run.reserved_unique_ids or id in reserved: return false
		reserved.append(id)
	if floor_data.has("phase3_recipe"):
		var recipe: Variant = floor_data.phase3_recipe
		if not recipe is Dictionary or not _integer(recipe.get("version"), 1, 1) or not recipe.get("report") is Dictionary or not recipe.get("opportunities") is Dictionary: return false
		if not Contract.same_json(recipe.get("new_unique_ids"), floor_data.phase3_new_unique_ids): return false
		var report: Dictionary = recipe.report
		for field in ["event", "variant", "variant_skip", "geometry", "geometry_fallback"]:
			if not report.get(field) is String: return false
		if report.geometry not in ["existing", "ruin_spokes"] or not _ids(report.get("theme_choices")): return false
		if report.geometry == "ruin_spokes":
			if number not in Recipe.EVENTS or run.campaign_rules_snapshot.get("ruin_geometry", "existing") != "ruin_spokes": return false
			var orientation := posmod(str(run.campaign_plan.floors[str(number)].floor_seed).to_int(), 8)
			if floor_data.template_id != "p3_ruin_spokes_%d" % orientation: return false
		if not floor_data.template_id is String and report.geometry != "existing": return false
		var has_choices: bool = number in [2,6] and floor_data.theme in ["battle","treasure"]
		if report.theme_choices.size() != (2 if has_choices else 0): return false
		if report.event != (Recipe.EVENTS[number][1] if number in Recipe.EVENTS else ""): return false
		if not report.variant.is_empty() and report.variant != run.variant_plan.get(str(number), ""): return false
		for id in report.theme_choices:
			if not run.reward_content.items.has(id): return false
		for id in recipe.new_unique_ids:
			if id not in report.theme_choices: return false
		for field in ["equipment", "relic", "merchants", "rests", "events"]:
			if not _count(recipe.opportunities.get(field)): return false
		if recipe.opportunities.equipment > Recipe.FLOOR_BUDGETS[number-1][0] or recipe.opportunities.relic > Recipe.FLOOR_BUDGETS[number-1][1]: return false
		if not Contract.same_json(recipe.get("direct_effect_budget"), Ruins.direct_effect_budget(run.ruin_definitions_snapshot).per_ruin.get(report.event, {})): return false
	else: return false
	if not floor_data.get("branch_paths") is Array: return false
	if number not in [5,10] and floor_data.branch_paths.size() != 4: return false
	for branch in floor_data.branch_paths:
		if not branch is Array or branch.size() < 2: return false
		for point in branch:
			if not _point(point): return false
	if floor_data.has("phase3_recipe") and not floor_data.phase3_recipe.report.theme_choices.is_empty():
		if floor_data.branch_paths.size() != 4: return false
		var point: Array = floor_data.branch_paths[2][-1]
		var entity: Dictionary = floor_data.entities.get("%d,%d" % [point[0],point[1]], {})
		if not entity.is_empty() and (entity.get("type") != "choice" or entity.get("choices") != floor_data.phase3_recipe.report.theme_choices): return false
	if number not in [5,10]:
		if not floor_data.get("safe_slots") is Dictionary: return false
		for field in ["event", "shop", "rest", "key"]:
			if not _point(floor_data.safe_slots.get(field)): return false
	for entity in floor_data.entities.values():
		if entity.type == "potion":
			if not _valid_healing(entity.get("phase3_heal_base"), entity.get("amount"), percent): return false
		elif entity.has("phase3_heal_base"): return false
		if entity.type == "rest":
			for option in entity.options:
				if option.get("effects", {}).has("heal"):
					if not _valid_healing(option.get("phase3_heal_base"), option.effects.heal, percent): return false
				elif option.has("phase3_heal_base"): return false
		if entity.get("type") != "event" or entity.get("event_id", "") not in Ruins.IDS:
			if entity.has("ruin_id") or entity.has("status") or entity.has("selected_option") or entity.has("transaction_id"): return false
			continue
		var id: String = entity.event_id
		if not _text(entity.get("ruin_id")) or entity.ruin_id != id or Ruins.IDS[id] != number or id in ruin_ids or not _integer(entity.get("rules_version"), 1, 1): return false
		for key in ["status", "selected_option", "transaction_id"]:
			if not entity.get(key) is String: return false
		ruin_ids.append(id)
		if entity.get("status") == "available":
			if entity.get("selected_option") != "" or entity.get("transaction_id") != "": return false
		elif entity.get("status") == "resolved":
			if entity.get("selected_option", "leave") not in Ruins.OPTIONS[id] or entity.selected_option == "leave": return false
			if entity.get("transaction_id") != "%s:%s:resolve" % [run.run_id,entity.id]: return false
			selected[entity.id] = entity.selected_option
		else: return false
	if number in Recipe.EVENTS and Recipe.EVENTS[number][1] not in ruin_ids: return false
	return true

static func _valid_healing(base: Variant, amount: Variant, percent: int) -> bool:
	if not _count(base) or not _count(amount): return false
	return int(amount) == (maxi(1, int(int(base) * percent / 100)) if base > 0 else 0)

static func valid_template(floor_data: Dictionary) -> bool:
	var template: Variant = floor_data.get("template_id")
	if not template is String or not template.begins_with("p3_ruin_spokes_"): return false
	var suffix: String = template.trim_prefix("p3_ruin_spokes_")
	return suffix in ["0","1","2","3","4","5","6","7"] and floor_data.get("phase3_recipe", {}).get("report", {}).get("geometry") == "ruin_spokes"

static func _matches_snapshot(snapshot: Dictionary, definition: Dictionary) -> bool:
	for key in definition:
		if not Contract.same_json(snapshot.get(key), definition[key]): return false
	for key in snapshot:
		if key != "version" and not definition.has(key): return false
	return true

static func _effects(value: Variant, allowed: Array) -> bool:
	if not value is Dictionary: return false
	for key in value:
		if key not in allowed or not _integer(value[key], 0, Items.LIMIT): return false
	return true

static func _ids(value: Variant) -> bool:
	if not value is Array: return false
	var seen := {}
	for id in value:
		if not _text(id) or seen.has(id): return false
		seen[id] = true
	return true

static func _point(value: Variant) -> bool:
	return value is Array and value.size() == 2 and _integer(value[0],0,10) and _integer(value[1],0,10)

static func _text(value: Variant) -> bool:
	return value is String and not value.strip_edges().is_empty() and value.length() <= 256

static func _integer(value: Variant, low: int, high: int) -> bool:
	return (value is int or value is float) and is_finite(float(value)) and value >= low and value <= high and float(value) == floorf(float(value))

static func _count(value: Variant) -> bool:
	return _integer(value, 0, LIMIT)
