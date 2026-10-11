extends RefCounted
## Visual sampling of a committed plan. Never produces combat events or rewards.
const Catalog = preload("res://assets/monsters/phase3/phase3_enemy_animation_catalog.gd")
const Art = preload("res://scripts/ui/runtime_art.gd")
var actions := {}
var cues: Array = []
var fallback: Texture2D
var settlement_start := -1.0
var cache_bytes := 0
const CACHE_LIMIT := 8*1024*1024
var max_cache_bytes := CACHE_LIMIT
var peak_cache_bytes := 0
var _cache := {}
var _lru: Array[String] = []
var _missing := {}
var effects_enabled := true
var stone_armor_states: Array = []
var _is_golem := false

func release_frames() -> void:
	_cache.clear()
	_lru.clear()
	_missing.clear()
	cache_bytes = 0

func _texture(action: Dictionary, index: int) -> Texture2D:
	var path: String = action.frames[index]
	if _missing.has(path): return null
	if _cache.has(path):
		_lru.erase(path)
		_lru.append(path)
		return _cache[path].texture
	# Reserve space before decoding; no full-action SpriteFrames retained.
	# A mip chain is bounded by twice the base RGBA8 allocation.
	var reservation := int(action.size[0])*int(action.size[1])*8
	while not _lru.is_empty() and cache_bytes+reservation > max_cache_bytes:
		var oldest: String = _lru.pop_front()
		cache_bytes -= int(_cache[oldest].bytes)
		_cache.erase(oldest)
	var texture := Catalog.load_frame(action,index)
	if texture == null:
		_missing[path] = true
		return null
	var decoded := texture.get_image()
	var bytes := decoded.get_data_size()
	if bytes > max_cache_bytes: return texture # one frame, never an unbounded cache
	while not _lru.is_empty() and cache_bytes+bytes > max_cache_bytes:
		var oldest: String = _lru.pop_front()
		cache_bytes -= int(_cache[oldest].bytes)
		_cache.erase(oldest)
	_cache[path] = {"texture":texture,"bytes":bytes}
	_lru.append(path)
	cache_bytes += bytes
	peak_cache_bytes = maxi(peak_cache_bytes,cache_bytes)
	return texture

func configure(enemy_id: String, plan: Dictionary) -> void:
	actions.clear()
	release_frames()
	peak_cache_bytes = 0
	settlement_start = -1.0
	cues = plan.get("cues", []).duplicate(true)
	_is_golem = enemy_id == "golem"
	stone_armor_states = plan.get("stone_armor_states", []).duplicate(true)
	fallback = Art.enemy_static(enemy_id) if not enemy_id.is_empty() else null
	for name in ["idle", "attack", "hit", "defeat", "rage", "armor", "guard", "charge", "threat"]:
		var loaded := Catalog.describe_action(enemy_id, name)
		if not loaded.ok: continue
		actions[name] = loaded.action
	if _is_golem:
		for stage in range(1,5):
			for name in ["idle","attack","hit","armor","defeat"]:
				var key := "%s_armor_%d" % [name,stage]
				var loaded := Catalog.describe_action(enemy_id,key)
				if loaded.ok: actions[key] = loaded.action

func stone_armor_stage_at(seconds: float, settled: bool = false) -> int:
	var stage := 0
	if not _is_golem: return stage
	for state in stone_armor_states:
		if settled or float(state.at) <= seconds: stage = int(state.stage)
	return clampi(stage,0,4)

func frame_at(seconds: float, settled: bool = false, won: bool = false, reduced: bool = false) -> Dictionary:
	var name := "idle"
	var since := seconds
	var death_at := INF
	for cue in cues:
		if cue.kind in ["attack", "retaliation"] and int(cue.get("enemy_hp",1)) == 0:
			death_at = minf(death_at,float(cue.at))
	if settled and settlement_start < 0: settlement_start = seconds
	if settled and won: death_at = minf(death_at,settlement_start)
	if seconds >= death_at:
		name = "defeat"
		since = seconds-death_at
	elif not settled:
		# Anticipation overlaps the hero windup; contact remains on the report's
		# counter timestamp. A brief received hit temporarily interrupts that pose.
		for cue in cues:
			if cue.kind == "counter" and seconds >= float(cue.at)-.15 and seconds < float(cue.at)+.15:
				name = "attack"
				var attack: Dictionary = actions.get("attack",{})
				if not attack.is_empty():
					var contact := float(attack.get("events",{}).get("hit",0))/float(attack.fps)
					since = maxf(0,contact+(seconds-float(cue.at))*contact/.15)
		for cue in cues:
			if cue.kind in ["attack", "retaliation"] and seconds >= float(cue.at) and seconds < float(cue.at)+.05:
				name = "hit"
				since = seconds-float(cue.at)
		# Mechanism poses consume only committed report facts. Contact has priority
		# at counter time; compressed replay is distinct from the full art timeline.
		for cue in cues:
			var start := float(cue.at)-.15 if cue.kind == "counter" else float(cue.at)
			if seconds < start: continue
			var end := float(cue.at)+.25
			for next in cues:
				if next.kind == "counter" and next.turn == cue.turn and float(next.at) >= float(cue.at):
					end = minf(end,float(next.at)-.015)
			if seconds >= end: continue
			for effect in cue.get("effects",[]):
				var special: String = {"rage":"rage","stone_armor":"armor","p3_shield":"guard","p3_ember":"charge","p3_ambush":"threat"}.get(str(effect.get("id","")),"")
				if special.is_empty() or not actions.has(special): continue
				name = special
				var duration := float(actions[special].frames.size())/float(actions[special].fps)
				since = (seconds-start)/maxf(.001,end-start)*duration
	if reduced:
		name = "idle"
		since = 0
	var stage := stone_armor_stage_at(seconds,settled)
	var key := "%s_armor_%d" % [name,stage] if stage > 0 else name
	var action: Dictionary = actions.get(key,actions.get(name,{}))
	if action.is_empty(): return {"texture":fallback,"action":"static","frame":0}
	var count: int = action.frames.size()
	var index := maxi(0,int(since*float(action.fps)+.00001))
	index = index%count if action.loop else mini(index,count-1)
	var texture := _texture(action,index)
	if texture == null: return {"texture":fallback,"action":"static","frame":0}
	var effect: Texture2D
	if effects_enabled and not reduced and action.has("effects_frames"):
		var effect_action := action.duplicate()
		effect_action.frames = action.effects_frames
		effect = _texture(effect_action,index)
	return {"texture":texture,"effects_texture":effect,"action":name,"frame":index,"stone_armor_stage":stage,"source_action":key}
