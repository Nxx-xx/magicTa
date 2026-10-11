extends SceneTree
## Production route adapted from campaign_test_runner / campaign_journey_capture.
## Never assigns player/state to manufacture progression. Only persistence fault injection.
const OUT := "res://build/verification/phase3/03-combat/integration/"
var evidence_out := OUT
const P3Combat = preload("res://scripts/core/phase3_combat.gd")
const P3Items = preload("res://scripts/core/phase3_items.gd")
var Core: GDScript
var core
var checks := 0
var failures: Array = []
var routes: Array = []
var context := {}
var trace: Array = []
var run_folder := ""
var current_path := ""
var batch := false
var suite_started := 0
var expected_min_hp := 100
var expected_kill_healing := 0
var expected_incoming := 0
var battle_count := 0
var midboss_proofs := 0
var checked_ruins := 0
var reload_count := 0

class FailStore:
	extends RefCounted
	var last_error := "phase3 integration injected storage interruption"
	func write(_run: Dictionary, _meta: Dictionary) -> bool:
		return false

func _initialize() -> void:
	if not ProjectSettings.globalize_path("user://").replace("\\", "/").contains("phase3/03-combat/integration/"):
		push_error("Refusing non-isolated APPDATA: require phase3/03-combat/integration/")
		quit(2)
		return
	suite_started = Time.get_ticks_msec()
	DirAccess.make_dir_recursive_absolute(evidence_out)
	batch = "--batch" in OS.get_cmdline_user_args()
	run_folder = "user://p3_integration_%d_%d" % [OS.get_process_id(), Time.get_ticks_usec()]
	DirAccess.make_dir_recursive_absolute(run_folder)
	Core = load("res://scripts/core/campaign_engine.gd")
	if Core == null or not Core.can_instantiate():
		_check(false, "campaign engine cannot compile/instantiate during integration")
		_finish()
		return
	core = Core.new(run_folder + "/probe.json")
	for method in ["start_phase3", "is_phase3", "choose_ruin", "ruin_previews"]:
		_check(core.has_method(method), "required production API: " + method)
	if not failures.is_empty():
		_finish()
		return
	_suite.call_deferred()

func _suite() -> void:
	var seeds := range(100) if batch else [42]
	var builds := ["attack", "defense", "wealth"] if batch or "--three" in OS.get_cmdline_user_args() else ["attack"]
	for seed_value in seeds:
		for build in builds:
			_route(str(seed_value), build, not batch)
			_write_results()
			await process_frame
	# Transactions are independent fresh real runs; do not need a route to have won.
	_death_transaction()
	_ruin_transaction()
	_start_transaction()
	_legacy_dispatch()
	_finish()

func _check(ok: bool, label: String, details: Dictionary = {}) -> bool:
	checks += 1
	if not ok:
		var item := {"label": label, "context": context.duplicate(true), "details": details.duplicate(true)}
		if core != null and not core.state.is_empty():
			item.floor = int(core.state.floor)
			item.player = core.state.player.duplicate(true)
			item.save_error = core.save_error
		failures.append(item)
		push_error("P3 INTEGRATION: " + label + " " + JSON.stringify(item.context) + " " + JSON.stringify(details))
	return ok

func _new_case(name: String, persist: bool = true) -> void:
	context = {"case": name}
	current_path = run_folder + "/" + name + ".json"
	core = Core.new(current_path)
	core.persistence_enabled = persist
	trace = []

func _start_phase3(seed_text: String = "42", replay: Dictionary = {}) -> bool:
	var result: String = core.call("start_phase3", seed_text, "p3_c0", "default", replay)
	if not _check(result.is_empty() and not core.state.is_empty() and not core.transaction_pending, "start_phase3 accepted", {"error": result}):
		return false
	_check(core.call("is_phase3"), "new route identifies phase3")
	for field in ["generator_version", "reward_rules_version", "combat_rules_version"]:
		_check(int(core.state.get(field, -1)) == 2, "new run version " + field)
	_check(core.state.meta_snapshot.upgrades == {"hp": 0, "attack": 0, "gold": 0}, "zero-fire progression proof")
	_check(int(core.state.player.hp) == 100 and int(core.state.player.attack) == 10 and int(core.state.player.defense) == 5 and int(core.state.player.gold) == 0, "default zero-fire actual starting stats")
	_check(int(core.db.enemy("golem").attack) == 28, "floor-ten snapshot preserves attack28")
	return true

