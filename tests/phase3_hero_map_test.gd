extends SceneTree
const Core = preload("res://scripts/core/campaign_engine.gd")
const Board = preload("res://scripts/ui/grid_board.gd")
const Catalog = preload("res://scripts/ui/phase3_animation_catalog.gd")
const OUT := "res://build/verification/phase3/07-completion/"
var checks := 0
var failures := 0

func _initialize() -> void:
	var isolated := ProjectSettings.globalize_path("user://").replace("\\","/")
	if not (isolated.contains("phase3/07-completion/") or isolated.contains("phase3/08-parallel/coordinator/")):
		quit(2)
		return
	_run.call_deferred()

func check(ok: bool, label: String) -> void:
	checks += 1
	if not ok:
		failures += 1
		push_error("FAIL "+label)

func _run() -> void:
	var catalog := Catalog.new()
	var manifest := Catalog.read_manifest()
	check(manifest.ok,"production manifest")
	if not manifest.ok:
		quit(1)
		return
	catalog.configure(manifest.manifest)
	for facing in Catalog.DIRECTIONS:
		var action: String = "map_walk_"+facing
		for i in 6:
			var frame := catalog.frame_at(action,float(i)/12+.001)
			check(not frame.fallback and frame.frame == i,"six real frames "+action)
		check(catalog.frame_at(action,.51).frame == 0,"cycle returns contact")
		check(catalog.frame_at(action,.3,true).frame == 0,"reduced locks pose")
	check(catalog.cache_bytes == 24*128*128*4,"all four walk cycles decode to 1.5 MiB")
	var core := Core.new("user://hero_map_check.json")
	core.persistence_enabled = false
	check(core.start_phase3("42").is_empty(),"production new journey")
	var board := Board.new()
	root.add_child(board)
	board.size = Vector2(540,720)
	board.setup(core.floor_data(),core.position(),Vector2i(-1,-1),true,core.db.data.enemies)
	await process_frame
	await RenderingServer.frame_post_draw
	check(not board.walk_art.visible,"accepted frames replace deformation only in p3")
	var original := core.position()
	var target := original
	for delta in [Vector2i.UP,Vector2i.RIGHT,Vector2i.LEFT,Vector2i.DOWN]:
		var cell: Vector2i = original+delta
		if cell.x in range(1,10) and cell.y in range(1,10) and core.floor_data().rows[cell.y][cell.x] == "." and core.entity_at(cell).is_empty():
			target = cell
			break
	check(target != original,"legal adjacent empty tile exists")
	core.interact(target)
	check(core.position() == target,"production move accepted")
	board.setup(core.floor_data(),core.position(),Vector2i(-1,-1),true,core.db.data.enemies)
	check(board.moving and board.hero_visual != Vector2(target),"real move interpolates")
	for i in 6: board._process(.04)
	check(not board.moving and board.hero_visual == Vector2(target),"same step timing and landing")
	board.play_interaction()
	check(board.interaction_started == board.idle_seconds,"committed interaction starts")
	var interaction := board.hero_catalog.frame_at("map_interact_"+board.facing,0)
	check(board.hero_pose().texture == interaction.texture,"interaction renders accepted action")
	for i in 8: board._process(.06)
	check(board.interaction_started < 0,"interaction ends without blocking movement")
	board.reduce_motion = true
	board.play_interaction()
	check(board.interaction_started < 0,"reduced motion suppresses interaction")
	board.queue_redraw()
	await process_frame
	await RenderingServer.frame_post_draw
	check(not board.walk_art.visible,"reduced motion uses accepted stable pose")
	var state_before: Dictionary = core.state.duplicate(true)
	for facing in Catalog.DIRECTIONS:
		board.facing = facing
		board.queue_redraw()
		await process_frame
		await RenderingServer.frame_post_draw
		root.get_texture().get_image().save_png(OUT+"hero_board_"+facing+".png")
	check(core.state == state_before,"viewing poses never changes gameplay")
	var enabled := board.hero_catalog.manifest.duplicate(true)
	board.reduce_motion = false
	var animated_times: Array = await sample_frames()
	# No accepted manifest simulates missing optional assets: static path still works.
	board.hero_catalog.manifest = {"actions":{}}
	board.queue_redraw()
	await process_frame
	await RenderingServer.frame_post_draw
	check(board.walk_art.visible,"missing frames retain original fallback")
	var fallback_times: Array = await sample_frames()
	board.hero_catalog.manifest = enabled
	var metrics := {"renderer":RenderingServer.get_video_adapter_name(),"viewport":[root.size.x,root.size.y],
		"map_catalog_decoded_bytes":board.hero_catalog.cache_bytes,"walk_review_decoded_bytes":catalog.cache_bytes,
		"animated_ms":stats(animated_times),"static_fallback_ms":stats(fallback_times),
		"scope":"120 rendered idle samples each, VSync included; Windows development machine, not mobile or whole-stage certification"}
	FileAccess.open(OUT+"hero-map-performance.json",FileAccess.WRITE).store_string(JSON.stringify(metrics,"\t"))
	print("HERO_MAP %d checks, %d failures" % [checks,failures])
	quit(1 if failures else 0)

func sample_frames() -> Array:
	var samples := []
	for i in 130:
		var start := Time.get_ticks_usec()
		await process_frame
		await RenderingServer.frame_post_draw
		if i >= 10: samples.append(float(Time.get_ticks_usec()-start)/1000)
	return samples

func stats(values: Array) -> Dictionary:
	values.sort()
	return {"samples":values.size(),"median":values[values.size()/2],"p95":values[int(values.size()*.95)],"max":values[-1]}
