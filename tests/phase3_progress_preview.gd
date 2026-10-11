extends SceneTree
const P = preload("res://scripts/core/phase3_progress.gd")
const Old = preload("res://scripts/core/campaign_progress.gd")
const ChallengePanel = preload("res://scripts/ui/phase3_challenge_panel.gd")
const CodexPanel = preload("res://scripts/ui/phase3_codex_panel.gd")
var capture := false
var container: MarginContainer
var theme: Theme
var failures := 0

func _initialize() -> void:
	capture = "--capture" in OS.get_cmdline_user_args()
	_run.call_deferred()

func _run() -> void:
	root.content_scale_mode = Window.CONTENT_SCALE_MODE_DISABLED
	root.content_scale_size = Vector2i.ZERO
	root.size = Vector2i(920,920)
	theme = Theme.new()
	theme.default_font = load("res://assets/fonts/ui_font.tres")
	theme.default_font_size = 18
	var background := ColorRect.new()
	background.color = Color("101c2a")
	background.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	root.add_child(background)
	container = MarginContainer.new()
	container.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	for key in ["margin_left","margin_top","margin_right","margin_bottom"]:
		container.add_theme_constant_override(key,32)
	container.theme = theme
	root.add_child(container)
	var meta := P.migrate_meta(Old.default_meta())
	meta.unlocked_ids.append_array(["p3_c1","p3_c2","p3_keeper","p3_vanguard","p3_trader"])
	meta.upgrades = {"hp":0,"attack":0,"gold":3}
	meta.achievement_ids = ["p3_first_midboss","p3_sustain_20","p3_shop_30","p3_c0_clear"]
	var panel := ChallengePanel.new()
	container.add_child(panel)
	panel.setup(meta)
	panel.select_ids("p3_c2","p3_trader")
	panel.show_unlocks(meta.achievement_ids,true)
	await frames()
	if capture:
		await screenshot("challenge-desktop")
		root.size = Vector2i(540,960)
		await frames()
		await screenshot("challenge-mobile")
		container.remove_child(panel)
		panel.queue_free()
		var codex := CodexPanel.new()
		container.add_child(codex)
		meta.codex.seen_enemies = ["minotaur", "berserker"]
		meta.codex.enemy_records = {"minotaur|2|p3_c0":{"enemy_id":"minotaur","combat_rules_version":2,"challenge_id":"p3_c0","count":2,"samples":2,"min_incoming":14}, "minotaur|2|p3_c2":{"enemy_id":"minotaur","combat_rules_version":2,"challenge_id":"p3_c2","count":1,"samples":1,"min_incoming":36}}
		var content: Dictionary = JSON.parse_string(FileAccess.get_file_as_string("res://data/content.json"))
		content.story = {"secret":{"name":"不可泄露的标题", "description":"不可泄露的剧情", "illustration":"secret.png"}}
		codex.setup(meta,content,"p3_c2")
		await frames()
		await screenshot("codex-enemies-mobile")
		codex.show_category("story")
		await frames()
		await screenshot("codex-story-redacted")
		container.remove_child(codex)
		codex.queue_free()
		root.size = Vector2i(920,540)
		var grid := GridContainer.new()
		grid.columns = 7
		grid.add_theme_constant_override("h_separation",14)
		container.add_child(grid)
		for id in ["p3_c0","p3_c1","p3_c2","default","p3_vanguard","p3_keeper","p3_trader"]:
			var column := VBoxContainer.new()
			grid.add_child(column)
			var defs: Dictionary = P.definitions().challenges
			var label := Label.new()
			label.text = defs.challenges.get(id,defs.start_configs.get(id,{})).name
			label.add_theme_font_size_override("font_size",14)
			column.add_child(label)
			for pixels in [96,48,32]:
				var texture := TextureRect.new()
				texture.texture = ChallengePanel.badge(id)
				texture.custom_minimum_size = Vector2(pixels,pixels)
				texture.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
				texture.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
				column.add_child(texture)
		await frames()
		await screenshot("badges-contact-sheet")
		print("PHASE3_PROGRESS_PREVIEW captures=5 failures=%d" % failures)
		quit(1 if failures else 0)

func frames() -> void:
	for index in 6:
		await process_frame

func screenshot(name_value: String) -> void:
	await RenderingServer.frame_post_draw
	var path := "res://build/verification/phase3/04-progress/%s.png" % name_value
	if root.get_texture().get_image().save_png(path) != OK:
		failures += 1
