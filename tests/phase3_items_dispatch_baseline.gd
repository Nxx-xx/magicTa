extends SceneTree
## Capture BEFORE changing the dispatch entry points; never overwrite evidence.
const DB = preload("res://scripts/core/content_db.gd")
const Rewards = preload("res://scripts/core/rewards.gd")
const Combat = preload("res://scripts/core/combat.gd")
const OUTPUT := "res://build/verification/phase3/01-items/integration/legacy-before-dispatch.json"

func _initialize() -> void:
	if FileAccess.file_exists(OUTPUT):
		push_error("Baseline already exists; preserving pre-change evidence.")
		quit(1)
		return
	var db = DB.new()
	var records: Array = []
	var ids: Array = [""] + db.data.items.keys()
	for id in ids:
		for gold in [24, 25, 49, 50, 99, 100]:
			var player := {"hp": 57, "max_hp": 100, "attack": 15, "defense": 5, "gold": gold,
				"keys": 2, "silver_keys": 1, "gold_keys": 1, "equipment_ids": [], "relic_ids": []}
			if not str(id).is_empty():
				var collection := "equipment_ids" if db.item(id).kind == "equipment" else "relic_ids"
				player[collection] = [id, id]
			var stats: Dictionary = db.player_stats(player)
			var reward := {"cost": {"gold": 20}, "item_id": id} if not str(id).is_empty() else {"effects": {"max_hp": 20, "heal": 20}}
			var battles: Array = []
			for enemy_id in ["slime", "minotaur", "golem"]:
				var enemy: Dictionary = db.enemy(enemy_id)
				battles.append({"enemy": enemy, "expected": Combat.simulate(player, enemy, stats)})
			records.append({"player": player, "stats": stats, "reward": reward,
				"reward_result": Rewards.resolve(db, player, reward), "battles": battles})
	var hashes := {}
	for file in ["content_db", "rewards", "combat"]:
		hashes[file] = FileAccess.get_sha256("res://scripts/core/" + file + ".gd")
	FileAccess.open(OUTPUT, FileAccess.WRITE).store_string(JSON.stringify({"source_sha256": hashes, "records": records}, "  "))
	print("Recorded legacy baseline: ", records.size(), " player/reward fixtures; 414 complete battle logs.")
	quit()