func _walk(target: Vector2i) -> bool:
	core.cancel_pending()
	if core.transaction_pending:
		return _check(false, "cancel pending unexpectedly blocked by save failure")
	var start: Vector2i = core.position()
	var queue: Array[Vector2i] = [start]
	var previous := {start: start}
	while not queue.is_empty() and not previous.has(target):
		var current: Vector2i = queue.pop_front()
		for direction in [Vector2i.UP, Vector2i.DOWN, Vector2i.LEFT, Vector2i.RIGHT]:
			var next: Vector2i = current + direction
			if core.is_wall(next) or previous.has(next):
				continue
			var entity: Dictionary = core.entity_at(next)
			if next != target and entity.get("type", "") in ["enemy", "door", "up", "down"]:
				continue
			previous[next] = current
			queue.append(next)
	if not _check(previous.has(target), "safe BFS route exists", {"target": [target.x, target.y]}):
		return false
	var path: Array[Vector2i] = []
	var cursor := target
	while cursor != start:
		path.push_front(cursor)
		cursor = previous[cursor]
	for cell in path:
		var result: String = core.step(cell - core.position())
		if not _check(result.is_empty() and not core.transaction_pending, "production movement accepted", {"error": result, "cell": [cell.x, cell.y]}):
			return false
		if cell != target and not core.state.pending.is_empty():
			core.cancel_pending()
	if path.is_empty():
		var result: String = core.interact(target)
		if not _check(result.is_empty(), "production re-interaction accepted", {"error": result}):
			return false
	return true

func _point(raw: Array) -> Vector2i:
	return Vector2i(int(raw[0]), int(raw[1]))

func _entity_cell(kind: String, flag: String = "") -> Vector2i:
	for entity in core.floor_data().entities.values():
		if entity.get("type", "") == kind and (flag.is_empty() or entity.get(flag, false)):
			return _point(entity.pos)
	return Vector2i(-1, -1)

func _fight(cell: Vector2i, permit_lethal: bool = false) -> bool:
	if not _walk(cell): return false
	var entity: Dictionary = core.entity_at(cell).duplicate(true)
	var before_player: Dictionary = core.state.player.duplicate(true)
	var before_state: Dictionary = core.state.duplicate(true)
	var expected: Dictionary = P3Combat.simulate(before_player, core.db.enemy(entity.enemy_id), core.stats())
	var report: Dictionary = core.preview(cell)
	if not _check(report.get("ok", false) and report == expected, "production preview dispatches to frozen v2 simulation", {"enemy_id": entity.enemy_id, "report": report, "expected": expected}):
		return false
	_check(core.state == before_state and report == core.preview(cell), "preview pure and repeatable")
	if not permit_lethal and not _check(not report.lethal, "reference battle viable", {"enemy_id": entity.enemy_id, "report": report, "stats": core.stats()}):
		return false
	var result: String = core.confirm_interaction(permit_lethal)
	if not _check(result.is_empty() and not core.transaction_pending, "production battle commits", {"error": result, "enemy_id": entity.enemy_id}):
		return false
	_check(core.state.last_report == report, "preview equals committed complete report")
	_check(int(core.state.player.gold) == int(before_player.gold) + int(report.gold_reward), "battle gold committed once")
	var expected_hp := int(report.hp_after)
	if entity.get("campaign_boss", false) and int(before_state.floor) == 5 and report.won:
		expected_hp = mini(int(core.stats().max_hp), expected_hp + 65)
	_check(int(core.state.player.hp) == expected_hp, "HP commit matches preview plus explicit midboss heal")
	expected_min_hp = mini(expected_min_hp, int(report.min_hp))
	expected_incoming += int(report.incoming)
	expected_kill_healing += int(report.healing)
	battle_count += 1
	if report.won:
		var kill: Dictionary = core.state.defeated_entities[-1]
		_check(kill.id == entity.id and kill.get("turns") == report.turns and kill.get("incoming") == report.incoming, "kill records actual turns/incoming evidence")
	trace.append({"kind": "fight", "floor": before_state.floor, "entity_id": entity.id, "enemy_id": entity.enemy_id, "player_before": before_player, "report": report})
	return true

