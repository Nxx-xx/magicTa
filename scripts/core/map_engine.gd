class_name MapEngine
extends RefCounted
## Two-floor vertical slice with template-based, persistent random maps.
## UI may inspect all cells, but only this class changes the player's resources.

const DB = preload("res://scripts/core/content_db.gd")
const Combat = preload("res://scripts/core/combat.gd")
const MapStore = preload("res://scripts/core/map_save.gd")
const Generator = preload("res://scripts/core/map_generator.gd")
const Keys = preload("res://scripts/core/map_keys.gd")
const Rewards = preload("res://scripts/core/rewards.gd")
const SAVE_PATH := "user://tower_map_save.json"
const SIZE := 11
const THEMES := ["battle", "treasure", "shop"]
signal chest_collected(receipt: Dictionary)
var db = DB.new()
var generator = Generator.new()
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
	errors.append_array(generator.errors)
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
		Keys.ensure_inventory(state.player)
		for category in state.get("reward_content", {}):
			db.data[category] = state.reward_content[category].duplicate(true)
		rng.seed = str(state.seed).to_int()
		rng.state = str(state.rng_state).to_int()

func start(seed_text: String = "", random_maps: bool = true) -> String:
	if not errors.is_empty():
		return "\n".join(errors)
	var seed_value: int
	if seed_text.strip_edges().is_empty():
		var seed_rng := RandomNumberGenerator.new()
		seed_rng.randomize()
		seed_value = int(seed_rng.randi())
	else:
		seed_value = seed_text.to_int() if seed_text.is_valid_int() else seed_text.hash()
	var first: Dictionary
	if random_maps:
		first = generator.generate(str(seed_value), 1, "entrance")
		if first.is_empty():
			return generator.last_error
		rng.seed = seed_value
	else:
		# Kept for existing hand-built saves and their regression test fixtures.
		rng.seed = seed_value
		first = _legacy_generate_floor(1, "entrance")
	# Only change the loaded catalog after generation succeeds.
	db = DB.new()
	state = {
		"mode": "grid_prototype_v1", "seed": str(seed_value), "rng_state": str(rng.state),
		"generator_version": Generator.VERSION if random_maps else 0,
		"reward_rules_version": 1, "reward_content": {
			"items": db.data.items.duplicate(true), "shop": db.data.shop.duplicate(true),
			"events": db.data.events.duplicate(true)},
		"floor": 1, "position": first.entry.duplicate(), "floors": {}, "pending": {},
		"player": {"hp": 100, "max_hp": 100, "attack": 10, "defense": 5,
			"gold": 0, "keys": 0, "silver_keys": 0, "gold_keys": 0,
			"equipment_ids": [], "relic_ids": []},
		"completed": false, "objective_complete": false, "summit_seen": false,
		"last_report": {}, "last_message": "先绕过支路强敌，上二层寻找装备，再回来挑战。"
	}
	state.floors["1"] = first
	save_game()
	return ""

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
			state.pending = {"kind": "stairs", "pos": [cell.x, cell.y], "destination": int(state.floor) + 1}
		"down":
			state.pending = {"kind": "stairs", "pos": [cell.x, cell.y], "destination": int(state.floor) - 1}
		"potion":
			_move_to(cell)
			if int(state.player.hp) < int(stats().max_hp):
				state.pending = {"kind": "entity", "pos": [cell.x, cell.y]}
			else:
				state.last_message = "当前已满血，药剂留在原地，可稍后回来使用。"
		"choice", "event", "rest":
			_move_to(cell)
			state.pending = {"kind": "entity", "pos": [cell.x, cell.y]}
		"gold", "key", "chest":
			var error := _collect(cell, entity)
			if not error.is_empty():
				return error
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
		if not state.floors.has(str(int(state.pending.destination))):
			return enter_next_floor()
		return _travel(int(state.pending.destination))
	if state.pending.kind == "floor_choice":
		return enter_next_floor()
	if state.pending.kind != "entity":
		return "没有可确认的交互。"
	var cell := pending_cell()
	var entity := entity_at(cell)
	match str(entity.get("type", "")):
		"potion":
			if int(state.player.hp) >= int(stats().max_hp):
				return "当前已满血，药剂仍保留在原地。"
			var error := _collect(cell, entity)
			if not error.is_empty():
				return error
		"door":
			var key_kind := Keys.kind(entity)
			if key_kind not in Keys.TYPES:
				return "未知的门类型。"
			if Keys.count(state.player, key_kind) < int(entity.cost):
				return "%s不足，需要同类型钥匙，可以稍后回来。" % Keys.key_name(key_kind)
			state.player[Keys.FIELDS[key_kind]] -= int(entity.cost)
			floor_data().entities.erase(cell_key(cell))
			state.last_message = "消耗 %d 把%s，%s已永久打开。" % [int(entity.cost), Keys.key_name(key_kind), Keys.door_name(key_kind)]
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

