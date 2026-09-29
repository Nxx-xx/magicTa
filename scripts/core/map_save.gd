extends "res://scripts/core/save_store.gd"
## Strict shape/reference validation applies to persisted state, not fresh-map recipes.
const Keys = preload("res://scripts/core/map_keys.gd")
const DB = preload("res://scripts/core/content_db.gd")
const EnemyRulesData = preload("res://scripts/core/enemy_rules.gd")
const MAX_COUNT := 1000000000

func _valid(value: Variant) -> bool:
	return value is Dictionary and value.get("version", 0) == 1 and value.get("meta") is Dictionary and value.get("run") is Dictionary and value.run.get("mode", "") == "grid_prototype_v1" and _valid_state(value.run, 2)

func _valid_state(state: Dictionary, limit: int) -> bool:
	for field in ["seed", "rng_state"]:
		if not _decimal64(state.get(field)):
			return false
	for field in ["player", "floors", "pending", "last_report"]:
		if not state.get(field) is Dictionary:
			return false
	for field in ["completed", "objective_complete", "summit_seen"]:
		if not state.get(field) is bool:
			return false
	if not state.get("last_message") is String or not _integer(state.get("floor"), 1, limit):
		return false
	if state.has("generator_version") and not _integer(state.generator_version, 0, 3):
		return false
	var content: Dictionary = DB.new().data
	if state.has("reward_content"):
		if not _valid_content(state.reward_content):
			return false
		for category in state.reward_content:
			content[category] = state.reward_content[category]
	if not _valid_player(state.player, content):
		return false
	if int(state.player.hp) == 0 and not state.completed: return false
	if not _valid_report(state.last_report): return false
	if not _position_valid(state.get("position")) or not state.floors.has(str(int(state.floor))) or not state.floors.has("1"):
		return false
	for floor_id in state.floors:
		if not floor_id is String or not floor_id.is_valid_int() or str(int(floor_id)) != floor_id or int(floor_id) < 1 or int(floor_id) > limit:
			return false
		if not _valid_floor(state.floors[floor_id], content):
			return false
	var active_floor: Dictionary = state.floors[str(int(state.floor))]
	if not _walkable(active_floor, state.position):
		return false
	if active_floor.entities.get(_cell_key(state.position), {}).get("type", "") in ["enemy","door"]: return false
	var pending: Dictionary = state.pending
	if not pending.is_empty():
		if state.completed or pending.get("kind", "") not in ["entity", "stairs", "floor_choice"] or not _position_valid(pending.get("pos")):
			return false
		var entity: Dictionary = active_floor.entities.get(_cell_key(pending.pos), {})
		if entity.is_empty() or abs(int(state.position[0]) - int(pending.pos[0])) + abs(int(state.position[1]) - int(pending.pos[1])) > 1:
			return false
		match pending.kind:
			"entity":
				if entity.type not in ["enemy", "door", "shop", "potion", "choice", "event", "rest"]:
					return false
			"stairs":
				if entity.type not in ["up", "down"] or not _integer(pending.get("destination"), 1, limit):
					return false
				var expected := int(state.floor) + (1 if entity.type == "up" else -1)
				if int(pending.destination) != expected or not state.floors.has(str(expected)):
					return false
			"floor_choice":
				if entity.type != "up" or int(state.floor) >= limit or state.floors.has(str(int(state.floor) + 1)):
					return false
	return true

func _valid_player(player: Dictionary, content: Dictionary) -> bool:
	for field in ["hp", "max_hp", "attack", "defense", "gold", "keys"]:
		if not _valid_count(player.get(field)):
			return false
	if int(player.max_hp) < 1 or int(player.attack) < 1:
		return false
	for field in Keys.FIELDS.values():
		if player.has(field) and not _valid_count(player[field]):
			return false
	var maximum := int(player.max_hp)
	for field in ["equipment_ids", "relic_ids"]:
		if not player.get(field) is Array or player[field].size() > 1000:
			return false
		for id in player[field]:
			if not id is String or not content.items.has(id):
				return false
			if content.items[id].kind != ("equipment" if field == "equipment_ids" else "relic"):
				return false
			maximum += int(content.items[id].effects.get("max_hp", 0))
	return int(player.hp) <= maximum

func _valid_report(report: Dictionary) -> bool:
	if report.is_empty(): return true
	for key in ["turns","counterattacks","incoming","healing","hp_after","enemy_hp_after","gold_reward"]:
		if not _valid_count(report.get(key)): return false
	if not _integer(report.get("loss"),-MAX_COUNT,MAX_COUNT) or not report.get("won") is bool or not report.get("lethal") is bool or report.won == report.lethal: return false
	if not report.get("log") is Array or report.log.size() != int(report.turns): return false
	var turn := 0
	for entry in report.log:
		turn += 1
		if not entry is Dictionary or not _integer(entry.get("turn"),turn,turn): return false
		for key in ["hit","enemy_hp","counter","hp"]:
			if not _valid_count(entry.get(key)): return false
		if not entry.get("note") is String: return false
	return true

