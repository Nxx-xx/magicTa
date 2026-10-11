extends Control

const CompactScreens = preload("res://scripts/ui/compact_screens.gd")
const Core = preload("res://scripts/core/campaign_engine.gd")
const CampaignPanels = preload("res://scripts/ui/campaign_panels.gd")
const MainMenu = preload("res://scripts/ui/main_menu.gd")
const PolishTrim = preload("res://scripts/ui/art_polish_d_frame.gd")
const CampMap = preload("res://scripts/ui/camp_map.gd")
const CampLayout = preload("res://scripts/core/camp_layout.gd")
const StoryIntroStage = preload("res://scripts/ui/story_intro_stage.gd")
const Preferences = preload("res://scripts/ui/presentation_settings.gd")
const AudioFeedback = preload("res://scripts/ui/audio_feedback.gd")
const CombatPresentation = preload("res://scripts/ui/combat_presentation.gd")
const Phase3Player = preload("res://scripts/ui/phase3_combat_player.gd")
const Tutorial = preload("res://scripts/ui/phase3_tutorial.gd")
const ActionChoices = preload("res://scripts/ui/action_choices.gd")
const ActionIcon = preload("res://scripts/ui/action_icon.gd")
const RuinPanel = preload("res://scripts/ui/phase3_ruin_panel.gd")
const RelicTrail = preload("res://scripts/core/relic_trail.gd")
const BuildSummary = preload("res://scripts/ui/phase3_build_summary.gd")
const Board = preload("res://scripts/ui/grid_board.gd")
const Minimap = preload("res://scripts/ui/map_minimap.gd")
const ClickPath = preload("res://scripts/ui/click_path.gd")
const TouchScroll = preload("res://scripts/ui/touch_scroll.gd")
const Keys = preload("res://scripts/core/map_keys.gd")
const Enemies = preload("res://scripts/core/enemy_rules.gd")
const Rewards = preload("res://scripts/core/rewards.gd")
const ItemIcon = preload("res://scripts/ui/item_icon.gd")
const RuntimeArt = preload("res://scripts/ui/runtime_art.gd")
const FONT = preload("res://assets/ui/visual_v01/body_font.tres")
const GOLD := Color("e0bf80")
const TEAL := Color("83d5bf")
const MUTED := Color("a2b3c3")
const RED := Color("ed9395")
var game = Core.new()
var page := "title"
var section_return_page := "title"
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
var minimap: Button
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
var held_move_keys: Array[int] = []
var queued_cell := Vector2i(-1, -1)
var click_route: Array[Vector2i] = []
var touch_scroll := TouchScroll.new()
var walk_audio_enabled := true
var overview_button: Button
var recenter_button: Button
var map_notice: Label
var overlay: Control
var overlay_panel: PanelContainer
var overlay_title: Label
var overlay_close: Button
var overlay_kind := ""
var chest_receipt: Dictionary = {}
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
var story_stage: Control
var save_retry: Button
var feedback_tween: Tween
var camp_sections: Dictionary = {}
var camp_position := CampLayout.SPAWN
var camp_view := ""
var camp_upgrade_tab := 0
var camp_growth_level := 0
var pending_camp_entry: Dictionary = {}
var camp_map: Control
var combat_view: Control
var combat_context: Dictionary = {}
var phase3_challenge := "p3_c0"
var phase3_config := "default"
var tutorial_view: PanelContainer
var discovery_scheduled := false
var viewed_entities: Dictionary = {}
var preview_evidence: Dictionary = {}
var tutorial_pending_evidence: Dictionary = {}
var equipment_comparison: Dictionary = {}
var encounter_action: Button
var encounter_details := false
var encounter_details_box: VBoxContainer
var combat_feedback: Label

func _exit_tree() -> void:
	audio.stop()
	get_window().content_scale_mode = previous_scale_mode
	get_window().content_scale_size = previous_scale_size


func _ready() -> void:
	game.chest_collected.connect(func(receipt: Dictionary): chest_receipt = receipt.duplicate(true))
	audio.prepare_steps()
	theme = preload("res://assets/ui/ui_polish_v02/ui_polish_theme.tres")
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
	resized.connect(_cancel_ui_drag)
	resized.connect(touch_scroll.cancel)
	_render()

func _notification(what: int) -> void:
	if what == NOTIFICATION_WM_CLOSE_REQUEST:
		_request_quit()
	elif what in [NOTIFICATION_APPLICATION_PAUSED, NOTIFICATION_APPLICATION_FOCUS_OUT]:
		touch_scroll.cancel()
		walk_audio_enabled = false
		if is_instance_valid(board):
			board.cancel_pointer()
		_cancel_ui_drag()
		audio.stop()
		game.save_game()
		if _transaction_pending() and is_instance_valid(combat_view):
			combat_view.queue_free()
			combat_view = null
			_render(true)
		# Background autosaves do not otherwise refresh the map or its open sheet.
		if is_instance_valid(map_root):
			_refresh_save_error()

func _key_direction(key: int) -> Vector2i:
	match key:
		KEY_W, KEY_UP: return Vector2i.UP
		KEY_S, KEY_DOWN: return Vector2i.DOWN
		KEY_A, KEY_LEFT: return Vector2i.LEFT
		KEY_D, KEY_RIGHT: return Vector2i.RIGHT
	return Vector2i.ZERO

func _input(event: InputEvent) -> void:
	if touch_scroll.handle(event, self, _cancel_ui_drag):
		get_viewport().set_input_as_handled()
		return
	if event is InputEventKey and event.pressed and not event.echo and event.keycode == KEY_ESCAPE and not modal_open and page != "map":
		if _back_detail():
			get_viewport().set_input_as_handled()
			return
		if page in ["records", "settings", "codex"]:
			_back_section()
		elif page == "menu":
			if not camp_view.is_empty(): _show_camp()
			else: _show_title()
		get_viewport().set_input_as_handled()
		return
	# Always process release, including when an overlay opened during this press.
	if event is InputEventKey and not event.pressed:
		held_move_keys.erase(int(event.keycode))
	if is_instance_valid(combat_view):
		if event is InputEventKey and event.pressed and not event.echo and event.keycode == KEY_ESCAPE:
			_combat_escape()
			get_viewport().set_input_as_handled()
		return
	if page == "map" and event is InputEventKey and event.pressed and event.keycode == KEY_ESCAPE and not modal_open and overlay_kind != "":
		if _back_detail():
			get_viewport().set_input_as_handled()
			return
		_close_overlay()
		get_viewport().set_input_as_handled()
		return
	if not _can_walk() or not event is InputEventKey or event.ctrl_pressed or event.alt_pressed:
		return
	var direction := _key_direction(event.keycode)
	if direction == Vector2i.ZERO:
		return
	get_viewport().set_input_as_handled()
	if event.pressed and not event.echo and not int(event.keycode) in held_move_keys:
		click_route.clear()
		queued_cell = Vector2i(-1, -1)
		held_move_keys.append(int(event.keycode))
		_continue_walk()

func _back_detail() -> bool:
	if not is_instance_valid(body): return false
	for child in body.find_children("*","Control",true,false):
		if child.is_visible_in_tree() and child.has_method("back_to_overview") and child.back_to_overview(): return true
	return false

func _can_walk() -> bool:
	return page == "map" and is_instance_valid(board) and not modal_open and overlay_kind == "" and not _transaction_pending() and game.active() and game.state.pending.is_empty()

func _cancel_ui_drag() -> void:
	_stop_movement_input()
	if is_instance_valid(board):
		board.cancel_pointer()
	if is_instance_valid(camp_map):
		camp_map.cancel_walk()
		camp_map.board.cancel_pointer()

func _stop_movement_input() -> void:
	held_move_keys.clear()
	queued_cell = Vector2i(-1, -1)
	click_route.clear()