func _branch(index: int, choice: int = 0) -> bool:
	var branch: Array = core.floor_data().branch_paths[index]
	var gate := _point(branch[0])
	var entity: Dictionary = core.entity_at(gate)
	if entity.get("type", "") == "enemy":
		if not _fight(gate): return false
	elif entity.get("type", "") == "door":
		if not _walk(gate): return false
		var result: String = core.confirm_interaction()
		if not _check(result.is_empty() and not core.transaction_pending, "reference door opens", {"error": result}): return false
	var end := _point(branch[-1])
	if not _walk(end): return false
	var reward: Dictionary = core.entity_at(end).duplicate(true)
	if reward.get("type", "") == "choice":
		var result: String = core.choose_reward(choice)
		if not _check(result.is_empty() and not core.transaction_pending, "reference reward selected", {"error": result}): return false
	elif reward.get("type", "") == "potion" and not core.state.pending.is_empty():
		if not _check(core.confirm_interaction().is_empty() and not core.transaction_pending, "reference potion consumed"): return false
	trace.append({"kind": "branch", "floor": core.state.floor, "index": index, "choice": choice, "reward": reward})
	return true

func _rest() -> bool:
	var cell := _entity_cell("rest")
	if not _check(cell.x >= 0, "reserved rest exists"): return false
	if not _walk(cell): return false
	var result: String = core.choose_reward(0)
	return _check(result.is_empty() and not core.transaction_pending, "production rest", {"error": result})

func _ruin(option_id: String, exercise_revisit: bool = true) -> bool:
	var cell := _entity_cell("event")
	if not _check(cell.x >= 0, "reserved ruin event exists"): return false
	if not _walk(cell): return false
	var entity: Dictionary = core.entity_at(cell).duplicate(true)
	if not _check(str(entity.get("ruin_id", "")).begins_with("p3_"), "event replaced by stable ruin", {"entity": entity}): return false
	if exercise_revisit:
		var before: Dictionary = core.state.player.duplicate(true)
		var leave_result: String = core.call("choose_ruin", "leave")
		if not _check(leave_result.is_empty() and not core.transaction_pending, "ruin leave is free", {"error": leave_result}): return false
		_check(core.state.player == before and core.entity_at(cell).get("status") == "available", "leave preserves player and unconsumed ruin")
		if not _walk(cell): return false
	var previews: Dictionary = core.call("ruin_previews", core.entity_at(cell))
	var option: Dictionary = previews.get("options", {}).get(option_id, {})
	if not _check(previews.get("ok", false) and option.get("ok", false), "ruin preview affordable", {"option": option_id, "previews": previews}): return false
	var result: String = core.call("choose_ruin", option_id)
	if not _check(result.is_empty() and not core.transaction_pending, "ruin commits", {"error": result, "option": option_id}): return false
	_check(core.state.player == option.player, "ruin actual player equals preview")
	var consumed: Dictionary = core.entity_at(cell).duplicate(true)
	_check(consumed.get("type") == "event" and consumed.get("status") == "resolved" and consumed.get("selected_option") == option_id and not str(consumed.get("transaction_id", "")).is_empty(), "spent ruin retains entity and transaction identity")
	_check(core.state.metrics.get("ruin_choices", {}).get(entity.id) == option_id, "ruin metric stores selected option")
	checked_ruins += 1
	trace.append({"kind": "ruin", "floor": core.state.floor, "option": option_id, "entity": consumed, "preview": option})
	if exercise_revisit:
		if not _checkpoint("spent_ruin"): return false
		if not _walk(cell): return false
		var before: Dictionary = core.state.player.duplicate(true)
		var before_meta: Dictionary = core.meta.duplicate(true)
		result = core.call("choose_ruin", option_id)
		_check(not result.is_empty() and core.state.player == before and core.meta == before_meta and core.entity_at(cell) == consumed, "spent ruin revisit cannot farm reward or codex counts")
		core.cancel_pending()
	return true

