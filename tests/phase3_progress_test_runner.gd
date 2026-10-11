extends SceneTree
const P = preload("res://scripts/core/phase3_progress.gd")
const Old = preload("res://scripts/core/campaign_progress.gd")
const CodexPanel = preload("res://scripts/ui/phase3_codex_panel.gd")
const ChallengePanel = preload("res://scripts/ui/phase3_challenge_panel.gd")
var checks := 0
var failures := 0

func _initialize() -> void:
	_run.call_deferred()

func check(value: bool, label: String) -> void:
	checks += 1
	if not value:
		failures += 1
		push_error("FAIL " + label)

func fixture(id: String = "boundary") -> Dictionary:
	return {"mode":"tower_campaign_v1", "campaign_kind":"tower_10f", "run_id":id,
		"result":"death", "combat_rules_version":2, "reward_rules_version":2, "challenge_id":"p3_c0",
		"start_config_snapshot":{"id":"default"}, "meta_snapshot":{"upgrades":{"hp":0,"attack":0,"gold":0}},
		"floor":5, "player":{"gold":99}, "metrics":{}, "defeated_entities":[], "codex_events":[], "completed_at":"2026-10-01"}

func run_test(run: Dictionary) -> Dictionary:
	var meta := P.migrate_meta(Old.default_meta())
	var before := meta.duplicate(true)
	var old_run := run.duplicate(true)
	var candidate := P.evaluate_unlocks(run, meta)
	check(candidate.ok, "candidate valid")
	check(meta == before and run == old_run, "pure inputs")
	if candidate.ok:
		for key in Old.default_meta():
			check(candidate.meta[key] == before[key], "old field preserved: " + key)
		check(P.validate_meta_extensions(candidate.meta).ok, "candidate validates")
	return candidate

