extends "res://scripts/core/map_engine.gd"
## Ten-floor campaign and account transactions over the shared map engine.
const CampaignGenerator = preload("res://scripts/core/campaign_generator.gd")
const CampaignSave = preload("res://scripts/core/campaign_save.gd")
const Progress = preload("res://scripts/core/campaign_progress.gd")
const Story = preload("res://scripts/core/story_state.gd")
const P3Contract = preload("res://scripts/core/phase3_contract.gd")
const P3Items = preload("res://scripts/core/phase3_items.gd")
const P3Enemies = preload("res://scripts/core/phase3_enemies.gd")
const P3Progress = preload("res://scripts/core/phase3_progress.gd")
const P3Ruins = preload("res://scripts/core/phase3_ruins.gd")
const RelicTrail = preload("res://scripts/core/relic_trail.gd")
const RelicStoryPool = preload("res://scripts/core/relic_story_pool.gd")
const FunctionCodes = preload("res://scripts/core/function_codes.gd")
var campaign_generator = CampaignGenerator.new()
var meta: Dictionary = Progress.default_meta()
var transaction_pending := false
var _committed_state: Dictionary = {}
var _committed_meta: Dictionary = {}
var _candidate_state: Dictionary = {}
var _candidate_meta: Dictionary = {}

func _init(path: String = SAVE_PATH) -> void:
	super(path)
	store = CampaignSave.new(path)
	errors.append_array(campaign_generator.errors)
	_committed_meta = meta.duplicate(true)

func is_campaign() -> bool:
	return state.get("mode", "") == "tower_campaign_v1"

func is_phase3() -> bool:
	return is_campaign() and state.get("phase3_contract_version", 0) == 1

func preview(cell: Vector2i) -> Dictionary:
	if not is_phase3():
		return super.preview(cell)
	var entity := entity_at(cell)
	if entity.get("type", "") != "enemy":
		return {}
	return Combat.simulate(state.player, db.enemy(entity.enemy_id), stats(), 2)

func active() -> bool:
	return not transaction_pending and super.active() and (not is_campaign() or state.get("result", "").is_empty())

func load_game() -> void:
	if transaction_pending:
		return
	var saved: Dictionary = store.read()
	save_error = store.last_error
	if saved.is_empty():
		return
	state = saved.run
	meta = saved.get("meta", {})
	if meta.is_empty():
		meta = Progress.default_meta()
	# Read legacy accounts without resuming or overwriting the retired prototype.
	if state.get("mode", "") == "grid_prototype_v1":
		state = {}
	if state.is_empty():
		db = DB.new()
		_committed_state = {}
		_committed_meta = meta.duplicate(true)
		return
	Keys.ensure_inventory(state.player)
	db.data.merge(state.get("reward_content", {}).duplicate(true), true)
	rng.seed = str(state.seed).to_int()
	rng.state = str(state.rng_state).to_int()
	# Ended runs are review-only. A crash cannot replay a punishment cue.
	if is_campaign() and not str(state.get("result", "")).is_empty():
		for event in state.story.get("queue", []):
			event.audio_cue = ""
			event["static_summary"] = true
	_committed_state = state.duplicate(true)
	_committed_meta = meta.duplicate(true)
	_sync_runtime()

func start(_seed_text: String = "", _random_maps: bool = true) -> String:
	# Override the inherited prototype entry so it cannot create a retired run.
	return "两层试炼已停用，请从营地塔口开始十层旅程。"

