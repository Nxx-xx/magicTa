extends SceneTree
## All routes use production movement, combat, reward and stair APIs, with zero upgrades.
const Core = preload("res://scripts/core/campaign_engine.gd")
const Generation = preload("res://scripts/core/campaign_generator.gd")
const Validation = preload("res://scripts/core/campaign_validator.gd")
var checks := 0
var failures := 0
var path := "user://campaign_map_test_%d.json" % OS.get_process_id()
var summaries: Array = []

class InvalidConfigCore:
	extends "res://scripts/core/campaign_engine.gd"
	var inject_error := ""
	func _new_campaign_generator():
		var next = preload("res://scripts/core/campaign_generator.gd").new()
		if inject_error == "shape":
			next.config.floor_budgets = []
		elif inject_error == "budget":
			next.config.floor_budgets[0] = [0,0]
		return next

func _initialize() -> void:
	_test_generation()
	for seed_value in range(100):
		for build in ["attack","defense","wealth"]:
			_route(str(seed_value), build, seed_value == 0 and build == "attack")
	_test_death_transaction()
	_test_theme_keys()
	_test_invalid_new_run_preserves_progress()
	_test_trial_removed()
	print("Campaign reference samples: " + JSON.stringify(summaries))
	print("Campaign tests: %d checks, %d failures" % [checks,failures])
	quit(1 if failures else 0)

func _check(value: bool, label: String) -> void:
	checks += 1
	if not value:
		failures += 1
		push_error("FAIL: " + label)

func _test_generation() -> void:
	var generator = Generation.new()
	var seen := {}
	for seed_value in range(100):
		var plan: Dictionary = generator.plan(str(seed_value))
		_check(plan == generator.plan(str(seed_value)), "stable global plan")
		for theme in ["battle","treasure","shop"]:
			var totals := {"equipment":0,"relic":0,"merchants":0,"rests":0,"events":0}
			for number in range(1,11):
				var map: Dictionary = generator.generate(plan, number, "boss" if number in [5,10] else theme, "dawn_spear")
				_check(not map.is_empty(), "seed %d floor %d generates: %s" % [seed_value,number,generator.last_error])
				if map.is_empty():
					continue
				_check(Validation.validate(map).is_empty(), "independent connectivity validator")
				seen[str(map.template_id)] = true
				var opportunities: Dictionary = generator.count_opportunities(map)
				for category in totals:
					totals[category] += int(opportunities[category])
			_check(totals.equipment <= 14 and totals.relic <= 17, "global opportunity budget includes all candidates")
			_check(totals.merchants == 2 and totals.rests == 2 and totals.events == 3, "guaranteed facility reservations")
	_check(seen.size() == 8, "six ordinary and two Boss geometries covered")

func _walk(core, target: Vector2i) -> bool:
	core.cancel_pending()
	var queue: Array[Vector2i] = [core.position()]
	var previous := {core.position():core.position()}
	while not queue.is_empty() and not previous.has(target):
		var current: Vector2i = queue.pop_front()
		for direction in [Vector2i.UP,Vector2i.DOWN,Vector2i.LEFT,Vector2i.RIGHT]:
			var next: Vector2i = current + direction
			if core.is_wall(next) or previous.has(next):
				continue
			var entity: Dictionary = core.entity_at(next)
			if next != target and entity.get("type", "") in ["enemy","door","up","down"]:
				continue
			previous[next] = current
			queue.append(next)
	if not previous.has(target):
		_check(false, "walk reaches %s floor %d" % [target,core.state.floor])
		return false
	var route: Array[Vector2i] = []
	var cursor := target
	while cursor != core.position():
		route.push_front(cursor)
		cursor = previous[cursor]
	for cell in route:
		var result: String = core.step(cell-core.position())
		if not result.is_empty():
			_check(false, "walk accepted: " + result)
			return false
		if cell != target and not core.state.pending.is_empty():
			core.cancel_pending()
	if route.is_empty():
		core.interact(target)
	return true

func _branch(core, branch_index: int, choice: int = 0) -> void:
	var branch: Array = core.floor_data().branch_paths[branch_index]
	var guard := Vector2i(branch[0][0],branch[0][1])
	if not _walk(core,guard):
		return
	var entity: Dictionary = core.entity_at(guard)
	if entity.get("type", "") in ["enemy","door"]:
		var result: String = core.confirm_interaction()
		_check(result.is_empty(), "reference battle/key viable: " + result)
		if not result.is_empty():
			return
	var end := Vector2i(branch[-1][0],branch[-1][1])
	if not _walk(core,end):
		return
	if core.entity_at(end).get("type", "") == "choice":
		_check(core.choose_reward(choice).is_empty(), "reference choice")
	elif core.entity_at(end).get("type", "") == "potion" and not core.state.pending.is_empty():
		core.confirm_interaction()

