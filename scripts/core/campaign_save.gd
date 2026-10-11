extends "res://scripts/core/map_save.gd"
## Whole-envelope recovery: a backup never mixes another run with a newer account.
const Progress = preload("res://scripts/core/campaign_progress.gd")
const Story = preload("res://scripts/core/story_state.gd")
const P3Progress = preload("res://scripts/core/phase3_progress.gd")
const Contract = preload("res://scripts/core/phase3_contract.gd")

func read() -> Dictionary:
	var saved := super.read()
	if saved.is_empty(): return saved
	if saved.meta.is_empty(): saved.meta = Progress.default_meta()
	saved.meta = P3Progress.migrate_meta(saved.meta)
	if saved.run.get("mode", "") == "grid_prototype_v1":
		saved.run.campaign_kind = "trial_2f"
		saved.run.meta_snapshot = {"upgrades": {"hp":0,"attack":0,"gold":0}, "version":1}
	elif not saved.run.is_empty():
		Story.restore_summary(saved.run)
	return saved

func write(run: Dictionary, meta: Dictionary) -> bool:
	# Only validated legacy accounts may be migrated; never repair a malformed schema2 silently.
	if not (meta.is_empty() and run.get("mode", "") == "grid_prototype_v1") and not _valid_meta(meta):
		last_error = "账户校验失败；原存档和备份未修改。"
		return false
	var account := P3Progress.migrate_meta(Progress.default_meta() if meta.is_empty() else meta)
	if not _valid({"version":2,"run":run,"meta":account}):
		last_error = "存档状态校验失败；原存档和备份未修改。"
		return false
	return super.write(run, account)

func _envelope_version() -> int:
	return 2

