extends SceneTree
const Screen = preload("res://scripts/ui/map_screen.gd")
const Core = preload("res://tests/legacy_map_core_fixture.gd")
var checks := 0
var failures := 0
var capture := false

class TestStore extends RefCounted:
	var fail := true
	var last_error := "测试：保存失败"
	func write(_state: Dictionary, _meta: Dictionary) -> bool:
		return not fail

func _initialize() -> void:
	_run.call_deferred()

func _check(value: bool, label: String) -> void:
	checks += 1
	if not value:
		failures += 1
		push_error("FAIL: " + label)

func _frames() -> void:
	for index in 6:
		await process_frame

func _capture(label: String) -> void:
	if capture:
		await RenderingServer.frame_post_draw
		var path := "res://build/verification/art-polish-c/legacy/" + label + ".png"
		_check(root.get_texture().get_image().save_png(path) == OK, "capture " + label)

func _fixture(screen, lethal: bool = false) -> void:
	if is_instance_valid(screen.combat_view):
		screen._finish_combat()
	screen.game = Core.new("user://combat_fixture.json")
	screen.game.persistence_enabled = false
	screen.game.start("42")
	screen.game.state.position = [5,5]
	screen.game.floor_data().rows[5] = "#.........#"
	screen.game.floor_data().entities["6,5"] = {"type":"enemy", "enemy_id":"knight", "id":"test-knight", "name":"铁甲骑士", "pos":[6,5]}
	screen.game.db.data.enemies.knight.hp = 45
	screen.game.db.data.enemies.knight.attack = 11
	screen.game.db.data.enemies.knight.defense = 2
	# Full result/report controls are retained for elite fights; ordinary auto-close
	# is covered by encounter_ui_test_runner.
	screen.game.db.data.enemies.knight.rank = "elite"
	screen.game.state.player.hp = 1 if lethal else 100
	screen.game.state.pending = {"kind":"entity", "pos":[6,5]}
	screen.game.save_game()
	screen.settings.reduce_motion = false
	screen.page = "map"
	screen.overlay_kind = "pending"
	screen._render(true)