func _route(seed_text: String, build: String, persist: bool) -> void:
	var core = Core.new(path)
	core.persistence_enabled = persist
	_check(core.start_campaign(seed_text).is_empty(), "start campaign")
	if core.state.is_empty():
		return
	var minimum_hp := 100
	var checkpoints: Array = []
	for number in range(1,11):
		_check(int(core.state.floor) == number, "reference current floor")
		match number:
			1:
				_branch(core,0)
				_branch(core,1)
				if build == "wealth":
					_branch(core,3,1)
			2:
				_branch(core,0,1 if build == "defense" else 0)
				_walk(core,Vector2i(core.floor_data().safe_slots.event[0],core.floor_data().safe_slots.event[1]))
				_check(core.choose_reward(1 if build == "defense" else 0).is_empty(), "library route")
			3:
				_branch(core,0)
			4:
				_branch(core,0)
				_walk(core,Vector2i(core.floor_data().safe_slots.rest[0],core.floor_data().safe_slots.rest[1]))
				core.choose_reward(0)
			5,10:
				_walk(core,Vector2i(5,5))
				if persist:
					core = _reload(core,"Boss pending confirmation")
				_check(not core.preview(Vector2i(5,5)).lethal, "zero-upgrade Boss viable %s/%s/%d HP=%d stats=%s" % [seed_text,build,number,core.state.player.hp,core.stats()])
				var result: String = core.confirm_interaction()
				_check(result.is_empty(), "production Boss victory: " + result)
				if not result.is_empty():
					return
				if number == 5:
					if persist:
						core = _reload(core,"Boss defeated reward unclaimed")
					_check(not core.state.boss_rewards_claimed.has(5), "reward required before progress")
					_walk(core,Vector2i(5,2))
					_check(not core.interact(Vector2i(5,1)).is_empty(), "midpoint stairs blocked before reward")
					_walk(core,Vector2i(5,3))
					_check(core.choose_reward(1 if build == "defense" else 0).is_empty(), "midpoint equipment")
					if persist:
						core = _reload(core,"Boss reward claimed before stairs")
			6:
				_branch(core,0)
			7:
				_branch(core,0)
				if build != "attack":
					_branch(core,1,1 if build == "wealth" else 0)
				if seed_text == "0":
					_backtrack_for_ring(core)
			9:
				_walk(core,Vector2i(core.floor_data().safe_slots.rest[0],core.floor_data().safe_slots.rest[1]))
				core.choose_reward(0)
		minimum_hp = mini(minimum_hp,int(core.state.player.hp))
		checkpoints.append({"floor":number,"hp":core.state.player.hp,"attack":core.stats().attack,"defense":core.stats().defense,"gold":core.state.player.gold})
		if number < 10:
			_walk(core,Vector2i(5,1))
			var result: String
			if core.state.pending.get("kind", "") == "floor_choice":
				# Mixed themes are deliberate; all theme geometry also has separate coverage.
				result = core.choose_floor(["battle","treasure","shop"][(number+seed_text.to_int())%3])
			else:
				result = core.confirm_interaction()
			_check(result.is_empty(), "advance: " + result)
			if persist:
				var resumed = Core.new(path)
				resumed.load_game()
				_check(resumed.state == JSON.parse_string(JSON.stringify(core.state)), "save reload exact floor %d: %s" % [number,resumed.save_error])
				if not resumed.state.is_empty():
					core = resumed
	_check(core.state.get("result", "") == "victory", "ten floors rescue completed")
	_check(int(core.meta.wins) == 1, "victory credited once")
	_check(int(core.state.meta_snapshot.upgrades.hp)+int(core.state.meta_snapshot.upgrades.attack)+int(core.state.meta_snapshot.upgrades.gold) == 0, "zero upgrade proof")
	if seed_text == "0":
		summaries.append({"build":build,"minimum_hp":core.state.metrics.minimum_hp,"damage_taken":core.state.metrics.damage_taken,"final_hp":core.state.player.hp,"gold":core.state.player.gold,"checkpoints":checkpoints})
	if persist:
		var resumed = Core.new(path)
		resumed.load_game()
		_check(resumed.state.get("result", "") == "victory" and int(resumed.meta.wins) == 1, "victory reload retains one settlement")
		_check(not resumed.active() and not resumed.step(Vector2i.UP).is_empty(), "completed map is read-only")

func _reload(core, label: String):
	var resumed = Core.new(path)
	resumed.load_game()
	_check(resumed.state == JSON.parse_string(JSON.stringify(core.state)), label + ": " + resumed.save_error)
	return resumed if not resumed.state.is_empty() else core

func _test_theme_keys() -> void:
	var core = Core.new(path)
	core.persistence_enabled = false
	core.start_campaign("keys")
	_walk(core,Vector2i(5,1))
	# Force treasure only for this key-budget fixture; production stairs choose automatically.
	core._accept_generated_floor(2, core.campaign_generator.generate(core.state.campaign_plan, 2, "treasure"))
	_check(core.confirm_interaction().is_empty(), "treasure fixture entered through stairs")
	var key_pos: Array = core.floor_data().safe_slots.key
	_walk(core,Vector2i(key_pos[0],key_pos[1]))
	_check(int(core.state.player.gold_keys) == 1, "second floor reserved gold key collected")
	_branch(core,2,0)
	_check(int(core.state.player.gold_keys) == 0 and "gold_sword" in core.state.player.relic_ids, "matching key spent for one-time treasure")
	_check(core.choose_floor("battle") != "", "theme cannot be rerolled")

