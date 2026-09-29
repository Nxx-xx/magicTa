extends RefCounted
## Presentation settings and personal map pins never consume gameplay RNG.
const PATH := "user://presentation.cfg"
var muted := false
var effects_volume := 0.45
var voice_volume := 0.45
var punishment_voice := true
var reduce_motion := false
var pins: Dictionary = {}
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
	var error := config.save(PATH)
	last_error = "偏好设置保存失败，请检查存储空间。" if error != OK else ""
	return error == OK