func automatic_floor_theme(destination: int) -> String:
	# Independent of gameplay RNG: cancelling, saving and backtracking cannot reroll it.
	return THEMES[(str(state.seed) + ":floor-theme:" + str(destination)).hash() % THEMES.size()]

func enter_next_floor() -> String:
	if not active() or state.pending.get("kind", "") not in ["stairs", "floor_choice"]:
		return "请先到达上行楼梯。"
	var previous: Dictionary = state.pending.duplicate(true)
	state.pending.kind = "floor_choice"
	var error := choose_floor(automatic_floor_theme(int(state.floor) + 1))
	if not error.is_empty():
		state.pending = previous
	return error

func choose_floor(theme_id: String) -> String:
	if not active() or state.pending.get("kind", "") != "floor_choice":
		return "请先到达上行楼梯。"
	if theme_id not in THEMES or int(state.floor) != 1 or state.floors.has("2"):
		return "本层类型已经确定，不能重新生成。"
	var generated := _generate_floor(2, theme_id)
	if generated.is_empty():
		return generator.last_error
	state.floors["2"] = generated
	return _travel(2)

func floor_choices() -> Dictionary:
	return generator.config.themes if int(state.get("generator_version", 0)) > 0 else layouts.themes

func shop_offer(id: String) -> Dictionary:
	var offer: Dictionary = db.shop_item(id)
	if int(offer.get("effects", {}).get("keys", 0)) > 0:
		offer.name = "铜钥匙"
		offer.description = "铜钥匙 +%d，仅开启铜门" % int(offer.effects.keys)
	return offer

func shop_preview(id: String) -> Dictionary:
	var offer := shop_offer(id)
	if offer.is_empty():
		return {"ok": false, "error": "未知商品。"}
	var reward := offer.duplicate(true)
	reward.cost = {"gold": offer.price}
	var result := Rewards.resolve(db, state.player, reward)
	if result.ok and offer.get("effects", {}).has("heal") and int(result.healing) == 0:
		return {"ok": false, "error": "当前已满血，无需购买治疗。"}
	return result

func reward_options(entity: Dictionary) -> Array:
	match str(entity.get("type", "")):
		"choice":
			var options: Array = []
			for id in entity.get("choices", []):
				var item: Dictionary = db.item(str(id))
				options.append({"name": item.get("name", "未知物品"), "description": item.get("description", ""),
					"item_id": id, "effects": {"gold": int(entity.get("gold", 0))}})
			return options
		"event":
			return db.event(str(entity.get("event_id", ""))).get("options", [])
		"rest":
			return entity.get("options", [])
	return []

func choose_reward(index: int) -> String:
	if not active() or state.pending.get("kind", "") != "entity":
		return "没有待领取的奖励。"
	var cell := pending_cell()
	var entity := entity_at(cell)
	var options := reward_options(entity)
	if index < 0 or index >= options.size():
		return "无效奖励选择。"
	var result := Rewards.resolve(db, state.player, options[index])
	if not result.ok:
		return result.error
	state.player = result.player
	state.last_message = "选择「%s」。%s" % [options[index].name, Rewards.summary(result)]
	floor_data().entities.erase(cell_key(cell))
	state.pending = {}
	save_game()
	return ""