func _run() -> void:
	var meta := Old.default_meta()
	meta.souls = 87
	meta.upgrades = {"hp":3,"attack":2,"gold":3}
	meta.upgrade_spend = {"hp":48,"attack":24,"gold":48}
	meta.wins = 1
	meta.records = [{"run_id":"old","result":"victory"}]
	var migrated := P.migrate_meta(meta)
	check(migrated.souls == 87 and migrated.upgrades == meta.upgrades and migrated.upgrade_spend == meta.upgrade_spend and migrated.records == meta.records, "migration keeps all legacy state")
	check(migrated.achievement_ids == ["p3_c0_clear"] and "p3_c1" in migrated.unlocked_ids, "legacy wins only recognizes C0")
	check(P.migrate_meta(migrated) == migrated, "migration idempotent")
	check(not meta.has("codex"), "migration input untouched")
	var first_victory := Old.default_meta()
	first_victory.milestones = ["first_victory"]
	check("p3_c1" in P.migrate_meta(first_victory).unlocked_ids, "legacy milestone recognition")
	var unknown := migrated.duplicate(true)
	unknown.meta_schema_version = 99
	check(P.migrate_meta(unknown) == unknown and not P.validate_meta_extensions(unknown).ok, "unknown schema preserved and rejected")
	var fresh := P.migrate_meta(Old.default_meta())
	check(not P.initial_player(fresh,"missing").ok, "unknown config")
	check(not P.initial_player(fresh,"p3_keeper").ok, "locked config")
	check(not P.select_start(fresh,"p3_c1","default").ok, "locked challenge")
	check(not P.select_start(fresh,"missing","default").ok, "unknown challenge")
	var expected := {"default":[100,10,5,0],"p3_vanguard":[100,12,4,0],"p3_keeper":[110,8,6,0],"p3_trader":[90,10,5,20]}
	for id in expected:
		var unlocked := fresh.duplicate(true)
		if id not in unlocked.unlocked_ids:
			unlocked.unlocked_ids.append(id)
		var initial := P.initial_player(unlocked,id)
		var player: Dictionary = initial.player
		check([player.hp,player.attack,player.defense,player.gold] == expected[id], "zero ember start " + id)
		unlocked.upgrades = {"hp":3,"attack":3,"gold":3}
		initial = P.initial_player(unlocked,id)
		player = initial.player
		check([player.hp,player.attack,player.defense,player.gold] == [expected[id][0]+15,expected[id][1]+3,expected[id][2],expected[id][3]+15], "embers once " + id)
		check(P.initial_player(unlocked,id) == initial, "repeat preview not additive")
	var bad := fresh.duplicate(true)
	bad.upgrades.hp = 4
	check(not P.initial_player(bad).ok, "invalid ember level")
	var baseline := {"enemies":{"normal":{"hp":31,"attack":10,"defense":2,"rank":"normal","gold_reward":8}, "elite":{"hp":65,"attack":18,"rank":"elite"}, "boss":{"hp":121,"attack":28,"rank":"boss","ability_id":"rage"}}, "shop":{"unchanged":42}}
	var copy := baseline.duplicate(true)
	var c0 := P.apply_challenge(baseline,"p3_c0")
	var c1 := P.apply_challenge(baseline,"p3_c1")
	var c2 := P.apply_challenge(baseline,"p3_c2")
	check(c0.content.enemies == baseline.enemies, "C0 baseline")
	check(c1.content.enemies.normal.hp == 35 and c1.content.enemies.normal.attack == 11 and c1.content.enemies.boss.hp == 121 and c1.content.enemies.boss.attack == 30, "C1 rounding and boss")
	check(c2.content.enemies.normal.hp == 36 and c2.content.enemies.normal.attack == 12 and c2.content.enemies.boss.hp == 134 and c2.content.enemies.boss.attack == 31, "C2 direct baseline")
	check(c2.content.enemies.normal.gold_reward == 8 and c2.content.shop == baseline.shop and c2.content.enemies.boss.ability_id == "rage", "resources and mechanics unchanged")
	check(baseline == copy, "challenge input untouched")
	check(not P.apply_challenge(c1.content,"p3_c2").ok, "reject stacking")
	check(not P.apply_challenge(baseline,"invalid").ok, "unknown challenge rejected")
	for source in ["shop","ruin","kill","max_hp","event"]:
		check(P.scale_heal(21,source,"p3_c2") == 21, "unscaled " + source)
	for source in ["potion","rest"]:
		for amount in [0,1,2,19,20,21]:
			check(P.scale_heal(amount,source,"p3_c2") == (maxi(1,floori(amount*0.8)) if amount>0 else 0), "heal floor/positive minimum")
		check(P.scale_heal(20,source,"p3_c1") == 20, "C1 healing baseline")
	check(P.scale_heal(-1,"rest","p3_c2") == -1 and P.scale_heal(1,"bad","p3_c0") == -1 and P.scale_heal(1,"rest","bad") == -1, "heal invalid sentinel")
	for value in [19,20]:
		var run := fixture()
		run.metrics.actual_kill_healing = value
		check(("p3_sustain_20" in run_test(run).new_achievements) == (value == 20), "heal 19/20")
	for value in [29,30]:
		var run := fixture()
		run.metrics.shop_gold_spent = value
		check(("p3_shop_30" in run_test(run).new_achievements) == (value == 30), "shop 29/30")
	for value in [99,100]:
		var run := fixture()
		run.player.gold = value
		check(("p3_reserve_100" in run_test(run).new_achievements) == (value == 100), "gold 99/100")
	for turns in [6,7]:
		var run := fixture()
		run.defeated_entities = [{"id":"f5-boss","enemy_id":"minotaur","rank":"boss","floor":5,"turns":turns,"incoming":20}]
		var candidate := run_test(run)
		check("p3_first_midboss" in candidate.new_achievements, "midboss survived kill")
		check(("p3_short_duel" in candidate.new_achievements) == (turns == 6), "midboss 6/7")
	for incoming in [10,11]:
		var run := fixture()
		run.defeated_entities = [{"id":"f4-elite","enemy_id":"berserker","rank":"elite","floor":4,"incoming":incoming}]
		check(("p3_low_loss_elite" in run_test(run).new_achievements) == (incoming == 10), "raw incoming 10/11")
	var full := fixture("complete-evidence")
	full.result = "victory"
	full.player.gold = 100
	full.metrics = {"actual_kill_healing":20,"shop_gold_spent":30,"midboss_turns":6,"lowest_elite_incoming":10}
	full.defeated_entities = [{"id":"f5-boss","enemy_id":"minotaur","rank":"boss","floor":5,"incoming":12}, {"id":"f4-elite","enemy_id":"berserker","rank":"elite","floor":4,"incoming":10}]
	for id in P.RUINS:
		full.codex_events.append({"event_id":id,"kind":"ruin_choice","id":id,"option_id":P.RUIN_OPTIONS[id][0]})
	full.codex_events.append({"event_id":"item-1","kind":"item_obtained","id":"iron_sword","source":"shop"})
	full.codex_events.append({"event_id":"story-1","kind":"story_seen","id":"arrived","triggered":true,"status":"skipped"})
	var settlement := run_test(full)
	check(settlement.new_achievements.size() == 9, "all C0 achievements evidenced")
	check(settlement.meta.codex.item_records.iron_sword.count == 1, "item counter")
	var again := P.evaluate_unlocks(full,settlement.meta)
	check(again.ok and again.meta == settlement.meta and again.new_achievements.is_empty() and again.new_unlocks.is_empty(), "duplicate settlement no mutation")
	var trimmed: Dictionary = settlement.meta.duplicate(true)
	trimmed.records = []
	check(P.evaluate_unlocks(full,trimmed).meta.codex == settlement.meta.codex, "trimmed recent records keep lifetime idempotency")
	trimmed.last_settled_run_id = "some-later-run"
	check(P.settlement_guard(full,trimmed).already_settled, "preflight blocks legacy reaward after 30-record trimming")
	check(not P.settlement_guard(fixture("fresh-id"),trimmed).already_settled, "new unique run passes preflight")
	var conflict := full.duplicate(true)
	conflict.result = "abandoned"
	check(not P.evaluate_unlocks(conflict,settlement.meta).ok, "conflicting result rejected")
	var abandoned := run_test(conflict)
	check(abandoned.new_achievements.is_empty() and abandoned.new_unlocks.is_empty(), "abandon all conditions yields no unlocks")
	var no_evidence := fixture()
	no_evidence.result = "victory"
	no_evidence.erase("meta_snapshot")
	no_evidence.erase("start_config_snapshot")
	no_evidence.metrics = {"midboss_turns":6,"lowest_elite_incoming":0}
	check(run_test(no_evidence).new_achievements == ["p3_c0_clear"], "missing battle/start proof never inferred")
	no_evidence.combat_rules_version = 1
	check(run_test(no_evidence).new_achievements.is_empty(), "legacy run no new metrics awards")
	no_evidence.combat_rules_version = 99
	check(not P.evaluate_unlocks(no_evidence,fresh).ok, "unknown combat version rejected")
	for challenge in ["p3_c1","p3_c2"]:
		var run := fixture(challenge)
		run.result = "victory"
		run.challenge_id = challenge
		var candidate := run_test(run)
		check(challenge + "_clear" in candidate.new_achievements, "challenge clear")
		check("p3_c0_clear" not in candidate.new_achievements, "does not infer lower clear")
	var dishonest := fixture()
	dishonest.codex_events = [{"event_id":"story","kind":"story_seen","id":"secret","triggered":false,"status":"skipped"}]
	check(not P.evaluate_unlocks(dishonest,fresh).ok, "untriggered story rejected")
	var malformed := fresh.duplicate(true)
	malformed.codex.seen_enemies = "wrong"
	check(not P.validate_meta_extensions(malformed).ok, "malformed codex")
	var catalog := {"enemies":baseline.enemies,"items":{"hidden":{"name":"SECRET_ITEM","description":"SECRET_EFFECT"}}, "story":{"secret":{"name":"SECRET_NAME","description":"SECRET_REVEAL"}}, "ruins":{}}
	for category in ["items","story"]:
		var visible := JSON.stringify(CodexPanel.view_rows(fresh,catalog,category))
		check("SECRET" not in visible, "undiscovered content redacted")
	var codex_copy: Dictionary = settlement.meta.duplicate(true)
	CodexPanel.view_rows(settlement.meta,catalog,"enemies","p3_c2")
	check(settlement.meta == codex_copy, "codex read-only")
	# The real old settlement owns currency and run counters. Compose on its candidate.
	var old_state := full.duplicate(true)
	old_state.seed = "42"
	old_state.story = {"queue":[], "seen":[]}
	var old_candidate := Old.settle(old_state, fresh, "victory")
	check(old_candidate.ok, "old settlement produces candidate")
	var composed := P.evaluate_unlocks(old_candidate.state, old_candidate.meta)
	check(composed.ok and composed.meta.souls == old_candidate.meta.souls and composed.meta.souls_earned_total == old_candidate.meta.souls_earned_total, "composition no second soul grant")
	check(composed.meta.runs == 1 and composed.meta.wins == 1, "composition no extra run/win")
	var repeated_old := Old.settle(old_candidate.state, composed.meta, "victory")
	var repeated_new := P.evaluate_unlocks(repeated_old.state, repeated_old.meta)
	check(repeated_new.ok and repeated_new.meta == composed.meta, "repeat complete pipeline no double reward")
	var restored: Dictionary = JSON.parse_string(JSON.stringify(composed.meta))
	check(P.validate_meta_extensions(restored).ok, "JSON/backup roundtrip validates")
	check(P.evaluate_unlocks(old_candidate.state,restored).meta == restored, "restored ledger blocks duplicate")
	var discovered := P.record_discoveries(fresh, full.run_id, full.codex_events)
	check(discovered.ok and discovered.meta.codex.item_records.iron_sword.count == 1, "live discovery candidate")
	var settled_live := P.evaluate_unlocks(full, discovered.meta)
	check(settled_live.ok and settled_live.meta.codex.item_records.iron_sword.count == 1, "settlement does not recount live discoveries")
	var post_story := [{"event_id":"ending-played","kind":"story_seen","id":"victory","triggered":true,"status":"completed"}]
	var after_story := P.record_discoveries(settled_live.meta, full.run_id, post_story)
	check(after_story.ok and "victory" in after_story.meta.codex.seen_story_nodes, "post-settlement story discovery")
	check(P.record_discoveries(after_story.meta,full.run_id,post_story).meta == after_story.meta, "post-settlement replay idempotent")
	post_story[0].status = "skipped"
	check(not P.record_discoveries(after_story.meta,full.run_id,post_story).ok, "conflicting same event rejected")
	var next_run := full.duplicate(true)
	next_run.run_id = "independent-retry"
	next_run.challenge_id = "p3_c1"
	var next_result := P.evaluate_unlocks(next_run,settlement.meta)
	check(next_result.meta.codex.enemy_records.has("minotaur|2|p3_c0") and next_result.meta.codex.enemy_records.has("minotaur|2|p3_c1"), "difficulty records remain separate")
	check(next_result.meta.codex.item_records.iron_sword.count == 2, "new run increments lifetime item counts")
	check(next_result.new_achievements == ["p3_c1_clear"], "existing achievements do not regrant")
	var no_damage_sample := fixture("missing-sample")
	no_damage_sample.defeated_entities = [{"id":"f4-elite","enemy_id":"berserker","rank":"elite","floor":4}]
	var count_only := run_test(no_damage_sample)
	check(count_only.meta.codex.enemy_records["berserker|2|p3_c0"].count == 1 and count_only.meta.codex.enemy_records["berserker|2|p3_c0"].samples == 0, "kill count without invented damage")
	for key in ["actual_kill_healing","shop_gold_spent","midboss_turns","lowest_elite_incoming"]:
		for invalid in [-1, 1.5, "20", true, INF, NAN]:
			var invalid_run := fixture()
			invalid_run.metrics[key] = invalid
			check(not P.evaluate_unlocks(invalid_run,fresh).ok, "invalid numeric evidence " + key)
	var early_gold := fixture()
	early_gold.player.gold = 100
	early_gold.floor = 4
	check("p3_reserve_100" not in run_test(early_gold).new_achievements, "gold needs floor 5")
	var leave_ruin := full.duplicate(true)
	leave_ruin.codex_events[0].option_id = "leave"
	check("p3_three_ruins" not in run_test(leave_ruin).new_achievements, "leaving not using ruin")
	var wrong_choice := full.duplicate(true)
	wrong_choice.codex_events[0].option_id = "unknown"
	check(not P.evaluate_unlocks(wrong_choice,fresh).ok, "unknown ruin option rejected")
	var same_event := full.duplicate(true)
	same_event.codex_events.append(same_event.codex_events[3].duplicate(true))
	check(P.evaluate_unlocks(same_event,fresh).meta.codex.item_records.iron_sword.count == 1, "duplicate event id counted once")
	for key in ["player","floors","challenge_snapshot","start_config_snapshot","meta_snapshot"]:
		var invalid_run := fixture()
		invalid_run[key] = "wrong"
		check(not P.evaluate_unlocks(invalid_run,fresh).ok, "invalid run container " + key)
	var definitions := P.definitions()
	var selection := P.select_start(fresh,"p3_c0","default",definitions)
	selection.start_config_snapshot.hp_delta = 88
	selection.unlocked_pool_snapshot.append("test")
	check(definitions.challenges.start_configs.default.hp_delta == 0 and "test" not in fresh.unlocked_ids, "snapshots detached from definitions/account")
	for id in ["p3_c0","p3_c1","p3_c2","default","p3_vanguard","p3_keeper","p3_trader"]:
		var badge := Image.load_from_file("res://assets/ui/phase3/progression/%s.png" % id)
		check(badge != null and badge.get_size() == Vector2i(128,128) and badge.get_format() == Image.FORMAT_RGBA8, "RGBA badge " + id)
		check(badge.get_pixel(0,0).a == 0, "transparent badge " + id)
	var panel := ChallengePanel.new()
	root.add_child(panel)
	panel.setup(fresh)
	check(not panel.select_ids("p3_c2","p3_keeper").ok, "panel rejects unavailable selection")
	check(panel.selection.player.hp == 100, "panel displays actual player")
	panel.queue_free()
	print("PHASE3_PROGRESS_TEST checks=%d failures=%d" % [checks,failures])
	quit(1 if failures else 0)
