extends Control
## Illustrated entry screen with separate new-game and resume actions.
const Art = preload("res://scripts/ui/runtime_art.gd")
const Surface = preload("res://scripts/ui/ui_polish_surface.gd")
const BACKGROUND := "res://assets/ui/main_menu/title_trio_v01.png"
var heading: VBoxContainer
var menu: ScrollContainer
var host
var action_back: Panel

func setup(ui) -> void:
	host = ui
	name = "MainMenu"
	var background := TextureRect.new()
	background.name = "TitleIllustration"
	background.texture = Art.texture(BACKGROUND)
	background.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	background.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
	background.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(background)
	background.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	var gradient := Gradient.new()
	gradient.offsets = PackedFloat32Array([0, 0.18, 0.48, 0.72, 1])
	gradient.colors = PackedColorArray([Color(0.02,0.04,0.06,0.7), Color(0.02,0.04,0.06,0), Color(0.02,0.04,0.06,0.05), Color(0.02,0.04,0.06,0.88), Color(0.02,0.04,0.06,0.98)])
	var texture := GradientTexture2D.new()
	texture.gradient = gradient
	texture.fill_from = Vector2(0,0)
	texture.fill_to = Vector2(0,1)
	var shade := TextureRect.new()
	shade.texture = texture
	shade.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(shade)
	shade.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	heading = VBoxContainer.new()
	heading.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(heading)
	heading.add_theme_constant_override("separation", 0)
	var title = ui._text(heading, "塔 境", 46, ui.GOLD)
	title.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	var subtitle = ui._text(heading, "公 主 救 援 记", 16, Color("e1e8df"))
	subtitle.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	action_back = Panel.new()
	action_back.mouse_filter = Control.MOUSE_FILTER_IGNORE
	var backing := StyleBoxFlat.new()
	backing.bg_color = Color.TRANSPARENT
	action_back.add_theme_stylebox_override("panel", backing)
	add_child(action_back)
	Surface.attach(action_back, "menu")
	menu = ScrollContainer.new()
	menu.name = "MainMenuActions"
	menu.horizontal_scroll_mode = ScrollContainer.SCROLL_MODE_DISABLED
	add_child(menu)
	var actions := VBoxContainer.new()
	actions.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	actions.add_theme_constant_override("separation", 8)
	menu.add_child(actions)
	ui.scroll = menu
	ui.body = actions
	var ready: bool = ui.game.errors.is_empty()
	var resume: bool = ready and ui.game.active()
	var status = ui._text(actions, "第 %d 层 · 旅程等待继续" % int(ui.game.state.floor) if resume else "循着归途灯，走向魔塔深处", 13, ui.MUTED)
	status.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	var start = ui._button(actions, "开始新游戏", ui._request_new_game, not ready or ui._transaction_pending(), "PrimaryButton")
	start.name = "StartGame"
	start.custom_minimum_size.y = 58
	start.add_theme_font_size_override("font_size", 20)
	var utility := HBoxContainer.new()
	actions.add_child(utility)
	var continued = ui._button(utility, "继续游戏", ui._open_map, not resume)
	continued.name = "ContinueGame"
	continued.tooltip_text = "恢复当前旅程" if resume else "暂无进行中的旅程"
	var settings = ui._button(utility, "游戏设置", ui._open_section.bind("settings"), false, "QuietButton")
	settings.name = "GameSettings"
	for button in [continued, settings]:
		button.custom_minimum_size.y = 48
	var divider := HSeparator.new()
	actions.add_child(divider)
	var links := GridContainer.new()
	links.columns = 2
	links.add_theme_constant_override("h_separation", 8)
	links.add_theme_constant_override("v_separation", 6)
	actions.add_child(links)
	for entry in [["旅程记录", "records"], ["旅途图鉴", "codex"]]:
		var link = ui._button(links, entry[0], ui._open_section.bind(entry[1]), not ready, "QuietButton")
		link.custom_minimum_size.y = 44
		link.add_theme_font_size_override("font_size", 14)
	if not ready: ui._text(actions, "\n".join(ui.game.errors), 14, ui.RED)
	if not ui.game.save_error.is_empty() or ui._transaction_pending():
		ui._text(actions, ui.game.save_error if not ui.game.save_error.is_empty() else "有操作等待保存，请先重试。", 14, ui.RED)
		ui._button(actions, "重试保存", ui._retry_save)
	var footer = ui._text(actions, "自动保存 · 每一次归来，都是新的起点", 12, ui.MUTED)
	footer.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	menu.get_child(0).minimum_size_changed.connect(func(): _layout.call_deferred())
	resized.connect(_layout)
	_layout()
	ui._restore_focus.call_deferred(continued if resume else start)

func _layout() -> void:
	if not is_instance_valid(menu): return
	var width := minf(380, size.x - 48)
	heading.position = Vector2((size.x - width) * 0.5, maxf(16, size.y * 0.035))
	heading.size = Vector2(width, 92)
	var height := minf(size.y - 140, maxf(300, menu.get_child(0).get_combined_minimum_size().y))
	menu.position = Vector2((size.x - width) * 0.5, size.y - height - 16)
	menu.size = Vector2(width, height)
	action_back.position = Vector2(0, menu.position.y - 18)
	action_back.size = Vector2(size.x, menu.size.y + 34)
