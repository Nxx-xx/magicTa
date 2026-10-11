extends RefCounted
## Pure account-extension candidates. The host owns settlement, snapshots and disk transactions.
const CHALLENGES_PATH := "res://data/phase3_challenges.json"
const UNLOCKS_PATH := "res://data/phase3_unlocks.json"
const RUINS := ["p3_oath_ruin", "p3_oath_forge", "p3_lantern_sanctuary"]
const RUIN_OPTIONS := {"p3_oath_ruin": ["edge", "guard", "salvage", "leave"],
	"p3_oath_forge": ["temper", "sacrifice", "salvage", "leave"],
	"p3_lantern_sanctuary": ["restore", "ward", "reserve", "leave"]}
const LIST_FIELDS := ["seen_enemies", "seen_items", "obtained_items", "seen_ruins", "seen_story_nodes"]
const MAP_FIELDS := ["enemy_records", "item_records", "ruin_records"]
const MAX_VALUE := 1000000000

static func definitions() -> Dictionary:
	return {"challenges": _read(CHALLENGES_PATH), "unlocks": _read(UNLOCKS_PATH)}

static func _read(path: String) -> Dictionary:
	var parsed: Variant = JSON.parse_string(FileAccess.get_file_as_string(path))
	return parsed.duplicate(true) if parsed is Dictionary else {}

static func _defs(custom: Dictionary) -> Dictionary:
	return definitions() if custom.is_empty() else custom

static func default_extensions() -> Dictionary:
	return {"meta_schema_version": 2, "unlock_rules_version": 1,
		"unlocked_ids": ["p3_c0", "default"], "achievement_ids": [], "achievement_records": {},
		"phase3_settled_runs": {}, "phase3_codex_events": {}, "codex": {"seen_enemies": [], "seen_items": [],
		"obtained_items": [], "seen_ruins": [], "seen_story_nodes": [],
		"enemy_records": {}, "item_records": {}, "ruin_records": {}}}

static func migrate_meta(meta: Dictionary) -> Dictionary:
	var next := meta.duplicate(true)
	# Unknown versions are left intact so validation can reject without losing data.
	if meta.has("meta_schema_version") and meta.meta_schema_version not in [1, 2]:
		return next
	var legacy: bool = not meta.has("meta_schema_version") or meta.meta_schema_version == 1
	var defaults := default_extensions()
	for key in defaults:
		if not next.has(key):
			next[key] = defaults[key]
	if next.codex is Dictionary:
		for key in defaults.codex:
			if not next.codex.has(key):
				next.codex[key] = defaults.codex[key]
	next.meta_schema_version = 2
	if legacy and next.unlocked_ids is Array and next.achievement_ids is Array and next.achievement_records is Dictionary:
		var wins: Variant = meta.get("wins", 0)
		var milestones: Variant = meta.get("milestones", [])
		if (_integer(wins) and wins > 0) or (milestones is Array and "first_victory" in milestones):
			_append_unique(next.achievement_ids, "p3_c0_clear")
			for id in ["p3_c1", "p3_badge_bronze"]:
				_append_unique(next.unlocked_ids, id)
			if not next.achievement_records.has("p3_c0_clear"):
				next.achievement_records["p3_c0_clear"] = {"run_id": "", "completed_at": "", "source": "legacy_account"}
	return next

