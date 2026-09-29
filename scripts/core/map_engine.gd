class_name MapEngine
extends RefCounted
## Two-floor vertical slice. Geometry is authored; theme contents roll once.
## UI may inspect all cells, but only this class changes the player's resources.

const DB = preload("res://scripts/core/content_db.gd")
const Combat = preload("res://scripts/core/combat.gd")
const MapStore = preload("res://scripts/core/map_save.gd")
const SAVE_PATH := "user://tower_map_save.json"
const SIZE := 11
const THEMES := ["battle", "treasure", "shop"]
var db = DB.new()
var rng := RandomNumberGenerator.new()
var store
var layouts: Dictionary = {}
var state: Dictionary = {}
var errors: Array[String] = []
var save_error := ""
var persistence_enabled := true

func _init(path: String = SAVE_PATH) -> void:
	store = MapStore.new(path)
	errors.assign(db.errors)
	var file := FileAccess.open("res://data/map_layouts.json", FileAccess.READ)
	if file == null:
		errors.append("无法读取地图布局。")
		return
	var value = JSON.parse_string(file.get_as_text())
	if not value is Dictionary or not value.has("themes"):
		errors.append("地图布局格式错误。")
		return
	layouts = value

func load_game() -> void:
	var saved: Dictionary = store.read()
	save_error = store.last_error
	if not saved.is_empty():
		state = saved.run
		rng.seed = str(state.seed).to_int()
		rng.state = str(state.rng_state).to_int()

func start(seed_text: String = "") -> void:
	if not errors.is_empty():
		return
	var seed_value: int
	if seed_text.strip_edges().is_empty():
		rng.randomize()
		seed_value = int(rng.randi())
	else:
		seed_value = seed_text.to_int() if seed_text.is_valid_int() else seed_text.hash()
	rng.seed = seed_value
	state = {
		"mode": "grid_prototype_v1", "seed": str(seed_value), "rng_state": str(rng.state),
		"floor": 1, "position": [1, 9], "floors": {}, "pending": {},
		"player": {"hp": 100, "max_hp": 100, "attack": 10, "defense": 5,
			"gold": 0, "keys": 0, "equipment_ids": [], "relic_ids": []},
		"completed": false, "objective_complete": false, "summit_seen": false,
		"last_report": {}, "last_message": "先绕过南侧强敌，上二层取补给，再回来挑战。"
	}
	state.floors["1"] = _generate_floor(1, "entrance")
	save_game()

func save_game() -> bool:
	if state.is_empty():
		return true
	state.rng_state = str(rng.state)
	if not persistence_enabled:
		return true
	var ok: bool = store.write(state, {})
	save_error = store.last_error
	return ok

func active() -> bool:
	return not state.is_empty() and not bool(state.completed)

func stats() -> Dictionary:
	return db.player_stats(state.player)

func floor_data() -> Dictionary:
	return state.floors[str(int(state.floor))]

func position() -> Vector2i:
	return Vector2i(int(state.position[0]), int(state.position[1]))

static func cell_key(cell: Vector2i) -> String:
	return "%d,%d" % [cell.x, cell.y]

func inside(cell: Vector2i) -> bool:
	return cell.x >= 0 and cell.y >= 0 and cell.x < SIZE and cell.y < SIZE

func is_wall(cell: Vector2i) -> bool:
	return not inside(cell) or str(floor_data().rows[cell.y]).substr(cell.x, 1) == "#"

func entity_at(cell: Vector2i) -> Dictionary:
	return floor_data().entities.get(cell_key(cell), {})

func preview(cell: Vector2i) -> Dictionary:
	var entity := entity_at(cell)
	if entity.get("type", "") == "enemy":
		return Combat.simulate(state.player, db.enemy(entity.enemy_id), stats())
	return {}

func step(direction: Vector2i) -> String:
	if absi(direction.x) + absi(direction.y) != 1:
		return "只能上下左右移动一格。"
	return interact(position() + direction)

