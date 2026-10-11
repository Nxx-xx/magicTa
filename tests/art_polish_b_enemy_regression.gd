extends SceneTree
const Player = preload("res://scripts/ui/phase3_combat_player.gd")
const Visual = preload("res://scripts/ui/phase3_enemy_player.gd")
const Combat = preload("res://scripts/core/phase3_combat.gd")
const Catalog = preload("res://assets/monsters/phase3/phase3_enemy_animation_catalog.gd")
const MapArt = preload("res://scripts/ui/phase3_enemy_map_art.gd")
var checks := 0
var failures := 0

func check(value: bool, label: String) -> void:
	checks += 1
	if not value:
		failures += 1
		push_error("FAIL: "+label)

func _initialize() -> void:
	_run.call_deferred()

func _run() -> void:
	if not "--production" in OS.get_cmdline_user_args(): preload("res://tests/art_polish_b_preview_loader.gd").enable()
	for name in ["idle","attack","hit","defeat"]:
		var action := Catalog.load_action("slime",name)
		check(action.ok,"accepted slime "+name)
		if not action.ok: continue
		for index in action.sprite_frames.get_frame_count(name):
			var picture: Image = action.sprite_frames.get_frame_texture(name,index).get_image()
			check(picture.get_size() == Vector2i(256,256) and picture.detect_alpha() != Image.ALPHA_NONE,"RGBA frame "+name)
	check(Catalog.load_action("minotaur","attack").ok,"explicitly reviewed v04 boss accepted")
	check(Catalog.load_action("golem","attack").ok,"explicitly reviewed golem accepted")
	check(not Catalog.load_action("skeleton","review_missing_action").ok,"unavailable action remains rejected")
	var stats := {"attack":10,"defense":1,"max_hp":100,"kill_heal":0,"gold_bonus":0,"combat_effects":[]}
	var enemy := {"id":"slime","hp":25,"attack":4,"defense":0,"gold_reward":3}
	var report := Combat.simulate({"hp":100},enemy,stats)
	var original := report.duplicate(true)
	var plan := Player.build_plan(report)
	var visual := Visual.new()
	visual.configure("slime",plan)
	check(visual.cache_bytes == 0,"configure reads metadata without decoding actions")
	var counter: Dictionary = plan.cues.filter(func(c): return c.kind == "counter")[0]
	var attack: Dictionary = plan.cues.filter(func(c): return c.kind == "attack")[0]
	check(visual.frame_at(counter.at-.14).action == "attack","counter anticipation")
	check(visual.frame_at(attack.at+.01).action == "hit","received strike interrupts anticipation")
	var contact := visual.frame_at(counter.at)
	check(contact.action == "attack" and contact.frame == 3,"enemy contact aligned with counter report")
	var fatal: Dictionary = plan.cues.filter(func(c): return c.kind == "attack" and c.enemy_hp == 0)[0]
	check(visual.frame_at(fatal.at).action == "defeat","fatal player hit starts death")
	check(visual.frame_at(fatal.at+1).frame == 5,"death holds final residue without another attack")
	check(visual.frame_at(0,true,true).action == "defeat","skip goes directly to settled outcome")
	check(visual.frame_at(.2,false,false,true).action == "idle","reduced motion uses stable idle")
	check(visual.cache_bytes > 0 and visual.peak_cache_bytes <= Visual.CACHE_LIMIT,"on-demand decoded bytes bounded")
	# Traverse every actual boss frame: aggregate decoded data exceeds the cache.
	var boss := Visual.new()
	boss.configure("minotaur",{})
	var all_bytes := 0
	var first_ref: WeakRef
	for name in ["idle","attack","hit","rage","defeat"]:
		var metadata := Catalog.describe_action("minotaur",name)
		check(metadata.ok,"reviewed boss metadata "+name)
		if not metadata.ok: continue
		for index in metadata.action.frames.size():
			var texture: Texture2D = boss._texture(metadata.action,index)
			check(texture != null,"boss frame survives budget pressure "+name+str(index))
			if texture == null: continue
			all_bytes += texture.get_image().get_data_size()
			if first_ref == null: first_ref = weakref(texture)
			check(boss.cache_bytes <= Visual.CACHE_LIMIT,"measured cache remains bounded")
	check(all_bytes > Visual.CACHE_LIMIT,"fixture actually exceeds active cache budget")
	check(first_ref.get_ref() == null,"evicted texture reference released")
	var boss_report := Combat.simulate({"hp":100},{"id":"minotaur","hp":120,"attack":18,"defense":8,"gold_reward":65,"ability_id":"rage"},{"attack":27,"defense":11,"max_hp":100,"kill_heal":0,"gold_bonus":0,"combat_effects":[]})
	var boss_plan := Player.build_plan(boss_report,"boss")
	boss.configure("minotaur",boss_plan)
	var rage_time := -1.0
	for cue in boss_plan.cues:
		for effect in cue.get("effects",[]):
			if effect.id == "rage": rage_time = float(cue.at)-.08 if cue.kind == "counter" else float(cue.at)+.01
	check(rage_time >= 0,"actual report contains rage mechanism")
	var rage_pose := boss.frame_at(rage_time)
	check(rage_pose.action == "rage" and rage_pose.effects_texture != null,"committed rage selects body and separate rune")
	boss.effects_enabled = false
	var plain_rage := boss.frame_at(rage_time)
	check(plain_rage.action == "rage" and plain_rage.texture == rage_pose.texture and plain_rage.effects_texture == null,"turning rune off preserves body pose")
	boss.effects_enabled = true
	var reduced_rage := boss.frame_at(rage_time,false,false,true)
	check(reduced_rage.action == "idle" and reduced_rage.effects_texture == null,"reduced motion suppresses mechanism overlay")
	check(boss.frame_at(boss_plan.duration+1).action == "defeat","mechanism cannot override terminal defeat")
	var map_art := MapArt.new()
	var map_texture := map_art.texture("minotaur",0)
	check(map_texture != null and map_texture.get_size() == Vector2(256,256),"independent boss map camera loads accepted frame")
	check(map_art.texture("minotaur",.2) != map_texture,"map idle advances its own timeline")
	check(map_art.texture("minotaur",.8,true) == map_texture,"map reduced motion holds independent first frame")
	check(map_art.texture("review_missing_enemy",0) == null,"unavailable map camera requests static fallback")
	map_art.clear()
	check(map_art.frames.cache_bytes == 0 and map_art.definitions.is_empty(),"new floor releases map animation residency")
	var golem_visual := Visual.new()
	golem_visual.configure("golem",{})
	for name in ["idle","attack","hit","armor","defeat"]:
		var metadata := Catalog.describe_action("golem",name)
		check(metadata.ok,"reviewed golem metadata "+name)
		if not metadata.ok: continue
		for index in metadata.action.frames.size():
			check(golem_visual._texture(metadata.action,index) != null,"all golem frames available "+name+str(index))
			check(golem_visual.cache_bytes <= Visual.CACHE_LIMIT,"golem real cache bytes bounded")
	var armor_report := Combat.simulate({"hp":100},{"id":"golem","hp":250,"attack":28,"defense":14,"ability_id":"stone_armor","gold_reward":120},{"attack":115,"defense":50,"max_hp":100,"kill_heal":0,"gold_bonus":0,"combat_effects":[]})
	var armor_plan := Player.build_plan(armor_report,"boss")
	golem_visual.configure("golem",armor_plan)
	var mechanism_cue: Dictionary = armor_plan.cues.filter(func(c): return c.kind == "mechanism")[0]
	var armor_pose := golem_visual.frame_at(mechanism_cue.at+.1)
	check(armor_pose.action == "armor" and armor_pose.effects_texture != null,"actual multi-threshold hit shows closing plates and separate rune")
	golem_visual.effects_enabled = false
	check(golem_visual.frame_at(mechanism_cue.at+.1).texture == armor_pose.texture and golem_visual.frame_at(mechanism_cue.at+.1).effects_texture == null,"golem plate motion survives rune switch")
	var golem_counter: Dictionary = armor_plan.cues.filter(func(c): return c.kind == "counter")[0]
	check(golem_visual.frame_at(golem_counter.at).action == "attack" and golem_visual.frame_at(golem_counter.at).frame == 5,"stone armor finishes before actual fist contact")
	check(map_art.texture("golem",0) != null,"golem independent map camera accepted")
	var missing := Catalog.describe_action("slime","idle").action as Dictionary
	missing.frames = ["res://assets/monsters/phase3/textures/missing-test-frame.png"]
	boss.actions = {"idle":missing}
	boss.fallback = visual.fallback
	check(boss.frame_at(0).action == "static" and boss.frame_at(0).texture != null,"missing frame visibly falls back")
	boss.configure("skeleton",{})
	check(boss.cache_bytes == 0 and boss._cache.is_empty(),"opponent change unloads decoded boss frames")
	visual.configure("skeleton",plan)
	visual.actions.clear() # Simulate absent or rejected metadata, independent of production coverage.
	check(visual.cache_bytes == 0 and visual.frame_at(.2).texture != null and visual.frame_at(.2).action == "static","missing actions retain visible static fallback")
	stats.combat_effects = [{"id":"retaliation","amount":20,"charges":3,"source_item_id":"p3_thorn_clasp"}]
	var thorn := Combat.simulate({"hp":100},enemy,stats)
	var thorn_plan := Player.build_plan(thorn)
	var terminal: Dictionary = thorn_plan.cues.filter(func(c): return c.kind == "retaliation")[0]
	visual.configure("slime",thorn_plan)
	check(visual.frame_at(terminal.at).action == "defeat","retaliation fatality goes directly to death")
	check(visual.frame_at(terminal.at+.6).action == "defeat","no fresh attack after retaliation death")
	var host := Player.new()
	check(not host.configure(report,false).ok,"unsaved combat cannot start enemy playback")
	check(host.configure(report,true,{"enemy_id":"slime"}).ok,"saved combat accepted")
	root.add_child(host)
	host.size = Vector2(540,760)
	host.set_process(false)
	await process_frame
	host.advance(float(counter.at))
	check(host._enemy_sprite.texture == host._enemy_player.frame_at(counter.at).texture,"real replay displays enemy contact frame")
	host.set_paused(true)
	var paused := host._elapsed
	host.advance(1)
	check(host._elapsed == paused,"pause freezes enemy timeline")
	host.set_paused(false)
	host.skip()
	check(host.full_report() == original,"skip and animation preserve report")
	if "--capture" in OS.get_cmdline_user_args():
		await process_frame
		await RenderingServer.frame_post_draw
		root.get_texture().get_image().save_png("res://build/verification/phase3/07-completion/slime_replay.png")
	host.queue_free()
	await process_frame
	print("Enemy player: %d checks, %d failures" % [checks,failures])
	quit(0 if failures == 0 else 1)
