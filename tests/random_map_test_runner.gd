extends "res://tests/map_test_runner.gd"
## Uses the production generator. The parent provides BFS movement and assertions;
## no fixed coordinates are used for generated maps.

const Generator = preload("res://scripts/core/map_generator.gd")
const Validator = preload("res://scripts/core/map_validator.gd")
const KeyRules = preload("res://scripts/core/map_keys.gd")
const Enemies = preload("res://scripts/core/enemy_rules.gd")

func _initialize() -> void:
	path = "user://random_map_test_%d.json" % OS.get_process_id()
	_test_many_seeds()
	_test_monster_constraints()
	for seed_text in ["0", "42", "20260929"]:
		for theme_id in ["battle", "treasure", "shop"]:
			_test_generated_return(seed_text, theme_id)
	_test_generated_shop_and_save()
	_test_failed_generation()
	_test_legacy_save_compatibility()
	for suffix in ["", ".bak", ".tmp"]:
		if FileAccess.file_exists(path + suffix):
			DirAccess.remove_absolute(ProjectSettings.globalize_path(path + suffix))
	print("Random map tests: %d checks, %d failures" % [checks, failures])
	quit(1 if failures > 0 else 0)

func _random_game(seed_text: String):
	var core = Core.new(path)
	core.persistence_enabled = false
	_check(core.start(seed_text).is_empty(), "random game starts")
	return core

func _find(core, role: String) -> Vector2i:
	for entity in core.floor_data().entities.values():
		if entity.get("role", "") == role:
			return Validator.point(entity.pos)
	_check(false, "role exists: " + role)
	return Vector2i(-1, -1)

func _activate(core, cell: Vector2i) -> void:
	if core.position() == cell:
		core.interact(cell)
	else:
		_walk(core, cell)

func _test_many_seeds() -> void:
	var generator = Generator.new()
	var validator = Validator.new()
	var shapes: Dictionary = {}
	var layouts: Dictionary = {}
	for seed_value in 80:
		for theme_id in ["entrance", "battle", "treasure", "shop"]:
			var number := 1 if theme_id == "entrance" else 2
			var floor_state: Dictionary = generator.generate(str(seed_value), number, theme_id)
			_check(not floor_state.is_empty(), "generation succeeds %d %s" % [seed_value, theme_id])
			if floor_state.is_empty():
				continue
			_check(validator.validate(floor_state).is_empty(), "runtime constraints pass")
			_check(floor_state == generator.generate(str(seed_value), number, theme_id), "same inputs reproduce full map")
			var enemy_count := 0
			for entity in floor_state.entities.values():
				if entity.type == "enemy":
					enemy_count += 1
					_check(Enemies.valid_placement(validator.db.enemy(entity.enemy_id), entity), "monster fits branch role and tier")
			_check(enemy_count == int(Enemies.THEME_COUNTS[theme_id]), "theme uses designed number of monsters")
			shapes[str(floor_state.rows)] = true
			layouts[str(floor_state.entities)] = true
			if theme_id == "shop":
				var merchants := 0
				for entity in floor_state.entities.values():
					merchants += int(entity.type == "shop")
				_check(merchants == 1, "shop theme includes exactly one merchant")
	_check(shapes.size() >= 8 and layouts.size() >= 80, "seeds vary geometry and placement")
	var original: Dictionary = generator.generate("42", 2, "treasure")
	var broken := original.duplicate(true)
	for cell in broken.entities.keys():
		if broken.entities[cell].type == "key":
			broken.entities.erase(cell)
	_check(not validator.validate(broken).is_empty(), "validator rejects missing keys")
	broken = original.duplicate(true)
	broken.rows[0] = "..........."
	_check(not validator.validate(broken).is_empty(), "validator rejects open boundary")
	_check(generator.generate("42", 3, "battle").is_empty(), "unsupported floor fails explicitly")
	_check(generator.generate("42", 1, "shop").is_empty(), "theme/floor mismatch rejected")

func _collect_key(core, key_kind: String = "copper") -> void:
	if KeyRules.count(core.state.player, key_kind) > 0:
		return
	for entity in core.floor_data().entities.values():
		if entity.type == "key" and KeyRules.kind(entity) == key_kind:
			_walk(core, Validator.point(entity.pos))
			return
	_check(false, "a matching key is available before opening armor gate: " + key_kind)

func _test_monster_constraints() -> void:
	var core = _random_game("42")
	var guardian := _find(core, "return_guard_gate")
	core.floor_data().entities[Core.cell_key(guardian)].guardian = false
	_check(not core.generator.validator.validate(core.floor_data()).is_empty(), "return guard must carry its role marker")
	var generator = Generator.new()
	var original: Dictionary = generator.generate("42", 2, "battle")
	var broken := original.duplicate(true)
	for entity in broken.entities.values():
		if entity.get("role", "") == "weapon_trial_gate":
			entity.enemy_id = "knight"
	_check(not generator.validator.validate(broken).is_empty(), "strong monster cannot replace guaranteed growth guardian")
	broken = original.duplicate(true)
	for cell in broken.entities.keys():
		if broken.entities[cell].get("role", "") == "gold_fight_gate":
			broken.entities.erase(cell)
	_check(not generator.validator.validate(broken).is_empty(), "missing encounter fails theme count")
	broken = original.duplicate(true)
	for entity in broken.entities.values():
		if entity.get("role", "") == "armor_trial_reward":
			entity.item_id = "iron_armor"
	_check(not generator.validator.validate(broken).is_empty(), "weaker armor cannot replace guaranteed growth equipment")

