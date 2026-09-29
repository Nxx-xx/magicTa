extends SceneTree
const Core = preload("res://scripts/core/campaign_engine.gd")
const Progress = preload("res://scripts/core/campaign_progress.gd")
const Story = preload("res://scripts/core/story_state.gd")
const Store = preload("res://scripts/core/campaign_save.gd")
const Equal = preload("res://tests/saved_data.gd")
var checks := 0
var failures := 0
var path := "user://phase2_story_%d.json" % OS.get_process_id()

class FailingStore:
	extends RefCounted
	var last_error := "injected write failure"
	func write(_run: Dictionary, _meta: Dictionary) -> bool:
		return false

func _initialize() -> void:
	_test_progress()
	_test_story()
	_test_validation()
	_test_transactions()
	for suffix in ["", ".bak", ".tmp"]:
		if FileAccess.file_exists(path + suffix): DirAccess.remove_absolute(ProjectSettings.globalize_path(path + suffix))
	print("Campaign story/save tests: %d checks, %d failures" % [checks, failures])
	quit(1 if failures else 0)

func _check(value: bool, message: String) -> void:
	checks += 1
	if not value:
		failures += 1
		push_error("FAIL: " + message)

func _core():
	var core = Core.new(path)
	core.persistence_enabled = false
	_check(core.start_campaign("42").is_empty(), "campaign initialized")
	return core

func _test_progress() -> void:
	var meta: Dictionary = Progress.default_meta()
	var base: Dictionary = Progress.initial_player(meta)
	_check(base.hp == 100 and base.attack == 10 and base.gold == 0, "zero upgrade start")
	meta.souls = 144
	meta.souls_earned_total = 144
	for kind in Progress.KINDS:
		for level in range(3):
			var before := meta.duplicate(true)
			var transaction: Dictionary = Progress.purchase(meta, kind)
			_check(transaction.ok and Equal.equal(meta, before), "purchase is pure")
			meta = transaction.meta
	var boosted: Dictionary = Progress.initial_player(meta)
	_check(boosted.hp == 115 and boosted.attack == 13 and boosted.gold == 15 and meta.souls == 0, "all nine upgrades cost 144")
	_check(not Progress.purchase(meta, "hp").ok and not Progress.purchase(meta, "defense").ok, "max and unknown upgrades rejected")
	var reset: Dictionary = Progress.reset(meta)
	_check(reset.ok and reset.refund == 144 and reset.meta.souls == 144 and reset.meta.souls_earned_total == 144, "full refund is not earned souls")
	_check("all_upgrades" in reset.meta.milestones and not Progress.reset(reset.meta).ok, "milestone survives reset, duplicate refund rejected")
	_check(not Progress.purchase(Progress.default_meta(), "hp").ok, "insufficient balance unchanged")
	var core = _core()
	core.state.defeated_entities = [{"id":"one","rank":"normal","floor":1}, {"id":"two","rank":"elite","floor":1}, {"id":"boss","rank":"boss","floor":5}, {"id":"one","rank":"normal","floor":1}]
	core.state.player.hp = 0
	var prior: Dictionary = core.state.duplicate(true)
	var settled: Dictionary = Progress.settle(core.state, core.meta, "death")
	_check(settled.ok and settled.meta.souls == 9 and settled.meta.failure_count == 1, "unique kills settle normal elite boss")
	_check(Equal.equal(core.state, prior) and core.meta.failure_count == 0, "settlement does not mutate originals")
	var again: Dictionary = Progress.settle(settled.state, settled.meta, "death")
	_check(again.ok and Equal.equal(again.meta, settled.meta), "repeated committed settlement idempotent")
	_check(not Progress.settle(core.state, settled.meta, "death").ok, "stale candidate cannot settle against advanced account")
	var abandoned: Dictionary = Progress.settle(core.state, core.meta, "abandoned")
	_check(abandoned.ok and abandoned.meta.souls == 0 and abandoned.meta.failure_count == 0, "abandon pays nothing and has no punishment")
	var victory: Dictionary = Progress.settle(core.state, core.meta, "victory")
	_check(victory.meta.souls == 29 and "zero_upgrade_victory" in victory.meta.milestones, "victory adds 20 and milestone")
	var trial: Dictionary = core.state.duplicate(true)
	trial.mode = "grid_prototype_v1"
	_check(not Progress.settle(trial, core.meta, "death").ok, "trial excluded")
	var backtracked: Dictionary = core.state.duplicate(true)
	backtracked.floors["4"] = {}
	var retreated: Dictionary = Progress.settle(backtracked, core.meta, "abandoned")
	_check(retreated.meta.best_floor == 4 and retreated.meta.records[0].floor == 1 and retreated.meta.records[0].highest_floor == 4, "best reached floor survives a retreat to lower floors")

func _test_story() -> void:
	var core = _core()
	var rng_state: String = core.state.rng_state
	Story.enqueue(core.state, "intro")
	_check(core.state.story.queue.size() == 1, "intro once per run")
	core.state.floor = 2
	Story.on_floor(core.state)
	Story.on_floor(core.state)
	_check(core.state.story.queue.size() == 2 and core.state.rng_state == rng_state, "floor revisits and story never change RNG")
	Story.on_failure(core.state, 1)
	_check(core.state.story.queue.size() == 1 and core.state.story.queue[0].audio_cue == "echo_1", "fresh death has immediate cue")
	core.state.result = "death"
	Story.restore_summary(core.state)
	_check(core.state.story.queue[0].audio_cue == "" and core.state.story.queue[0].static_summary, "reloaded death is silent summary")

