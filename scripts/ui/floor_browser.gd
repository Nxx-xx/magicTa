extends "res://scripts/ui/paged_catalog.gd"
const Board = preload("res://scripts/ui/grid_board.gd")
var host

func setup(ui) -> void:
	host = ui
	_ensure_ui()
	show_overview()

func show_overview() -> void:
	_clear()
	_selected = ""
	_label(_content, "选择楼层查看地图与目标 · 沿楼梯往返", 14, Color("8fcbbd"))
	var grid := GridContainer.new()
	grid.columns = 2
	grid.add_theme_constant_override("h_separation", 8)
	grid.add_theme_constant_override("v_separation", 8)
	_content.add_child(grid)
	for number in range(1, 11 if host._is_campaign() else 3):
		var visited: bool = host.game.state.floors.has(str(number))
		var state := "当前" if number == int(host.game.state.floor) else ("已到达" if visited else "未到达")
		var button := _button(grid, "%02d 层 · %s" % [number,state], func(): _show_floor(number))
		button.name = "Floor_%d" % number
		button.disabled = not visited
		if number == int(host.game.state.floor): button.theme_type_variation = "PrimaryButton"
		_buttons[str(number)] = button

func _show_floor(number: int) -> void:
	_clear()
	_selected = str(number)
	host.index_floor = number
	var floor_data: Dictionary = host.game.state.floors[str(number)]
	_label(_content, "%02d 层 · %s" % [number,floor_data.get("name", "魔塔")], 18, Color("e4c783"))
	var preview := Board.new()
	preview.name = "FloorMapPreview"
	preview.custom_minimum_size = Vector2(0,150)
	preview.size_flags_vertical = Control.SIZE_EXPAND_FILL
	_content.add_child(preview)
	preview.mouse_filter = Control.MOUSE_FILTER_IGNORE
	preview.setup(floor_data, host.game.position() if number == int(host.game.state.floor) else Vector2i(-5,-5), Vector2i(-1,-1), true, host.game.db.data.enemies)
	preview.marked_cells = host._floor_pins(number).keys()
	preview.set_overview(true)
	_button(_content, "查看剩余资源与标记目标", func(): _show_information(number))
	_button(_content, "‹  返回楼层总览", show_overview)

func _show_information(number: int) -> void:
	var floor_data: Dictionary = host.game.state.floors[str(number)]
	var counts := {"enemy":0,"reward":0,"rest":0,"shop":0,"sold":0}
	for entity in floor_data.entities.values():
		match str(entity.get("type", "")):
			"enemy": counts.enemy += 1
			"choice", "chest", "event": counts.reward += 1
			"rest": counts.rest += 1
			"shop":
				counts.shop += 1
				if entity.get("purchased", false): counts.sold += 1
	var detail := "未清守卫 %d · 待领 %d\n休息点剩余 %d\n商人 %d · 已售罄 %d\n" % [counts.enemy,counts.reward,counts.rest,counts.shop,counts.sold]
	var pins: Dictionary = host._floor_pins(number)
	for key in pins:
		var entity: Dictionary = floor_data.entities.get(key, {})
		var copy := "已完成" if entity.is_empty() else "尚未领取"
		if entity.get("type", "") == "enemy":
			var enemy: Dictionary = host.game.db.enemy(entity.enemy_id)
			copy = "生命 %d · 攻击 %d · 防御 %d" % [enemy.hp,enemy.attack,enemy.defense]
		detail += "\n%s (%s)\n%s\n" % [pins[key].get("name", "目标"),key,copy]
	if pins.is_empty(): detail += "\n尚未标记目标。在地图上查看目标时可以添加标记。"
	_entries = [{"id":str(number),"name":"第 %d 层 · 剩余目标" % number,"detail":detail,"readonly":true}]
	super._show_detail(str(number))
	var back := _content.get_child(_content.get_child_count() - 1) as Button
	back.text = "‹  返回本层地图"
	for connection in back.pressed.get_connections(): back.pressed.disconnect(connection.callable)
	back.pressed.connect(func(): _show_floor(number))

func back_to_overview() -> bool:
	if _selected.is_empty(): return false
	if is_instance_valid(_detail): _show_floor(int(_selected))
	else: show_overview()
	return true