func interact(cell: Vector2i) -> String:
	if not active():
		return "本次探索已经结束。"
	if not state.pending.is_empty():
		return "请先处理当前选择，或取消返回地图。"
	var delta := cell - position()
	if absi(delta.x) + absi(delta.y) > 1:
		return "距离太远，请逐格靠近。"
	if is_wall(cell):
		return "石墙挡住了去路。"
	var entity := entity_at(cell)
	if entity.is_empty():
		_move_to(cell)
		save_game()
		return ""
	match str(entity.type):
		"enemy", "door":
			state.pending = {"kind": "entity", "pos": [cell.x, cell.y]}
		"shop":
			state.pending = {"kind": "entity", "pos": [cell.x, cell.y]}
			_move_to(cell)
		"up":
			if state.floors.has(str(int(state.floor) + 1)):
				state.pending = {"kind": "stairs", "pos": [cell.x, cell.y], "destination": int(state.floor) + 1}
			else:
				state.pending = {"kind": "floor_choice", "pos": [cell.x, cell.y]}
		"down":
			state.pending = {"kind": "stairs", "pos": [cell.x, cell.y], "destination": int(state.floor) - 1}
		"gold", "key", "potion", "chest":
			_collect(cell, entity)
			_move_to(cell)
		"summit":
			state.summit_seen = true
			state.last_message = entity.description
			_move_to(cell)
		"camp":
			state.last_message = entity.description
			_move_to(cell)
	save_game()
	return ""

func pending_cell() -> Vector2i:
	var value: Array = state.pending.get("pos", state.position)
	return Vector2i(int(value[0]), int(value[1]))

func cancel_pending() -> void:
	state.pending = {}
	save_game()

func confirm_interaction(confirm_lethal: bool = false) -> String:
	if not active() or state.pending.is_empty():
		return "没有待确认的交互。"
	if state.pending.kind == "stairs":
		return _travel(int(state.pending.destination))
	if state.pending.kind != "entity":
		return "请先选择下一层类型。"
	var cell := pending_cell()
	var entity := entity_at(cell)
	match str(entity.get("type", "")):
		"door":
			if int(state.player.keys) < int(entity.cost):
				return "钥匙不足，可以先离开，找到钥匙后回来。"
			state.player.keys -= int(entity.cost)
			floor_data().entities.erase(cell_key(cell))
			state.last_message = "消耗 %d 把钥匙，门已永久打开。" % int(entity.cost)
			_move_to(cell)
		"enemy":
			var report := preview(cell)
			if report.lethal and not confirm_lethal:
				return "confirm_lethal"
			state.last_report = report
			state.player.hp = report.hp_after
			state.player.gold += report.gold_reward
			if report.won:
				floor_data().entities.erase(cell_key(cell))
				_move_to(cell)
				state.last_message = "击败 %s，净生命变化 %+d，金币 +%d。" % [db.enemy(entity.enemy_id).name, -int(report.loss), report.gold_reward]
			else:
				state.completed = true
				state.last_message = "你倒在了 %s 面前。可以重新开始地图试炼。" % db.enemy(entity.enemy_id).name
		_:
			return "此处没有可确认的战斗或门。"
	state.pending = {}
	save_game()
	return ""

func choose_floor(theme_id: String) -> String:
	if not active() or state.pending.get("kind", "") != "floor_choice":
		return "请先到达上行楼梯。"
	if theme_id not in THEMES or int(state.floor) != 1 or state.floors.has("2"):
		return "本层类型已经确定，不能重新生成。"
	state.floors["2"] = _generate_floor(2, theme_id)
	return _travel(2)

