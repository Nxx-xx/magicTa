extends RefCounted
## Story only mutates the caller's candidate. It never consumes map RNG or writes a save.
const VERSION := 1

static func initialize(state: Dictionary, meta: Dictionary) -> void:
	state.story_version = VERSION
	state.story = {"queue": [], "seen": []}
	enqueue(state, "intro" if int(meta.get("runs", 0)) == 0 else "retry")

static func enqueue(state: Dictionary, event_id: String) -> void:
	if not state.has("story"):
		state.story = {"queue": [], "seen": []}
	if event_id in state.story.seen:
		return
	var file := FileAccess.open("res://data/story.json", FileAccess.READ)
	if file == null:
		return
	var content = JSON.parse_string(file.get_as_text())
	if not content is Dictionary or not content.get("events", {}).has(event_id):
		return
	state.story.seen.append(event_id)
	var event: Dictionary = content.events[event_id].duplicate(true)
	event.id = event_id
	state.story.queue.append(event)

static func on_floor(state: Dictionary) -> void:
	enqueue(state, "floor_%d" % int(state.floor))

static func on_failure(state: Dictionary, failure_count: int) -> void:
	# Each run can die once. Variant selection is deterministic and independent of map RNG.
	var variant := failure_count if failure_count <= 3 else 4 + ((failure_count - 4) % 2)
	state.story.queue.clear()
	enqueue(state, "death_%d" % variant)
	if not state.story.queue.is_empty():
		state.story.queue.back().event_key = str(state.run_id) + ":death"

static func on_victory(state: Dictionary) -> void:
	state.story.queue.clear()
	enqueue(state, "victory")

static func restore_summary(state: Dictionary) -> void:
	# Loading a finished run must never replay its immediate failure sound.
	if state.get("result", "") == "death":
		for event in state.get("story", {}).get("queue", []):
			event.audio_cue = ""
			event.static_summary = true
