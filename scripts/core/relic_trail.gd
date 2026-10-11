extends RefCounted
## Evidence is derived from committed ruin choices and frozen run content.
## No additional save fields, RNG, rewards, or cross-run discovery are needed.
const IDS := ["p3_oath_ruin", "p3_oath_forge", "p3_lantern_sanctuary"]
const CHAIN := "unreturned_lamp_v1"
const TITLE := "未归者的灯"

static func entries(run: Dictionary) -> Array:
	var result: Array = []
	var definitions: Dictionary = run.get("ruin_definitions_snapshot", {})
	for id in IDS:
		var definition: Dictionary = definitions.get(id, {})
		var trail: Dictionary = definition.get("trail", {})
		if trail.get("chain") != CHAIN: continue
		var floor_map: Dictionary = run.get("floors", {}).get(str(int(definition.get("floor", 0))), {})
		for entity in floor_map.get("entities", {}).values():
			if entity.get("ruin_id") != id or entity.get("status") != "resolved": continue
			var choice := str(entity.get("selected_option", ""))
			if not trail.get("finds", {}).has(choice): continue
			var find: Dictionary = trail.finds[choice]
			result.append({"id":id, "title":trail.title, "story_title":trail.get("story_title", TITLE), "floor":definition.floor,
				"evidence":trail.evidence, "clue":trail.clue, "lead":trail.lead,
				"item":find.name, "outcome":find.outcome, "choice":choice})
			break
	return result

static func has_evidence(run: Dictionary, id: String) -> bool:
	for entry in entries(run):
		if entry.id == id: return true
	return false

static func complete(run: Dictionary) -> bool:
	return entries(run).size() == IDS.size()

static func conclusion(run: Dictionary = {}) -> String:
	var frozen: Dictionary = run.get("ruin_definitions_snapshot", {}).get(IDS[0], {}).get("trail", {})
	if frozen.has("conclusion"): return str(frozen.conclusion)
	return "三处遗物上的缺角灯纹终于拼合：守灯人留下武器、补给和副芯，是要让后来者带回失踪者的名字。新的王室拆锁订单却借用了他们的旧路。有人把救援当成了开启封印的机会；归途灯必须留在自己手里。"

static func journal(run: Dictionary) -> Array:
	var rows: Array = []
	for entry in entries(run):
		rows.append({"id":"trail_" + entry.id, "name":str(entry.title).trim_prefix(str(entry.story_title) + " · "), "icon":"book", "readonly":true,
			"brief":"第 %d 层 · %s" % [entry.floor, entry.evidence],
			"detail":"%s\n第 %d 层 · %s\n\n%s\n\n遗物去向 · %s\n%s\n\n下一条线索\n%s" % [entry.story_title, entry.floor, entry.evidence, entry.clue, entry.item, entry.outcome, entry.lead]})
	if rows.size() == IDS.size():
		rows.append({"id":"trail_complete", "name":"拼合的往事", "icon":"lamp", "readonly":true,
			"brief":"三份证据已串联 · 可向老骑士求证", "detail":conclusion(run)})
	return rows

static func presentation(run: Dictionary, definition: Dictionary, entity: Dictionary) -> Dictionary:
	var result := definition.duplicate(true)
	var trail: Dictionary = result.get("trail", {})
	if trail.get("chain") != CHAIN: return result
	var copy := str(result.description)
	if trail.has("story_id") and entity.get("status") != "resolved":
		copy += "\n\n遗物上的发现\n" + str(trail.clue)
	var previous := str(trail.get("previous", ""))
	if not previous.is_empty() and has_evidence(run, previous):
		copy += "\n\n" + str(trail.link)
	else:
		copy += "\n\n" + str(trail.standalone)
	if entity.get("status") == "resolved":
		var find: Dictionary = trail.finds.get(str(entity.get("selected_option", "")), {})
		copy += "\n\n已记下 · %s\n%s\n\n%s" % [trail.evidence, trail.clue, find.get("outcome", "")]
		if complete(run): copy += "\n\n" + conclusion(run)
	else:
		copy += "\n\n选择任一遗物后，都会将这里的证据记入「记录 / 行囊·旅途拾遗」。暂时离开会保留现场。"
	result.description = copy
	return result

static func knight_memory(run: Dictionary) -> String:
	var definitions: Dictionary = run.get("ruin_definitions_snapshot", {})
	if definitions.get(IDS[0], {}).get("trail", {}).has("story_id"):
		if complete(run): return str(definitions[IDS[2]].trail.knight_memory)
		for id in [IDS[1], IDS[0]]:
			if has_evidence(run, id): return str(definitions[id].trail.knight_memory)
		if has_evidence(run, IDS[2]): return "这件遗物背后还有一段没查清的路。二层与六层若还留着同样的记号，把它们一并带来，我不想只凭最后一页就替人下结论。"
		return ""
	if complete(run):
		return "铜牌上的名字是伊蕾。那趟旧远征，她替我们守住最后一处火，我与你母亲才得以带灯离开。她没回来。新订单上的王印，我认得；但后来是谁借了她的路，还得由你查清。你母亲坚持留下副芯，就是不肯让一句王命抹掉这些名字。"
	if has_evidence(run, "p3_oath_forge"):
		return "那张油纸是伊蕾行囊的内衬，旧灯纹是我们同行时刻的；蜡封订单却是后来塞进去的。两趟入塔的人走了同一条路，目的未必相同。去九层找她没能带回的灯芯匣。"
	if has_evidence(run, "p3_oath_ruin"):
		return "这块铜牌……伊蕾曾和我同行。她把缺角剑留下给后来的人。六层兵库里若还有她的行囊，替我看看。别急着把所有留下的东西都当成战利品。"
	return ""