func _continue_walk() -> void:
	if not _can_walk():
		_stop_movement_input()
		return
	if board.moving:
		return
	if queued_cell.x >= 0:
		var cell := queued_cell
		queued_cell = Vector2i(-1, -1)
		_select_cell(cell)
		return
	if not click_route.is_empty():
		var next: Vector2i = click_route.pop_front()
		var delta := next - game.position()
		if absi(delta.x) + absi(delta.y) != 1 or game.is_wall(next) or (not click_route.is_empty() and not ClickPath.transit_allowed(game, next)):
			_stop_movement_input()
			return
		var before: Vector2i = game.position()
		_act(func(): return game.interact(next))
		if game.position() == before or not _can_walk():
			_stop_movement_input()
		return
	if not held_move_keys.is_empty():
		_move_direction(_key_direction(held_move_keys.back()))

func _walk_footstep() -> void:
	if walk_audio_enabled and _can_walk():
		audio.play_step(get_tree(), settings)

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
	_stop_movement_input()
	audio.stop_steps()
	map_root = null
	combat_view = null
	combat_context = {}
	overlay_kind = ""
	var previous_scroll := scroll.scroll_vertical if is_instance_valid(scroll) and not reset_scroll else 0
	for child in get_children():
		remove_child(child)
		child.queue_free()
	camp_map = null
	seed_input = null
	if page == "title":
		margin = null
		var title_screen := MainMenu.new()
		add_child(title_screen)
		title_screen.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
		title_screen.setup(self)
		return
	var bg := ColorRect.new()
	bg.color = Color("0b111c")
	bg.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(bg)
	bg.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	PolishTrim.attach(bg, "backdrop")
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
	var section_title: String = {"records":"旅程记录", "settings":"游戏设置", "codex":"旅途图鉴"}.get(page, "塔境 / 公主救援记")
	_text(row, section_title, 25, GOLD)
	if page == "menu":
		var home := _button(row, "主菜单", _show_title, false, "QuietButton")
		home.name = "CampHome"
		home.custom_minimum_size.x = 84
		home.autowrap_mode = TextServer.AUTOWRAP_OFF
		home.size_flags_horizontal = Control.SIZE_SHRINK_END
	if page in ["records", "settings", "codex"]:
		_button(shell, "‹ 返回主菜单" if section_return_page == "title" else "‹ 返回营地", _back_section, false, "QuietButton")
	if page == "map":
		var camp_button := _button(row, "回营", _show_camp)
		camp_button.name = "ReturnToCamp"
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
	elif page == "codex":
		CampaignPanels.codex(self)
	elif page == "records":
		CampaignPanels.records(self)
	elif page == "settings":
		CampaignPanels.settings(self, body)
	if page != "menu":
		_text(shell, "十层营救 · 自动保存 · 可跨层回溯", 11, MUTED).horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	scroll.set_deferred("scroll_vertical", previous_scroll)

func _fit_width() -> void:
	for child in get_children():
		if child is ConfirmationDialog and child.is_inside_tree() and child.visible:
			_fit_confirmation(child)
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
	PolishTrim.attach(hud_back)
	hud = VBoxContainer.new()
	hud.name = "FixedStatus"
	hud.add_theme_constant_override("separation", 4)
	map_root.add_child(hud)
	var heading := HBoxContainer.new()
	hud.add_child(heading)
	floor_label = _text(heading, "", 20, GOLD)
	floor_label.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	var menu_button := _button(heading, "回营", _show_camp)
	menu_button.name = "ReturnToCamp"
	menu_button.custom_minimum_size = Vector2(64, 44)
	menu_button.size_flags_horizontal = Control.SIZE_SHRINK_END
	var stats_row := HBoxContainer.new()
	hud.add_child(stats_row)
	hp_label = _text(stats_row, "", 18, TEAL)
	stats_label = _text(stats_row, "", 16)
	stats_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_RIGHT
	health = ProgressBar.new()
	health.show_percentage = false
	health.custom_minimum_size.y = 6
	health.mouse_filter = Control.MOUSE_FILTER_IGNORE
	hud.add_child(health)
	var resources := HBoxContainer.new()
	hud.add_child(resources)
	money_label = _text(resources, "", 14, GOLD)
	money_label.theme_type_variation = "StatChip"
	money_label.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	money_label.custom_minimum_size.y = 24
	for kind in Keys.TYPES:
		key_labels[kind] = _text(resources, "", 14, Keys.COLORS[kind])
		key_labels[kind].theme_type_variation = "StatChip"
		key_labels[kind].horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
		key_labels[kind].vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	board_frame = PanelContainer.new()
	board_frame.theme_type_variation = "MapFrame"
	board_frame.mouse_filter = Control.MOUSE_FILTER_IGNORE
	map_root.add_child(board_frame)
	board = Board.new()
	board.name = "PersistentBoard"
	board.exploration = true
	board.lock_to_hero = true
	map_root.add_child(board)
	board.cell_selected.connect(_select_cell)
	board.arrived.connect(_continue_walk)
	board.footstep.connect(_walk_footstep)
	board.pan_started.connect(_stop_movement_input)
	board.view_changed.connect(_refresh_view_controls)
	detail_panel = PanelContainer.new()
	detail_panel.name = "TargetSummary"
	detail_panel.theme_type_variation = "TargetPanel"
	var summary_style := _box(Color(0.04, 0.08, 0.12, 0.92), Color("526777"))
	summary_style.content_margin_top = 4
	summary_style.content_margin_bottom = 4
	detail_panel.add_theme_stylebox_override("panel", summary_style)
	map_root.add_child(detail_panel)
	var details := VBoxContainer.new()
	details.add_theme_constant_override("separation", 4)
	detail_panel.add_child(details)
	var detail_row := HBoxContainer.new()
	details.add_child(detail_row)
	detail_title = _text(detail_row, "", 17, GOLD)
	detail_title.custom_minimum_size.y = 22
	detail_button = _button(detail_row, "详情", func(): _open_overlay("target"))
	detail_button.size_flags_horizontal = Control.SIZE_SHRINK_END
	detail_button.custom_minimum_size = Vector2(64, 44)
	detail_copy = _text(details, "", 15, TEAL)
	detail_copy.custom_minimum_size.y = 22
	detail_hint = _text(details, "", 13, MUTED)
	map_notice = _text(map_root, "", 13, GOLD)
	map_notice.mouse_filter = Control.MOUSE_FILTER_IGNORE
	map_notice.max_lines_visible = 1
	map_notice.text_overrun_behavior = TextServer.OVERRUN_TRIM_ELLIPSIS
	map_notice.add_theme_color_override("font_shadow_color", Color.BLACK)
	map_notice.add_theme_constant_override("shadow_offset_x", 1)
	map_notice.add_theme_constant_override("shadow_offset_y", 1)
	recenter_button = _button(map_root, "回到角色", func(): board.recenter(), false, "QuietButton")
	recenter_button.custom_minimum_size = Vector2(104, 44)
	minimap = Minimap.new()
	minimap.board = board
	map_root.add_child(minimap)
	minimap.pressed.connect(_toggle_overview)
	controls = VBoxContainer.new()
	controls.name = "FixedControls"
	controls.add_theme_constant_override("separation", 8)
	map_root.add_child(controls)
	var tools_row := HBoxContainer.new()
	controls.add_child(tools_row)
	_button(tools_row, "行囊", func(): _open_overlay("inventory"), false, "QuietButton").custom_minimum_size.y = 44
	_button(tools_row, "楼层", func(): _open_overlay("floors"), false, "QuietButton").custom_minimum_size.y = 44
	_button(tools_row, "记录", func(): _open_overlay("log"), false, "QuietButton").custom_minimum_size.y = 44
	var code_button := _button(tools_row, "功能码", func(): _open_overlay("function_code"), false, "QuietButton")
	code_button.name = "OpenFunctionCode"
	code_button.custom_minimum_size.y = 44
	overview_button = _button(tools_row, "全图", _toggle_overview, false, "QuietButton")
	overview_button.custom_minimum_size.y = 44
	# Five persistent tools must keep their labels on one line at 320px.
	for tool_button in tools_row.get_children():
		tool_button.theme_type_variation = "ToolbarButton"
		tool_button.autowrap_mode = TextServer.AUTOWRAP_OFF
		tool_button.add_theme_font_size_override("font_size", 13)
	tutorial_view = Tutorial.create_prompt({})
	tutorial_view.name = "Phase3Tutorial"
	map_root.add_child(tutorial_view)
	tutorial_view.minimum_size_changed.connect(func():
		if is_instance_valid(tutorial_view): tutorial_view.set_deferred("size", Vector2(tutorial_view.size.x, 0))
	)
	tutorial_view.dismissed.connect(func(id): _tutorial_event({"type":"dismiss", "id":id}))
	tutorial_view.skip_requested.connect(func(): _tutorial_event({"type":"skip_all"}))
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
	encounter_action = _button(sheet, "挑战", _request_fight, false, "PrimaryButton")
	encounter_action.name = "EncounterChallenge"
	encounter_action.visible = false
	overlay_close = _button(sheet, "返回地图", _close_overlay, false, "QuietButton")
	story_stage = StoryIntroStage.new()
	story_stage.setup(self)
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
	# Sheet text wraps asynchronously; refit after its temporary minimum size settles.
	overlay_panel.minimum_size_changed.connect(_queue_layout)
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
	var width := minf(size.x - 16, 760)
	var left := (size.x - width) * 0.5
	var header_height := maxf(104.0, hud.get_combined_minimum_size().y)
	var error_height := maxf(84.0, save_error_panel.get_combined_minimum_size().y)
	var error_space := error_height + 8.0 if save_error_panel.visible else 0.0
	var controls_height := 44.0
	hud.position = Vector2(left + 4, 6)
	hud.size = Vector2(width - 8, header_height)
	hud_back.position = Vector2(left - 6, 3)
	hud_back.size = Vector2(width + 12, header_height + 7)
	save_error_panel.position = Vector2(left, header_height + 8)
	save_error_panel.size = Vector2(width, error_height)
	board.position = Vector2(left, header_height + error_space + 12)
	board.size = Vector2(width, maxf(160, size.y - board.position.y - controls_height - 16))
	board_frame.position = board.position - Vector2(3, 3)
	board_frame.size = board.size + Vector2(6, 6)
	controls.position = Vector2(left, size.y - controls_height - 6)
	controls.size = Vector2(width, controls_height)
	detail_panel.position = board.position + Vector2(6, 6)
	detail_panel.size = Vector2(width - 12, 80)
	# Arriving on a stair is not a request to inspect it.
	detail_panel.visible = selected != game.position() and not game.entity_at(selected).is_empty() and not board.overview
	detail_copy.visible = true
	detail_hint.visible = false
	detail_title.add_theme_font_size_override("font_size", 15)
	map_notice.position = board.position + Vector2(10, 8)
	map_notice.size = Vector2(width - 20, 24)
	map_notice.text = notice
	map_notice.visible = not detail_panel.visible and not notice.is_empty() and not board.overview
	board.safe_bottom = 12.0
	recenter_button.position = Vector2(left + width - 114, board.get_rect().end.y - 56)
	recenter_button.size = Vector2(104, 44)
	board.safe_top = 12.0
	var minimap_width := 92.0 if compact else 114.0
	minimap.size = Vector2(minimap_width, minimap_width + 18)
	minimap.position = board.position + board.size - minimap.size - Vector2(8,8)
	board.refit_view()
	_refresh_view_controls()
	var sheet_top := header_height + 12.0 + error_space
	overlay_panel.position = Vector2(left, sheet_top)
	overlay_panel.size = Vector2(width, size.y - sheet_top - 12)
	if overlay_kind == "function_code":
		var code_input = body.get_node_or_null("FunctionCodeInput")
		if code_input != null and code_input.occluded_fraction > 0.0:
			var viewport_height := get_viewport_rect().size.y
			var visible_bottom := minf(size.y, viewport_height * (1.0 - code_input.occluded_fraction) - global_position.y)
			overlay_panel.position.y = 8.0
			overlay_panel.size.y = maxf(1.0, visible_bottom - 20.0)
	if overlay_kind == "chest_reward":
		var available := size.y - sheet_top - 12
		var card_height := minf(available, maxf(230, body.get_combined_minimum_size().y + 130))
		var card_width := minf(width, 400)
		overlay_panel.size = Vector2(card_width, card_height)
		overlay_panel.position.x = (size.x - card_width) * 0.5
		overlay_panel.position.y = sheet_top + (available - card_height) * 0.5
	if _enemy_sheet() and not encounter_details:
		var available := size.y - sheet_top - 12
		var card_height := minf(available, maxf(280, minf(available * 0.72, body.get_combined_minimum_size().y + 200)))
		overlay_panel.size = Vector2(width, card_height)
		overlay_panel.position.y = size.y - card_height - 12
	var shade := overlay.get_child(0) as ColorRect
	shade.color.a = 0.38 if _enemy_sheet() else 0.88
	if is_instance_valid(combat_view):
		combat_view.position = Vector2(left, sheet_top)
		combat_view.size = Vector2(width, maxf(1, size.y - sheet_top - 6))
	_refresh_summary()
	_refresh_tutorial()
	if is_instance_valid(story_stage): story_stage.layout()

