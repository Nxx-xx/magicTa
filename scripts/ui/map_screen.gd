extends Control

const Core = preload("res://scripts/core/campaign_engine.gd")
const CampaignPanels = preload("res://scripts/ui/campaign_panels.gd")
const Preferences = preload("res://scripts/ui/presentation_settings.gd")
const AudioFeedback = preload("res://scripts/ui/audio_feedback.gd")
const Board = preload("res://scripts/ui/grid_board.gd")
const Keys = preload("res://scripts/core/map_keys.gd")
const Enemies = preload("res://scripts/core/enemy_rules.gd")
const Rewards = preload("res://scripts/core/rewards.gd")
const ItemIcon = preload("res://scripts/ui/item_icon.gd")
const FONT = preload("res://assets/ui/visual_v01/body_font.tres")
const GOLD := Color("e0bf80")
const TEAL := Color("83d5bf")
const MUTED := Color("a2b3c3")
const RED := Color("ed9395")
var game = Core.new()
var page := "menu"
var selected := Vector2i(-1, -1)
var notice := ""
var shell: VBoxContainer
var body: VBoxContainer
var margin: MarginContainer
var scroll: ScrollContainer
var seed_input: LineEdit
var modal_open := false
var map_root: Control
var board: Control
var hud: VBoxContainer
var floor_label: Label
var hp_label: Label
var stats_label: Label
var money_label: Label
var key_labels: Dictionary = {}
var health: ProgressBar
var detail_panel: PanelContainer
var detail_copy: Label
var detail_title: Label
var detail_hint: Label
var detail_button: Button
var controls: VBoxContainer
var direction_buttons: Array[Button] = []
var overlay: Control
var overlay_panel: PanelContainer
var overlay_title: Label
var overlay_close: Button
var overlay_kind := ""
var compact := false
var previous_scale_mode: int
var previous_scale_size: Vector2i
var return_focus: Control
var layout_queued := false
var sheet_cache_key := ""
var save_error_panel: PanelContainer
var save_error_scroll: ScrollContainer
var save_error_label: Label
var hud_back: PanelContainer
var board_frame: PanelContainer
var settings = Preferences.new()
var audio = AudioFeedback.new()
var story_line := 0
var story_id := ""
var index_floor := -1
var overlay_next: Button
var save_retry: Button
var feedback_tween: Tween

func _exit_tree() -> void:
	audio.stop()
	get_window().content_scale_mode = previous_scale_mode
	get_window().content_scale_size = previous_scale_size


func _ready() -> void:
	theme = preload("res://assets/ui/map_theme.tres")
	# Desktop uses window pixels; phones keep logical pixels so high-DPI controls stay usable.
	previous_scale_mode = get_window().content_scale_mode
	previous_scale_size = get_window().content_scale_size
	if not OS.has_feature("mobile"):
		get_window().content_scale_mode = Window.CONTENT_SCALE_MODE_DISABLED
		get_window().content_scale_size = Vector2i.ZERO
	settings.read()
	game.load_game()
	get_tree().auto_accept_quit = false
	resized.connect(_fit_width)
	_render()

func _notification(what: int) -> void:
	if what == NOTIFICATION_WM_CLOSE_REQUEST:
		_request_quit()
	elif what in [NOTIFICATION_APPLICATION_PAUSED, NOTIFICATION_APPLICATION_FOCUS_OUT]:
		game.save_game()
		# Background autosaves do not otherwise refresh the map or its open sheet.
		if is_instance_valid(map_root):
			_refresh_save_error()

func _input(event: InputEvent) -> void:
	if page == "map" and event is InputEventKey and event.pressed and event.keycode == KEY_ESCAPE and not modal_open and overlay_kind != "":
		_close_overlay()
		get_viewport().set_input_as_handled()
		return
	if page != "map" or modal_open or overlay_kind != "" or _transaction_pending() or not game.active() or not game.state.pending.is_empty():
		return
	if not event is InputEventKey or not event.pressed or event.echo or event.ctrl_pressed or event.alt_pressed:
		return
	var direction := Vector2i.ZERO
	match event.keycode:
		KEY_W, KEY_UP: direction = Vector2i.UP
		KEY_S, KEY_DOWN: direction = Vector2i.DOWN
		KEY_A, KEY_LEFT: direction = Vector2i.LEFT
		KEY_D, KEY_RIGHT: direction = Vector2i.RIGHT
	if direction != Vector2i.ZERO:
		get_viewport().set_input_as_handled()
		_act(func(): return game.step(direction))

func _box(fill: Color, border: Color) -> StyleBoxFlat:
	var box := StyleBoxFlat.new()
	box.bg_color = fill
	box.border_color = border
	box.set_border_width_all(1)
	box.set_corner_radius_all(9)
	box.content_margin_left = 12
	box.content_margin_right = 12
	box.content_margin_top = 10
	box.content_margin_bottom = 10
	return box

func _text(parent: Node, text: String, size_px: int = 16, color: Color = Color("e5e9e8")) -> Label:
	var label := Label.new()
	label.text = text
	label.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	label.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	label.add_theme_font_size_override("font_size", size_px)
	label.add_theme_color_override("font_color", color)
	if size_px >= 19:
		label.theme_type_variation = "TitleLabel"
	parent.add_child(label)
	return label

func _button(parent: Node, text: String, action: Callable, disabled: bool = false, role: String = "") -> Button:
	var button := Button.new()
	button.text = text
	button.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	button.custom_minimum_size.y = 48
	button.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	button.disabled = disabled
	button.theme_type_variation = role
	parent.add_child(button)
	button.pressed.connect(func():
		if button.is_inside_tree() and not button.disabled and not modal_open:
			action.call()
	)
	return button

func _panel(parent: Node, role: String = "CardPanel") -> VBoxContainer:
	var panel := PanelContainer.new()
	panel.theme_type_variation = role
	parent.add_child(panel)
	var box := VBoxContainer.new()
	panel.add_child(box)
	return box

