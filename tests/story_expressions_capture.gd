extends SceneTree
const Screen = preload("res://scripts/ui/map_screen.gd")
const Core = preload("res://scripts/core/campaign_engine.gd")
const Story = preload("res://scripts/core/story_state.gd")
const Expressions = preload("res://scripts/ui/story_expression_art.gd")
const Art = preload("res://scripts/ui/runtime_art.gd")
const Knight = preload("res://scripts/ui/camp_knight_art.gd")
var out := "res://build/verification/story-expressions/before/"
var ui
var checks := 0
var failures := 0

func _initialize() -> void: _run.call_deferred()

func check(ok: bool, label: String) -> void:
	checks += 1
	if not ok:
		failures += 1
		push_error("FAIL " + label)

func frames() -> void:
	for i in 12: await process_frame

func _run() -> void:
	if not ProjectSettings.globalize_path("user://").replace("\\", "/").contains("story-expressions/"):
		quit(2)
		return
	if "--after" in OS.get_cmdline_user_args(): out = out.replace("/before/", "/after/")
	DirAccess.make_dir_recursive_absolute(out)
	var after := "--after" in OS.get_cmdline_user_args()
	if after: expression_contract()
	root.min_size = Vector2i(320,640)
	for dimensions in [Vector2i(320,640),Vector2i(390,700),Vector2i(540,960)]:
		root.size = dimensions
		root.content_scale_size = dimensions
		ui = Screen.new()
		ui.game = Core.new("user://expressions_%d.json" % dimensions.x)
		ui.game.persistence_enabled = false
		root.add_child(ui)
		ui.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
		await frames()
		ui.settings.muted = true
		ui.settings.reduce_motion = true
		ui._start_campaign("STORY-EXPRESSIONS")
		await frames()
		for sample in [["intro",10,"hero_guarded"],["intro",13,"prince_weary"],["mid_boss",1,"demon_stern"],["victory",6,"hero_shock"],["victory",8,"prince_sneer"],["victory",15,"reveal"],["victory",19,"knight"]]:
			ui.game.state.story = {"queue":[],"seen":[]}
			Story.enqueue(ui.game.state,sample[0])
			# Entering a new event intentionally resets the host to line zero.
			ui._refresh_map(true)
			await frames()
			ui.story_line = sample[1]
			ui._refresh_map(true)
			await frames()
			var portrait: TextureRect = ui.story_stage.portrait if ui.story_stage.active else ui.body.get_node_or_null("StoryPortrait")
			if not after:
				# Replay the saved pre-change renderer, without rolling back shared files.
				for child in ui.body.get_children():
					ui.body.remove_child(child)
					child.queue_free()
				load("res://build/verification/story-expressions/baseline/campaign_panels.gd").story(ui,ui._story_event())
				if ui.story_stage.active:
					var layer = ui.story_stage.portrait.get_node_or_null("StoryExpressionPatch")
					if layer != null: layer.hide()
				await frames()
			else:
				check(portrait != null,"formal story portrait")
				if portrait != null:
					var expected: String = sample[2] if sample[2] not in ["reveal","knight"] else ""
					check(portrait.get_meta("story_expression","") == expected,"expression selection " + sample[2])
					if sample[2] == "reveal": check(portrait.texture.resource_path.ends_with("prince_monster_reveal_v01.png"),"explicit ending illustration wins")
					if sample[2] == "knight": check(portrait.texture == Knight.PORTRAIT,"old knight portrait preserved")
			check(Vector2i(ui.size) == dimensions,"actual viewport " + str(dimensions))
			check(ui.overlay_next.get_global_rect().end.y <= dimensions.y+1,"continue within viewport")
			check(ui.scroll.get_h_scroll_bar().max_value <= ui.scroll.size.x+1,"no horizontal overflow")
			var snapshot: Dictionary = ui.game.state.duplicate(true)
			await RenderingServer.frame_post_draw
			var shot := root.get_texture().get_image()
			check(shot.get_size() == dimensions,"actual screenshot pixels")
			check(shot.save_png(out+"%s_%d.png" % [sample[2],dimensions.x]) == OK,"capture")
			if after and portrait != null and sample[2] == "hero_guarded":
				var region := Rect2i(portrait.get_global_rect()).intersection(Rect2i(Vector2i.ZERO,dimensions))
				var reduced_pixels := shot.get_region(region).get_data()
				ui.settings.reduce_motion = false
				await frames()
				await RenderingServer.frame_post_draw
				check(root.get_texture().get_image().get_region(region).get_data() == reduced_pixels,"expression does not add motion when reduced motion changes")
				ui.settings.reduce_motion = true
			await frames()
			check(snapshot == ui.game.state,"presentation preserves state")
		ui.queue_free()
		await frames()
	print("STORY EXPRESSIONS %d checks, %d failures" % [checks,failures])
	quit(1 if failures else 0)

func expression_contract() -> void:
	var data: Dictionary = JSON.parse_string(FileAccess.get_file_as_string("res://data/story.json"))
	var selected := {}
	for id in data.events:
		var event: Dictionary = data.events[id].duplicate(true)
		event.id = id
		for i in event.lines.size():
			var line: Dictionary = event.lines[i]
			var key := Expressions.expression(event,line,i)
			if not key.is_empty(): selected[key] = true
			check(key != "prince_sneer" or (id == "victory" and i > 5 and i < 14),"no early betrayal expression")
			if line.has("illustration"): check(key.is_empty(),"all explicit illustrations bypass patch")
	check(selected.size() == 5,"all five patches reachable from actual story")
	check(Expressions.expression({"id":"victory"},{"speaker":"王子","text":"unknown saved line"},8).is_empty(),"unknown saved victory text remains neutral")
	var portrait := TextureRect.new()
	root.add_child(portrait)
	var line: Dictionary = data.events.victory.lines[8]
	var path := "res://assets/story/expressions/textures/prince_sneer_v01.png"
	var saved = Art.texture(path)
	Art.cache[path] = null
	Expressions.present(portrait,Expressions.PRINCE,{"id":"victory"},line,8)
	check(portrait.texture == Art.texture(Expressions.PRINCE) and portrait.get_meta("story_expression").is_empty(),"missing patch keeps neutral portrait")
	Art.cache[path] = saved
	Expressions.present(portrait,Expressions.PRINCE,{"id":"victory"},line,8)
	check(portrait.get_meta("story_expression") == "prince_sneer","patch applied")
	Expressions.present(portrait,Expressions.PRINCE,{"id":"unknown"},{"speaker":"王子"},0)
	check(portrait.get_meta("story_expression").is_empty() and portrait.get_node("StoryExpressionPatch").patch == null,"next neutral line clears stale expression")
	portrait.queue_free()
