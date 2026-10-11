extends RefCounted
## Pure event reducer. The host persists snapshot(), never this module.
const IDS := ["T01", "T02", "T03", "T04", "T05", "T06", "T07", "T08"]
const COPY := {
	"T01": "点相邻地格，或使用方向键移动。",
	"T02": "先看预计损失，再决定是否挑战。",
	"T03": "装备已经生效，看看同一敌人的损失变化。",
	"T04": "同色钥匙开门；开过的门不会再收费。",
	"T05": "可以现在用，也可以留在这里。",
	"T06": "三项只能取一项，也能稍后回来。",
	"T07": "标记目标，变强后再回来。",
	"T08": "灵魂可在营地升级，也能免费重置。"
}
const BLOCKERS := ["save_error", "lethal_confirmation", "combat_modal", "reward_modal", "story", "story_queued"]
const STATUSES := ["eligible", "deferred", "shown", "completed", "dismissed", "skipped"]

static func initial_state() -> Dictionary:
	var nodes := {}
	for id in IDS:
		nodes[id] = {"status": "eligible", "triggered": false}
	return {"version": 1, "enabled": true, "nodes": nodes, "active": ""}

static func restore(saved: Dictionary) -> Dictionary:
	if saved.get("version", 0) != 1 or not saved.get("enabled") is bool or not saved.get("nodes") is Dictionary:
		return {"ok": false, "error": "Invalid tutorial preferences"}
	var state := initial_state()
	state.enabled = saved.enabled
	for id in IDS:
		var node: Variant = saved.nodes.get(id)
		if not node is Dictionary or not node.get("status", "") in STATUSES or not node.get("triggered") is bool:
			return {"ok": false, "error": "Invalid tutorial node: " + id}
		state.nodes[id] = node.duplicate(true)
		# A restored prompt must wait for the host's current overlay context.
		if node.status == "shown":
			state.nodes[id].status = "deferred"
	return {"ok": true, "error": "", "state": state}

static func snapshot(state: Dictionary) -> Dictionary:
	var copy := state.duplicate(true)
	copy.active = ""
	return copy

static func reduce(state: Dictionary, event: Dictionary, context: Dictionary = {}) -> Dictionary:
	var validated := restore(state)
	if not validated.ok:
		return validated
	var next: Dictionary = validated.state
	var kind := str(event.get("type", ""))
	if kind == "reset":
		next = initial_state()
	elif kind == "skip_all":
		next.enabled = false
		for id in IDS:
			if not next.nodes[id].status in ["completed", "dismissed"]:
				next.nodes[id].status = "skipped"
	elif kind == "dismiss":
		var id := str(event.get("id", state.get("active", "")))
		if id in IDS and next.nodes[id].triggered and not _terminal(next.nodes[id]):
			next.nodes[id].status = "dismissed"
	if next.enabled:
		match kind:
			"floor_entered":
				if event.get("floor", 0) == 1 and event.get("new_run", false):
					_trigger(next, "T01")
			"enemy_viewed":
				_trigger(next, "T02")
				if event.get("floor", 0) == 1 and event.get("enemy_id", "") == "knight":
					if event.get("lethal", false):
						_trigger(next, "T07")
					elif not _terminal(next.nodes.T07):
						next.nodes.T07.status = "skipped"
			"equipment_received":
				if event.get("committed", false):
					_trigger(next, "T03")
			"door_viewed":
				_trigger(next, "T04")
			"potion_viewed":
				_trigger(next, "T05")
			"ruin_viewed":
				if event.get("ruin_id", "") == "p3_oath_ruin":
					_trigger(next, "T06")
			"result_viewed":
				_trigger(next, "T08")
		var completed := ""
		match kind:
			"move_succeeded":
				if event.get("committed", false): completed = "T01"
			"enemy_preview_closed", "enemy_preview_confirmed":
				if event.get("viewed_full", false): completed = "T02"
			"comparison_viewed":
				if event.get("discovered", false) and event.get("same_enemy", false): completed = "T03"
			"door_opened":
				if event.get("committed", false): completed = "T04"
			"door_explanation_closed": completed = "T04"
			"potion_used":
				if event.get("committed", false): completed = "T05"
			"potion_retained": completed = "T05"
			"ruin_claimed":
				if event.get("committed", false) and event.get("ruin_id", "") == "p3_oath_ruin": completed = "T06"
			"ruin_left":
				if event.get("ruin_id", "") == "p3_oath_ruin": completed = "T06"
			"target_marked", "target_mark_declined": completed = "T07"
			"camp_embers_viewed", "result_hint_closed": completed = "T08"
		if not completed.is_empty() and next.nodes[completed].triggered and next.nodes[completed].status != "skipped":
			next.nodes[completed].status = "completed"
	_choose(next, context)
	return {"ok": true, "error": "", "state": next, "prompt": prompt(next, context)}

