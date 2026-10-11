extends SceneTree
## Explicit visual protocol fixture in the production replay UI; not a campaign fight.
const Player = preload("res://scripts/ui/phase3_combat_player.gd")
const Fixture = preload("res://tests/phase3_animation_fixture.gd")
const OUT := "res://build/verification/hero-motion/after-ui/"
var failures := 0
var checks := 0
func check(ok: bool,label: String) -> void:
	checks += 1
	if not ok:
		failures += 1
		push_error("FAIL "+label)
func _initialize() -> void:
	if not ProjectSettings.globalize_path("user://").replace("\\","/").contains("hero-motion/"):
		quit(2)
		return
	_run.call_deferred()
func _run() -> void:
	DirAccess.make_dir_recursive_absolute(OUT)
	root.min_size = Vector2i(320,640)
	for width in [540,320]:
		root.size = Vector2i(width,960 if width==540 else 640)
		var report := Fixture.report(6)
		var before := report.duplicate(true)
		var host := Player.new()
		check(host.configure(report,true,{"enemy_id":"slime","enemy_name":"史莱姆 · 视觉协议夹具"}).ok,"production replay fixture")
		root.add_child(host)
		host.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
		host.set_process(false)
		for i in 8: await process_frame
		for action in ["idle","attack","guard","hit","victory","defeat"]:
			host._action = "combat_"+action
			host._action_start = 0
			host._action_speed = 1
			host._elapsed = {"idle":.16,"attack":3.0/16+.001,"guard":2.0/12+.001,"hit":1.0/12+.001,"victory":4.0/12+.001,"defeat":5.0/10+.001}[action]
			host._cue.text = "公主动作 v07 · "+action+"（视觉采样，非真实回合）"
			for effects in [true,false]:
				host._catalog.effects_enabled = effects
				host._render_frame()
				for i in 3: await process_frame
				await RenderingServer.frame_post_draw
				check(host._sprite.texture != null,"visible "+action)
				check(not host._sprite.get_global_rect().intersects(host._cue.get_global_rect()),"hero/label separation")
				check(host._primary.get_global_rect().end.y<=host.get_global_rect().end.y+1,"footer fits")
				root.get_texture().get_image().save_png(OUT+"%s_%d_%s.png" % [action,width,"fx" if effects else "body"])
		check(report==before and host.full_report()==before,"art sampling never mutates report")
		host.queue_free()
		await process_frame
	FileAccess.open(OUT+"results.json",FileAccess.WRITE).store_string(JSON.stringify({"checks":checks,"failures":failures,"scope":"Production replay UI with explicit protocol fixture and requested hero action/frame samples at 540/320px, body and FX; not natural campaign outcomes."},"\t"))
	print("Hero action UI: %d checks, %d failures" % [checks,failures])
	quit(1 if failures else 0)