func _take_branch(core, role: String) -> void:
	var gate := _find(core, role + "_gate")
	var reward := _find(core, role + "_reward")
	if core.entity_at(gate).type == "door":
		_collect_key(core, KeyRules.kind(core.entity_at(gate)))
	_activate(core, gate)
	_check(core.confirm_interaction().is_empty(), "branch gate resolved: " + role)
	_check(core.active(), "branch encounter survives: " + role)
	_walk(core, reward)

func _test_generated_return(seed_text: String, theme_id: String) -> void:
	var core = _random_game(seed_text)
	var guardian := _find(core, "return_guard_gate")
	_check(core.preview(guardian).lethal, "generated return guard starts lethal")
	var stairs := _find(core, "exit")
	_activate(core, stairs)
	_check(core.state.pending.kind == "stairs", "first ascent uses stairs")
	var pending_snapshot: Dictionary = core.state.duplicate(true)
	core.cancel_pending()
	_activate(core, stairs)
	_check(core.state.floors == pending_snapshot.floors, "cancel does not generate or mutate floors")
	_enter_fixture_theme(core, theme_id)
	_check(core.state.floor == 2, "chosen theme entered")
	_take_branch(core, "weapon_trial")
	_take_branch(core, "armor_trial")
	var second_snapshot: Dictionary = core.floor_data().duplicate(true)
	_activate(core, _find(core, "entry"))
	core.confirm_interaction()
	_check(core.state.floor == 1, "backtracking reaches floor one")
	var report: Dictionary = core.preview(guardian)
	_check(not report.lethal and report.loss == 77, "generated route makes old guard survivable at designed cost")
	_take_branch(core, "return_guard")
	_check(core.state.objective_complete, "return objective completes on generated map")
	var first_snapshot: Dictionary = core.floor_data().duplicate(true)
	_activate(core, stairs)
	_check(core.state.pending.kind == "stairs", "revisit uses fixed stair connection")
	_check(not core.choose_floor("shop").is_empty(), "revisit cannot reroll theme")
	core.confirm_interaction()
	_check(core.floor_data() == second_snapshot, "floor two retains removed rewards")
	core.interact(core.position())
	core.confirm_interaction()
	_check(core.floor_data() == first_snapshot, "floor one retains defeated guardian and trophy")

func _test_generated_shop_and_save() -> void:
	var core = _random_game("314159")
	core.persistence_enabled = true
	_activate(core, _find(core, "exit"))
	var loaded = Core.new(path)
	loaded.load_game()
	_check(loaded.state.pending.kind == "stairs", "random pending stairs resume")
	_enter_fixture_theme(core, "shop")
	_enter_fixture_theme(loaded, "shop")
	_check(SavedData.equal(core.state.floors, loaded.state.floors), "reload produces same unvisited floor")
	var expected: Dictionary = core.generator.generate(str(core.state.seed), 2, "shop")
	core.rng.randi()
	core.rng.randi()
	_check(core._generate_floor(2, "shop") == expected, "unrelated RNG calls do not influence floor")
	var merchant := _find(core, "merchant")
	_activate(core, merchant)
	core.state.player.gold = 0
	_check(not core.buy(0).is_empty(), "random shop checks affordability")
	core.cancel_pending()
	core.state.player.gold = 100
	_activate(core, merchant)
	var offer: Dictionary = core.db.shop_item(core.entity_at(merchant).offers[0])
	core.buy(0)
	_check(core.state.player.gold == 100 - int(offer.price), "random purchase price charged once")
	loaded.load_game()
	_check(loaded.entity_at(merchant).purchased_ids.size() == 1, "random shop sold item survives reload")
	loaded.interact(loaded.position())
	_check(not loaded.buy(0).is_empty(), "sold item cannot be bought again after reload")
	_check(loaded.buy(1).is_empty(), "another item can be bought after reload")

func _test_failed_generation() -> void:
	var core = _random_game("2026")
	_activate(core, _find(core, "exit"))
	var before: Dictionary = core.state.duplicate(true)
	var invalid: Dictionary = core.generator.config.templates[0].duplicate(true)
	invalid.rows[0] = "..........."
	core.generator.config.templates = [invalid]
	core.generator.config.max_attempts = 2
	_check(not core.confirm_interaction().is_empty(), "invalid geometry fails after bounded retries")
	_check(core.state == before, "failed floor generation preserves pending stairs and old floor")
	_check(not core.start("bad-new-run").is_empty(), "failed new run returns error")
	_check(core.state == before, "failed new run preserves previous run")

func _test_legacy_save_compatibility() -> void:
	var old = _new_game("42")
	old.persistence_enabled = true
	old.state.erase("generator_version")
	old.save_game()
	var loaded = Core.new(path)
	loaded.load_game()
	_check(SavedData.equal(loaded.state.floors, old.state.floors), "existing hand-built floor survives update unchanged")
	_walk(loaded, Vector2i(9, 1))
	loaded.confirm_interaction()
	_check(not loaded.floor_data().has("generator"), "old saves keep hand-built future floor")
