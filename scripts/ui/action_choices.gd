extends PanelContainer
## Read-only overview and paged detail; only the explicit action emits a choice.
signal option_selected(option_id: String)
signal leave_requested
const ActionIcon = preload("res://scripts/ui/action_icon.gd")
const ItemIcon = preload("res://scripts/ui/item_icon.gd")
const Art = preload("res://scripts/ui/runtime_art.gd")
const Surface = preload("res://scripts/ui/ui_polish_surface.gd")
var _layout: VBoxContainer
var _content: VBoxContainer
var _leave: Button
var _buttons: Dictionary = {}
var _entries: Array = []
var _intro := ""
var _hint := ""
var _selected := ""
var _list_page := 0
var _text_page := 0
var _pages: Array[String] = []
var _detail: Label
var _pager: HBoxContainer
var _page_label: Label
var _previous: Button
var _next: Button
var _full_text := ""
var _action: Button
var embedded := false
var intro_title := "背景与规则"
var intro_button_text := "查看背景与规则  ›"

func _ready() -> void:
	_ensure_ui()

func present_choices(entries: Array, intro: String, hint: String) -> void:
	_ensure_ui()
	_entries = entries.duplicate(true)
	_intro = intro
	_hint = hint
	_list_page = 0
	show_overview()

func _ensure_ui() -> void:
	if _layout != null: return
	# Actual children determine the required height; leave enough space for the
	# merchant introduction above this shared panel on the smallest viewport.
	custom_minimum_size = Vector2(0, 264)
	size_flags_vertical = Control.SIZE_EXPAND_FILL
	size_flags_horizontal = Control.SIZE_EXPAND_FILL
	add_theme_stylebox_override("panel", StyleBoxEmpty.new())
	_layout = VBoxContainer.new()
	_layout.add_theme_constant_override("separation", 8)
	add_child(_layout)
	_content = VBoxContainer.new()
	_content.size_flags_vertical = Control.SIZE_EXPAND_FILL
	_content.add_theme_constant_override("separation", 8)
	_layout.add_child(_content)
	_leave = _button(_layout, "暂时离开 · 不消耗", func(): leave_requested.emit())
	_leave.visible = not embedded

func _clear() -> void:
	_detail = null
	_action = null
	_buttons.clear()
	for child in _content.get_children():
		_content.remove_child(child)
		child.queue_free()

func show_overview() -> void:
	var previous_selection := _selected
	_clear()
	_selected = ""
	_label(_content, _hint, 14, Color("8fcbbd"))
	if not _intro.is_empty():
		_button(_content, intro_button_text, func(): _show_detail("__intro"))
	for index in range(_list_page * 3, mini(_entries.size(), (_list_page + 1) * 3)):
		var entry: Dictionary = _entries[index]
		var id := str(entry.id)
		var button := _button(_content, "", func(): _show_detail(id))
		button.name = "Option_" + id
		var large_offer := entry.has("price") and get_viewport_rect().size.y >= 640
		button.custom_minimum_size.y = 80 if large_offer else 68
		button.theme_type_variation = "OfferButton"
		Surface.attach(button, "offer")
		button.tooltip_text = str(entry.name) + " · 查看详情"
		var row := HBoxContainer.new()
		button.add_child(row)
		row.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
		row.offset_left = 10
		row.offset_right = -10
		row.offset_top = 6
		row.offset_bottom = -6
		row.mouse_filter = Control.MOUSE_FILTER_IGNORE
		row.add_theme_constant_override("separation", 10)
		var icon: Control
		if entry.get("item", {}).is_empty():
			icon = ActionIcon.new()
			icon.kind = str(entry.get("icon", "relic"))
		else:
			icon = ItemIcon.new()
			icon.item = entry.item
		icon.custom_minimum_size = Vector2(52, 52) if large_offer else Vector2(42, 42)
		icon.size_flags_vertical = Control.SIZE_SHRINK_CENTER
		icon.mouse_filter = Control.MOUSE_FILTER_IGNORE
		row.add_child(icon)
		var copy := VBoxContainer.new()
		copy.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		copy.size_flags_vertical = Control.SIZE_SHRINK_CENTER
		copy.mouse_filter = Control.MOUSE_FILTER_IGNORE
		row.add_child(copy)
		var title := _label(copy, str(entry.name), 17)
		title.autowrap_mode = TextServer.AUTOWRAP_OFF
		title.text_overrun_behavior = TextServer.OVERRUN_TRIM_ELLIPSIS
		var summary := _label(copy, str(entry.get("brief", "查看详情")), 13, Color("a8bcbf"))
		if entry.has("price"):
			summary.text = "%d 金币  ·  %s" % [int(entry.price), str(entry.get("availability", "可选购"))]
			summary.add_theme_color_override("font_color", Color("a8bcbf") if entry.get("disabled", false) else Color("e0c48b"))
		summary.autowrap_mode = TextServer.AUTOWRAP_OFF
		summary.text_overrun_behavior = TextServer.OVERRUN_TRIM_ELLIPSIS
		var chevron := _label(row, "›", 22, Color("e4c783"))
		chevron.size_flags_horizontal = Control.SIZE_SHRINK_END
		chevron.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
		_buttons[id] = button
	var shelf := Control.new()
	shelf.size_flags_vertical = Control.SIZE_EXPAND_FILL
	_content.add_child(shelf)
	Surface.attach(shelf, "footer")
	if _entries.size() > 3:
		var row := HBoxContainer.new()
		_content.add_child(row)
		_button(row, "上一页", func(): _list_page -= 1; show_overview()).disabled = _list_page == 0
		_label(row, "%d / %d" % [_list_page + 1, ceili(_entries.size() / 3.0)], 14)
		_button(row, "下一页", func(): _list_page += 1; show_overview()).disabled = (_list_page + 1) * 3 >= _entries.size()
	if _buttons.has(previous_selection): _focus.call_deferred(_buttons[previous_selection])

