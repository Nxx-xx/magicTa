extends Control
## Read-only replay. Host calls configure only AFTER the transaction succeeds.
signal playback_finished(result: Dictionary)
signal dismissed
signal cue_presented(cue: Dictionary)
const Catalog = preload("res://scripts/ui/phase3_animation_catalog.gd")
const Art = preload("res://scripts/ui/runtime_art.gd")
const EnemyPlayer = preload("res://scripts/ui/phase3_enemy_player.gd")
const ReportPages = preload("res://scripts/ui/paged_catalog.gd")
const Stage = preload("res://scripts/ui/art_polish_c_stage.gd")
const STAGE_SPANS := {"slime":.60,"bat":.56,"skeleton":.72,"sentinel":.72,"warlock":.72,"knight":.74,"berserker":.84,"warden":.84,"minotaur":.80,"golem":.78,"p3_shield_sentinel":.72,"p3_ember_channeler":.70,"p3_vault_knight":.74}
const EFFECT_LABELS := {"first_hit_bonus": "首击增伤", "counter_guard": "提灯抵消", "periodic_hit_bonus": "三拍增伤", "retaliation": "荆棘反伤", "rank_gold_bonus": "赏金", "p3_shield": "盾壳减伤", "p3_ember": "蓄焰增伤", "p3_ambush": "金库突袭", "rage": "狂怒", "stone_armor": "石甲"}
var _report: Dictionary = {}
var _plan: Dictionary = {}
var _catalog := Catalog.new()
var _enemy_player := EnemyPlayer.new()
var _elapsed := 0.0
var _cursor := 0
var _finished := false
var _dismissed := false
var _configured := false
var _paused := false
var _manual_paused := false
var _background_paused := false
var _reduced := false
var _auto_close := false
var _action := "combat_idle"
var _action_start := 0.0
var _action_speed := 1.0
var _round_effects: Array[String] = []
var _column: VBoxContainer
var _headline: Label
var _cue: Label
var _sprite: TextureRect
var _enemy_sprite: TextureRect
var _enemy_effect_sprite: TextureRect
var _enemy_id := ""
var _enemy_name := ""
var _fallback: Label
var _log: RichTextLabel
var _report_pages: PanelContainer
var _primary: Button
var _log_toggle: Button
var _stage: Control
var _feedback: Control
var _environment_kind := "stone_hall"

static func _error(message: String) -> Dictionary:
	return {"ok": false, "error": message}

static func validate_report(report: Dictionary) -> Dictionary:
	if report.get("ok", true) != true or not report.get("log") is Array: return _error("Invalid report")
	for key in ["turns", "hp_after", "enemy_hp_after", "gold_reward", "healing", "incoming"]:
		if not Catalog._integer(report.get(key)) or report[key] < 0: return _error("Invalid report field: " + key)
	if not report.get("won") is bool or report.turns != report.log.size(): return _error("Report turn/outcome mismatch")
	if report.log.is_empty() or report.log.size() > 10000: return _error("Combat report turn count outside 1..10000")
	if report.has("min_hp") and (not Catalog._integer(report.min_hp) or report.min_hp < 0): return _error("Invalid minimum HP")
	if not report.get("effects_triggered", []) is Array: return _error("Invalid aggregate effects")
	for effect in report.get("effects_triggered", []):
		if not effect is Dictionary or not effect.get("id") is String or not Catalog._integer(effect.get("amount")) or effect.amount < 0:
			return _error("Invalid aggregate effect event")
	for index in report.log.size():
		var entry: Variant = report.log[index]
		if not entry is Dictionary: return _error("Invalid turn")
		for key in ["turn", "hit", "enemy_hp", "counter", "hp"]:
			if not Catalog._integer(entry.get(key)) or entry[key] < 0: return _error("Invalid turn field: " + key)
		if entry.turn != index + 1: return _error("Turns must be ordered and contiguous")
		for key in ["enemy_hp_after_counter", "retaliation_damage", "guard_reduction"]:
			if entry.has(key) and (not Catalog._integer(entry[key]) or entry[key] < 0): return _error("Invalid extended turn: " + key)
		if not entry.get("note", "") is String or not entry.get("effect_events", []) is Array: return _error("Invalid turn annotation")
		for effect in entry.get("effect_events", []):
			if not effect is Dictionary or not effect.get("id") is String or not Catalog._integer(effect.get("amount")) or effect.amount < 0:
				return _error("Invalid effect event")
		if entry.enemy_hp == 0 and (entry.counter > 0 or entry.get("retaliation_damage", 0) > 0): return _error("Counter after fatal player hit")
		if entry.get("retaliation_damage", 0) > 0 and not entry.has("enemy_hp_after_counter"): return _error("Retaliation requires final enemy HP")
	return {"ok": true, "error": ""}

