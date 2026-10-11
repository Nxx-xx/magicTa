extends RefCounted
## Presentation settings and personal map pins never consume gameplay RNG.
const PATH := "user://presentation.cfg"
const Tutorial = preload("res://scripts/ui/phase3_tutorial.gd")
var tutorial: Dictionary = Tutorial.initial_state()
var muted := false
var effects_volume := 0.45
var voice_volume := 0.45
var punishment_voice := true
var reduce_motion := false
var pins: Dictionary = {}
var seen_mechanics: Dictionary = {}
var fought_mechanics: Dictionary = {}
var last_error := ""

func read() -> void:
	var config := ConfigFile.new()
	if config.load(PATH) != OK:
		return
	muted = bool(config.get_value("audio", "muted", false))
	effects_volume = clampf(float(config.get_value("audio", "effects_volume", 0.45)), 0.0, 1.0)
	voice_volume = clampf(float(config.get_value("audio", "voice_volume", 0.45)), 0.0, 1.0)
	punishment_voice = bool(config.get_value("audio", "punishment_voice", true))
	reduce_motion = bool(config.get_value("display", "reduce_motion", false))
	var saved = config.get_value("map", "pins", {})
	if saved is Dictionary:
		pins = saved
	var seen: Variant = config.get_value("encounters", "seen", {})
	var fought: Variant = config.get_value("encounters", "fought", {})
	if seen is Dictionary: seen_mechanics = seen
	if fought is Dictionary: fought_mechanics = fought
	var lesson: Variant = config.get_value("tutorial_v1", "state", {})
	if lesson is Dictionary and not lesson.is_empty():
		var restored := Tutorial.restore(lesson)
		if restored.ok: tutorial = restored.state

func write() -> bool:
	var config := ConfigFile.new()
	config.set_value("audio", "muted", muted)
	config.set_value("audio", "effects_volume", effects_volume)
	config.set_value("audio", "voice_volume", voice_volume)
	config.set_value("audio", "punishment_voice", punishment_voice)
	config.set_value("display", "reduce_motion", reduce_motion)
	# Keep a bounded set of journeys; pins carry no player resources.
	while pins.size() > 20:
		pins.erase(pins.keys()[0])
	config.set_value("map", "pins", pins)
	config.set_value("encounters", "seen", seen_mechanics)
	config.set_value("encounters", "fought", fought_mechanics)
	config.set_value("tutorial_v1", "state", Tutorial.snapshot(tutorial))
	var error := config.save(PATH)
	if error == OK and not preload("res://scripts/core/platform_persistence.gd").flush():
		error = ERR_CANT_CREATE
	last_error = "偏好设置保存失败，请检查存储空间。" if error != OK else ""
	return error == OK
