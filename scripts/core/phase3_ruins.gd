extends RefCounted
## Pure event adapter. All player arithmetic belongs to phase3_items.resolve.
const IDS := {"p3_oath_ruin":2, "p3_oath_forge":6, "p3_lantern_sanctuary":9}
const OPTIONS := {
	"p3_oath_ruin":["edge", "guard", "salvage", "leave"],
	"p3_oath_forge":["temper", "sacrifice", "salvage", "leave"],
	"p3_lantern_sanctuary":["restore", "ward", "reserve", "leave"]}

static func definitions() -> Dictionary:
	var file := FileAccess.open("res://data/phase3_ruins.json", FileAccess.READ)
	if file == null:
		return {}
	var parsed = JSON.parse_string(file.get_as_text())
	if not parsed is Dictionary or parsed.get("version") != 1 or not parsed.get("ruins") is Dictionary:
		return {}
	return parsed.ruins.duplicate(true) if validate_definitions(parsed.ruins).ok else {}

static func validate_definitions(defs: Dictionary) -> Dictionary:
	if defs.size() != IDS.size():
		return _error("遗迹必须包含固定的三个稳定 ID。")
	for id in IDS:
		if not defs.get(id) is Dictionary:
			return _error("遗迹定义缺失：" + id)
		var ruin: Dictionary = defs[id]
		if defs.get("p3_oath_ruin", {}).get("trail", {}) is Dictionary and defs.get("p3_oath_ruin", {}).get("trail", {}).has("story_id") and not ruin.has("trail"):
			return _error("勇者往事快照缺少章节。")
		if ruin.get("floor") != IDS[id] or not _text(ruin.get("name")) or not _text(ruin.get("description")):
			return _error("遗迹名称、说明或楼层无效：" + id)
		if not ruin.get("options") is Array or ruin.options.size() != 4:
			return _error("遗迹需要三个互斥选项和免费离开。")
		if ruin.has("trail"):
			var trail = ruin.trail
			if not trail is Dictionary or trail.get("chain") != "unreturned_lamp_v1":
				return _error("遗物暗线版本无效。")
			for field in ["title", "evidence", "clue", "lead", "standalone"]:
				if not _text(trail.get(field)): return _error("遗物暗线缺少文案：" + field)
			if trail.has("story_id"):
				for field in ["story_id", "story_title", "conclusion", "knight_memory"]:
					if not _text(trail.get(field)): return _error("勇者往事快照缺少：" + field)
				if trail.get("variant_id") not in ["sealed", "disturbed"]: return _error("勇者往事现场无效。")
				var first: Dictionary = defs.get("p3_oath_ruin", {}).get("trail", {})
				if trail.story_id != first.get("story_id") or trail.story_title != first.get("story_title") or trail.conclusion != first.get("conclusion"):
					return _error("同一旅程不能混合不同勇者往事。")
			elif defs.get("p3_oath_ruin", {}).get("trail", {}).has("story_id"):
				return _error("勇者往事快照不完整。")
			var previous: String = {"p3_oath_ruin":"", "p3_oath_forge":"p3_oath_ruin", "p3_lantern_sanctuary":"p3_oath_forge"}[id]
			if trail.get("previous") != previous or not trail.get("link") is String or (not previous.is_empty() and not _text(trail.link)):
				return _error("遗物暗线的前后关系无效。")
			if not trail.get("finds") is Dictionary or trail.finds.size() != 3:
				return _error("遗物暗线需要三种遗物去向。")
			for choice in OPTIONS[id]:
				if choice == "leave": continue
				var find = trail.finds.get(choice)
				if not find is Dictionary or not _text(find.get("name")) or not _text(find.get("outcome")):
					return _error("遗物去向缺失或无效。")
		var seen := []
		for option in ruin.options:
			if not option is Dictionary or not _text(option.get("id")):
				return _error("遗迹选项格式无效。")
			if option.id not in OPTIONS[id] or option.id in seen or not _text(option.get("name")) or not _text(option.get("description")):
				return _error("选项 ID 重复、未知或文案无效。")
			seen.append(option.id)
			for field in option:
				if field not in ["id","name","description","cost","effects","requires_healing"]:
					return _error("未知选项字段：" + str(field))
			for group in ["cost", "effects"]:
				if not option.get(group, {}) is Dictionary:
					return _error("选项成本/收益必须为字典。")
				for field in option.get(group, {}):
					var allowed := ["hp","gold","max_hp"] if group == "cost" else ["attack","defense","gold","heal"]
					if field not in allowed or not _count(option[group][field]):
						return _error("未知、负数或非整数的遗迹数值。")
			if option.has("requires_healing") and not option.requires_healing is bool:
				return _error("治疗条件必须为布尔值。")
			if option.get("requires_healing", false) and int(option.get("effects", {}).get("heal", 0)) <= 0:
				return _error("治疗条件必须对应正数治疗。")
			if option.id == "leave" and (not option.get("cost", {}).is_empty() or not option.get("effects", {}).is_empty() or option.get("requires_healing", false)):
				return _error("离开不得收费、奖励或限制。")
			if option.id != "leave" and option.get("effects", {}).is_empty():
				return _error("获益选项缺少收益。")
	return {"ok":true, "error":""}

