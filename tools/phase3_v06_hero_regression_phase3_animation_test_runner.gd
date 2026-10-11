extends SceneTree
const Tutorial = preload("res://scripts/ui/phase3_tutorial.gd")
const Catalog = preload("res://scripts/ui/phase3_animation_catalog.gd")
const Player = preload("res://scripts/ui/phase3_combat_player.gd")
const Fixture = preload("res://tests/phase3_animation_fixture.gd")
var checks: Array[Dictionary] = []
var failed := 0
var emitted: Array = []
var cues: Array = []

func _initialize() -> void:
	_run.call_deferred()

func check(value: bool, label: String) -> void:
	checks.append({"name": label, "passed": value})
	if not value:
		failed += 1
		push_error(label)

func _run() -> void:
	check(("05-animation" in OS.get_environment("APPDATA") and "05-animation" in OS.get_environment("LOCALAPPDATA")) or ("08-parallel\\hero_refine" in OS.get_environment("APPDATA") and "08-parallel\\hero_refine" in OS.get_environment("LOCALAPPDATA")), "isolated profile")
	if failed: quit(1); return
	_tutorial()
	_catalog()
	_combat()
	_production_reports()
	await _components()
	var result := {"checks": checks, "passed": checks.size() - failed, "failed": failed, "godot": Engine.get_version_info().string, "user_data": OS.get_user_data_dir()}
	var output := FileAccess.open("res://build/verification/phase3/09-refinement/hero/regression/validation.json", FileAccess.WRITE)
	output.store_string(JSON.stringify(result, "\t"))
	print("PHASE3_05: %d passed, %d failed" % [checks.size() - failed, failed])
	quit(1 if failed else 0)

func _tutorial() -> void:
	var state := Tutorial.initial_state()
	var original := state.duplicate(true)
	state = Tutorial.reduce(state, {"type": "floor_entered", "floor": 1, "new_run": true}).state
	check(state.active == "T01" and original == Tutorial.initial_state(), "tutorial trigger is immutable")
	state = Tutorial.reduce(state, {"type": "move_succeeded", "committed": false}).state
	check(state.nodes.T01.status == "shown", "failed transaction cannot teach movement")
	state = Tutorial.reduce(state, {"type": "dismiss", "id": "T01"}).state
	check(state.nodes.T01.status == "dismissed", "dismiss is not completion")
	state = Tutorial.reduce(state, {"type": "move_succeeded", "committed": true}).state
	check(state.nodes.T01.status == "completed", "actual evidence completes dismissed lesson")
	state = Tutorial.reduce(state, {"type": "enemy_viewed", "floor": 1, "enemy_id": "knight", "lethal": true}, {"story_queued": true}).state
	check(state.active == "" and state.nodes.T02.status == "deferred" and state.nodes.T07.triggered, "story priority defers multiple lessons")
	state = Tutorial.reduce(state, {"type": "context_changed"}).state
	check(state.active == "T02" and state.nodes.T07.status == "deferred", "only one active tutorial")
	state = Tutorial.reduce(state, {"type": "enemy_preview_closed", "viewed_full": false}).state
	check(state.nodes.T02.status != "completed", "partial preview does not complete T02")
	state = Tutorial.reduce(state, {"type": "enemy_preview_closed", "viewed_full": true}).state
	check(state.nodes.T02.status == "completed", "full preview cancellation completes T02")
	state = Tutorial.reduce(state, {"type": "equipment_received", "committed": true}).state
	check(state.nodes.T03.status == "deferred", "comparison defers without discovered enemy")
	state = Tutorial.reduce(state, {"type": "comparison_viewed", "discovered": true, "same_enemy": true}).state
	check(state.nodes.T03.status == "completed", "same enemy comparison completes T03")
	for sequence in [
		[{"type": "door_viewed"}, {"type": "door_explanation_closed"}, "T04"],
		[{"type": "potion_viewed"}, {"type": "potion_retained"}, "T05"],
		[{"type": "ruin_viewed", "ruin_id": "p3_oath_ruin"}, {"type": "ruin_left", "ruin_id": "p3_oath_ruin"}, "T06"],
		[{"type": "enemy_viewed", "enemy_id": "knight", "floor": 1, "lethal": true}, {"type": "target_mark_declined"}, "T07"],
		[{"type": "result_viewed"}, {"type": "camp_embers_viewed"}, "T08"]]:
		state = Tutorial.reduce(state, sequence[0]).state
		state = Tutorial.reduce(state, sequence[1]).state
		check(state.nodes[sequence[2]].status == "completed", "evidence completes " + sequence[2])
	check(Tutorial.reduce(state, {"type": "floor_entered", "floor": 1, "new_run": true}).state.active == "", "completed lessons do not replay")
	state = Tutorial.reduce(state, {"type": "reset"}).state
	check(state == Tutorial.initial_state(), "reset touches tutorial state only")
	state = Tutorial.reduce(state, {"type": "skip_all"}).state
	check(not state.enabled and Tutorial.reduce(state, {"type": "floor_entered", "floor": 1, "new_run": true}).state.active == "", "skip all persists")
	check(Tutorial.restore(Tutorial.snapshot(state)).ok and not Tutorial.restore({"version": 2}).ok, "versioned tutorial restore")
	state = Tutorial.reduce(Tutorial.initial_state(), {"type": "enemy_viewed", "enemy_id": "knight", "floor": 1, "lethal": false}).state
	check(state.nodes.T07.status == "skipped", "safe knight bypasses lethal-target lesson")
	state = Tutorial.reduce(Tutorial.initial_state(), {"type": "potion_viewed"}, {"full_hp": true}).state
	check("溢出" in Tutorial.prompt(state, {"full_hp": true}).text, "full-health potion explains overflow")
	state = Tutorial.reduce(Tutorial.initial_state(), {"type": "result_viewed"}, {"trial": true}).state
	check(not "灵魂" in Tutorial.prompt(state, {"trial": true}).text, "trial never promises souls")
	for blocker in Tutorial.BLOCKERS:
		check(Tutorial.reduce(state, {}, {blocker: true}).prompt.is_empty(), "priority blocker: " + blocker)