func _enemy_sheet() -> bool:
	if overlay_kind not in ["pending", "target"] or game.state.is_empty():
		return false
	var cell: Vector2i = game.pending_cell() if overlay_kind == "pending" else selected
	return game.inside(cell) and game.entity_at(cell).get("type", "") == "enemy"

func _move_direction(direction: Vector2i) -> void:
	if not _can_walk() or board.moving:
		return
	if not board.following:
		board.recenter()
	var before: Vector2i = game.position()
	_act(func(): return game.step(direction))
	if game.position() == before or not _can_walk():
		_stop_movement_input()

func _toggle_overview() -> void:
	_stop_movement_input()
	board.set_overview(not board.overview)
	_layout_map()

func _refresh_view_controls() -> void:
	if not is_instance_valid(overview_button):
		return
	overview_button.text = "探索" if board.overview else "全图"
	recenter_button.visible = not board.overview and not board.following and overlay_kind == "" and not modal_open
	minimap.visible = not board.overview and overlay_kind == "" and not modal_open

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
	minimap.queue_redraw()
	_refresh_summary()
	var next_overlay := overlay_kind
	if not game.state.pending.is_empty():
		next_overlay = "pending"
	elif next_overlay == "pending":
		next_overlay = ""
	if _transaction_pending():
		next_overlay = "save_blocked"
	elif not combat_context.is_empty():
		next_overlay = "combat"
	elif not chest_receipt.is_empty():
		next_overlay = "chest_reward"
	elif game.state.pending.is_empty() and not _story_event().is_empty():
		next_overlay = "story"
	elif not game.active() and not next_overlay in ["floors", "inventory", "log", "settings"]:
		next_overlay = "result"
	elif next_overlay in ["story", "save_blocked"]:
		next_overlay = ""
	var changed := next_overlay != overlay_kind
	if changed: encounter_details = false
	if changed and next_overlay != "":
		return_focus = get_viewport().gui_get_focus_owner()
	overlay_kind = next_overlay
	# Only the sheet's contents change. HUD, board and controls retain identity/focus.
	var old_scroll := scroll.scroll_vertical
	var key := str([overlay_kind, player.equipment_ids, player.relic_ids, stats, game.state.seed, game.state.floor]) if overlay_kind in ["", "inventory"] else ""
	if key.is_empty() or key != sheet_cache_key:
		_populate_sheet()
		sheet_cache_key = key
	overlay.visible = overlay_kind != "" and overlay_kind != "combat"
	overlay_close.text = "离开" if overlay_kind == "pending" else ("跳过对白" if overlay_kind == "story" else ("返回结算" if not game.active() else "返回地图"))
	if overlay_kind == "chest_reward": overlay_close.text = "确定"
	overlay_close.visible = not overlay_kind in ["result", "save_blocked"]
	encounter_action.visible = overlay_kind == "pending" and _enemy_sheet()
	if encounter_action.visible:
		var report: Dictionary = game.preview(game.pending_cell())
		encounter_action.text = "仍要挑战" if report.get("lethal", false) else "挑战"
		encounter_action.disabled = not report.get("ok", true)
		encounter_action.theme_type_variation = "DangerButton" if report.get("lethal", false) else "PrimaryButton"
	if _enemy_sheet(): overlay_close.text = "离开"
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
	if is_instance_valid(story_stage):
		story_stage.set_active(overlay_kind == "story" and StoryIntroStage.supports(_story_event()))
	if overlay_kind == "combat":
		return
	_clear(body)
	scroll.vertical_scroll_mode = ScrollContainer.SCROLL_MODE_AUTO
	body.size_flags_vertical = Control.SIZE_FILL
	match overlay_kind:
		"chest_reward":
			overlay_title.text = "获得道具"
			_item_card(body, str(chest_receipt.item_id), 1, true)
			if int(chest_receipt.gold) > 0:
				_text(body, "金币 +%d" % int(chest_receipt.gold), 16, GOLD)
		"function_code":
			overlay_title.text = "功能码"
			_function_code_panel()
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
			var pending_type := str(game.entity_at(game.pending_cell()).get("type", ""))
			overlay_title.text = {"enemy":"遭遇敌人", "shop":"商店 · 选购补给", "up":"上行楼梯", "down":"下行楼梯"}.get(pending_type, "待确认 · 查看成本后行动")
			_pending_panel()
		"target":
			overlay_title.text = "查看目标 · 不会远程执行"
			if game.inside(selected):
				_describe(body, selected)
			else:
				_text(body, "点击可达地板，角色会沿四向合法路径走到目标；点击敌人、门或楼梯会先靠近，再等待确认。探索视角始终以主角为中心，点击右下角小地图查看全图。全图也可点击移动，方向键 / WASD 可连续行走。长列表可直接拖动内容。", 16)
			if game.inside(selected) and not game.entity_at(selected).is_empty():
				_button(body, "取消目标标记" if _floor_pins(int(game.state.floor)).has(Core.cell_key(selected)) else "标记目标 · 留待回溯", _toggle_pin)
			if not _enemy_sheet():
				_text(body, "怪物 1 / 2 / 3 表示强度档，“回”表示回溯守卫。铜 / 银 / 金门只消耗同类钥匙。", 14, MUTED)
		"log":
			overlay_title.text = "探索记录"
			CompactScreens.log(self)
		"result":
			_tutorial_event({"type":"result_viewed"}, false)
			if _is_campaign():
				CampaignPanels.result(self)
				return
			overlay_title.text = "火把熄灭了"
			_text(body, str(game.state.last_message), 16, RED)
			_button(body, "相同种子重新开始", func(): _request_start(str(game.state.seed)), false, "PrimaryButton")
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
			title = str(enemy.name) + " · " + Enemies.classification(enemy)
			copy = "生命 %d · 攻击 %d · 防御 %d" % [enemy.hp, enemy.attack, enemy.defense]
			tint = MUTED
			hint = "%s\n击杀奖励 %d 金币" % [enemy.get("combat_hint", ""), int(enemy.gold_reward) + int(game.stats().gold_bonus)]
			for link in game.floor_data().get("guard_links", []):
				if Vector2i(int(link.gate[0]), int(link.gate[1])) == selected:
					hint += " · 守护奖励见详情"
					break
		elif not entity.is_empty():
			copy = "相邻格可交互 · 完整成本与收益见详情"
	if _is_campaign() and game.state.get("side_objective_complete", false):
		hint = "王权指环已找回，继续向塔顶前进。"
	elif not _is_campaign() and game.state.objective_complete:
		hint = "目标已完成，可以继续探索。"
	if not notice.is_empty() and game.entity_at(selected).get("type", "") != "enemy":
		hint = notice
	# Keep enemy attributes on their own row so long classifications cannot hide them.
	detail_title.text = title
	detail_title.max_lines_visible = 1
	detail_title.text_overrun_behavior = TextServer.OVERRUN_TRIM_ELLIPSIS
	detail_copy.text = hint if compact and game.entity_at(selected).get("type", "") != "enemy" else copy
	detail_copy.max_lines_visible = 1
	detail_copy.text_overrun_behavior = TextServer.OVERRUN_TRIM_ELLIPSIS
	detail_copy.add_theme_color_override("font_color", tint)
	detail_title.add_theme_color_override("font_color", tint if compact else GOLD)
	detail_hint.text = hint
	detail_hint.max_lines_visible = 2
	detail_hint.text_overrun_behavior = TextServer.OVERRUN_TRIM_ELLIPSIS