func shop_offer_sold(entity: Dictionary, offer_id: String) -> bool:
	# Old saves only recorded whole-shop closure; preserve that exhausted stock.
	if not entity.has("purchased_ids"):
		return bool(entity.get("purchased", false))
	return offer_id in entity.purchased_ids

func _mark_shop_purchase(entity: Dictionary, offer_id: String) -> void:
	if not entity.has("purchased_ids"):
		entity.purchased_ids = []
	entity.purchased_ids.append(offer_id)
	entity.purchased_id = offer_id
	entity.purchased = entity.purchased_ids.size() == entity.offers.size()

func buy(index: int) -> String:
	if not active() or state.pending.get("kind", "") != "entity":
		return "请先靠近商人。"
	var entity := entity_at(pending_cell())
	if entity.get("type", "") != "shop" or entity.get("purchased", false):
		return "这位商人本局的交易已经结束。"
	if index < 0 or index >= entity.offers.size():
		return "无效商品。"
	if shop_offer_sold(entity, str(entity.offers[index])):
		return "这件商品已售罄。"
	var offer: Dictionary = shop_offer(str(entity.offers[index]))
	var result := shop_preview(str(entity.offers[index]))
	if not result.ok:
		return result.error
	state.player = result.player
	_mark_shop_purchase(entity, str(entity.offers[index]))
	state.last_message = "购买了 %s。%s" % [offer.name, "商品已全部售罄。" if entity.purchased else "还可以继续选购其他商品。"]
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

func collection_reward(entity: Dictionary) -> Dictionary:
	match str(entity.get("type", "")):
		"gold":
			return {"effects": {"gold": entity.amount}}
		"key":
			var key_kind := Keys.kind(entity)
			if key_kind not in Keys.TYPES:
				return {"item_id": "invalid_key"}
			return {"effects": {str(Keys.FIELDS[key_kind]): entity.amount}}
		"potion":
			return {"effects": {"heal": entity.amount}}
		"chest":
			return {"item_id": entity.item_id, "effects": {"gold": entity.gold}}
	return {"item_id": "invalid_reward"}

func _collect(cell: Vector2i, entity: Dictionary) -> String:
	var result := Rewards.resolve(db, state.player, collection_reward(entity))
	if not result.ok:
		return result.error
	state.player = result.player
	match str(entity.type):
		"gold":
			state.last_message = "获得 %d 金币。" % int(entity.amount)
		"key":
			var key_kind := Keys.kind(entity)
			state.last_message = "获得 %d 把%s。" % [int(entity.amount), Keys.key_name(key_kind)]
		"potion":
			state.last_message = "恢复 %d HP，溢出 %d HP，药剂已消耗。" % [result.healing, result.overflow]
		"chest":
			state.last_message = "获得 %s（%s），金币 +%d。" % [db.item(entity.item_id).name, db.item(entity.item_id).description, entity.gold]
			if bool(entity.get("objective", false)):
				state.objective_complete = true
				state.last_message = "回溯试炼完成！你绕过强敌、上楼变强，回头拿到了王权指环。仍可继续探索。"
	floor_data().entities.erase(cell_key(cell))
	if entity.type == "chest":
		# Presentation waits for save success before showing this receipt.
		chest_collected.emit({"item_id":str(entity.item_id), "gold":int(result.gold_delta)})
	return ""

func _grant_item(id: String) -> void:
	var result := Rewards.resolve(db, state.player, {"item_id": id})
	if result.ok:
		state.player = result.player

func _apply_effects(effects: Dictionary) -> void:
	var result := Rewards.resolve(db, state.player, {"effects": effects})
	if result.ok:
		state.player = result.player

func _generate_floor(number: int, theme_id: String) -> Dictionary:
	var version := int(state.get("generator_version", 0))
	if version in Generator.SUPPORTED_VERSIONS:
		return generator.generate(str(state.seed), number, theme_id, version)
	if version != 0:
		generator.last_error = "存档使用了不同版本的地图生成器，现有地图仍可探索。"
		return {}
	return _legacy_generate_floor(number, theme_id)

func _legacy_generate_floor(number: int, theme_id: String) -> Dictionary:
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
