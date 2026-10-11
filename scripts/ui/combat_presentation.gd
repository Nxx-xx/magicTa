extends Control
## Read-only replay of an already committed combat. No resource or save mutations.
signal dismissed
signal cue_requested(cue: String)
const Stage = preload("res://scripts/ui/art_polish_c_stage.gd")
const Art = preload("res://scripts/ui/runtime_art.gd")
const FONT = preload("res://assets/ui/visual_v01/body_font.tres")
const TITLE = preload("res://assets/ui/visual_v01/title_font.tres")
const GOLD := Color("f3cf83")
const TEAL := Color("83dfcf")
const RED := Color("f3999a")
var context: Dictionary
var report: Dictionary
var enemy: Dictionary
var reduce_motion := false
var elapsed := 0.0
var celebration := 0.0
var settled := false
var finished := false
var showing_log := false
var last_beat := -1
var beats: Array = []
var primary: Button
var secondary: Button
var log_panel: PanelContainer
var log_scroll: ScrollContainer
var hero: Texture2D
var foe: Texture2D
var victory: Texture2D
var stage_scale := 1.0
var stage_origin := Vector2.ZERO
var effect_strength := 1.0

func configure(data: Dictionary, reduced: bool) -> void:
	context = data.duplicate(true)
	report = context.report
	enemy = context.enemy
	reduce_motion = reduced
	effect_strength = 1.35 if enemy.get("rank", "normal") in ["elite", "boss"] else 1.0
	var entries: Array = report.get("log", [])
	# Bound playback even for extremely long fights; every shown number is a real log entry.
	for index in mini(6, entries.size()):
		var source := index if entries.size() <= 6 else int(round(float(index) * (entries.size() - 1) / 5.0))
		beats.append(entries[source])

func _ready() -> void:
	name = "CombatPresentation"
	mouse_filter = Control.MOUSE_FILTER_STOP
	clip_contents = true
	hero = Art.texture("res://assets/ui/combat/hero_attack.png")
	if hero == null:
		hero = Art.hero("right")
	foe = Art.entity_texture({"type":"enemy", "enemy_id":context.enemy_id})
	victory = Art.texture("res://assets/ui/combat/hero_victory.png")
	primary = _button("跳过演出", _primary)
	secondary = _button("查看战报", _toggle_log)
	secondary.visible = false
	_build_log()
	resized.connect(_layout)
	_layout()
	_focus_primary.call_deferred()
	if reduce_motion or beats.is_empty():
		settle()

func _button(copy: String, action: Callable) -> Button:
	var button := Button.new()
	button.text = copy
	button.add_theme_font_size_override("font_size", 18)
	add_child(button)
	button.pressed.connect(action)
	return button

func _focus_primary() -> void:
	if is_inside_tree() and is_visible_in_tree():
		primary.grab_focus()

func _style_buttons() -> void:
	for button in [primary, secondary]:
		for state in ["normal", "hover", "pressed", "focus"]:
			var box := StyleBoxFlat.new()
			var gold_button: bool = button == primary and settled and report.won and not showing_log
			box.bg_color = Color("e6bd71") if gold_button else Color("142b38")
			if state == "hover":
				box.bg_color = box.bg_color.lightened(0.12)
			elif state == "pressed":
				box.bg_color = box.bg_color.darkened(0.15)
			box.border_color = Color("fff3c3") if state == "focus" else GOLD.darkened(0.25)
			box.set_border_width_all(2 if state == "focus" else 1)
			box.set_corner_radius_all(8)
			button.add_theme_stylebox_override(state, box)
			button.add_theme_color_override("font_" + ("color" if state == "normal" else state + "_color"), Color("292117") if gold_button else GOLD)

func _layout() -> void:
	var width := minf(520.0, size.x - 24)
	var left := (size.x - width) * 0.5
	primary.position = Vector2(left, size.y - (108 if settled else 60))
	primary.size = Vector2(width, 48)
	secondary.position = Vector2(left, size.y - 56)
	secondary.size = Vector2(width, 44)
	var art_height := maxf(1, primary.position.y - 8)
	stage_scale = minf(size.x / 540.0, art_height / 680.0)
	stage_origin = Vector2((size.x - 540 * stage_scale) * 0.5, (art_height - 680 * stage_scale) * 0.5)
	log_panel.position = Vector2(left, 12)
	log_panel.size = Vector2(width, maxf(80, primary.position.y - 24))
	_style_buttons()
	queue_redraw()

