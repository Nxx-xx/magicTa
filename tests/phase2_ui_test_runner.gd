extends SceneTree
## Isolated campaign presentation integration, keyboard input and viewport captures.
const Screen = preload("res://scripts/ui/map_screen.gd")
const Core = preload("res://scripts/core/campaign_engine.gd")
const Art = preload("res://scripts/ui/runtime_art.gd")
var checks := 0
var failures := 0
var capture := false

func _initialize() -> void:
	_run.call_deferred()

func _check(condition: bool, label: String) -> void:
	checks += 1
	if not condition:
		failures += 1
		push_error("FAIL " + label)

func _frames() -> void:
	for i in 6:
		await process_frame

func _capture(label: String) -> void:
	if not capture:
		return
	await RenderingServer.frame_post_draw
	var directory := ProjectSettings.globalize_path("res://build/verification/phase2-ui/")
	DirAccess.make_dir_recursive_absolute(directory)
	_check(root.get_texture().get_image().save_png(directory.path_join(label + ".png")) == OK, "screenshot " + label)

func _key(code: int) -> void:
	var event := InputEventKey.new()
	event.keycode = code
	event.pressed = true
	Input.parse_input_event(event)
	await process_frame
	event.pressed = false
	Input.parse_input_event(event)
	await _frames()