func _render(reset_scroll: bool = false) -> void:
	if page == "map" and not game.state.is_empty():
		if not is_instance_valid(map_root):
			_build_map_shell()
		_refresh_map(reset_scroll)
		return
	map_root = null
	overlay_kind = ""
	var previous_scroll := scroll.scroll_vertical if is_instance_valid(scroll) and not reset_scroll else 0
	for child in get_children():
		remove_child(child)
		child.queue_free()
	var bg := ColorRect.new()
	bg.color = Color("0b111c")
	bg.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(bg)
	bg.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	margin = MarginContainer.new()
	add_child(margin)
	margin.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	for side in ["left", "right", "top", "bottom"]:
		margin.add_theme_constant_override("margin_" + side, 16)
	_fit_width()
	shell = VBoxContainer.new()
	margin.add_child(shell)
	var row := HBoxContainer.new()
	shell.add_child(row)
	_text(row, "塔境 / 公主救援记", 25, GOLD)
	if page == "map":
		var camp_button := _button(row, "营地", func():
			page = "menu"
			_render(true)
		)
		camp_button.size_flags_horizontal = Control.SIZE_SHRINK_END
		camp_button.custom_minimum_size.x = 64
	scroll = ScrollContainer.new()
	scroll.size_flags_vertical = Control.SIZE_EXPAND_FILL
	scroll.horizontal_scroll_mode = ScrollContainer.SCROLL_MODE_DISABLED
	shell.add_child(scroll)
	body = VBoxContainer.new()
	body.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	scroll.add_child(body)
	if not game.errors.is_empty():
		_text(body, "\n".join(game.errors), 18, RED)
		return
	if not game.save_error.is_empty():
		_text(body, game.save_error, 14, RED)
	if not notice.is_empty():
		_text(body, notice, 14, GOLD)
	if page == "menu":
		_menu()
	_text(shell, "十层营救 / 两层试炼 · 自动保存 · 可跨层回溯", 11, MUTED).horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	scroll.set_deferred("scroll_vertical", previous_scroll)

func _fit_width() -> void:
	if is_instance_valid(map_root):
		_layout_map()
		return
	if is_instance_valid(margin):
		var gutter := maxf(0.0, (size.x - 640.0) / 2.0)
		margin.offset_left = gutter
		margin.offset_right = -gutter

func _clear(node: Node) -> void:
	for child in node.get_children():
		node.remove_child(child)
		child.queue_free()

func _build_map_shell() -> void:
	sheet_cache_key = ""
	_clear(self)
	direction_buttons.clear()
	key_labels.clear()
	map_root = Control.new()
	map_root.name = "ExplorationLayout"
	add_child(map_root)
	map_root.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	var bg := ColorRect.new()
	bg.color = Color("0c131b")
	bg.mouse_filter = Control.MOUSE_FILTER_IGNORE
	map_root.add_child(bg)
	bg.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	hud_back = PanelContainer.new()
	hud_back.theme_type_variation = "HudPanel"
	hud_back.mouse_filter = Control.MOUSE_FILTER_IGNORE
	map_root.add_child(hud_back)
	hud = VBoxContainer.new()
	hud.name = "FixedStatus"
	hud.add_theme_constant_override("separation", 4)
	map_root.add_child(hud)
	var heading := HBoxContainer.new()
	hud.add_child(heading)
	floor_label = _text(heading, "", 20, GOLD)
	var menu_button := _button(heading, "营地", func():
		page = "menu"
		_render(true)
	)
	menu_button.custom_minimum_size = Vector2(64, 44)
	menu_button.size_flags_horizontal = Control.SIZE_SHRINK_END
	var stats_row := HBoxContainer.new()
	hud.add_child(stats_row)
	hp_label = _text(stats_row, "", 18, TEAL)
	stats_label = _text(stats_row, "", 16)
	stats_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_RIGHT
	health = ProgressBar.new()
	health.show_percentage = false
	health.custom_minimum_size.y = 8
	health.mouse_filter = Control.MOUSE_FILTER_IGNORE
	hud.add_child(health)
	var resources := HBoxContainer.new()
	hud.add_child(resources)
	money_label = _text(resources, "", 14, GOLD)
	money_label.theme_type_variation = "StatChip"
	for kind in Keys.TYPES:
		key_labels[kind] = _text(resources, "", 14, Keys.COLORS[kind])
		key_labels[kind].theme_type_variation = "StatChip"
		key_labels[kind].horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	board_frame = PanelContainer.new()
	board_frame.theme_type_variation = "MapFrame"
	board_frame.mouse_filter = Control.MOUSE_FILTER_IGNORE
	map_root.add_child(board_frame)
	board = Board.new()
	board.name = "PersistentBoard"
	map_root.add_child(board)
	board.cell_selected.connect(_select_cell)
	detail_panel = PanelContainer.new()
	detail_panel.name = "TargetSummary"
	detail_panel.theme_type_variation = "TargetPanel"
	map_root.add_child(detail_panel)
	var details := VBoxContainer.new()
	details.add_theme_constant_override("separation", 4)
	detail_panel.add_child(details)
	var detail_row := HBoxContainer.new()
	details.add_child(detail_row)
	detail_title = _text(detail_row, "", 17, GOLD)
	detail_button = _button(detail_row, "详情", func(): _open_overlay("target"))
	detail_button.size_flags_horizontal = Control.SIZE_SHRINK_END
	detail_button.custom_minimum_size = Vector2(64, 44)
	detail_copy = _text(details, "", 15, TEAL)
	detail_hint = _text(details, "", 13, MUTED)
	controls = VBoxContainer.new()
	controls.name = "FixedControls"
	controls.add_theme_constant_override("separation", 8)
	map_root.add_child(controls)
	var row := HBoxContainer.new()
	controls.add_child(row)
	var directions := [Vector2i.LEFT, Vector2i.UP, Vector2i.DOWN, Vector2i.RIGHT]
	var labels := ["← 左", "↑ 上", "↓ 下", "→ 右"]
	for index in 4:
		var button := _button(row, labels[index], func(): _act(func(): return game.step(directions[index])))
		button.theme_type_variation = "DirectionButton"
		button.custom_minimum_size.y = 44
		direction_buttons.append(button)
	var tools_row := HBoxContainer.new()
	controls.add_child(tools_row)
	_button(tools_row, "行囊", func(): _open_overlay("inventory"), false, "QuietButton").custom_minimum_size.y = 44
	_button(tools_row, "楼层", func(): _open_overlay("floors"), false, "QuietButton").custom_minimum_size.y = 44
	_button(tools_row, "记录", func(): _open_overlay("log"), false, "QuietButton").custom_minimum_size.y = 44
	overlay = Control.new()
	overlay.name = "DetailSheet"
	map_root.add_child(overlay)
	overlay.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	var shade := ColorRect.new()
	shade.color = Color(0.02, 0.04, 0.06, 0.88)
	overlay.add_child(shade)
	shade.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	shade.offset_top = 118
	overlay_panel = PanelContainer.new()
	overlay_panel.theme_type_variation = "SheetPanel"
	overlay.add_child(overlay_panel)
	var sheet := VBoxContainer.new()
	overlay_panel.add_child(sheet)
	overlay_title = _text(sheet, "目标详情", 21, GOLD)
	sheet.add_child(HSeparator.new())
	scroll = ScrollContainer.new()
	scroll.size_flags_vertical = Control.SIZE_EXPAND_FILL
	scroll.horizontal_scroll_mode = ScrollContainer.SCROLL_MODE_DISABLED
	scroll.follow_focus = true
	sheet.add_child(scroll)
	body = VBoxContainer.new()
	body.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	scroll.add_child(body)
	overlay_next = _button(sheet, "继续", _advance_story, false, "PrimaryButton")
	overlay_next.visible = false
	overlay_close = _button(sheet, "返回地图", _close_overlay, false, "QuietButton")
	overlay.visible = false
	# A sibling after the sheet stays readable in every map state, including results.
	save_error_panel = PanelContainer.new()
	save_error_panel.name = "PersistentSaveError"
	var error_style := _box(Color("321f27"), RED)
	error_style.content_margin_top = 6
	error_style.content_margin_bottom = 6
	save_error_panel.add_theme_stylebox_override("panel", error_style)
	map_root.add_child(save_error_panel)
	var error_copy := VBoxContainer.new()
	error_copy.add_theme_constant_override("separation", 2)
	save_error_panel.add_child(error_copy)
	var error_row := HBoxContainer.new()
	error_copy.add_child(error_row)
	_text(error_row, "存档异常", 15, RED)
	save_retry = _button(error_row, "重试保存", _retry_save, false, "QuietButton")
	save_retry.custom_minimum_size = Vector2(90, 28)
	save_retry.add_theme_font_size_override("font_size", 13)
	for state_name in ["normal", "hover", "pressed", "focus"]:
		var retry_style := _box(Color("182936"), MUTED)
		retry_style.content_margin_top = 2
		retry_style.content_margin_bottom = 2
		save_retry.add_theme_stylebox_override(state_name, retry_style)
	save_retry.size_flags_horizontal = Control.SIZE_SHRINK_END
	save_error_scroll = ScrollContainer.new()
	save_error_scroll.horizontal_scroll_mode = ScrollContainer.SCROLL_MODE_DISABLED
	save_error_scroll.size_flags_vertical = Control.SIZE_EXPAND_FILL
	error_copy.add_child(save_error_scroll)
	save_error_label = _text(save_error_scroll, "", 15)
	save_error_panel.visible = not game.save_error.is_empty()
	save_error_label.text = game.save_error
	hud.minimum_size_changed.connect(_queue_layout)
	detail_panel.minimum_size_changed.connect(_queue_layout)
	_layout_map()
	_queue_layout()

