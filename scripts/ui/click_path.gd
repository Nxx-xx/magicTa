extends RefCounted
## Plan only four-connected routes; the host still commits each step via interact().
const DIRECTIONS := [Vector2i.UP, Vector2i.RIGHT, Vector2i.DOWN, Vector2i.LEFT]
const TRANSIT_TYPES := ["gold", "key", "chest", "camp", "summit"]
const STAIR_STOP_TYPES := ["shop", "rest"]

static func transit_allowed(game, cell: Vector2i) -> bool:
	if game.is_wall(cell):
		return false
	var entity: Dictionary = game.entity_at(cell)
	return entity.is_empty() or str(entity.get("type", "")) in TRANSIT_TYPES

static func find(game, start: Vector2i, goal: Vector2i) -> Array[Vector2i]:
	var result: Array[Vector2i] = []
	if game.is_wall(goal) or goal == start:
		return result
	var stair_target: bool = str(game.entity_at(goal).get("type", "")) in ["up", "down"]
	var frontier: Array[Vector2i] = [start]
	var previous := {start: start}
	var cursor := 0
	while cursor < frontier.size():
		var current := frontier[cursor]
		cursor += 1
		for direction in DIRECTIONS:
			var next: Vector2i = current + direction
			if previous.has(next) or game.is_wall(next):
				continue
			# Stair routes may reach a merchant or fire, but must stop to interact.
			var stair_stop: bool = stair_target and str(game.entity_at(next).get("type", "")) in STAIR_STOP_TYPES
			if next != goal and not transit_allowed(game, next) and not stair_stop:
				continue
			previous[next] = current
			if next == goal:
				var cell := goal
				while cell != start:
					result.push_front(cell)
					cell = previous[cell]
				if stair_target:
					for index in result.size():
						if str(game.entity_at(result[index]).get("type", "")) in STAIR_STOP_TYPES:
							result.resize(index + 1)
							break
				return result
			frontier.append(next)
	return result