static func choose_turns(report: Dictionary, limit: int = 6) -> Dictionary:
	var check := validate_report(report)
	if not check.ok: return check
	limit = clampi(limit, 1, 6)
	var entries: Array = report.log
	var selected: Array[int] = []
	var priority: Array[int] = [entries.size() - 1]
	var seen := {}
	for index in entries.size():
		for effect in entries[index].get("effect_events", []):
			if not seen.has(effect.id):
				seen[effect.id] = true
				if not index in priority: priority.append(index)
	for token in ["狂怒", "石甲"]:
		for index in entries.size():
			if token in str(entries[index].get("note", "")):
				if not index in priority: priority.append(index)
				break
	if not 0 in priority: priority.append(0)
	for index in priority:
		if selected.size() < limit: selected.append(index)
	# Farthest-from-selected gap filling keeps the remaining samples distributed.
	while selected.size() < mini(limit, entries.size()):
		var best := -1
		var distance := -1
		for index in entries.size():
			if index in selected: continue
			var nearest := entries.size()
			for other in selected: nearest = mini(nearest, absi(index - other))
			if nearest > distance:
				best = index
				distance = nearest
		selected.append(best)
	selected.sort()
	var omitted: Array[Dictionary] = []
	for index in entries.size():
		if index in selected: continue
		var entry: Dictionary = entries[index]
		if not entry.get("effect_events", []).is_empty() or not str(entry.get("note", "")).is_empty():
			omitted.append({"turn": entry.turn, "effect_events": entry.get("effect_events", []).duplicate(true), "note": entry.get("note", "")})
	return {"ok": true, "error": "", "indices": selected, "omitted_turns": entries.size() - selected.size(), "omitted_mechanisms": omitted}

static func build_plan(report: Dictionary, rank: String = "normal", reduced: bool = false) -> Dictionary:
	var selected := choose_turns(report, 5 if rank == "normal" else 6)
	if not selected.ok: return selected
	var cues: Array[Dictionary] = []
	var armor_states: Array[Dictionary] = []
	var armor_total := 0
	var scanned_turn := 0
	var duration := 0.0
	if not reduced:
		var step := 0.5 if rank == "normal" else (0.58 if rank == "elite" else 0.65)
		for index in selected.indices:
			var entry: Dictionary = report.log[index]
			# Carry only actual event increments from omitted committed turns.
			while scanned_turn < index:
				for effect in report.log[scanned_turn].get("effect_events", []):
					if effect.get("id", "") == "stone_armor": armor_total += int(effect.get("amount", 0))
				scanned_turn += 1
			armor_states.append({"at":duration,"stage":clampi(armor_total / 2,0,4)})
			var stages := stage_effects(entry)
			# Boss mechanisms follow the real strike, then have a readable pose
			# window before contact. This only spaces a committed report's cues.
			var mechanism_delay := .18 if rank == "boss" and not stages.mechanism.is_empty() else 0.0
			var after_delay := .18 if rank == "boss" and not stages.after_retaliation.is_empty() else 0.0
			cues.append({"at": duration, "kind": "prepare", "turn": entry.turn, "amount": 0, "speed": 0.5 / step})
			cues.append({"at": duration + step * 0.375, "kind": "attack", "turn": entry.turn, "amount": entry.get("actual_hit", entry.hit), "enemy_hp": entry.enemy_hp, "effects": stages.attack})
			if entry.enemy_hp > 0:
				if not stages.mechanism.is_empty():
					cues.append({"at": duration + step * 0.39, "kind": "mechanism", "turn": entry.turn, "amount": 0, "effects": stages.mechanism})
					for effect in stages.mechanism:
						if effect.get("id", "") == "stone_armor": armor_total += int(effect.get("amount", 0))
					armor_states.append({"at":duration+step*.39,"stage":clampi(armor_total / 2,0,4)})
				if entry.get("guard_reduction", 0) > 0 or not stages.guard.is_empty():
					cues.append({"at": duration + step * 0.4 + mechanism_delay, "kind": "guard", "turn": entry.turn, "amount": entry.get("guard_reduction", 0), "effects": stages.guard})
				cues.append({"at": duration + step * 0.55 + mechanism_delay, "kind": "counter", "turn": entry.turn, "amount": entry.counter, "hp": entry.hp, "effects": stages.counter})
				if entry.get("retaliation_damage", 0) > 0:
					cues.append({"at": duration + step * 0.78 + mechanism_delay, "kind": "retaliation", "turn": entry.turn, "amount": entry.retaliation_damage, "enemy_hp": entry.enemy_hp_after_counter, "effects": stages.retaliation})
				if not stages.after_retaliation.is_empty():
					cues.append({"at": duration + step * 0.80 + mechanism_delay, "kind": "mechanism", "turn": entry.turn, "amount": 0, "effects": stages.after_retaliation})
					if int(entry.get("enemy_hp_after_counter", entry.enemy_hp)) > 0:
						for effect in stages.after_retaliation:
							if effect.get("id", "") == "stone_armor": armor_total += int(effect.get("amount", 0))
						armor_states.append({"at":duration+step*.80+mechanism_delay,"stage":clampi(armor_total / 2,0,4)})
			scanned_turn = index + 1
			duration += step + mechanism_delay + after_delay
		duration = maxf(1.2, duration + 0.2)
	if reduced:
		for entry in report.log:
			for effect in entry.get("effect_events", []):
				if effect.get("id", "") == "stone_armor": armor_total += int(effect.get("amount", 0))
		armor_states.append({"at":0.0,"stage":clampi(armor_total / 2,0,4)})
	return {"ok": true, "error": "", "cues": cues, "duration": duration, "selected_indices": selected.indices, "omitted_turns": selected.omitted_turns, "omitted_mechanisms": selected.omitted_mechanisms, "result": final_result(report), "stone_armor_states":armor_states}

