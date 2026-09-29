class_name RunEngine
extends RefCounted

const DB = preload("res://scripts/core/content_db.gd")
const Combat = preload("res://scripts/core/combat.gd")
const Store = preload("res://scripts/core/save_store.gd")
const UPGRADE_CAP := 3
const UPGRADE_NAMES := {"hp": "生命火种", "attack": "锋芒火种", "gold": "财富火种"}

var db = DB.new()
var store
var rng := RandomNumberGenerator.new()
var run: Dictionary = {}
var meta: Dictionary = {
	"souls": 0, "upgrades": {"hp": 0, "attack": 0, "gold": 0},
	"runs": 0, "wins": 0, "best_floor": 0, "records": []
}
var message := ""
var persistence_enabled := true
var _last_tick := 0

func _init(save_path: String = Store.DEFAULT_PATH) -> void:
	store = Store.new(save_path)

func load_game() -> void:
	var loaded: Dictionary = store.read()
	message = store.last_error
	if not loaded.is_empty():
		run = loaded.run
		meta.merge(loaded.meta, true)
		if not run.is_empty():
			rng.seed = str(run.seed).to_int()
			rng.state = str(run.rng_state).to_int()
	_last_tick = Time.get_ticks_msec()

func active() -> bool:
	return not run.is_empty() and not bool(run.completed)

func stats() -> Dictionary:
	return db.player_stats(run.player)

func start(seed_text: String = "") -> void:
	var seed_value: int
	if seed_text.strip_edges().is_empty():
		rng.randomize()
		seed_value = int(rng.randi())
	elif seed_text.is_valid_int():
		seed_value = seed_text.to_int()
	else:
		seed_value = seed_text.hash()
	message = ""
	rng.seed = seed_value
	run = {
		"seed": str(seed_value), "rng_state": str(rng.state), "floor": 1,
		"player": {
			"hp": 100 + int(meta.upgrades.hp) * 5,
			"max_hp": 100 + int(meta.upgrades.hp) * 5,
			"attack": 10 + int(meta.upgrades.attack), "defense": 5,
			"gold": int(meta.upgrades.gold) * 5, "keys": 0,
			"equipment_ids": [], "relic_ids": []
		},
		"room_options": [], "phase": "rooms", "completed": false, "result": "",
		"selected_room": {}, "pending_choices": [], "history": [],
		"last_report": {}, "last_message": "火把已经点燃。选择第一扇门。",
		"kills": 0, "soul_reward": 0, "played_seconds": 0.0
	}
	_last_tick = Time.get_ticks_msec()
	_generate_floor()
	save_game()

func save_game() -> bool:
	if not run.is_empty():
		if active() and _last_tick > 0:
			run.played_seconds += float(Time.get_ticks_msec() - _last_tick) / 1000.0
		run.rng_state = str(rng.state)
	_last_tick = Time.get_ticks_msec()
	if not persistence_enabled:
		return true
	var success: bool = store.write(run, meta)
	if not success:
		message = store.last_error
	return success

func preview(room: Dictionary) -> Dictionary:
	if str(room.type) in ["normal", "elite", "boss"]:
		return Combat.simulate(run.player, db.enemy(room.enemy_id), stats())
	return {}

func enter_room(index: int, confirm_lethal: bool = false) -> String:
	if not active() or run.phase != "rooms":
		return "当前不能选择房间。"
	if index < 0 or index >= run.room_options.size():
		return "无效房间。"
	var room: Dictionary = run.room_options[index].duplicate(true)
	if int(run.player.keys) < int(room.lock_cost):
		return "钥匙不足。"
	var report := preview(room)
	if not report.is_empty() and report.lethal and not confirm_lethal:
		return "confirm_lethal"
	run.selected_room = room
	run.room_options = []
	run.player.keys -= int(room.lock_cost)
	if not report.is_empty():
		run.last_report = report
		run.player.hp = report.hp_after
		run.player.gold += report.gold_reward
		if not report.won:
			_record("在 %s 面前倒下" % db.enemy(room.enemy_id).name, report)
			_finish("death")
			return ""
		run.kills += 1
		run.last_message = "击败 %s，获得 %d 金币。" % [db.enemy(room.enemy_id).name, report.gold_reward]
		if room.type == "elite" or (room.type == "boss" and int(run.floor) == 5):
			run.pending_choices = room.rewards.duplicate()
			run.phase = "reward"
			if room.type == "boss":
				_apply_effects({"heal": 45})
				run.last_message += " 守卫的泉水恢复了至多 45 HP。"
			save_game()
		else:
			_complete_floor(run.last_message)
	elif room.type == "chest":
		_apply_effects({"gold": int(room.get("gold", 0))})
		if not str(room.get("item_id", "")).is_empty():
			_grant_item(room.item_id)
		_complete_floor("打开宝箱：" + room.reward_text)
	else:
		run.phase = room.type
		run.last_message = "已进入 %s。本层选择已锁定。" % room.name
		save_game()
	return ""

