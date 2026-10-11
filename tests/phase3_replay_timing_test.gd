extends SceneTree
const Combat = preload("res://scripts/core/phase3_combat.gd")
const Player = preload("res://scripts/ui/phase3_combat_player.gd")
var checks := 0
var failures := 0

func check(condition: bool, label: String) -> void:
	checks += 1
	if not condition:
		failures += 1
		push_error("FAIL " + label)

func _initialize() -> void:
	var isolated := ProjectSettings.globalize_path("user://").replace("\\", "/")
	if not (isolated.contains("phase3/06-animation-balance/") or isolated.contains("phase3/08-parallel/coordinator/")):
		quit(2)
		return
	_run.call_deferred()

func _run() -> void:
	var stats := {"attack":63,"defense":50,"max_hp":100,"kill_heal":0,"gold_bonus":0,"combat_effects":[
		{"id":"retaliation","amount":2,"charges":3,"source_item_id":"p3_thorn_clasp"},
		{"id":"counter_guard","amount":2,"charges":2,"source_item_id":"p3_lantern_aegis"}]}
	var golem := {"id":"golem","hp":250,"attack":28,"defense":14,"ability_id":"stone_armor","gold_reward":120}
	var report := Combat.simulate({"hp":100},golem,stats)
	var original := report.duplicate(true)
	var plan := Player.build_plan(report,"boss")
	var first: Array = plan.cues.filter(func(c): return c.turn == 1)
	check(first.map(func(c): return c.kind) == ["prepare","attack","guard","counter","retaliation","mechanism"], "49 hit then 2 retaliation crosses 50: armor strictly after retaliation")
	check(first[-1].effects[0].id == "stone_armor" and first[-1].effects[0].amount == 2, "actual armor increment preserved")
	check(first[2].amount == 0, "zero-benefit guard consumption retained without fake benefit")
	check(Player.sound_for_cue(first[2]).is_empty(), "zero-benefit guard has no benefit sound")
	check(Player.sound_for_cue(first[4]) == "hit", "actual retaliation uses existing shipped impact audio")
	check(report == original, "timeline does not mutate report")
	stats.combat_effects = []
	stats.attack = 115
	var multi := Combat.simulate({"hp":100},golem,stats)
	var multi_plan := Player.build_plan(multi,"boss")
	check(multi_plan.cues[2].kind == "mechanism" and multi_plan.cues[2].effects[0].amount == 4, "101 hit crosses two armor thresholds before counter")
	stats.attack = 28
	var rage := Combat.simulate({"hp":100},{"id":"minotaur","hp":120,"attack":18,"defense":8,"ability_id":"rage","gold_reward":65},stats)
	var rage_plan := Player.build_plan(rage,"boss")
	var third: Array = rage_plan.cues.filter(func(c): return c.turn == 3)
	check(third.map(func(c): return c.kind) == ["prepare","attack","mechanism","counter"], "rage before third counter")
	check(third[3].at-third[2].at >= .25 and rage_plan.duration <= 6,"boss mechanism readable before contact within six-second budget")
	check(rage_plan.cues.filter(func(c): return c.turn == 6).size() == 2, "fatal sixth strike has no rage or counter")
	stats.attack = 1000
	var direct := Combat.simulate({"hp":100},golem,stats)
	check(Player.build_plan(direct).cues[1].amount == 250, "overkill label uses actual HP loss")
	var player := Player.new()
	check(not player.configure(report,false).ok, "uncommitted report rejected")
	check(player.configure(report,true,{"enemy_id":"golem"}).ok,"committed replay configures")
	root.add_child(player)
	player.set_process(false)
	await process_frame
	check(player._enemy_sprite.texture != null,"production enemy visible")
	player._notification(MainLoop.NOTIFICATION_APPLICATION_FOCUS_OUT)
	player.advance(10)
	check(player._cursor == 0,"focus loss pauses timeline")
	player._notification(MainLoop.NOTIFICATION_APPLICATION_FOCUS_IN)
	player.set_paused(true)
	player._notification(MainLoop.NOTIFICATION_APPLICATION_FOCUS_OUT)
	player._notification(MainLoop.NOTIFICATION_APPLICATION_FOCUS_IN)
	player.advance(10)
	check(player._cursor == 0,"focus return cannot undo explicit pause")
	player.set_paused(false)
	player.advance(0.4)
	check(player._cursor > 0,"focus return resumes")
	check("石甲" in player._cue.text,"mechanism remains readable after following cues in same rendered frame")
	player.set_reduce_motion(true)
	check(player._finished and not player._sprite.get_parent().visible,"reduced motion hides both actors and shows settlement")
	player.skip()
	player.close()
	check(player.full_report() == original,"skip close reduced mode preserve committed result")
	player.queue_free()
	await process_frame
	print("Replay timing: %d checks, %d failures" % [checks,failures])
	quit(0 if failures == 0 else 1)