static func validate_meta_extensions(meta: Dictionary) -> Dictionary:
	if not _integer(meta.get("meta_schema_version"), 2, 2) or not _integer(meta.get("unlock_rules_version"), 1, 1):
		return _error("未知账户或解锁规则版本。")
	for key in ["unlocked_ids", "achievement_ids"]:
		if not _ids(meta.get(key)):
			return _error("无效账户列表：" + key)
	for key in ["achievement_records", "phase3_settled_runs", "phase3_codex_events", "codex"]:
		if not meta.get(key) is Dictionary:
			return _error("无效账户字典：" + key)
	if "p3_c0" not in meta.unlocked_ids or "default" not in meta.unlocked_ids:
		return _error("账户缺少基础起点或标准旅程。")
	for id in meta.phase3_settled_runs:
		if not _id(id) or meta.phase3_settled_runs[id] not in ["death", "victory", "abandoned"]:
			return _error("无效结算防重键。")
	for run_id in meta.phase3_codex_events:
		if not _id(run_id) or not meta.phase3_codex_events[run_id] is Dictionary:
			return _error("无效图鉴防重键。")
		for event_id in meta.phase3_codex_events[run_id]:
			var event: Variant = meta.phase3_codex_events[run_id][event_id]
			if not event is Dictionary or not _event_error(event).is_empty() or event.event_id != event_id:
				return _error("无效历史图鉴事件。")
	for id in meta.achievement_records:
		var record: Variant = meta.achievement_records[id]
		if not _id(id) or not record is Dictionary or not record.get("run_id") is String or not record.get("completed_at") is String:
			return _error("无效成就记录。")
	for key in LIST_FIELDS:
		if not _ids(meta.codex.get(key)):
			return _error("无效图鉴列表：" + key)
	for key in MAP_FIELDS:
		if not meta.codex.get(key) is Dictionary:
			return _error("无效图鉴字典：" + key)
	for key in meta.codex.enemy_records:
		var rec: Variant = meta.codex.enemy_records[key]
		if not rec is Dictionary or not _id(rec.get("enemy_id")) or not _integer(rec.get("combat_rules_version"), 1) or not _id(rec.get("challenge_id")) or not _integer(rec.get("count"), 1) or not _integer(rec.get("samples"), 0, int(rec.get("count", 0))):
			return _error("无效守卫纪录。")
		if (rec.samples == 0 and rec.get("min_incoming") != null) or (rec.samples > 0 and not _integer(rec.get("min_incoming"))):
			return _error("无效受伤样本。")
		if key != _enemy_key(rec.enemy_id, int(rec.combat_rules_version), rec.challenge_id):
			return _error("守卫纪录分组不匹配。")
	for key in meta.codex.item_records:
		var rec: Variant = meta.codex.item_records[key]
		if not _id(key) or not rec is Dictionary or not _integer(rec.get("count"), 1) or not _ids(rec.get("sources")):
			return _error("无效藏品纪录。")
	for key in meta.codex.ruin_records:
		var rec: Variant = meta.codex.ruin_records[key]
		if key not in RUINS or not rec is Dictionary or not _ids(rec.get("options")) or not _integer(rec.get("count"), 1):
			return _error("无效遗迹纪录。")
		for option in rec.options:
			if option not in RUIN_OPTIONS[key] or option == "leave":
				return _error("无效历史遗迹选项。")
	return _ok()

static func initial_player(meta: Dictionary, config_id: String = "default", custom: Dictionary = {}) -> Dictionary:
	var account := migrate_meta(meta)
	var valid := validate_meta_extensions(account)
	if not valid.ok:
		return valid
	var configs: Dictionary = _defs(custom).get("challenges", {}).get("start_configs", {})
	if not configs.has(config_id):
		return _error("未知起始配置。")
	if config_id not in account.unlocked_ids:
		return _error("起始配置尚未解锁。")
	var levels: Variant = account.get("upgrades", {"hp": 0, "attack": 0, "gold": 0})
	if not levels is Dictionary:
		return _error("火种等级无效。")
	for key in ["hp", "attack", "gold"]:
		if not _integer(levels.get(key), 0, 3):
			return _error("火种等级无效。")
	var config: Dictionary = configs[config_id]
	for key in ["hp_delta", "attack_delta", "defense_delta", "gold_delta"]:
		if not _integer(config.get(key), -100, 100):
			return _error("起点差值无效。")
	var player := {"max_hp": 100 + int(config.hp_delta) + 5 * int(levels.hp),
		"attack": 10 + int(config.attack_delta) + int(levels.attack), "defense": 5 + int(config.defense_delta),
		"gold": int(config.gold_delta) + 5 * int(levels.gold), "keys": 0, "silver_keys": 0,
		"gold_keys": 0, "equipment_ids": [], "relic_ids": []}
	if player.max_hp < 1 or player.attack < 0 or player.defense < 0 or player.gold < 0:
		return _error("起点属性无效。")
	player.hp = player.max_hp
	return {"ok": true, "error": "", "player": player}

