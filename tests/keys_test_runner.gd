extends "res://tests/random_map_test_runner.gd"
## Real production pickup, door, persistence and generator validation tests.

func _initialize() -> void:
	path = "user://keys_test_%d.json" % OS.get_process_id()
	for key_kind in KeyRules.TYPES:
		_test_pickup(key_kind)
		_test_matching_door(key_kind)
	_test_typed_generation()
	_test_colored_save()
	_test_old_inventory_migration()
	_test_v1_generation_compatibility()
	for suffix in ["", ".bak", ".tmp"]:
		if FileAccess.file_exists(path + suffix):
			DirAccess.remove_absolute(ProjectSettings.globalize_path(path + suffix))
	print("Key tests: %d checks, %d failures" % [checks, failures])
	quit(1 if failures > 0 else 0)

func _test_pickup(key_kind: String) -> void:
	var core = _new_game()
	var target := Vector2i(2, 5)
	core.entity_at(target).key_kind = key_kind
	_walk(core, target)
	for other in KeyRules.TYPES:
		_check(KeyRules.count(core.state.player, other) == (1 if other == key_kind else 0), "pickup increments only matching inventory")
	core.interact(target)
	_check(KeyRules.count(core.state.player, key_kind) == 1 and core.entity_at(target).is_empty(), "colored key cannot be collected twice")

func _test_matching_door(key_kind: String) -> void:
	var core = _new_game()
	var target := Vector2i(1, 3)
	core.entity_at(target).key_kind = key_kind
	for other in KeyRules.TYPES:
		core.state.player[KeyRules.FIELDS[other]] = 0 if other == key_kind else 9
	_walk(core, target)
	var before: Dictionary = core.state.duplicate(true)
	_check(not core.confirm_interaction().is_empty(), "other key colors cannot open " + key_kind + " door")
	_check(core.state == before, "wrong key attempt spends nothing and keeps pending door")
	core.state.player[KeyRules.FIELDS[key_kind]] = 1
	_check(core.confirm_interaction().is_empty(), "matching key opens door")
	_check(KeyRules.count(core.state.player, key_kind) == 0 and core.entity_at(target).is_empty(), "one matching key spent and door removed")
	for other in KeyRules.TYPES:
		if other != key_kind:
			_check(KeyRules.count(core.state.player, other) == 9, "opening leaves other key colors untouched")
	core.interact(target)
	core.confirm_interaction()
	_check(KeyRules.count(core.state.player, key_kind) == 0, "opened door does not charge again")

func _test_typed_generation() -> void:
	var generator = Generator.new()
	var validator = Validator.new()
	var seen: Dictionary = {}
	for seed_value in 30:
		for theme_id in ["entrance", "battle", "treasure", "shop"]:
			var number := 1 if theme_id == "entrance" else 2
			var map: Dictionary = generator.generate(str(seed_value), number, theme_id)
			_check(not map.is_empty() and validator.validate(map).is_empty(), "typed key budget validates")
			var amounts := {"copper": 0, "silver": 0, "gold": 0}
			var costs := {"copper": 0, "silver": 0, "gold": 0}
			for entity in map.entities.values():
				if entity.type in ["key", "door"]:
					_check(entity.has("key_kind"), "v2 entities explicitly store key type")
					var kind: String = KeyRules.kind(entity)
					seen[kind] = true
					if entity.type == "key":
						amounts[kind] += int(entity.amount)
					else:
						costs[kind] += int(entity.cost)
			for kind in KeyRules.TYPES:
				_check(amounts[kind] >= costs[kind], "sufficient keys of each color")
	_check(seen.size() == 3, "all three key and door types appear in generated content")
	var map: Dictionary = generator.generate("42", 2, "treasure")
	var wrong_colors := map.duplicate(true)
	for entity in wrong_colors.entities.values():
		if entity.type == "key":
			entity.key_kind = "copper"
	_check(not validator.validate(wrong_colors).is_empty(), "equal total key count cannot mask wrong colors")
	var bad_type := map.duplicate(true)
	for entity in bad_type.entities.values():
		if entity.type == "door":
			entity.key_kind = "unknown"
			break
	_check(not validator.validate(bad_type).is_empty(), "unknown door kind rejected")