func _inventory_content() -> void:
	CompactScreens.inventory(self)

func _open_overlay(kind: String) -> void:
	if not combat_context.is_empty():
		return
	return_focus = get_viewport().gui_get_focus_owner()
	encounter_details = false
	overlay_kind = kind
	_refresh_map(true)
	if kind == "target": _inspect_phase3(selected)
	_restore_focus.call_deferred(overlay_close)

func _function_code_panel() -> void:
	var input = preload("res://scripts/ui/mobile_code_input.gd").new()
	input.name = "FunctionCodeInput"
	input.placeholder_text = "请输入功能码"
	input.max_length = 32
	input.custom_minimum_size.y = 48
	input.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	body.add_child(input)
	input.keyboard_layout_changed.connect(_queue_layout)
	_text(body, "输入功能码，将本局生命、攻击、防御设为 1000。新旅程恢复正常初始属性。", 16, MUTED)
	var feedback := _text(body, "", 14, RED)
	feedback.name = "FunctionCodeFeedback"
	input.keyboard_failed.connect(func(): feedback.text = "键盘未能打开，请再次点击输入框。")
	var submit := func():
		var error: String = game.apply_function_code(input.text)
		if not error.is_empty():
			feedback.text = error
			if _transaction_pending(): _refresh_map(true)
			return
		viewed_entities.clear()
		equipment_comparison.clear()
		preview_evidence.clear()
		notice = "功能码已生效：生命 1000/1000，攻击 1000，防御 1000。"
		overlay_kind = ""
		_refresh_map(true)
	var activate := _button(body, "启用功能码", submit, _transaction_pending() or not game.active(), "PrimaryButton")
	activate.name = "ApplyFunctionCode"
	input.text_submitted.connect(func(_value): submit.call())

func _close_overlay() -> void:
	if not combat_context.is_empty():
		if is_instance_valid(combat_view):
			_combat_escape()
		return
	if overlay_kind == "story":
		_finish_story()
		return
	if _transaction_pending():
		return
	_complete_inspection()
	if overlay_kind == "pending":
		game.cancel_pending()
	if overlay_kind == "chest_reward":
		chest_receipt.clear()
	overlay_kind = ""
	notice = ""
	_refresh_map(true)
	if is_instance_valid(return_focus) and return_focus.is_visible_in_tree():
		_restore_focus.call_deferred(return_focus)

func _restore_focus(control: Control) -> void:
	if is_instance_valid(combat_view) and (not is_instance_valid(control) or not combat_view.is_ancestor_of(control)):
		var primary: Control = combat_view._primary if _is_phase3() else combat_view.primary
		primary.grab_focus()
		return
	if is_instance_valid(control) and control.is_inside_tree() and control.is_visible_in_tree():
		if not control is BaseButton or not control.disabled:
			control.grab_focus()

func _set_map_input() -> void:
	var blocked: bool = overlay_kind != "" or modal_open or _transaction_pending() or not game.active() or not game.state.pending.is_empty()
	board.mouse_filter = Control.MOUSE_FILTER_IGNORE if blocked else Control.MOUSE_FILTER_STOP
	if blocked:
		board.cancel_pointer()
		_stop_movement_input()
		audio.stop_steps()
	for region in [hud, detail_panel, controls]:
		for button in region.find_children("*", "Button", true, false):
			button.disabled = overlay_kind != "" or modal_open
			# Disabled buttons can still participate in Godot's Tab traversal.
			# Remember the original mode once, before removing background focus targets.
			if not button.has_meta("map_focus_mode"):
				button.set_meta("map_focus_mode", button.focus_mode)
			button.focus_mode = Control.FOCUS_NONE if button.disabled else int(button.get_meta("map_focus_mode"))
	recenter_button.disabled = blocked
	minimap.disabled = blocked
	minimap.focus_mode = Control.FOCUS_NONE if blocked else Control.FOCUS_ALL
	recenter_button.focus_mode = Control.FOCUS_NONE if blocked else Control.FOCUS_ALL
	_refresh_view_controls()
	_refresh_tutorial()