func _show_detail(id: String) -> void:
	_clear()
	_selected = id
	_text_page = 0
	var entry: Dictionary = {}
	for candidate in _entries:
		if str(candidate.id) == id: entry = candidate
	var heading := HBoxContainer.new()
	heading.add_theme_constant_override("separation", 10)
	_content.add_child(heading)
	if not entry.get("item", {}).is_empty():
		var icon := ItemIcon.new()
		icon.name = "DetailItemIcon"
		icon.item = entry.item
		icon.custom_minimum_size = Vector2(48, 48)
		icon.size_flags_vertical = Control.SIZE_SHRINK_CENTER
		icon.mouse_filter = Control.MOUSE_FILTER_IGNORE
		heading.add_child(icon)
	var title := _label(heading, intro_title if id == "__intro" else str(entry.get("name", "详情")), 20, Color("e4c783"))
	title.size_flags_vertical = Control.SIZE_SHRINK_CENTER
	if entry.get("item", {}).is_empty() and (entry.get("preview_texture") is Texture2D or not str(entry.get("image", "")).is_empty()):
		var picture := TextureRect.new()
		picture.name = "DetailPicture"
		picture.texture = entry.preview_texture if entry.get("preview_texture") is Texture2D else Art.texture(str(entry.image))
		picture.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
		picture.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
		picture.custom_minimum_size.y = 80
		_content.add_child(picture)
	_full_text = _intro if id == "__intro" else str(entry.get("detail", ""))
	var area := Control.new()
	# Item headings include a 48px icon; preserve room for shop/footer controls
	# on 320x600 displays and let the existing paginator retain all copy.
	area.custom_minimum_size.y = 48 if not entry.get("item", {}).is_empty() else 80
	area.size_flags_vertical = Control.SIZE_EXPAND_FILL
	_content.add_child(area)
	_detail = Label.new()
	_detail.name = "ChoiceDetailText"
	_detail.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	_detail.add_theme_font_size_override("font_size", 16)
	area.add_child(_detail)
	_detail.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	area.resized.connect(_paginate)
	_pager = HBoxContainer.new()
	_content.add_child(_pager)
	_previous = _button(_pager, "上一页", func(): _text_page -= 1; _update_page())
	_page_label = _label(_pager, "", 13)
	_next = _button(_pager, "下一页", func(): _text_page += 1; _update_page())
	if id != "__intro" and not entry.get("readonly", false):
		_action = _button(_content, str(entry.get("action", "确认选择")), func():
			if not _action.disabled: option_selected.emit(id)
		)
		_action.name = "ConfirmChoice"
		_action.theme_type_variation = "PrimaryButton"
		_action.disabled = bool(entry.get("disabled", false))
	var back := _button(_content, "‹  返回全部选项", show_overview)
	back.theme_type_variation = "QuietButton"
	_focus.call_deferred(back)
	_paginate.call_deferred()

func _paginate() -> void:
	if not is_instance_valid(_detail): return
	var width := maxf(40, _detail.size.x - 4)
	var font := _detail.get_theme_font("font")
	var font_size := _detail.get_theme_font_size("font_size")
	var height := maxf(24, _detail.get_parent().size.y - font.get_height(font_size) - 4)
	_pages.clear()
	var remaining := _full_text
	while not remaining.is_empty():
		var low := 1
		var high := remaining.length()
		while low < high:
			var count := ceili((low + high) / 2.0)
			var measured := font.get_multiline_string_size(remaining.left(count), HORIZONTAL_ALIGNMENT_LEFT, width, font_size)
			if measured.y <= height: low = count
			else: high = count - 1
		_pages.append(remaining.left(low))
		remaining = remaining.substr(low)
	if _pages.is_empty(): _pages.append("")
	_text_page = mini(_text_page, _pages.size() - 1)
	_update_page()

func _update_page() -> void:
	_detail.text = _pages[_text_page]
	_previous.disabled = _text_page == 0
	_next.disabled = _text_page == _pages.size() - 1
	_page_label.text = "%d / %d" % [_text_page + 1, _pages.size()]
	# Keep its height stable so text pagination cannot oscillate on resize.
	_pager.modulate.a = 1.0 if _pages.size() > 1 else 0.0
	_previous.focus_mode = Control.FOCUS_ALL if _pages.size() > 1 else Control.FOCUS_NONE
	_next.focus_mode = Control.FOCUS_ALL if _pages.size() > 1 else Control.FOCUS_NONE

func back_to_overview() -> bool:
	if _selected.is_empty(): return false
	show_overview()
	return true

func _focus(control: Control) -> void:
	if is_instance_valid(control) and control.is_inside_tree() and control.is_visible_in_tree():
		control.grab_focus()

func option_button(id: String) -> Button:
	return _buttons.get(id)

func leave_button() -> Button:
	return _leave

func _button(parent: Node, value: String, action: Callable) -> Button:
	var button := Button.new()
	button.text = value
	button.custom_minimum_size.y = 44
	button.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	button.add_theme_font_size_override("font_size", 16)
	parent.add_child(button)
	button.pressed.connect(action)
	return button

func _label(parent: Node, value: String, font_size: int, color := Color("e5e9e8")) -> Label:
	var label := Label.new()
	label.text = value
	label.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	label.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	label.mouse_filter = Control.MOUSE_FILTER_IGNORE
	label.add_theme_font_size_override("font_size", font_size)
	label.add_theme_color_override("font_color", color)
	parent.add_child(label)
	return label
