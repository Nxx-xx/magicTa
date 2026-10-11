extends "res://tests/phase3_ui_host_test_runner.gd"
const REPLAY_OUT := "res://build/verification/art-polish-c/host-slime/"

class FailStore:
	extends RefCounted
	var last_error := "isolated replay capture storage fault"
	func write(_run: Dictionary, _meta: Dictionary) -> bool: return false

func _run() -> void:
	if not ProjectSettings.globalize_path("user://").replace("\\", "/").contains("08-parallel/art-polish-c/"):
		quit(2)
		return
	root.min_size = Vector2i(320,640)
	root.size = Vector2i(540,960)
	ui = Screen.new()
	ui.game = Core.new("user://replay_capture_%d.json" % Time.get_ticks_usec())
	root.add_child(ui)
	ui.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	await _frames()
	ui.settings.muted = true
	ui.settings.reduce_motion = false
	ui._start_phase3("42")
	await _frames()
	while not ui._story_event().is_empty(): ui._finish_story()
	var branch: Array = ui.game.floor_data().branch_paths[0]
	_check(_walk(Vector2i(branch[0][0],branch[0][1])),"production movement to slime")
	ui._render(true)
	var store = ui.game.store
	ui.game.store = FailStore.new()
	var state: Dictionary = ui.game.state.duplicate(true)
	ui._fight()
	await _frames()
	_check(not is_instance_valid(ui.combat_view),"failed save cannot show successful replay")
	_check(ui.game.state == state and ui.game.transaction_pending,"failed save preserves state and pending candidate")
	ui.game.store = store
	_check(ui.game.retry_save(),"same candidate retry commits")
	ui._render(true)
	ui._present_combat()
	_check(is_instance_valid(ui.combat_view),"retry creates replay only after commit")
	var replay = ui.combat_view
	replay.set_process(false)
	var committed: Dictionary = ui.game.state.duplicate(true)
	var account: Dictionary = ui.game.meta.duplicate(true)
	DirAccess.make_dir_recursive_absolute(REPLAY_OUT+"host-frames")
	for frame in 26:
		if replay._finished:
			replay._process(.1)
		else:
			replay.advance(0.1 if frame > 0 else 0)
		await process_frame
		await RenderingServer.frame_post_draw
		root.get_texture().get_image().save_png(REPLAY_OUT+"host-frames/%02d.png" % frame)
	_check(replay._enemy_sprite.texture != null and replay._enemy_player.actions.size() == 4,"real slime uses four accepted actions")
	_check(ui.game.state == committed and ui.game.meta == account,"entire visual replay has zero gameplay writes")
	replay.close()
	await _frames()
	_check(ui.game.state == committed and ui.game.meta == account,"close cannot duplicate rewards")
	ui.game.load_game()
	_check(Contract.same_json(ui.game.state.player,committed.player) and Contract.same_json(ui.game.meta,account),"reload preserves result resources")
	FileAccess.open(REPLAY_OUT+"host-replay-results.json",FileAccess.WRITE).store_string(JSON.stringify({"checks":checks,"failures":failures,"provenance":"real C0 seed42 first slime fight; failed save then same-candidate retry; 26 frames at 10fps; current production hero and slime; final animations keep advancing"},"\t"))
	print("REPLAY_HOST checks=%d failures=%d" % [checks,failures])
	quit(1 if failures else 0)

