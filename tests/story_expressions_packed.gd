extends SceneTree
var checks := 0
var failures := 0
var output := ""

func check(ok: bool, label: String) -> void:
	checks += 1
	if not ok:
		failures += 1
		push_error("FAIL " + label)

func frames() -> void:
	for i in 12: await process_frame

func _initialize() -> void: run.call_deferred()

func run() -> void:
	var package := ""
	for argument in OS.get_cmdline_user_args():
		if argument.begins_with("--package="): package = argument.trim_prefix("--package=")
		if argument.begins_with("--output="): output = argument.trim_prefix("--output=")
	check(not package.is_empty() and not output.is_empty(),"explicit package and output")
	check(ProjectSettings.load_resource_pack(package),"mount actual engine/godot.zip")
	check(not FileAccess.file_exists("res://README.md"),"no source tree fallback")
	var Expressions = load("res://scripts/ui/story_expression_art.gd")
	for key in Expressions.PATCHES:
		var texture = load("res://assets/story/expressions/textures/%s_v01.png" % key)
		check(texture != null and texture.get_size() == Expressions.PATCHES[key].size,"packed patch " + key)
	var Screen = load("res://scripts/ui/map_screen.gd")
	var Core = load("res://scripts/core/campaign_engine.gd")
	var Story = load("res://scripts/core/story_state.gd")
	DirAccess.make_dir_recursive_absolute(output)
	root.min_size = Vector2i(320,640)
	for dimensions in [Vector2i(320,640),Vector2i(390,700)]:
		root.size = dimensions
		root.content_scale_size = dimensions
		var ui = Screen.new()
		ui.game = Core.new("user://packed_story.json")
		ui.game.persistence_enabled = false
		root.add_child(ui)
		ui.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
		await frames()
		ui.settings.muted = true
		ui.settings.reduce_motion = true
		ui._start_campaign("PACKED-STORY-EXPRESSIONS")
		await frames()
		for sample in [["intro",10,"hero_guarded"],["intro",13,"prince_weary"],["mid_boss",1,"demon_stern"],["victory",6,"hero_shock"],["victory",8,"prince_sneer"],["victory",15,"reveal"]]:
			ui.game.state.story = {"queue":[],"seen":[]}
			Story.enqueue(ui.game.state,sample[0])
			ui._refresh_map(true)
			await frames()
			ui.story_line = sample[1]
			ui._refresh_map(true)
			await frames()
			var portrait: TextureRect = ui.story_stage.portrait if ui.story_stage.active else ui.body.get_node("StoryPortrait")
			check(portrait.get_meta("story_expression","") == (sample[2] if sample[2] != "reveal" else ""),"packed selection " + sample[2])
			check(Vector2i(ui.size) == dimensions,"actual packed viewport")
			check(ui.overlay_next.get_global_rect().end.y <= dimensions.y+1,"packed continue fits")
			await RenderingServer.frame_post_draw
			var image := root.get_texture().get_image()
			check(image.get_size() == dimensions,"packed capture dimensions")
			check(image.save_png(output+"/%s_%d.png" % [sample[2],dimensions.x]) == OK,"packed capture")
		ui.queue_free()
		await frames()
	print("PACKED STORY EXPRESSIONS %d checks, %d failures" % [checks,failures])
	quit(1 if failures else 0)
