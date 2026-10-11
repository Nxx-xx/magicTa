extends SceneTree
const Replay = preload("res://scripts/ui/phase3_combat_player.gd")
const Combat = preload("res://scripts/core/phase3_combat.gd")
const IDS = ["slime","skeleton","bat","sentinel","warlock","knight","berserker","warden","minotaur","golem","p3_shield_sentinel","p3_ember_channeler","p3_vault_knight"]
var out := "res://build/verification/art-polish-c/after/"
var failures := 0
var checks := 0
func check(ok: bool, message: String) -> void:
	checks += 1
	if not ok:
		failures += 1
		push_error("FAIL " + message)
func _initialize() -> void:
	if not ProjectSettings.globalize_path("user://").replace("\\","/").contains("08-parallel/art-polish-c/"):
		quit(2)
		return
	_run.call_deferred()
func frames() -> void:
	for i in 3: await process_frame
	await RenderingServer.frame_post_draw
func _run() -> void:
	var before := "--before" in OS.get_cmdline_user_args()
	if before: out = out.replace("after/","before/")
	DirAccess.make_dir_recursive_absolute(out)
	root.min_size = Vector2i(320,640)
	var defs: Dictionary = JSON.parse_string(FileAccess.get_file_as_string("res://data/content.json")).enemies
	defs.merge(JSON.parse_string(FileAccess.get_file_as_string("res://data/phase3_enemies.json")).enemies)
	for width in [320,390,540]:
		root.size = Vector2i(width,960 if width == 540 else (700 if width == 390 else 640))
		for id in (["slime"] if before else IDS):
			var report := Combat.simulate({"hp":2000},defs[id],{"attack":16 if id == "p3_ember_channeler" else 35,"defense":15,"max_hp":2000,"kill_heal":0,"gold_bonus":0,"combat_effects":[{"id":"retaliation","amount":2,"charges":3,"source_item_id":"p3_thorn_clasp"},{"id":"counter_guard","amount":2,"charges":2,"source_item_id":"p3_lantern_aegis"}]})
			if id.begins_with("p3_"):
				var seen := false
				for entry in report.log:
					for effect in entry.effect_events:
						if effect.id == defs[id].ability_id and effect.amount > 0: seen = true
				check(seen,"fixture actually triggers enemy ability "+id)
			var original := report.duplicate(true)
			var host := Replay.new()
			check(host.configure(report,true,{"enemy_id":id,"enemy_name":defs[id].name,"rank":defs[id].get("rank","normal")}).ok,"configure "+id)
			root.add_child(host)
			host.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
			host.set_process(false)
			await frames()
			host.advance(.21)
			await frames()
			root.get_texture().get_image().save_png(out+"%s_%d.png"%[id,width])
			check(host._primary.get_global_rect().end.y <= host.size.y+1,"footer "+id)
			check(not host._enemy_sprite.get_global_rect().intersects(host._cue.get_global_rect()),"text separated "+id)
			check(host._plan.duration <= 6.0,"six second target "+id)
			if not before and width == 390:
				for cue in host._plan.cues:
					if cue.at < host._elapsed or cue.get("effects",[]).is_empty(): continue
					host.advance(float(cue.at)-host._elapsed+.015)
					await frames()
					root.get_texture().get_image().save_png(out+"%s_mechanism_%d.png"%[id,int(cue.turn)])
			var paused_time: float = host._elapsed
			host.set_paused(true)
			host.advance(1)
			check(host._elapsed == paused_time,"pause freezes "+id)
			host.set_paused(false)
			host.skip()
			await frames()
			check(host.full_report() == original and report == original,"read only "+id)
			host.set_reduce_motion(true)
			await frames()
			check(not host._sprite.get_parent().visible and host._report_pages.visible,"reduce after skip enters quiet report "+id)
			var frozen := root.get_texture().get_image().get_data()
			host._process(.5)
			await frames()
			check(frozen == root.get_texture().get_image().get_data(),"reduced stable "+id)
			root.get_texture().get_image().save_png(out+"%s_reduced_%d.png"%[id,width])
			host.queue_free()
			await process_frame
			if not before:
				var quiet := Replay.new()
				check(quiet.configure(report,true,{"enemy_id":id,"enemy_name":defs[id].name,"reduce_motion":true}).ok,"direct reduced configure "+id)
				root.add_child(quiet)
				quiet.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
				await frames()
				check(quiet._finished and not quiet._stage.visible and quiet._report_pages.visible,"direct reduced has no action/effect stage "+id)
				check(quiet._primary.get_global_rect().end.y <= quiet.size.y+1,"reduced footer fits "+id)
				root.get_texture().get_image().save_png(out+"%s_reduced_%d.png"%[id,width])
				quiet.queue_free()
				await process_frame
	FileAccess.open(out+"results.json",FileAccess.WRITE).store_string(JSON.stringify({"checks":checks,"failures":failures,"scope":"Production UI / simulated committed reports, not natural campaign or device acceptance"},"\t"))
	print("ART_POLISH_C %d checks / %d failures"%[checks,failures])
	quit(1 if failures else 0)