func _valid(value: Variant) -> bool:
	if not value is Dictionary or not _integer(value.get("version"), 1, 2) or not value.get("run") is Dictionary or not value.get("meta") is Dictionary:
		return false
	var state: Dictionary = value.run
	var classified := Contract.classify(state)
	if not classified.ok: return false
	var phase3: bool = classified.kind == "phase3_campaign"
	var rules_version := 2 if phase3 else 1
	if not phase3:
		for field in ["challenge_snapshot", "start_config_snapshot", "progress_rules_snapshot", "ruin_definitions_snapshot", "phase3_contract_version"]:
			if state.has(field): return false
	if value.version == 1 and phase3: return false
	if value.version == 2 and not P3Progress.validate_meta_extensions(value.meta).ok: return false
	if state.get("mode", "") == "grid_prototype_v1":
		return _valid_state(state, 2) and (value.meta.is_empty() or _valid_meta(value.meta))
	if not _valid_meta(value.meta): return false
	if state.is_empty(): return true
	if state.get("mode", "") != "tower_campaign_v1" or state.get("campaign_kind", "") != "tower_10f" or not _text(state.get("run_id")):
		return false
	if not _valid_state(state, 10, rules_version) or not state.get("reward_content", {}).get("enemies") is Dictionary:
		return false
	if phase3 and not Phase3Validation.valid_run(state, value.meta): return false
	if state.get("result", "invalid") not in ["", "death", "victory", "abandoned"]:
		return false
	if not state.get("meta_snapshot") is Dictionary or not _levels(state.meta_snapshot.get("upgrades")):
		return false
	if not state.get("meta_rules_snapshot") is Dictionary:
		return false
	for key in Progress.RULES:
		if state.meta_rules_snapshot.get(key, -1) != Progress.RULES[key]: return false
	if not _valid_story(state.get("story")) or not _valid_plan(state.get("campaign_plan"), state.reward_content.items, rules_version):
		return false
	if not _valid_campaign_rules(state.get("campaign_rules_snapshot"), state.reward_content, state.campaign_plan, rules_version, state.get("challenge_snapshot", {})): return false
	if not state.get("side_objective_complete") is bool: return false
	if state.objective_complete != (state.result == "victory"): return false
	if state.side_objective_complete != ("sovereign_ring" in state.player.equipment_ids): return false
	if state.get("story_rules_version",0) != 1 or state.get("story_version",0) != 1: return false
	if not state.get("metrics") is Dictionary: return false
	for key in ["steps","backtrack_steps","damage_taken","healing","overflow","gold_spent","minimum_hp"]:
		if not _valid_count(state.metrics.get(key)): return false
	if int(state.metrics.backtrack_steps) > int(state.metrics.steps): return false
	if not state.get("boss_rewards_claimed") is Array or state.boss_rewards_claimed.size() > 1:
		return false
	for number in state.boss_rewards_claimed:
		if not _integer(number, 5, 5): return false
	if state.get("boss_choice", "invalid") not in ["", "dawn_spear", "obsidian_mail"]:
		return false
	if state.boss_rewards_claimed.is_empty() != str(state.boss_choice).is_empty(): return false
	var living := {}
	var boss_entities := {5:0,10:0}
	var mid_reward_count := 0
	for floor_id in state.floors:
		var data: Dictionary = state.floors[floor_id]
		if not _integer(data.get("floor"), int(floor_id), int(floor_id)) or not _integer(data.get("generator_version"), rules_version, rules_version) or not _text(data.get("floor_seed")) or not data.get("boss_floor") is bool:
			return false
		if data.boss_floor != (int(floor_id) in [5,10]): return false
		if int(floor_id) > 1 and not state.floors.has(str(int(floor_id) - 1)): return false
		var recipe: Dictionary = state.campaign_plan.floors[floor_id]
		if data.floor_seed != recipe.floor_seed: return false
		if data.boss_floor:
			if data.get("template_id") != ("boss_gate" if int(floor_id) == 5 else "boss_seal"): return false
		elif phase3 and data.get("template_id") is String:
			if not Phase3Validation.valid_template(data): return false
		elif not _integer(data.get("template_id"),0,5) or int(data.template_id) != int(recipe.template_id): return false
		if int(floor_id) > 5 and state.boss_rewards_claimed.is_empty(): return false
		for entity in data.entities.values():
			if not _text(entity.get("id")) or living.has(entity.id): return false
			if entity.id != "f%s:%s" % [floor_id, _cell_key(entity.pos)]: return false
			if entity.type == "enemy":
				var enemy: Dictionary = state.reward_content.enemies[entity.enemy_id]
				if enemy.rank == "boss":
					if not entity.get("campaign_boss", false) or int(floor_id) != int(enemy.boss_floor): return false
					boss_entities[int(floor_id)] += 1
				elif entity.get("campaign_boss", false): return false
			if entity.get("campaign_boss_reward", false):
				if int(floor_id) != 5 or entity.type != "choice" or entity.choices != ["dawn_spear","obsidian_mail"]: return false
				mid_reward_count += 1
			living[entity.id] = true
	if not state.get("defeated_entities") is Array: return false
	var defeated := {}
	var counts := {"normal":0,"elite":0,"boss":0}
	var mid_boss := false
	var final_boss := false
	for enemy in state.defeated_entities:
		if not enemy is Dictionary or not _text(enemy.get("id")) or defeated.has(enemy.id) or living.has(enemy.id) or not _integer(enemy.get("floor"), 1, 10): return false
		if enemy.get("rank", "") not in counts or not _reference(enemy, "enemy_id", state.reward_content.enemies): return false
		if state.reward_content.enemies[enemy.enemy_id].rank != enemy.rank or not state.floors.has(str(int(enemy.floor))): return false
		var prefix := "f%d:" % int(enemy.floor)
		if not str(enemy.id).begins_with(prefix): return false
		var coordinates: PackedStringArray = str(enemy.id).trim_prefix(prefix).split(",")
		if coordinates.size() != 2 or not coordinates[0].is_valid_int() or not coordinates[1].is_valid_int(): return false
		var pos := [int(coordinates[0]),int(coordinates[1])]
		if not _position_valid(pos) or not _walkable(state.floors[str(int(enemy.floor))],pos): return false
		defeated[enemy.id] = true
		counts[enemy.rank] += 1
		if enemy.rank == "boss":
			if int(enemy.floor) != int(state.reward_content.enemies[enemy.enemy_id].boss_floor): return false
			mid_boss = mid_boss or int(enemy.floor) == 5
			final_boss = final_boss or int(enemy.floor) == 10
	if not state.boss_rewards_claimed.is_empty() and not mid_boss: return false
	if state.floors.has("5"):
		if boss_entities[5] != (0 if mid_boss else 1) or mid_reward_count != (1 if state.boss_rewards_claimed.is_empty() else 0): return false
		if not state.boss_choice.is_empty() and state.boss_choice not in state.player.equipment_ids: return false
	if state.floors.has("10") and boss_entities[10] != (0 if final_boss else 1): return false
	if state.result.is_empty():
		return not state.completed and int(state.player.hp) > 0 and not state.has("settlement") and not final_boss and value.meta.last_settled_run_id != state.run_id
	if not state.completed or not state.pending.is_empty() or not state.get("settlement") is Dictionary:
		return false
	if state.result == "death" and int(state.player.hp) != 0: return false
	if state.result == "victory" and (not final_boss or int(state.floor) != 10 or int(state.player.hp) <= 0): return false
	if state.result != "victory" and final_boss: return false
	var settlement: Dictionary = state.settlement
	if settlement.get("committed") != true or settlement.get("run_id") != state.run_id or settlement.get("result") != state.result or value.meta.last_settled_run_id != state.run_id:
		return false
	for key in ["souls","regular","elite","boss","victory_bonus","balance_before","balance_after"]:
		if not _valid_count(settlement.get(key)): return false
	if int(settlement.regular) != counts.normal or int(settlement.elite) != counts.elite or int(settlement.boss) != counts.boss: return false
	var bonus := 20 if state.result == "victory" else 0
	var earned: int = counts.normal * 2 + counts.elite * 2 + counts.boss * 5 + bonus if state.result != "abandoned" else 0
	if int(settlement.souls) != earned or int(settlement.victory_bonus) != bonus or int(settlement.balance_after) != int(settlement.balance_before) + earned: return false
	if value.meta.records.is_empty(): return false
	var record: Dictionary = value.meta.records.back()
	return record.run_id == state.run_id and record.result == state.result and int(record.souls) == earned and int(record.floor) == int(state.floor)

