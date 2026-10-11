extends RefCounted
## Short, quiet procedural effects. Optional recorded voices have an explicit map.
## These synthesized tones are not a human scream or dialogue recording.
const VOICES := {
	"echo_1": "res://assets/audio/phase2/prince_cry_1.wav",
	"echo_2": "res://assets/audio/phase2/prince_cry_2.wav",
	"echo_3": "res://assets/audio/phase2/prince_cry_3.wav"
}
static var streams: Dictionary = {}
const STEP_GAIN := 0.30
const STEP_VARIATIONS := [0.94, 1.0, 0.97, 0.91, 1.0, 0.95]
var player: AudioStreamPlayer
var native_audio: JavaScriptObject
var last_cue := ""
var last_tick := 0
var footstep_player: AudioStreamPlayer
var footstep_side := false
var native_steps: JavaScriptObject
var step_index := 0

func prepare_steps() -> void:
	for cue in ["step", "step_alt"]:
		if not streams.has(cue): streams[cue] = _tone(cue)
	if OS.has_feature("web"):
		var bridge = JavaScriptBridge.get_interface("__towerAudio")
		if bridge != null: bridge.prepareSteps()

func play_step(tree: SceneTree, settings) -> void:
	if settings.muted or settings.effects_volume <= 0:
		stop_steps()
		return
	footstep_side = not footstep_side
	var cue := "step" if footstep_side else "step_alt"
	var volume: float = settings.effects_volume * STEP_GAIN * STEP_VARIATIONS[step_index % STEP_VARIATIONS.size()]
	step_index += 1
	if OS.has_feature("web"):
		var bridge = JavaScriptBridge.get_interface("__towerAudio")
		if bridge != null and bool(bridge.playStep(cue, volume)):
			native_steps = bridge
			return
	if not streams.has(cue): prepare_steps()
	if not is_instance_valid(footstep_player):
		footstep_player = AudioStreamPlayer.new()
		tree.root.add_child(footstep_player)
	footstep_player.stream = streams[cue]
	footstep_player.volume_db = linear_to_db(maxf(0.0001, volume))
	footstep_player.play()

func stop_steps() -> void:
	if native_steps != null:
		native_steps.stopSteps()
		native_steps = null
	if is_instance_valid(footstep_player):
		footstep_player.stop()
		footstep_player.queue_free()
	footstep_player = null

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
	if OS.has_feature("web"):
		var bridge = JavaScriptBridge.get_interface("__towerAudio")
		if bridge != null:
			stop()
			native_audio = bridge
			var volume: float = settings.voice_volume if voice else settings.effects_volume
			if bool(bridge.playCue(cue, volume, voice)):
				return
			native_audio = null
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
	stop_steps()
	if native_audio != null:
		native_audio.stop()
		native_audio = null
	if is_instance_valid(player):
		player.stop()
		player.queue_free()
	player = null

static func _tone(cue: String) -> AudioStreamWAV:
	var duration := 0.09
	var frequency := 180.0
	match cue:
		"step", "step_alt":
			duration = 0.095
			frequency = 132.0 if cue == "step" else 124.0
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
			duration = 0.85
			frequency = 440.0
		"echo", "echo_curse", "failure", "failure_1", "failure_2", "failure_3":
			duration = 0.8
			frequency = 145.0
	var samples := int(duration * 22050)
	var data := PackedByteArray()
	data.resize(samples * 2)
	var foot_noise := RandomNumberGenerator.new()
	foot_noise.seed = 719 if cue == "step" else 1024
	var filtered_noise := 0.0
	for i in samples:
		var t := float(i) / 22050.0
		var envelope := sin(PI * float(i) / samples) * exp(-t * 4.0)
		var value := sin(TAU * frequency * t + sin(t * 19.0) * 0.6) * envelope * 0.35
		if cue in ["step", "step_alt"]:
			# Leather boot contact on stone: short low impact with a dry scuff.
			# Local seeded noise never advances the gameplay random generator.
			filtered_noise = lerpf(filtered_noise, foot_noise.randf_range(-1.0, 1.0), 0.24)
			var attack := smoothstep(0.0, 0.004, t)
			# Brief heel impact, then a quieter sole scrape; no ringing bass note.
			var impact := sin(TAU * (frequency * t - 160.0 * t * t)) * exp(-t * 95.0) * 0.27
			var scuff := filtered_noise * exp(-t * 46.0) * 0.65
			var sole := filtered_noise * exp(-absf(t - 0.022) * 140.0) * 0.16
			value = (impact + scuff + sole) * attack * smoothstep(0.0, 0.015, duration - t)
		if cue == "victory":
			# Rising major arpeggio with a gentle sustained final chord.
			var notes := [523.25, 659.25, 783.99, 1046.5]
			var note_index := mini(3, int(t / 0.14))
			var local_time := t - note_index * 0.14
			var attack := minf(1, local_time / 0.012)
			value = sin(TAU * notes[note_index] * local_time) * attack * exp(-local_time * 4) * 0.3
			if note_index == 3:
				value += (sin(TAU * 659.25 * local_time) + sin(TAU * 783.99 * local_time)) * attack * exp(-local_time * 5) * 0.09
			value *= clampf((duration - t) / 0.08, 0, 1)
		data.encode_s16(i * 2, int(value * 32767))
	var stream := AudioStreamWAV.new()
	stream.format = AudioStreamWAV.FORMAT_16_BITS
	stream.mix_rate = 22050
	stream.data = data
	return stream
