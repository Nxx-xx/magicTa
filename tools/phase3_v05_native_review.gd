extends SceneTree
## Explicit source-only viewer. Never edits approvals or production assets.
var folder := ""
var data := {}
var ids: Array = []
var textures := {}
var current := 0
var seconds := 0.0
var speed := 1.0
var playing := true
var effects := true
var frame := 0
var label: Label
var pictures: Array[TextureRect] = []
var effect_pictures: Array[TextureRect] = []
var lifetime := 0.0

func _initialize() -> void:
	print("Native source review initializing")
	var draft := ""
	for arg in OS.get_cmdline_user_args():
		if arg.begins_with("--draft="): draft = arg.trim_prefix("--draft=")
	if not draft.begins_with("res://assets/monsters/phase3/source/parallel_v05/") or ".." in draft:
		quit(2)
		return
	folder = draft.get_base_dir()+"/"
	data = JSON.parse_string(FileAccess.get_file_as_string(draft))
	ids = data.actions.keys()
	for id in ids:
		var action: Dictionary = data.actions[id]
		textures[id] = {"frames":[],"effects_frames":[]}
		for channel in ["frames","effects_frames"]:
			for path in action.get(channel,[]):
				var image := Image.load_from_file(folder+path)
				textures[id][channel].append(ImageTexture.create_from_image(image))
	_build.call_deferred()

func _build() -> void:
	print("Native source review building visible window")
	root.title = "MagicTa v05 Native Review - "+folder.get_slice("/",folder.get_slice_count("/")-2)
	root.size = Vector2i(900,650)
	root.window_input.connect(_input)
	var background := ColorRect.new()
	background.color = Color("25323b")
	background.size = Vector2(900,650)
	root.add_child(background)
	label = Label.new()
	label.position = Vector2(20,12)
	label.add_theme_font_size_override("font_size",20)
	root.add_child(label)
	var help := Label.new()
	help.position = Vector2(20,48)
	help.text = "1-5: action | S: speed 1/.25 | Space: pause | Right: step | R: restart | F: effects | Esc: close"
	root.add_child(help)
	var action_buttons := HBoxContainer.new()
	action_buttons.position = Vector2(20,82)
	root.add_child(action_buttons)
	for index in ids.size():
		var button := Button.new()
		button.text = str(index+1)+": "+str(ids[index])
		button.pressed.connect(func(): _select(index))
		action_buttons.add_child(button)
	for index in 4:
		var side: int = [384,47,33,26][index]
		var position := Vector2(20,138) if index == 0 else Vector2(450+(index-1)*105,350-side)
		var panel := ColorRect.new()
		panel.position = position
		panel.size = Vector2(side,side)
		panel.color = Color("40535b")
		root.add_child(panel)
		var texture := TextureRect.new()
		texture.position = position
		texture.size = Vector2(side,side)
		texture.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
		texture.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
		root.add_child(texture)
		pictures.append(texture)
		var overlay := texture.duplicate() as TextureRect
		root.add_child(overlay)
		effect_pictures.append(overlay)
	_update()

func _select(index: int) -> void:
	current = index
	seconds = 0
	frame = 0
	_update()

func _process(delta: float) -> bool:
	lifetime += delta
	if lifetime > 90:
		quit(0)
	if label == null: return false
	if playing:
		seconds += delta*speed
		var action: Dictionary = data.actions[ids[current]]
		frame = int(seconds*float(action.fps)) % action.frames.size()
	_update()
	return false

func _input(event: InputEvent) -> void:
	if not event is InputEventKey or not event.pressed or event.echo: return
	match event.keycode:
		KEY_1,KEY_2,KEY_3,KEY_4,KEY_5:
			var next: int = event.keycode-KEY_1
			if next < ids.size(): _select(next)
		KEY_S: speed = .25 if speed == 1 else 1
		KEY_SPACE: playing = not playing
		KEY_RIGHT:
			playing = false
			frame = (frame+1)%data.actions[ids[current]].frames.size()
			seconds = frame/float(data.actions[ids[current]].fps)
		KEY_R:
			frame = 0
			seconds = 0
		KEY_F: effects = not effects
		KEY_ESCAPE: quit(0)
	_update()

func _update() -> void:
	if label == null: return
	var id: String = ids[current]
	var action: Dictionary = data.actions[id]
	label.text = "%s | frame %d/%d | %s FPS x%.2f | %s | FX %s" % [id,frame+1,action.frames.size(),str(action.fps),speed,"playing" if playing else "paused","on" if effects else "off"]
	for index in pictures.size():
		pictures[index].texture = textures[id].frames[frame]
		effect_pictures[index].texture = textures[id].effects_frames[frame] if effects and not textures[id].effects_frames.is_empty() else null
