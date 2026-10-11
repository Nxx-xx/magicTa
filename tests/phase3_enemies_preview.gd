extends SceneTree
## Standalone raw-PNG review; no global import, save, reward or gameplay dependency.
const ROOT := "res://assets/monsters/phase3/"
const OUTPUT := "res://build/verification/phase3/03-combat/"
const Catalog = preload("res://assets/monsters/phase3/phase3_enemy_animation_catalog.gd")
var manifest: Dictionary
var actions: Array = []
var effect_ids: Array = ["none"]
var cache := {}
var active := "minotaur_attack"
var effect_id := "none"
var elapsed := 0.0
var frame_index := 0
var playback_paused := false
var repeat := true
var action_select: OptionButton
var effect_select: OptionButton
var main_sprite: TextureRect
var effect_sprite: TextureRect
var small_sprites: Array[TextureRect] = []
var counter_label: Label
var detail_label: Label
var report_label: Label
var smoke_checks := 0
var smoke_failures: Array[String] = []

func _initialize() -> void:
	manifest = JSON.parse_string(FileAccess.get_file_as_string(ROOT + "manifest.json"))
	root.title = "Phase3 enemies | explicit status frame review"
	root.size = Vector2i(1120, 760)
	root.content_scale_size = Vector2i(1120, 760)
	root.content_scale_mode = Window.CONTENT_SCALE_MODE_CANVAS_ITEMS
	_build_ui()
	call_deferred("_ready_preview")

func _build_ui() -> void:
	var bg := ColorRect.new()
	bg.color = Color("101724")
	bg.size = Vector2(1120, 760)
	root.add_child(bg)
	_label("ENEMY ACTION LAB", Vector2(28, 18), 26, Color("e7cf9c"))
	_label("Reviewed rigs + historical draft effects • per-action status • no save or rewards", Vector2(28, 54), 16, Color("bdc7d6"))
	var controls := HBoxContainer.new()
	controls.position = Vector2(28, 92)
	controls.add_theme_constant_override("separation", 12)
	root.add_child(controls)
	action_select = OptionButton.new()
	actions = manifest.actions.keys()
	actions.sort()
	for key in actions:
		action_select.add_item(key)
	action_select.item_selected.connect(func(i: int) -> void: _select_action(str(actions[i])))
	controls.add_child(action_select)
	_button(controls, "Play / pause", func() -> void: playback_paused = not playback_paused)
	_button(controls, "Step frame", _step)
	_button(controls, "Restart", func() -> void: elapsed = 0.0; frame_index = 0; _display())
	var repeat_box := CheckButton.new()
	repeat_box.text = "Repeat review"
	repeat_box.button_pressed = true
	repeat_box.toggled.connect(func(value: bool) -> void: repeat = value)
	controls.add_child(repeat_box)
	effect_select = OptionButton.new()
	effect_ids.append_array(manifest.effects.keys())
	for key in effect_ids:
		effect_select.add_item("FX: " + key)
	effect_select.item_selected.connect(func(i: int) -> void: effect_id = str(effect_ids[i]); _display())
	controls.add_child(effect_select)
	var stage := ColorRect.new()
	stage.position = Vector2(28, 144)
	stage.size = Vector2(648, 418)
	stage.color = Color("192335")
	root.add_child(stage)
	main_sprite = _sprite(Vector2(48, 162), 384)
	effect_sprite = _sprite(Vector2(48, 162), 384)
	_label("96 px", Vector2(468, 202), 15)
	_label("64 px", Vector2(581, 202), 15)
	small_sprites.append(_sprite(Vector2(458, 232), 96))
	small_sprites.append(_sprite(Vector2(578, 260), 64))
	_label("Fixed anchor / no static stretch", Vector2(440, 402), 13, Color("99aac0"))
	_label("Combat camera only; map idle absent", Vector2(440, 428), 12, Color("99aac0"))
	counter_label = _label("", Vector2(40, 572), 18)
	detail_label = _label("", Vector2(40, 609), 15, Color("b7c5d7"))
	detail_label.size = Vector2(650, 118)
	detail_label.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	_label("READ-ONLY COMBAT EVIDENCE", Vector2(710, 151), 18, Color("e7cf9c"))
	var report_select := OptionButton.new()
	report_select.position = Vector2(708, 188)
	var reports := ["retaliation_kill", "lethal_no_thorns", "retaliation_armor", "floor10_golem"]
	for name in reports:
		report_select.add_item(name)
	report_select.item_selected.connect(func(i: int) -> void: _show_report(reports[i]))
	root.add_child(report_select)
	report_label = _label("", Vector2(710, 238), 16, Color("cdd9e7"))
	report_label.size = Vector2(382, 476)
	report_label.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	_show_report("retaliation_kill")

func _label(text: String, position: Vector2, size: int, color: Color = Color.WHITE) -> Label:
	var label := Label.new()
	label.text = text
	label.position = position
	label.add_theme_font_size_override("font_size", size)
	label.add_theme_color_override("font_color", color)
	root.add_child(label)
	return label

func _button(parent: Node, text: String, action: Callable) -> void:
	var button := Button.new()
	button.text = text
	button.pressed.connect(action)
	parent.add_child(button)

func _sprite(position: Vector2, side: int) -> TextureRect:
	var sprite := TextureRect.new()
	sprite.position = position
	sprite.size = Vector2(side, side)
	sprite.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	sprite.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
	sprite.texture_filter = CanvasItem.TEXTURE_FILTER_LINEAR
	root.add_child(sprite)
	return sprite

func _texture(path: String) -> Texture2D:
	if not cache.has(path):
		var image := Image.load_from_file(path)
		if image == null or image.is_empty():
			return null
		cache[path] = ImageTexture.create_from_image(image)
	return cache[path]