func _valid_meta(meta: Dictionary) -> bool:
	if meta.has("meta_schema_version"):
		if not _integer(meta.meta_schema_version, 1, 2): return false
		if meta.meta_schema_version == 2 and not Phase3Validation.valid_meta(meta): return false
	if meta.get("meta_schema_version", 1) == 1:
		for key in P3Progress.default_extensions():
			if key != "meta_schema_version" and meta.has(key): return false
	for key in ["souls","souls_earned_total","failure_count","runs","wins","best_floor"]:
		if not _valid_count(meta.get(key)): return false
	if int(meta.best_floor) > 10 or int(meta.wins) + int(meta.failure_count) > int(meta.runs): return false
	if not _levels(meta.get("upgrades")) or not meta.get("upgrade_spend") is Dictionary: return false
	var spent := 0
	for kind in Progress.KINDS:
		if not _valid_count(meta.upgrade_spend.get(kind)): return false
		# Current price version is fixed; prevent malformed JSON inventing refundable funds.
		var expected: int = [0,8,24,48][int(meta.upgrades[kind])]
		if int(meta.upgrade_spend[kind]) != expected: return false
		spent += int(meta.upgrade_spend[kind])
	if int(meta.souls) + spent != int(meta.souls_earned_total): return false
	if not meta.get("milestones") is Array or not meta.get("records") is Array or meta.records.size() > 30 or not meta.get("last_settled_run_id") is String:
		return false
	var milestones := {}
	for item in meta.milestones:
		if item not in ["first_victory","zero_upgrade_victory","all_upgrades"] or milestones.has(item): return false
		milestones[item] = true
	var ids := {}
	var recent_wins := 0
	var recent_deaths := 0
	var recent_souls := 0
	var previous_failure := -1
	for record in meta.records:
		if not record is Dictionary or not _text(record.get("run_id")) or ids.has(record.run_id) or record.get("result", "") not in ["death","victory","abandoned"]: return false
		if record.has("relic_story_id") and (not _text(record.relic_story_id) or record.relic_story_id.length() > 64): return false
		if not _integer(record.get("floor"),1,10) or not record.get("seed") is String or not record.seed.is_valid_int(): return false
		for key in ["souls","kills","failure_count"]:
			if not _valid_count(record.get(key)): return false
		if int(record.floor) > int(meta.best_floor) or int(record.failure_count) > int(meta.failure_count): return false
		if record.has("highest_floor") and not _integer(record.highest_floor,int(record.floor),int(meta.best_floor)): return false
		if record.result == "abandoned" and int(record.souls) != 0: return false
		if record.result == "victory": recent_wins += 1
		if record.result == "death": recent_deaths += 1
		if previous_failure >= 0 and int(record.failure_count) != previous_failure + (1 if record.result == "death" else 0): return false
		previous_failure = int(record.failure_count)
		recent_souls += int(record.souls)
		ids[record.run_id] = true
	if meta.records.size() != mini(int(meta.runs), 30): return false
	if int(meta.wins) < recent_wins or int(meta.failure_count) < recent_deaths or int(meta.souls_earned_total) < recent_souls: return false
	if meta.records.is_empty(): return meta.last_settled_run_id.is_empty() and int(meta.runs) == 0
	return meta.records.back().run_id == meta.last_settled_run_id and int(meta.records.back().failure_count) == int(meta.failure_count)