func _camp_section(id: String, title: String, summary: String) -> VBoxContainer:
	var card := _panel(body)
	card.get_parent().name = "Camp_" + id
	var content := VBoxContainer.new()
	content.name = "Content"
	content.visible = camp_sections.get(id, false)
	content.add_theme_constant_override("separation", 10)
	var heading := _button(card, title + ("  −" if content.visible else "  ＋"), func():
		content.visible = not content.visible
		camp_sections[id] = content.visible
	)
	heading.alignment = HORIZONTAL_ALIGNMENT_LEFT
	heading.add_theme_font_size_override("font_size", 19)
	heading.add_theme_color_override("font_color", GOLD)
	heading.tooltip_text = "展开或收起" + title
	content.visibility_changed.connect(func():
		heading.text = title + ("  −" if content.visible else "  ＋")
	)
	if not summary.is_empty():
		_text(card, summary, 14, MUTED)
	card.add_child(content)
	return content

func _show_title() -> void:
	_cancel_ui_drag()
	page = "title"
	notice = ""
	_render(true)

func _show_camp(view: String = "") -> void:
	_request_camp_entry(view, false)

func _request_new_game() -> void:
	_request_camp_entry("", true)

func _request_camp_entry(view: String, new_game: bool) -> void:
	if modal_open: return
	if _transaction_pending():
		notice = "有操作等待保存，请先重试。"
		_render(true)
		return
	_cancel_ui_drag()
	var enter := func():
		pending_camp_entry = {"view":view, "new_game":new_game}
		if game.active() and _is_campaign():
			var error: String = game.abandon_run()
			if not error.is_empty():
				if not _transaction_pending(): pending_camp_entry.clear()
				notice = error
				_render(true)
				return
		_complete_camp_entry()
	if game.active():
		_confirm("开始新游戏？" if new_game else "结束旅程并回营？",
			"当前旅程将结束，本局不获得灵魂。已有灵魂、火种和历史保留；再次入塔将开始新的旅程。", enter)
	else:
		enter.call()

func _complete_camp_entry() -> void:
	var view: String = pending_camp_entry.get("view", "")
	pending_camp_entry.clear()
	_cancel_ui_drag()
	page = "menu"
	camp_view = view
	camp_growth_level = 0
	notice = ""
	_render(true)

func _open_section(destination: String) -> void:
	_cancel_ui_drag()
	section_return_page = page
	page = destination
	notice = ""
	_render(true)

func _back_section() -> void:
	page = section_return_page
	_render(true)

func _menu() -> void:
	body.add_theme_constant_override("separation", 14)
	if camp_view.is_empty(): _text(body, "归途营地", 24, GOLD)
	if _transaction_pending() and camp_view.is_empty():
		_text(body, "有操作等待保存，请重试。",14,RED)
		_button(body,"重试保存",_retry_save,false,"PrimaryButton")
	elif _transaction_pending() and camp_view != "tower":
		_button(body,"重试保存",_retry_save,false,"PrimaryButton")
	if camp_view.is_empty():
		_fit_single_screen()
		camp_map = CampMap.new()
		body.add_child(camp_map)
		camp_map.setup(self,camp_position)
		camp_map.position_changed.connect(func(cell): camp_position = cell)
		camp_map.interaction_requested.connect(_camp_interact)
	else:
		camp_map = null
		_button(body,"‹ 返回营地",func():
			camp_view = ""
			notice = ""
			_render(true)
		)
	if camp_view == "knight": CampaignPanels.camp_knight(self)
	if camp_view == "growth": CampaignPanels.upgrades(self)
	if camp_view == "death" and game.has_method("start_phase3"):
		_fit_single_screen()
		var preparation := _panel(body,"SheetPanel")
		preparation.get_parent().size_flags_vertical = Control.SIZE_EXPAND_FILL
		preparation.get_parent().name = "CampDeathDialogue"
		CampaignPanels.phase3_departure(self,preparation)
	var departure := _panel(body)
	departure.get_parent().name = "Camp_departure"
	departure.get_parent().visible = camp_view == "tower"
	_text(departure, "魔塔入口 · 出发探索", 21, GOLD)
	if not game.state.is_empty() and game.active():
		_button(departure, "继续探索 · 第 %d 层" % int(game.state.floor), _open_map, false, "PrimaryButton")
	if _transaction_pending():
		_text(departure, "有操作等待保存。重试成功前不能开始新旅程。", 16, RED)
		_button(departure, "重试保存", _retry_save, false, "PrimaryButton")
	if game.has_method("start_phase3"):
		var definitions: Dictionary = CampaignPanels.P3Challenges.Progress.definitions().challenges
		_text(departure,"%s · %s" % [definitions.challenges.get(phase3_challenge,{}).get("name","标准旅程"),definitions.start_configs.get(phase3_config,{}).get("name","提灯旅人")],14,MUTED)
		var start := _button(departure, "营救王子 · 十层旅程", func(): _request_start(""), _transaction_pending(), "" if game.active() else "PrimaryButton")
		start.name = "CampStartJourney"
	if camp_view.is_empty():
		var shortcuts := GridContainer.new()
		shortcuts.columns = 2
		shortcuts.add_theme_constant_override("h_separation", 8)
		shortcuts.add_theme_constant_override("v_separation", 8)
		body.add_child(shortcuts)
		for entry in [["旅程记录", "records"], ["旅途图鉴", "codex"], ["游戏设置", "settings"]]:
			_button(shortcuts, entry[0], _open_section.bind(entry[1]), false, "QuietButton")

func _camp_interact(kind: String) -> void:
	if page != "menu" or modal_open or kind not in ["knight","death","tower"]: return
	if is_instance_valid(camp_map): camp_map.set_enabled(false)
	camp_view = kind
	notice = ""
	_render(true)

func _camp_purchase(kind: String) -> void:
	notice = game.purchase_upgrade(kind)
	if notice.is_empty(): notice = "神秘的老骑士：火种已点亮，下一次出发时生效。"
	_render(false)

