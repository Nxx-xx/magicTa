extends SceneTree
const Screen = preload("res://scripts/ui/map_screen.gd")
const Core = preload("res://scripts/core/campaign_engine.gd")
const Prototype = preload("res://scripts/core/map_engine.gd")
const Store = preload("res://scripts/core/campaign_save.gd")
const Progress = preload("res://scripts/core/campaign_progress.gd")
var failures := 0
var checks := 0

func _initialize() -> void: _run.call_deferred()

func check(ok: bool, label: String) -> void:
	checks += 1
	if not ok:
		failures += 1
		push_error("FAIL " + label)

func frames() -> void:
	for i in 8: await process_frame

func _run() -> void:
	if not "trial-removal" in ProjectSettings.globalize_path("user://"):
		quit(2)
		return
	var path := "user://retired_%d.json" % Time.get_ticks_usec()
	var prototype := Prototype.new(path)
	prototype.persistence_enabled = false
	check(prototype.start("42").is_empty(), "construct old save fixture")
	var account := Progress.default_meta()
	account.souls = 16
	account.souls_earned_total = 24
	account.upgrades.hp = 1
	account.upgrade_spend.hp = 8
	check(Store.new(path).write(prototype.state, account), "write valid old account")
	var original := FileAccess.get_file_as_string(path)
	var ui = Screen.new()
	ui.game = Core.new(path)
	root.add_child(ui)
	ui.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	await frames()
	check(ui.game.state.is_empty() and not ui.game.active(), "old trial is not resumed")
	check(ui.game.meta.souls == 16 and ui.game.meta.upgrades.hp == 1, "account retained")
	check(FileAccess.get_file_as_string(path) == original, "load leaves old disk save intact")
	check(ui.find_child("ContinueGame",true,false).disabled, "retired run cannot continue")
	check(not ui.game.start("retired").is_empty() and ui.game.state.is_empty(), "core rejects prototype creation")
	ui._show_camp()
	ui._camp_interact("tower")
	await frames()
	for node in ui.body.find_children("*", "Control", true, false):
		if node is Label or node is Button:
			check(not "试炼" in node.text and not "两层" in node.text, "departure has no retired mode copy")
	ui._request_start("new-campaign")
	await frames()
	check(ui.game.is_phase3() and ui.game.active() and ui.page == "map", "sole start path opens current ten-floor campaign")
	check(ui.game.state.player.max_hp == 105 and ui.game.meta.souls == 16, "new campaign applies preserved account")
	var resumed := Core.new(path)
	resumed.load_game()
	check(resumed.is_phase3() and resumed.active(), "new campaign survives reload")
	ui.queue_free()
	await frames()
	print("TRIAL REMOVAL: %d checks, %d failures" % [checks, failures])
	quit(1 if failures else 0)
