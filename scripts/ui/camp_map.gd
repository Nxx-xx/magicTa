extends VBoxContainer
signal position_changed(cell: Vector2i)
signal interaction_requested(kind: String)
const Layout = preload("res://scripts/core/camp_layout.gd")
const CampBoard = preload("res://scripts/ui/camp_board.gd")
const Minimap = preload("res://scripts/ui/map_minimap.gd")
var board: Control
var minimap: Button
var position_cell := Layout.SPAWN
var route: Array[Vector2i] = []
var target := Vector2i(-1,-1)
var destination := ""
var enabled := true
var hint: Label

func _notification(what: int) -> void:
	if what in [NOTIFICATION_APPLICATION_PAUSED,NOTIFICATION_APPLICATION_FOCUS_OUT]:
		cancel_walk()
		if is_instance_valid(board): board.cancel_pointer()

func setup(ui, spawn: Vector2i) -> void:
	name = "CampMap"
	position_cell = spawn if Layout.walkable(spawn) else Layout.SPAWN
	board = CampBoard.new()
	board.name = "CampBoard"
	size_flags_vertical = Control.SIZE_EXPAND_FILL
	board.custom_minimum_size.y = 180
	board.size_flags_vertical = Control.SIZE_EXPAND_FILL
	board.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	board.exploration = true
	board.lock_to_hero = true
	board.overview = false
	board.safe_top = 12
	board.safe_bottom = 12
	board.reduce_motion = ui.settings.reduce_motion
	add_child(board)
	board.setup(Layout.floor_data(),position_cell,target,true)
	board.cell_selected.connect(walk_to)
	board.arrived.connect(_advance)
	board.pan_started.connect(cancel_walk)
	board.footstep.connect(func():
		if enabled: ui.audio.play_step(get_tree(),ui.settings)
	)
	minimap = Minimap.new()
	minimap.board = board
	board.add_child(minimap)
	minimap.name = "CampMinimap"
	minimap.set_meta("map_surface", true)
	minimap.pressed.connect(func():
		if enabled and not ui.modal_open: board.set_overview(not board.overview)
	)
	board.view_changed.connect(_refresh_minimap)
	board.resized.connect(_fit_minimap)
	board.resized.connect(board.refit_view)
	_fit_minimap()
	_refresh_minimap()
	hint = ui._text(self,"",14,ui.MUTED)
	hint.hide()

func _fit_minimap() -> void:
	var width := 132.0 if board.size.x < 500 else 156.0
	minimap.size = Vector2(width,width + 18)
	minimap.position = board.size - minimap.size - Vector2(8,8)
	minimap.queue_redraw()

func _refresh_minimap() -> void:
	minimap.caption = "返回营地" if board.overview else "营地全图"
	minimap.tooltip_text = "点击返回放大视角" if board.overview else "点击查看营地全图\n白点：主角  蓝色：魔塔入口  金色：老骑士  紫色：死神"
	minimap.queue_redraw()

func walk_to(cell: Vector2i) -> void:
	if not enabled: return
	var kind := Layout.interaction(cell)
	if not Layout.walkable(cell) and kind.is_empty():
		hint.text = "这里无法通行，请点击营地道路。"
		hint.show()
		return
	target = cell
	destination = kind
	route = Layout.path(position_cell,cell)
	board.recenter()
	hint.hide()
	if not board.moving: _advance()

func cancel_walk() -> void:
	route.clear()
	destination = ""

func set_enabled(value: bool) -> void:
	enabled = value
	if not value: cancel_walk()
	board.mouse_filter = Control.MOUSE_FILTER_STOP if value else Control.MOUSE_FILTER_IGNORE
	for button in find_children("*","Button",true,false): button.disabled = not value

func _advance() -> void:
	if not enabled: return
	if not route.is_empty():
		position_cell = route.pop_front()
		position_changed.emit(position_cell)
		board.setup(Layout.floor_data(),position_cell,target,true)
		return
	if not destination.is_empty():
		var kind := destination
		destination = ""
		interaction_requested.emit(kind)
	else:
		hint.hide()