func _valid_floor(value: Variant, content: Dictionary) -> bool:
	if not value is Dictionary:
		return false
	for field in ["theme", "name"]:
		if not value.get(field) is String:
			return false
	if not value.get("rows") is Array or value.rows.size() != 11 or not value.get("entities") is Dictionary:
		return false
	for row in value.rows:
		if not row is String or row.length() != 11:
			return false
		for ch in row:
			if ch not in ["#", "."]:
				return false
	if not _position_valid(value.get("entry")) or not _position_valid(value.get("exit")) or not _walkable(value, value.entry) or not _walkable(value, value.exit):
		return false
	for key in value.entities:
		var entity = value.entities[key]
		if not entity is Dictionary or not _position_valid(entity.get("pos")) or key != _cell_key(entity.pos) or not _walkable(value, entity.pos):
			return false
		if not entity.get("name") is String or not entity.get("type") is String:
			return false
		for flag in ["guardian", "objective", "campaign_boss", "campaign_boss_reward"]:
			if entity.has(flag) and not entity[flag] is bool: return false
		if entity.type in ["door", "key"] and Keys.kind(entity) not in Keys.TYPES:
			return false
		match entity.type:
			"enemy":
				if not _reference(entity, "enemy_id", content.enemies): return false
			"chest":
				if not _reference(entity, "item_id", content.items) or not _valid_count(entity.get("gold")): return false
			"choice":
				if not entity.get("choices") is Array or entity.choices.size() != 2 or entity.choices[0] == entity.choices[1] or not _valid_count(entity.get("gold")): return false
				for id in entity.choices:
					if not id is String or not content.items.has(id): return false
			"event":
				if not _reference(entity, "event_id", content.events): return false
			"rest":
				if not _valid_options(entity.get("options"), content.items): return false
			"gold", "key", "potion":
				if not _integer(entity.get("amount"), 1, MAX_COUNT): return false
			"door":
				if not _integer(entity.get("cost"), 1, MAX_COUNT): return false
			"shop":
				if not entity.get("offers") is Array or not entity.get("purchased") is bool: return false
				for id in entity.offers:
					if not id is String or not content.shop.has(id): return false
				if entity.get("purchased", false) and entity.get("purchased_id", "") not in entity.offers: return false
			"camp", "summit":
				if not entity.get("description") is String: return false
			"up", "down": pass
			_: return false
	return true

func _valid_content(value: Variant) -> bool:
	if not value is Dictionary: return false
	for category in ["items", "shop", "events"]:
		if not value.get(category) is Dictionary or value[category].is_empty(): return false
	for id in value.items:
		var item = value.items[id]
		if not id is String or not item is Dictionary or item.get("kind", "") not in ["equipment", "relic"] or not item.get("name") is String or not _effects(item.get("effects"), ["attack", "defense", "max_hp", "kill_heal", "gold_bonus", "gold_attack_step"]): return false
		if not item.get("description") is String: return false
		if item.get("id", "") != id or not _integer(item.get("tier"),1,3): return false
		if item.has("price") and not _valid_count(item.price): return false
	for id in value.shop:
		var offer = value.shop[id]
		if not id is String or not offer is Dictionary or not offer.get("name") is String or not _valid_count(offer.get("price")) or not _reward(offer, value.items): return false
		if not offer.get("description") is String: return false
		if offer.has("min_floor") and not _integer(offer.min_floor,1,10): return false
	for id in value.events:
		var event = value.events[id]
		if not id is String or not event is Dictionary or not event.get("name") is String or not _valid_options(event.get("options"), value.items): return false
		if not event.get("description") is String: return false
	if value.has("enemies"):
		if not value.enemies is Dictionary or value.enemies.is_empty(): return false
		for id in value.enemies:
			var enemy = value.enemies[id]
			if not id is String or not enemy is Dictionary or not enemy.get("name") is String or not EnemyRulesData.valid_definition(enemy): return false
			if enemy.get("id", "") != id or not enemy.get("description") is String: return false
			for field in ["hp", "attack", "defense", "gold_reward"]:
				if not _valid_count(enemy.get(field)): return false
			if int(enemy.hp) == 0 or enemy.get("ability_id", "") not in ["", "rage", "stone_armor"]: return false
	return true

func _valid_options(value: Variant, items: Dictionary) -> bool:
	if not value is Array or value.size() != 2: return false
	for option in value:
		if not option is Dictionary or not option.get("name") is String or not _reward(option, items): return false
	return true

func _reward(value: Dictionary, items: Dictionary) -> bool:
	if value.has("item_id") and not _reference(value, "item_id", items): return false
	return _effects(value.get("cost", {}), ["hp", "gold", "keys", "silver_keys", "gold_keys"]) and _effects(value.get("effects", {}), ["attack", "defense", "max_hp", "gold", "keys", "silver_keys", "gold_keys", "heal"])

func _effects(value: Variant, allowed: Array) -> bool:
	if not value is Dictionary: return false
	for key in value:
		if key not in allowed or not _valid_count(value[key]): return false
	return true

func _reference(value: Dictionary, field: String, catalog: Dictionary) -> bool:
	return value.get(field) is String and catalog.has(value[field])

func _position_valid(value: Variant) -> bool:
	return value is Array and value.size() == 2 and _integer(value[0], 0, 10) and _integer(value[1], 0, 10)

func _walkable(floor_data: Dictionary, pos: Array) -> bool:
	return str(floor_data.rows[int(pos[1])]).substr(int(pos[0]), 1) == "."

func _cell_key(pos: Array) -> String:
	return "%d,%d" % [int(pos[0]), int(pos[1])]

func _valid_count(value: Variant) -> bool:
	return _integer(value, 0, MAX_COUNT)

func _integer(value: Variant, minimum: int, maximum: int) -> bool:
	return (value is int or value is float) and is_finite(float(value)) and float(value) >= minimum and float(value) <= maximum and float(value) == floorf(float(value))

func _decimal64(value: Variant) -> bool:
	return value is String and value.is_valid_int() and str(value.to_int()) == value
