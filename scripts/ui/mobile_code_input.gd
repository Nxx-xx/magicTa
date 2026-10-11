extends LineEdit
## Native exports use Godot's system keyboard; WeChat uses its native API.
signal keyboard_layout_changed
signal keyboard_failed
var occluded_fraction := 0.0
var _bridge
var _session := 0

func _ready() -> void:
	virtual_keyboard_enabled = true
	virtual_keyboard_type = LineEdit.KEYBOARD_TYPE_DEFAULT
	if OS.has_feature("web"):
		_bridge = JavaScriptBridge.get_interface("__towerKeyboard")
		if _bridge != null and bool(_bridge.available()):
			virtual_keyboard_enabled = false
		else:
			_bridge = null
	focus_exited.connect(_on_focus_exited)

func _gui_input(event: InputEvent) -> void:
	if _bridge == null or not editable: return
	if (event is InputEventMouseButton and event.button_index == MOUSE_BUTTON_LEFT and event.pressed) or (event is InputEventScreenTouch and event.pressed):
		if _session == 0:
			_session = int(_bridge.show(text, max_length))
			if _session == 0: keyboard_failed.emit()

func _process(_delta: float) -> void:
	if _bridge != null:
		_read_native()
	elif has_focus():
		_set_occlusion(float(DisplayServer.virtual_keyboard_get_height()) / maxf(1.0, DisplayServer.window_get_size().y))

func _read_native() -> void:
	if _session == 0: return
	var encoded: String = str(_bridge.read(_session))
	if encoded.is_empty(): return
	var update: Variant = JSON.parse_string(encoded)
	if not update is Dictionary: return
	var value: String = str(update.get("value", text))
	if text != value:
		text = value
		caret_column = text.length()
		text_changed.emit(text)
	_set_occlusion(float(update.get("height", 0)))
	var event: String = str(update.get("event", "input"))
	if event in ["confirm", "complete", "error"]:
		_close_native()
		release_focus()
		if event == "confirm": _submit_native.call_deferred()
		if event == "error": keyboard_failed.emit()

func _submit_native() -> void:
	if is_inside_tree(): text_submitted.emit(text)

func _on_focus_exited() -> void:
	_read_native()
	_close_native()
	_set_occlusion(0.0)

func _close_native() -> void:
	if _session != 0:
		_bridge.hide(_session)
		_session = 0
	_set_occlusion(0.0)

func _set_occlusion(value: float) -> void:
	value = clampf(value, 0.0, 1.0)
	if is_equal_approx(value, occluded_fraction): return
	occluded_fraction = value
	keyboard_layout_changed.emit()

func _exit_tree() -> void:
	_close_native()
	if virtual_keyboard_enabled and has_focus(): DisplayServer.virtual_keyboard_hide()