func _queue_layout() -> void:
	if layout_queued:
		return
	layout_queued = true
	_refit_map.call_deferred()

func _refit_map() -> void:
	layout_queued = false
	if is_instance_valid(map_root):
		_layout_map()

func _layout_map() -> void:
	compact = size.y < 800 or size.x < 400
	var width := minf(size.x - 24, 600)
	var left := (size.x - width) * 0.5
	var header_height := 118.0
	var error_height := maxf(84.0, save_error_panel.get_combined_minimum_size().y)
	var error_space := error_height + 8.0 if save_error_panel.visible else 0.0
	var detail_height := 90.0 if compact else 166.0
	var controls_height := 96.0
	var board_size := minf(width, size.y - header_height - error_space - detail_height - controls_height - 48)
	board_size = maxf(100, board_size)
	hud.position = Vector2(left, 8)
	hud.size = Vector2(width, header_height)
	hud_back.position = Vector2(left - 6, 3)
	hud_back.size = Vector2(width + 12, header_height + 4)
	save_error_panel.position = Vector2(left, 124)
	save_error_panel.size = Vector2(width, error_height)
	board.position = Vector2((size.x - board_size) * 0.5, header_height + error_space + 12)
	board.size = Vector2.ONE * board_size
	board_frame.position = board.position - Vector2(3, 3)
	board_frame.size = board.size + Vector2(6, 6)
	controls.position = Vector2(left, size.y - controls_height - 12)
	controls.size = Vector2(width, controls_height)
	detail_panel.position = Vector2(left, header_height + error_space + board_size + 20)
	detail_panel.size = Vector2(width, controls.position.y - detail_panel.position.y - 8)
	detail_copy.visible = true
	detail_hint.visible = not compact
	detail_title.add_theme_font_size_override("font_size", 15 if compact else 17)
	var sheet_top := 124.0 + error_space
	overlay_panel.position = Vector2(left, sheet_top)
	overlay_panel.size = Vector2(width, size.y - sheet_top - 12)
	_refresh_summary()