func _ready_preview() -> void:
	root.size = Vector2i(1120, 760)
	DisplayServer.window_set_size(Vector2i(1120, 760))
	_select_action(active)
	if "--smoke" in OS.get_cmdline_user_args():
		_smoke()

func _process(delta: float) -> bool:
	if not playback_paused:
		elapsed += delta
		var action: Dictionary = manifest.actions[active]
		var next_frame := int(elapsed * float(action.fps))
		frame_index = next_frame % action.frames.size() if repeat or action.loop else mini(next_frame, action.frames.size() - 1)
		_display()
	return false

func _select_action(id: String) -> void:
	active = id
	elapsed = 0
	frame_index = 0
	action_select.select(actions.find(id))
	_display()

func _step() -> void:
	playback_paused = true
	frame_index = (frame_index + 1) % manifest.actions[active].frames.size()
	elapsed = float(frame_index) / float(manifest.actions[active].fps)
	_display()

func _display() -> void:
	var action: Dictionary = manifest.actions[active]
	main_sprite.texture = _texture(action.frames[frame_index])
	for sprite in small_sprites:
		sprite.texture = main_sprite.texture
	effect_sprite.visible = effect_id != "none"
	if effect_id != "none":
		var fx: Dictionary = manifest.effects[effect_id]
		effect_sprite.texture = _texture(fx.frames[int(elapsed * float(fx.fps)) % fx.frames.size()])
	counter_label.text = "%s   |   frame %02d / %02d   |   %d FPS   |   %s" % [active, frame_index + 1, action.frames.size(), int(action.fps), "PAUSED" if playback_paused else "PLAYING"]
	detail_label.text = "Status: DRAFT — original, distinct redraws. Native masters fall below design resolution; editable layered masters and final continuity approval remain pending.\nRuntime: %dx%d, anchor (%d,%d). FX can be disabled. No missing action is advertised as complete." % [int(action.size[0]), int(action.size[1]), int(action.anchor[0]), int(action.anchor[1])]

func _show_report(id: String) -> void:
	var data: Variant = JSON.parse_string(FileAccess.get_file_as_string(OUTPUT + "combat-results.json"))
	if not data is Dictionary or not data.get("fixtures", {}).has(id):
		report_label.text = "Run phase3_combat_test_runner.gd first."
		return
	var report: Dictionary = data.fixtures[id]
	var text := "Result: %s\nTurns: %d  Counters: %d\nMinimum HP: %d\nFinal HP: %d  Heal: %d\nGold: %d\n\n" % ["WIN" if report.won else "LOSS", report.turns, report.counterattacks, report.min_hp, report.hp_after, report.healing, report.gold_reward]
	for entry in report.log.slice(0, 5):
		text += "Turn %d  hit %d  counter %d\nEnemy: %d -> %d after thorns\nPlayer HP: %d  retaliation: %d\n\n" % [entry.turn, entry.hit, entry.counter, entry.enemy_hp, entry.enemy_hp_after_counter, entry.hp, entry.retaliation_damage]
	report_label.text = text + "Report only. Playback and frame stepping cannot change the result."

func _smoke() -> void:
	playback_paused = true
	_check(not Catalog.load_action("skeleton", "review_missing_action").ok, "unavailable action cannot silently enter production")
	var preview_action := Catalog.load_action("minotaur", "attack", true)
	_check(preview_action.ok and preview_action.sprite_frames.get_frame_count("attack") == 8, "reviewed action creates real SpriteFrames")
	_check(not Catalog.load_action("skeleton", "review_missing_action", true).ok, "unmade action returns an explicit error")
	_check(Catalog.static_fallback("p3_shield_sentinel").requires_mechanic_badge, "variant fallback requests distinct mechanism badge")
	_check(not Catalog.static_fallback("unknown").ok, "unknown static fallback rejected")
	for id in actions:
		_select_action(id)
		var action: Dictionary = manifest.actions[id]
		for path in action.frames:
			var texture := _texture(path)
			_check(texture != null and texture.get_width() == int(action.size[0]) and texture.get_height() == int(action.size[1]), "frame loads at declared size: " + path)
		for i in range(action.frames.size()):
			_step()
		_check(frame_index == 0 and playback_paused, "step wraps and pauses " + id)
	for id in manifest.effects:
		for path in manifest.effects[id].frames:
			_check(_texture(path) != null, "effect loads: " + path)
	for entry in [["minotaur_attack", 4, "none"], ["slime_attack", 3, "none"], ["minotaur_rage", 2, "rage"]]:
		_select_action(entry[0])
		frame_index = entry[1]
		elapsed = float(frame_index) / float(manifest.actions[active].fps)
		effect_id = entry[2]
		effect_select.select(effect_ids.find(effect_id))
		_display()
		await process_frame
		await process_frame
		await RenderingServer.frame_post_draw
		var image := root.get_texture().get_image()
		_check(image.save_png(OUTPUT + "preview_" + active + ".png") == OK, "preview screenshot " + active)
	FileAccess.open(OUTPUT + "preview-results.json", FileAccess.WRITE).store_string(JSON.stringify({"checks": smoke_checks, "failures": smoke_failures, "scope": "native Godot texture loading, frame controls and rendered screenshots; not art acceptance"}, "\t"))
	print("Phase3 enemy preview: %d checks, %d failures" % [smoke_checks, smoke_failures.size()])
	quit(0 if smoke_failures.is_empty() else 1)

func _check(value: bool, label: String) -> void:
	smoke_checks += 1
	if not value:
		smoke_failures.append(label)
		push_error(label)