func _open_map() -> void:
	if game.state.is_empty():
		_show_camp()
		return
	camp_view = ""
	page = "map"
	_render(true)
	board.set_overview(false)
	_layout_map()

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
			var stats: Dictionary = game.stats()
			_text(parent, Enemies.classification(enemy) + " · " + Enemies.map_role(entity), 14, GOLD)
			_text(parent, "敌方：生命 %d / 攻击 %d / 防御 %d" % [enemy.hp, enemy.attack, enemy.defense], 14, MUTED)
			_text(parent, "我方：生命 %d / %d · 攻击 %d / 防御 %d" % [game.state.player.hp, stats.max_hp, stats.attack, stats.defense], 14, MUTED)
			_text(parent, str(enemy.get("combat_hint", "")), 14, MUTED)
			if not str(enemy.get("ability_id", "")).is_empty():
				_text(parent, "机制：" + str(enemy.description), 14, MUTED)
			_text(parent, "你先攻击，敌人存活时反击。每击伤害为攻击减防御：你至少造成 1 点，敌人最低造成 0 点。", 13, MUTED)
			_text(parent, "击杀后恢复至多 %d HP，不超过生命上限。" % int(stats.kill_heal), 13, MUTED)
			_text(parent, "击杀奖励：%d 金币。" % (int(enemy.gold_reward) + int(game.stats().gold_bonus)), 14, GOLD)
			if _is_phase3():
				var report: Dictionary = game.preview(cell)
				if not report.get("ok", true):
					_text(parent, str(report.get("error", "战斗预览不可用")), 15, RED)
				else:
					_text(parent, "预计：" + ("可战胜" if report.won else "会战败"), 19, TEAL if report.won else RED)
					_text(parent, "总受伤 %d · 战后恢复 %d · 净损失 %d\n战中最低生命 %d → 战后生命 %d\n金币奖励 %d（含战斗机制）" % [report.incoming,report.healing,report.loss,report.min_hp,report.hp_after,report.gold_reward], 15)
					var details := _button(parent, "展开回合与遗物效果", func():
						var log := _text(parent, Phase3Player.report_text(report), 14, MUTED)
						log.name = "Phase3PreviewLog"
					)
					details.pressed.connect(func(): details.disabled = true)
					preview_evidence = {"cell":cell, "type":"enemy", "enemy_id":entity.enemy_id, "viewed_full":true}
					if equipment_comparison.get("changed", false) and equipment_comparison.get("enemy_id", "") == entity.enemy_id:
						var previous: Dictionary = equipment_comparison.report
						_text(parent, "成长前后 · %s\n受伤 %d → %d · 反击 %d → %d%s" % [enemy.name,previous.incoming,report.incoming,previous.counterattacks,report.counterattacks," · 本场反击次数不变" if previous.counterattacks == report.counterattacks else ""], 14, TEAL)
						_tutorial_event({"type":"comparison_viewed", "discovered":true,"same_enemy":true}, false)
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
			if entity.type == "rest":
				_text(parent, "围石间还留着前人的火种，铺盖已经叠好。添一把柴，在这里缓一口气，也为后来的人留一点光。", 14, MUTED)
			if _is_phase3() and entity.has("ruin_id"):
				_text(parent, "遗迹 · " + ("已选择，铭文可回看。" if entity.get("status", "") == "resolved" else "三项互斥，保存成功后生效；可免费离开。"), 15, TEAL)
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
			_text(parent, "商品已全部售罄。" if entity.purchased else "每件商品限购一件，可以购买多件。未购买的商品会保留，随时可以回来。", 15, MUTED)
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
	var pending: Dictionary = game.state.pending
	if _is_phase3() and pending.kind == "entity":
		var ruin := game.entity_at(game.pending_cell())
		if ruin.has("ruin_id"):
			_present_ruin(ruin)
			return
	if pending.kind == "entity":
		var entity: Dictionary = game.entity_at(game.pending_cell())
		if entity.get("type", "") in ["shop", "choice", "event", "rest"]:
			_present_reward_choices(entity)
			return
	var box := _panel(body)
	if pending.kind in ["stairs", "floor_choice"]:
		_text(box, "前往第 %d 层" % int(pending.get("destination", int(game.state.floor) + 1)), 22, GOLD)
		_text(box, "楼层布局、怪物、宝箱和商人状态都会保留。", 14, MUTED)
		_button(box, "通过楼梯", func(): _act(game.confirm_interaction), false, "PrimaryButton")
	else:
		var cell: Vector2i = game.pending_cell()
		var entity: Dictionary = game.entity_at(cell)
		_describe(box, cell, false)
		if _is_phase3() and entity.has("ruin_id"):
			_present_ruin(entity)
		elif entity.get("type", "") == "potion":
			_button(box, "使用药剂", func(): _act(game.confirm_interaction), int(game.state.player.hp) >= int(game.stats().max_hp), "PrimaryButton")
		elif entity.get("type", "") == "door":
			var key_kind := Keys.kind(entity)
			var enough := Keys.count(game.state.player, key_kind) >= int(entity.cost)
			_button(box, "消耗 %d 把%s开门" % [int(entity.cost), Keys.key_name(key_kind)] if enough else Keys.key_name(key_kind) + "不足", func(): _act(game.confirm_interaction), not enough, "PrimaryButton")
		else:
			var report: Dictionary = game.preview(cell) if _is_phase3() else {}
			_button(box, "仍要挑战" if _is_phase3() and report.get("lethal", false) else "确认挑战", _request_fight, not report.get("ok", true), "DangerButton" if report.get("lethal", false) else "PrimaryButton")

func _item_card(parent: Node, id: String, count: int = 1, concise: bool = false) -> void:
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
	var title := str(item.get("name", id)) if concise else "%s ×%d · %s %d阶" % [item.get("name", id), count, kind, int(item.get("tier", 1))]
	_text(copy, title, 15, GOLD)
	_text(copy, str(item.get("description", "")), 14, MUTED)

func _fight() -> void:
	if _transaction_pending() or not combat_context.is_empty():
		return
	var entity: Dictionary = game.entity_at(game.pending_cell())
	if entity.get("type", "") != "enemy" or game.state.pending.is_empty():
		return
	combat_context = {"enemy":game.db.enemy(entity.enemy_id).duplicate(true), "enemy_id":str(entity.enemy_id)}
	_complete_inspection(true)
	# The player chooses from the displayed facts; confirmation never reveals the outcome.
	notice = game.confirm_interaction(true)
	if not notice.is_empty() and not _transaction_pending():
		combat_context = {}
	_render(true)
	_present_combat()

func _present_combat() -> void:
	if combat_context.is_empty() or _transaction_pending() or is_instance_valid(combat_view):
		return
	if game.state.last_report.is_empty():
		combat_context = {}
		_render(true)
		return
	combat_context.report = game.state.last_report.duplicate(true)
	combat_context.final_hp = int(game.state.player.hp)
	combat_context.max_hp = int(game.stats().max_hp)
	combat_context.run_ended = not game.active()
	notice = ""
	if _is_phase3():
		combat_view = Phase3Player.new()
		var configured: Dictionary = combat_view.configure(combat_context.report, true, {"rank":combat_context.enemy.get("rank","normal"), "enemy_id":combat_context.enemy_id, "enemy_name":combat_context.enemy.get("name",""), "reduce_motion":settings.reduce_motion})
		if not configured.ok:
			notice = str(configured.error)
			combat_view.free()
			combat_view = null
			combat_context = {}
			_render(true)
			return
		combat_view.cue_presented.connect(func(cue):
			audio.play(get_tree(), Phase3Player.sound_for_cue(cue), settings)
		)
	else:
		combat_view = CombatPresentation.new()
		combat_view.configure(combat_context, settings.reduce_motion)
		combat_view.cue_requested.connect(func(cue: String): audio.play(get_tree(), cue, settings))
	combat_view.dismissed.connect(_finish_combat)
	map_root.add_child(combat_view)
	map_root.move_child(combat_view, save_error_panel.get_index())
	_layout_map()
	_set_map_input()
	_restore_focus.call_deferred(null)

func _finish_combat() -> void:
	if is_instance_valid(combat_view):
		map_root.remove_child(combat_view)
		combat_view.queue_free()
	combat_view = null
	combat_context = {}
	overlay_kind = ""
	selected = game.position()
	_render(true)
	if overlay_kind == "":
		_restore_focus.call_deferred(overview_button)

func _select_cell(cell: Vector2i) -> void:
	if _transaction_pending() or modal_open or overlay_kind != "" or not game.state.pending.is_empty():
		return
	_stop_movement_input()
	if board.moving:
		queued_cell = cell
		return
	selected = cell
	if not game.active():
		_open_overlay("target")
		return
	if cell == game.position():
		_act(func(): return game.interact(cell))
		return
	click_route = ClickPath.find(game, game.position(), cell)
	if click_route.is_empty():
		notice = "石墙挡住了去路。" if game.is_wall(cell) else "目标暂不可达，请先处理沿途的守卫、门或交互。"
		_render()
		return
	board.recenter()
	_continue_walk()