func _levels(value: Variant) -> bool:
	if not value is Dictionary: return false
	for kind in Progress.KINDS:
		if not _integer(value.get(kind), 0, 3): return false
	return true

func _valid_story(value: Variant) -> bool:
	if not value is Dictionary or not value.get("queue") is Array or not value.get("seen") is Array or value.queue.size() > 32 or value.seen.size() > 64: return false
	var seen := {}
	for id in value.seen:
		if not _text(id) or seen.has(id): return false
		seen[id] = true
	var queued := {}
	for event in value.queue:
		if not event is Dictionary or not _text(event.get("id")) or not seen.has(event.id) or queued.has(event.id) or not event.get("title") is String or not event.get("audio_cue") is String or not event.get("lines") is Array or event.lines.is_empty(): return false
		queued[event.id] = true
		for line in event.lines:
			if not line is Dictionary or not line.get("speaker") is String or not line.get("text") is String: return false
	return true

func _valid_plan(value: Variant, items: Dictionary, rules_version: int = 1) -> bool:
	if not value is Dictionary or not _integer(value.get("version"), rules_version, rules_version) or not value.get("floors") is Dictionary or value.floors.size() != 10 or not value.get("budget") is Dictionary: return false
	for key in ["equipment_opportunities","relic_opportunities","merchants","rests","events"]:
		if not _valid_count(value.budget.get(key)): return false
	for number in range(1,11):
		var recipe = value.floors.get(str(number))
		if not recipe is Dictionary or not _integer(recipe.get("template_id"),0,5) or not _text(recipe.get("floor_seed")) or not recipe.floor_seed.is_valid_int() or not recipe.get("fixed_equipment") is Array: return false
		if not _budget_pair(recipe.get("reward_budget")): return false
		for id in recipe.fixed_equipment:
			if not id is String or not items.has(id): return false
	return true