func _build_log() -> void:
	log_panel = PanelContainer.new()
	log_panel.theme_type_variation = "SheetPanel"
	add_child(log_panel)
	var column := VBoxContainer.new()
	log_panel.add_child(column)
	var title := Label.new()
	title.text = "战斗记录 · " + str(enemy.name)
	title.add_theme_color_override("font_color", GOLD)
	title.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	column.add_child(title)
	log_scroll = ScrollContainer.new()
	log_scroll.size_flags_vertical = Control.SIZE_EXPAND_FILL
	log_scroll.horizontal_scroll_mode = ScrollContainer.SCROLL_MODE_DISABLED
	log_scroll.focus_mode = Control.FOCUS_ALL
	column.add_child(log_scroll)
	var text := Label.new()
	text.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	text.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	text.add_theme_font_size_override("font_size", 15)
	var lines := PackedStringArray()
	for entry in report.get("log", []):
		lines.append("第 %d 击：造成 %d 伤害，敌人剩余 %d HP\n反击 %d，受击后生命 %d%s" % [entry.turn, entry.hit, entry.enemy_hp, entry.counter, entry.hp, "\n" + str(entry.note) if not str(entry.get("note", "")).is_empty() else ""])
	text.text = "\n\n".join(lines)
	log_scroll.add_child(text)
	log_panel.visible = false
	log_scroll.focus_mode = Control.FOCUS_NONE

func _process(delta: float) -> void:
	if not settled:
		elapsed += delta
		var beat := int((elapsed - 0.2) / 0.64)
		if elapsed >= 0.2 and beat >= 0 and beat < beats.size() and beat != last_beat:
			last_beat = beat
			cue_requested.emit("hit")
		if elapsed >= 0.2 + beats.size() * 0.64 + 0.32:
			settle()
	elif not reduce_motion:
		celebration += delta
	queue_redraw()

func settle() -> void:
	if settled:
		return
	settled = true
	celebration = 0.0
	primary.text = "继续探索" if report.won and not context.get("run_ended", false) else "继续"
	secondary.visible = true
	cue_requested.emit("victory" if report.won else "failure")
	if reduce_motion:
		set_process(false)
	_layout()
	if context.get("auto_close", false): _primary.call_deferred()

func _primary() -> void:
	if showing_log:
		_toggle_log()
	elif not settled:
		settle()
	elif not finished:
		finished = true
		dismissed.emit()

func escape() -> void:
	_primary()

func _toggle_log() -> void:
	showing_log = not showing_log
	log_panel.visible = showing_log
	log_scroll.focus_mode = Control.FOCUS_ALL if showing_log else Control.FOCUS_NONE
	secondary.visible = not showing_log
	primary.text = "返回结算" if showing_log else ("继续探索" if report.won and not context.get("run_ended", false) else "继续")
	primary.grab_focus()
	_style_buttons()
	queue_redraw()

func _copy(copy: String, point: Vector2, pixels: int, tint: Color = Color("e9efef"), width: float = 540, heading: bool = false) -> void:
	var font: Font = TITLE if heading else FONT
	pixels = maxi(pixels, int(ceil((10.0 if pixels <= 12 else 14.0) / maxf(0.1, stage_scale))))
	draw_string(font, point, copy, HORIZONTAL_ALIGNMENT_CENTER, width, pixels, tint)

func _texture(texture: Texture2D, rect: Rect2, tint: Color = Color.WHITE) -> void:
	if texture == null:
		return
	var dimensions := texture.get_size()
	var fitted := dimensions * minf(rect.size.x / dimensions.x, rect.size.y / dimensions.y)
	draw_texture_rect(texture, Rect2(rect.position + (rect.size - fitted) * 0.5, fitted), false, tint)

func _bar(rect: Rect2, value: float, maximum: float, tint: Color) -> void:
	draw_style_box(_box(Color("101f2a"), Color("465963")), rect)
	var fill := rect.grow(-3)
	fill.size.x *= clampf(value / maxf(1, maximum), 0, 1)
	if fill.size.x > 0:
		draw_style_box(_box(tint, tint), fill)

func _box(fill: Color, border: Color) -> StyleBoxFlat:
	var box := StyleBoxFlat.new()
	box.bg_color = fill
	box.border_color = border
	box.set_border_width_all(1)
	box.set_corner_radius_all(7)
	return box