func _test_colored_save() -> void:
	var core = _random_game("2209")
	core.persistence_enabled = true
	core.state.player.keys = 4
	core.state.player.silver_keys = 3
	core.state.player.gold_keys = 2
	_activate(core, _find(core, "exit"))
	core.choose_floor("treasure")
	var silver_gate := _find(core, "armor_trial_gate")
	_activate(core, silver_gate)
	var before: Dictionary = core.state.player.duplicate(true)
	core.confirm_interaction()
	_check(core.state.player.silver_keys == before.silver_keys - 1, "silver door consumes silver key")
	_check(core.state.player.keys == before.keys and core.state.player.gold_keys == before.gold_keys, "silver door preserves copper and gold")
	var gold_gate := _find(core, "treasure_vault_gate")
	_activate(core, gold_gate)
	var loaded = Core.new(path)
	loaded.load_game()
	_check(SavedData.equal(loaded.state.player, core.state.player), "all colored inventories survive save/load")
	_check(KeyRules.kind(loaded.entity_at(loaded.pending_cell())) == "gold", "pending gold-door interaction survives reload")
	_check(loaded.entity_at(silver_gate).is_empty(), "opened silver door remains removed after reload")
	loaded.cancel_pending()
	_activate(loaded, _find(loaded, "entry"))
	loaded.confirm_interaction()
	_check(loaded.state.floor == 1, "return to floor one after colored interactions")
	loaded.interact(loaded.position())
	loaded.confirm_interaction()
	_check(loaded.entity_at(silver_gate).is_empty() and KeyRules.kind(loaded.entity_at(gold_gate)) == "gold", "colored door states persist across floor travel")
	var bad := {"version": 1, "meta": {}, "run": loaded.state.duplicate(true)}
	bad.run.player.silver_keys = -1
	_check(not loaded.store._valid(bad), "save rejects negative colored inventory")
	bad.run.player.silver_keys = 0
	bad.run.floors["2"].entities[Core.cell_key(gold_gate)].key_kind = "unknown"
	_check(not loaded.store._valid(bad), "save rejects unknown door colors")

func _test_old_inventory_migration() -> void:
	var old = _new_game()
	old.persistence_enabled = true
	old.state.player.keys = 7
	old.state.player.erase("silver_keys")
	old.state.player.erase("gold_keys")
	old.save_game()
	var old_floor: Dictionary = old.floor_data().duplicate(true)
	var loaded = Core.new(path)
	loaded.load_game()
	_check(loaded.state.player.keys == 7 and loaded.state.player.silver_keys == 0 and loaded.state.player.gold_keys == 0, "old keys preserved as copper, new inventories start at zero")
	_check(SavedData.equal(loaded.floor_data(), old_floor), "migration does not replace existing maps")
	_check(KeyRules.kind(loaded.entity_at(Vector2i(1, 3))) == "copper", "old untyped doors default to copper")
	loaded.save_game()
	loaded.load_game()
	_check(loaded.state.player.keys == 7, "migration is idempotent")
	_check(loaded.shop_offer("buy_key").name == "铜钥匙", "legacy shop keys have an unambiguous copper label")

func _test_v1_generation_compatibility() -> void:
	var core = _random_game("52")
	core.persistence_enabled = true
	core.state.generator_version = 1
	core.state.floors = {"1": core.generator.generate("52", 1, "entrance", 1)}
	core.state.position = core.floor_data().entry.duplicate()
	core.state.player.erase("silver_keys")
	core.state.player.erase("gold_keys")
	core.save_game()
	var loaded = Core.new(path)
	loaded.load_game()
	_activate(loaded, _find(loaded, "exit"))
	_check(loaded.choose_floor("treasure").is_empty(), "v1 save can still generate its unvisited second floor")
	_check(loaded.floor_data().generator.version == 1, "v1 save retains generator version")
	for entity in loaded.floor_data().entities.values():
		if entity.type in ["key", "door"]:
			_check(not entity.has("key_kind") and KeyRules.kind(entity) == "copper", "v1 generation retains original untyped copper layout")
