extends SceneTree
## Encounter setup must not decode every animation before the first visible frame.
const Hero = preload("res://scripts/ui/phase3_animation_catalog.gd")
const Enemy = preload("res://assets/monsters/phase3/phase3_enemy_animation_catalog.gd")
const Replay = preload("res://scripts/ui/phase3_combat_player.gd")
const Combat = preload("res://scripts/core/phase3_combat.gd")
var failures := 0
var checks := 0

func check(value: bool, label: String) -> void:
	checks += 1
	if not value:
		failures += 1
		push_error("FAIL " + label)

func _initialize() -> void:
	_run.call_deferred()

func _run() -> void:
	var metadata := Hero.read_manifest(Hero.DEFAULT_MANIFEST, false)
	check(metadata.ok, "shipped hero metadata remains valid")
	if not metadata.ok:
		quit(1)
		return
	var previously_loaded := {}
	for action in metadata.manifest.actions.values():
		for channel in ["frames", "effects_frames"]:
			for path in action.get(channel, []):
				previously_loaded[path] = ResourceLoader.has_cached(path)
	var report := Combat.simulate({"hp":500}, {"id":"slime","hp":100,"attack":12,"defense":0,"gold_reward":3}, {"attack":25,"defense":2,"max_hp":500,"kill_heal":0,"gold_bonus":0})
	var original := report.duplicate(true)
	for id in ["slime", "golem", "slime"]:
		var start := Time.get_ticks_usec()
		var replay := Replay.new()
		check(replay.configure(report, true, {"enemy_id":id}).ok, "encounter configures: " + id)
		var setup_ms := (Time.get_ticks_usec()-start)/1000.0
		print("ENCOUNTER_SETUP %s %.3f ms" % [id, setup_ms])
		# Generous margin over the measured 1-6 ms metadata path; the old full
		# image scans took 400+ ms even after the OS file cache was warm.
		check(setup_ms < 150.0, "encounter setup stays below 150 ms: " + id)
		for path in previously_loaded:
			check(ResourceLoader.has_cached(path) == previously_loaded[path], "setup does not retain invisible hero frame: " + path)
		check(replay._enemy_player.cache_bytes == 0, "enemy setup stays metadata-only")
		replay.free()
	check(report == original, "loading never changes committed combat")
	var hero := Hero.new()
	check(hero.configure_runtime().ok, "map hero runtime configures")
	hero.manifest.actions.combat_attack.frames[0] = Hero.ROOT + "textures/missing_runtime_frame.png"
	check(hero.frame_at("combat_attack", 0).fallback, "missing runtime body still falls back")
	var fresh := Hero.new()
	check(fresh.configure_runtime().ok and not fresh.frame_at("combat_attack", 0).fallback, "a player cannot poison the shared hero metadata")
	var action := Enemy.describe_action("slime", "attack")
	check(action.ok, "enemy metadata loads")
	action.action.frames[0] = "res://missing.png"
	check(Enemy.describe_action("slime", "attack").action.frames[0] != "res://missing.png", "enemy metadata callers remain isolated")
	check(not Enemy.describe_action("slime", "missing_action").ok, "missing enemy action remains rejected")
	# The offline acceptance gate must still inspect real files by default.
	check(not Hero.validate(hero.manifest).ok, "strict validation still rejects missing pixels")
	print("COMBAT_LOADING: %d checks, %d failures" % [checks, failures])
	quit(1 if failures else 0)