static func stage_effects(entry: Dictionary) -> Dictionary:
	# Producer events are ordered. Older saved reports need no schema rewrite.
	var stages := {"attack": [], "mechanism": [], "guard": [], "counter": [], "retaliation": [], "after_retaliation": []}
	var after_retaliation := false
	for effect in entry.get("effect_events", []):
		var id := str(effect.id)
		if id == "rank_gold_bonus": continue
		var stage := _effect_stage(id)
		if id == "rage": stage = "mechanism"
		if id == "stone_armor": stage = "after_retaliation" if after_retaliation else "mechanism"
		stages[stage].append(effect.duplicate(true))
		if id == "retaliation": after_retaliation = true
	return stages

static func final_result(report: Dictionary) -> Dictionary:
	var minimum := int(report.hp_after)
	for entry in report.log: minimum = mini(minimum, int(entry.hp))
	return {"won": report.won, "hp_after": report.hp_after, "enemy_hp_after": report.enemy_hp_after, "gold_reward": report.gold_reward, "healing": report.healing, "incoming": report.incoming, "min_hp": report.get("min_hp", minimum)}

static func effect_text(effect: Dictionary) -> String:
	if effect.get("id", "") == "stone_armor":
		var amount := int(effect.get("amount", 0))
		return "石甲 防御 +%d%s" % [amount,"（跨越%d层石甲）" % (amount / 2) if amount >= 4 else ""]
	return "%s %d" % [EFFECT_LABELS.get(effect.get("id", ""), str(effect.get("id", "机制"))), int(effect.get("amount", 0))]

static func sound_for_cue(cue: Dictionary) -> String:
	# Reuse shipped short sounds, including the existing WeChat WAV whitelist.
	# Zero-benefit guards and mechanisms stay text-only; host keeps its throttle.
	if int(cue.get("amount",0)) <= 0: return ""
	if cue.get("kind") in ["attack","counter","retaliation"]: return "hit"
	if cue.get("kind") == "guard": return "door"
	return ""

