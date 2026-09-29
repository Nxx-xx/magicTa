extends "res://scripts/core/save_store.gd"
## Separate schema and path keep the original card-mode save untouched.
const Keys = preload("res://scripts/core/map_keys.gd")

func _valid(value: Variant) -> bool:
	if not value is Dictionary or value.get("version", 0) != 1:
		return false
	if not value.get("run") is Dictionary:
		return false
	var state: Dictionary = value.run
	if state.get("mode", "") != "grid_prototype_v1":
		return false
	for field in ["seed", "rng_state", "floor", "position", "player", "floors", "pending",
			"completed", "last_message", "last_report", "objective_complete", "summit_seen"]:
		if not state.has(field):
			return false
	if not str(state.seed).is_valid_int() or not str(state.rng_state).is_valid_int():
		return false
	if not state.player is Dictionary or not state.floors is Dictionary:
		return false
	if not state.pending is Dictionary or not state.last_report is Dictionary:
		return false
	if not state.completed is bool or not state.objective_complete is bool:
		return false
	for field in ["hp", "max_hp", "attack", "defense", "gold", "keys", "equipment_ids", "relic_ids"]:
		if not state.player.has(field):
			return false
	if not state.player.equipment_ids is Array or not state.player.relic_ids is Array:
		return false
	if state.has("reward_content"):
		if not state.reward_content is Dictionary:
			return false
		for category in ["items", "shop", "events"]:
			if not state.reward_content.get(category) is Dictionary:
				return false
	for field in Keys.FIELDS.values():
		# Older saves have only `keys`; new counters are supplied after loading.
		if state.player.has(field) and not _valid_count(state.player[field]):
			return false
	if not _position_valid(state.position) or not state.floors.has(str(int(state.floor))):
		return false
	for id in state.floors:
		var floor_data = state.floors[id]
		if id not in ["1", "2"] or not floor_data is Dictionary:
			return false
		for key in ["rows", "entities", "theme", "name", "entry", "exit"]:
			if not floor_data.has(key):
				return false
		if not floor_data.rows is Array or floor_data.rows.size() != 11:
			return false
		for row in floor_data.rows:
			if not row is String or row.length() != 11:
				return false
		if not floor_data.entities is Dictionary:
			return false
		for key in floor_data.entities:
			var entity = floor_data.entities[key]
			if not entity is Dictionary or not _position_valid(entity.get("pos")):
				return false
			if key != "%d,%d" % [int(entity.pos[0]), int(entity.pos[1])]:
				return false
			if not entity.has("name") or not entity.has("type"):
				return false
			if entity.type in ["door", "key"] and Keys.kind(entity) not in Keys.TYPES:
				return false
			match str(entity.type):
				"enemy":
					if not entity.has("enemy_id"):
						return false
				"chest":
					if not entity.has("item_id") or not entity.has("gold"):
						return false
				"choice":
					if not entity.get("choices") is Array or entity.choices.size() != 2:
						return false
					if entity.choices[0] == entity.choices[1] or not _valid_count(entity.get("gold", -1)):
						return false
					for item_id in entity.choices:
						if not item_id is String or item_id.is_empty():
							return false
				"event":
					if not entity.get("event_id") is String or entity.event_id.is_empty():
						return false
				"rest":
					if not entity.get("options") is Array or entity.options.size() != 2:
						return false
					for option in entity.options:
						if not option is Dictionary or not option.get("effects") is Dictionary or not option.get("name") is String:
							return false
				"gold", "key", "potion":
					if not entity.has("amount"):
						return false
					if entity.type == "key" and (not _valid_count(entity.amount) or int(entity.amount) == 0):
						return false
				"door":
					if not entity.has("cost") or not _valid_count(entity.cost) or int(entity.cost) == 0:
						return false
				"shop":
					if not entity.get("offers") is Array or not entity.has("purchased"):
						return false
				"up", "down", "camp", "summit":
					pass
				_:
					return false
		if not _position_valid(floor_data.entry) or not _position_valid(floor_data.exit):
			return false
	if not state.pending.is_empty():
		if state.pending.get("kind", "") not in ["entity", "stairs", "floor_choice"]:
			return false
		if not _position_valid(state.pending.get("pos")):
			return false
		if state.pending.kind == "stairs" and not state.pending.has("destination"):
			return false
	return true

func _position_valid(value: Variant) -> bool:
	return value is Array and value.size() == 2 and int(value[0]) >= 0 and int(value[0]) < 11 and int(value[1]) >= 0 and int(value[1]) < 11

func _valid_count(value: Variant) -> bool:
	return (value is int or value is float) and is_finite(float(value)) and float(value) >= 0 and float(value) == floorf(float(value))
