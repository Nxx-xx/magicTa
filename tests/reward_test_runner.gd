extends "res://tests/random_map_test_runner.gd"
const Rewards = preload("res://scripts/core/rewards.gd")

func _initialize() -> void:
	path = "user://reward_test_%d.json" % OS.get_process_id()
	_test_all_rewards()
	_test_potions()
	_test_choice_resume()
	_test_purchase_preview()
	_test_events_and_rest()
	_test_reward_generation()
	_test_catalog_snapshot()
	for suffix in ["", ".bak", ".tmp"]:
		if FileAccess.file_exists(path + suffix):
			DirAccess.remove_absolute(ProjectSettings.globalize_path(path + suffix))
	print("Reward tests: %d checks, %d failures" % [checks, failures])
	quit(1 if failures else 0)

func _place_fixture(core, entity: Dictionary) -> Vector2i:
	var cell: Vector2i = core.position()
	entity.pos = [cell.x, cell.y]
	entity.name = entity.get("name", "测试奖励")
	core.floor_data().entities[Core.cell_key(cell)] = entity
	core.state.pending = {}
	return cell

func _test_all_rewards() -> void:
	var core = _random_game("rewards")
	for id in core.db.data.items:
		var player: Dictionary = core.state.player.duplicate(true)
		player.hp = 50
		player.gold = 100
		var original := player.duplicate(true)
		var first := Rewards.resolve(core.db, player, {"item_id": id})
		_check(first.ok and player == original, "reward preview is pure: " + id)
		var effects: Dictionary = core.db.item(id).effects
		_check(first.player.hp == 50 + int(effects.get("max_hp", 0)), "max hp item heals exactly once: " + id)
		var second := Rewards.resolve(core.db, first.player, {"item_id": id})
		_check(second.ok and second.max_hp_delta == first.max_hp_delta and second.attack_delta == first.attack_delta and second.defense_delta == first.defense_delta, "duplicate copies stack: " + id)
		_check(second.after.kill_heal == 2 * int(effects.get("kill_heal", 0)) and second.after.gold_bonus == 2 * int(effects.get("gold_bonus", 0)), "passives stack by copy: " + id)
	var snapshot: Dictionary = core.state.player.duplicate(true)
	for reward in [{"cost": {"gold": -1}}, {"effects": {"heal": 1.5}}, {"effects": {"unknown": 1}}, {"item_id": "bad", "effects": {"gold": 100}}]:
		_check(not Rewards.resolve(core.db, core.state.player, reward).ok and core.state.player == snapshot, "invalid transaction cannot partially grant")

func _test_potions() -> void:
	var core = _random_game("potions")
	var cell := _place_fixture(core, {"type": "potion", "amount": 45})
	core.interact(cell)
	_check(core.state.pending.is_empty() and not core.entity_at(cell).is_empty(), "full hp can pass without wasting potion")
	core.state.player.hp = 80
	core.interact(cell)
	_check(core.state.player.hp == 80 and not core.state.pending.is_empty(), "injured player confirms before consuming")
	core.cancel_pending()
	_check(not core.entity_at(cell).is_empty(), "cancel preserves potion")
	core.interact(cell)
	var result := Rewards.resolve(core.db, core.state.player, core.collection_reward(core.entity_at(cell)))
	_check(result.healing == 20 and result.overflow == 25, "preview reports actual heal and overflow")
	_check(core.confirm_interaction().is_empty() and core.state.player.hp == 100 and core.entity_at(cell).is_empty(), "potion heals to cap and disappears")
	_check(not core.confirm_interaction().is_empty(), "cannot consume twice")

func _test_choice_resume() -> void:
	var core = _random_game("choices")
	core.persistence_enabled = true
	var cell := _place_fixture(core, {"type": "choice", "choices": ["heart_pendant", "iron_sword"], "gold": 20})
	core.interact(cell)
	var loaded = Core.new(path)
	loaded.load_game()
	_check(SavedData.equal(core.state, loaded.state), "pending choice round trips through save")
	loaded.cancel_pending()
	loaded.interact(cell)
	var before: Dictionary = loaded.state.duplicate(true)
	_check(not loaded.choose_reward(2).is_empty() and loaded.state == before, "invalid choice has no side effects")
	var expected := Rewards.resolve(loaded.db, loaded.state.player, loaded.reward_options(loaded.entity_at(cell))[0])
	_check(loaded.choose_reward(0).is_empty() and loaded.state.player == expected.player, "choice commit equals preview")
	_check(loaded.state.player.gold == 20 and loaded.stats().max_hp == 125, "choice includes gold and hp once")
	loaded.load_game()
	_check(loaded.entity_at(cell).is_empty() and not loaded.choose_reward(1).is_empty(), "claimed choice cannot be rerolled or claimed after reload")
	cell = _place_fixture(loaded, {"type": "chest", "item_id": "missing", "gold": 100})
	before = loaded.state.duplicate(true)
	_check(not loaded.interact(cell).is_empty() and loaded.state == before, "unknown chest preserves both entity and player")

