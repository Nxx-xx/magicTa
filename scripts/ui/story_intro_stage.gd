extends Control
## Opening-location presentation; existing host controls retain input/save behavior.
const Art = preload("res://scripts/ui/runtime_art.gd")
const StoryExpressionArt = preload("res://scripts/ui/story_expression_art.gd")
const BACKGROUND := "res://assets/story/intro/tower_entrance_v01.png"
var host
var active := false
var portrait: TextureRect
var chapter: Label
var heading: Label
var counter: Label
var footer: HBoxContainer
var sheet: VBoxContainer
var separator: Control
var next_parent: Node
var close_parent: Node
var next_index: int
var close_index: int
var next_minimum: Vector2

func setup(ui) -> void:
	host = ui
	name = "StoryIntroStage"
	mouse_filter = Control.MOUSE_FILTER_IGNORE
	clip_contents = true
	host.overlay.add_child(self)
	host.overlay.move_child(self, 1)
	set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	var background := TextureRect.new()
	background.name = "TowerEntranceBackground"
	background.texture = Art.texture(BACKGROUND)
	background.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	background.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_COVERED
	background.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(background)
	background.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	portrait = TextureRect.new()
	portrait.name = "StoryPortrait"
	portrait.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	portrait.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
	portrait.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(portrait)
	var gradient := Gradient.new()
	gradient.offsets = PackedFloat32Array([0, 0.18, 0.62, 1])
	gradient.colors = PackedColorArray([Color(0.02,0.04,0.06,0.72), Color(0.02,0.04,0.06,0), Color(0.02,0.04,0.06,0), Color(0.02,0.04,0.06,0.65)])
	var texture := GradientTexture2D.new()
	texture.gradient = gradient
	texture.fill_from = Vector2.ZERO
	texture.fill_to = Vector2(0,1)
	var shade := TextureRect.new()
	shade.texture = texture
	shade.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(shade)
	shade.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	chapter = host._text(self, "序章", 18, host.GOLD)
	heading = host._text(self, "", 24, Color("f0e7d1"))
	sheet = host.overlay_title.get_parent()
	separator = sheet.get_child(1)
	next_parent = host.overlay_next.get_parent()
	close_parent = host.overlay_close.get_parent()
	next_index = host.overlay_next.get_index()
	close_index = host.overlay_close.get_index()
	next_minimum = host.overlay_next.custom_minimum_size
	footer = HBoxContainer.new()
	footer.name = "StoryFooter"
	sheet.add_child(footer)
	counter = host._text(footer, "", 14, host.MUTED)
	counter.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	footer.hide()
	hide()

static func supports(event: Dictionary) -> bool:
	return str(event.get("id", "")) in ["intro", "retry"]

func set_active(value: bool) -> void:
	if active == value: return
	active = value
	visible = value
	host.overlay_title.visible = not value
	separator.visible = not value
	footer.visible = value
	if value:
		host.overlay_close.reparent(self)
		host.overlay_next.reparent(footer)
		host.overlay_next.size_flags_horizontal = Control.SIZE_SHRINK_END
		host.overlay_next.custom_minimum_size.x = 124
		for button in [host.overlay_next, host.overlay_close]:
			for state in ["normal", "hover", "pressed"]:
				var style := StyleBoxFlat.new()
				style.bg_color = Color(0.05,0.10,0.14,0.90 if state == "normal" else 1.0)
				style.set_border_width_all(1)
				style.border_color = Color("867756")
				style.set_corner_radius_all(3)
				style.content_margin_left = 12
				style.content_margin_right = 12
				button.add_theme_stylebox_override(state, style)
			# PrimaryButton normally uses dark text on gold. This stage uses a
			# dark background, so all interactive states need light lettering.
			for color_name in ["font_color", "font_hover_color", "font_pressed_color", "font_focus_color"]:
				button.add_theme_color_override(color_name, Color("ffe4a3"))
		var panel := StyleBoxFlat.new()
		panel.bg_color = Color(0.025,0.06,0.09,0.97)
		panel.border_width_top = 1
		panel.border_color = Color("ad915e")
		panel.content_margin_left = 24
		panel.content_margin_right = 24
		panel.content_margin_top = 14
		panel.content_margin_bottom = 10
		host.overlay_panel.add_theme_stylebox_override("panel", panel)
	else:
		host.overlay_next.reparent(next_parent)
		next_parent.move_child(host.overlay_next, next_index)
		host.overlay_next.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		host.overlay_next.custom_minimum_size = next_minimum
		host.overlay_close.reparent(close_parent)
		close_parent.move_child(host.overlay_close, close_index)
		for button in [host.overlay_next, host.overlay_close]:
			for state in ["normal", "hover", "pressed"]:
				button.remove_theme_stylebox_override(state)
			for color_name in ["font_color", "font_hover_color", "font_pressed_color", "font_focus_color"]:
				button.remove_theme_color_override(color_name)
		host.overlay_panel.remove_theme_stylebox_override("panel")