static func select_start(meta: Dictionary, challenge_id: String, config_id: String, custom: Dictionary = {}) -> Dictionary:
	var defs := _defs(custom)
	var initial := initial_player(meta, config_id, defs)
	if not initial.ok:
		return initial
	if not defs.challenges.challenges.has(challenge_id):
		return _error("未知挑战。")
	var account := migrate_meta(meta)
	if challenge_id not in account.unlocked_ids:
		return _error("挑战尚未解锁。")
	return {"ok": true, "error": "", "player": initial.player,
		"challenge_snapshot": defs.challenges.challenges[challenge_id].duplicate(true),
		"start_config_snapshot": defs.challenges.start_configs[config_id].duplicate(true),
		"unlocked_pool_snapshot": account.unlocked_ids.duplicate(), "challenge_rules_version": 1}

static func apply_challenge(content: Dictionary, challenge_id: String, custom: Dictionary = {}) -> Dictionary:
	var challenges: Dictionary = _defs(custom).get("challenges", {}).get("challenges", {})
	if not challenges.has(challenge_id):
		return _error("未知挑战。")
	if content.has("phase3_challenge_applied"):
		return _error("挑战只能对基线应用一次。")
	if not content.get("enemies") is Dictionary:
		return _error("缺少敌人基线。")
	var rule: Dictionary = challenges[challenge_id]
	for key in ["normal_hp_percent", "boss_hp_percent"]:
		if not _integer(rule.get(key), 1, 1000):
			return _error("挑战生命倍率无效。")
	for key in ["normal_attack", "boss_attack"]:
		if not _integer(rule.get(key), 0, 1000):
			return _error("挑战攻击增量无效。")
	var next := content.duplicate(true)
	for id in next.enemies:
		var enemy: Variant = next.enemies[id]
		if not enemy is Dictionary or enemy.get("rank", "") not in ["normal", "elite", "boss"]:
			return _error("敌人阶级无效。")
		if not _integer(enemy.get("hp"), 1, 1000000) or not _integer(enemy.get("attack"), 0, 1000000):
			return _error("敌人基线数值无效。")
		var boss: bool = enemy.rank == "boss"
		enemy.hp = ceili(float(int(enemy.hp) * int(rule.boss_hp_percent if boss else rule.normal_hp_percent)) / 100.0)
		enemy.attack = int(enemy.attack) + int(rule.boss_attack if boss else rule.normal_attack)
	next.phase3_challenge_applied = challenge_id
	return {"ok": true, "error": "", "content": next}

static func scale_heal(amount: int, source_kind: String, challenge_id: String) -> int:
	# -1 is an invalid-request sentinel. The fixed int contract cannot return an error Dictionary.
	if amount < 0 or amount > MAX_VALUE or challenge_id not in ["p3_c0", "p3_c1", "p3_c2"]:
		return -1
	if source_kind not in ["potion", "rest", "shop", "ruin", "kill", "max_hp", "event"]:
		return -1
	if amount > 0 and challenge_id == "p3_c2" and source_kind in ["potion", "rest"]:
		return maxi(1, floori(float(amount) * 0.8))
	return amount

static func settlement_guard(run: Dictionary, meta: Dictionary) -> Dictionary:
	# MUST run before legacy settle: its recent records alone cannot reject an old replay.
	var account := migrate_meta(meta)
	var valid := validate_meta_extensions(account)
	if not valid.ok:
		return valid
	if not _id(run.get("run_id")) or run.get("result", "") not in ["death", "victory", "abandoned"]:
		return _error("缺少唯一旅程 ID 或真实局末结果。")
	if account.phase3_settled_runs.has(run.run_id):
		if account.phase3_settled_runs[run.run_id] != run.result:
			return _error("已结算旅程不能改变结果。")
		return {"ok": true, "error": "", "already_settled": true}
	return {"ok": true, "error": "", "already_settled": false}

