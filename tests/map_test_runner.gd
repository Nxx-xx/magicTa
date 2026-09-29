extends SceneTree
## Calls production map/combat/save code. Does not replace engine execution.
const Core = preload("res://scripts/core/map_engine.gd")
var checks := 0
var failures := 0
var path := "user://map_test_%d.json" % OS.get_process_id()

func _initialize() -> void:
	_test_return_trip()
	_test_shop()
	_test_treasure()
	_test_save_and_seed()
	for suffix in ["", ".bak", ".tmp"]:
		if FileAccess.file_exists(path + suffix):
			DirAccess.remove_absolute(ProjectSettings.globalize_path(path + suffix))
	print("Map tests: %d checks, %d failures" % [checks, failures])
	quit(1 if failures else 0)

func _check(value: bool, label: String) -> void:
	checks += 1
	if not value:
		failures += 1
		push_error("FAIL: " + label)

func _new_game(seed_text: String = "42"):
	var core = Core.new(path)
	core.persistence_enabled = false
	core.start(seed_text)
	return core

func _walk(core, target: Vector2i) -> void:
	# Movement through the real API, with a BFS path over noncombat cells.
	# Interactive target is allowed, but may leave the player adjacent to it.
	var start: Vector2i = core.position()
	var queue: Array[Vector2i] = [start]
	var previous: Dictionary = {start: start}
	while not queue.is_empty() and not previous.has(target):
		var current: Vector2i = queue.pop_front()
		for direction in [Vector2i.UP, Vector2i.RIGHT, Vector2i.DOWN, Vector2i.LEFT]:
			var next: Vector2i = current + direction
			if core.is_wall(next) or previous.has(next):
				continue
			var entity: Dictionary = core.entity_at(next)
			if next != target and entity.get("type", "") in ["enemy", "door", "up", "down"]:
				continue
			previous[next] = current
			queue.append(next)
	if not previous.has(target):
		_check(false, "safe route exists to " + str(target))
		return
	var route: Array[Vector2i] = []
	var cursor := target
	while cursor != start:
		route.push_front(cursor)
		cursor = previous[cursor]
	for cell in route:
		var result: String = core.step(cell - core.position())
		_check(result.is_empty(), "movement accepted at " + str(cell))
		if not core.state.pending.is_empty() and cell != target:
			var entity: Dictionary = core.entity_at(core.pending_cell())
			_check(entity.get("type", "") == "shop", "only an en-route shop may interrupt path")
			core.cancel_pending()

func _ascend(core, theme_id: String) -> void:
	_walk(core, Vector2i(9, 1))
	_check(core.state.pending.get("kind", "") == "floor_choice", "first ascent shows three choices")
	core.choose_floor(theme_id)
	_check(core.state.floor == 2 and core.position() == Vector2i(1, 9), "ascent arrives on downstairs without bouncing")

func _test_return_trip() -> void:
	var core = _new_game()
	_check(core.errors.is_empty(), "map content loads")
	_check(core.preview(Vector2i(5, 7)).lethal, "first-floor guard starts too strong")
	var start: Vector2i = core.position()
	_check(not core.step(Vector2i.DOWN).is_empty() and core.position() == start, "wall blocks movement")
	_check(not core.step(Vector2i(1, 1)).is_empty(), "diagonal movement rejected")
	_check(not core.interact(Vector2i(9, 1)).is_empty(), "cannot teleport by clicking a remote cell")
	_walk(core, Vector2i(1, 4))
	core.step(Vector2i.UP)
	_check(not core.confirm_interaction().is_empty(), "door rejects missing key")
	core.cancel_pending()
	_walk(core, Vector2i(2, 5))
	_check(core.state.player.keys == 1, "key picked up")
	_walk(core, Vector2i(1, 5))
	_walk(core, Vector2i(2, 5))
	_check(core.state.player.keys == 1, "key cannot be farmed")
	# Keep the key for later: no armor from floor one is required for this route.
	_ascend(core, "battle")
	_walk(core, Vector2i(3, 9))
	_walk(core, Vector2i(5, 7))
	_check(core.stats().attack == 20 and core.stats().defense == 9, "shared second-floor supplies improve stats")
	var floor_two: Dictionary = core.floor_data().duplicate(true)
	_walk(core, Vector2i(1, 9))
	core.confirm_interaction()
	_check(core.state.floor == 1 and core.position() == Vector2i(9, 1), "descending returns to first-floor upstairs")
	_check(core.entity_at(Vector2i(2, 5)).is_empty(), "old key stays removed across floors")
	var predicted: Dictionary = core.preview(Vector2i(5, 7))
	_check(not predicted.lethal and predicted.loss == 77, "returning guard is now survivable without first-floor armor")
	_walk(core, Vector2i(5, 6))
	core.step(Vector2i.DOWN)
	_check(core.state.pending.kind == "entity", "bumping guard previews before resolution")
	core.confirm_interaction()
	_check(core.state.player.hp == predicted.hp_after and core.entity_at(Vector2i(5, 7)).is_empty(), "fight matches preview and removes guard")
	_walk(core, Vector2i(7, 9))
	_check(core.state.objective_complete and core.state.player.equipment_ids.has("sovereign_ring"), "guarded trophy completes return-trip objective")
	var gold := int(core.state.player.gold)
	_walk(core, Vector2i(6, 9))
	_walk(core, Vector2i(7, 9))
	_check(core.state.player.gold == gold, "trophy cannot be collected twice")
	_walk(core, Vector2i(1, 3))
	core.confirm_interaction()
	_check(core.state.player.keys == 0 and core.entity_at(Vector2i(1, 3)).is_empty(), "unlock consumes one key and permanently removes door")
	_walk(core, Vector2i(9, 1))
	_check(core.state.pending.kind == "stairs", "repeat ascent skips theme selection")
	_check(not core.choose_floor("shop").is_empty(), "cannot reroll an explored floor")
	core.confirm_interaction()
	_check(core.floor_data() == floor_two, "second floor remains exactly as left")
	core.interact(core.position())
	core.confirm_interaction()
	_check(core.entity_at(Vector2i(1, 3)).is_empty() and core.entity_at(Vector2i(5, 7)).is_empty(), "opened door and killed guard remain cleared after another visit")