func start_campaign(seed_text: String = "") -> String:
	if transaction_pending:
		return "待提交进度尚未保存，请先重试保存。"
	if is_campaign() and active():
		return "请先放弃或结束当前十层旅程。"
	if not errors.is_empty():
		return "\n".join(errors)
	var seed_value: int = seed_text.to_int() if seed_text.is_valid_int() else seed_text.hash()
	if seed_text.strip_edges().is_empty():
		var random := RandomNumberGenerator.new()
		random.randomize()
		seed_value = random.randi()
	var next_generator = _new_campaign_generator()
	var plan_data: Dictionary = next_generator.plan(str(seed_value))
	if plan_data.is_empty():
		return next_generator.last_error
	var next_db = DB.new()
	if not next_db.errors.is_empty():
		return "\n".join(next_db.errors)
	for enemy_id in next_generator.config.get("enemy_overrides", {}):
		if not next_db.data.enemies.has(enemy_id):
			return "战役怪物覆盖引用了未知怪物。"
		for field in next_generator.config.enemy_overrides[enemy_id]:
			next_db.data.enemies[enemy_id][field] = next_generator.config.enemy_overrides[enemy_id][field]
	var validation = CampaignSave.new(SAVE_PATH)
	if not validation._valid_plan(plan_data,next_db.data.items) or not validation._valid_campaign_rules(next_generator.config,next_db.data,plan_data):
		return "战役规则或固定成长计划校验失败，现有进度未修改。"
	next_generator.content_snapshot = next_db.data.duplicate(true)
	var first: Dictionary = next_generator.generate(plan_data, 1, "entrance")
	if first.is_empty():
		return next_generator.last_error
	db = next_db
	campaign_generator = next_generator
	rng.seed = seed_value
	state = {"mode":"tower_campaign_v1", "campaign_kind":"tower_10f", "run_id":"%s-%s-%s" % [Time.get_unix_time_from_system(),Time.get_ticks_usec(),OS.get_process_id()],
		"seed":str(seed_value), "rng_state":str(rng.state), "generator_version":1, "reward_rules_version":1,
		"story_rules_version":1, "meta_rules_snapshot":Progress.RULES.duplicate(true), "campaign_plan":plan_data, "campaign_rules_snapshot":campaign_generator.config.duplicate(true), "reward_content":db.data.duplicate(true),
		"floor":1, "position":first.entry.duplicate(), "floors":{"1":first}, "pending":{},
		"player":Progress.initial_player(meta), "meta_snapshot":meta.duplicate(true),
		"completed":false, "objective_complete":false, "side_objective_complete":false, "summit_seen":false, "result":"",
		"defeated_entities":[], "boss_rewards_claimed":[], "boss_choice":"", "last_report":{},
		"metrics":{"steps":0,"backtrack_steps":0,"damage_taken":0,"healing":0,"overflow":0,"gold_spent":0,"minimum_hp":int(Progress.initial_player(meta).hp)},
		"last_message":"王子被囚在第十层。先收集军械，再挑战第五层封印守卫。"}
	Story.initialize(state, meta)
	return "" if save_game() else save_error

func _new_campaign_generator():
	return CampaignGenerator.new()

func _new_phase3_generator():
	return load("res://scripts/core/phase3_campaign_generator.gd").new()

