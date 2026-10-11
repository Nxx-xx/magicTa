extends SceneTree
const Screen = preload("res://scripts/ui/map_screen.gd")
const Core = preload("res://scripts/core/campaign_engine.gd")
const Contract = preload("res://scripts/core/phase3_contract.gd")
const OUT := "res://build/verification/art-polish-d/regression/phase3/00-integration/"
var checks := 0
var failures := 0
var capture := false
var ui

class RejectStore:
	extends RefCounted
	var last_error := "isolated ruin feedback save failure"
	func write(_run: Dictionary, _meta: Dictionary) -> bool: return false

func _initialize() -> void:
	_run.call_deferred()

func _check(ok: bool, label: String) -> void:
	checks += 1
	if not ok:
		failures += 1
		push_error("FAIL " + label)

func _frames() -> void:
	for i in 8: await process_frame

func _capture(label: String) -> void:
	if not capture: return
	await RenderingServer.frame_post_draw
	_check(root.get_texture().get_image().save_png(OUT + label + ".png") == OK, "capture " + label)

func _run() -> void:
	var isolated := ProjectSettings.globalize_path("user://").replace("\\", "/")
	if not (isolated.contains("phase3/00-integration/") or isolated.contains("phase3/08-parallel/art-polish-d/")):
		quit(2)
		return
	DirAccess.make_dir_recursive_absolute(OUT)
	capture = "--capture" in OS.get_cmdline_user_args()
	root.min_size = Vector2i(320,640)
	for dimensions in [Vector2i(540,960),Vector2i(360,640),Vector2i(900,960),Vector2i(320,640)]:
		root.size = dimensions
		ui = Screen.new()
		ui.page = "menu"
		ui.game = Core.new("user://p3_ui_%d_%d.json" % [dimensions.x,Time.get_ticks_usec()])
		root.add_child(ui)
		ui.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
		await _frames()
		ui.settings.tutorial = ui.Tutorial.initial_state() # Fresh per-suite fixture, independent of capture skip_all.
		ui.settings.muted = true
		ui.settings.reduce_motion = true
		ui.camp_view = "death"
		ui._render(true)
		await _frames()
		var choices = ui.find_child("Phase3Departure",true,false)
		_check(choices != null and choices.selection.ok, "camp contains valid challenge selector")
		_check(choices._challenge.is_item_disabled(1), "new account cannot select locked C1")
		_check(ui.scroll.get_h_scroll_bar().max_value <= ui.scroll.size.x + 1, "camp has no horizontal overflow")
		_check(choices.get_global_rect().end.x <= ui.size.x, "challenge controls are not clipped horizontally")
		await _capture("camp_%d" % dimensions.x)
		ui._start_phase3("42")
		await _frames()
		_check(ui.game.is_phase3() and ui.overlay_kind == "story", "production departure and story priority")
		while not ui._story_event().is_empty(): ui._finish_story()
		await _frames()
		_check(ui.game.meta.codex.seen_story_nodes.size() > 0, "story viewing saved to codex")
		_check(ui.tutorial_view.visible, "tutorial restored after story")
		_check(ui.tutorial_view.size.y < 160, "coach prompt stays compact over map")
		_check(ui.controls.get_global_rect().end.y <= ui.size.y + 1, "map controls fit")
		await _capture("map_%d" % dimensions.x)
		var branch: Array = ui.game.floor_data().branch_paths[0]
		var enemy := Vector2i(branch[0][0],branch[0][1])
		ui.selected = enemy
		ui._open_overlay("target")
		await _frames()
		_check(ui.game.meta.codex.seen_enemies.size() > 0, "enemy inspection registers discovery")
		_check(ui.overlay_close.get_global_rect().end.y <= ui.size.y + 1, "preview footer fits")
		await _capture("preview_%d" % dimensions.x)
		ui._close_overlay()
		_check(_walk(enemy), "walk to real first enemy")
		ui._render(true)
		ui.settings.reduce_motion = false # Inspect the replay before ordinary victory auto-closes.
		ui._fight()
		await _frames()
		_check(is_instance_valid(ui.combat_view), "committed battle opens new player")
		var committed: Dictionary = ui.game.state.duplicate(true)
		if is_instance_valid(ui.combat_view):
			_check(ui.combat_view._primary.get_global_rect().end.y <= ui.size.y + 1, "combat footer fits")
			await _capture("combat_%d" % dimensions.x)
			ui._combat_escape()
			if is_instance_valid(ui.combat_view): ui._combat_escape()
		await _frames()
		_check(Contract.same_json(committed,ui.game.state), "playback and closing never settle twice")
		_check(_walk(Vector2i(branch[1][0],branch[1][1])), "walk to earned equipment")
		while not ui._story_event().is_empty(): ui._finish_story()
		ui._open_overlay("inventory")
		await _frames()
		await _capture("inventory_%d" % dimensions.x)
		ui._close_overlay()
		var exit_cell := Vector2i(ui.game.floor_data().exit[0],ui.game.floor_data().exit[1])
		_check(_walk(exit_cell), "real stairs approach")
		_check(ui.game.confirm_interaction().is_empty() and ui.game.state.floor == 2, "enter generated ruin floor without theme selection")
		while not ui._story_event().is_empty(): ui._finish_story()
		var ruin := Vector2i(-1,-1)
		for entity in ui.game.floor_data().entities.values():
			if entity.has("ruin_id"): ruin = Vector2i(entity.pos[0],entity.pos[1])
		_check(_walk(ruin), "walk to real ruin")
		ui._render(true)
		await _frames()
		var panel = ui.find_child("Phase3Ruin",true,false)
		_check(panel != null and not panel.option_button("edge").disabled, "production ruin panel shows legal option")
		if panel != null:
			_check(panel.leave_button().get_global_rect().end.y <= ui.size.y + 1, "ruin leave control fits")
			await _capture("ruin_%d" % dimensions.x)
			panel.option_selected.emit("edge")
			await _frames()
			_check(ui.modal_open and ui.game.entity_at(ruin).status == "available", "ruin confirmation precedes mutation")
			ui.settings.reduce_motion = dimensions.x == 320
			ui.board.reduce_motion = ui.settings.reduce_motion
			ui.settings.muted = false
			ui.audio.last_tick = -1000
			var original_store = ui.game.store
			if dimensions.x == 540: ui.game.store = RejectStore.new()
			for child in ui.get_children():
				if child is ConfirmationDialog: child.confirmed.emit()
			if dimensions.x == 540:
				_check(ui.game.transaction_pending and ui.game.entity_at(ruin).status == "available","failed ruin save keeps original state")
				_check(ui.board.interaction_started < 0 and ui.board.ruin_art.playing.is_empty() and ui.audio.last_cue.is_empty(),"failed save has no success motion or sound")
				ui.game.store = original_store
				ui._retry_save()
			_check((ui.board.interaction_started >= 0) == not ui.settings.reduce_motion,"saved ruin interaction respects reduced motion")
			_check(ui.audio.last_cue == "door","committed oath ruin uses shipped stone sound once")
			var played_at: int = ui.audio.last_tick
			ui._consume_tutorial_evidence()
			_check(ui.audio.last_tick == played_at,"consumed feedback cannot replay on refresh")
			ui.settings.muted = true
			await _frames()
			_check(not ui.modal_open and not ui.game.transaction_pending and ui.game.entity_at(ruin).status == "resolved", "confirmation commits ruin through host")
			_check(ui.board.ruin_art.states.get(str(ui.game.entity_at(ruin).id)) == "resolved", "board observes committed ruin state")
			_check(ui.board.ruin_art.texture(ui.game.entity_at(ruin),ui.board.idle_seconds) != null, "production ruin uses accepted animation")
			await _capture("ruin_resolved_%d" % dimensions.x)
			_check(ui.game.abandon_run().is_empty(), "fixture ends through production settlement")
			ui._render(true)
			await _frames()
			_check(ui.overlay_kind == "result" and ui.settings.tutorial.nodes.T08.triggered, "result triggers camp guidance")
			await _capture("result_%d" % dimensions.x)
			ui.page = "codex"
			ui._render(true)
			await _frames()
			var codex = ui.find_child("Phase3Codex",true,false)
			_check(codex != null and codex.rows.size() > 0, "discovered content reaches production codex")
			_check(codex.get_global_rect().end.x <= ui.size.x, "codex fits horizontally")
			await _capture("codex_%d" % dimensions.x)
		root.remove_child(ui)
		ui.queue_free()
		await _frames()
	print("PHASE3_UI_HOST checks=%d failures=%d" % [checks,failures])
	quit(1 if failures else 0)

func _walk(target: Vector2i) -> bool:
	var core = ui.game
	core.cancel_pending()
	var start: Vector2i = core.position()
	var queue: Array[Vector2i] = [start]
	var previous := {start:start}
	while not queue.is_empty() and not previous.has(target):
		var current: Vector2i = queue.pop_front()
		for direction in [Vector2i.UP,Vector2i.DOWN,Vector2i.LEFT,Vector2i.RIGHT]:
			var next: Vector2i = current + direction
			if core.is_wall(next) or previous.has(next): continue
			if next != target and core.entity_at(next).get("type", "") in ["enemy","door","up","down"]: continue
			previous[next] = current
			queue.append(next)
	if not previous.has(target): return false
	var path: Array[Vector2i] = []
	var cursor := target
	while cursor != start:
		path.push_front(cursor)
		cursor = previous[cursor]
	for cell in path:
		if not core.step(cell-core.position()).is_empty() or core.transaction_pending: return false
		if cell != target and not core.state.pending.is_empty(): core.cancel_pending()
	if path.is_empty(): return core.interact(target).is_empty()
	return true