static func evaluate_unlocks(run: Dictionary, meta: Dictionary, custom: Dictionary = {}) -> Dictionary:
	var account := migrate_meta(meta)
	var valid := validate_meta_extensions(account)
	if not valid.ok:
		return valid
	var run_id: Variant = run.get("run_id")
	var result: Variant = run.get("result")
	if not _id(run_id) or result not in ["death", "victory", "abandoned"]:
		return _error("缺少唯一旅程 ID 或真实局末结果。")
	if account.phase3_settled_runs.has(run_id):
		if account.phase3_settled_runs[run_id] != result:
			return _error("已结算旅程不能改变结果。")
		return _candidate(account, [], [])
	# Legacy runs retain old semantics and cannot supply new-rule achievements.
	for key in ["combat_rules_version", "reward_rules_version"]:
		if not _integer(run.get(key, 1), 1, 2):
			return _error("未知旅程规则版本：" + key)
	if run.get("combat_rules_version", 1) != 2 or run.get("reward_rules_version", 1) != 2:
		return _candidate(account, [], [])
	if run.get("mode", "") != "tower_campaign_v1" or run.get("campaign_kind", "") != "tower_10f":
		return _error("第三阶段解锁仅用于正式十层旅程。")
	for key in ["challenge_snapshot", "start_config_snapshot", "meta_snapshot", "player", "floors"]:
		if run.has(key) and not run[key] is Dictionary:
			return _error("旅程字段必须是字典：" + key)
	var defs := _defs(custom)
	var challenge: Variant = run.get("challenge_id", run.get("challenge_snapshot", {}).get("id", ""))
	if not challenge is String or not defs.get("challenges", {}).get("challenges", {}).has(challenge):
		return _error("结算缺少有效挑战快照。")
	var metrics: Variant = run.get("metrics", {})
	var kills: Variant = run.get("defeated_entities", [])
	if not metrics is Dictionary or not kills is Array:
		return _error("结算证据结构无效。")
	for key in ["actual_kill_healing", "shop_gold_spent", "midboss_turns", "lowest_elite_incoming", "min_hp_in_combat"]:
		if metrics.has(key) and not _integer(metrics[key]):
			return _error("结算指标无效：" + key)
	var midboss := false
	var elite := false
	var short_duel := false
	var low_loss := false
	var seen := {}
	for kill in kills:
		if not kill is Dictionary or not _id(kill.get("id")) or not _id(kill.get("enemy_id")) or kill.get("rank", "") not in ["normal", "elite", "boss"]:
			return _error("击杀证据无效。")
		if seen.has(kill.id):
			return _error("击杀实体重复。")
		seen[kill.id] = true
		for key in ["incoming", "turns"]:
			if kill.has(key) and not _integer(kill[key], 1 if key == "turns" else 0):
				return _error("战报数值无效。")
		if kill.enemy_id == "minotaur" and kill.rank == "boss" and kill.get("floor", 0) == 5:
			midboss = true
			short_duel = kill.has("turns") and int(kill.turns) <= 6
		if kill.rank == "elite":
			elite = true
			low_loss = low_loss or (kill.has("incoming") and int(kill.incoming) <= 10)
		_append_unique(account.codex.seen_enemies, kill.enemy_id)
		_record_enemy(account.codex, kill, int(run.combat_rules_version), challenge)
	short_duel = short_duel or (midboss and metrics.has("midboss_turns") and int(metrics.midboss_turns) >= 1 and int(metrics.midboss_turns) <= 6)
	low_loss = low_loss or (elite and metrics.has("lowest_elite_incoming") and int(metrics.lowest_elite_incoming) <= 10)
	var event_ledger: Dictionary = account.phase3_codex_events.get(run_id, {})
	var discovery := _discover(account.codex, run.get("codex_events", []), event_ledger)
	if not discovery.ok:
		return discovery
	account.phase3_codex_events[run_id] = event_ledger
	var new_unlocks: Array = []
	var new_achievements: Array = []
	if result != "abandoned":
		var highest := _highest_floor(run)
		var gold: Variant = run.get("player", {}).get("gold", null)
		var passed := {
			"p3_first_midboss": midboss,
			"p3_sustain_20": metrics.has("actual_kill_healing") and int(metrics.actual_kill_healing) >= 20,
			"p3_shop_30": metrics.has("shop_gold_spent") and int(metrics.shop_gold_spent) >= 30,
			"p3_short_duel": short_duel, "p3_low_loss_elite": low_loss,
			"p3_reserve_100": _integer(gold) and gold >= 100 and highest >= 5,
			"p3_c0_clear": result == "victory" and challenge == "p3_c0",
			"p3_c1_clear": result == "victory" and challenge == "p3_c1",
			"p3_c2_clear": result == "victory" and challenge == "p3_c2",
			"p3_no_embers": result == "victory" and _zero_embers(run),
			"p3_three_ruins": result == "victory" and _three_ruins(run)}
		for id in passed:
			if not passed[id] or id in account.achievement_ids:
				continue
			var unlock: Variant = defs.get("unlocks", {}).get("unlocks", {}).get(id)
			if not unlock is Dictionary or not _ids(unlock.get("grants")):
				return _error("缺少冻结解锁定义：" + id)
			account.achievement_ids.append(id)
			new_achievements.append(id)
			account.achievement_records[id] = {"run_id": run_id, "completed_at": str(run.get("completed_at", "")), "source": "run"}
			for grant in unlock.grants:
				if grant not in account.unlocked_ids:
					account.unlocked_ids.append(grant)
					new_unlocks.append(grant)
	account.phase3_settled_runs[run_id] = result
	valid = validate_meta_extensions(account)
	if not valid.ok:
		return valid
	return _candidate(account, new_unlocks, new_achievements)