func _refresh_map(reset_scroll: bool = false) -> void:
	_refresh_save_error()
	var player: Dictionary = game.state.player
	var stats: Dictionary = game.stats()
	floor_label.text = "塔境 · 第 %d 层" % int(game.state.floor)
	floor_label.tooltip_text = str(game.floor_data().name)
	hp_label.text = "生命 %d / %d" % [player.hp, stats.max_hp]
	stats_label.text = "攻 %d  防 %d" % [stats.attack, stats.defense]
	health.max_value = stats.max_hp
	health.value = player.hp
	money_label.text = "金币 %d" % int(player.gold)
	for kind in Keys.TYPES:
		key_labels[kind].text = "%s钥 %d" % [Keys.LABELS[kind], Keys.count(player, kind)]
	board.reduce_motion = settings.reduce_motion
	board.marked_cells = _floor_pins(int(game.state.floor)).keys()
	board.setup(game.floor_data(), game.position(), selected, game.active(), game.db.data.enemies)
	_refresh_summary()
	var next_overlay := overlay_kind
	if not game.state.pending.is_empty():
		next_overlay = "pending"
	elif next_overlay == "pending":
		next_overlay = ""
	if _transaction_pending():
		next_overlay = "save_blocked"
	elif game.state.pending.is_empty() and not _story_event().is_empty():
		next_overlay = "story"
	elif not game.active() and not next_overlay in ["floors", "inventory", "log", "settings"]:
		next_overlay = "result"
	elif next_overlay in ["story", "save_blocked"]:
		next_overlay = ""
	var changed := next_overlay != overlay_kind
	if changed and next_overlay != "":
		return_focus = get_viewport().gui_get_focus_owner()
	overlay_kind = next_overlay
	# Only the sheet's contents change. HUD, board and controls retain identity/focus.
	var old_scroll := scroll.scroll_vertical
	var key := str([overlay_kind, player.equipment_ids, player.relic_ids, stats, game.state.seed, game.state.floor]) if overlay_kind in ["", "inventory"] else ""
	if key.is_empty() or key != sheet_cache_key:
		_populate_sheet()
		sheet_cache_key = key
	overlay.visible = overlay_kind != ""
	overlay_close.text = "暂时离开 · 返回地图" if overlay_kind == "pending" else ("跳过对白" if overlay_kind == "story" else ("返回结算" if not game.active() else "返回地图"))
	overlay_close.visible = not overlay_kind in ["result", "save_blocked"]
	overlay_next.visible = overlay_kind == "story"
	if overlay_next.visible:
		overlay_next.text = "结束对白" if story_line >= _story_event().get("lines", []).size() - 1 else "继续"
	scroll.set_deferred("scroll_vertical", 0 if changed or reset_scroll else old_scroll)
	_set_map_input()
	_layout_map()
	if changed and overlay.visible:
		if overlay_next.visible:
			_restore_focus.call_deferred(overlay_next)
		elif overlay_close.visible:
			_restore_focus.call_deferred(overlay_close)
		else:
			var actions := body.find_children("*", "Button", true, false)
			if not actions.is_empty():
				_restore_focus.call_deferred(actions[0])
	elif changed and is_instance_valid(return_focus) and return_focus.is_visible_in_tree():
		_restore_focus.call_deferred(return_focus)

func _refresh_save_error() -> void:
	if not is_instance_valid(save_error_panel):
		return
	var message: String = game.save_error
	if save_error_label.text != message:
		save_error_label.text = message
		save_error_scroll.set_deferred("scroll_vertical", 0)
	save_error_panel.visible = not message.is_empty()
	# Never infer success: an empty engine error only removes the warning.
	_queue_layout()

func _populate_sheet() -> void:
	_clear(body)
	match overlay_kind:
		"story":
			var event := _story_event()
			if story_id != str(event.get("id", "")):
				story_id = str(event.get("id", ""))
				story_line = 0
				if not event.get("static_summary", false):
					var cue := str(event.get("audio_cue", ""))
					if not cue.is_empty():
						audio.play_story(get_tree(), cue, settings)
			overlay_title.text = str(event.get("title", "传声石"))
			CampaignPanels.story(self, event)
		"floors":
			overlay_title.text = "楼层索引 · 回溯目标"
			CampaignPanels.floor_index(self)
		"settings":
			overlay_title.text = "声音与显示"
			CampaignPanels.settings(self, body)
		"save_blocked":
			overlay_title.text = "尚未保存 · 请重试"
			_text(body, "保存未完成，当前操作不会重复结算。请重试保存，成功后继续旅程。", 17, GOLD)
			_button(body, "重试保存", _retry_save, false, "PrimaryButton")
			_button(body, "退出游戏", _request_quit, false, "QuietButton")
		"pending":
			overlay_title.text = "待确认 · 查看成本后行动"
			_pending_panel()
		"target":
			overlay_title.text = "查看目标 · 不会远程执行"
			if game.inside(selected):
				_describe(body, selected)
			else:
				_text(body, "点击相邻格移动或交互，点击远处目标查看属性。方向键 / WASD 与下方按钮均可移动。", 16)
			if game.inside(selected) and not game.entity_at(selected).is_empty():
				_button(body, "取消目标标记" if _floor_pins(int(game.state.floor)).has(Core.cell_key(selected)) else "标记目标 · 留待回溯", _toggle_pin)
			_text(body, "怪物 1 / 2 / 3 表示强度档，“回”表示回溯守卫。铜 / 银 / 金门只消耗同类钥匙。", 14, MUTED)
		"log":
			overlay_title.text = "最近一次战斗记录"
			if game.state.last_report.is_empty():
				_text(body, "尚未发生战斗。", 16, MUTED)
			for entry in game.state.last_report.get("log", []):
				_text(body, "第 %d 击：造成 %d，敌人剩 %d HP；反击 %d。" % [entry.turn, entry.hit, entry.enemy_hp, entry.counter], 14, MUTED)
		"result":
			if _is_campaign():
				CampaignPanels.result(self)
				return
			overlay_title.text = "火把熄灭了"
			_text(body, str(game.state.last_message), 16, RED)
			_button(body, "相同种子重新开始", func(): _start(str(game.state.seed)), false, "PrimaryButton")
			_button(body, "返回营地", func():
				page = "menu"
				_render(true)
			)
		_:
			# Prepare the inventory in the hidden sheet; it never takes space from the map.
			overlay_title.text = "行囊 · 获得即生效"
			_inventory_content()