static func event_definitions(ruin_definitions: Dictionary = {}) -> Dictionary:
	var defs := definitions() if ruin_definitions.is_empty() else ruin_definitions
	if not validate_definitions(defs).ok:
		return {}
	var events := {}
	for id in defs:
		events[id] = {"name":defs[id].name, "description":defs[id].description,
			"options":defs[id].options.duplicate(true), "ruin_id":id, "rules_version":1}
	return events

static func reward_for_option(ruin_id: String, option_id: String, ruin_definitions: Dictionary = {}) -> Dictionary:
	var defs := definitions() if ruin_definitions.is_empty() else ruin_definitions
	var validation := validate_definitions(defs)
	if not validation.ok:
		return validation
	if not defs.has(ruin_id):
		return _error("未知遗迹。")
	for option in defs[ruin_id].options:
		if option.id == option_id:
			var reward := {}
			for field in ["cost", "effects"]:
				if option.has(field):
					reward[field] = option[field].duplicate(true)
			return {"ok":true,"error":"","reward":reward,"consumes":option_id != "leave",
				"requires_healing":bool(option.get("requires_healing", false))}
	return _error("未知遗迹选项。")

## Caller supplies the frozen content and the authoritative items.resolve Callable.
## This never commits. The same condition must be checked again inside the save transaction.
static func preview_options(ruin_id: String, player: Dictionary, content: Dictionary, resolver: Callable, ruin_definitions: Dictionary = {}) -> Dictionary:
	var defs := definitions() if ruin_definitions.is_empty() else ruin_definitions
	var validation := validate_definitions(defs)
	if not validation.ok:
		return validation
	if not defs.has(ruin_id) or not resolver.is_valid():
		return _error("遗迹或交易解析器无效。")
	var previews := {}
	for option in defs[ruin_id].options:
		var request := reward_for_option(ruin_id, option.id, defs)
		if not request.consumes:
			previews[option.id] = {"ok":true,"error":"","consumes":false}
			continue
		var result = resolver.call(content.duplicate(true), player.duplicate(true), request.reward)
		if not result is Dictionary or not result.get("ok") is bool:
			return _error("交易解析器返回格式无效。")
		result = result.duplicate(true)
		if result.ok and request.requires_healing and int(result.get("healing", 0)) <= 0:
			result = _error("生命已满，保留灯火可稍后回来。")
		result.consumes = true
		previews[option.id] = result
	return {"ok":true,"error":"","options":previews}

## Consume caller-computed combat reports only; never reveals an undiscovered target
## or updates the player's original comparison baseline when a panel is reopened.
static func marked_target_hint(mark: Dictionary, current_report: Dictionary) -> Dictionary:
	if mark.get("discovered", false) != true:
		return {"ok":true,"error":"","show_hint":false}
	if not _text(mark.get("entity_id")) or not _count(mark.get("floor")) or int(mark.floor) < 1 or int(mark.floor) > 10:
		return _error("标记目标身份无效。")
	var previous = mark.get("previous_report")
	if not previous is Dictionary or not previous.get("won") is bool or not current_report.get("won") is bool or current_report.get("ok", true) != true:
		return _error("标记比较缺少有效的已计算战报。")
	return {"ok":true,"error":"","show_hint":not previous.won and current_report.won,
		"entity_id":mark.entity_id,"floor":int(mark.floor),"previous":previous.duplicate(true),"current":current_report.duplicate(true)}