static func report_text(report: Dictionary) -> String:
	var lines := PackedStringArray()
	for entry in report.get("log", []):
		var copy := "第%d回合  攻击%d → 敌HP %d；反击%d → HP %d" % [entry.turn, entry.hit, entry.enemy_hp, entry.counter, entry.hp]
		if entry.get("retaliation_damage", 0) > 0: copy += "；反伤%d → 敌HP %d" % [entry.retaliation_damage, entry.enemy_hp_after_counter]
		if not str(entry.get("note", "")).is_empty(): copy += "\n" + entry.note
		for effect in entry.get("effect_events", []): copy += "\n" + effect_text(effect)
		lines.append(copy)
	for effect in report.get("effects_triggered", []):
		if effect is Dictionary and effect.get("id", "") == "rank_gold_bonus": lines.append(effect_text(effect))
	return "\n\n".join(lines)

func configure(report: Dictionary, committed: bool, options: Dictionary = {}) -> Dictionary:
	if not committed: return _error("Playback requires a successfully committed report")
	if _configured: return _error("Create a new player for another report")
	var candidate := build_plan(report, str(options.get("rank", "normal")), bool(options.get("reduce_motion", false)))
	if not candidate.ok: return candidate
	_report = report.duplicate(true)
	_plan = candidate
	_reduced = bool(options.get("reduce_motion", false))
	_auto_close = bool(options.get("auto_close", false))
	_enemy_id = str(options.get("enemy_id", ""))
	_enemy_name = str(options.get("enemy_name", ""))
	_environment_kind = Stage.select_environment(_enemy_id, str(options.get("rank", "normal")), str(options.get("environment", "")))
	if is_instance_valid(_stage): _stage.environment_kind = _environment_kind
	_enemy_player.configure(_enemy_id, _plan)
	_enemy_player.effects_enabled = bool(options.get("enemy_effects",true))
	_configured = true
	_catalog.configure_runtime()
	if is_node_ready(): _begin()
	return {"ok": true, "error": "", "duration": _plan.duration}

func _ready() -> void:
	mouse_filter = Control.MOUSE_FILTER_STOP
	clip_contents = true
	var background := ColorRect.new()
	background.color = Color("14242e")
	background.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(background)
	background.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	_column = VBoxContainer.new()
	add_child(_column)
	_column.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	_column.offset_left = 12
	_column.offset_right = -12
	_column.offset_top = 12
	_column.offset_bottom = -12
	_headline = _label(22)
	var opponent := _label(16)
	opponent.text = _enemy_name
	opponent.visible = not _enemy_name.is_empty()
	var actors := Stage.new()
	_stage = actors
	actors.environment_kind = _environment_kind
	actors.name = "ArtPolishCStage"
	actors.size_flags_vertical = Control.SIZE_EXPAND_FILL
	actors.custom_minimum_size.y = 100
	_column.add_child(actors)
	_sprite = TextureRect.new()
	_sprite.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	_sprite.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
	_sprite.size_flags_vertical = Control.SIZE_EXPAND_FILL
	_sprite.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	actors.add_child(_sprite)
	_enemy_sprite = TextureRect.new()
	_enemy_sprite.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	_enemy_sprite.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
	_enemy_sprite.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	_enemy_sprite.texture = Art.enemy_static(_enemy_id) if not _enemy_id.is_empty() else null
	_enemy_sprite.visible = _enemy_sprite.texture != null
	actors.add_child(_enemy_sprite)
	_enemy_effect_sprite = TextureRect.new()
	_enemy_effect_sprite.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_enemy_effect_sprite.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	_enemy_effect_sprite.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
	_enemy_sprite.add_child(_enemy_effect_sprite)
	_enemy_effect_sprite.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	_feedback = Stage.new()
	_feedback.foreground = true
	actors.add_child(_feedback)
	_feedback.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	actors.resized.connect(_render_frame)
	_fallback = _label(14)
	_cue = _label(18)
	_cue.custom_minimum_size.y = 68
	_cue.add_theme_color_override("font_color", Color("e4cb9d"))
	_log = RichTextLabel.new()
	_log.bbcode_enabled = false
	_log.size_flags_vertical = Control.SIZE_EXPAND_FILL
	_log.custom_minimum_size.y = 120
	_log.visible = false
	_column.add_child(_log)
	_report_pages = ReportPages.new()
	_report_pages.name = "CombatReportPages"
	_report_pages.back_label = "‹  返回战报概况"
	_report_pages.embedded = true
	_column.add_child(_report_pages)
	_report_pages.custom_minimum_size.y = 220
	_report_pages.visible = false
	_log_toggle = Button.new()
	_log_toggle.text = "完整战报 / 机制摘要"
	_log_toggle.custom_minimum_size.y = 44
	_log_toggle.pressed.connect(func():
		_auto_close = false # Reading the report must never be interrupted.
		_set_report_visible(not _report_pages.visible)
	)
	_column.add_child(_log_toggle)
	_primary = Button.new()
	_primary.text = "跳过演出"
	_primary.custom_minimum_size.y = 48
	_primary.pressed.connect(func():
		if _finished: close()
		else: skip()
	)
	_column.add_child(_primary)
	_primary.focus_neighbor_top = _primary.get_path_to(_log_toggle)
	_primary.focus_neighbor_bottom = _primary.get_path_to(_log_toggle)
	_primary.focus_next = _primary.get_path_to(_log_toggle)
	_primary.focus_previous = _primary.get_path_to(_log_toggle)
	_log_toggle.focus_neighbor_top = _log_toggle.get_path_to(_primary)
	_log_toggle.focus_neighbor_bottom = _log_toggle.get_path_to(_primary)
	_log_toggle.focus_next = _log_toggle.get_path_to(_primary)
	_log_toggle.focus_previous = _log_toggle.get_path_to(_primary)
	if _configured: _begin()