## New-mode entry point. The legacy start_campaign remains available for old runs.
func start_phase3(seed_text: String = "", challenge_id: String = "p3_c0", start_config_id: String = "default", replay_snapshot: Dictionary = {}) -> String:
	if transaction_pending:
		return "待提交进度尚未保存，请先重试保存。"
	if active():
		return "请先结束或放弃当前旅程。"
	if not errors.is_empty():
		return "\n".join(errors)
	var next_meta: Dictionary = P3Progress.migrate_meta(meta)
	var valid_meta := P3Progress.validate_meta_extensions(next_meta)
	if not valid_meta.ok:
		return valid_meta.error
	var progress_defs: Dictionary = P3Progress.definitions()
	var ruins: Dictionary = P3Ruins.definitions()
	var starting_account: Dictionary = next_meta.duplicate(true)
	var next_generator = _new_phase3_generator()
	var content: Dictionary = {}
	var plan_data: Dictionary = {}
	var variant_plan := {"3":"p3_shield_sentinel", "6":"p3_ember_channeler", "8":"p3_vault_knight"}
	var seed_value: int = seed_text.to_int() if seed_text.is_valid_int() else seed_text.hash()
	if seed_text.strip_edges().is_empty():
		var random := RandomNumberGenerator.new()
		random.randomize()
		seed_value = random.randi()
	if not replay_snapshot.is_empty():
		var checked := P3Contract.validate_snapshots(replay_snapshot)
		if not checked.ok or checked.kind != "phase3_campaign":
			return "无法使用这份旅程快照重试。"
		for field in ["progress_rules_snapshot", "ruin_definitions_snapshot", "reward_content", "meta_snapshot", "variant_plan"]:
			if not replay_snapshot.get(field) is Dictionary:
				return "重试快照缺少：%s。" % field
		progress_defs = replay_snapshot.progress_rules_snapshot.duplicate(true)
		ruins = replay_snapshot.ruin_definitions_snapshot.duplicate(true)
		starting_account = P3Progress.migrate_meta(replay_snapshot.meta_snapshot)
		starting_account.unlocked_ids = replay_snapshot.unlocked_pool_snapshot.duplicate()
		challenge_id = str(replay_snapshot.challenge_snapshot.id)
		start_config_id = str(replay_snapshot.start_config_snapshot.id)
		seed_value = str(replay_snapshot.seed).to_int()
		content = replay_snapshot.reward_content.duplicate(true)
		plan_data = replay_snapshot.campaign_plan.duplicate(true)
		next_generator.config = replay_snapshot.campaign_rules_snapshot.duplicate(true)
		variant_plan = replay_snapshot.variant_plan.duplicate(true)
	else:
		ruins = RelicStoryPool.for_run(ruins, seed_value, next_meta)
		if ruins.is_empty(): return "勇者往事内容无效，原旅程未修改。"
		var baseline = DB.new()
		content = P3Items.merge_content(baseline.data)
		if content.get("ok", true) == false:
			return str(content.error)
		content = P3Enemies.merge_content(content)
		if content.get("ok", true) == false:
			return str(content.error)
		for id in next_generator.config.get("enemy_overrides", {}):
			if not content.enemies.has(id):
				return "战役怪物覆盖引用无效。"
			content.enemies[id].merge(next_generator.config.enemy_overrides[id], true)
		var scaled := P3Progress.apply_challenge(content, challenge_id, progress_defs)
		if not scaled.ok:
			return scaled.error
		content = scaled.content
		var events := P3Ruins.event_definitions(ruins)
		if events.is_empty():
			return "遗迹定义无效。"
		content.events.merge(events, true)
	var selected := P3Progress.select_start(starting_account, challenge_id, start_config_id, progress_defs)
	if not selected.ok:
		return selected.error
	selected.challenge_snapshot.version = 1
	selected.start_config_snapshot.version = 1
	next_generator.content_snapshot = content.duplicate(true)
	next_generator.phase3_context = {"unlocked_ids":selected.unlocked_pool_snapshot.duplicate(),
		"ruin_definitions":ruins.duplicate(true), "variant_plan":variant_plan.duplicate(true),
		"used_unique_ids":[], "challenge_id":challenge_id, "challenge_snapshot":selected.challenge_snapshot.duplicate(true)}
	if plan_data.is_empty():
		plan_data = next_generator.plan(str(seed_value))
	if plan_data.is_empty():
		return next_generator.last_error
	var first: Dictionary = next_generator.generate(plan_data, 1, "entrance")
	if first.is_empty():
		return next_generator.last_error
	var next_rng := RandomNumberGenerator.new()
	next_rng.seed = seed_value
	var candidate := {"mode":"tower_campaign_v1", "campaign_kind":"tower_10f",
		"run_id":"%s-%s-%s" % [Time.get_unix_time_from_system(),Time.get_ticks_usec(),OS.get_process_id()],
		"seed":str(seed_value), "rng_state":str(next_rng.state),
		"meta_rules_snapshot":Progress.RULES.duplicate(true), "campaign_plan":plan_data,
		"campaign_rules_snapshot":next_generator.config.duplicate(true), "reward_content":content,
		"challenge_id":challenge_id, "challenge_rules_version":1,
		"challenge_snapshot":selected.challenge_snapshot, "start_config_snapshot":selected.start_config_snapshot,
		"unlocked_pool_snapshot":selected.unlocked_pool_snapshot, "progress_rules_snapshot":progress_defs,
		"ruin_definitions_snapshot":ruins, "variant_plan":variant_plan,
		"reserved_unique_ids":first.get("phase3_new_unique_ids", []).duplicate(), "codex_events":[],
		"floor":1, "position":first.entry.duplicate(), "floors":{"1":first},
		"pending":{}, "player":selected.player, "meta_snapshot":starting_account,
		"completed":false, "objective_complete":false, "side_objective_complete":false, "summit_seen":false, "result":"",
		"defeated_entities":[], "boss_rewards_claimed":[], "boss_choice":"", "last_report":{},
		"metrics":{"steps":0,"backtrack_steps":0,"damage_taken":0,"healing":0,"overflow":0,"gold_spent":0,
			"minimum_hp":int(selected.player.hp),"actual_kill_healing":0,"shop_gold_spent":0,
			"min_hp_in_combat":int(selected.player.hp),"ruin_choices":{},"effect_counts":{},"effect_actual_values":{}},
		"last_message":"新的提灯旅程开始。查看战斗代价，选择自己的成长与遗迹路线。"}
	candidate.merge(P3Contract.new_run_versions(), true)
	Story.initialize(candidate, next_meta)
	# Validate the complete new candidate before replacing an existing ended run.
	var validation = CampaignSave.new(SAVE_PATH)
	if not validation._valid({"version":2, "run":candidate, "meta":next_meta}):
		return "第三阶段旅程校验失败，原进度未修改。"
	state = candidate
	meta = next_meta
	campaign_generator = next_generator
	rng.seed = seed_value
	rng.state = next_rng.state
	db = DB.new()
	db.data = content.duplicate(true)
	db.rules_version = 2
	return "" if save_game() else save_error