func _test_purchase_preview() -> void:
	var core = _random_game("shop-rewards")
	core.state.player.gold = 100
	core._grant_item("gold_sword")
	core._grant_item("merchant_seal")
	var cell := _place_fixture(core, {"type": "shop", "offers": ["buy_steel", "buy_potion", "buy_plate"], "purchased": false})
	core.interact(cell)
	var result: Dictionary = core.shop_preview("buy_steel")
	_check(result.ok and result.attack_delta == 4 and result.player.gold == 58, "gold relic spending is included in final attack")
	_check(not core.shop_preview("buy_potion").ok, "full hp healing purchase disabled")
	_check(core.buy(0).is_empty() and core.state.player == result.player, "purchase equals exact preview")
	core.interact(cell)
	var snapshot: Dictionary = core.state.player.duplicate(true)
	_check(not core.buy(2).is_empty() and core.state.player == snapshot, "merchant sells one total item")
	cell = _place_fixture(core, {"type": "shop", "offers": ["buy_sword"], "purchased": false})
	core.state.player.gold = 19
	core.interact(cell)
	_check(not core.buy(0).is_empty() and core.state.player.gold == 19, "insufficient balance cannot debit")
	core.state.player.gold = 20
	_check(core.buy(0).is_empty() and core.state.player.gold == 0, "exact price balance succeeds")

func _test_events_and_rest() -> void:
	var core = _random_game("events")
	var base: Dictionary = core.state.player.duplicate(true)
	for event_id in core.db.data.events:
		for index in 2:
			core.state.player = base.duplicate(true)
			core.state.player.gold = 100
			core.state.player.hp = 60
			var cell := _place_fixture(core, {"type": "event", "event_id": event_id})
			core.interact(cell)
			var option: Dictionary = core.reward_options(core.entity_at(cell))[index]
			var preview := Rewards.resolve(core.db, core.state.player, option)
			_check(core.choose_reward(index).is_empty() and core.state.player == preview.player, "event option resolves as preview: %s %d" % [event_id, index])
			_check(core.entity_at(cell).is_empty() and not core.choose_reward(1-index).is_empty(), "event only resolves once")
	core.state.player = base.duplicate(true)
	core.state.player.hp = 20
	var cell := _place_fixture(core, {"type": "event", "event_id": "altar"})
	core.interact(cell)
	_check(not core.choose_reward(0).is_empty() and core.state.player.hp == 20, "sacrifice must leave one hp")
	core.state.player.hp = 21
	_check(core.choose_reward(0).is_empty() and core.state.player.hp == 1, "sacrifice can leave exactly one hp")
	cell = _place_fixture(core, {"type": "rest", "options": core.generator.reward_config.rest_options.duplicate(true)})
	core.interact(cell)
	core.persistence_enabled = true
	_check(core.save_game(), "rest choice saves")
	core.load_game()
	_check(core.choose_reward(0).is_empty() and core.state.player.hp == 41, "rest resumes and heals exactly 40")
	_check(not core.choose_reward(1).is_empty(), "cannot also take rest reinforcement")

func _test_reward_generation() -> void:
	var generator = Generator.new()
	for seed_value in 30:
		for theme_id in ["battle", "treasure", "shop"]:
			var map: Dictionary = generator.generate(str(seed_value), 2, theme_id)
			_check(not map.is_empty(), "reward generation succeeds")
			var seen := {}
			for entity in map.entities.values():
				seen[entity.type] = true
				if entity.type == "choice":
					_check(entity.choices.size() == 2 and entity.choices[0] != entity.choices[1], "generated choice has distinct fixed options")
				if entity.type == "shop":
					_check(entity.offers[2] in ["buy_potion", "buy_pendant"], "shop replaces surplus key stock")
			_check(seen.has({"battle": "choice", "treasure": "event", "shop": "rest"}[theme_id]), "theme exposes new reward interaction")
	for version in [1, 2]:
		var map: Dictionary = generator.generate("42", 2, "treasure", version)
		for entity in map.entities.values():
			_check(entity.type not in ["event", "rest", "choice"], "legacy version retains original rewards")

func _test_catalog_snapshot() -> void:
	var core = _random_game("frozen-rewards")
	core.persistence_enabled = true
	core.state.reward_content.items.iron_sword.effects.attack = 9
	core.save_game()
	var loaded = Core.new(path)
	loaded.load_game()
	_check(loaded.db.item("iron_sword").effects.attack == 9, "loaded run uses its frozen reward catalog")
	loaded.start("fresh-rewards")
	_check(loaded.db.item("iron_sword").effects.attack == 3, "new run resets catalog to current definitions")