func _valid_campaign_rules(value: Variant, content: Dictionary, plan: Dictionary, rules_version: int = 1, challenge: Dictionary = {}) -> bool:
	if not value is Dictionary or not _integer(value.get("version"), rules_version, rules_version): return false
	if not value.get("floor_names") is Array or value.floor_names.size() != 10: return false
	for name in value.floor_names:
		if not _text(name): return false
	if not value.get("normal_templates") is Array or value.normal_templates.size() != 6: return false
	for name in value.normal_templates:
		if not _text(name): return false
	if not value.get("floor_budgets") is Array or value.floor_budgets.size() != 10 or not value.get("budget") is Dictionary: return false
	var equipment_total := 0
	var relic_total := 0
	for number in range(1,11):
		var pair = value.floor_budgets[number-1]
		if not _budget_pair(pair): return false
		var planned: Array = plan.floors[str(number)].reward_budget
		if int(pair[0]) != int(planned[0]) or int(pair[1]) != int(planned[1]): return false
		equipment_total += int(pair[0])
		relic_total += int(pair[1])
	for key in ["equipment_opportunities","relic_opportunities","merchants","rests","events"]:
		if not _valid_count(value.budget.get(key)) or int(value.budget[key]) != int(plan.budget[key]): return false
	if equipment_total > int(value.budget.equipment_opportunities) or relic_total > int(value.budget.relic_opportunities): return false
	for key in ["merchant_floors","rest_floors","theme_relic_floors"]:
		if not value.get(key) is Array: return false
		var seen := {}
		for number in value[key]:
			if not _integer(number,2,9) or int(number) == 5 or seen.has(int(number)): return false
			seen[int(number)] = true
	if value.merchant_floors.size() > int(value.budget.merchants) or value.rest_floors.size() > int(value.budget.rests): return false
	if not value.get("event_floors") is Dictionary or not value.get("elite_floors") is Dictionary or value.event_floors.size() > int(value.budget.events): return false
	for key in ["event_floors","elite_floors"]:
		var catalog: Dictionary = content.events if key == "event_floors" else content.enemies
		for floor_id in value[key]:
			if not _decimal64(floor_id) or int(floor_id) < 2 or int(floor_id) > 9 or int(floor_id) == 5 or not value[key][floor_id] is String or not catalog.has(value[key][floor_id]): return false
			if key == "elite_floors" and catalog[value[key][floor_id]].rank != "elite": return false
	if not value.get("fixed_equipment") is Dictionary: return false
	for floor_id in value.fixed_equipment:
		if not _decimal64(floor_id) or int(floor_id) < 1 or int(floor_id) > 10 or not value.fixed_equipment[floor_id] is Array: return false
		for id in value.fixed_equipment[floor_id]:
			if not id is String or not content.items.has(id) or content.items[id].kind != "equipment": return false
	for number in range(1,11):
		if plan.floors[str(number)].fixed_equipment != value.fixed_equipment.get(str(number),[]): return false
	if not value.get("themes") is Dictionary: return false
	for theme in ["battle","treasure","shop"]:
		if not value.themes.get(theme) is Dictionary or not _text(value.themes[theme].get("name")) or not value.themes[theme].get("description") is String: return false
	if not value.get("enemy_overrides") is Dictionary: return false
	for id in value.enemy_overrides:
		if not id is String or not content.enemies.has(id) or not value.enemy_overrides[id] is Dictionary: return false
		for field in value.enemy_overrides[id]:
			if field not in ["name","hp","attack","defense","gold_reward"]: return false
			var expected: Variant = value.enemy_overrides[id][field]
			if field == "name" and not expected is String: return false
			if field != "name" and not _valid_count(expected): return false
			if rules_version == 2 and field in ["hp", "attack"]:
				if not _valid_count(expected): return false
				var boss: bool = content.enemies[id].rank == "boss"
				if field == "hp":
					expected = ceili(float(expected) * float(challenge.get("boss_hp_percent" if boss else "normal_hp_percent", 0)) / 100.0)
				else: expected += int(challenge.get("boss_attack" if boss else "normal_attack", -1))
			if expected != content.enemies[id].get(field): return false
	return true

func _budget_pair(value: Variant) -> bool:
	return value is Array and value.size() == 2 and _valid_count(value[0]) and _valid_count(value[1])

func _text(value: Variant) -> bool:
	return value is String and not value.is_empty() and value.length() <= 256