func _draw() -> void:
	draw_rect(Rect2(Vector2.ZERO, size), Color(0.025, 0.055, 0.085, 0.87 if settled else 0.62))
	draw_style_box(_box(Color.TRANSPARENT, Color(0.78, 0.63, 0.36, 0.7)), Rect2(5, 4, size.x - 10, size.y - 8))
	if showing_log:
		return
	draw_set_transform(stage_origin, 0, Vector2.ONE * stage_scale)
	Stage.draw_environment(self,Vector2(540,680),Vector2(-100,-100) if settled else Vector2(164,606),Vector2(-100,-100) if settled else Vector2(375,496),Stage.select_environment(str(context.get("enemy_id","")),str(enemy.get("rank","normal"))))
	if settled:
		_draw_result()
	else:
		_draw_fight()
	draw_set_transform(Vector2.ZERO)

func _draw_fight() -> void:
	var raw := maxf(0, elapsed - 0.2) / 0.64
	var index := mini(int(raw), beats.size() - 1)
	if index < 0:
		return
	var entry: Dictionary = beats[index]
	var phase := fmod(raw, 1.0)
	var ending := elapsed > 0.2 + beats.size() * 0.64
	var dissolve := clampf((elapsed - 0.2 - beats.size() * 0.64) / 0.32, 0, 1) if report.won else 0.0
	var strike := sin(clampf(phase / 0.55, 0, 1) * PI)
	var impact := maxf(0, 1.0 - absf(phase - 0.35) * 5)
	_copy("交 战", Vector2(0, 62), 24, GOLD, 540, true)
	_copy(str(enemy.name), Vector2(210, 120), 26, GOLD, 290, true)
	var previous_hp: int = int(enemy.hp) if index == 0 else int(beats[index - 1].enemy_hp)
	_bar(Rect2(246, 136, 224, 13), float(entry.enemy_hp if phase > 0.35 or ending else previous_hp), float(enemy.hp), RED)
	var shake := sin(phase * 65) * impact * 7
	var counter_hit := sin(clampf((phase - 0.65) / 0.35, 0, 1) * PI) if int(entry.counter) > 0 and not ending else 0.0
	_texture(foe, Rect2(250 + shake - counter_hit * 34, 198 + counter_hit * 10, 248, 312), Color(1 + impact, 1 + impact, 1 + impact, 1 - dissolve))
	_texture(hero, Rect2(2 + strike * 84 - counter_hit * 12, 300 - strike * 24, 320, 320), Color(1, 1 - counter_hit * 0.35, 1 - counter_hit * 0.35))
	if phase > 0.16 and phase < 0.7 and not ending:
		var arc := PackedVector2Array()
		for segment in 25:
			var angle := -1.8 + segment / 24.0 * 2.4
			arc.append(Vector2(264, 358) + Vector2(cos(angle) * 155, sin(angle) * 108))
		draw_polyline(arc, Color(0.27, 0.93, 0.88, impact * 0.18), 28, true)
		draw_polyline(arc, Color(0.44, 1, 0.94, impact * 0.65), 12, true)
		draw_polyline(arc, Color(0.9, 1, 1, impact), 4, true)
		for ray in 12:
			var direction := Vector2.from_angle(ray * TAU / 12)
			draw_line(Vector2(377, 320) + direction * 8, Vector2(377, 320) + direction * (18 + impact * 32), Color(GOLD, impact), 2, true)
	if phase > 0.3 or ending:
		_copy("−%d" % int(entry.hit), Vector2(256, 210 - phase * 28), 38, Color.WHITE, 240, true)
	if int(entry.counter) > 0 and phase > 0.65 and not ending:
		_copy("−%d" % int(entry.counter), Vector2(30, 310 - phase * 15), 30, RED, 200, true)
	if ending and report.won:
		for mote in 32:
			var direction := Vector2.from_angle(mote * 2.4)
			var point := Vector2(365, 340) + direction * (30 + dissolve * (70 + mote * 3))
			draw_circle(point, 2 + (mote % 3), Color(GOLD, 1 - dissolve * 0.7))
	_copy("最后一击" if index == beats.size() - 1 and report.won else "第 %d 击" % int(entry.turn), Vector2(0, 610), 30, GOLD, 540, true)
	_copy("长战斗精简演出 · 完整过程见战报" if report.get("log", []).size() > 6 else "剑光破暗 · 迎击守卫", Vector2(0, 651), 17, Color("b4c6ca"))

