extends "res://scripts/ui/action_choices.gd"
## Bounded icon grid, category selection and lossless paged detail.
var categories: Array = []
var category_index := 0
var page_size := 4
var on_back := Callable()
var back_label := "‹  返回列表"
var empty_title := "此页尚待书写"

func page_capacity() -> int:
	return 6 if page_size == 4 and get_viewport_rect().size.y >= 850 else page_size

func _show_detail(id: String) -> void:
	super._show_detail(id)
	(_content.get_child(_content.get_child_count()-1) as Button).text = back_label

func present_categories(values: Array, hint: String = "") -> void:
	categories = values.duplicate(true)
	category_index = clampi(category_index, 0, maxi(0, categories.size() - 1))
	var entries: Array = categories[category_index].entries if not categories.is_empty() else []
	present_choices(entries, "", hint)

func show_overview() -> void:
	if not _selected.is_empty() and on_back.is_valid():
		on_back.call()
		return
	var previous := _selected
	_clear()
	_selected = ""
	var capacity := page_capacity()
	_list_page = mini(_list_page, maxi(0, ceili(_entries.size() / float(capacity)) - 1))
	if not _hint.is_empty():
		var hint := _label(_content, _hint, 14, Color("8fcbbd"))
		hint.max_lines_visible = 2
		hint.text_overrun_behavior = TextServer.OVERRUN_TRIM_ELLIPSIS
	if categories.size() > 1:
		var tabs := OptionButton.new()
		tabs.name = "CatalogCategory"
		# The mobile adapter sends mouse and touch for one gesture. Open only
		# on release so the following touch-down cannot dismiss the popup.
		tabs.action_mode = BaseButton.ACTION_MODE_BUTTON_RELEASE
		tabs.custom_minimum_size.y = 44
		tabs.fit_to_longest_item = false
		tabs.clip_text = true
		tabs.get_popup().add_theme_font_size_override("font_size", 16)
		tabs.get_popup().add_theme_constant_override("v_separation", 12)
		for category in categories: tabs.add_item("%s  ·  %d" % [category.name, category.entries.size()])
		tabs.select(category_index)
		_content.add_child(tabs)
		tabs.item_selected.connect(func(index):
			category_index = index
			_entries = categories[index].entries.duplicate(true)
			_list_page = 0
			show_overview()
		)
	var grid := GridContainer.new()
	grid.name = "CatalogGrid"
	grid.columns = 2
	grid.add_theme_constant_override("h_separation", 8)
	grid.add_theme_constant_override("v_separation", 8)
	_content.add_child(grid)
	for index in range(_list_page * capacity, mini(_entries.size(), (_list_page + 1) * capacity)):
		var entry: Dictionary = _entries[index]
		var id := str(entry.id)
		var button := _button(grid, "", func():
			if entry.get("navigate", false): option_selected.emit(id)
			else: _show_detail(id)
		)
		button.name = "Catalog_" + id
		button.theme_type_variation = "CatalogButton"
		var roomy := get_viewport_rect().size.y >= 640
		var tall := get_viewport_rect().size.y >= 850
		button.custom_minimum_size.y = (140 if tall else 116 if roomy else 100) if not str(entry.get("brief", "")).is_empty() else (124 if tall else 100 if roomy else 84)
		button.tooltip_text = str(entry.name)
		Surface.attach(button, "tall_card" if tall else "card" if roomy else "compact_card")
		var stack := VBoxContainer.new()
		stack.add_theme_constant_override("separation", 4)
		button.add_child(stack)
		stack.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
		stack.offset_left = 10
		stack.offset_right = -10
		stack.offset_top = 7
		stack.offset_bottom = -5
		stack.mouse_filter = Control.MOUSE_FILTER_IGNORE
		var icon: Control
		if entry.get("preview_texture") is Texture2D or not str(entry.get("thumbnail", "")).is_empty():
			icon = TextureRect.new()
			icon.texture = entry.preview_texture if entry.get("preview_texture") is Texture2D else Art.texture(str(entry.thumbnail))
			icon.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
			icon.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
		elif not entry.get("item", {}).is_empty():
			icon = ItemIcon.new()
			icon.item = entry.item
		else:
			icon = ActionIcon.new()
			icon.kind = str(entry.get("icon", "book"))
		icon.custom_minimum_size = Vector2(72, 72) if tall else Vector2(48, 48) if roomy else Vector2(32, 32)
		icon.size_flags_horizontal = Control.SIZE_SHRINK_CENTER
		icon.mouse_filter = Control.MOUSE_FILTER_IGNORE
		stack.add_child(icon)
		var gap := Control.new()
		gap.custom_minimum_size.y = 2
		gap.mouse_filter = Control.MOUSE_FILTER_IGNORE
		stack.add_child(gap)
		var caption := _label(stack, str(entry.name), 14)
		caption.autowrap_mode = TextServer.AUTOWRAP_OFF
		caption.text_overrun_behavior = TextServer.OVERRUN_TRIM_ELLIPSIS
		caption.horizontal_alignment = HORIZONTAL_ALIGNMENT_LEFT
		if not str(entry.get("brief", "")).is_empty():
			var brief := _label(stack, str(entry.brief), 12, Color("b7c6ca"))
			brief.autowrap_mode = TextServer.AUTOWRAP_OFF
			brief.text_overrun_behavior = TextServer.OVERRUN_TRIM_ELLIPSIS
			brief.horizontal_alignment = HORIZONTAL_ALIGNMENT_LEFT
		_buttons[id] = button
	if _entries.is_empty():
		var emblem := Control.new()
		emblem.custom_minimum_size.y = 110
		_content.add_child(emblem)
		Surface.attach(emblem, "empty")
		var empty := _label(_content, empty_title, 18, Color("d6c49e"))
		empty.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
		var copy := _label(_content, "尚无条目，探索后会在这里留下记录。", 14, Color("9aafb2"))
		copy.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	var spacer := Control.new()
	spacer.size_flags_vertical = Control.SIZE_EXPAND_FILL
	_content.add_child(spacer)
	Surface.attach(spacer, "footer")
	if _entries.size() > capacity:
		var navigation := HBoxContainer.new()
		_content.add_child(navigation)
		_button(navigation, "上一页", func(): _list_page -= 1; show_overview()).disabled = _list_page == 0
		_label(navigation, "%d / %d" % [_list_page + 1, ceili(_entries.size() / float(capacity))], 14)
		_button(navigation, "下一页", func(): _list_page += 1; show_overview()).disabled = (_list_page + 1) * capacity >= _entries.size()
	if _buttons.has(previous): _focus.call_deferred(_buttons[previous])