func _refresh_summary() -> void:
	var title := "探索 · 点击格子查看"
	var copy := "登上十层救出王子；先收集装备，五层击败牛头守卫。" if _is_campaign() else "主路可直达楼梯，支路奖励可在变强后回来拿。"
	var hint := str(game.state.last_message)
	var tint := TEAL
	if game.inside(selected):
		var entity: Dictionary = game.entity_at(selected)
		title = str(entity.get("name", "通路")) + " · 查看"
		if game.is_wall(selected):
			title = "石墙 · 无法通过"
		elif entity.get("type", "") == "enemy":
			var enemy: Dictionary = game.db.enemy(entity.enemy_id)
			var report: Dictionary = game.preview(selected)
			title = str(enemy.name) + " · " + Enemies.classification(enemy)
			copy = "当前挑战会死亡" if report.lethal else ("预计净损失 %d HP" % int(report.loss) if int(report.loss) >= 0 else "预计净恢复 %d HP" % -int(report.loss))
			tint = RED if report.lethal else TEAL
			hint = "实际受伤 %d · 击杀恢复 %d\n击杀奖励 %d 金币" % [report.incoming, report.healing, int(enemy.gold_reward) + int(game.stats().gold_bonus)]
			for link in game.floor_data().get("guard_links", []):
				if Vector2i(int(link.gate[0]), int(link.gate[1])) == selected:
					hint += " · 守护奖励见详情"
					break
		elif not entity.is_empty():
			copy = "相邻格可交互 · 完整成本与收益见详情"
	if _is_campaign() and game.state.get("side_objective_complete", false):
		hint = "王权指环已找回，继续向塔顶前进。"
	elif not _is_campaign() and game.state.objective_complete:
		hint = "回溯试炼完成！可以继续探索。"
	if not notice.is_empty() and game.entity_at(selected).get("type", "") != "enemy":
		hint = notice
	# Keep cost on its own full-width row: a long classification must never hide it.
	detail_title.text = title
	detail_title.max_lines_visible = 1
	detail_title.text_overrun_behavior = TextServer.OVERRUN_TRIM_ELLIPSIS
	detail_copy.text = hint if compact and game.entity_at(selected).get("type", "") != "enemy" else copy
	detail_copy.max_lines_visible = 1 if compact else 2
	detail_copy.text_overrun_behavior = TextServer.OVERRUN_TRIM_ELLIPSIS
	detail_copy.add_theme_color_override("font_color", tint)
	detail_title.add_theme_color_override("font_color", tint if compact else GOLD)
	detail_hint.text = hint
	detail_hint.max_lines_visible = 2
	detail_hint.text_overrun_behavior = TextServer.OVERRUN_TRIM_ELLIPSIS

func _inventory_content() -> void:
	_text(body, "装备与遗物 · 同名副本叠加", 17, GOLD)
	var counts: Dictionary = {}
	for id in game.state.player.equipment_ids + game.state.player.relic_ids:
		counts[id] = int(counts.get(id, 0)) + 1
	if counts.is_empty():
		_text(body, "尚未获得装备。", 15, MUTED)
	for id in counts:
		_item_card(_panel(body), str(id), int(counts[id]))
	var stats: Dictionary = game.stats()
	_text(body, "击杀恢复 %d HP · 击杀额外金币 %d" % [stats.kill_heal, stats.gold_bonus], 14, TEAL)
	_text(body, "种子 %s · %s" % [game.state.seed, game.floor_data().name], 13, MUTED)

func _open_overlay(kind: String) -> void:
	return_focus = get_viewport().gui_get_focus_owner()
	overlay_kind = kind
	_refresh_map(true)
	_restore_focus.call_deferred(overlay_close)

func _close_overlay() -> void:
	if overlay_kind == "story":
		_finish_story()
		return
	if _transaction_pending():
		return
	if overlay_kind == "pending":
		game.cancel_pending()
	overlay_kind = ""
	notice = ""
	_refresh_map(true)
	if is_instance_valid(return_focus) and return_focus.is_visible_in_tree():
		_restore_focus.call_deferred(return_focus)

func _restore_focus(control: Control) -> void:
	if is_instance_valid(control) and control.is_inside_tree() and control.is_visible_in_tree():
		if not control is BaseButton or not control.disabled:
			control.grab_focus()

func _set_map_input() -> void:
	var blocked: bool = overlay_kind != "" or modal_open or _transaction_pending() or not game.active() or not game.state.pending.is_empty()
	board.mouse_filter = Control.MOUSE_FILTER_IGNORE if blocked else Control.MOUSE_FILTER_STOP
	for button in direction_buttons:
		button.disabled = blocked
	for region in [hud, detail_panel, controls]:
		for button in region.find_children("*", "Button", true, false):
			if not button in direction_buttons:
				button.disabled = overlay_kind != "" or modal_open
			# Disabled buttons can still participate in Godot's Tab traversal.
			# Remember the original mode once, before removing background focus targets.
			if not button.has_meta("map_focus_mode"):
				button.set_meta("map_focus_mode", button.focus_mode)
			button.focus_mode = Control.FOCUS_NONE if button.disabled else int(button.get_meta("map_focus_mode"))

func _menu() -> void:
	var intro := _panel(body, "SheetPanel")
	_text(intro, "营地 · 公主救援记", 14, TEAL)
	_text(intro, "先绕行，再归来。", 28, GOLD)
	_text(intro, "王子被困在十层塔顶。\n点亮归途灯，选择路线，把他带回家。", 16)
	if not game.state.is_empty():
		_button(body, "继续探索 · 第 %d 层" % int(game.state.floor) if game.active() else "查看上次探索", _open_map, false, "PrimaryButton")
	if _transaction_pending():
		_text(body, "有操作等待保存。重试成功前不能开始新旅程。", 16, RED)
		_button(body, "重试保存", _retry_save, false, "PrimaryButton")
	seed_input = LineEdit.new()
	seed_input.custom_minimum_size.y = 48
	seed_input.placeholder_text = "地图种子（留空随机）"
	body.add_child(seed_input)
	_button(body, "营救王子 · 十层旅程", func(): _request_start(seed_input.text.strip_edges(), true), _transaction_pending(), "PrimaryButton")
	_button(body, "开始两层地图试炼", func(): _request_start(seed_input.text.strip_edges(), false), _transaction_pending())
	if game.has_method("purchase_upgrade"):
		CampaignPanels.upgrades(self)
	CampaignPanels.settings(self, body)
	var info := _panel(body)
	_text(info, "探索指引", 19, GOLD)
	_text(info, "两层均为 11×11 格。每局随机布局方向、支路与物件位置；首次上楼可选战斗、宝藏或商店主题，生成后永久保存。", 15, MUTED)
	_text(info, "怪物被击败后不刷新；开过的门、拿过的宝箱、商店售出记录都会保留。", 15, MUTED)
	_text(info, "普通怪分入门、进阶、高阶三档。先看当前战斗损失，再决定是否挑战；标有“回”的守卫适合变强后回来。", 15, MUTED)
	_text(body, "操作：方向键 / WASD / 下方方向按钮移动；点击相邻格也可移动，点击远处目标可查看属性。战斗和开门先预览再确认。", 14, MUTED)
	_text(body, "两层试炼用于练习回溯，不产出灵魂。十层旅程在第五层和第十层挑战 Boss，营地火种只在新旅程生效。", 13, MUTED)

