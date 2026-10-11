extends RefCounted
## Observe before GUI dispatch so nested cards/buttons cannot swallow a swipe.
const DRAG_THRESHOLD := 10.0
var target: ScrollContainer
var pointer := -2
var dragging := false
var start := Vector2.ZERO
var last := Vector2.ZERO
var suppressed_touches: Dictionary = {}

static func hit_control(node: Node, position: Vector2) -> Control:
	if node is Window:
		return null
	if node is CanvasItem and not node.is_visible_in_tree():
		return null
	if node is Control and node.clip_contents and not node.get_global_rect().has_point(position):
		return null
	var children := node.get_children()
	children.reverse()
	for child in children:
		var hit := hit_control(child, position)
		if hit != null:
			return hit
	if node is Control and node.mouse_filter != Control.MOUSE_FILTER_IGNORE and node.get_global_rect().has_point(position):
		return node
	return null

func cancel() -> void:
	if dragging and is_instance_valid(target):
		target.propagate_notification(Control.NOTIFICATION_SCROLL_END)
	target = null
	pointer = -2
	dragging = false
	suppressed_touches.clear()

func handle(event: InputEvent, host: Control, on_drag: Callable) -> bool:
	# Desktop mouse-to-touch and native touch-to-mouse must not scroll twice.
	if event.device == InputEvent.DEVICE_ID_EMULATION:
		return dragging
	# The WeChat adapter exposes a mouse stream followed by native touches.
	# Own the first stream and suppress its duplicate through release/cancel.
	if event is InputEventScreenTouch or event is InputEventScreenDrag:
		if event is InputEventScreenTouch and event.canceled and pointer == -1:
			if is_instance_valid(target): target.propagate_notification(Control.NOTIFICATION_SCROLL_BEGIN)
			cancel()
			return true
		if suppressed_touches.has(event.index):
			if event is InputEventScreenTouch and (not event.pressed or event.canceled):
				suppressed_touches.erase(event.index)
			return true
		if pointer == -1:
			suppressed_touches[event.index] = true
			return true
	elif pointer >= 0 and (event is InputEventMouseMotion or event is InputEventMouseButton):
		return dragging
	var id := -2
	var position := Vector2.ZERO
	var press := false
	var release := false
	var motion := false
	if event is InputEventScreenTouch:
		id = event.index
		position = event.position
		press = event.pressed and not event.canceled
		release = not press
	elif event is InputEventScreenDrag:
		id = event.index
		position = event.position
		motion = true
	elif event is InputEventMouseButton and event.button_index == MOUSE_BUTTON_LEFT:
		id = -1
		position = event.position
		press = event.pressed
		release = not press
	elif event is InputEventMouseMotion:
		id = -1
		position = event.position
		motion = true
	else:
		return false
	if press and pointer == -2:
		var hit := hit_control(host, position)
		# Keep scrollbar thumbs and text editing on their native input path.
		if hit is ScrollBar or hit is LineEdit or hit is TextEdit or (hit != null and hit.has_meta("map_surface")):
			return false
		while hit != null and not hit is ScrollContainer:
			hit = hit.get_parent() as Control
		if hit == null:
			return false
		target = hit
		pointer = id
		start = position
		last = position
		dragging = false
		return false
	if id != pointer:
		return false
	if not is_instance_valid(target) or not target.is_visible_in_tree():
		cancel()
		return false
	if release:
		var consumed := dragging
		if event is InputEventScreenTouch and event.canceled:
			target.propagate_notification(Control.NOTIFICATION_SCROLL_BEGIN)
			target.propagate_notification(Control.NOTIFICATION_SCROLL_END)
			consumed = true
		var duplicates := suppressed_touches.duplicate()
		cancel()
		suppressed_touches = duplicates
		return consumed
	if motion:
		var total := position - start
		var vertical := target.vertical_scroll_mode != ScrollContainer.SCROLL_MODE_DISABLED and target.get_v_scroll_bar().max_value > target.get_v_scroll_bar().page
		var horizontal := target.horizontal_scroll_mode != ScrollContainer.SCROLL_MODE_DISABLED and target.get_h_scroll_bar().max_value > target.get_h_scroll_bar().page
		if not dragging and ((vertical and absf(total.y) > DRAG_THRESHOLD) or (horizontal and absf(total.x) > DRAG_THRESHOLD)):
			dragging = true
			target.propagate_notification(Control.NOTIFICATION_SCROLL_BEGIN)
			on_drag.call()
		if dragging:
			var delta := position - last
			if vertical:
				target.scroll_vertical -= roundi(delta.y)
			if horizontal:
				target.scroll_horizontal -= roundi(delta.x)
		last = position
		return dragging
	return false