func _test_shop() -> void:
	var core = _new_game()
	_ascend(core, "shop")
	_walk(core, Vector2i(9, 7))
	_check(core.position() == Vector2i(9, 7), "merchant tile is passable while trade opens")
	_check(not core.buy(0).is_empty(), "insufficient gold does not buy")
	core.cancel_pending()
	_walk(core, Vector2i(7, 9))
	_check(core.state.player.keys == 2, "can reach reward behind merchant without buying")
	_walk(core, Vector2i(1, 7))
	_check(core.state.player.gold == 30, "collect money then return to merchant")
	_walk(core, Vector2i(9, 7))
	core.buy(0)
	_check(core.state.player.gold == 0 and core.entity_at(Vector2i(9, 7)).purchased, "purchase persists and charges once")
	core.interact(core.position())
	_check(not core.buy(0).is_empty() and core.state.player.gold == 0, "merchant cannot sell again")
	core.cancel_pending()
	_walk(core, Vector2i(1, 9))
	core.confirm_interaction()
	core.interact(core.position())
	core.confirm_interaction()
	_check(core.entity_at(Vector2i(9, 7)).purchased, "merchant purchase persists across floors")

func _test_treasure() -> void:
	var core = _new_game()
	_ascend(core, "treasure")
	_walk(core, Vector2i(5, 3))
	core.confirm_interaction()
	_check(core.entity_at(Vector2i(5, 3)).is_empty(), "key from floor one opens treasure door")
	_walk(core, Vector2i(1, 1))
	_check(core.entity_at(Vector2i(1, 1)).is_empty(), "treasure chest collected")
	_walk(core, Vector2i(1, 3))
	_check(core.state.player.keys == 1, "treasure branch refunds a key after opening")
	_walk(core, Vector2i(1, 5))
	var health := int(core.state.player.hp)
	_walk(core, Vector2i(1, 6))
	_walk(core, Vector2i(1, 5))
	_check(core.state.player.hp == health and core.entity_at(Vector2i(1, 5)).is_empty(), "fountain does not refill on revisit")

func _test_save_and_seed() -> void:
	var original = _new_game("123456")
	original.persistence_enabled = true
	_walk(original, Vector2i(9, 1))
	var restored = Core.new(path)
	restored.load_game()
	_check(restored.state.pending.kind == "floor_choice" and restored.state.floors.size() == 1, "reload keeps pending first-ascent choice")
	original.choose_floor("battle")
	restored.choose_floor("battle")
	_check(original.state.floors == restored.state.floors and original.rng.state == restored.rng.state, "same seed and saved RNG create identical theme contents")
	_walk(original, Vector2i(3, 9))
	_walk(original, Vector2i(1, 9))
	original.confirm_interaction()
	var loaded = Core.new(path)
	loaded.load_game()
	_check(loaded.state.floor == 1 and loaded.state.floors["2"].entities.get("3,9", {}).is_empty(), "save preserves inactive-floor collected chest")
	_check(loaded.state.player.equipment_ids.has("dawn_spear"), "global equipment survives reload and descent")
	_walk(loaded, Vector2i(5, 6))
	loaded.step(Vector2i.DOWN)
	_check(loaded.confirm_interaction() == "confirm_lethal", "lethal guard still needs extra confirmation before armor")
	loaded.cancel_pending()
	loaded.save_game()
	var file := FileAccess.open(path, FileAccess.WRITE)
	file.store_string("{broken")
	file.close()
	var recovered = Core.new(path)
	recovered.load_game()
	_check(not recovered.state.is_empty() and not recovered.save_error.is_empty(), "map save recovers backup")