func _act(action: Callable) -> void:
	if _transaction_pending():
		_render()
		return
	walk_audio_enabled = true
	var previous_hp := int(game.state.player.hp)
	var previous_gold := int(game.state.player.gold)
	var pending_type := str(game.entity_at(game.pending_cell()).get("type", "")) if not game.state.pending.is_empty() else ""
	var previous_items: int = game.state.player.equipment_ids.size() + game.state.player.relic_ids.size()
	var previous_floor := int(game.state.floor)
	var previous_position: Vector2i = game.position()
	var previous_equipment: int = game.state.player.equipment_ids.size()
	var pending_entity: Dictionary = game.entity_at(game.pending_cell()).duplicate(true) if not game.state.pending.is_empty() else {}
	var result = action.call()
	if _is_phase3():
		tutorial_pending_evidence = {"position":previous_position, "equipment":previous_equipment, "entity":pending_entity}
		if not _transaction_pending(): _consume_tutorial_evidence()
	notice = str(result) if result is String else ""
	selected = game.pending_cell() if not game.state.pending.is_empty() else game.position()
	_render(previous_floor != int(game.state.floor) or not game.state.pending.is_empty())
	if _transaction_pending():
		return
	if _is_phase3() and not game.state.pending.is_empty(): _inspect_phase3(game.pending_cell())
	if int(game.state.player.hp) < previous_hp:
		audio.play(get_tree(), "hit", settings)
		_flash_board(Color("ed9395"))
	elif game.state.player.equipment_ids.size() + game.state.player.relic_ids.size() > previous_items or int(game.state.player.gold) > previous_gold or int(game.state.player.hp) > previous_hp:
		audio.play(get_tree(), "pickup", settings)
		_flash_board(Color("e0bf80"))
	elif pending_type == "door" and game.state.pending.is_empty():
		audio.play(get_tree(), "door", settings)

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
	# Smart wrapping also breaks long names/numbers without whitespace.
	dialog.get_label().autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
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
	_fit_confirmation(dialog)
	# Prefer the non-destructive action; the popup's own viewport traps keyboard focus.
	dialog.get_cancel_button().grab_focus()

func _fit_confirmation(dialog: ConfirmationDialog) -> void:
	dialog.popup_centered(Vector2i(mini(440, int(size.x) - 32), 220))

func _is_campaign() -> bool:
	return game.has_method("is_campaign") and game.is_campaign()

func _transaction_pending() -> bool:
	return game.has_method("retry_save") and bool(game.transaction_pending)

func _story_event() -> Dictionary:
	return game.story_event() if game.has_method("story_event") else {}

func _request_start(seed_text: String) -> void:
	var action := func():
		if game.active() and _is_campaign():
			var error: String = game.abandon_run()
			if not error.is_empty():
				notice = error
				_render(true)
				return
		_start_phase3(seed_text)
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
	chest_receipt.clear()
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
	if not _transaction_pending():
		_consume_tutorial_evidence()
		if not pending_camp_entry.is_empty():
			_complete_camp_entry()
			return
	_render(true)
	_present_combat()

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
		pins[key] = {"name": str(entity.get("name", "目标"))}
		if _is_phase3() and entity.get("enemy_id", "") == "knight": _tutorial_event({"type":"target_marked"}, false)
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

func _is_phase3() -> bool:
	return game.has_method("is_phase3") and game.is_phase3()

func _start_phase3(seed_text: String, replay: Dictionary = {}) -> void:
	if _transaction_pending(): return
	if not game.has_method("start_phase3"):
		notice = "第三阶段核心尚未接入。"
		_render(true)
		return
	var challenge := str(replay.get("challenge_id", phase3_challenge))
	var config := str(replay.get("start_config_snapshot", {}).get("id", phase3_config))
	var result: String = game.start_phase3(seed_text, challenge, config, replay)
	if not result.is_empty():
		notice = result
		_render(true)
		return
	viewed_entities.clear()
	equipment_comparison.clear()
	preview_evidence.clear()
	chest_receipt.clear()
	selected = Vector2i(-1,-1)
	notice = ""
	story_id = ""
	story_line = 0
	overlay_kind = ""
	_tutorial_event({"type":"floor_entered","floor":1,"new_run":true}, false)
	_open_map()

func _retry_journey() -> void:
	if _is_phase3(): _start_phase3(str(game.state.seed), game.state.duplicate(true))
	else: _start_campaign(str(game.state.seed))

func _request_fight() -> void:
	if _is_phase3():
		var report: Dictionary = game.preview(game.pending_cell())
		if not report.get("ok", true): return
		if report.get("lethal", false):
			_confirm("仍要挑战？", "预计战败，战中最低生命 %d；战后恢复不能避免死亡。" % int(report.min_hp), _fight)
			return
	_fight()

func _combat_escape() -> void:
	if not is_instance_valid(combat_view): return
	if _is_phase3():
		if combat_view._report_pages.visible:
			if not combat_view._report_pages.back_to_overview(): combat_view._set_report_visible(false)
			return
		if combat_view._finished: combat_view.close()
		else: combat_view.skip()
	else: combat_view.escape()


func _fit_single_screen() -> void:
	scroll.vertical_scroll_mode = ScrollContainer.SCROLL_MODE_DISABLED
	body.size_flags_vertical = Control.SIZE_EXPAND_FILL

func _mount_choices(panel: Control) -> void:
	_fit_single_screen()
	panel.embedded = true
	body.add_child(panel)

func _present_reward_choices(entity: Dictionary) -> void:
	var shop: bool = entity.get("type", "") == "shop"
	overlay_title.text = str(entity.get("name", "商店" if shop else "选择奖励"))
	var options: Array = []
	if shop:
		var merchant_row := HBoxContainer.new()
		merchant_row.add_theme_constant_override("separation", 12)
		body.add_child(merchant_row)
		var portrait = preload("res://scripts/ui/npc_portrait.gd").merchant(settings,get_viewport_rect().size.y < 640)
		merchant_row.add_child(portrait)
		var greeting := _text(merchant_row, "货都在这里，慢慢挑。\n每件限购一次，可购买多件。" if not entity.get("purchased", false) else "这趟带来的货都卖完了。", 14, MUTED)
		greeting.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		greeting.size_flags_vertical = Control.SIZE_SHRINK_CENTER
		for id in entity.offers: options.append(game.shop_offer(str(id)))
	else:
		options = game.reward_options(entity)
	var entries: Array = []
	for index in options.size():
		var option: Dictionary = options[index]
		var result: Dictionary = game.shop_preview(str(entity.offers[index])) if shop else Rewards.resolve(game.db, game.state.player, option)
		var sold: bool = shop and game.shop_offer_sold(entity, str(entity.offers[index]))
		var item: Dictionary = game.db.item(str(option.item_id)) if option.has("item_id") else {}
		var detail := str(item.get("description", option.get("description", "")))
		var bonus_gold := int(option.get("effects", {}).get("gold", 0)) if entity.get("type", "") == "choice" else 0
		if bonus_gold > 0: detail += "\n另获 %d 金币" % bonus_gold
		if shop: detail += "\n价格 · %d 金币" % int(option.price)
		if sold: detail += "\n\n已售罄，本局不能再次购买。"
		else: detail += "\n\n" + Rewards.summary(result).replace("领取后", "购买后" if shop else "领取后")
		var brief := "%d 金币 · 查看详情" % int(option.price) if shop else str(item.get("description", option.get("description", "查看收益")))
		if bonus_gold > 0: brief = "另获 %d 金币 · 查看详情" % bonus_gold
		if sold: brief = "已售罄 · 可查看详情"
		elif not result.ok: brief = "暂不可用 · 查看原因"
		var action := ("购买 · " if shop else "选择 · ") + str(option.name)
		if shop: action += " · %d 金币" % int(option.price)
		entries.append({"id":str(index), "name":option.name, "item":item, "icon":ActionIcon.for_reward(option), "brief":brief,
			"detail":detail, "disabled":sold or not result.ok, "action":"已售罄" if sold else action})
		if shop:
			entries[-1].price = int(option.price)
			entries[-1].availability = "已售罄" if sold else "查看原因" if not result.ok else "可选购"
	var panel := ActionChoices.new()
	panel.name = "RewardChoices"
	_mount_choices(panel)
	# Keep the merchant header from feeding the previous expanded body height
	# back into the sheet minimum when the window becomes shorter.
	if shop: scroll.vertical_scroll_mode = ScrollContainer.SCROLL_MODE_SHOW_NEVER
	var hint := "持有金币 · %d" % int(game.state.player.gold) if shop else "选择一项 · 点击图标查看详情"
	panel.present_choices(entries, "", hint)
	panel.option_selected.connect(func(id):
		if modal_open or _transaction_pending(): return
		if shop: _act(func(): return game.buy(int(id)))
		else: _act(func(): return game.choose_reward(int(id)))
	)