func choose_reward(index: int) -> String:
	if not active() or run.phase != "reward" or index < 0 or index >= run.pending_choices.size():
		return "无效奖励。"
	var id := str(run.pending_choices[index])
	_grant_item(id)
	run.pending_choices = []
	_complete_floor(run.last_message + " 获得「%s」。" % db.item(id).name)
	return ""

func buy(index: int) -> String:
	if not active() or run.phase != "shop":
		return "当前不在商店。"
	var offers: Array = run.selected_room.offers
	if index < 0 or index >= offers.size():
		return "无效商品。"
	var offer: Dictionary = db.shop_item(offers[index])
	if int(run.player.gold) < int(offer.price):
		return "金币不足。"
	run.player.gold -= int(offer.price)
	if offer.has("item_id"):
		_grant_item(offer.item_id)
	else:
		_apply_effects(offer.get("effects", {}))
	_complete_floor("花费 %d 金币购买「%s」。" % [offer.price, offer.name])
	return ""

func leave_shop() -> void:
	if active() and run.phase == "shop":
		_complete_floor("离开商店，保留金币。")

func available_options() -> Array:
	if run.phase == "event":
		return db.event(run.selected_room.event_id).options
	if run.phase == "rest":
		return [
			{"name": "休息", "description": "恢复 40 HP", "effects": {"heal": 40}},
			{"name": "磨砺", "description": "攻击 +3，防御 +1", "effects": {"attack": 3, "defense": 1}}
		]
	return []

func option_blocked(option: Dictionary) -> String:
	var cost: Dictionary = option.get("cost", {})
	if int(run.player.hp) <= int(cost.get("hp", 0)):
		return "生命不足，需保留至少 1 HP"
	if int(run.player.gold) < int(cost.get("gold", 0)):
		return "金币不足"
	if int(run.player.keys) < int(cost.get("keys", 0)):
		return "钥匙不足"
	return ""

func choose_option(index: int) -> String:
	if not active() or run.phase not in ["event", "rest"]:
		return "当前没有可选事件。"
	var options := available_options()
	if index < 0 or index >= options.size():
		return "无效选项。"
	var option: Dictionary = options[index]
	var blocked := option_blocked(option)
	if not blocked.is_empty():
		return blocked
	for key in ["hp", "gold", "keys"]:
		run.player[key] -= int(option.get("cost", {}).get(key, 0))
	_apply_effects(option.get("effects", {}))
	if option.has("item_id"):
		_grant_item(option.item_id)
	_complete_floor("%s · %s" % [option.name, option.description])
	return ""

func upgrade_cost(id: String) -> int:
	return 8 + int(meta.upgrades.get(id, 0)) * 8

func upgrade(id: String) -> String:
	if active():
		return "请在本局结束后升级火种。"
	if not meta.upgrades.has(id) or int(meta.upgrades[id]) >= UPGRADE_CAP:
		return "已达升级上限。"
	var price := upgrade_cost(id)
	if int(meta.souls) < price:
		return "灵魂不足。"
	meta.souls -= price
	meta.upgrades[id] += 1
	save_game()
	return ""

func abandon() -> void:
	if active():
		_finish("abandoned")

func _grant_item(id: String) -> void:
	var item: Dictionary = db.item(id)
	if item.is_empty():
		return
	var collection := "equipment_ids" if item.kind == "equipment" else "relic_ids"
	run.player[collection].append(id)
	# No equipment slots: every copy stacks. A max-HP item also heals its increment.
	_apply_effects({"heal": int(item.effects.get("max_hp", 0))})

func _apply_effects(effects: Dictionary) -> void:
	for key in ["attack", "defense", "max_hp", "gold", "keys"]:
		run.player[key] += int(effects.get(key, 0))
	run.player.hp = clampi(int(run.player.hp) + int(effects.get("heal", 0)), 0, int(stats().max_hp))

func _pick(values: Array) -> Variant:
	return values[rng.randi_range(0, values.size() - 1)]

func _sample(values: Array, count: int) -> Array:
	var pool := values.duplicate()
	var result: Array = []
	while not pool.is_empty() and result.size() < count:
		var index := rng.randi_range(0, pool.size() - 1)
		result.append(pool.pop_at(index))
	return result