func _run() -> void:
	if not "art-polish-c" in ProjectSettings.globalize_path("user://"):
		push_error("Run with isolated APPDATA/LOCALAPPDATA under build/verification/combat-presentation")
		quit(2)
		return
	capture = "--capture" in OS.get_cmdline_user_args()
	root.min_size = Vector2i.ZERO
	var screen = Screen.new()
	screen.game = Core.new("user://combat_fixture.json")
	screen.game.persistence_enabled = false
	root.add_child(screen)
	screen.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	await _frames()
	screen.settings.muted = true
	for dimensions in [Vector2i(320,640), Vector2i(360,640), Vector2i(540,960), Vector2i(900,960)]:
		root.size = dimensions
		_fixture(screen)
		await _frames()
		var expected: Dictionary = screen.game.preview(Vector2i(6,5))
		var gold_before: int = screen.game.state.player.gold
		screen._fight()
		await _frames()
		var view = screen.combat_view
		_check(is_instance_valid(view) and screen.overlay_kind == "combat", "fight opens playback")
		_check(not screen.overlay.visible and not screen._can_walk(), "background blocked")
		_check(int(screen.game.state.player.gold) == gold_before + int(expected.gold_reward), "one committed reward")
		_check(int(screen.game.state.player.hp) == int(expected.hp_after), "real HP committed before playback")
		var committed: Dictionary = screen.game.state.duplicate(true)
		screen._fight()
		screen._move_direction(Vector2i.LEFT)
		screen._select_cell(Vector2i(4,5))
		_check(screen.game.state == committed, "repeat challenge and movement blocked")
		view.set_process(false)
		view.elapsed = 0.2 + 0.64 * 0.36
		view.queue_redraw()
		await _frames()
		var suffix := "%dx%d" % [dimensions.x, dimensions.y]
		await _capture("fight_" + suffix)
		view.primary.pressed.emit()
		view.celebration = 1.0
		view.queue_redraw()
		await _frames()
		_check(view.settled and view.report == expected, "skip uses exact report")
		_check(view.primary.size.y >= 44 and view.secondary.size.y >= 44, "accessible actions")
		_check(Rect2(Vector2.ZERO, screen.size).encloses(view.primary.get_global_rect()), "continue on screen " + suffix)
		_check(Rect2(Vector2.ZERO, screen.size).encloses(view.secondary.get_global_rect()), "report on screen " + suffix)
		_check(view.context.final_hp == screen.game.state.player.hp, "HUD and settlement agree")
		_check(view.hero != null and view.foe != null and view.victory != null, "runtime textures available")
		await _capture("victory_" + suffix)
		view.secondary.pressed.emit()
		await _frames()
		_check(view.showing_log and view.log_panel.visible, "full report opens inside modal")
		_check(view.log_scroll.get_h_scroll_bar().max_value <= view.log_scroll.size.x + 1, "report wraps")
		var event := InputEventKey.new()
		event.keycode = KEY_TAB
		event.pressed = true
		Input.parse_input_event(event)
		await _frames()
		_check(view.is_ancestor_of(root.gui_get_focus_owner()), "Tab stays inside combat")
		await _capture("report_" + suffix)
		view.escape()
		_check(not view.showing_log and view.settled, "escape returns to settlement")
		view.primary.pressed.emit()
		await _frames()
		_check(not is_instance_valid(screen.combat_view) and screen.overlay_kind == "", "continue returns to map")
		_check(screen.game.state == committed, "skip report continue never mutate reward")
	# Natural finish, reduced motion, defeat, failed save and retry.
	_fixture(screen)
	screen._fight()
	screen.combat_view._process(10.0)
	_check(screen.combat_view.settled, "natural playback completes")
	screen._finish_combat()
	_fixture(screen)
	screen.settings.reduce_motion = true
	screen._fight()
	_check(screen.combat_view.settled and screen.combat_view.reduce_motion, "reduce motion goes straight to result")
	screen._finish_combat()
	_fixture(screen)
	screen.game.db.data.enemies.knight.hp = 1000
	screen.game.state.player.defense = 100
	screen._fight()
	_check(screen.combat_view.beats.size() == 6 and screen.combat_view.report.log.size() > 6, "long combat bounded with full log retained")
	_check(screen.combat_view.beats.back() == screen.combat_view.report.log.back(), "condensed combat includes final hit")
	screen._finish_combat()
	_fixture(screen, true)
	screen._fight()
	screen.combat_view.settle()
	_check(not screen.combat_view.report.won, "defeat never shows victory")
	screen._finish_combat()
	_check(screen.overlay_kind == "result", "defeat routes to existing restart")
	_fixture(screen)
	var test_store := TestStore.new()
	screen.game.store = test_store
	screen.game.persistence_enabled = true
	var before: Dictionary = screen.game.state.duplicate(true)
	screen._fight()
	_check(screen.game.transaction_pending and screen.overlay_kind == "save_blocked", "save failure precedes playback")
	_check(not is_instance_valid(screen.combat_view), "no celebration of uncommitted rewards")
	_check(screen.game.state.player == before.player, "failed save rolled back resources")
	screen._retry_save()
	_check(not is_instance_valid(screen.combat_view), "failed retry stays blocked")
	test_store.fail = false
	screen._retry_save()
	_check(is_instance_valid(screen.combat_view) and screen.overlay_kind == "combat", "successful retry starts replay")
	var after: Dictionary = screen.game.state.duplicate(true)
	screen._retry_save()
	_check(screen.game.state == after, "retry does not repeat combat")
	screen._finish_combat()
	# Boss healing and story progression use actual campaign rules, after combat dismissal.
	for floor_number in [5, 10]:
		screen.game = Core.new("user://boss_fixture.json")
		screen.game.persistence_enabled = false
		screen.game.start_campaign("42")
		screen.game.state.story.queue.clear()
		var floor_data: Dictionary = screen.game.campaign_generator.generate(screen.game.state.campaign_plan, floor_number, "boss")
		screen.game.state.floors[str(floor_number)] = floor_data
		screen.game.state.floor = floor_number
		for key in floor_data.entities:
			var entity: Dictionary = floor_data.entities[key]
			if not entity.get("campaign_boss", false):
				continue
			var cell: PackedStringArray = str(key).split(",")
			screen.game.db.data.enemies[entity.enemy_id].hp = 1
			screen.game.db.data.enemies[entity.enemy_id].defense = 0
			screen.game.state.player.hp = 25
			screen.game.state.pending = {"kind":"entity", "pos":[int(cell[0]),int(cell[1])]}
			break
		screen.game.save_game()
		screen.overlay_kind = "pending"
		screen._render(true)
		screen._fight()
		_check(is_instance_valid(screen.combat_view) and screen.combat_view.report.won, "boss victory shows combat settlement")
		_check(screen.combat_view.context.final_hp == screen.game.state.player.hp, "boss post-combat healing included")
		if floor_number == 5:
			_check(int(screen.combat_view.context.final_hp) > int(screen.combat_view.report.hp_after), "midpoint bonus healing distinct from kill healing")
		else:
			_check(screen.game.state.result == "victory" and screen.combat_view.context.run_ended, "final boss keeps campaign ending")
		screen.combat_view.settle()
		screen.combat_view.primary.pressed.emit()
		_check(screen.overlay_kind in ["story", "result"] if floor_number == 10 else screen.overlay_kind in ["story", ""], "boss dismissal resumes campaign flow")
	screen.queue_free()
	await _frames()
	print("Combat presentation: %d checks, %d failures" % [checks, failures])
	quit(1 if failures else 0)