func _backtrack_for_ring(core) -> void:
	var rng_before: String = core.state.rng_state
	var seen_before: Array = core.state.story.seen.duplicate()
	var layouts := {}
	for id in core.state.floors:
		layouts[id] = core.state.floors[id].rows.duplicate()
	for number in range(7,1,-1):
		_walk(core,Vector2i(5,9))
		_check(core.confirm_interaction().is_empty(), "downstairs backtrack")
	_branch(core,2)
	_check(core.state.side_objective_complete and not core.state.objective_complete and not core.state.completed, "ring is a side objective only")
	for number in range(1,7):
		_walk(core,Vector2i(5,1))
		_check(core.confirm_interaction().is_empty(), "upstairs revisit without regeneration")
	for id in layouts:
		_check(core.state.floors[id].rows == layouts[id], "backtracking preserves geometry")
	_check(core.state.rng_state == rng_before, "travel and story do not consume map RNG")
	_check(core.state.story.seen.size() == seen_before.size()+1, "only new ring story on revisit")

func _test_death_transaction() -> void:
	var core = Core.new(path)
	core.persistence_enabled = false
	core.start_campaign("death")
	# Starting player genuinely loses to the optional knight; no stat mutation.
	var branch: Array = core.floor_data().branch_paths[2]
	_walk(core,Vector2i(branch[0][0],branch[0][1]))
	_check(core.confirm_interaction() == "confirm_lethal", "lethal asks explicit confirmation")
	var before: Dictionary = core.state.duplicate(true)
	var valid_store = core.store
	core.store = Core.CampaignSave.new("user://missing_campaign_directory/save.json")
	core.persistence_enabled = true
	_check(not core.confirm_interaction(true).is_empty(), "failed disk commit reported")
	_check(core.transaction_pending and core.state == before, "failed settlement rolls memory back")
	_check(int(core.meta.failure_count) == 0, "no premature failure count")
	_check(not core.start_campaign("overwrite").is_empty(), "pending transaction blocks fresh run")
	core.cancel_pending()
	_check(core.state == before, "pending transaction blocks cancel")
	core.buy(0)
	core.choose_reward(0)
	core.choose_floor("battle")
	core.step(Vector2i.UP)
	core.load_game()
	core.acknowledge_story()
	_check(core.state == before, "pending transaction blocks all gameplay and reload")
	core.store = valid_store
	_check(core.retry_save(), "retry commits candidate")
	_check(int(core.meta.failure_count) == 1 and core.state.result == "death", "death settles exactly once")
	core.retry_save()
	_check(int(core.meta.failure_count) == 1, "repeated retry idempotent")
	var resumed = Core.new(path)
	resumed.load_game()
	_check(int(resumed.meta.failure_count) == 1, "death reload preserves count")
	_check(resumed.story_event().get("audio_cue", "") == "", "reload cannot replay cry")
	var old_id: String = core.state.run_id
	core.persistence_enabled = false
	core.start_campaign("death")
	_check(core.state.run_id != old_id, "same seed gets unique settlement id")
	core.abandon_run()
	_check(int(core.meta.failure_count) == 1, "abandon is not death")

func _test_trial_removed() -> void:
	var core = Core.new(path)
	core.persistence_enabled = false
	_check(not core.start("42").is_empty(), "retired trial API rejects creation")
	_check(core.state.is_empty() and not core.transaction_pending, "rejected trial leaves no run or pending transaction")
	_check(core.meta.souls == 0, "rejected trial preserves account")

func _test_invalid_new_run_preserves_progress() -> void:
	var core = InvalidConfigCore.new(path)
	_check(core.start_campaign("configuration_baseline").is_empty(), "configuration failure baseline")
	core.abandon_run()
	var before: Dictionary = core.state.duplicate(true)
	var before_meta: Dictionary = core.meta.duplicate(true)
	var before_catalog: Dictionary = core.db.data.duplicate(true)
	var before_rng: String = str(core.rng.state)
	var before_save := FileAccess.get_file_as_string(path)
	for failure in ["shape","budget"]:
		core.inject_error = failure
		_check(not core.start_campaign("invalid_configuration").is_empty(), "new run rejects " + failure)
		_check(core.state == before and core.meta == before_meta and not core.transaction_pending, "failed generation keeps prior run/account playable")
		_check(core.db.data == before_catalog and str(core.rng.state) == before_rng, "failed generation keeps old combat rules and RNG")
		_check(FileAccess.get_file_as_string(path) == before_save, "failed generation never overwrites save")