func _present_ruin(entity: Dictionary) -> void:
	var previews: Dictionary = game.ruin_previews(entity)
	if not previews.get("ok", false):
		_text(body, str(previews.get("error", "遗迹预览不可用")), 15, RED)
		return
	var definition: Dictionary = game.state.get("ruin_definitions_snapshot", {}).get(str(entity.ruin_id), {})
	definition = RelicTrail.presentation(game.state, definition, entity)
	overlay_title.text = str(definition.get("name", "遗迹"))
	var panel := RuinPanel.new()
	panel.name = "Phase3Ruin"
	_mount_choices(panel)
	panel.present(definition, previews.options, entity)
	# The standalone panel emits selection; the host owns confirmation and commit.
	panel.option_selected.connect(func(id):
		if modal_open or _transaction_pending(): return
		var option_name := str(id)
		for option in definition.get("options", []):
			if option.id == id: option_name = str(option.name)
		var result: Dictionary = previews.options.get(id, {})
		_confirm("确认" + option_name + "？", "三项只能选择一项。\n" + Rewards.summary(result), func():
			_act(func(): return game.choose_ruin(id))
		)
	)
	panel.leave_requested.connect(func():
		if modal_open or _transaction_pending(): return
		_act(func(): return game.choose_ruin("leave"))
		_tutorial_event({"type":"ruin_left","ruin_id":entity.ruin_id})
	)

func _tutorial_context() -> Dictionary:
	return {"save_error":_transaction_pending() or not game.save_error.is_empty(), "lethal_confirmation":modal_open,
		"combat_modal":is_instance_valid(combat_view), "reward_modal":overlay_kind in ["pending","target","inventory","floors","log","settings","save_blocked","chest_reward"],
		"story":overlay_kind == "story", "story_queued":not _story_event().is_empty(),
		"comparison_available":not equipment_comparison.is_empty(), "trial":not _is_campaign(),
		"full_hp":not game.state.is_empty() and int(game.state.player.hp) >= int(game.stats().max_hp)}

func _tutorial_event(event: Dictionary, refresh: bool = true) -> void:
	# Old saved runs retain their prior UI behavior; explicit settings remain available.
	if not _is_phase3() and not str(event.get("type", "")) in ["reset","skip_all","camp_embers_viewed","result_hint_closed"]: return
	var next := Tutorial.reduce(settings.tutorial, event, _tutorial_context())
	if not next.ok: return
	if next.state != settings.tutorial:
		settings.tutorial = next.state
		_save_preferences()
	if refresh: _refresh_tutorial()

func _refresh_tutorial() -> void:
	if not is_instance_valid(tutorial_view): return
	if page != "map" or not _is_phase3():
		tutorial_view.set_prompt({})
		return
	var next := Tutorial.reduce(settings.tutorial, {}, _tutorial_context())
	if not next.ok: return
	settings.tutorial = next.state
	tutorial_view.set_prompt(next.prompt)
	if not next.prompt.is_empty():
		tutorial_view.position = board.position + Vector2(10, 96 if detail_panel.visible else 34)
		tutorial_view.size = Vector2(board.size.x - 20, 0)

func _consume_tutorial_evidence() -> void:
	if tutorial_pending_evidence.is_empty() or not _is_phase3() or _transaction_pending(): return
	var before := tutorial_pending_evidence.duplicate(true)
	tutorial_pending_evidence.clear()
	if before.position != game.position(): _tutorial_event({"type":"move_succeeded","committed":true}, false)
	if int(before.equipment) < game.state.player.equipment_ids.size():
		equipment_comparison["changed"] = true
		_tutorial_event({"type":"equipment_received","committed":true}, false)
	var entity: Dictionary = before.entity
	if game.state.pending.is_empty():
		if not entity.is_empty() and entity.has("pos"):
			var current: Dictionary = game.floor_data().entities.get(Core.cell_key(Vector2i(entity.pos[0],entity.pos[1])),{})
			if current.is_empty() or (current.get("status","") == "resolved" and entity.get("status","") != "resolved"):
				board.play_interaction()
		match str(entity.get("type", "")):
			"door": _tutorial_event({"type":"door_opened","committed":true}, false)
			"potion": _tutorial_event({"type":"potion_used","committed":true}, false)
			"event":
				if entity.has("ruin_id"):
					var now: Dictionary = game.floor_data().entities.get(Core.cell_key(Vector2i(entity.pos[0],entity.pos[1])), {})
					if now.get("status", "") == "resolved":
						_tutorial_event({"type":"ruin_claimed","ruin_id":entity.ruin_id,"committed":true}, false)
						audio.play(get_tree(),{"p3_oath_ruin":"door","p3_oath_forge":"hit","p3_lantern_sanctuary":"pickup"}.get(entity.ruin_id,"pickup"),settings)

func _inspect_phase3(cell: Vector2i) -> void:
	if not _is_phase3() or _transaction_pending(): return
	var entity: Dictionary = game.entity_at(cell)
	if entity.is_empty(): return
	var kind := str(entity.get("type", ""))
	var observed := "%s:f%d:%s" % [_pin_run_key(),int(game.state.floor),Core.cell_key(cell)]
	var events: Array = []
	if kind == "enemy":
		var report: Dictionary = game.preview(cell)
		_tutorial_event({"type":"enemy_viewed","enemy_id":entity.enemy_id,"floor":game.state.floor,"lethal":report.get("lethal",false)}, false)
		if not equipment_comparison.get("changed", false): equipment_comparison = {"enemy_id":entity.enemy_id,"report":report.duplicate(true),"changed":false}
		events.append({"event_id":observed+":enemy_seen", "kind":"enemy_seen", "id":entity.enemy_id})
	elif kind == "door":
		_tutorial_event({"type":"door_viewed"}, false)
		preview_evidence = {"type":"door"}
	elif kind == "potion":
		_tutorial_event({"type":"potion_viewed"}, false)
		preview_evidence = {"type":"potion"}
	elif entity.has("ruin_id"):
		_tutorial_event({"type":"ruin_viewed","ruin_id":entity.ruin_id}, false)
		preview_evidence = {"type":"ruin","ruin_id":entity.ruin_id}
		events.append({"event_id":observed+":ruin_seen","kind":"ruin_seen","id":entity.ruin_id})
	var items: Array = []
	if entity.has("item_id"): items.append(str(entity.item_id))
	if kind == "choice":
		for option in game.reward_options(entity):
			if option.has("item_id"): items.append(str(option.item_id))
	if kind == "shop":
		for id in entity.get("offers", []):
			var offer: Dictionary = game.shop_offer(str(id))
			if offer.has("item_id"): items.append(str(offer.item_id))
	for id in items: events.append({"event_id":observed+":item_seen:"+id,"kind":"item_seen","id":id})
	if not events.is_empty() and not viewed_entities.has(observed):
		var error: String = game.record_phase3_discoveries(events)
		if error.is_empty(): viewed_entities[observed] = true
		else:
			notice = error
			_render(true)
	_refresh_tutorial()

func _complete_inspection(confirmed: bool = false) -> void:
	match str(preview_evidence.get("type", "")):
		"enemy":
			_tutorial_event({"type":"enemy_preview_confirmed" if confirmed else "enemy_preview_closed","viewed_full":preview_evidence.get("viewed_full",false)}, false)
			if preview_evidence.get("enemy_id", "") == "knight" and not confirmed: _tutorial_event({"type":"target_mark_declined"}, false)
		"door": _tutorial_event({"type":"door_explanation_closed"}, false)
		"potion": _tutorial_event({"type":"potion_retained"}, false)
		"ruin": _tutorial_event({"type":"ruin_left","ruin_id":preview_evidence.ruin_id}, false)
	preview_evidence.clear()