func save_game() -> bool:
	if transaction_pending:
		return false
	if not state.is_empty():
		state.rng_state = str(rng.state)
	if is_phase3():
		var discovered := P3Progress.record_discoveries(meta, str(state.run_id), state.get("codex_events", []))
		if not discovered.ok:
			_hold_failed_transaction(str(discovered.error))
			return false
		meta = discovered.meta
	var ok: bool = not persistence_enabled or store.write(state, meta)
	save_error = "" if ok else store.last_error
	if ok:
		_committed_state = state.duplicate(true)
		_committed_meta = meta.duplicate(true)
	else:
		_candidate_state = state.duplicate(true)
		_candidate_meta = meta.duplicate(true)
		state = _committed_state.duplicate(true)
		meta = _committed_meta.duplicate(true)
		transaction_pending = true
		_sync_runtime()
	return ok

func _hold_failed_transaction(message: String) -> void:
	save_error = message
	_candidate_state = state.duplicate(true)
	_candidate_meta = meta.duplicate(true)
	state = _committed_state.duplicate(true)
	meta = _committed_meta.duplicate(true)
	transaction_pending = true
	_sync_runtime()

func retry_save() -> bool:
	if not transaction_pending:
		return save_game()
	if persistence_enabled and not store.write(_candidate_state, _candidate_meta):
		save_error = store.last_error
		return false
	state = _candidate_state
	meta = _candidate_meta
	_committed_state = state.duplicate(true)
	_committed_meta = meta.duplicate(true)
	_candidate_state = {}
	_candidate_meta = {}
	transaction_pending = false
	save_error = ""
	_sync_runtime()
	return true

func _sync_runtime() -> void:
	db = DB.new()
	db.rules_version = 2 if is_phase3() else 1
	if not state.is_empty():
		db.data.merge(state.get("reward_content", {}).duplicate(true), true)
		rng.seed = str(state.seed).to_int()
		rng.state = str(state.rng_state).to_int()
		if is_campaign() and state.has("campaign_rules_snapshot"):
			campaign_generator = _new_phase3_generator() if is_phase3() else _new_campaign_generator()
			campaign_generator.config = state.campaign_rules_snapshot.duplicate(true)
			campaign_generator.content_snapshot = state.reward_content.duplicate(true)
			if is_phase3():
				_sync_phase3_generation()

func _sync_phase3_generation() -> void:
	if is_phase3():
		campaign_generator.phase3_context = {"unlocked_ids":state.unlocked_pool_snapshot.duplicate(),
			"ruin_definitions":state.ruin_definitions_snapshot.duplicate(true), "variant_plan":state.variant_plan.duplicate(true),
			"used_unique_ids":state.reserved_unique_ids.duplicate(), "challenge_id":str(state.challenge_id),
			"challenge_snapshot":state.challenge_snapshot.duplicate(true)}

func _accept_generated_floor(number: int, generated: Dictionary) -> void:
	state.floors[str(number)] = generated
	if is_phase3():
		for id in generated.get("phase3_new_unique_ids", []):
			if id not in state.reserved_unique_ids:
				state.reserved_unique_ids.append(id)
		_sync_phase3_generation()