func _checkpoint(label: String) -> bool:
	var persist: bool = core.persistence_enabled
	core.persistence_enabled = true
	if not _check(core.save_game(), "checkpoint save: " + label, {"error": core.save_error}): return false
	var before: Dictionary = _json_copy(core.state)
	var meta: Dictionary = _json_copy(core.meta)
	var db: Dictionary = _json_copy(core.db.data)
	var reloaded = Core.new(current_path)
	reloaded.load_game()
	if not _check(not reloaded.state.is_empty() and reloaded.save_error.is_empty(), "checkpoint reload: " + label, {"error": reloaded.save_error}): return false
	var actual: Dictionary = _json_copy(reloaded.state)
	# Finished story audio intentionally becomes a static summary on load.
	if not str(before.get("result", "")).is_empty():
		before.erase("story")
		actual.erase("story")
	_check(actual == before and _json_copy(reloaded.meta) == meta, "save/reload exact gameplay and account: " + label)
	_check(_json_copy(reloaded.db.data) == db, "save/reload frozen content: " + label)
	_check(reloaded.call("is_phase3"), "reload retains phase3 dispatch")
	core = reloaded
	core.persistence_enabled = persist
	reload_count += 1
	return true

func _travel_up(seed_text: String, number: int) -> bool:
	var stairs := _entity_cell("up")
	if not _check(stairs.x >= 0, "upstairs discovered in actual geometry"): return false
	if not _walk(stairs): return false
	var result: String
	if core.state.pending.get("kind", "") == "floor_choice":
		result = core.choose_floor(["battle", "treasure", "shop"][(number + seed_text.to_int()) % 3])
	else:
		result = core.confirm_interaction()
	if not _check(result.is_empty() and not core.transaction_pending and int(core.state.floor) == number + 1, "production ascent", {"error": result}): return false
	return _checkpoint("floor_%d" % (number + 1))

func _backtrack_ruin() -> bool:
	# Enter floor3, walk down to actual floor2 entrance and inspect persisted ruin.
	var rng_before: String = core.state.rng_state
	var floors_before: Dictionary = _json_copy(core.state.floors)
	if not _walk(_entity_cell("down")): return false
	if not _check(core.confirm_interaction().is_empty() and int(core.state.floor) == 2, "backtrack into spent-ruin floor"): return false
	var cell := _entity_cell("event")
	if not _walk(cell): return false
	var before: Dictionary = core.state.player.duplicate(true)
	var entity: Dictionary = core.entity_at(cell).duplicate(true)
	_check(entity.get("status") == "resolved", "ruin consumed state survives cross-floor revisit")
	_check(not str(core.call("choose_ruin", str(entity.get("selected_option", "")))).is_empty() and core.state.player == before, "cross-floor revisit cannot repeat ruin transaction")
	if not _walk(_entity_cell("up")): return false
	if not _check(core.confirm_interaction().is_empty() and int(core.state.floor) == 3, "return upstairs without reroll"): return false
	_check(_json_copy(core.state.floors) == floors_before and core.state.rng_state == rng_before, "cross-floor travel preserves generated floor data and RNG")
	return _checkpoint("ruin_cross_floor_revisit")

