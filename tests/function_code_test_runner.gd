extends SceneTree
const Core = preload("res://scripts/core/campaign_engine.gd")
const Screen = preload("res://scripts/ui/map_screen.gd")
const Contract = preload("res://scripts/core/phase3_contract.gd")
const Codes = preload("res://scripts/core/function_codes.gd")
const Rewards = preload("res://scripts/core/rewards.gd")
var checks := 0
var failures := 0

class KeyboardBridge:
	extends RefCounted
	var update := ""
	var closed := false
	func show(_text: String, _limit: int) -> int:
		closed = false
		return 1
	func read(_session: int) -> String:
		var result := update
		update = ""
		return result
	func hide(_session: int) -> void: closed = true

class RejectStore:
	extends RefCounted
	var last_error := "function code test save rejected"
	func write(_run: Dictionary, _meta: Dictionary) -> bool: return false

func _initialize() -> void: _run.call_deferred()

func check(ok: bool, label: String) -> void:
	checks += 1
	if not ok:
		failures += 1
		push_error("FAIL " + label)

func frames() -> void:
	for i in 8: await process_frame

func capture(label: String) -> void:
	if not "--capture" in OS.get_cmdline_user_args() or root.size.x != 540: return
	await RenderingServer.frame_post_draw
	check(root.get_texture().get_image().save_png("res://build/verification/function-code/" + label + ".png") == OK, "capture " + label)

func boosted(game) -> bool:
	var stats: Dictionary = game.stats()
	return game.state.player.hp == 1000 and stats.max_hp == 1000 and stats.attack == 1000 and stats.defense == 1000