func interact(cell: Vector2i) -> String:
	if not is_campaign() or not active() or not state.pending.is_empty():
		return super.interact(cell)
	if absi(cell.x-position().x) + absi(cell.y-position().y) <= 1:
		var entity := entity_at(cell)
		if entity.get("type", "") == "up":
			if int(state.floor) == 5 and state.boss_rewards_claimed.is_empty():
				return "外环封印尚未解除：击败守卫并领取军械。"
			var destination := int(state.floor) + 1
			if destination in [5,10] and not state.floors.has(str(destination)):
				_sync_phase3_generation()
				var generated: Dictionary = campaign_generator.generate(state.campaign_plan, destination, "boss", str(state.boss_choice))
				if generated.is_empty():
					return campaign_generator.last_error
				_accept_generated_floor(destination, generated)
				state.pending = {"kind":"stairs", "pos":[cell.x,cell.y], "destination":destination}
				save_game()
				return ""
	return super.interact(cell)

func choose_floor(theme_id: String) -> String:
	if not is_campaign():
		return super.choose_floor(theme_id)
	if not active() or state.pending.get("kind", "") != "floor_choice":
		return "请先到达上行楼梯。"
	var next := int(state.floor) + 1
	if theme_id not in THEMES or next > 10 or state.floors.has(str(next)):
		return "本层类型已经确定，不能重新生成。"
	_sync_phase3_generation()
	var generated: Dictionary = campaign_generator.generate(state.campaign_plan, next, theme_id, str(state.boss_choice))
	if generated.is_empty():
		return campaign_generator.last_error
	_accept_generated_floor(next, generated)
	return _travel(next)

func floor_choices() -> Dictionary:
	return campaign_generator.config.themes if is_campaign() else super.floor_choices()

func confirm_interaction(confirm_lethal: bool = false) -> String:
	if not is_campaign() or not active() or state.pending.get("kind", "") != "entity":
		return super.confirm_interaction(confirm_lethal)
	var cell := pending_cell()
	var entity := entity_at(cell)
	if entity.get("type", "") != "enemy":
		return super.confirm_interaction(confirm_lethal)
	var report := preview(cell)
	if report.get("ok", true) == false:
		return str(report.get("error", "战斗规则校验失败。"))
	if report.lethal and not confirm_lethal:
		return "confirm_lethal"
	state.last_report = report
	state.player.hp = report.hp_after
	state.player.gold += report.gold_reward
	state.metrics.damage_taken += report.incoming
	state.metrics.healing += report.healing
	state.metrics.minimum_hp = mini(int(state.metrics.get("minimum_hp",100)),int(report.hp_after))
	if is_phase3():
		state.metrics.actual_kill_healing += int(report.healing)
		state.metrics.min_hp_in_combat = mini(int(state.metrics.min_hp_in_combat), int(report.min_hp))
		state.metrics.minimum_hp = mini(int(state.metrics.minimum_hp), int(report.min_hp))
		_queue_phase3_event({"event_id":str(entity.id)+":enemy_seen", "kind":"enemy_seen", "id":str(entity.enemy_id)})
		for event in report.get("effects_triggered", []):
			var effect_id: String = str(event.id)
			state.metrics.effect_counts[effect_id] = int(state.metrics.effect_counts.get(effect_id, 0)) + 1
			state.metrics.effect_actual_values[effect_id] = int(state.metrics.effect_actual_values.get(effect_id, 0)) + int(event.amount)
	state.pending = {}
	if report.won:
		var defeated := {"id":entity.id, "enemy_id":entity.enemy_id, "rank":db.enemy(entity.enemy_id).rank, "floor":int(state.floor)}
		if is_phase3():
			defeated.turns = int(report.turns)
			defeated.incoming = int(report.incoming)
			if defeated.rank == "elite":
				state.metrics.lowest_elite_incoming = mini(int(state.metrics.get("lowest_elite_incoming", report.incoming)), int(report.incoming))
			if entity.enemy_id == "minotaur":
				state.metrics.midboss_turns = int(report.turns)
		state.defeated_entities.append(defeated)
		floor_data().entities.erase(cell_key(cell))
		_move_to(cell)
		state.last_message = "击败 %s，生命损失 %d，金币 +%d。" % [db.enemy(entity.enemy_id).name,report.loss,report.gold_reward]
		if entity.get("campaign_boss", false):
			if int(state.floor) == 5:
				_apply_effects({"heal":65})
			else:
				state.objective_complete = true
				return _settle("victory")
	else:
		return _settle("death")
	save_game()
	return ""