func buy(index: int) -> String:
	if not active() or state.pending.get("kind", "") != "entity":
		return "请先靠近商人。"
	var entity := entity_at(pending_cell())
	if entity.get("type", "") != "shop" or entity.get("purchased", false):
		return "这位商人本局的交易已经结束。"
	if index < 0 or index >= entity.offers.size():
		return "无效商品。"
	var offer: Dictionary = db.shop_item(entity.offers[index])
	if int(state.player.gold) < int(offer.price):
		return "金币不足，可以稍后回来购买。"
	state.player.gold -= int(offer.price)
	if offer.has("item_id"):
		_grant_item(str(offer.item_id))
	else:
		_apply_effects(offer.get("effects", {}))
	entity.purchased = true
	entity.purchased_id = str(entity.offers[index])
	state.last_message = "购买了 %s。这位商人本局不再补货。" % offer.name
	state.pending = {}
	save_game()
	return ""

func _travel(destination: int) -> String:
	if not state.floors.has(str(destination)) or absi(destination - int(state.floor)) != 1:
		return "楼梯没有连接到可进入的楼层。"
	var ascending := destination > int(state.floor)
	state.floor = destination
	state.position = floor_data().entry.duplicate() if ascending else floor_data().exit.duplicate()
	state.pending = {}
	state.last_message = "来到第 %d 层。楼层内容保持原样，可以继续探索。" % destination
	save_game()
	return ""

func _move_to(cell: Vector2i) -> void:
	state.position = [cell.x, cell.y]

func _collect(cell: Vector2i, entity: Dictionary) -> void:
	match str(entity.type):
		"gold":
			state.player.gold += int(entity.amount)
			state.last_message = "获得 %d 金币。" % int(entity.amount)
		"key":
			state.player.keys += int(entity.amount)
			state.last_message = "获得 %d 把通用钥匙。" % int(entity.amount)
		"potion":
			var before := int(state.player.hp)
			_apply_effects({"heal": int(entity.amount)})
			state.last_message = "恢复 %d HP，泉水或药剂已消耗。" % (int(state.player.hp) - before)
		"chest":
			_grant_item(str(entity.item_id))
			state.player.gold += int(entity.gold)
			state.last_message = "获得 %s（%s），金币 +%d。" % [db.item(entity.item_id).name, db.item(entity.item_id).description, entity.gold]
			if bool(entity.get("objective", false)):
				state.objective_complete = true
				state.last_message = "回溯试炼完成！你绕过强敌、上楼变强，回头拿到了王权指环。仍可继续探索。"
	floor_data().entities.erase(cell_key(cell))

func _grant_item(id: String) -> void:
	var item: Dictionary = db.item(id)
	var collection := "equipment_ids" if item.kind == "equipment" else "relic_ids"
	state.player[collection].append(id)
	_apply_effects({"heal": int(item.effects.get("max_hp", 0))})

func _apply_effects(effects: Dictionary) -> void:
	for key in ["attack", "defense", "max_hp", "gold", "keys"]:
		state.player[key] += int(effects.get(key, 0))
	state.player.hp = clampi(int(state.player.hp) + int(effects.get("heal", 0)), 0, int(stats().max_hp))

func _generate_floor(number: int, theme_id: String) -> Dictionary:
	var template: Dictionary = layouts["floor_%d" % number].duplicate(true)
	var entities: Array = template.entities
	if number == 2:
		entities.append_array(layouts.themes[theme_id].entities.duplicate(true))
		template.name = layouts.themes[theme_id].name + " · " + template.name
	var placed: Dictionary = {}
	for raw in entities:
		var entity: Dictionary = raw.duplicate(true)
		for pool in ["enemy_pool", "item_pool"]:
			if entity.has(pool):
				var options: Array = entity[pool]
				entity["enemy_id" if pool == "enemy_pool" else "item_id"] = options[rng.randi_range(0, options.size() - 1)]
				entity.erase(pool)
		placed["%d,%d" % [int(entity.pos[0]), int(entity.pos[1])]] = entity
	template.entities = placed
	template.theme = theme_id
	template.floor = number
	return template