func present(event: Dictionary, line: Dictionary, path: String) -> void:
	chapter.text = "序章" if event.get("id", "") == "intro" else "再启旅程"
	heading.text = str(event.get("title", ""))
	counter.text = "%d / %d" % [host.story_line + 1, event.get("lines", []).size()]
	StoryExpressionArt.present(portrait,path,event,line,host.story_line)
	portrait.visible = portrait.texture != null
	portrait.modulate = Color(0.82,0.91,1,0.88) if "传声石" in str(line.get("speaker", "")) else Color.WHITE

func layout() -> void:
	if not active: return
	var w: float = host.size.x
	var h: float = host.size.y
	var inset := 20.0 if w >= 400 else 14.0
	var panel_width := minf(w, 760)
	# Grow to the measured dialogue instead of clipping the first paragraph at 320px.
	# Unusually long external text retains the host's accessible scroll fallback.
	var content_height := 0.0
	# Measure at the final width: new labels can still have a zero-width cached
	# minimum during a page change, which otherwise grows a short line to 60%.
	for child in host.body.get_children():
		if child is Label:
			var label := child as Label
			var font := label.get_theme_font("font")
			var pixels := label.get_theme_font_size("font_size")
			var measured := font.get_multiline_string_size(label.text, HORIZONTAL_ALIGNMENT_LEFT, panel_width - 48, pixels)
			var lines := maxi(1, ceili(measured.y / font.get_height(pixels)))
			content_height += measured.y + (lines - 1) * label.get_theme_constant("line_spacing") + 8
		elif child is Control:
			content_height += child.get_combined_minimum_size().y + 8
	var panel_height := minf(h * 0.60, maxf(210, content_height + footer.get_combined_minimum_size().y + 42))
	host.overlay_panel.position = Vector2((w - panel_width) * 0.5, h - panel_height)
	host.overlay_panel.size = Vector2(panel_width, panel_height)
	heading.position = Vector2(inset, 44)
	heading.size = Vector2(maxf(160, w - inset * 2 - 84), 70)
	heading.add_theme_font_size_override("font_size", 22 if w >= 400 else 18)
	chapter.position = Vector2(inset, 15)
	chapter.size = Vector2(120, 28)
	host.overlay_close.text = "跳过  ›"
	host.overlay_close.position = Vector2(w - 96 - inset, 12)
	host.overlay_close.size = Vector2(96, 48)
	# Waist stays behind the dialogue panel, while the gate remains visible above.
	var portrait_height := minf(minf(h * 0.65, panel_width * 1.10), maxf(120, (h - panel_height - 112) / 0.83))
	var portrait_width := portrait_height * 2.0 / 3.0
	portrait.position = Vector2((w + panel_width) * 0.5 - portrait_width, h - panel_height - portrait_height * 0.83)
	portrait.size = Vector2(portrait_width, portrait_height)
	host.overlay_next.text = "结束对白  ›" if host.story_line >= host._story_event().get("lines", []).size() - 1 else "继续  ›"