func _settle(result: String) -> String:
	var ending := state.duplicate(true)
	if is_phase3():
		ending.result = result
		ending.completed_at = Time.get_datetime_string_from_system(true) + "Z"
		var guard := P3Progress.settlement_guard(ending, meta)
		if not guard.ok:
			return str(guard.error)
		if guard.already_settled:
			return ""
	var candidate: Dictionary = Progress.settle(ending, meta, result)
	if not candidate.ok:
		return str(candidate.error)
	if is_phase3():
		var relic_story_id := RelicStoryPool.story_id(candidate.state)
		if not relic_story_id.is_empty(): candidate.meta.records.back()["relic_story_id"] = relic_story_id
		var extension := P3Progress.evaluate_unlocks(candidate.state, candidate.meta, state.progress_rules_snapshot)
		if not extension.ok:
			state = _committed_state.duplicate(true)
			meta = _committed_meta.duplicate(true)
			_sync_runtime()
			return str(extension.error)
		candidate.meta = extension.meta
		candidate.state.phase3_new_unlocks = extension.new_unlocks
		candidate.state.phase3_new_achievements = extension.new_achievements
	state = candidate.state
	meta = candidate.meta
	match result:
		"victory": state.last_message = "魔王倒下，王子却熄灯背刺公主，显露怪物真身：这场营救替他解开了最后的束缚。王城地下传来应答，老骑士循着未灭的副芯重返魔塔。公主生死未明，母亲留在灯中的警告才刚刚显现。"
		"death": state.last_message = "提灯将公主送回营地。远处传来回声咒与王子的惨叫；本次失败只记录一次。"
		"abandoned": state.last_message = "公主暂时返回营地。主动撤离不记战败，也不发放灵魂。"
	return "" if save_game() else save_error

func abandon_run() -> String:
	if transaction_pending:
		return "请先重试保存。"
	if not is_campaign() or not active():
		return "当前没有进行中的十层旅程。"
	return _settle("abandoned")

func purchase_upgrade(kind: String) -> String:
	if transaction_pending or (is_campaign() and active()):
		return "请先结束旅程并保存，再购买火种。"
	var result: Dictionary = Progress.purchase(meta, kind)
	if not result.ok:
		return str(result.error)
	meta = result.meta
	return "" if save_game() else save_error

func apply_function_code(code: String) -> String:
	if transaction_pending:
		return "有操作等待保存，请先重试。"
	if code.strip_edges().to_upper() != FunctionCodes.DEFAULT_CODE:
		return "功能码不正确。"
	if not is_campaign() or not active():
		return "请先进入魔塔，开始或继续一段旅程。"
	var player: Dictionary = state.player.duplicate(true)
	player.erase("function_code_offsets")
	var current: Dictionary = db.player_stats(player)
	if not current.get("ok", true): return str(current.get("error", "无法读取角色属性。"))
	var offsets := {}
	for field in FunctionCodes.FIELDS:
		offsets[field] = int(current[field]) - int(player[field])
		player[field] = FunctionCodes.VALUE
	player.function_code_offsets = offsets
	player.hp = FunctionCodes.VALUE
	state.player = player
	state.last_message = "功能码已生效：生命 1000/1000，攻击 1000，防御 1000。"
	return "" if save_game() else save_error

func reset_upgrades() -> String:
	if transaction_pending or (is_campaign() and active()):
		return "请先结束旅程并保存，再重置火种。"
	var result: Dictionary = Progress.reset(meta)
	if not result.ok:
		return str(result.error)
	meta = result.meta
	return "" if save_game() else save_error

func story_event() -> Dictionary:
	if transaction_pending or not is_campaign() or not state.pending.is_empty():
		return {}
	var queue: Array = state.get("story", {}).get("queue", [])
	return queue[0].duplicate(true) if not queue.is_empty() else {}

func acknowledge_story() -> void:
	if transaction_pending or not is_campaign():
		return
	if not state.story.queue.is_empty():
		if is_phase3():
			var story: Dictionary = state.story.queue[0]
			var story_id := str(story.get("id", ""))
			if not story_id.is_empty():
				_queue_phase3_event({"event_id":"story:"+story_id+":finished", "kind":"story_seen", "id":story_id,
					"triggered":true, "status":"completed"})
		state.story.queue.pop_front()
		save_game()