static func _terminal(node: Dictionary) -> bool:
	return node.status in ["completed", "dismissed", "skipped"]

static func _trigger(state: Dictionary, id: String) -> void:
	if not _terminal(state.nodes[id]):
		state.nodes[id].triggered = true

static func _choose(state: Dictionary, context: Dictionary) -> void:
	state.active = ""
	var blocked := false
	for key in BLOCKERS:
		blocked = blocked or context.get(key, false)
	for id in IDS:
		var node: Dictionary = state.nodes[id]
		if _terminal(node) or not node.triggered or not state.enabled:
			continue
		var unavailable: bool = id == "T03" and not context.get("comparison_available", false)
		if blocked or unavailable or not str(state.active).is_empty():
			node.status = "deferred"
		else:
			node.status = "shown"
			state.active = id

static func prompt(state: Dictionary, context: Dictionary = {}) -> Dictionary:
	for blocker in BLOCKERS:
		if context.get(blocker, false): return {}
	var id := str(state.get("active", ""))
	if not id in IDS or not state.get("enabled", false): return {}
	var copy: String = COPY[id]
	if id == "T05" and context.get("full_hp", false):
		copy = "满血时治疗会溢出，可以把药剂留在这里。"
	if id == "T08" and context.get("trial", false):
		copy = "返回营地可查看火种升级，也能免费重置。"
	return {"id": id, "text": copy}

static func create_prompt(data: Dictionary) -> PanelContainer:
	var view := Prompt.new()
	view.set_prompt(data)
	return view

class Prompt extends PanelContainer:
	signal dismissed(id: String)
	signal skip_requested
	var current: Dictionary = {}
	var copy_label: Label
	func set_prompt(data: Dictionary) -> void:
		current = data.duplicate(true)
		visible = not current.is_empty()
		if is_instance_valid(copy_label): copy_label.text = str(current.get("text", ""))
	func _ready() -> void:
		mouse_filter = Control.MOUSE_FILTER_PASS
		focus_mode = Control.FOCUS_NONE
		var box := StyleBoxFlat.new()
		box.bg_color = Color("193a46")
		box.border_color = Color("7bcaba")
		box.set_border_width_all(1)
		box.set_corner_radius_all(8)
		box.content_margin_left = 12
		box.content_margin_right = 12
		box.content_margin_top = 12
		box.content_margin_bottom = 12
		add_theme_stylebox_override("panel", box)
		var column := VBoxContainer.new()
		column.add_theme_constant_override("separation", 6)
		add_child(column)
		copy_label = Label.new()
		copy_label.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
		copy_label.text = str(current.get("text", ""))
		copy_label.mouse_filter = Control.MOUSE_FILTER_IGNORE
		column.add_child(copy_label)
		var buttons := HBoxContainer.new()
		column.add_child(buttons)
		var close := Button.new()
		close.text = "收起提示"
		close.custom_minimum_size.y = 44
		close.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		# Nonmodal coach marks must never steal Escape/Cancel or Tab focus.
		close.focus_mode = Control.FOCUS_NONE
		close.pressed.connect(func(): dismissed.emit(str(current.get("id", ""))))
		buttons.add_child(close)
		var skip := Button.new()
		skip.text = "跳过教学"
		skip.custom_minimum_size.y = 44
		skip.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		skip.focus_mode = Control.FOCUS_NONE
		skip.pressed.connect(func(): skip_requested.emit())
		buttons.add_child(skip)
