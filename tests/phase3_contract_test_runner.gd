extends SceneTree
const Contract = preload("res://scripts/core/phase3_contract.gd")
var checks := 0
var failures := 0

func _initialize() -> void:
	_check(Contract.classify({}).kind == "empty", "empty account is not a new run")
	_check(Contract.classify({"mode":"grid_prototype_v1", "generator_version":3}).kind == "legacy_trial", "trial generator 3 stays legacy")
	_check(Contract.classify({"mode":"tower_campaign_v1"}).kind == "legacy_campaign", "missing old combat version keeps legacy semantics")
	_check(not Contract.classify({"mode":"unknown"}).ok, "unknown mode rejected")
	_check(not Contract.classify({"mode":"tower_campaign_v1", "combat_rules_version":2}).ok, "partial new run never falls back to old combat")
	_check(not Contract.classify({"mode":"grid_prototype_v1", "phase3_contract_version":1}).ok, "no accidental trial upgrade")
	var current := _new_run()
	var original := current.duplicate(true)
	_check(Contract.classify(current).kind == "phase3_campaign", "explicit new run routes correctly")
	_check(current == original, "classification is read only")
	for field in Contract.RUN_VERSIONS:
		for invalid in [null, true, "2", -1, 0.5, INF, NAN, 99]:
			var bad := current.duplicate(true)
			bad[field] = invalid
			_check(not Contract.classify(bad).ok, "bad version %s rejected" % field)
		var json_roundtrip := current.duplicate(true)
		json_roundtrip[field] = float(Contract.RUN_VERSIONS[field])
		_check(Contract.classify(json_roundtrip).ok, "JSON integral float allowed: %s" % field)
	var versions := Contract.new_run_versions()
	versions.generator_version = 99
	_check(Contract.new_run_versions().generator_version == 2, "caller cannot alter shared version defaults")
	_check(Contract.validate_profile({}, []).ok, "default configuration unlocked without migration")
	_check(not Contract.validate_profile({"challenge_id":"p3_c1"}, []).ok, "locked challenge rejected")
	_check(not Contract.validate_profile({"start_config_id":"p3_trader"}, []).ok, "locked start rejected")
	_check(not Contract.validate_profile({"challenge_id":7}, []).ok, "invalid profile type rejected")
	_check(not Contract.validate_profile({}, [null]).ok, "bad unlock entry rejected")
	var ids := ["p3_trader", "p3_c1", "p3_trader"]
	var before := ids.duplicate()
	var selected := Contract.validate_profile({"challenge_id":"p3_c1", "start_config_id":"p3_trader"}, ids)
	_check(selected.ok and selected.profile.unlocked_ids == ["default", "p3_c0", "p3_c1", "p3_trader"], "profile snapshot is stable and deduplicated")
	_check(ids == before, "profile validation does not mutate account unlocks")
	_check(not Contract.validate_snapshots(current).ok, "new run must carry snapshots before persistence")
	current.campaign_rules_snapshot = {"version":2}
	current.campaign_plan = {"version":2}
	current.challenge_snapshot = {"version":1, "id":"p3_c0"}
	current.start_config_snapshot = {"version":1, "id":"default"}
	current.unlocked_pool_snapshot = ["default", "p3_c0"]
	_check(Contract.validate_snapshots(current).ok, "coherent default snapshot accepted")
	current.challenge_snapshot.id = "p3_c2"
	_check(not Contract.validate_snapshots(current).ok, "snapshot cannot select a locked difficulty")
	current.unlocked_pool_snapshot.append("p3_c2")
	_check(Contract.validate_snapshots(current).ok, "unlocked difficulty snapshot accepted")
	current.campaign_plan.version = 1
	_check(not Contract.validate_snapshots(current).ok, "mixed old/new generator snapshots rejected")
	print("Phase 3 contract: %d checks, %d failures" % [checks, failures])
	quit(1 if failures else 0)

func _new_run() -> Dictionary:
	var run := Contract.new_run_versions()
	run.mode = "tower_campaign_v1"
	run.campaign_kind = "tower_10f"
	return run

func _check(condition: bool, label: String) -> void:
	checks += 1
	if not condition:
		failures += 1
		push_error("FAIL: " + label)