func _test_validation() -> void:
	var core = _core()
	var store = Store.new(path)
	var envelope := {"version":1,"run":core.state.duplicate(true),"meta":core.meta.duplicate(true)}
	_check(store._valid(envelope), "new campaign save valid")
	_check(store._valid(JSON.parse_string(JSON.stringify(envelope))), "JSON number normalization accepted")
	for hp in ["100", -1, 2.5, 99999999999]:
		var broken := envelope.duplicate(true)
		broken.run.player.hp = hp
		_check(not store._valid(broken), "reject invalid HP " + str(hp))
	for pos in [["5",9], [5.5,9], [11,9], [0,0], [5]]:
		var broken := envelope.duplicate(true)
		broken.run.position = pos
		_check(not store._valid(broken), "reject coordinate " + str(pos))
	var broken := envelope.duplicate(true)
	broken.run.pending = {"kind":"entity","pos":[5,8]}
	_check(not store._valid(broken), "reject nonexistent pending reference")
	broken = envelope.duplicate(true)
	broken.run.reward_content.enemies.slime.hp = "24"
	_check(not store._valid(broken), "reject corrupt enemy snapshot")
	broken = envelope.duplicate(true)
	broken.run.reward_content.items.iron_sword.effects.attack = -1
	_check(not store._valid(broken), "reject negative snapshot effect")
	broken = envelope.duplicate(true)
	broken.run.player.equipment_ids = ["missing"]
	_check(not store._valid(broken), "reject missing equipment reference")
	broken = envelope.duplicate(true)
	broken.meta.upgrades.attack = 0.5
	_check(not store._valid(broken), "reject fractional upgrade")
	broken = envelope.duplicate(true)
	broken.meta.upgrade_spend.hp = 8
	_check(not store._valid(broken), "reject invented refund amount")
	broken = envelope.duplicate(true)
	broken.meta.souls = 2
	_check(not store._valid(broken), "reject unaccounted balance")
	broken = envelope.duplicate(true)
	broken.run.campaign_plan.floors["2"].template_id = 6
	_check(not store._valid(broken), "reject out-of-range future template")
	_check(store.write(core.state, core.meta), "write initial whole envelope")
	core.state.last_message = "second save"
	_check(store.write(core.state, core.meta), "write rotates valid backup")
	var file := FileAccess.open(path, FileAccess.WRITE)
	file.store_string(JSON.stringify(broken))
	file.close()
	var recovered: Dictionary = store.read()
	_check(not recovered.is_empty() and recovered.run.last_message != "second save" and not store.last_error.is_empty(), "valid JSON corrupt primary restores entire backup")
	_check(Equal.equal(recovered.meta, core.meta), "backup account and run remain paired")
	_check(store.write(recovered.run, recovered.meta), "save after recovery preserves good backup")
	file = FileAccess.open(path, FileAccess.WRITE)
	file.store_string("{\"version\":1}")
	file.close()
	_check(not store.read().is_empty(), "second corruption still recovers last good backup")
	var empty := {"version":1,"run":{},"meta":Progress.default_meta()}
	_check(store._valid(empty), "account-only save is valid")
	var trial = Core.new(path)
	trial.persistence_enabled = false
	trial.start("42", false)
	_check(store._valid({"version":1,"run":trial.state,"meta":{}}), "legacy two-floor save accepted")

func _test_transactions() -> void:
	var core = _core()
	# Build a legal ended state using the actual first-floor entity IDs. Combat correctness
	# and the lethal confirmation route are separately covered by the campaign runner.
	for entity in core.floor_data().entities.values():
		if entity.type == "enemy":
			core.state.defeated_entities.append({"id":entity.id,"enemy_id":entity.enemy_id,"rank":"normal","floor":1})
			core.floor_data().entities.erase(Core.cell_key(Vector2i(entity.pos[0],entity.pos[1])))
	core.state.player.hp = 0
	core.persistence_enabled = true
	_check(core._settle("death").is_empty(), "ended state and account save atomically")
	_check(core.meta.souls == 8 and core.meta.failure_count == 1 and core.story_event().audio_cue == "echo_1", "one death awards unique kills and immediate story")
	var resumed = Core.new(path)
	resumed.load_game()
	_check(resumed.meta.souls == 8 and resumed.meta.failure_count == 1 and resumed.story_event().audio_cue == "", "reload cannot replay death sound or duplicate payment")
	var account_before: Dictionary = core.meta.duplicate(true)
	core.store = FailingStore.new()
	_check(not core.purchase_upgrade("hp").is_empty() and core.transaction_pending, "purchase write failure retains pending transaction")
	_check(Equal.equal(core.meta, account_before), "failed purchase does not charge visible account")
	_check(not core.start_campaign("new").is_empty() and not core.reset_upgrades().is_empty(), "pending purchase blocks new run and reset")
	core.store = Store.new(path)
	_check(core.retry_save() and core.meta.souls == 0 and core.meta.upgrades.hp == 1, "purchase retry commits exactly once")
	_check(core.retry_save() and core.meta.souls == 0 and core.meta.upgrades.hp == 1, "second retry does not repurchase")
	core.store = FailingStore.new()
	_check(not core.reset_upgrades().is_empty() and core.transaction_pending and core.meta.souls == 0, "failed refund leaves prior account intact")
	core.store = Store.new(path)
	_check(core.retry_save() and core.meta.souls == 8 and core.meta.upgrades.hp == 0, "refund retry commits exactly once")
	_check(not core.reset_upgrades().is_empty() and core.meta.souls == 8, "second refund cannot mint souls")
	var same_seed_id: String = core.state.run_id
	_check(core.start_campaign("42").is_empty() and core.state.run_id != same_seed_id, "same seed creates new settlement identity")
	_check(core.state.player.hp == 100 and core.meta.failure_count == 1 and core.story_event().id == "retry", "fresh run preserves count and uses retry story")

