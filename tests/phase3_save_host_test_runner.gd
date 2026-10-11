extends SceneTree
## Isolated persistence fixtures; unlock fixture is NOT evidence of earned progression.
const Core = preload("res://scripts/core/campaign_engine.gd")
const Store = preload("res://scripts/core/campaign_save.gd")
const Progress = preload("res://scripts/core/phase3_progress.gd")
const Contract = preload("res://scripts/core/phase3_contract.gd")
var checks := 0
var failures := 0
var folder := ""

func _initialize() -> void:
	if not ProjectSettings.globalize_path("user://").replace("\\", "/").contains("phase3/00-integration/"):
		quit(2)
		return
	folder = "user://save_audit_%d" % Time.get_ticks_usec()
	DirAccess.make_dir_recursive_absolute(folder)
	var old = Core.new(folder + "/legacy.json")
	_check(old.start_campaign("42").is_empty(), "legacy production start")
	var legacy := {"version":1,"run":old.state.duplicate(true),"meta":old.meta.duplicate(true)}
	_check(Store.new(folder + "/validator.json")._valid(legacy), "original v1 envelope accepted")
	FileAccess.open(folder + "/legacy_v1.json",FileAccess.WRITE).store_string(JSON.stringify(legacy))
	var migrated = Core.new(folder + "/legacy_v1.json")
	migrated.load_game()
	_check(not migrated.state.is_empty() and not migrated.is_phase3() and migrated.db.rules_version == 1, "old run retains v1 dispatch")
	_check(migrated.meta.meta_schema_version == 2 and migrated.save_game(), "old account migrates and writes v2 envelope")
	_check(Contract.same_json(migrated.state, legacy.run), "migration preserves legacy gameplay tree")
	for challenge in ["p3_c0","p3_c1","p3_c2"]:
		var core = Core.new(folder + "/" + challenge + ".json")
		core.meta = Progress.migrate_meta(core.meta)
		# Use canonical start IDs; only challenges are needed for this persistence fixture.
		core.meta.unlocked_ids = ["p3_c0","default","p3_c1","p3_c2"]
		var error: String = core.start_phase3("42",challenge)
		_check(error.is_empty(), challenge + " new run: " + error)
		if not error.is_empty(): continue
		var snapshot: Dictionary = core.state.duplicate(true)
		var saved := {"version":2,"run":snapshot,"meta":core.meta.duplicate(true)}
		var store = Store.new(folder + "/validator.json")
		_check(store._valid(saved), challenge + " live envelope valid")
		_check(store._valid(JSON.parse_string(JSON.stringify(saved))), challenge + " JSON envelope valid")
		var invalid_layout := saved.duplicate(true)
		invalid_layout.run.campaign_rules_snapshot.ruin_geometry = "unknown"
		_check(not store._valid(invalid_layout), challenge + " unknown geometry rejected")
		var prior_v2 := snapshot.duplicate(true)
		prior_v2.campaign_rules_snapshot.erase("ruin_geometry")
		var old_v2 = Core.new(folder + "/old_v2_" + challenge + ".json")
		_check(old_v2.start_phase3("ignored", "p3_c0", "default", prior_v2).is_empty(), challenge + " prior v2 snapshot retry")
		if not old_v2.state.is_empty():
			var old_floor: Dictionary = old_v2.campaign_generator.generate(old_v2.state.campaign_plan, 2, "battle")
			_check(old_floor.get("phase3_recipe", {}).get("report", {}).get("geometry") == "existing", challenge + " old retry retains future floor geometry")
			_check(old_v2.save_game(), challenge + " old v2 layout snapshot saves")
			var old_loaded = Core.new(folder + "/old_v2_" + challenge + ".json")
			old_loaded.load_game()
			_check(old_loaded.campaign_generator.generate(old_loaded.state.campaign_plan, 2, "battle") == old_floor, challenge + " old v2 layout survives disk reload")
		var resumed = Core.new(folder + "/" + challenge + ".json")
		resumed.load_game()
		_check(resumed.is_phase3() and resumed.db.rules_version == 2 and Contract.same_json(resumed.state,snapshot), challenge + " real disk read")
		_check(core.abandon_run().is_empty(), challenge + " abandonment settles once")
		var account: Dictionary = core.meta.duplicate(true)
		core._settle("abandoned")
		_check(core.meta == account, challenge + " settlement replay idempotent")
		_check(core.start_phase3("ignored","p3_c0","default",snapshot).is_empty(), challenge + " frozen retry")
		_check(core.state.run_id != snapshot.run_id and core.state.challenge_id == challenge and Contract.same_json(core.state.reward_content,snapshot.reward_content) and Contract.same_json(core.state.floors,snapshot.floors), challenge + " new identity, same frozen world")
		for field in ["combat_rules_version","reward_rules_version","generator_version","phase3_contract_version"]:
			var bad := saved.duplicate(true)
			bad.run[field] = 99
			_check(not store._valid(bad), challenge + " unknown " + field)
		for field in ["challenge_snapshot","start_config_snapshot","progress_rules_snapshot","ruin_definitions_snapshot","variant_plan","reserved_unique_ids","codex_events"]:
			var bad := saved.duplicate(true)
			bad.run[field] = "bad-type"
			_check(not store._valid(bad), challenge + " malformed " + field)
		var bad := saved.duplicate(true)
		bad.run.floors["1"].phase3_healing.heal_percent = 1
		_check(not store._valid(bad), challenge + " wrong healing rule refused")
		bad = saved.duplicate(true)
		bad.run.reserved_unique_ids.append("p3_dawn_sigil")
		_check(not store._valid(bad), challenge + " invented unique reservation refused")
		for entity in saved.run.floors["1"].entities.values():
			if entity.type != "potion": continue
			bad = saved.duplicate(true)
			var key := "%d,%d" % [entity.pos[0],entity.pos[1]]
			bad.run.floors["1"].entities[key].amount += 1
			_check(not store._valid(bad), challenge + " altered potion refused")
			break
		# A invalid write never overwrites the last valid primary or backup.
		var disk = Store.new(folder + "/recovery_" + challenge + ".json")
		_check(disk.write(saved.run,saved.meta) and disk.write(saved.run,saved.meta), challenge + " backup created")
		var before := FileAccess.get_file_as_string(disk.path)
		_check(not disk.write(bad.run,bad.meta) and FileAccess.get_file_as_string(disk.path) == before, challenge + " malformed write preserves primary")
		FileAccess.open(disk.path,FileAccess.WRITE).store_string("{broken")
		var recovered: Dictionary = disk.read()
		_check(not recovered.is_empty() and Contract.same_json(recovered.run,saved.run), challenge + " broken primary restores whole backup")
	print("PHASE3_SAVE_HOST checks=%d failures=%d" % [checks,failures])
	quit(1 if failures else 0)

func _check(ok: bool, label: String) -> void:
	checks += 1
	if not ok:
		failures += 1
		push_error("FAIL " + label)