func _generate_floor() -> void:
	var floor_number := int(run.floor)
	run.phase = "rooms"
	run.selected_room = {}
	run.pending_choices = []
	if floor_number in [5, 10]:
		var enemy_id := "minotaur" if floor_number == 5 else "golem"
		var rewards: Array = ["dawn_spear", "obsidian_mail"] if floor_number == 5 else []
		run.room_options = [{"id": "%d_boss" % floor_number, "floor": floor_number,
			"type": "boss", "name": "封印之门", "enemy_id": enemy_id,
			"reward_pool_id": "boss", "event_id": "", "lock_cost": 0, "rewards": rewards}]
		return
	var pool: Dictionary = db.data.floor_pools[str(floor_number)]
	var combat_kind := "normal"
	if floor_number in [4, 9] or (floor_number >= 6 and rng.randf() < 0.35):
		combat_kind = "elite"
	var supply_kind: String = str(_pick(["chest", "rest"]))
	if floor_number in [3, 8]:
		supply_kind = "shop"
	var kinds: Array = _sample([combat_kind, supply_kind, "event"], 3)
	run.room_options = []
	for index in kinds.size():
		var kind := str(kinds[index])
		var room := {"id": "%d_%d" % [floor_number, index], "floor": floor_number,
			"type": kind, "name": "", "enemy_id": "", "event_id": "",
			"reward_pool_id": "tier_%d" % int(pool.tier), "lock_cost": 0}
		match kind:
			"normal", "elite":
				room.enemy_id = _pick(pool[kind])
				room.name = "巡游之敌" if kind == "normal" else "精英据点"
				room.rewards = _sample(db.items_of_kind("relic", int(pool.tier)), 2) if kind == "elite" else []
			"chest":
				room.name = "遗落宝箱"
				room.lock_cost = 1 if floor_number > 2 and rng.randf() < 0.3 else 0
				room.item_id = str(_pick(db.items_of_kind("equipment", int(pool.tier))))
				room.gold = 20 if int(room.lock_cost) > 0 else 0
				if int(room.lock_cost) == 0 and rng.randf() < 0.2:
					room.item_id = ""
					room.gold = 25 + floor_number * 3
				room.reward_text = "金币 +%d" % int(room.gold) if room.item_id == "" else "%s · %s" % [db.item(room.item_id).name, db.item(room.item_id).description]
				if room.item_id != "" and int(room.gold) > 0:
					room.reward_text += "，金币 +%d" % int(room.gold)
			"shop":
				room.name = "烛火商店"
				var offers: Array = []
				for id in db.data.shop:
					if int(db.data.shop[id].min_floor) <= floor_number:
						offers.append(id)
				offers.sort()
				room.offers = _sample(offers, 3)
			"event":
				room.event_id = _pick(pool.events)
				room.name = db.event(room.event_id).name
			"rest":
				room.name = "静谧营火"
		run.room_options.append(room)

func _record(summary: String, report: Dictionary = {}) -> void:
	run.history.append({"floor": run.floor, "room_type": run.selected_room.get("type", ""),
		"room_id": run.selected_room.get("id", ""), "summary": summary,
		"hp": run.player.hp, "gold": run.player.gold, "stats": stats(),
		"combat_loss": report.get("loss", 0)})

func _complete_floor(summary: String) -> void:
	run.last_message = summary
	_record(summary, run.last_report if run.selected_room.type in ["normal", "elite", "boss"] else {})
	if int(run.floor) == 10:
		_finish("victory")
		return
	run.floor += 1
	_generate_floor()
	save_game()

func _finish(result: String) -> void:
	if not active():
		return
	if _last_tick > 0:
		run.played_seconds += float(Time.get_ticks_msec() - _last_tick) / 1000.0
	_last_tick = Time.get_ticks_msec()
	run.completed = true
	run.result = result
	run.phase = "ended"
	var souls := 0 if result == "abandoned" else maxi(1, (int(run.floor) - 1) * 2 + int(run.kills))
	if result == "victory":
		souls += 20
		meta.wins += 1
	run.soul_reward = souls
	meta.souls += souls
	meta.runs += 1
	meta.best_floor = maxi(int(meta.best_floor), int(run.floor))
	meta.records.append({"seed": run.seed, "result": result, "floor": run.floor,
		"souls": souls, "seconds": run.played_seconds, "history": run.history.duplicate(true)})
	if meta.records.size() > 30:
		meta.records.pop_front()
	save_game()