## A pure transaction candidate, not a save/commit. Parent engine must atomically save
## this player + entity + metrics and discard the entire candidate on write failure.
static func prepare_resolution(ruin_id: String, option_id: String, state: Dictionary, content: Dictionary, player: Dictionary, resolver: Callable, run_id: String, ruin_definitions: Dictionary = {}) -> Dictionary:
	var request := reward_for_option(ruin_id, option_id, ruin_definitions)
	if not request.ok: return request
	var raw_entity_id = state.get("entity_id", state.get("id", ""))
	if not _text(raw_entity_id) or state.get("ruin_id") != ruin_id or state.get("rules_version") != 1:
		return _error("遗迹状态身份或规则版本无效。")
	var entity_id: String = raw_entity_id
	if state.get("status") not in ["available","resolved"]:
		return _error("遗迹持久状态无效。")
	if state.status == "available" and (state.get("selected_option", "") != "" or state.get("transaction_id", "") != ""):
		return _error("可用遗迹包含冲突的交易记录。")
	if state.status == "resolved":
		if not _text(state.get("selected_option")) or not _text(state.get("transaction_id")):
			return _error("已耗尽遗迹缺少选择或交易记录。")
		var recorded := reward_for_option(ruin_id, state.selected_option, ruin_definitions)
		if not recorded.ok or not recorded.consumes: return _error("已耗尽遗迹记录了未知或非获益选项。")
	if not request.consumes:
		return {"ok":true,"error":"","consumes":false,"player":player.duplicate(true),"ruin_state":state.duplicate(true)}
	if state.status == "resolved": return _error("遗迹本局已经耗尽。")
	if run_id.is_empty() or not resolver.is_valid(): return _error("缺少旅程身份或交易解析器。")
	var reward = resolver.call(content.duplicate(true), player.duplicate(true), request.reward)
	if not reward is Dictionary or not reward.get("ok") is bool: return _error("交易解析器返回无效。")
	if not reward.ok: return reward.duplicate(true)
	if not reward.get("player") is Dictionary: return _error("交易解析器缺少玩家候选。")
	if request.requires_healing and int(reward.get("healing", 0)) <= 0: return _error("生命已满，保留灯火可稍后回来。")
	var next := state.duplicate(true)
	next.status = "resolved"
	next.selected_option = option_id
	next.transaction_id = "%s:%s:resolve" % [run_id,entity_id]
	return {"ok":true,"error":"","consumes":true,"player":reward.player.duplicate(true),"ruin_state":next,
		"reward_result":reward.duplicate(true),"metric_choice":{entity_id:option_id}}

## Independent per-field maxima; these cannot all be claimed in one route.
static func direct_effect_budget(ruin_definitions: Dictionary = {}) -> Dictionary:
	var defs := definitions() if ruin_definitions.is_empty() else ruin_definitions
	var validation := validate_definitions(defs)
	if not validation.ok:
		return validation
	var totals := {"hp_cost":0,"max_hp_cost":0,"gold_cost":0,"attack":0,"defense":0,"gold_gain":0,"heal":0}
	var per_ruin := {}
	for id in defs:
		var maxima := totals.duplicate()
		for field in maxima:
			maxima[field] = 0
		for option in defs[id].options:
			for field in ["hp","max_hp","gold"]:
				maxima[field + "_cost"] = maxi(maxima[field + "_cost"], int(option.get("cost", {}).get(field, 0)))
			for field in ["attack","defense","gold","heal"]:
				var key: String = "gold_gain" if field == "gold" else field
				maxima[key] = maxi(maxima[key], int(option.get("effects", {}).get(field, 0)))
		per_ruin[id] = maxima
		for field in totals:
			totals[field] += maxima[field]
	return {"ok":true,"error":"","per_ruin":per_ruin,"upper_bounds":totals,"max_resolutions":3}

static func _text(value: Variant) -> bool:
	return value is String and not value.strip_edges().is_empty()

static func _count(value: Variant) -> bool:
	return (value is int or value is float) and is_finite(float(value)) and float(value) >= 0 and float(value) <= 1000000 and float(value) == floorf(float(value))

static func _error(message: String) -> Dictionary:
	return {"ok":false,"error":message}