func _route(seed_text: String, build: String, persist_steps: bool) -> void:
	_new_case("route_%s_%s" % [seed_text, build], persist_steps)
	context.seed = seed_text
	context.build = build
	var failures_before := failures.size()
	expected_min_hp = 100
	expected_kill_healing = 0
	expected_incoming = 0
	var checkpoints: Array = []
	var route_started := Time.get_ticks_msec()
	var started := _start_phase3(seed_text)
	var account_wins_before := int(core.meta.get("wins",0))
	var account_runs_before := int(core.meta.get("runs",0))
	var replay: Dictionary = core.state.duplicate(true) if started else {}
	var passed_midpoint := false
	var route_ok := started
	if started:
		for number in range(1, 11):
			if not _check(int(core.state.floor) == number, "route floor matches plan"): route_ok = false; break
			match number:
				1:
					route_ok = _branch(0) and _branch(1)
					if route_ok and build == "wealth": route_ok = _branch(3, 1)
				2:
					route_ok = _branch(0, 1 if build == "defense" else 0)
					if route_ok: route_ok = _ruin("guard" if build == "defense" else ("salvage" if build == "wealth" else "edge"))
				3:
					route_ok = _backtrack_ruin() if seed_text == "42" else true
					if route_ok: route_ok = _branch(0)
				4:
					route_ok = _branch(0) and _rest()
				5, 10:
					var boss := _entity_cell("enemy", "campaign_boss")
					route_ok = _check(boss.x >= 0, "boss exists") and _walk(boss) and _checkpoint("boss_pending_%d" % number)
					if route_ok: route_ok = _fight(boss)
					if route_ok and number == 5:
						passed_midpoint = true
						midboss_proofs += 1
						route_ok = _checkpoint("boss5_defeated_unclaimed")
						if route_ok:
							_check(core.state.boss_rewards_claimed.is_empty(), "boss reward still unclaimed")
							var reward_cell := _entity_cell("choice", "campaign_boss_reward")
							route_ok = _walk(reward_cell)
							if route_ok:
								var result: String = core.choose_reward(1 if build == "defense" else 0)
								route_ok = _check(result.is_empty() and not core.transaction_pending, "midboss growth reward commits", {"error": result})
				6:
					route_ok = _branch(0)
					if route_ok: route_ok = _ruin("salvage" if build == "wealth" else "temper")
				7:
					route_ok = _branch(0)
					if route_ok and build != "attack": route_ok = _branch(1, 1 if build == "wealth" else 0)
				9:
					route_ok = _ruin("ward") and _rest()
			if not route_ok: break
			checkpoints.append({"floor": number, "player": core.state.player.duplicate(true), "stats": core.stats(), "metrics": core.state.metrics.duplicate(true)})
			if number < 10:
				route_ok = _travel_up(seed_text, number)
				if not route_ok: break
	var won: bool = route_ok and core.state.get("result", "") == "victory"
	# Snapshot outcome before the optional retry test starts another run.
	var route_end := {"floor":core.state.get("floor",0), "player":core.state.get("player",{}).duplicate(true),
		"upgrades":core.state.get("meta_snapshot",{}).get("upgrades",{}).duplicate(true)}
	if route_ok:
		_check(won and int(core.meta.wins) == account_wins_before + 1 and int(core.meta.runs) == account_runs_before + 1, "ten-floor production victory credited once")
		_check(int(core.state.metrics.get("min_hp_in_combat", -1)) == expected_min_hp, "minimum combat HP uses pre-heal minima")
		_check(int(core.state.metrics.get("actual_kill_healing", -1)) == expected_kill_healing, "actual kill healing excludes fixed boss/rest heals")
		_check(int(core.state.metrics.damage_taken) == expected_incoming, "damage metric equals complete combat reports")
		_checkpoint("victory")
		var account: Dictionary = core.meta.duplicate(true)
		core.retry_save()
		core.confirm_interaction()
		core.abandon_run()
		_check(not core.active() and core.meta == account, "victory retry/input cannot settle twice")
		if seed_text == "42" and build == "attack":
			_test_replay(replay)
	var summary := {"seed": seed_text, "build": build, "context": context.duplicate(true), "write_every_action": persist_steps,
		"checkpoints_saved_and_reloaded": true, "passed_midboss": passed_midpoint, "won": won,
		"checks_failed": failures.size() - failures_before, "elapsed_ms": Time.get_ticks_msec() - route_started,
		"checkpoints": checkpoints, "last_floor": route_end.floor, "last_player": route_end.player,
		"meta_upgrades": route_end.upgrades, "trace_file": str(context.case) + ".json"}
	routes.append(summary)
	FileAccess.open(evidence_out + summary.trace_file, FileAccess.WRITE).store_string(JSON.stringify({"summary": summary, "actions": trace, "failures": failures.slice(failures_before)}, "\t"))
	print("P3 ROUTE seed=%s build=%s midboss=%s victory=%s failures=%d" % [seed_text, build, passed_midpoint, won, summary.checks_failed])