func _start(seed_text: String) -> void:
	var result: String = game.start(seed_text)
	if not result.is_empty():
		notice = result
		_render(true)
		return
	selected = Vector2i(-1, -1)
	notice = ""
	overlay_kind = ""
	_open_map()

func _open_map() -> void:
	page = "map"
	_render(true)

func _describe(parent: Node, cell: Vector2i, include_options: bool = true) -> void:
	var entity: Dictionary = game.entity_at(cell)
	if game.is_wall(cell):
		_text(parent, "石墙 · 无法通过", 16, MUTED)
		return
	if entity.is_empty():
		_text(parent, "通路（%d, %d）" % [cell.x, cell.y], 16, MUTED)
		return
	var title := str(entity.name)
	if entity.type == "key":
		title = Keys.key_name(Keys.kind(entity))
	elif entity.type == "door":
		title = Keys.door_name(Keys.kind(entity))
	elif entity.type == "enemy":
		title = str(game.db.enemy(entity.enemy_id).name)
	_text(parent, title, 19, GOLD)
	match str(entity.type):
		"enemy":
			var enemy: Dictionary = game.db.enemy(entity.enemy_id)
			var report: Dictionary = game.preview(cell)
			_text(parent, Enemies.classification(enemy) + " · " + Enemies.map_role(entity), 14, GOLD)
			_text(parent, "生命 %d / 攻击 %d / 防御 %d" % [enemy.hp, enemy.attack, enemy.defense], 14, MUTED)
			_text(parent, str(enemy.get("combat_hint", "")), 14, MUTED)
			if not str(enemy.get("ability_id", "")).is_empty():
				_text(parent, "机制：" + str(enemy.description), 14, MUTED)
			var cost := "预计净损失 %d HP。" % int(report.loss) if int(report.loss) >= 0 else "预计净恢复 %d HP。" % -int(report.loss)
			var cost_box := _panel(parent, "TargetPanel")
			_text(cost_box, "当前挑战会死亡，可以变强后再来。" if report.lethal else cost, 18, RED if report.lethal else TEAL)
			_text(parent, "实际受伤 %d · 击杀恢复 %d · 战中最低生命 %d" % [report.incoming, report.healing, int(report.hp_after) - int(report.healing)], 13, MUTED)
			_text(parent, "击杀奖励：%d 金币。" % (int(enemy.gold_reward) + int(game.stats().gold_bonus)), 14, GOLD)
		"door":
			var key_kind := Keys.kind(entity)
			_text(parent, "消耗 %d 把%s（持有 %d）。其他钥匙不能替代，开门后永久畅通。" % [int(entity.cost), Keys.key_name(key_kind), Keys.count(game.state.player, key_kind)], 15, Keys.COLORS[key_kind])
		"chest":
			var item: Dictionary = game.db.item(entity.item_id)
			_text(parent, "%s · %s；额外 %d 金币。" % [item.name, item.description, entity.gold], 15, TEAL)
			_text(parent, Rewards.summary(Rewards.resolve(game.db, game.state.player, game.collection_reward(entity))), 13, MUTED)
		"potion":
			var result := Rewards.resolve(game.db, game.state.player, game.collection_reward(entity))
			_text(parent, "恢复至多 %d HP；本次实际恢复 %d，溢出 %d。\n确认使用才会消耗，满血经过会保留。" % [int(entity.amount), result.healing, result.overflow], 15, TEAL)
		"choice", "event", "rest":
			_text(parent, "只能选择一项；可以离开再回来，候选不会改变。", 14, MUTED)
			if entity.type == "event":
				_text(parent, str(game.db.event(entity.event_id).get("description", "")), 14, MUTED)
			if include_options:
				for option in game.reward_options(entity):
					_text(parent, "%s · %s" % [option.name, option.get("description", "")], 14, TEAL)
			if int(entity.get("gold", 0)) > 0:
				_text(parent, "选取任一物品后，另获 %d 金币。" % int(entity.gold), 14, GOLD)
		"gold":
			_text(parent, "获得 %d 金币，拾取后不会刷新。" % int(entity.amount), 15, GOLD)
		"key":
			var key_kind := Keys.kind(entity)
			_text(parent, "获得 %d 把%s，仅用于%s。拾取后不会刷新。" % [entity.amount, Keys.key_name(key_kind), Keys.door_name(key_kind)], 15, Keys.COLORS[key_kind])
		"shop":
			_text(parent, "已售出一件商品，本局不再补货。" if entity.purchased else "三件商品选购一件。不买可以离开，下次回来仍可购买。", 15, MUTED)
			if include_options:
				for id in entity.offers:
					var offer: Dictionary = game.shop_offer(str(id))
					_text(parent, "%s · %s · %d 金币" % [offer.name, offer.description, offer.price], 13, GOLD)
		_:
			_text(parent, str(entity.get("description", "")), 14, MUTED)
	if entity.type in ["enemy", "door"]:
		for link in game.floor_data().get("guard_links", []):
			if int(link.gate[0]) != cell.x or int(link.gate[1]) != cell.y:
				continue
			var reward: Dictionary = game.entity_at(Vector2i(int(link.reward[0]), int(link.reward[1])))
			if reward.get("type", "") == "chest":
				var item: Dictionary = game.db.item(reward.item_id)
				_text(parent, "守护奖励：%s（%s），金币 +%d。" % [item.name, item.description, reward.gold], 14, GOLD)
			elif reward.get("type", "") == "choice":
				_text(parent, "守护奖励（二选一，另获 %d 金币）：" % int(reward.gold), 14, GOLD)
				for option in game.reward_options(reward):
					_text(parent, "%s · %s" % [option.name, option.description], 14, TEAL)
			elif reward.get("type", "") == "gold":
				_text(parent, "守护奖励：%d 金币。" % int(reward.amount), 14, GOLD)