func _crest(center: Vector2) -> void:
	var reveal := 1.0 if reduce_motion else clampf(celebration / 0.5, 0, 1)
	for ray in 24:
		var angle: float = ray * TAU / 24 + (0.0 if reduce_motion else celebration * 0.025)
		var direction := Vector2.from_angle(angle)
		var spread := Vector2.from_angle(angle + 0.04)
		draw_colored_polygon(PackedVector2Array([center + direction * 36, center + direction * (150 + ray % 3 * 26), center + spread * (150 + ray % 3 * 26)]), Color(1, 0.77, 0.32, 0.09 * reveal))
	for ring in 5:
		draw_arc(center, 58 + ring * 2, 0, TAU, 64, Color(1, 0.77, 0.3, 0.05 + 0.035 * ring), 2, true)
	for side in [-1, 1]:
		var branch := PackedVector2Array()
		for leaf in 9:
			var angle := 0.18 + leaf * 0.225
			var stem := center + Vector2(side * sin(angle) * 83, cos(angle) * 81)
			branch.append(stem)
			var axis := Vector2(side * (0.9 - leaf * 0.05), -0.7).normalized() * 32
			var normal := axis.normalized().orthogonal() * 8
			var outline := PackedVector2Array()
			for step in 13:
				var progress := step / 12.0
				outline.append(stem + axis * progress + normal * sin(PI * progress))
			for step in 13:
				var progress := 1 - step / 12.0
				outline.append(stem + axis * progress - normal * sin(PI * progress))
			draw_colored_polygon(outline, GOLD)
			draw_line(stem, stem + axis, Color("fff1b6"), 1, true)
		draw_polyline(branch, GOLD, 2, true)
	# Central upright sword and small diamond jewel.
	draw_colored_polygon(PackedVector2Array([center + Vector2(0,-62), center + Vector2(9,-42), center + Vector2(5,27), center + Vector2(-5,27), center + Vector2(-9,-42)]), Color("fff0ad"))
	draw_line(center + Vector2(-25,17), center + Vector2(25,17), GOLD, 5, true)
	draw_line(center + Vector2(0,20), center + Vector2(0,44), GOLD, 7, true)

func _draw_result() -> void:
	if not report.won:
		_copy("此战落败", Vector2(0, 145), 42, RED, 540, true)
		_texture(foe, Rect2(150, 192, 240, 280))
		_copy("倒在了 %s 面前" % enemy.name, Vector2(0, 520), 24)
		_copy("此次未获得战斗奖励", Vector2(0, 565), 20, Color("a2b3c3"))
		return
	_crest(Vector2(270, 91))
	_copy("战斗胜利", Vector2(0, 222), 56, GOLD, 540, true)
	_copy("已击败 · " + str(enemy.name), Vector2(0, 257), 22, Color("eadbbb"))
	var lift := 0.0 if reduce_motion else (1 - minf(1, celebration / 0.45)) * 24
	_texture(victory, Rect2(70, 250 + lift, 400, 400))
	if not reduce_motion:
		for mote in int(22 * effect_strength):
			var phase := fmod(celebration * (23 + mote % 7) + mote * 29, 440)
			var point := Vector2(35 + fmod(mote * 73.0, 470), 535 - phase)
			var alpha := sin(phase / 440 * PI) * 0.7
			draw_circle(point, 1.5 + mote % 2, Color(GOLD, alpha))
		for coin in 4:
			var flight := fmod(celebration * 0.55 + coin * 0.25, 1.0)
			var point := Vector2(85 if coin % 2 == 0 else 425, 490 - flight * 170)
			point.x += sin(flight * PI) * (-20 if coin % 2 == 0 else 20)
			_texture(Art.environment("coins"), Rect2(point, Vector2(32,32)), Color(1,1,1,sin(flight * PI) * 0.85))
	draw_style_box(_box(Color(0.035, 0.075, 0.11, 0.96), Color("776441")), Rect2(27, 520, 486, 157))
	_texture(Art.environment("coins"), Rect2(93, 525, 64, 57))
	var amount := int(report.gold_reward) if reduce_motion else int(round(int(report.gold_reward) * minf(1, celebration / 0.55)))
	_copy("金币 +%d" % amount, Vector2(156, 568), 34, GOLD, 287, true)
	_copy("受到伤害  %d" % int(report.incoming), Vector2(34, 610), 21, RED, 230)
	_copy("击杀恢复  +%d" % int(report.healing), Vector2(272, 610), 21, TEAL, 230)
	_copy("剩余生命 %d / %d" % [context.final_hp, context.max_hp], Vector2(34, 650), 20, TEAL, 280)
	_bar(Rect2(325, 633, 162, 16), float(context.final_hp), float(context.max_hp), TEAL)
	if int(context.final_hp) != int(report.hp_after):
		_copy("含战后恢复 +%d" % (int(context.final_hp) - int(report.hp_after)), Vector2(287, 672), 12, TEAL, 210)
