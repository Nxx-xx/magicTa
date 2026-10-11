extends SceneTree
const Core = preload("res://scripts/core/campaign_engine.gd")
const Store = preload("res://scripts/core/campaign_save.gd")
const Old = preload("res://scripts/core/campaign_progress.gd")
const P3 = preload("res://scripts/core/phase3_progress.gd")
const V = preload("res://scripts/core/phase3_save_validation.gd")
const Items = preload("res://scripts/core/phase3_items.gd")
const Combat = preload("res://scripts/core/phase3_combat.gd")
const Equal = preload("res://tests/saved_data.gd")
var checks := 0
var failures := 0
var directory := "user://phase3-save-%d" % OS.get_process_id()
var path: String

func _initialize() -> void:
	_run.call_deferred()

func check(condition: bool, label: String) -> void:
	checks += 1
	if not condition:
		failures += 1
		push_error("FAIL " + label)

func write_raw(target: String, value: Variant) -> void:
	var file := FileAccess.open(target, FileAccess.WRITE)
	file.store_string(value if value is String else JSON.stringify(value))
	file.close()

func _run() -> void:
	DirAccess.make_dir_recursive_absolute(ProjectSettings.globalize_path(directory))
	path = directory.path_join("save.json")
	var core = Core.new(path)
	var error: String = core.start_phase3("42")
	check(error.is_empty(), "actual phase3 start: " + error)
	if not error.is_empty():
		finish()
		return
	var store = Store.new(path)
	var envelope := {"version":2, "run":core.state.duplicate(true), "meta":core.meta.duplicate(true)}
	check(store._valid(envelope), "actual v2 initial validates")
	check(JSON.parse_string(FileAccess.get_file_as_string(path)).version == 2, "writes v2 envelope")
	var loaded := store.read()
	check(Equal.equal(loaded.run, core.state) and Equal.equal(loaded.meta,core.meta), "whole initial roundtrip")
	for location in [["version"], ["run","phase3_contract_version"], ["run","combat_rules_version"], ["run","reward_rules_version"], ["run","generator_version"], ["run","challenge_snapshot","version"], ["run","campaign_plan","version"], ["meta","meta_schema_version"]]:
		for invalid in [99, "2", true, null]:
			var bad := envelope.duplicate(true)
			var cursor: Dictionary = bad
			for key in location.slice(0,location.size()-1): cursor = cursor[key]
			cursor[location[-1]] = invalid
			check(not store._valid(bad), "unknown/bad version " + str(location))
	for field in ["player","floors","pending","last_report","campaign_plan","campaign_rules_snapshot","challenge_snapshot","start_config_snapshot","progress_rules_snapshot","ruin_definitions_snapshot","variant_plan","metrics","meta_snapshot"]:
		var bad := envelope.duplicate(true)
		bad.run[field] = "bad"
		check(not store._valid(bad), "reject run container " + field)
	for field in ["unlocked_ids","achievement_ids","achievement_records","phase3_settled_runs","phase3_codex_events","codex"]:
		var bad := envelope.duplicate(true)
		bad.meta[field] = 7
		check(not store._valid(bad), "reject meta container " + field)
	var bad := envelope.duplicate(true)
	bad.run.player.relic_ids = ["p3_dawn_sigil","p3_dawn_sigil"]
	check(not store._valid(bad), "reject duplicated unique relic")
	bad = envelope.duplicate(true)
	bad.run.reward_content.items.p3_dawn_sigil.combat_effects[0].id = "unknown"
	check(not store._valid(bad), "reject unknown item effect")
	bad = envelope.duplicate(true)
	bad.run.reward_content.events.p3_oath_forge.options[1].cost.max_hp = -10
	check(not store._valid(bad), "reject negative cap cost")
	bad = envelope.duplicate(true)
	bad.run.reward_content.enemies.p3_shield_sentinel.ability_id = "unknown"
	check(not store._valid(bad), "reject unknown enemy ability")
	bad = envelope.duplicate(true)
	bad.run.reward_content.phase3_challenge_applied = "p3_c2"
	check(not store._valid(bad), "challenge marker matches frozen profile")
	bad = envelope.duplicate(true)
	bad.run.progress_rules_snapshot.challenges.challenges.p3_c0.normal_attack = "1"
	check(not store._valid(bad), "reject malformed frozen definition")
	for location in [["run","challenge_id"],["run","reward_content","items","p3_dawn_sigil","id"],["run","reward_content","items","p3_dawn_sigil","kind"],["run","reward_content","enemies","slime","id"],["run","progress_rules_snapshot","challenges","challenges","p3_c0","id"],["run","progress_rules_snapshot","unlocks","unlocks","p3_shop_30","grants"],["run","ruin_definitions_snapshot","p3_oath_ruin","floor"],["run","floors","1","phase3_recipe","new_unique_ids"],["run","floors","1","template_id"]]:
		for wrong in [{}, [], true, null]:
			bad = envelope.duplicate(true)
			var target: Dictionary = bad
			for key in location.slice(0,location.size()-1): target = target[key]
			if typeof(target[location[-1]]) == typeof(wrong) and Equal.equal(target[location[-1]], wrong): continue
			target[location[-1]] = wrong
			check(not store._valid(bad), "bad nested type " + str(location))
	# Real v2 generation, then retain a consumed ruin entity through the disk boundary.
	var second: Dictionary = core.campaign_generator.generate(core.state.campaign_plan,2,"battle")
	check(not second.is_empty(), "actual floor2 generated")
	core.state.floors["2"] = second
	core.state.reserved_unique_ids.append_array(second.phase3_new_unique_ids)
	core.state.floor = 2
	core.state.position = second.entry.duplicate()
	var ruin_cell := ""
	for cell in second.entities:
		if second.entities[cell].get("ruin_id") == "p3_oath_ruin": ruin_cell = cell
	check(not ruin_cell.is_empty(), "actual ruin exists")
	core.state.position = second.entities[ruin_cell].pos.duplicate()
	core.state.pending = {"kind":"entity","pos":second.entities[ruin_cell].pos.duplicate()}
	check(core.choose_ruin("salvage").is_empty(), "actual ruin transaction saved")
	loaded = store.read()
	check(loaded.run.floors["2"].entities[ruin_cell].status == "resolved" and loaded.run.player.gold == 8, "resolved entity and reward roundtrip")
	var resolved := {"version":2,"run":loaded.run.duplicate(true),"meta":loaded.meta.duplicate(true)}
	bad = resolved.duplicate(true)
	bad.run.floors["2"].entities[ruin_cell].selected_option = "leave"
	check(not store._valid(bad), "resolved leave rejected")
	bad = resolved.duplicate(true)
	bad.run.floors["2"].entities[ruin_cell].transaction_id = "foreign-run"
	check(not store._valid(bad), "foreign transaction rejected")
	bad = resolved.duplicate(true)
	bad.run.metrics.ruin_choices.clear()
	check(not store._valid(bad), "ruin and metric mismatch rejected")
	bad = resolved.duplicate(true)
	bad.run.floors["2"].phase3_recipe.version = 99
	check(not store._valid(bad), "unknown recipe version rejected")
	# Extended reports use the production simulator, including real effect events.
	var player: Dictionary = core.state.player.duplicate(true)
	player.relic_ids = ["p3_dawn_sigil","p3_lantern_aegis","p3_thorn_clasp"]
	var report := Combat.simulate(player,core.db.data.enemies.slime,Items.player_stats(player,core.db.data))
	check(V.valid_report(report,core.db.data), "actual extended report validates")
	bad = resolved.duplicate(true)
	bad.run.last_report = report
	check(store._valid(bad), "extended report envelope")
	bad.run.last_report.effects_triggered[0].amount += 1
	check(not store._valid(bad), "report summary/log mismatch rejected")
	# Invalid write must not rotate either known-good file.
	var primary := FileAccess.get_file_as_bytes(path)
	var backup := FileAccess.get_file_as_bytes(path + ".bak")
	check(not store.write(bad.run,bad.meta), "invalid write refused")
	check(primary == FileAccess.get_file_as_bytes(path) and backup == FileAccess.get_file_as_bytes(path+".bak"), "invalid write preserves exact primary/backup")
	check(store.write(resolved.run,resolved.meta), "good write rotates matching envelope")
	write_raw(path,"{ broken JSON")
	loaded = store.read()
	check(not loaded.is_empty() and not store.last_error.is_empty() and Equal.equal(loaded.run,resolved.run) and Equal.equal(loaded.meta,resolved.meta), "bad primary restores paired backup")
	check(store.write(loaded.run,loaded.meta), "save after recovery")
	write_raw(path,{"version":99,"run":resolved.run,"meta":resolved.meta})
	check(not store.read().is_empty(), "unknown primary version falls back")
	write_raw(path+".bak","broken backup")
	check(store.read().is_empty(), "bad primary and backup both rejected")
	check(FileAccess.file_exists(path) and FileAccess.file_exists(path+".bak"), "bad originals retained")
	# Genuine IO failure followed by retry; no player-save paths involved.
	var retry_path := directory.path_join("missing/sub/save.json")
	var retry = Store.new(retry_path)
	check(not retry.write(resolved.run,resolved.meta), "missing directory write fails")
	DirAccess.make_dir_recursive_absolute(ProjectSettings.globalize_path(directory.path_join("missing/sub")))
	check(retry.write(resolved.run,resolved.meta), "same candidate succeeds on retry")
	check(Equal.equal(retry.read().meta,resolved.meta), "retry does not mint currency/counters")
	core.store = retry
	check(core._settle("abandoned").is_empty(), "actual abandonment settles and saves")
	var ended := retry.read()
	check(not ended.is_empty() and ended.meta.phase3_settled_runs[ended.run.run_id] == "abandoned" and ended.meta.souls == 0 and ended.meta.runs == 1, "settled permanent key and counters roundtrip")
	var ended_before: Dictionary = ended.meta.duplicate(true)
	check(core._settle("abandoned").is_empty() and Equal.equal(core.meta, ended_before), "repeated settle keeps counters")
	bad = ended.duplicate(true)
	bad.meta.phase3_settled_runs.clear()
	check(not store._valid(bad), "ended run requires permanent ledger")
	bad = ended.duplicate(true)
	bad.meta.phase3_settled_runs[bad.run.run_id] = "victory"
	check(not store._valid(bad), "ended result agrees with ledger")
	challenge_roundtrips()
	legacy_compatibility()
	engine_retry()
	finish()