func _catalog() -> void:
	var loaded := Catalog.read_manifest()
	check(loaded.ok and loaded.get("complete",false), "complete production hero manifest: " + loaded.get("error", ""))
	if not loaded.ok: return
	check(Catalog.validate(loaded.manifest, true).ok, "strict complete hero validation")
	var incomplete: Dictionary = loaded.manifest.duplicate(true)
	incomplete.actions.erase("combat_attack")
	check(not Catalog.validate(incomplete,true).ok, "strict manifest rejects missing actions")
	var catalog := Catalog.new()
	check(catalog.configure(loaded.manifest).ok, "catalog configuration")
	for direction in Catalog.DIRECTIONS:
		var frame := catalog.frame_at("map_walk_" + direction, 0.4)
		check(frame.ok and not frame.fallback and frame.texture != null and frame.anchor == Vector2(64, 116), "accepted independent map walk " + direction)
	check(catalog.cache_bytes == 4 * 128 * 128 * 4, "measured fallback cache bytes")
	var baked := catalog.sprite_frames("map_walk_down")
	check(baked.ok and not baked.fallback and baked.frames.get_frame_count("map_walk_down") == 6, "accepted six-frame SpriteFrames walk")
	var fallback_catalog := Catalog.new()
	check(fallback_catalog.configure({"version":1,"handedness":"right_sword_left_lantern","mirrored":false,"actions":{}}).ok, "empty optional catalog allowed")
	check(fallback_catalog.frame_at("map_walk_down",.4).fallback, "missing accepted action retains static fallback")
	catalog.max_cache_bytes = 65536
	catalog.clear_cache()
	catalog.frame_at("map_walk_down", 0)
	catalog.frame_at("map_walk_up", 0)
	check(catalog.cache_bytes <= catalog.max_cache_bytes, "bounded texture cache evicts")
	var spec: Dictionary = Catalog.specifications().combat_attack
	var action := {"status": "accepted", "fps": 16, "loop": false, "size": spec.size, "anchor": spec.anchor, "source": "fixture", "review": "fixture only", "events": {"hit": 3}, "frames": []}
	for index in 8: action.frames.append(Catalog.ROOT + "textures/fixture_%02d.png" % index)
	var data: Dictionary = loaded.manifest.duplicate(true)
	data.actions.combat_attack = action
	check(Catalog.validate(data, false, false).ok, "valid eight-frame manifest fixture")
	check(not Catalog.validate(data).ok, "missing files rejected")
	var held: Dictionary = data.duplicate(true)
	held.actions.combat_attack.pose_holds = {"7":0}
	check(Catalog.validate(held,false,false).ok, "explicit non-loop return-pose hold allowed")
	held.actions.combat_attack.pose_holds = {"2":3}
	check(not Catalog.validate(held,false,false).ok, "hold cannot refer to future pose")
	held = loaded.manifest.duplicate(true)
	held.actions.map_walk_down.pose_holds = {"5":0}
	check(not Catalog.validate(held,false,false).ok, "cannot pad walk cycle with declared holds")
	for mutation in ["fps", "loop", "anchor", "event", "duplicate", "path", "draft"]:
		var bad: Dictionary = data.duplicate(true)
		match mutation:
			"fps": bad.actions.combat_attack.fps = 0
			"loop": bad.actions.combat_attack.loop = true
			"anchor": bad.actions.combat_attack.anchor = [0, 0]
			"event": bad.actions.combat_attack.events.hit = 8
			"duplicate": bad.actions.combat_attack.frames[1] = bad.actions.combat_attack.frames[0]
			"path": bad.actions.combat_attack.frames[0] = "res://outside.png"
			"draft": bad.actions.combat_attack.status = "draft"
		check(not Catalog.validate(bad, false, false).ok, "manifest rejects " + mutation)
	data.mirrored = true
	check(not Catalog.validate(data, false, false).ok, "mirroring rejected")
	# Synthetic decoder fixtures in evidence only, never production art/manifest.
	var decoder_action := {"fps": 6, "loop": true, "size": [128, 128], "anchor": [64, 116], "frames": []}
	for index in 4:
		var img := Image.create(128, 128, false, Image.FORMAT_RGBA8)
		img.fill(Color.TRANSPARENT)
		img.set_pixel(index, 1, Color.RED)
		var path := "res://build/verification/phase3/09-refinement/hero/regression/decoder_fixture_%d.png" % index
		img.save_png(path)
		decoder_action.frames.append(path)
	catalog.manifest = {"actions": {"map_idle_down": decoder_action}}
	var loaded_frame := catalog.frame_at("map_idle_down", 0.51)
	check(loaded_frame.ok and not loaded_frame.fallback and loaded_frame.frame == 3, "raw PNG decoding and FPS index")
	check(catalog.frame_at("map_idle_down", 0.7).frame == 0, "loop wraps")
	check(catalog.frame_at("map_idle_down", 0.51, true).frame == 0, "reduced frame locks at zero")
	catalog.manifest.actions.map_idle_down.loop = false
	check(catalog.frame_at("map_idle_down", 20).frame == 3, "one-shot clamps to final frame")
	catalog.manifest.actions.map_idle_down.frames[0] = "res://missing.png"
	check(catalog.frame_at("map_idle_down", 0).fallback, "missing frame at runtime falls back")
	_acceptance_gate(loaded.manifest)