func _test_replay(snapshot: Dictionary) -> void:
	var old_id: String = core.state.run_id
	var result: String = core.call("start_phase3", "42", "p3_c0", "default", snapshot)
	if not _check(result.is_empty(), "same-seed frozen snapshot replay accepted", {"error": result}): return
	_check(core.state.run_id != old_id, "replay gets a fresh settlement identity")
	for field in ["reward_content", "campaign_plan", "campaign_rules_snapshot", "progress_rules_snapshot", "ruin_definitions_snapshot", "variant_plan", "unlocked_pool_snapshot"]:
		_check(core.state.get(field) == snapshot.get(field), "replay freezes " + field)
	_check(core.state.player == snapshot.player and core.state.floors["1"] == snapshot.floors["1"], "replay restores zero-fire opening and layout despite newly unlocked account")

func _death_transaction() -> void:
	_new_case("death_transaction")
	if not _start_phase3(): return
	var cell := _point(core.floor_data().branch_paths[2][0])
	if not _walk(cell): return
	var report: Dictionary = core.preview(cell)
	_check(report.lethal, "untouched player genuinely loses to first-floor knight")
	_check(core.confirm_interaction() == "confirm_lethal", "lethal combat requests confirmation")
	var before: Dictionary = core.state.duplicate(true)
	var before_meta: Dictionary = core.meta.duplicate(true)
	var store = core.store
	core.store = FailStore.new()
	var result: String = core.confirm_interaction(true)
	if not _check(not result.is_empty() and core.transaction_pending, "failed death save reported and blocked", {"error": result}): return
	_check(core.state == before and core.meta == before_meta, "failed death rolls back player and account")
	_blocked_operations(before, before_meta)
	core.store = store
	if not _check(core.retry_save(), "death save retry commits candidate"): return
	_check(core.state.result == "death" and int(core.meta.failure_count) == 1 and int(core.meta.runs) == 1, "death counted exactly once")
	_check(core.state.last_report == report and core.state.player.hp == 0, "death retry preserves preview and HP")
	var account: Dictionary = core.meta.duplicate(true)
	core.retry_save()
	_check(core.meta == account, "second save retry idempotent")
	if not _checkpoint("death"): return
	_check(int(core.meta.failure_count) == 1 and core.meta.get("phase3_settled_runs", {}).get(core.state.run_id) == "death", "death reload retains permanent phase3 ledger")
	var old_run_id: String = core.state.run_id
	var replay: Dictionary = core.state.duplicate(true)
	result = core.call("start_phase3", "42", "p3_c0", "default", replay)
	_check(result.is_empty() and core.state.run_id != old_run_id, "death replay fresh run id")
	core.abandon_run()
	_check(int(core.meta.failure_count) == 1, "abandon is not another death")

func _blocked_operations(before: Dictionary, meta: Dictionary) -> void:
	_check(not str(core.call("start_phase3", "overwrite", "p3_c0", "default")).is_empty(), "pending write blocks new game")
	core.cancel_pending()
	core.buy(0)
	core.choose_reward(0)
	core.call("choose_ruin", "salvage")
	core.choose_floor("battle")
	core.step(Vector2i.UP)
	core.load_game()
	core.acknowledge_story()
	_check(core.state == before and core.meta == meta, "pending write blocks all gameplay/reload/story changes")

