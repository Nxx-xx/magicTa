extends "res://tests/phase3_golem_host_capture.gd"
## Same publicly traversed campaign route, own isolation and evidence.
func _initialize()->void:
	if not ProjectSettings.globalize_path("user://").replace("\\","/").contains("08-parallel/golem_refine/"):
		quit(2)
		return
	suite_started=Time.get_ticks_msec()
	evidence_out="res://build/verification/phase3/09-refinement/golem/host/"
	DirAccess.make_dir_recursive_absolute(evidence_out)
	run_folder="user://golem_v06_%d_%d"%[OS.get_process_id(),Time.get_ticks_usec()]
	DirAccess.make_dir_recursive_absolute(run_folder)
	Core=load("res://scripts/core/campaign_engine.gd")
	core=Core.new(run_folder+"/probe.json")
	_suite.call_deferred()
func _suite()->void:
	boss_id="golem"
	target_floor=10
	mechanism="armor"
	capture_out="res://build/verification/phase3/09-refinement/golem/host/"
	# Call the route directly because the legacy golem override hardcodes its path.
	await _run_public_route()
func _run_public_route()->void:
	DirAccess.make_dir_recursive_absolute(capture_out+"frames")
	_new_case(boss_id+"_animation_capture",true)
	if not _start_phase3("42"):
		quit(1)
		return
	for number in range(1,target_floor):
		var ok := true
		match number:
			1: ok = _branch(0) and _branch(1)
			2: ok = _branch(0) and _ruin("edge",false)
			3: ok = _branch(0)
			4: ok = _branch(0) and _rest()
			5:
				var middle_boss := _entity_cell("enemy","campaign_boss")
				ok = _walk(middle_boss) and _fight(middle_boss)
				if ok:
					ok = _walk(_entity_cell("choice","campaign_boss_reward"))
					if ok: ok = _check(core.choose_reward(0).is_empty(),"real midboss growth reward claimed")
			6: ok = _branch(0) and _ruin("temper",false)
			7: ok = _branch(0)
			9: ok = _ruin("ward",false) and _rest()
		if not ok or not _travel_up("42",number):
			quit(1)
			return
	var boss := _entity_cell("enemy","campaign_boss")
	if not _check(boss.x >= 0 and core.entity_at(boss).enemy_id == boss_id,"real target-floor boss exists") or not _walk(boss) or not _checkpoint(boss_id+"_before_ui"):
		quit(1)
		return
	root.min_size = Vector2i(320,640)
	root.size = Vector2i(540,960)
	var ui := Screen.new()
	ui.game = core
	root.add_child(ui)
	ui.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	for i in 8: await process_frame
	ui.settings.reduce_motion = false
	ui.settings.muted = true
	ui._open_map()
	core.cancel_pending()
	while not ui._story_event().is_empty(): ui._finish_story()
	ui._render(true)
	for i in 4: await process_frame
	await RenderingServer.frame_post_draw
	root.get_texture().get_image().save_png(capture_out+"map-camera.png")
	ui.game.interact(boss)
	ui._render(true)
	await process_frame
	await RenderingServer.frame_post_draw
	root.get_texture().get_image().save_png(capture_out+"map.png")
	var baseline_gpu := RenderingServer.get_rendering_info(RenderingServer.RENDERING_INFO_TEXTURE_MEM_USED)
	var before: Dictionary = core.state.duplicate(true)
	var store = core.store
	core.store = FailStore.new()
	ui._fight()
	_check(core.transaction_pending and not is_instance_valid(ui.combat_view) and core.state == before,"failed save cannot replay boss or mutate state")
	await process_frame
	await RenderingServer.frame_post_draw
	root.get_texture().get_image().save_png(capture_out+"save-failure.png")
	core.store = store
	if not _check(core.retry_save(),"same boss transaction retry saves"):
		quit(1)
		return
	ui._render(true)
	ui._present_combat()
	if not _check(is_instance_valid(ui.combat_view),"saved boss opens production playback"):
		quit(1)
		return
	var replay = ui.combat_view
	replay.set_process(false)
	var committed: Dictionary = core.state.duplicate(true)
	var account: Dictionary = core.meta.duplicate(true)
	var peak_decoded := 0
	var peak_gpu := baseline_gpu
	var samples := []
	var rendered_actions := {}
	var frame_count := ceili((float(replay._plan.duration)+1.3)/.05)
	for frame in frame_count:
		if replay._finished: replay._process(.05)
		else: replay.advance(.05 if frame > 0 else 0)
		await process_frame
		await RenderingServer.frame_post_draw
		root.get_texture().get_image().save_png(capture_out+"frames/%03d.png" % frame)
		var decoded := _decoded_bytes(ui,replay)
		var gpu := RenderingServer.get_rendering_info(RenderingServer.RENDERING_INFO_TEXTURE_MEM_USED)
		peak_decoded = maxi(peak_decoded,decoded)
		peak_gpu = maxi(peak_gpu,gpu)
		var pose: Dictionary = replay._enemy_player.frame_at(replay._elapsed,replay._finished,committed.last_report.won)
		rendered_actions[pose.action] = true
		samples.append({"frame":frame,"time":replay._elapsed,"enemy_action":pose.action,"stone_armor_stage":pose.get("stone_armor_stage",0),"decoded_animation_bytes":decoded,"render_texture_bytes":gpu})
	_check(peak_decoded <= 48*1024*1024,"actual unique decoded animation residency below 48 MiB in this boss replay")
	_check(replay._enemy_player.peak_cache_bytes <= 8*1024*1024,"boss LRU stays within 8 MiB")
	_check(rendered_actions.has("attack") and rendered_actions.has(mechanism) and rendered_actions.has("defeat"),"actual boss report shows attack, mechanism and death")
	_check(core.state == committed and core.meta == account,"whole animation leaves committed report and rewards unchanged")
	_check(ui.board.enemy_map_art.frames.peak_cache_bytes <= 4*1024*1024,"map actual image data cache below 4MiB")
	var boss_peak: int = replay._enemy_player.peak_cache_bytes
	replay.close()
	for i in 8: await process_frame
	_check(core.state == committed and core.meta == account,"closing boss cannot settle twice")
	await RenderingServer.frame_post_draw
	root.get_texture().get_image().save_png(capture_out+"post-combat.png")
	if target_floor == 10:
		_check(committed.get("result","") == "victory" and not committed.story.queue.is_empty(),"golem keeps committed ending and existing rescue story queue")
	FileAccess.open(capture_out+"results.json",FileAccess.WRITE).store_string(JSON.stringify({
		"checks":checks,"failures":failures,"frame_count":frame_count,"provenance":"C0 seed42, zero-fire default; public movement/reward/rest/ruin APIs to floor%d; no direct progression mutation; injected save failure followed by retry; actual UI capture at 20 FPS" % target_floor,
		"boss_enemy_id":boss_id,"committed_result":committed.get("result",""),"story_events_after_commit":committed.story.queue.map(func(event): return event.get("id","")),
		"peak_unique_decoded_animation_bytes":peak_decoded,"boss_peak_cache_bytes":boss_peak,
		"render_texture_baseline_bytes":baseline_gpu,"render_texture_peak_bytes":peak_gpu,
		"render_texture_delta_bytes":peak_gpu-baseline_gpu,"samples":samples,"report":committed.last_report,
		"scope":"one desktop boss replay, actual texture image data and renderer counters; not all scenes, process RAM or mobile/device proof"},"\t"))
	print("%s host: %d checks, %d failures; decoded peak %d; renderer delta %d" % [boss_id,checks,failures.size(),peak_decoded,peak_gpu-baseline_gpu])
	quit(0 if failures.is_empty() else 1)

func _decoded_bytes(ui,replay)->int:
	var unique:Dictionary={}
	for cache in [ui.board.hero_catalog._cache,ui.board.enemy_map_art.frames._cache,replay._catalog._cache,replay._enemy_player._cache]:
		for entry in cache.values():
			var texture:Texture2D=entry.texture
			unique[texture.get_rid().get_id()]=texture
	for texture in ui.board.ruin_art.cache.values():unique[texture.get_rid().get_id()]=texture
	for texture in [replay._sprite.texture,replay._enemy_sprite.texture,replay._enemy_effect_sprite.texture]:
		if texture!=null:unique[texture.get_rid().get_id()]=texture
	var total:=0
	for texture in unique.values():total+=texture.get_image().get_data_size()
	return total