func engine_retry() -> void:
	var target := directory.path_join("engine-missing/nested/save.json")
	var core = Core.new(target)
	check(not core.start_phase3("19").is_empty() and core.transaction_pending, "real new-run IO failure holds candidate")
	check(core.state.is_empty() and core.meta.runs == 0, "failed new-run leaves committed state untouched")
	DirAccess.make_dir_recursive_absolute(ProjectSettings.globalize_path(directory.path_join("engine-missing/nested")))
	check(core.retry_save() and not core.transaction_pending and core.is_phase3(), "real new-run retry commits candidate")
	var account: Dictionary = core.meta.duplicate(true)
	core.store.path = directory.path_join("still-missing/save.json")
	check(not core._settle("abandoned").is_empty() and core.transaction_pending, "real settlement IO failure holds candidate")
	check(Equal.equal(core.meta,account) and core.state.result.is_empty(), "failed settlement rolls back counters and ledger in memory")
	core.store.path = target
	check(core.retry_save() and core.meta.runs == 1 and core.state.result == "abandoned", "settlement retry commits run/meta once")
	var committed: Dictionary = core.meta.duplicate(true)
	check(core.retry_save() and Equal.equal(core.meta,committed), "repeat retry cannot reaward")

func challenge_roundtrips() -> void:
	for challenge in ["p3_c1", "p3_c2"]:
		var core = Core.new(directory.path_join(challenge+".json"))
		core.meta = P3.migrate_meta(Old.default_meta())
		core.meta.unlocked_ids.append_array(["p3_c1","p3_c2"])
		var error: String = core.start_phase3("81",challenge)
		check(error.is_empty(), "real challenge start " + challenge + ": " + error)
		if not error.is_empty(): continue
		for number in [2,3,4]:
			core.campaign_generator.phase3_context.used_unique_ids = core.state.reserved_unique_ids.duplicate()
			var floor_data: Dictionary = core.campaign_generator.generate(core.state.campaign_plan, number, "battle")
			check(not floor_data.is_empty(), "challenge generates floor " + str(number))
			core.state.floors[str(number)] = floor_data
			core.state.reserved_unique_ids.append_array(floor_data.phase3_new_unique_ids)
		check(core.save_game(), "challenge writes visited floors")
		var loaded: Dictionary = core.store.read()
		check(not loaded.is_empty() and Equal.equal(loaded.run,core.state), "challenge whole disk roundtrip")
		if loaded.is_empty(): continue
		var base := {"version":2,"run":loaded.run,"meta":loaded.meta}
		var bad := base.duplicate(true)
		bad.run.floors["1"].phase3_healing.heal_percent = 33
		check(not core.store._valid(bad), "tampered healing percent rejected")
		for entity in bad.run.floors["4"].entities.values():
			if entity.type == "rest":
				bad = base.duplicate(true)
				bad.run.floors["4"].entities["%d,%d" % [entity.pos[0],entity.pos[1]]].options[0].phase3_heal_base = "wrong"
				check(not core.store._valid(bad), "bad heal base type rejected")
				bad = base.duplicate(true)
				bad.run.floors["4"].entities["%d,%d" % [entity.pos[0],entity.pos[1]]].options[0].effects.heal += 1
				check(not core.store._valid(bad), "double/mismatched heal scaling rejected")
		for location in [["run","floors","1","phase3_recipe"],["run","floors","1","phase3_healing"],["run","floors","1","phase3_new_unique_ids"],["run","floors","1","branch_paths"],["run","floors","1","safe_slots"],["run","progress_rules_snapshot","challenges"],["run","progress_rules_snapshot","unlocks"]]:
			for value in ["bad", 4, null, []]:
				bad = base.duplicate(true)
				var cursor: Dictionary = bad
				for key in location.slice(0,location.size()-1): cursor = cursor[key]
				if typeof(cursor[location[-1]]) == typeof(value) and Equal.equal(cursor[location[-1]],value): continue
				cursor[location[-1]] = value
				check(not core.store._valid(bad), "malformed frozen subtree " + str(location))