func _run() -> void:
	if not ProjectSettings.globalize_path("user://").replace("\\", "/").contains("phase2-ui"):
		push_error("Requires isolated APPDATA/LOCALAPPDATA under build/verification/phase2-ui")
		quit(2)
		return
	capture = "--capture" in OS.get_cmdline_user_args()
	root.min_size = Vector2i(320,640)
	var screen = Screen.new()
	screen.game = Core.new("user://ui_fixture.json")
	screen.game.persistence_enabled = false
	root.add_child(screen)
	screen.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	await _frames()
	_check(Art.hero("left") != null and Art.hero("right") != null, "hero directional art")
	_check(Art.environment("wall_15") != null, "connected wall art")
	_check(Art.entity_texture({"type":"enemy", "enemy_id":"warlock"}) != null, "monster art")
	_check(Art.entity_texture({"type":"enemy", "enemy_id":"unknown_creature"}) == null, "missing monster art deliberately falls back")
	for dimensions in [Vector2i(540,960), Vector2i(360,640), Vector2i(900,960), Vector2i(320,640)]:
		root.size = dimensions
		screen._start_campaign("UI-PHASE2")
		await _frames()
		_check(screen._is_campaign(), "campaign entry")
		_check(screen.overlay_kind == "story", "story starts before movement")
		_check(screen.overlay_next.is_visible_in_tree() and screen.overlay_close.is_visible_in_tree(), "continue and skip visible")
		_check(screen.overlay_close.get_global_rect().end.y <= screen.size.y + 1, "skip fits viewport")
		var before: Dictionary = screen.game.state.duplicate(true)
		await _key(KEY_DOWN)
		_check(screen.game.state.position == before.position, "story isolates directional input")
		await _key(KEY_TAB)
		var focused: Control = root.gui_get_focus_owner()
		_check(is_instance_valid(focused) and screen.overlay.is_ancestor_of(focused), "story traps Tab focus")
		# Long subtitles must scroll while fixed footer actions remain on-screen.
		screen.game.state.story.queue[0].lines[0].text = "公主握紧归途灯，听着王子从塔顶传来的线索。".repeat(12)
		screen._refresh_map(true)
		await _frames()
		_check(screen.overlay_close.get_global_rect().end.y <= screen.size.y + 1, "long subtitles preserve skip")
		_check(screen.scroll.get_h_scroll_bar().max_value <= screen.scroll.size.x + 1, "no subtitle horizontal scroll")
		await _capture("story_%dx%d" % [dimensions.x, dimensions.y])
		screen.story_line = 2
		screen._refresh_map(true)
		await _frames()
		await _capture("prince_%dx%d" % [dimensions.x, dimensions.y])
		while not screen._story_event().is_empty():
			screen._finish_story()
		await _frames()
		_check(screen.overlay_kind == "", "skip clears story queue")
		_check(screen.board.size.x == screen.board.size.y, "square board")
		_check(screen.controls.get_global_rect().end.y <= screen.size.y + 1, "controls fit")
		await _capture("map_%dx%d" % [dimensions.x, dimensions.y])
		for cell in screen.game.floor_data().entities:
			var entity: Dictionary = screen.game.floor_data().entities[cell]
			if entity.type == "enemy":
				var coordinates: PackedStringArray = cell.split(",")
				screen.selected = Vector2i(int(coordinates[0]), int(coordinates[1]))
				break
		screen._open_overlay("target")
		screen._toggle_pin()
		_check(not screen._floor_pins(1).is_empty(), "target recorded for backtracking")
		screen._close_overlay()
		screen._open_overlay("floors")
		before = screen.game.state.duplicate(true)
		screen.index_floor = 1
		screen._populate_sheet()
		await _frames()
		_check(screen.game.state == before, "floor inspection never mutates run")
		await _capture("floors_%dx%d" % [dimensions.x, dimensions.y])
		screen._close_overlay()
		screen.game.transaction_pending = true
		screen.game.save_error = "磁盘暂时无法写入；此结算等待提交。"
		screen._refresh_map()
		await _frames()
		_check(screen.overlay_kind == "save_blocked", "transaction blocks play")
		_check(screen.direction_buttons[0].disabled and not screen.overlay_close.visible, "blocked save cannot escape into play")
		_check(screen.save_retry.is_visible_in_tree(), "retry remains visible")
		_check(screen.save_error_panel.get_global_rect().end.y <= screen.overlay_panel.position.y, "error banner never covers sheet title")
		await _capture("save_blocked_%dx%d" % [dimensions.x, dimensions.y])
		screen._request_quit()
		await _frames()
		var exit_dialog: ConfirmationDialog
		for child in screen.get_children():
			if child is ConfirmationDialog:
				exit_dialog = child
		_check(is_instance_valid(exit_dialog) and exit_dialog.get_cancel_button().has_focus(), "unsaved exit defaults to cancel")
		_check(exit_dialog.dialog_text.contains("上次成功存档仍保留"), "unsaved exit explains lost changes")
		exit_dialog.canceled.emit()
		await _frames()
		_check(not screen.modal_open and screen.game.transaction_pending, "cancel exit preserves pending transaction")
		screen.game.transaction_pending = false
		screen.game.save_error = ""
		screen.game.state.completed = true
		screen.game.state.result = "victory"
		screen.game.state.last_message = "王子打开了内部的锁。公主与王子一起离开魔塔。"
		screen._refresh_map()
		await _frames()
		_check(screen.overlay_kind == "result", "victory sheet")
		await _capture("result_%dx%d" % [dimensions.x, dimensions.y])
		screen._open_overlay("floors")
		_check(screen.overlay_kind == "floors", "ended run supports read-only floor review")
		screen._close_overlay()
		_check(screen.overlay_kind == "result", "review returns to result")
		screen.page = "menu"
		screen._render(true)
		await _frames()
		await _capture("camp_%dx%d" % [dimensions.x, dimensions.y])
	# New elite/Boss sprites are tested on actual board coordinates at both target sizes.
	screen._start_campaign("UI-BOSS-ART")
	while not screen._story_event().is_empty():
		screen._finish_story()
	var art_ids := ["berserker", "warden", "minotaur", "golem"]
	var art_index := 0
	for entity in screen.game.floor_data().entities.values():
		if entity.type == "enemy" and art_index < art_ids.size():
			entity.enemy_id = art_ids[art_index]
			entity.name = screen.game.db.enemy(entity.enemy_id).name
			entity.campaign_boss = art_index >= 2
			_check(Art.entity_texture(entity) != null, "new monster texture " + art_ids[art_index])
			if entity.campaign_boss:
				_check(Screen.Enemies.map_role(entity) == "楼层首领", "boss role names progress gate")
			art_index += 1
	_check(art_index == 4, "all elite and boss sprites exercised")
	for dimensions in [Vector2i(540,960), Vector2i(360,640)]:
		root.size = dimensions
		screen._refresh_map()
		await _frames()
		await _capture("monsters_%dx%d" % [dimensions.x, dimensions.y])
	# Exercise real death -> story -> result, then UI purchase/refund controls.
	root.size = Vector2i(360,640)
	screen._start_campaign("UI-DEATH")
	while not screen._story_event().is_empty():
		screen._finish_story()
	var target := Vector2i.ZERO
	for cell in screen.game.floor_data().entities:
		var entity: Dictionary = screen.game.floor_data().entities[cell]
		if entity.type == "enemy":
			var coordinates: PackedStringArray = cell.split(",")
			target = Vector2i(int(coordinates[0]), int(coordinates[1]))
			for direction in [Vector2i.UP,Vector2i.DOWN,Vector2i.LEFT,Vector2i.RIGHT]:
				if not screen.game.is_wall(target + direction) and screen.game.entity_at(target + direction).is_empty():
					screen.game.state.position = [target.x + direction.x, target.y + direction.y]
					break
			break
	screen.game.state.player.hp = 1
	screen.game.interact(target)
	screen._act(func(): return screen.game.confirm_interaction(true))
	await _frames()
	_check(screen.game.state.result == "death" and screen.game.meta.failure_count == 1, "real fatal combat settles once")
	_check(screen.overlay_kind == "story" and screen.audio.last_cue.begins_with("echo"), "failure story plays its first cue")
	if ResourceLoader.exists("res://assets/audio/phase2/prince_cry_1.wav"):
		_check(is_instance_valid(screen.audio.player) and screen.audio.player.stream.resource_path.ends_with("prince_cry_1.wav"), "first failure uses imported synthetic voice")
	var audio_tick: int = screen.audio.last_tick
	screen._refresh_map()
	_check(screen.audio.last_tick == audio_tick, "sheet refresh never repeats audio")
	await _capture("failure_360x640")
	screen._finish_story()
	_check(screen.overlay_kind == "result" and screen.game.meta.failure_count == 1, "skip enters settled result")
	screen.game.meta.souls = 32
	screen._start("UI-UPGRADE-TRIAL")
	screen.page = "menu"
	screen._render(true)
	await _frames()
	for button in screen.body.find_children("*", "Button", true, false):
		if button.text.begins_with("消耗 8 灵魂"):
			button.pressed.emit()
			break
	_check(screen.game.meta.upgrades.hp == 1 and screen.game.meta.souls == 24, "purchase button buys one level")
	_check(screen.game.state.player.hp == 100 and screen.game.state.player.max_hp == 100, "camp upgrade during trial leaves trial stats unchanged")
	for button in screen.body.find_children("*", "Button", true, false):
		if button.text.begins_with("免费重置"):
			button.pressed.emit()
			break
	for child in screen.get_children():
		if child is ConfirmationDialog:
			child.confirmed.emit()
	_check(screen.game.meta.upgrades.hp == 0 and screen.game.meta.souls == 32, "confirmed reset refunds actual spend")
	# Real filesystem error: an empty directory prevents opening the .tmp file.
	screen.game = Core.new("user://ui_save_retry_%d.json" % OS.get_process_id())
	screen.game.persistence_enabled = true
	screen._start_campaign("UI-RETRY")
	_check(not screen.game.transaction_pending, "baseline saved before retry fixture")
	var temp_path: String = ProjectSettings.globalize_path(screen.game.store.path + ".tmp")
	_check(DirAccess.make_dir_recursive_absolute(temp_path) == OK, "create safe write-failure fixture")
	screen._finish_story()
	_check(screen._transaction_pending() and screen.overlay_kind == "save_blocked", "failed story acknowledgement opens retry sheet")
	_check(DirAccess.remove_absolute(temp_path) == OK, "remove empty failure fixture")
	screen._retry_save()
	_check(not screen._transaction_pending() and screen.game.state.story.queue.is_empty(), "retry commits acknowledgement and restores input")
	screen.settings.muted = true
	screen.audio.stop()
	screen.audio.play_story(self, "echo_1", screen.settings)
	_check(not is_instance_valid(screen.audio.player), "muted story requires no audio player")
	screen.settings.reduce_motion = true
	screen._flash_board(Color.RED)
	_check(screen.board.modulate == Color.WHITE, "reduced motion prevents flash")
	screen.game.persistence_enabled = false
	screen.queue_free()
	await _frames()
	print("PHASE2 UI checks=%d failures=%d" % [checks, failures])
	quit(0 if failures == 0 else 1)
