extends RefCounted
## Short, quiet procedural effects. Optional recorded voices have an explicit map.
## These synthesized tones are not a human scream or dialogue recording.
const VOICES := {
	"echo_1": "res://assets/audio/phase2/prince_cry_1.wav",
	"echo_2": "res://assets/audio/phase2/prince_cry_2.wav",
	"echo_3": "res://assets/audio/phase2/prince_cry_3.wav"
}
static var streams: Dictionary = {}
var player: AudioStreamPlayer
var last_cue := ""
var last_tick := 0

func play(tree: SceneTree, cue: String, settings, voice: bool = false) -> void:
	if settings.muted or cue.is_empty():
		return
	if voice and not settings.punishment_voice:
		return
	var tick := Time.get_ticks_msec()
	if tick - last_tick < 140:
		return
	last_tick = tick
	last_cue = cue
	var stream: AudioStream
	if voice:
		var path: String = VOICES.get(cue, "")
		if path.is_empty() or not ResourceLoader.exists(path):
			return
		stream = load(path)
	else:
		if not streams.has(cue):
			streams[cue] = _tone(cue)
		stream = streams[cue]
	stop()
	player = AudioStreamPlayer.new()
	player.stream = stream
	player.volume_db = linear_to_db(maxf(0.0001, settings.voice_volume if voice else settings.effects_volume)) - 14.0
	tree.root.add_child(player)
	player.finished.connect(player.queue_free)
	player.play()

func play_story(tree: SceneTree, cue: String, settings) -> void:
	# Story has priority over a just-completed movement or combat sound.
	last_tick = -1000
	var path: String = VOICES.get(cue, "")
	if cue.begins_with("echo"):
		if settings.punishment_voice and not path.is_empty() and ResourceLoader.exists(path):
			play(tree, cue, settings, true)
		else:
			play(tree, "echo_curse", settings)
	else:
		play(tree, "victory", settings)

func stop() -> void:
	if is_instance_valid(player):
		player.stop()
		player.queue_free()
	player = null

static func _tone(cue: String) -> AudioStreamWAV:
	var duration := 0.09
	var frequency := 180.0
	match cue:
		"pickup":
			duration = 0.19
			frequency = 660.0
		"door":
			duration = 0.15
			frequency = 120.0
		"hit":
			duration = 0.13
			frequency = 82.0
		"victory", "rescue", "midpoint":
			duration = 0.5
			frequency = 440.0
		"echo", "echo_curse", "failure", "failure_1", "failure_2", "failure_3":
			duration = 0.8
			frequency = 145.0
	var samples := int(duration * 22050)
	var data := PackedByteArray()
	data.resize(samples * 2)
	for i in samples:
		var t := float(i) / 22050.0
		var envelope := sin(PI * float(i) / samples) * exp(-t * 4.0)
		var value := sin(TAU * frequency * t + sin(t * 19.0) * 0.6) * envelope * 0.35
		data.encode_s16(i * 2, int(value * 32767))
	var stream := AudioStreamWAV.new()
	stream.format = AudioStreamWAV.FORMAT_16_BITS
	stream.mix_rate = 22050
	stream.data = data
	return stream
