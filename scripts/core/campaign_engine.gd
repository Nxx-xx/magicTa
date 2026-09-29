extends "res://scripts/core/map_engine.gd"
## Campaign adds its own recipes and account envelope without changing trial RNG.
const CampaignGenerator = preload("res://scripts/core/campaign_generator.gd")
const CampaignSave = preload("res://scripts/core/campaign_save.gd")
const Progress = preload("res://scripts/core/campaign_progress.gd")
const Story = preload("res://scripts/core/story_state.gd")
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
	if state.is_empty():
		_committed_state = {}
		_committed_meta = meta.duplicate(true)
		return
	Keys.ensure_inventory(state.player)
	for category in state.get("reward_content", {}):
		db.data[category] = state.reward_content[category].duplicate(true)
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

func start(seed_text: String = "", random_maps: bool = true) -> String:
	if transaction_pending:
		return "待提交进度尚未保存，请先重试保存。"
	if is_campaign() and active():
		return "请先放弃或结束当前十层旅程。"
	var error := super.start(seed_text, random_maps)
	return save_error if transaction_pending else error

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

func save_game() -> bool:
	if transaction_pending:
		return false
	if not state.is_empty():
		state.rng_state = str(rng.state)
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
	if not state.is_empty():
		for category in state.get("reward_content", {}):
			db.data[category] = state.reward_content[category].duplicate(true)
		rng.seed = str(state.seed).to_int()
		rng.state = str(state.rng_state).to_int()
		if is_campaign() and state.has("campaign_rules_snapshot"):
			campaign_generator.config = state.campaign_rules_snapshot.duplicate(true)
			campaign_generator.content_snapshot = state.reward_content.duplicate(true)

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
				var generated: Dictionary = campaign_generator.generate(state.campaign_plan, destination, "boss", str(state.boss_choice))
				if generated.is_empty():
					return campaign_generator.last_error
				state.floors[str(destination)] = generated
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
	var generated: Dictionary = campaign_generator.generate(state.campaign_plan, next, theme_id, str(state.boss_choice))
	if generated.is_empty():
		return campaign_generator.last_error
	state.floors[str(next)] = generated
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
	if report.lethal and not confirm_lethal:
		return "confirm_lethal"
	state.last_report = report
	state.player.hp = report.hp_after
	state.player.gold += report.gold_reward
	state.metrics.damage_taken += report.incoming
	state.metrics.healing += report.healing
	state.metrics.minimum_hp = mini(int(state.metrics.get("minimum_hp",100)),int(report.hp_after))
	state.pending = {}
	if report.won:
		state.defeated_entities.append({"id":entity.id, "enemy_id":entity.enemy_id, "rank":db.enemy(entity.enemy_id).rank, "floor":int(state.floor)})
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
	var candidate: Dictionary = Progress.settle(state, meta, result)
	if not candidate.ok:
		return str(candidate.error)
	state = candidate.state
	meta = candidate.meta
	match result:
		"victory": state.last_message = "魔王的封印已破。公主救出了王子，两人一同离开魔塔。"
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
	var resolved := Rewards.resolve(db,state.player,options[index])
	if not resolved.ok:
		return resolved.error
	state.player = resolved.player
	state.metrics.healing += resolved.healing
	state.metrics.overflow += resolved.overflow
	state.metrics.gold_spent += maxi(0,-int(resolved.gold_delta))
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
	var resolved := shop_preview(str(entity.offers[index]))
	if not resolved.ok:
		return resolved.error
	state.player = resolved.player
	state.metrics.gold_spent += maxi(0,-int(resolved.gold_delta))
	state.metrics.healing += resolved.healing
	state.metrics.overflow += resolved.overflow
	entity.purchased = true
	entity.purchased_id = str(entity.offers[index])
	state.last_message = "购买了 %s。商人本局不再补货。" % shop_offer(entity.purchased_id).name
	state.pending = {}
	save_game()
	return ""