func _pending_panel() -> void:
	var box := _panel(body)
	var pending: Dictionary = game.state.pending
	if pending.kind == "floor_choice":
		_text(box, "第 %d 层 · 选择地图主题" % int(pending.get("destination", int(game.state.floor) + 1)), 23, GOLD)
		_text(box, "只选择一次。装备位于支路，先查看守卫与钥匙成本；以后往返不再重选。" if int(game.state.get("generator_version", 0)) > 0 else "旧版布局：三种主题均有长枪、板甲和泉水补给，往返不重选。", 14, MUTED)
		for id in Core.THEMES:
			var choice: Dictionary = game.floor_choices()[id]
			var card := _panel(body)
			_text(card, choice.name + "：" + choice.description, 15)
			_button(card, "进入" + choice.name, func(): _act(func(): return game.choose_floor(id)), false, "PrimaryButton")
	elif pending.kind == "stairs":
		_text(box, "前往已探索的第 %d 层" % int(pending.destination), 22, GOLD)
		_text(box, "楼层布局、怪物、宝箱和商人状态都会保留。", 14, MUTED)
		_button(box, "通过楼梯", func(): _act(game.confirm_interaction), false, "PrimaryButton")
	else:
		var cell: Vector2i = game.pending_cell()
		var entity: Dictionary = game.entity_at(cell)
		_describe(box, cell, false)
		if entity.get("type", "") == "shop":
			for index in entity.offers.size():
				var offer: Dictionary = game.shop_offer(str(entity.offers[index]))
				var result: Dictionary = game.shop_preview(str(entity.offers[index]))
				var card := _panel(body)
				_text(card, "商品 %d · %d 金币" % [index + 1, offer.price], 14, GOLD)
				if offer.has("item_id"):
					_item_card(card, str(offer.item_id))
				else:
					_text(card, str(offer.name) + " · " + str(offer.description), 15)
				_text(card, Rewards.summary(result).replace("领取后", "购买后"), 14, TEAL if result.ok else MUTED)
				if entity.purchased:
					_text(card, "已售罄 · 本局不再补货", 14, MUTED)
				_button(card, "购买 %s · %d 金币" % [offer.name, offer.price], func(): _act(func(): return game.buy(index)), entity.purchased or not result.ok, "PrimaryButton")
		elif entity.get("type", "") in ["choice", "event", "rest"]:
			var options: Array = game.reward_options(entity)
			for index in options.size():
				var result := Rewards.resolve(game.db, game.state.player, options[index])
				var card := _panel(body)
				_text(card, "选项 %d · %s" % [index + 1, options[index].name], 16, GOLD)
				if options[index].has("item_id"):
					_item_card(card, str(options[index].item_id))
				else:
					_text(card, str(options[index].get("description", "")), 15, MUTED)
				_text(card, Rewards.summary(result), 14, TEAL if result.ok else RED)
				_button(card, "选择 · " + str(options[index].name), func(): _act(func(): return game.choose_reward(index)), not result.ok, "PrimaryButton")
		elif entity.get("type", "") == "potion":
			_button(box, "使用药剂", func(): _act(game.confirm_interaction), int(game.state.player.hp) >= int(game.stats().max_hp), "PrimaryButton")
		elif entity.get("type", "") == "door":
			var key_kind := Keys.kind(entity)
			var enough := Keys.count(game.state.player, key_kind) >= int(entity.cost)
			_button(box, "消耗 %d 把%s开门" % [int(entity.cost), Keys.key_name(key_kind)] if enough else Keys.key_name(key_kind) + "不足", func(): _act(game.confirm_interaction), not enough, "PrimaryButton")
		else:
			_button(box, "确认挑战", _fight, false, "DangerButton" if game.preview(cell).get("lethal", false) else "PrimaryButton")

func _item_card(parent: Node, id: String, count: int = 1) -> void:
	var item: Dictionary = game.db.item(id)
	var row := HBoxContainer.new()
	parent.add_child(row)
	var icon = ItemIcon.new()
	icon.item = item
	icon.custom_minimum_size = Vector2(44, 48)
	row.add_child(icon)
	var copy := VBoxContainer.new()
	copy.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	row.add_child(copy)
	var kind := "遗物" if item.get("kind", "") == "relic" else "装备"
	_text(copy, "%s ×%d · %s %d阶" % [item.get("name", id), count, kind, int(item.get("tier", 1))], 15, GOLD)
	_text(copy, str(item.get("description", "")), 14, MUTED)

func _fight() -> void:
	if _transaction_pending():
		return
	var hp_before := int(game.state.player.hp)
	var result: String = game.confirm_interaction()
	if result == "confirm_lethal":
		_confirm("这场战斗会死亡", "可以先去其他楼层变强，再回来。仍要挑战并结束本次探索吗？", func(): _act(func(): return game.confirm_interaction(true)))
	else:
		notice = result
		_render(true)
		if int(game.state.player.hp) < hp_before and not _transaction_pending():
			audio.play(get_tree(), "hit", settings)
			_flash_board(RED)

func _select_cell(cell: Vector2i) -> void:
	if _transaction_pending() or modal_open or overlay_kind != "" or not game.state.pending.is_empty():
		return
	selected = cell
	var delta: Vector2i = cell - game.position()
	if game.active() and game.state.pending.is_empty() and absi(delta.x) + absi(delta.y) <= 1:
		_act(func(): return game.interact(cell))
	else:
		var entity: Dictionary = game.entity_at(cell)
		notice = "已选中：" + str(entity.get("name", "通路")) + "。可展开查看完整预览。"
		_render()