func _run() -> void:
	if not "function-code" in ProjectSettings.globalize_path("user://"):
		quit(2)
		return
	for phase3 in [false, true]:
		var path := "user://code_%s_%d.json" % [phase3, Time.get_ticks_usec()]
		var game = Core.new(path)
		check(not game.apply_function_code("NXX").is_empty() and game.state.is_empty(), "code requires active journey")
		check((game.start_phase3("42") if phase3 else game.start_campaign("42")).is_empty(), "start test journey")
		# Explicit equipment fixture: one non-unique item for each boosted stat.
		for field in Codes.FIELDS:
			for id in game.db.data.items:
				var item: Dictionary = game.db.data.items[id]
				if not item.get("unique_per_run", false) and int(item.get("effects", {}).get(field, 0)) > 0:
					var reward := Rewards.resolve(game.db, game.state.player, {"item_id":id})
					check(reward.ok, "equipment fixture resolves")
					game.state.player = reward.player
					break
		check(game.save_game(), "equipment fixture saves")
		var before: Dictionary = game.state.duplicate(true)
		check(not game.apply_function_code("wrong").is_empty() and Contract.same_json(before, game.state), "wrong code changes nothing")
		var store = game.store
		game.store = RejectStore.new()
		check(not game.apply_function_code("NXX").is_empty() and game.transaction_pending, "failed code save creates pending transaction")
		check(Contract.same_json(before, game.state), "failed code save restores original stats")
		check(not game.apply_function_code("NXX").is_empty(), "pending save blocks duplicate activation")
		game.store = store
		check(game.retry_save() and boosted(game), "retry persists exact 1000 stats including equipment")
		check(game.state.player.equipment_ids == before.player.equipment_ids and game.state.player.relic_ids == before.player.relic_ids, "activation retains all items")
		check(game.apply_function_code(" nxx ").is_empty() and boosted(game), "code accepts case and whitespace without stacking")
		var loaded = Core.new(path)
		loaded.load_game()
		check(loaded.active() and boosted(loaded), "reload retains boosted stats")
		var reward := Rewards.resolve(loaded.db, loaded.state.player, {"effects":{"attack":2,"defense":3,"max_hp":5,"heal":5}})
		check(reward.ok and reward.after.attack == 1002 and reward.after.defense == 1003 and reward.after.max_hp == 1005 and reward.player.hp == 1005, "later upgrades and healing still work normally")
		loaded.state.player = reward.player
		check(loaded.save_game(), "later rewards save with code baseline")
		check(loaded.apply_function_code("NXX").is_empty() and boosted(loaded), "reapplying restores exactly 1000")
		check(not Codes.valid({"function_code_offsets":{"attack":-1,"defense":0,"max_hp":0}}), "invalid code offsets rejected")
		check(loaded.abandon_run().is_empty(), "boosted run can end normally")
		check(not loaded.apply_function_code("NXX").is_empty(), "ended run cannot be revived by code")
		check(loaded.start_phase3("43").is_empty() and loaded.stats().attack == 10 and loaded.state.player.hp == 100 and not loaded.state.player.has("function_code_offsets"), "new game restores normal initial stats")
	for dimensions in [Vector2i(320,640), Vector2i(540,960)]:
		root.min_size = Vector2i(320,640)
		root.size = dimensions
		var ui = Screen.new()
		ui.game = Core.new("user://code_ui_%d.json" % Time.get_ticks_usec())
		root.add_child(ui)
		ui.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
		await frames()
		ui.settings.muted = true
		ui._start_phase3("42")
		while not ui.game.story_event().is_empty(): ui.game.acknowledge_story()
		ui._render(true)
		await frames()
		var button: Button = ui.find_child("OpenFunctionCode",true,false)
		check(button.is_visible_in_tree() and button.get_global_rect().end.x <= dimensions.x, "code entry fits mobile width")
		check(ui.controls.get_global_rect().end.x <= dimensions.x, "map controls fit mobile width")
		await capture("button-location")
		button.pressed.emit()
		await frames()
		var input: LineEdit = ui.find_child("FunctionCodeInput",true,false)
		check(input != null and not ui._can_walk(), "code input opens and blocks map movement")
		check(input.virtual_keyboard_enabled, "native exports enable system keyboard")
		var keyboard := KeyboardBridge.new()
		input._bridge = keyboard
		var tap := InputEventScreenTouch.new()
		tap.pressed = true
		input.grab_focus()
		input._gui_input(tap)
		keyboard.update = JSON.stringify({"value":"typed", "event":"input", "height":0.5})
		await frames()
		check(input.text == "typed", "native input updates field")
		check(input.get_global_rect().end.y <= dimensions.y * 0.5, "input stays above native keyboard")
		await capture("code-system-keyboard-layout")
		keyboard.update = JSON.stringify({"value":"kept", "event":"complete", "height":0})
		await frames()
		check(input.text == "kept" and ui.overlay_kind == "function_code" and keyboard.closed, "dismiss keeps text without applying code")
		input.text = "bad"
		ui.find_child("ApplyFunctionCode",true,false).pressed.emit()
		check(ui.find_child("FunctionCodeFeedback",true,false).text == "功能码不正确。", "wrong code feedback visible")
		input.text = "NXX"
		ui.find_child("FunctionCodeFeedback",true,false).text = ""
		await frames()
		await capture("code-input")
		input.grab_focus()
		input._gui_input(tap)
		keyboard.update = JSON.stringify({"value":"NXX", "event":"confirm", "height":0})
		await frames()
		check(boosted(ui.game) and ui.overlay_kind.is_empty() and keyboard.closed, "native done applies code and closes keyboard")
		check(ui.hp_label.text == "生命 1000 / 1000" and ui.stats_label.text == "攻 1000  防 1000", "HUD immediately displays exact boosted values")
		ui._open_overlay("function_code")
		await frames()
		input = ui.find_child("FunctionCodeInput",true,false)
		input._bridge = keyboard
		input.grab_focus()
		input._gui_input(tap)
		keyboard.update = JSON.stringify({"value":"retry", "event":"error", "height":0})
		await frames()
		check(ui.find_child("FunctionCodeFeedback",true,false).text.contains("再次点击"), "keyboard failure gives retry feedback")
		input._gui_input(tap)
		check(not keyboard.closed, "keyboard can reopen after failure")
		ui._close_overlay()
		check(keyboard.closed, "closing overlay disposes active keyboard")
		ui.queue_free()
		await frames()
	print("FUNCTION CODE: %d checks, %d failures" % [checks, failures])
	quit(1 if failures else 0)
