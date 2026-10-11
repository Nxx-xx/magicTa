extends SceneTree
## Production coverage and committed replay checks, not visual approval.
const Catalog = preload("res://assets/monsters/phase3/phase3_enemy_animation_catalog.gd")
const Visual = preload("res://scripts/ui/phase3_enemy_player.gd")
const MapArt = preload("res://scripts/ui/phase3_enemy_map_art.gd")
const Replay = preload("res://scripts/ui/phase3_combat_player.gd")
const Combat = preload("res://scripts/core/phase3_combat.gd")
const IDS = ["slime","skeleton","bat","sentinel","warlock","knight","berserker","warden","minotaur","golem","p3_shield_sentinel","p3_ember_channeler","p3_vault_knight"]
const SPECIALS = {"p3_shield_sentinel":"guard","p3_ember_channeler":"charge","p3_vault_knight":"threat"}
const OUT = "res://build/verification/phase3/09-refinement/golem/"
var checks := 0
var failures := 0
var summary: Array = []

func check(value: bool, label: String) -> void:
	checks += 1
	if not value:
		failures += 1
		push_error("FAIL "+label)

func _initialize() -> void:
	if not ProjectSettings.globalize_path("user://").replace("\\","/").contains("08-parallel/golem_refine/"):
		quit(2)
		return
	_run.call_deferred()

func _run() -> void:
	var map_art := MapArt.new()
	var visual := Visual.new()
	var old_texture: WeakRef
	for enemy in IDS:
		visual.configure(enemy,{})
		check(visual.cache_bytes == 0,"opponent configure is metadata-only: "+enemy)
		if old_texture != null: check(old_texture.get_ref() == null,"opponent switch releases previous decoded frame: "+enemy)
		var names := ["idle","attack","hit","defeat"]
		if enemy == "minotaur": names.append("rage")
		if enemy == "golem": names.append("armor")
		if SPECIALS.has(enemy): names.append(SPECIALS[enemy])
		var slots := 0
		var decoded_bytes := 0
		for action_name in names:
			var result := Catalog.describe_action(enemy,action_name)
			check(result.ok,"accepted combat metadata: "+enemy+"/"+action_name)
			if not result.ok: continue
			var action: Dictionary = result.action
			if enemy not in ["slime","minotaur","golem"]:
				var elite: bool = enemy in ["berserker","warden"]
				var expected: int = 4 if action_name in ["idle","guard","charge","threat"] else (8 if elite else 6) if action_name in ["attack","defeat"] else (3 if elite else 2)
				check(action.frames.size() == expected,"prescribed frame count: "+enemy+"/"+action_name)
				check(Vector2(action.size[0],action.size[1]) == Vector2(256,256),"256 runtime combat: "+enemy)
			for channel in ["frames","effects_frames"]:
				if not action.has(channel): continue
				var sampled := action.duplicate(true)
				sampled.frames = action[channel]
				for index in sampled.frames.size():
					var texture: Texture2D = visual._texture(sampled,index)
					check(texture != null,"production decoded frame: "+enemy+"/"+action_name+"/"+channel+str(index))
					if texture == null: continue
					var image := texture.get_image()
					check(image.detect_alpha() != Image.ALPHA_NONE,"transparent runtime pixels: "+enemy)
					decoded_bytes += image.get_data_size()
					check(visual.cache_bytes <= 8*1024*1024,"actual enemy image-data LRU <=8MiB")
					old_texture = weakref(texture)
			slots += action.frames.size()
		var map_result := Catalog.describe_action(enemy,"map_idle")
		check(map_result.ok,"accepted independent map: "+enemy)
		if map_result.ok:
			check(Vector2(map_result.action.size[0],map_result.action.size[1]) == Vector2(256,256) and Vector2(map_result.action.anchor[0],map_result.action.anchor[1]) == Vector2(128,224),"fixed map registration: "+enemy)
			check(map_result.action.frames.size() == 4 and float(map_result.action.fps) == (8.0 if enemy == "bat" else 6.0),"map timeline: "+enemy)
			var initial := map_art.texture(enemy,0)
			check(initial != null and map_art.texture(enemy,.8,true) == initial,"map reduced motion holds initial: "+enemy)
			for frame in 4:
				check(map_art.texture(enemy,float(frame)/float(map_result.action.fps)) != null,"map advance: "+enemy)
				check(map_art.frames.cache_bytes <= 4*1024*1024,"actual map image-data LRU <=4MiB")
		summary.append({"enemy":enemy,"combat_slots":slots,"traversed_image_data_bytes":decoded_bytes,"enemy_cache_peak_bytes":visual.peak_cache_bytes,"map_cache_bytes":map_art.frames.cache_bytes})
	visual.release_frames()
	map_art.clear()
	check(visual.cache_bytes == 0 and map_art.frames.cache_bytes == 0,"all enemy/map residency released")
	var variants: Dictionary = JSON.parse_string(FileAccess.get_file_as_string("res://data/phase3_enemies.json")).enemies
	for enemy in SPECIALS:
		var stats := {"attack":16,"defense":35,"max_hp":200,"kill_heal":0,"gold_bonus":0,"combat_effects":[]}
		var report := Combat.simulate({"hp":200},variants[enemy],stats)
		var original := report.duplicate(true)
		var plan := Replay.build_plan(report)
		visual.configure(enemy,plan)
		var found := false
		for cue in plan.cues:
			for effect in cue.get("effects",[]):
				if effect.get("id") != variants[enemy].ability_id: continue
				var sample_time: float = float(cue.at)-.08 if cue.kind == "counter" else float(cue.at)+.03
				var displayed := visual.frame_at(sample_time)
				if displayed.action != SPECIALS[enemy]: continue
				found = true
				check(displayed.texture != null,"committed mechanism has body: "+enemy)
				visual.effects_enabled = false
				var body_only := visual.frame_at(sample_time)
				check(body_only.texture == displayed.texture and body_only.effects_texture == null,"attachment survives FX-off: "+enemy)
				visual.effects_enabled = true
				var reduced := visual.frame_at(sample_time,false,false,true)
				check(reduced.action == "idle" and reduced.effects_texture == null,"mechanism reduced motion: "+enemy)
		check(found,"actual report selects variant mechanism: "+enemy)
		var host := Replay.new()
		check(not host.configure(report,false,{"enemy_id":enemy}).ok,"uncommitted report refuses playback: "+enemy)
		check(host.configure(report,true,{"enemy_id":enemy}).ok,"committed report accepts playback: "+enemy)
		root.add_child(host)
		host.size = Vector2(540,760)
		host.set_process(false)
		host.advance(.5)
		host.set_paused(true)
		var stopped: float = host._elapsed
		host.advance(1)
		check(host._elapsed == stopped,"variant pause preserves playback: "+enemy)
		host.set_paused(false)
		host.skip()
		check(host.full_report() == original and report == original,"variant skip/read-only report unchanged: "+enemy)
		host.queue_free()
		await process_frame
	FileAccess.open(OUT+"production-animation-results.json",FileAccess.WRITE).store_string(JSON.stringify({"checks":checks,"failures":failures,"coverage":summary,"measurement":"actual per-cache image data, not PNG sizes or renderer total","fixture_scope":"production textures and committed in-memory reports; not human/device acceptance"},"\t"))
	print("v05 production animation: %d checks, %d failures" % [checks,failures])
	quit(0 if failures == 0 else 1)
