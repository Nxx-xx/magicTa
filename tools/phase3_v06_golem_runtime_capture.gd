extends SceneTree
## Production UI and cache stress with simulated in-memory committed reports.
## This does not claim a naturally unlocked campaign, human review, or device proof.
const Replay = preload("res://scripts/ui/phase3_combat_player.gd")
const Combat = preload("res://scripts/core/phase3_combat.gd")
const Hero = preload("res://scripts/ui/phase3_animation_catalog.gd")
const MapArt = preload("res://scripts/ui/phase3_enemy_map_art.gd")
const RuinArt = preload("res://scripts/ui/phase3_ruin_art.gd")
const EnemyCatalog = preload("res://assets/monsters/phase3/phase3_enemy_animation_catalog.gd")
const OUT = "res://build/verification/phase3/09-refinement/golem/runtime/"
const IDS = ["slime","skeleton","bat","sentinel","warlock","knight","berserker","warden","minotaur","golem","p3_shield_sentinel","p3_ember_channeler","p3_vault_knight"]
var checks := 0
var failures := 0
var peak := 0
var records: Array = []
var map_hero := Hero.new()
var map_art := MapArt.new()
var ruins := RuinArt.new()

func check(ok: bool, label: String) -> void:
	checks += 1
	if not ok:
		failures += 1
		push_error("FAIL "+label)

func _initialize() -> void:
	if not ProjectSettings.globalize_path("user://").replace("\\","/").contains("08-parallel/golem_refine/"):
		quit(2)
		return
	_run.call_deferred()

func _frames() -> void:
	for i in 4: await process_frame
	await RenderingServer.frame_post_draw

func _bytes(host) -> int:
	var unique := {}
	for cache in [map_hero._cache,map_art.frames._cache,host._catalog._cache,host._enemy_player._cache]:
		for entry in cache.values():
			var texture: Texture2D = entry.texture
			unique[texture.get_rid().get_id()] = texture
	for texture in ruins.cache.values(): unique[texture.get_rid().get_id()] = texture
	for texture in [host._sprite.texture,host._enemy_sprite.texture,host._enemy_effect_sprite.texture]:
		if texture != null: unique[texture.get_rid().get_id()] = texture
	var total := 0
	for texture in unique.values(): total += texture.get_image().get_data_size()
	return total

func _run() -> void:
	DirAccess.make_dir_recursive_absolute(OUT)
	root.min_size = Vector2i(320,640)
	var definitions: Dictionary = JSON.parse_string(FileAccess.get_file_as_string("res://data/content.json")).enemies
	definitions.merge(JSON.parse_string(FileAccess.get_file_as_string("res://data/phase3_enemies.json")).enemies)
	var hero_data := Hero.read_manifest()
	check(hero_data.ok,"accepted hero metadata")
	map_hero.configure(hero_data.manifest)
	for key in hero_data.manifest.actions:
		if not key.begins_with("map_"): continue
		var action: Dictionary = hero_data.manifest.actions[key]
		for frame in action.frames.size(): map_hero.frame_at(key,float(frame)/float(action.fps)+.00001)
	for enemy in IDS:
		for frame in 4: map_art.texture(enemy,float(frame)/6.0+.00001)
	for id in ruins.manifest.ruins:
		var entity := {"id":"stress:"+id,"ruin_id":id,"status":"available"}
		for action in ruins.manifest.ruins[id].actions:
			entity.status = "resolved" if action != "idle" else "available"
			if action.begins_with("resolve_"):
				ruins.playing[entity.id] = {"start":0.0,"option":action.trim_prefix("resolve_")}
			var data: Dictionary = ruins.manifest.ruins[id].actions[action]
			for frame in data.frames.size(): ruins.texture(entity,float(frame)/float(data.fps)+.00001)
	for width in [540,320]:
		root.size = Vector2i(width,960 if width == 540 else 640)
		for enemy in IDS:
			var report := Combat.simulate({"hp":2000},definitions[enemy],{"attack":16,"defense":35,"max_hp":2000,"kill_heal":0,"gold_bonus":0,"combat_effects":[]})
			var original := report.duplicate(true)
			var host := Replay.new()
			check(host.configure(report,true,{"enemy_id":enemy,"enemy_name":definitions[enemy].get("name",enemy)}).ok,"production UI configured: "+enemy)
			root.add_child(host)
			host.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
			host.set_process(false)
			await _frames()
			for key in hero_data.manifest.actions:
				if not key.begins_with("combat_"): continue
				var action: Dictionary = hero_data.manifest.actions[key]
				for frame in action.frames.size(): host._catalog.frame_at(key,float(frame)/float(action.fps)+.00001)
			for action_name in host._enemy_player.actions:
				var action: Dictionary = host._enemy_player.actions[action_name]
				for channel in ["frames","effects_frames"]:
					if not action.has(channel): continue
					var sampled := action.duplicate(true)
					sampled.frames = action[channel]
					for frame in sampled.frames.size(): host._enemy_player._texture(sampled,frame)
			var target := .6
			for cue in host._plan.cues:
				if not cue.get("effects",[]).is_empty():
					target = maxf(0,float(cue.at)-.08) if cue.kind == "counter" else float(cue.at)+.03
					break
			host.advance(target)
			await _frames()
			check(host._enemy_sprite.texture != null,"visible production enemy: "+enemy)
			check(not host._enemy_sprite.get_global_rect().intersects(host._cue.get_global_rect()),"actor/chain cannot overlap mechanism text: "+enemy)
			check(host._primary.get_global_rect().end.y <= host.get_global_rect().end.y+1,"footer fits in logical canvas: "+enemy)
			var bytes := _bytes(host)
			peak = maxi(peak,bytes)
			check(bytes <= 48*1024*1024,"unique actual animation image data below 48MiB")
			check(host._enemy_player.cache_bytes <= 8*1024*1024,"enemy LRU below 8MiB")
			check(map_art.frames.cache_bytes <= 4*1024*1024,"map LRU below 4MiB")
			check(root.get_texture().get_image().save_png(OUT+"%s_%d.png" % [enemy,width]) == OK,"UI screenshot")
			records.append({"enemy":enemy,"width":width,"cue_text":host._cue.text,"enemy_action":host._enemy_player.frame_at(host._elapsed).action,"unique_decoded_bytes":bytes,"enemy_cache_bytes":host._enemy_player.cache_bytes,"map_cache_bytes":map_art.frames.cache_bytes})
			host.skip()
			check(host.full_report() == original and report == original,"UI stress never mutates report")
			host.queue_free()
			await process_frame
	FileAccess.open(OUT+"results.json",FileAccess.WRITE).store_string(JSON.stringify({"checks":checks,"failures":failures,"peak_unique_decoded_animation_bytes":peak,"samples":records,"scope":"Production replay UI with in-memory simulated reports marked committed; warmed production hero/map/ruin/enemy caches plus actor textures deduplicated by RID and measured via Image.get_data_size. Not a campaign route, process RAM, renderer total, or device acceptance."},"\t"))
	print("v06 runtime UI/cache: %d checks, %d failures; image-data peak %d" % [checks,failures,peak])
	quit(0 if failures == 0 else 1)
