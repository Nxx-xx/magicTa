extends RefCounted

## JSON reads numbers as floats; compare frozen trees by value across a save/load.
static func same_json(a: Variant, b: Variant) -> bool:
	if (a is int or a is float) and (b is int or b is float):
		return is_finite(float(a)) and is_finite(float(b)) and a == b
	if a is Dictionary and b is Dictionary:
		if a.size() != b.size(): return false
		for key in a:
			if not b.has(key) or not same_json(a[key], b[key]): return false
		return true
	if a is Array and b is Array:
		if a.size() != b.size(): return false
		for i in a.size():
			if not same_json(a[i], b[i]): return false
		return true
	return typeof(a) == typeof(b) and a == b
## Version/profile gate only. Loading this module never enables Phase 3 globally.
const CONTRACT_VERSION := 1
const RUN_VERSIONS := {
	"phase3_contract_version": 1,
	"generator_version": 2,
	"combat_rules_version": 2,
	"reward_rules_version": 2,
	"story_rules_version": 1,
}
const CHALLENGES := ["p3_c0", "p3_c1", "p3_c2"]
const START_CONFIGS := ["default", "p3_vanguard", "p3_keeper", "p3_trader"]

static func new_run_versions() -> Dictionary:
	return RUN_VERSIONS.duplicate(true)

static func classify(run: Dictionary) -> Dictionary:
	if run.is_empty():
		return _success("empty")
	var mode: Variant = run.get("mode")
	if not mode is String or mode not in ["grid_prototype_v1", "tower_campaign_v1"]:
		return _error("未知旅程模式，不能推测使用哪一版规则。")
	if mode == "grid_prototype_v1":
		if run.has("phase3_contract_version"):
			return _error("两层试炼不能使用第三阶段规则。")
		if run.has("combat_rules_version") and not _version(run.combat_rules_version, 1):
			return _error("两层试炼的战斗规则版本无效。")
		return _success("legacy_trial")
	if not run.has("phase3_contract_version"):
		for field in ["generator_version", "combat_rules_version", "reward_rules_version"]:
			if run.has(field) and not _version(run[field], 1):
				return _error("新版旅程缺少明确的版本标记，不能按旧规则读取。")
		return _success("legacy_campaign")
	for field in RUN_VERSIONS:
		if not _version(run.get(field), int(RUN_VERSIONS[field])):
			return _error("不支持或矛盾的第三阶段规则版本：%s。" % field)
	if run.get("campaign_kind") != "tower_10f":
		return _error("第三阶段仅支持十层旅程。")
	return _success("phase3_campaign")

static func validate_profile(profile: Dictionary, unlocked_ids: Array) -> Dictionary:
	var challenge: Variant = profile.get("challenge_id", "p3_c0")
	var config: Variant = profile.get("start_config_id", "default")
	if not challenge is String or challenge not in CHALLENGES:
		return _error("未知挑战难度。")
	if not config is String or config not in START_CONFIGS:
		return _error("未知起始配置。")
	var pool: Array = []
	for id in unlocked_ids:
		if not id is String or str(id).is_empty():
			return _error("解锁快照包含无效标识。")
		if id not in pool:
			pool.append(id)
	for id in ["p3_c0", "default"]:
		if id not in pool:
			pool.append(id)
	if challenge not in pool or config not in pool:
		return _error("所选难度或起始配置尚未解锁。")
	pool.sort()
	return {"ok": true, "error": "", "profile": {
		"challenge_id": challenge, "start_config_id": config,
		"unlocked_ids": pool,
	}}

static func validate_snapshots(run: Dictionary) -> Dictionary:
	var result := classify(run)
	if not result.ok or result.kind != "phase3_campaign":
		return result
	for field in ["campaign_rules_snapshot", "campaign_plan"]:
		var snapshot: Variant = run.get(field)
		if not snapshot is Dictionary or not _version(snapshot.get("version"), 2):
			return _error("第三阶段缺少一致的规则快照：%s。" % field)
	for field in ["challenge_snapshot", "start_config_snapshot"]:
		var snapshot: Variant = run.get(field)
		if not snapshot is Dictionary or not _version(snapshot.get("version"), 1):
			return _error("挑战或起点快照无效：%s。" % field)
	var pool: Variant = run.get("unlocked_pool_snapshot")
	if not pool is Array:
		return _error("缺少本局解锁池快照。")
	var profile_result := validate_profile({
		"challenge_id": run.challenge_snapshot.get("id"),
		"start_config_id": run.start_config_snapshot.get("id"),
	}, pool)
	if not profile_result.ok:
		return profile_result
	return _success("phase3_campaign")

static func _version(value: Variant, expected: int) -> bool:
	return (value is int or value is float) and is_finite(float(value)) and float(value) == expected

static func _success(kind: String) -> Dictionary:
	return {"ok": true, "error": "", "kind": kind}

static func _error(message: String) -> Dictionary:
	return {"ok": false, "error": message, "kind": "invalid"}