func _label(font_size: int) -> Label:
	var label := Label.new()
	label.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	label.add_theme_font_size_override("font_size", font_size)
	_column.add_child(label)
	return label

func _begin() -> void:
	_headline.text = "战斗"
	_log.text = "略过 %d 回合。\n" % _plan.omitted_turns
	for entry in _plan.omitted_mechanisms:
		_log.text += "省略回合%d：%s" % [entry.turn, entry.note]
		for effect in entry.effect_events: _log.text += " " + effect_text(effect)
		_log.text += "\n"
	_log.text += "\n完整战报\n" + report_text(_report)
	_report_pages.present_choices([
		{"id":"summary","name":"结算与机制","icon":"shield","readonly":true,"detail":"战后生命 %d · 金币 +%d\n总受伤 %d · 治疗 %d\n战中最低生命 %d\n\n" % [_report.hp_after,_report.gold_reward,_report.incoming,_report.healing,_report.min_hp] + _log.text.get_slice("\n完整战报",0)},
		{"id":"full","name":"完整战斗过程","icon":"log","readonly":true,"detail":report_text(_report)}
	],"","战后生命 %d · 金币 +%d" % [_report.hp_after,_report.gold_reward])
	_cue.text = "准备交锋"
	if _reduced: _finish()
	_render_frame()

func _set_report_visible(value: bool) -> void:
	_report_pages.visible = value
	_cue.visible = not value
	_sprite.get_parent().visible = not value
	_log_toggle.text = "返回战斗演出" if value else "战报 · 机制与回合详情"

func _process(delta: float) -> void:
	if not _configured or _paused or not is_visible_in_tree(): return
	if _finished:
		if not _reduced:
			_elapsed += delta
			_render_frame()
		return
	advance(delta)

func advance(delta: float) -> void:
	if not _configured or _finished or _paused or not is_finite(delta) or delta < 0: return
	_elapsed += delta
	while _cursor < _plan.cues.size() and _plan.cues[_cursor].at <= _elapsed:
		var cue: Dictionary = _plan.cues[_cursor]
		_cursor += 1
		if cue.kind == "prepare": _round_effects.clear()
		for effect in cue.get("effects", []): _round_effects.append(effect_text(effect))
		if cue.kind not in ["attack", "mechanism"]:
			_action = {"prepare": "combat_attack", "guard": "combat_guard", "counter": "combat_hit", "retaliation": "combat_guard"}.get(cue.kind, "combat_idle")
			if cue.kind == "counter" and cue.amount == 0: _action = "combat_guard"
			_action_start = cue.at
			_action_speed = float(cue.get("speed", 1.0))
		if is_instance_valid(_cue):
			_cue.text = "回合 %d · %s" % [cue.turn, {"prepare": "蓄力", "attack": "攻击", "guard": "提灯抵消", "counter": "反击", "retaliation": "反伤", "mechanism": "守卫机制"}[cue.kind]]
			if cue.kind not in ["prepare", "mechanism"]: _cue.text += " %d" % cue.amount
			# Keep mechanism facts visible through this turn, even when several cues
			# fall within one rendered frame or attack/counter are compressed.
			if not _round_effects.is_empty(): _cue.text += "\n" + " · ".join(_round_effects)
		cue_presented.emit(cue.duplicate(true))
	if _elapsed >= _plan.duration: _finish()
	_render_frame()