static func _zero_embers(run: Dictionary) -> bool:
	if run.get("start_config_snapshot", {}).get("id", "") != "default":
		return false
	var levels: Variant = run.get("meta_snapshot", {}).get("upgrades")
	if not levels is Dictionary:
		return false
	for key in ["hp", "attack", "gold"]:
		if not _integer(levels.get(key), 0, 0):
			return false
	return true

static func _three_ruins(run: Dictionary) -> bool:
	var used: Array = []
	for event in run.get("codex_events", []):
		if event.get("kind", "") == "ruin_choice" and event.get("option_id", "leave") != "leave" and event.get("id", "") in RUINS:
			_append_unique(used, event.id)
	return used.size() == 3

static func _highest_floor(run: Dictionary) -> int:
	var highest := 0
	for value in [run.get("floor", 0), run.get("highest_floor", 0)]:
		if _integer(value, 0, 10):
			highest = maxi(highest, int(value))
	for key in run.get("floors", {}):
		if str(key).is_valid_int() and int(key) <= 10:
			highest = maxi(highest, int(key))
	return highest

static func _record_enemy(codex: Dictionary, kill: Dictionary, version: int, challenge: String) -> void:
	var key := _enemy_key(kill.enemy_id, version, challenge)
	var rec: Dictionary = codex.enemy_records.get(key, {"enemy_id": kill.enemy_id, "combat_rules_version": version,
		"challenge_id": challenge, "count": 0, "samples": 0, "min_incoming": null})
	rec.count = int(rec.count) + 1
	if kill.has("incoming"):
		rec.min_incoming = int(kill.incoming) if rec.samples == 0 else mini(int(rec.min_incoming), int(kill.incoming))
		rec.samples = int(rec.samples) + 1
	codex.enemy_records[key] = rec

static func record_discoveries(meta: Dictionary, run_id: String, events: Array) -> Dictionary:
	# Supports discoveries during a run and story completion after settlement.
	# Commit the returned account with the corresponding run event in one transaction.
	var account := migrate_meta(meta)
	var valid := validate_meta_extensions(account)
	if not valid.ok:
		return valid
	if not _id(run_id):
		return _error("图鉴发现缺少旅程 ID。")
	var ledger: Dictionary = account.phase3_codex_events.get(run_id, {})
	valid = _discover(account.codex, events, ledger)
	if not valid.ok:
		return valid
	account.phase3_codex_events[run_id] = ledger
	valid = validate_meta_extensions(account)
	return {"ok": true, "error": "", "meta": account} if valid.ok else valid