func _acceptance_gate(base: Dictionary) -> void:
	# Temporary diagnostic pixels only; ignored and removed after the gate tests.
	var directory := Catalog.ROOT + "textures/_verification"
	DirAccess.make_dir_recursive_absolute(ProjectSettings.globalize_path(directory))
	var ignored := FileAccess.open(directory + "/.gdignore", FileAccess.WRITE)
	ignored.close()
	var action := {"status": "accepted", "fps": 6, "loop": true, "size": [128, 128], "anchor": [64, 116], "source": "synthetic test fixture", "review": "not art", "events": {}, "frames": []}
	for index in 4:
		var path := directory + "/fixture_%d.png" % index
		var img := Image.create(128, 128, false, Image.FORMAT_RGBA8)
		img.fill(Color.TRANSPARENT)
		img.set_pixel(64 + index, 64, Color.RED)
		img.save_png(path)
		action.frames.append(path)
	var manifest := base.duplicate(true)
	manifest.actions.map_idle_down = action
	check(Catalog.validate(manifest).ok, "acceptance gate decodes dimensioned RGBA frames")
	var repeated := Image.load_from_file(action.frames[0])
	repeated.save_png(action.frames[1])
	check(not Catalog.validate(manifest).ok, "identical pixels under distinct paths rejected")
	var opaque := Image.create(128, 128, false, Image.FORMAT_RGBA8)
	opaque.fill(Color.RED)
	opaque.save_png(action.frames[1])
	check(not Catalog.validate(manifest).ok, "opaque image rejected")
	var wrong := Image.create(16, 16, false, Image.FORMAT_RGBA8)
	wrong.fill(Color.TRANSPARENT)
	wrong.save_png(action.frames[1])
	check(not Catalog.validate(manifest).ok, "wrong physical dimensions rejected")
	for path in action.frames: DirAccess.remove_absolute(ProjectSettings.globalize_path(path))