func _render_frame() -> void:
	if not is_instance_valid(_sprite): return
	var frame := _catalog.frame_at(_action, (_elapsed - _action_start) * _action_speed, _reduced)
	_sprite.texture = frame.texture
	var opponent := _enemy_player.frame_at(_elapsed,_finished,bool(_report.get("won",false)),_reduced)
	_enemy_sprite.texture = opponent.texture
	_enemy_effect_sprite.texture = opponent.get("effects_texture")
	_layout_stage(frame, opponent)
	_fallback.text = ""
	_fallback.visible = false

func _layout_stage(frame: Dictionary, opponent: Dictionary) -> void:
	if not is_instance_valid(_stage) or not is_instance_valid(_feedback): return
	var w := _stage.size.x
	var floor_y := _stage.size.y * .78
	var hero_foot := Vector2(w*.27,floor_y)
	var enemy_foot := Vector2(w*.74,floor_y)
	_place_actor(_sprite,hero_foot,minf(w*.66,_stage.size.y*.85),frame.get("anchor",Vector2(192,348)))
	var action: Dictionary = _enemy_player.actions.get(opponent.get("source_action",opponent.get("action","idle")),{})
	var anchor_data: Array = action.get("anchor",[128,224])
	var anchor := Vector2(anchor_data[0],anchor_data[1])
	if action.is_empty() and _enemy_sprite.texture != null: anchor = _enemy_sprite.texture.get_size()*Vector2(.5,.9)
	var enemy_span: float = STAGE_SPANS.get(_enemy_id,.70)
	_place_actor(_enemy_sprite,enemy_foot,minf(w*enemy_span,_stage.size.y*.85),anchor)
	_feedback.enemy_number_height = maxf(.49,enemy_span*.74)
	for layer in [_stage,_feedback]:
		layer.hero_foot = hero_foot
		layer.enemy_foot = enemy_foot
		layer.sample(_plan.get("cues",[]),_elapsed,_reduced,_finished)

func _place_actor(actor: TextureRect, foot: Vector2, span: float, anchor: Vector2) -> void:
	if actor.texture == null: return
	var scale_factor := span / actor.texture.get_width()
	actor.size = actor.texture.get_size()*scale_factor
	actor.position = foot-anchor*scale_factor

func set_paused(value: bool) -> void:
	_manual_paused = value
	_paused = _manual_paused or _background_paused

func set_reduce_motion(value: bool) -> void:
	_reduced = value
	if value and _configured:
		_finish()
		# A setting change after skip/settlement must also enter the quiet report.
		if is_instance_valid(_report_pages): _set_report_visible(true)
		_render_frame()

func skip() -> void:
	if _configured: _finish()

func close() -> void:
	if _dismissed: return
	if _configured: _finish()
	_dismissed = true
	dismissed.emit()

func _finish() -> void:
	if _finished: return
	_finished = true
	_action = "combat_victory" if _report.won else "combat_defeat"
	_action_start = _elapsed
	_action_speed = 1.0
	if is_instance_valid(_headline):
		_headline.text = "胜利" if _report.won else "战败"
		_cue.text = "战后生命 %d · 金币 +%d" % [_report.hp_after, _report.gold_reward]
		if int(_report.healing) > 0: _cue.text += "\n战后恢复 %d 生命" % int(_report.healing)
		_primary.text = "继续"
		if _reduced:
			_set_report_visible(true)
	_render_frame()
	playback_finished.emit(_plan.result.duplicate(true))
	if _auto_close: close.call_deferred()

func full_report() -> Dictionary:
	return _report.duplicate(true)

static func _effect_stage(id: String) -> String:
	if id == "counter_guard": return "guard"
	if id == "retaliation": return "retaliation"
	if id in ["rage", "stone_armor", "p3_ember", "p3_ambush"]: return "counter"
	if id == "rank_gold_bonus": return "settlement"
	return "attack"

func _notification(what: int) -> void:
	if what in [NOTIFICATION_APPLICATION_PAUSED, NOTIFICATION_APPLICATION_FOCUS_OUT]: _background_paused = true
	elif what in [NOTIFICATION_APPLICATION_RESUMED, NOTIFICATION_APPLICATION_FOCUS_IN]: _background_paused = false
	_paused = _manual_paused or _background_paused
