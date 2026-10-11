extends "res://scripts/core/campaign_engine.gd"
## Historical map fixtures only; production rejects this retired mode.

func start(seed_text: String = "", random_maps: bool = true) -> String:
	if not errors.is_empty():
		return "\n".join(errors)
	var seed_value: int
	if seed_text.strip_edges().is_empty():
		var seed_rng := RandomNumberGenerator.new()
		seed_rng.randomize()
		seed_value = int(seed_rng.randi())
	else:
		seed_value = seed_text.to_int() if seed_text.is_valid_int() else seed_text.hash()
	var first: Dictionary
	if random_maps:
		first = generator.generate(str(seed_value), 1, "entrance")
		if first.is_empty():
			return generator.last_error
		rng.seed = seed_value
	else:
		# Kept for existing hand-built saves and their regression test fixtures.
		rng.seed = seed_value
		first = _legacy_generate_floor(1, "entrance")
	# Only change the loaded catalog after generation succeeds.
	db = DB.new()
	state = {
		"mode": "grid_prototype_v1", "seed": str(seed_value), "rng_state": str(rng.state),
		"generator_version": Generator.VERSION if random_maps else 0,
		"reward_rules_version": 1, "reward_content": {
			"items": db.data.items.duplicate(true), "shop": db.data.shop.duplicate(true),
			"events": db.data.events.duplicate(true)},
		"floor": 1, "position": first.entry.duplicate(), "floors": {}, "pending": {},
		"player": {"hp": 100, "max_hp": 100, "attack": 10, "defense": 5,
			"gold": 0, "keys": 0, "silver_keys": 0, "gold_keys": 0,
			"equipment_ids": [], "relic_ids": []},
		"completed": false, "objective_complete": false, "summit_seen": false,
		"last_report": {}, "last_message": "先绕过支路强敌，上二层寻找装备，再回来挑战。"
	}
	state.floors["1"] = first
	save_game()
	return ""