static func _event_error(event: Dictionary) -> String:
	if not _id(event.get("id")) or not _id(event.get("event_id")):
		return "图鉴事件缺少稳定事件 ID。"
	match event.get("kind", ""):
		"enemy_seen", "item_seen": pass
		"item_obtained":
			if not _id(event.get("source")):
				return "获得藏品缺少来源。"
		"ruin_seen", "ruin_choice":
			if event.id not in RUINS:
				return "未知遗迹。"
			if event.kind == "ruin_choice" and event.get("option_id", "") not in RUIN_OPTIONS[event.id]:
				return "遗迹选项证据缺失。"
		"story_seen":
			if event.get("triggered", false) != true or event.get("status", "") not in ["completed", "skipped"]:
				return "剧情必须实际触发且观看或跳过后登记。"
		_: return "未知图鉴事件。"
	return ""

static func _discover(codex: Dictionary, events: Variant, seen: Dictionary) -> Dictionary:
	if not events is Array:
		return _error("图鉴事件必须是数组。")
	for event in events:
		if not event is Dictionary:
			return _error("图鉴事件必须是字典。")
		var message := _event_error(event)
		if not message.is_empty():
			return _error(message)
		if seen.has(event.event_id):
			if seen[event.event_id] != event:
				return _error("图鉴事件 ID 冲突。")
			continue
		seen[event.event_id] = event.duplicate(true)
		match event.get("kind", ""):
			"enemy_seen": _append_unique(codex.seen_enemies, event.id)
			"item_seen": _append_unique(codex.seen_items, event.id)
			"item_obtained":
				if not _id(event.get("source")):
					return _error("获得藏品缺少来源。")
				_append_unique(codex.seen_items, event.id)
				_append_unique(codex.obtained_items, event.id)
				var rec: Dictionary = codex.item_records.get(event.id, {"count": 0, "sources": []})
				rec.count = int(rec.count) + 1
				_append_unique(rec.sources, event.source)
				codex.item_records[event.id] = rec
			"ruin_seen", "ruin_choice":
				if event.id not in RUINS:
					return _error("未知遗迹。")
				_append_unique(codex.seen_ruins, event.id)
				if event.kind == "ruin_choice":
					if event.get("option_id", "") not in RUIN_OPTIONS[event.id]:
						return _error("遗迹选项证据缺失。")
					if event.option_id == "leave":
						continue
					var rec: Dictionary = codex.ruin_records.get(event.id, {"count": 0, "options": []})
					rec.count = int(rec.count) + 1
					_append_unique(rec.options, event.option_id)
					codex.ruin_records[event.id] = rec
			"story_seen":
				if event.get("triggered", false) != true or event.get("status", "") not in ["completed", "skipped"]:
					return _error("剧情必须实际触发且观看或跳过后登记。")
				_append_unique(codex.seen_story_nodes, event.id)
			_: return _error("未知图鉴事件。")
	return _ok()

static func _enemy_key(id: String, version: int, challenge: String) -> String:
	return "%s|%d|%s" % [id, version, challenge]

static func _candidate(meta: Dictionary, unlocks: Array, achievements: Array) -> Dictionary:
	return {"ok": true, "error": "", "meta": meta, "new_unlocks": unlocks, "new_achievements": achievements}

static func _integer(value: Variant, low: int = 0, high: int = MAX_VALUE) -> bool:
	return (value is int or value is float) and is_finite(float(value)) and float(value) == floor(float(value)) and value >= low and value <= high

static func _id(value: Variant) -> bool:
	return value is String and not value.strip_edges().is_empty() and value.length() <= 256 and "|" not in value

static func _ids(value: Variant) -> bool:
	if not value is Array:
		return false
	var seen := {}
	for id in value:
		if not _id(id) or seen.has(id):
			return false
		seen[id] = true
	return true

static func _append_unique(values: Array, value: String) -> void:
	if value not in values:
		values.append(value)

static func _ok() -> Dictionary:
	return {"ok": true, "error": ""}

static func _error(message: String) -> Dictionary:
	return {"ok": false, "error": message}
