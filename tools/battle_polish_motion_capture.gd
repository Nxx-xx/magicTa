extends SceneTree
## Timed viewport capture; fixture reports are explicitly simulated and committed.
const Replay = preload("res://scripts/ui/phase3_combat_player.gd")
const Combat = preload("res://scripts/core/phase3_combat.gd")
const OUT := "res://build/verification/battle-polish/timed/"
func _initialize() -> void:
	if not ProjectSettings.globalize_path("user://").replace("\\","/").contains("08-parallel/art-polish-c/"):
		quit(2)
		return
	_run.call_deferred()
func _run() -> void:
	root.min_size = Vector2i(320,640)
	root.size = Vector2i(390,700)
	var defs: Dictionary = JSON.parse_string(FileAccess.get_file_as_string("res://data/content.json")).enemies
	defs.merge(JSON.parse_string(FileAccess.get_file_as_string("res://data/phase3_enemies.json")).enemies)
	for id in (["p3_ember_channeler"] if "--ember" in OS.get_cmdline_user_args() else ["slime","p3_ember_channeler","golem"]):
		for speed in [1.0,.25]:
			var path := OUT+"%s_%s/"%[id,str(speed)]
			DirAccess.make_dir_recursive_absolute(path)
			var report := Combat.simulate({"hp":2000},defs[id],{"attack":16 if id == "p3_ember_channeler" else 35,"defense":15,"max_hp":2000,"kill_heal":0,"gold_bonus":0,"combat_effects":[]})
			var host := Replay.new()
			host.configure(report,true,{"enemy_id":id,"enemy_name":defs[id].name,"rank":defs[id].get("rank","normal")})
			root.add_child(host)
			host.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
			host.set_process(false)
			for i in 4: await process_frame
			var started := Time.get_ticks_usec()
			var previous := started
			var samples: Array = []
			var index := 0
			while host._elapsed < float(host._plan.duration)+.7:
				var now := Time.get_ticks_usec()
				var delta: float = (now-previous)/1000000.0*speed
				previous = now
				if host._finished: host._process(delta)
				else: host.advance(delta)
				await process_frame
				await RenderingServer.frame_post_draw
				root.get_texture().get_image().save_png(path+"%03d.png"%index)
				samples.append({"frame":index,"elapsed":host._elapsed,"wall_seconds":(Time.get_ticks_usec()-started)/1000000.0,"enemy_action":host._enemy_player.frame_at(host._elapsed,host._finished,report.won).action})
				index += 1
				await create_timer(.05).timeout
			FileAccess.open(path+"timing.json",FileAccess.WRITE).store_string(JSON.stringify({"speed":speed,"samples":samples,"report":report,"scope":"Timed actual Godot viewport; simulated committed report fixture, no campaign provenance"},"\t"))
			host.queue_free()
			await process_frame
	print("C timed 1x / .25x viewport captures complete")
	quit()
