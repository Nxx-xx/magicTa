extends "res://scripts/ui/action_choices.gd"
## Projects precomputed transactions; inspection never owns player or save state.
var _model: Dictionary = {}

func present(ruin: Dictionary, previews: Dictionary, state: Dictionary = {}, comparisons: Dictionary = {}) -> void:
	intro_title = "遗留线索" if ruin.has("trail") else "背景与规则"
	intro_button_text = "阅读遗留线索  ›" if ruin.has("trail") else "查看背景与规则  ›"
	_model = {"ruin":ruin.duplicate(true),"previews":previews.duplicate(true),"state":state.duplicate(true)}
	var entries: Array = []
	var resolved: bool = state.get("status") == "resolved"
	for option in ruin.get("options", []):
		var id := str(option.id)
		if id == "leave": continue
		var preview: Dictionary = previews.get(id, {"ok":false,"error":"预览尚未就绪。"})
		var unavailable: bool = resolved or not preview.get("ok", false)
		var status := "本局已选择，不能再次领取。" if resolved else str(preview.get("error", "无法选择。"))
		var detail := str(option.get("description", "")) + "\n\n" + (status if unavailable else _summary(preview))
		var trail: Dictionary = ruin.get("trail", {})
		if not trail.is_empty():
			var find: Dictionary = trail.get("finds", {}).get(id, {})
			detail += "\n\n遗留之物 · %s\n%s" % [find.get("name", ""), find.get("outcome", "")]
			if resolved and state.get("selected_option") == id:
				detail += "\n\n这是你本局取用的遗物。\n" + str(trail.get("clue", ""))
			elif resolved:
				detail += "\n\n你未取用此物；以上为当时可选的用途。"
		var comparison: Dictionary = comparisons.get(id, {})
		if comparison.get("discovered", false): detail += "\n\n" + str(comparison.get("text", ""))
		var brief := str(option.get("description", "")).split("。")[0].replace("基础", "").replace("当前", "")
		if unavailable: brief = "已耗尽 · 可查看详情" if resolved else "暂不可用 · 查看原因"
		entries.append({"id":id, "name":option.name, "icon":"lamp" if id == "guard" else ActionIcon.for_reward(option),
			"brief":brief, "detail":detail, "disabled":unavailable, "action":"已耗尽" if resolved else ("暂不可用" if unavailable else "选择此项")})
	var hint := "已耗尽 · 可查看各项详情" if resolved else "三选一 · 点击图标查看代价与收益"
	if ruin.has("trail"): hint = str(ruin.trail.title) + (" · 已留存线索" if resolved else " · 调查遗物")
	present_choices(entries, str(ruin.get("description", "")), hint)

func _summary(result: Dictionary) -> String:
	if not result.get("player") is Dictionary or not result.get("after") is Dictionary:
		return "等待完整的交易预览。"
	var player: Dictionary = result.player
	var after: Dictionary = result.after
	var text := "选择后 HP %d/%d\n攻击 %d · 防御 %d · 金币 %d" % [
		int(player.get("hp",0)),int(after.get("max_hp",0)),int(after.get("attack",0)),
		int(after.get("defense",0)),int(player.get("gold",0))]
	if int(result.get("max_hp_delta",0)) < 0:
		text += "\n本次生命变化 %d（不治疗）" % int(result.get("hp_delta",0))
	if int(result.get("healing",0)) > 0 or int(result.get("overflow",0)) > 0:
		text += "\n有效治疗 %d · 溢出 %d" % [int(result.get("healing",0)),int(result.get("overflow",0))]
	return text