func cancel_pending() -> void:
	if not transaction_pending:
		super.cancel_pending()

func _travel(destination: int) -> String:
	if is_campaign():
		if int(state.floor) == 5 and destination == 6 and state.boss_rewards_claimed.is_empty():
			return "请先击败守卫并领取阶段军械。"
		if not state.floors.has(str(destination)) or absi(destination-int(state.floor)) != 1:
			return "楼梯没有连接到可进入的楼层。"
		var ascending := destination > int(state.floor)
		state.floor = destination
		state.position = floor_data().entry.duplicate() if ascending else floor_data().exit.duplicate()
		state.pending = {}
		Story.on_floor(state)
		state.last_message = "来到第 %d 层 · %s。" % [destination,floor_data().name]
		save_game()
		return ""
	return super._travel(destination)

func _collect(cell: Vector2i, entity: Dictionary) -> String:
	var hp_before := int(state.player.hp)
	var result := super._collect(cell,entity)
	if is_campaign() and result.is_empty():
		state.metrics.healing += maxi(0,int(state.player.hp)-hp_before)
		if entity.type == "potion":
			state.metrics.overflow += maxi(0,int(entity.amount)-(int(state.player.hp)-hp_before))
		if entity.type == "chest":
			if is_phase3():
				_queue_phase3_event({"event_id":str(entity.id)+":obtain", "kind":"item_obtained", "id":str(entity.item_id), "source":"chest"})
			Story.enqueue(state, "first_equipment")
			if entity.get("objective", false):
				state.objective_complete = false
				state.side_objective_complete = true
				Story.enqueue(state, "ring")
				state.last_message = "王权指环已回收。王子仍在第十层等待营救。"
	return result

func choose_reward(index: int) -> String:
	if not is_campaign():
		return super.choose_reward(index)
	if not active() or state.pending.get("kind", "") != "entity":
		return "没有待领取的奖励。"
	var cell := pending_cell()
	var entity := entity_at(cell)
	var options := reward_options(entity)
	if index < 0 or index >= options.size():
		return "无效奖励选择。"
	if is_phase3() and entity.has("ruin_id"):
		return choose_ruin(str(options[index].get("id", "")))
	var resolved := Rewards.resolve(db,state.player,options[index])
	if not resolved.ok:
		return resolved.error
	state.player = resolved.player
	state.metrics.healing += resolved.healing
	state.metrics.overflow += resolved.overflow
	state.metrics.gold_spent += maxi(0,-int(resolved.gold_delta))
	if is_phase3() and options[index].has("item_id"):
		_queue_phase3_event({"event_id":str(entity.id)+":obtain", "kind":"item_obtained", "id":str(options[index].item_id), "source":"choice"})
	if entity.get("campaign_boss_reward", false):
		state.boss_rewards_claimed.append(5)
		state.boss_choice = str(entity.choices[index])
		Story.enqueue(state, "mid_boss")
	state.last_message = "选择「%s」。%s" % [options[index].name,Rewards.summary(resolved)]
	floor_data().entities.erase(cell_key(cell))
	state.pending = {}
	save_game()
	return ""

func _move_to(cell: Vector2i) -> void:
	if is_campaign() and cell != position():
		state.metrics.steps += 1
		if int(state.floor) < state.floors.size():
			state.metrics.backtrack_steps += 1
	super._move_to(cell)

func _apply_effects(effects: Dictionary) -> void:
	if not is_campaign():
		super._apply_effects(effects)
		return
	var resolved := Rewards.resolve(db,state.player,{"effects":effects})
	if resolved.ok:
		state.player = resolved.player
		state.metrics.healing += resolved.healing
		state.metrics.overflow += resolved.overflow