func _ruin_transaction() -> void:
	_new_case("ruin_transaction")
	if not _start_phase3(): return
	if not _travel_up("42", 1): return
	var cell := _entity_cell("event")
	if not _walk(cell): return
	var before: Dictionary = core.state.duplicate(true)
	var before_meta: Dictionary = core.meta.duplicate(true)
	var previews: Dictionary = core.call("ruin_previews", core.entity_at(cell))
	if not _check(previews.get("ok", false) and previews.get("options", {}).get("salvage", {}).get("ok", false), "salvage fault fixture is affordable"): return
	var expected: Dictionary = previews.options.salvage.player
	var store = core.store
	core.store = FailStore.new()
	var result: String = core.call("choose_ruin", "salvage")
	if not _check(not result.is_empty() and core.transaction_pending, "ruin failed commit reported", {"error": result}): return
	_check(core.state == before and core.meta == before_meta, "ruin failed save rolls back costs, rewards, consumption and discovery")
	_blocked_operations(before, before_meta)
	core.store = store
	if not _check(core.retry_save(), "ruin retry commits one candidate"): return
	_check(core.state.player == expected and core.entity_at(cell).get("status") == "resolved", "ruin retry atomically commits expected player and entity")
	var after: Dictionary = core.state.duplicate(true)
	var account: Dictionary = core.meta.duplicate(true)
	core.retry_save()
	_check(core.state == after and core.meta == account, "ruin retry cannot duplicate metrics or codex")
	_checkpoint("ruin_transaction")

func _start_transaction() -> void:
	_new_case("start_transaction")
	var store = core.store
	core.store = FailStore.new()
	var before_meta: Dictionary = core.meta.duplicate(true)
	var result: String = core.call("start_phase3", "42", "p3_c0", "default")
	_check(not result.is_empty() and core.transaction_pending and core.state.is_empty() and core.meta == before_meta, "new-run save failure exposes no partial phase3 state")
	core.store = store
	if not _check(core.retry_save() and core.call("is_phase3") and core.active(), "new-run retry installs complete phase3 candidate"): return
	_checkpoint("new_run_retry")

func _legacy_dispatch() -> void:
	_new_case("legacy_dispatch")
	_check(core.start_campaign("42").is_empty(), "old campaign API still starts")
	_check(not core.call("is_phase3") and int(core.state.generator_version) == 1 and int(core.state.reward_rules_version) == 1, "old campaign keeps legacy versions")
	var cell := _point(core.floor_data().branch_paths[0][0])
	var legacy := preload("res://scripts/core/combat.gd").simulate(core.state.player, core.db.enemy("slime"), core.stats())
	_check(core.preview(cell) == legacy and not core.preview(cell).has("combat_rules_version"), "legacy campaign preview remains old report")
	core.abandon_run()
	var ended: Dictionary = core.state.duplicate(true)
	_check(not core.start("42").is_empty() and core.is_campaign(), "retired trial entry rejected")
	_check(core.state == ended, "rejected trial leaves ended campaign unchanged")
	var resumed = Core.new(current_path)
	resumed.load_game()
	_check(resumed.is_campaign() and not resumed.active(), "rejected trial leaves saved campaign intact")

func _json_copy(value: Dictionary) -> Dictionary:
	return JSON.parse_string(JSON.stringify(value))

func _write_results() -> void:
	var stats := {"mode": "batch_100x3" if batch else "quick", "checks": checks, "failures": failures,
		"routes": routes, "route_count": routes.size(), "midboss_passes": midboss_proofs,
		"wins": routes.filter(func(r: Dictionary) -> bool: return r.won).size(), "battle_reports_compared": battle_count,
		"ruins_consumed_and_revisited": checked_ruins, "save_reload_pairs": reload_count,
		"elapsed_ms": Time.get_ticks_msec() - suite_started, "user_data_dir": ProjectSettings.globalize_path("user://"),
		"production_state_mutation": "none; progression only through public gameplay APIs",
		"bulk_persistence": "all floors, pending bosses, consumed ruins and endings saved/reloaded; quick writes every operation"}
	FileAccess.open(evidence_out + ("batch-results.json" if batch else "quick-results.json"), FileAccess.WRITE).store_string(JSON.stringify(stats, "\t"))

func _finish() -> void:
	_write_results()
	print("Phase3 integration: %d checks, %d failures, %d routes, %d midboss passes" % [checks, failures.size(), routes.size(), midboss_proofs])
	quit(0 if failures.is_empty() else 1)