func _combat() -> void:
	var report := Fixture.report()
	var original := report.duplicate(true)
	var sample := Player.choose_turns(report)
	check(sample.ok and sample.indices.size() == 6 and 11 in sample.indices, "six real turns including final retaliation")
	check(1 in sample.indices and 2 in sample.indices and 4 in sample.indices, "first mechanism turns prioritized")
	check(report == original and report.log.size() == 12, "sampling preserves complete report")
	var plan := Player.build_plan(report)
	var last: Array = []
	for cue in plan.cues:
		if cue.turn == 12: last.append(cue.kind)
	check(last == ["prepare", "attack", "counter", "retaliation"], "retaliation kill exact order, no phantom attack")
	check(plan.duration >= 1.2 and plan.duration <= 3.0 and plan.omitted_turns == 7, "normal replay time budget and omitted count")
	check(Player.build_plan(report, "elite").duration <= 4 and Player.build_plan(report, "boss").duration <= 6, "elite and boss time budgets")
	check(is_equal_approx(plan.cues[1].at, 3.0 / 16.0), "attack impact uses source frame 3 at 16 FPS")
	var crowded := report.duplicate(true)
	for index in 10:
		crowded.log[index].effect_events.append({"id": "fixture_mechanism_%d" % index, "amount": index})
	check(not Player.build_plan(crowded).omitted_mechanisms.is_empty(), "omitted mechanisms have explicit summary data")
	var reduced := Player.build_plan(report, "normal", true)
	check(reduced.cues.is_empty() and reduced.duration == 0 and reduced.result == plan.result, "reduced motion same final resources")
	var direct := Player.build_plan(Fixture.report(1, false))
	check(direct.cues.size() == 2 and direct.cues[1].kind == "attack", "one-hit kill has no counter")
	check("第12回合" in Player.report_text(report) and "荆棘反伤" in Player.report_text(report), "complete readable log and silent mechanism labels")
	var legacy := report.duplicate(true)
	legacy.erase("min_hp")
	check(Player.final_result(legacy).min_hp == report.min_hp, "legacy minimum HP derives from pre-healing log")
	legacy.effects_triggered = "invalid"
	check(not Player.validate_report(legacy).ok, "aggregate effects must be structured events")
	for invalid in ["turn", "counter", "effect"]:
		var bad := report.duplicate(true)
		match invalid:
			"turn": bad.log[0].turn = 2
			"counter": bad.log[0].counter = -1
			"effect": bad.log[1].effect_events = ["bad"]
		check(not Player.validate_report(bad).ok, "reject malformed report " + invalid)

func _production_reports() -> void:
	var path := "res://scripts/core/phase3_combat.gd"
	if not FileAccess.file_exists(path):
		print("Production report integration pending; protocol fixtures ran.")
		return
	var combat: Script = load(path)
	var stats := {"attack": 8, "defense": 3, "max_hp": 100, "kill_heal": 3, "gold_bonus": 0, "combat_effects": [
		{"id": "retaliation", "amount": 2, "charges": 3, "source_item_id": "p3_thorn_clasp"},
		{"id": "counter_guard", "amount": 2, "charges": 2, "source_item_id": "p3_lantern_aegis"}]}
	for ability in ["", "rage", "stone_armor", "p3_shield", "p3_ember", "p3_ambush"]:
		var enemy := {"id": "fixture", "hp": 30, "attack": 7, "defense": 2, "gold_reward": 5, "ability_id": ability}
		var real: Dictionary = combat.simulate({"hp": 100}, enemy, stats)
		var before := real.duplicate(true)
		check(real.ok and Player.build_plan(real).ok and real == before, "real producer report accepted without mutation: " + ability)
	var retaliation: Dictionary = combat.simulate({"hp": 100}, {"hp": 8, "attack": 7, "defense": 2}, stats)
	var real_plan := Player.build_plan(retaliation)
	check(real_plan.ok and real_plan.cues[-1].kind == "retaliation" and retaliation.turns == 1, "real producer retaliation kill preserved")

func _components() -> void:
	var report := Fixture.report()
	var player := Player.new()
	check(not player.configure(report, false).ok, "save failure blocks playback")
	player.playback_finished.connect(func(result): emitted.append(result))
	player.cue_presented.connect(func(cue): cues.append(cue))
	check(player.configure(report, true).ok, "committed replay starts")
	root.add_child(player)
	player.set_process(false)
	await process_frame
	player.set_paused(true)
	player.advance(9)
	check(cues.is_empty(), "pause cannot advance")
	player.set_paused(false)
	player.advance(0.2)
	check(not cues.is_empty(), "manual replay advancement")
	player.skip()
	player.skip()
	player.close()
	check(emitted.size() == 1 and emitted[0] == Player.final_result(report), "skip/close finish exactly once")
	var external := player.full_report()
	external.hp_after = 0
	check(player.full_report().hp_after == report.hp_after, "report accessor does not leak mutable state")
	player.queue_free()
	var prompt := Tutorial.create_prompt({"id": "T01", "text": Tutorial.COPY.T01})
	root.add_child(prompt)
	await process_frame
	check(prompt.focus_mode == Control.FOCUS_NONE and prompt.get_child(0).get_child(1).get_child(0).custom_minimum_size.y >= 44, "nonmodal prompt no focus theft and touch sizing")
	prompt.queue_free()
	await process_frame