func buy(index: int) -> String:
	if not is_campaign():
		return super.buy(index)
	if not active() or state.pending.get("kind", "") != "entity":
		return "请先靠近商人。"
	var entity := entity_at(pending_cell())
	if entity.get("type", "") != "shop" or entity.get("purchased", false):
		return "这位商人本局的交易已经结束。"
	if index < 0 or index >= entity.offers.size():
		return "无效商品。"
	if shop_offer_sold(entity, str(entity.offers[index])):
		return "这件商品已售罄。"
	var resolved := shop_preview(str(entity.offers[index]))
	if not resolved.ok:
		return resolved.error
	state.player = resolved.player
	state.metrics.gold_spent += maxi(0,-int(resolved.gold_delta))
	if is_phase3():
		state.metrics.shop_gold_spent += maxi(0,-int(resolved.gold_delta))
		var purchased_offer := shop_offer(str(entity.offers[index]))
		if purchased_offer.has("item_id"):
			_queue_phase3_event({"event_id":str(entity.id)+":buy:"+str(entity.offers[index]), "kind":"item_obtained", "id":str(purchased_offer.item_id), "source":"shop"})
	state.metrics.healing += resolved.healing
	state.metrics.overflow += resolved.overflow
	_mark_shop_purchase(entity, str(entity.offers[index]))
	state.last_message = "购买了 %s。%s" % [shop_offer(entity.purchased_id).name, "商品已全部售罄。" if entity.purchased else "还可以继续选购其他商品。"]
	save_game()
	return ""

func ruin_previews(entity: Dictionary) -> Dictionary:
	if not is_phase3() or not entity.has("ruin_id"):
		return {"ok":false, "error":"此处不是第三阶段遗迹。"}
	return P3Ruins.preview_options(str(entity.ruin_id), state.player, db.data, Callable(P3Items, "resolve"), state.ruin_definitions_snapshot)

func choose_ruin(option_id: String) -> String:
	if not is_phase3() or not active() or state.pending.get("kind", "") != "entity":
		return "没有待处理的遗迹。"
	var cell := pending_cell()
	var entity := entity_at(cell)
	if not entity.has("ruin_id"):
		return "当前设施不是遗迹。"
	var candidate := P3Ruins.prepare_resolution(str(entity.ruin_id), option_id, entity, db.data, state.player,
		Callable(P3Items, "resolve"), str(state.run_id), state.ruin_definitions_snapshot)
	if not candidate.ok:
		return str(candidate.error)
	_queue_phase3_event({"event_id":str(entity.id)+":inspect", "kind":"ruin_seen", "id":str(entity.ruin_id)})
	if candidate.consumes:
		state.player = candidate.player
		floor_data().entities[cell_key(cell)] = candidate.ruin_state
		state.metrics.ruin_choices.merge(candidate.metric_choice, true)
		var resolved: Dictionary = candidate.reward_result
		state.metrics.healing += int(resolved.healing)
		state.metrics.overflow += int(resolved.overflow)
		state.metrics.gold_spent += maxi(0,-int(resolved.gold_delta))
		_queue_phase3_event({"event_id":str(entity.id)+":consume", "kind":"ruin_choice", "id":str(entity.ruin_id), "option_id":option_id})
		state.last_message = "遗迹已经铭记你的选择。" + Rewards.summary(resolved)
		var trail: Dictionary = state.ruin_definitions_snapshot.get(str(entity.ruin_id), {}).get("trail", {})
		if trail.get("chain") == RelicTrail.CHAIN:
			state.last_message = "已取用%s；线索「%s」已记入旅途拾遗。%s" % [trail.finds[option_id].name, trail.evidence, Rewards.summary(resolved)]
			if RelicTrail.complete(state): state.last_message += " 三份证据已串联，可回营向老骑士求证。"
	else:
		state.last_message = "保留遗迹，可以稍后回来。" if entity.get("status") == "available" else "这座遗迹已留下你的铭文。"
	state.pending = {}
	return "" if save_game() else save_error

func _queue_phase3_event(event: Dictionary) -> void:
	if not is_phase3():
		return
	for previous in state.codex_events:
		if previous.get("event_id") == event.get("event_id"):
			return
	state.codex_events.append(event.duplicate(true))

## Observation registration is itself one durable transaction, never a UI meta write.
func record_phase3_discoveries(events: Array) -> String:
	if not is_phase3():
		return ""
	if transaction_pending:
		return "请先重试保存。"
	var candidate := P3Progress.record_discoveries(meta, str(state.run_id), events)
	if not candidate.ok:
		return str(candidate.error)
	if candidate.meta == meta:
		return ""
	for event in events:
		_queue_phase3_event(event)
	meta = candidate.meta
	return "" if save_game() else save_error
