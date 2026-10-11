extends SceneTree
const Combat=preload("res://scripts/core/phase3_combat.gd")
const Replay=preload("res://scripts/ui/phase3_combat_player.gd")
const Visual=preload("res://scripts/ui/phase3_enemy_player.gd")
const Catalog=preload("res://assets/monsters/phase3/phase3_enemy_animation_catalog.gd")
var checks:=0
var failures:=0
var decoded_peak:=0
func check(ok:bool,label:String)->void:
	checks+=1
	if not ok:
		failures+=1
		push_error("FAIL "+label)
func report(attack:int,retaliation:int=0)->Dictionary:
	var effects=[] if retaliation==0 else [{"id":"retaliation","source_item_id":"probe","amount":retaliation,"charges":999}]
	return Combat.simulate({"hp":1000},{"id":"golem","hp":250,"attack":28,"defense":14,"gold_reward":120,"ability_id":"stone_armor"},{"attack":attack,"defense":35,"max_hp":1000,"kill_heal":0,"gold_bonus":0,"combat_effects":effects})
func _initialize()->void:
	if not ProjectSettings.globalize_path("user://").replace("\\","/").contains("08-parallel/golem_refine/"):
		quit(2)
		return
	_run.call_deferred()
func _run()->void:
	check(Catalog.stone_armor_design().get("reachable_enhancements")==4,"five design states include base")
	var v=Visual.new()
	v.configure("golem",{})
	check(v.cache_bytes==0 and v.actions.size()==25,"metadata only, no full-tier preload")
	var idle_hashes={}
	for tier in range(5):
		for name in ["idle","attack","hit","armor","defeat"]:
			var key=name if tier==0 else "%s_armor_%d"%[name,tier]
			var d=Catalog.describe_action("golem",key)
			check(d.ok,"accepted tier action "+key)
			if not d.ok:continue
			if name=="idle":idle_hashes[FileAccess.get_sha256(d.action.frames[0])]=true
			for channel in ["frames","effects_frames"]:
				var a=d.action.duplicate(true)
				a.frames=d.action[channel]
				for i in a.frames.size():
					var t=v._texture(a,i)
					check(t!=null and t.get_image().get_size()==Vector2i(256,256),"actual decoded tier frame "+key)
					check(v.cache_bytes<=8*1024*1024,"8MiB actual image data LRU")
					decoded_peak=maxi(decoded_peak,v.cache_bytes)
	check(idle_hashes.size()==5,"all five effects-off body states are distinct")
	for spec in [[65,0],[165,0],[63,2],[263,2],[264,0],[16,0]]:
		var r=report(spec[0],spec[1]);var before=r.duplicate(true)
		var plan=Replay.build_plan(r,"boss");v.configure("golem",plan)
		check(plan.ok,"real rule report valid")
		var cumulative:=0
		for index in r.log.size():
			var entry:Dictionary=r.log[index]
			var stages=Replay.stage_effects(entry)
			for stage in ["mechanism","after_retaliation"]:
				for e in stages[stage]:
					if e.id=="stone_armor":cumulative+=int(e.amount)
			if index in plan.selected_indices:
				var next_index=plan.selected_indices.find(index)+1
				var end=plan.duration
				if next_index<plan.selected_indices.size():
					var next_turn=plan.selected_indices[next_index]+1
					for c in plan.cues:
						if c.kind=="prepare" and c.turn==next_turn:end=float(c.at)-.001
				check(v.stone_armor_stage_at(end)==clampi(cumulative/2,0,4),"omitted true events carried in replay order")
		check(v.stone_armor_stage_at(999,true)==clampi(cumulative/2,0,4),"skip retains final true armor")
		if spec[0]==165:check(plan.stone_armor_states[1].stage==3,"one hit crosses three thresholds once")
		if spec[0]==264:check(cumulative==0,"direct kill never creates reinforcement")
		if spec[0]==263:check(cumulative==8,"retaliation fatal never creates fifth reinforcement")
		if spec[0]==63:
			var mech:Dictionary=plan.cues.filter(func(c):return c.kind=="mechanism")[0]
			var thorn:Dictionary=plan.cues.filter(func(c):return c.kind=="retaliation")[0]
			check(mech.at>thorn.at and v.stone_armor_stage_at(thorn.at)==0,"armor after retaliation follows actual event")
		for state in plan.stone_armor_states:
			var f=v.frame_at(state.at+.00001)
			check(f.stone_armor_stage==state.stage,"arbitrary seek reconstructs true tier")
		v.effects_enabled=false
		var f=v.frame_at(.9)
		check(f.get("effects_texture")==null and f.texture!=null,"effect disable preserves physical armor body")
		check(v.frame_at(.9,false,false,true).frame==0,"reduced mode stable tier pose")
		check(r==before,"visual sampling leaves committed report unchanged")
		# Old records with notes but no ordered events stay at base.
		for e in r.log:e.erase("effect_events")
		r.erase("effects_triggered")
		v.configure("golem",Replay.build_plan(r,"boss"))
		check(v.stone_armor_stage_at(999,true)==0,"old notes/HP cannot fabricate reinforcement")
	# Pause and restart are deterministic queries; missing active frame falls back.
	v.configure("golem",Replay.build_plan(report(65),"boss"))
	var original=v.frame_at(1.1)
	check(v.frame_at(1.1).texture==original.texture,"pause keeps exact frame")
	v.frame_at(999,true,true)
	check(v.frame_at(0).stone_armor_stage==0,"replay backwards starts at base")
	var broken=v.actions.idle.duplicate(true)
	# Deliberately missing test path, assembled at runtime; not a project preload.
	broken.frames=[Catalog.ROOT+"textures/v06/golem/"+"missing.png"]
	v.actions.idle=broken
	check(v.frame_at(0).action=="static","missing frame safe fallback")
	print("Golem v06: %d checks, %d failures"%[checks,failures])
	FileAccess.open("res://build/verification/phase3/09-refinement/golem/protocol-results.json",FileAccess.WRITE).store_string(JSON.stringify({"checks":checks,"failures":failures,"actual_image_data_peak":decoded_peak},"\t"))
	quit(0 if failures==0 else 1)