func legacy_compatibility() -> void:
	var legacy = Core.new(directory.path_join("old.json"))
	legacy.persistence_enabled = false
	check(legacy.start_campaign("27").is_empty(), "legacy campaign fixture")
	var original: Dictionary = legacy.state.duplicate(true)
	var account: Dictionary = legacy.meta.duplicate(true)
	write_raw(legacy.store.path,{"version":1,"run":original,"meta":account})
	var loaded: Dictionary = legacy.store.read()
	check(Equal.equal(loaded.run,original), "v1 run rules/content unchanged")
	for key in account:
		check(Equal.equal(loaded.meta[key],account[key]), "v1 meta field unchanged " + key)
	check(loaded.meta.meta_schema_version == 2 and P3.validate_meta_extensions(loaded.meta).ok, "v1 account migrates to schema2")
	check(legacy.store.write(loaded.run,loaded.meta), "v1 run saves inside v2 envelope")
	check(JSON.parse_string(FileAccess.get_file_as_string(legacy.store.path)).version == 2, "legacy migration writes v2")
	check(Equal.equal(legacy.store.read().run,original), "old run stays v1 after write/read")
	var trial = preload("res://tests/legacy_map_core_fixture.gd").new(directory.path_join("trial.json"))
	trial.persistence_enabled = false
	check(trial.start("42",true).is_empty(), "old trial fixture")
	write_raw(trial.store.path,{"version":1,"run":trial.state,"meta":{}})
	var trial_loaded: Dictionary = trial.store.read()
	check(not trial_loaded.is_empty() and trial_loaded.run.mode == "grid_prototype_v1" and trial_loaded.meta.meta_schema_version == 2, "empty legacy trial account migrates")
	check(trial.store.write(trial_loaded.run,trial_loaded.meta), "trial saved inside v2 envelope")
	var winner := Old.default_meta()
	winner.souls = 20
	winner.souls_earned_total = 20
	winner.runs = 1
	winner.wins = 1
	winner.best_floor = 10
	winner.milestones = ["first_victory"]
	winner.last_settled_run_id = "legacy-win"
	winner.records = [{"run_id":"legacy-win","result":"victory","floor":10,"highest_floor":10,"seed":"42","souls":20,"kills":0,"failure_count":0}]
	var winner_path := directory.path_join("winner.json")
	write_raw(winner_path,{"version":1,"run":{},"meta":winner})
	var winner_store = Store.new(winner_path)
	var migrated: Dictionary = winner_store.read()
	check(not migrated.is_empty() and "p3_c1" in migrated.meta.unlocked_ids and migrated.meta.achievement_ids == ["p3_c0_clear"], "trusted legacy winner only receives C0 recognition")
	check(migrated.meta.souls == 20 and migrated.meta.runs == 1 and migrated.meta.wins == 1, "winner migration keeps old currency/counters")
	check(winner_store.write(migrated.run,migrated.meta), "migrated winner persists schema2")

func finish() -> void:
	print("PHASE3_SAVE_TEST checks=%d failures=%d" % [checks,failures])
	quit(1 if failures else 0)
