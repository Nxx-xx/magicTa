extends SceneTree
const Screen = preload("res://scripts/ui/map_screen.gd")
const Core = preload("res://scripts/core/campaign_engine.gd")
const Story = preload("res://scripts/core/story_state.gd")
const OUT := "res://build/verification/art-polish-d/regression/story-intro/"
var checks := 0
var failures := 0
var capture := false

func _initialize() -> void: _run.call_deferred()

func check(ok: bool, label: String) -> void:
	checks += 1
	if not ok:
		failures += 1
		push_error("FAIL " + label)

func frames() -> void:
	for i in 10: await process_frame

func shot(label: String) -> void:
	if not capture: return
	await RenderingServer.frame_post_draw
	check(root.get_texture().get_image().save_png(OUT + label + ".png") == OK, "capture " + label)

func _run() -> void:
	if not ProjectSettings.globalize_path("user://").replace("\\", "/").contains("phase3/08-parallel/art-polish-d/"):
		quit(2)
		return
	DirAccess.make_dir_recursive_absolute(OUT)
	capture = "--capture" in OS.get_cmdline_user_args()
	root.min_size = Vector2i(320,640)
	var ui = Screen.new()
	ui.game = Core.new("user://story_intro.json")
	ui.game.persistence_enabled = false
	root.add_child(ui)
	ui.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	await frames()
	ui.settings.muted = true
	for dimensions in [Vector2i(540,960), Vector2i(360,640), Vector2i(320,640), Vector2i(900,960)]:
		root.size = dimensions
		ui.game = Core.new("user://story_intro_%d.json" % dimensions.x)
		ui.game.persistence_enabled = false
		ui._start_campaign("STORY-INTRO")
		await frames()
		check(ui.story_stage.active, "opening uses illustrated stage")
		check(not ui.story_stage.portrait.visible, "narration shows environment alone")
		check(ui.story_stage.get_node("TowerEntranceBackground").texture != null, "background loads")
		check(ui.overlay_next.get_global_rect().end.y <= ui.size.y + 1, "continue fits")
		check(ui.overlay_close.get_global_rect().end.x <= ui.size.x + 1, "skip fits")
		await shot("narration_%d" % dimensions.x)
		var before: Dictionary = ui.game.state.duplicate(true)
		ui.overlay_next.pressed.emit()
		ui.overlay_next.pressed.emit()
		await frames()
		check(ui.story_line == 2 and ui.story_stage.portrait.visible, "continue shows princess")
		check(ui.game.state == before, "reading lines does not mutate run")
		check(ui.scroll.get_v_scroll_bar().max_value <= ui.scroll.size.y + 1, "normal dialogue fits without scrolling")
		check(ui.story_stage.portrait.get_global_rect().position.y > 100, "portrait leaves chapter clear")
		await shot("princess_%d" % dimensions.x)
		ui.story_line = 7
		ui._refresh_map(true)
		await frames()
		check(ui.story_stage.portrait.visible, "remote speaker has portrait")
		if dimensions.x == 540: await shot("transmission_540")
		ui.game.state.story.queue[0].lines[7].text = "公主握紧归途灯，听着王子从塔顶传来的线索。".repeat(15)
		ui._refresh_map(true)
		await frames()
		print("LONG ",dimensions," max=",ui.scroll.get_v_scroll_bar().max_value," viewport=",ui.scroll.size," panel=",ui.overlay_panel.size)
		check(ui.body.get_global_rect().end.y <= ui.scroll.get_global_rect().end.y + 1 or ui.scroll.get_v_scroll_bar().max_value > ui.scroll.size.y, "long dialogue fully fits or remains scroll accessible")
		check(ui.overlay_next.get_global_rect().end.y <= ui.size.y + 1, "long dialogue keeps continue accessible")
		check(ui.scroll.get_h_scroll_bar().max_value <= ui.scroll.size.x + 1, "dialogue never scrolls horizontally")
		ui.overlay_close.pressed.emit()
		await frames()
		while not ui._story_event().is_empty(): ui._finish_story()
		await frames()
		check(not ui.story_stage.active and ui.overlay_kind == "", "skip restores map")
		ui._open_overlay("floors")
		await frames()
		check(ui.overlay_title.is_visible_in_tree() and ui.overlay_close.is_visible_in_tree(), "ordinary sheet restores title and close")
		check(ui.overlay_close.get_parent() == ui.story_stage.close_parent, "close restored to original action row")
		ui._close_overlay()
		Story.enqueue(ui.game.state, "retry")
		ui._refresh_map(true)
		await frames()
		check(ui.story_stage.active and ui.story_stage.chapter.text == "再启旅程", "retry restores opening location")
		ui._finish_story()
		Story.on_victory(ui.game.state)
		ui._refresh_map(true)
		await frames()
		check(not ui.story_stage.active and ui.overlay_title.visible, "ending keeps its own illustration presentation")
		ui._finish_story()
	root.remove_child(ui)
	ui.free()
	print("Story intro UI: %d checks, %d failures" % [checks, failures])
	quit(1 if failures else 0)
