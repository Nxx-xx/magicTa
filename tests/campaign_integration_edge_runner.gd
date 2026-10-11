extends SceneTree
## Cross-module cases absent from reference routes: interrupted mode switches and frozen catalogs.
const Core = preload("res://scripts/core/campaign_engine.gd")
const Store = preload("res://scripts/core/campaign_save.gd")
const Progress = preload("res://scripts/core/campaign_progress.gd")
const DB = preload("res://scripts/core/content_db.gd")
const Equal = preload("res://tests/saved_data.gd")
var checks := 0
var failures := 0
var path := "user://campaign_edge_%d.json" % OS.get_process_id()

class FailStore:
	extends RefCounted
	var last_error := "injected interruption"
	func write(_run: Dictionary, _meta: Dictionary) -> bool: return false

func _initialize() -> void:
	_snapshot_corruption()
	_mode_switch_rollback()
	_account_only_and_repeated_load()
	_frozen_budget()
	print("Campaign integration edge tests: %d checks, %d failures" % [checks,failures])
	quit(1 if failures else 0)

func _check(ok: bool, label: String) -> void:
	checks += 1
	if not ok:
		failures += 1
		push_error("FAIL: " + label)

func _new():
	var core = Core.new(path)
	core.persistence_enabled = false
	core.start_campaign("edge")
	return core

func _snapshot_corruption() -> void:
	var core = _new()
	var store = Store.new(path)
	var baseline: Dictionary = {"version":1,"run":core.state.duplicate(true),"meta":core.meta.duplicate(true)}
	for field in ["floor_names","floor_budgets","normal_templates"]:
		var broken := baseline.duplicate(true)
		broken.run.campaign_rules_snapshot[field] = []
		_check(not store._valid(broken), "reject truncated future floor configuration: " + field)
	var broken := baseline.duplicate(true)
	broken.run.campaign_plan.floors["2"].reward_budget = [0]
	_check(not store._valid(broken), "reject truncated future reward budget")
	broken = baseline.duplicate(true)
	broken.run.campaign_rules_snapshot.event_floors["2"] = "unknown_event"
	_check(not store._valid(broken), "reject future event reference missing from frozen catalog")
	broken = baseline.duplicate(true)
	broken.run.campaign_plan.floors["3"].fixed_equipment = []
	_check(not store._valid(broken), "reject required growth removed from plan")
	broken = baseline.duplicate(true)
	broken.run.side_objective_complete = "false"
	_check(not store._valid(broken), "reject invalid side objective flag")
	broken = baseline.duplicate(true)
	broken.run.last_report = {"log":[{}]}
	_check(not store._valid(broken), "reject malformed battle log before UI renders it")
	broken = baseline.duplicate(true)
	for entity in broken.run.floors["1"].entities.values():
		if entity.type == "enemy":
			broken.run.position = entity.pos.duplicate()
			break
	_check(not store._valid(broken), "reject standing inside an undefeated enemy")

func _mode_switch_rollback() -> void:
	var core = Core.new(path)
	core.store = FailStore.new()
	var error: String = core.start_campaign("first_failure")
	_check(not error.is_empty() and core.transaction_pending and core.state.is_empty(), "first campaign creation failure remains pending without visible run")
	core.store = Store.new(path)
	_check(core.retry_save() and core.is_campaign() and core.active(), "first campaign retry installs the candidate")
	_check(core.abandon_run().is_empty(), "end campaign before switching mode")
	var before_state: Dictionary = core.state.duplicate(true)
	var before_meta: Dictionary = core.meta.duplicate(true)
	var before_rng: String = str(core.rng.state)
	var before_enemy: Dictionary = core.db.enemy("golem")
	core.store = FailStore.new()
	error = core.start("legacy_random_seed", false)
	_check(not error.is_empty(), "retired trial start rejected before persistence")
	_check(not core.transaction_pending and Equal.equal(before_state,core.state) and Equal.equal(before_meta,core.meta), "rejected trial preserves ended campaign and account")
	_check(str(core.rng.state) == before_rng and Equal.equal(core.db.enemy("golem"),before_enemy), "rollback restores RNG and frozen combat database")
	core.store = Store.new(path)
	_check(core.retry_save() and core.is_campaign() and Equal.equal(before_state,core.state), "retry cannot install retired trial")
	_check(core.start_campaign("next_campaign").is_empty(), "next campaign creates another distinct journey")
	_check(core.state.run_id != before_state.run_id and core.meta.runs == 1, "mode switches retain account without duplicating settlement")

func _account_only_and_repeated_load() -> void:
	var account: Dictionary = Progress.default_meta()
	account.souls = 8
	account.souls_earned_total = 8
	var store = Store.new(path)
	_check(store.write({},account), "persist account without a run")
	var core = Core.new(path)
	core.load_game()
	_check(core.state.is_empty() and core.purchase_upgrade("attack").is_empty(), "empty run account can purchase and persist")
	var second = Core.new(path)
	second.load_game()
	_check(second.state.is_empty() and second.meta.upgrades.attack == 1 and second.meta.souls == 0, "account-only purchase survives reload")
	second.start_campaign("snapshot")
	var snapshot_attack: int = int(second.db.enemy("golem").attack)
	_check(snapshot_attack != int(DB.new().enemy("golem").attack), "campaign catalog differs from baseline for pollution test")
	var trial = preload("res://tests/legacy_map_core_fixture.gd").new(path)
	trial.persistence_enabled = false
	trial.start("old",false)
	trial.state.erase("reward_content")
	_check(store.write(trial.state,account), "legacy no-snapshot trial fixture persists")
	second.load_game()
	_check(second.state.is_empty() and Equal.equal(second.db.enemy("golem"),DB.new().enemy("golem")), "retired save load resets catalog and clears playable run")

func _frozen_budget() -> void:
	var core = _new()
	core.state.reward_content.shop.buy_potion.item_id = "iron_sword"
	core._sync_runtime()
	var map: Dictionary = core.campaign_generator.generate(core.state.campaign_plan,3,"shop")
	_check(map.is_empty() and not core.campaign_generator.last_error.is_empty(), "future floor budget counts the frozen potion offer's added equipment")