func _act(action: Callable) -> void:
	if _transaction_pending():
		_render()
		return
	var previous_position: Vector2i = game.position()
	var previous_hp := int(game.state.player.hp)
	var previous_gold := int(game.state.player.gold)
	var pending_type := str(game.entity_at(game.pending_cell()).get("type", "")) if not game.state.pending.is_empty() else ""
	var previous_items: int = game.state.player.equipment_ids.size() + game.state.player.relic_ids.size()
	var previous_floor := int(game.state.floor)
	var result = action.call()
	notice = str(result) if result is String else ""
	selected = game.pending_cell() if not game.state.pending.is_empty() else game.position()
	_render(previous_floor != int(game.state.floor) or not game.state.pending.is_empty())
	if _transaction_pending():
		return
	if int(game.state.player.hp) < previous_hp:
		audio.play(get_tree(), "hit", settings)
		_flash_board(Color("ed9395"))
	elif game.state.player.equipment_ids.size() + game.state.player.relic_ids.size() > previous_items or int(game.state.player.gold) > previous_gold or int(game.state.player.hp) > previous_hp:
		audio.play(get_tree(), "pickup", settings)
		_flash_board(Color("e0bf80"))
	elif pending_type == "door" and game.state.pending.is_empty():
		audio.play(get_tree(), "door", settings)
	elif previous_position != game.position():
		audio.play(get_tree(), "step", settings)

func _confirm(title: String, text: String, action: Callable) -> void:
	modal_open = true
	var previous_focus := get_viewport().gui_get_focus_owner()
	var shade := ColorRect.new()
	shade.color = Color(0.02, 0.04, 0.06, 0.65)
	if is_instance_valid(map_root):
		_set_map_input()
		map_root.add_child(shade)
		# Diagnostics stay above the dimmer and outside the centered dialog.
		map_root.move_child(shade, save_error_panel.get_index())
	else:
		add_child(shade)
	shade.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	var dialog := ConfirmationDialog.new()
	dialog.theme = theme
	dialog.borderless = true
	dialog.title = title
	dialog.dialog_text = title + "\n\n" + text
	dialog.dialog_autowrap = true
	dialog.ok_button_text = "确认"
	dialog.cancel_button_text = "取消"
	dialog.get_ok_button().theme_type_variation = "DangerButton"
	dialog.get_cancel_button().theme_type_variation = "QuietButton"
	dialog.get_label().add_theme_font_size_override("font_size", 16)
	add_child(dialog)
	dialog.confirmed.connect(func():
		modal_open = false
		shade.queue_free()
		dialog.queue_free()
		action.call()
		if is_instance_valid(map_root):
			_set_map_input()
	)
	dialog.canceled.connect(func():
		modal_open = false
		shade.queue_free()
		dialog.queue_free()
		if is_instance_valid(map_root):
			_set_map_input()
		_restore_focus.call_deferred(previous_focus)
	)
	dialog.popup_centered(Vector2i(mini(440, int(size.x) - 32), 220))
	# Prefer the non-destructive action; the popup's own viewport traps keyboard focus.
	dialog.get_cancel_button().grab_focus()

func _is_campaign() -> bool:
	return game.has_method("is_campaign") and game.is_campaign()

func _transaction_pending() -> bool:
	return game.has_method("retry_save") and bool(game.transaction_pending)

func _story_event() -> Dictionary:
	return game.story_event() if game.has_method("story_event") else {}

func _request_start(seed_text: String, campaign: bool) -> void:
	var action := func():
		if game.active() and _is_campaign():
			var error: String = game.abandon_run()
			if not error.is_empty():
				notice = error
				_render(true)
				return
		if campaign:
			_start_campaign(seed_text)
		else:
			_start(seed_text)
	if game.active():
		_confirm("开始新旅程？", "本次进行中的旅程将被放弃，不获得灵魂；账户火种和历史保留。", action)
	else:
		action.call()

func _start_campaign(seed_text: String) -> void:
	var result: String = game.start_campaign(seed_text)
	if not result.is_empty():
		notice = result
		_render(true)
		return
	selected = Vector2i(-1,-1)
	notice = ""
	story_id = ""
	story_line = 0
	overlay_kind = ""
	_open_map()

func _advance_story() -> void:
	if story_line + 1 >= _story_event().get("lines", []).size():
		_finish_story()
	else:
		story_line += 1
		_refresh_map(true)
		_restore_focus.call_deferred(overlay_next)

func _finish_story() -> void:
	audio.stop()
	if game.has_method("acknowledge_story"):
		game.acknowledge_story()
	story_line = 0
	story_id = ""
	overlay_kind = ""
	_refresh_map(true)

func _retry_save() -> void:
	if game.has_method("retry_save"):
		game.retry_save()
	else:
		game.save_game()
	_render(true)

func _save_preferences() -> void:
	if not settings.write():
		notice = settings.last_error

func _pin_run_key() -> String:
	return str(game.state.get("run_id", "trial:" + str(game.state.get("seed", ""))))

func _floor_pins(floor_number: int) -> Dictionary:
	return settings.pins.get(_pin_run_key(), {}).get(str(floor_number), {})

func _toggle_pin() -> void:
	var run_key := _pin_run_key()
	var floor_key := str(int(game.state.floor))
	if not settings.pins.has(run_key):
		settings.pins[run_key] = {}
	if not settings.pins[run_key].has(floor_key):
		settings.pins[run_key][floor_key] = {}
	var pins: Dictionary = settings.pins[run_key][floor_key]
	var key := Core.cell_key(selected)
	if pins.has(key):
		pins.erase(key)
	else:
		var entity: Dictionary = game.entity_at(selected)
		pins[key] = {"name": str(entity.get("name", "目标")), "loss": int(game.preview(selected).get("loss", 0))}
	_save_preferences()
	_refresh_map()

func _flash_board(tint: Color) -> void:
	if settings.reduce_motion or not is_instance_valid(board) or overlay_kind != "":
		return
	if is_instance_valid(feedback_tween):
		feedback_tween.kill()
	board.modulate = tint
	feedback_tween = create_tween()
	feedback_tween.tween_property(board, "modulate", Color.WHITE, 0.18)


func _request_quit() -> void:
	if modal_open:
		return
	if not _transaction_pending():
		game.save_game()
	if _transaction_pending() or not game.save_error.is_empty():
		_confirm("退出会丢失未保存变化", "退出会丢失本次未保存变化；上次成功存档仍保留。建议取消并重试保存。", func(): get_tree().quit())
	else:
		get_tree().quit()
