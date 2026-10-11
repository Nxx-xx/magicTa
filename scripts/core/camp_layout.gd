extends RefCounted
## Camp navigation is presentation-only; never writes to the tower run/save schema.
const SPAWN := Vector2i(5, 8)
const KNIGHT := Vector2i(2, 3)
const DEATH := Vector2i(7, 4)
const TOWER := Vector2i(5, 1)
const ROWS := [
	"###########", "####...####", "#......####", "#......####",
	"#.......###", "#.......###", "####....###", "####......#",
	"#.........#", "#.........#", "###########",
]

static func floor_data() -> Dictionary:
	return {"floor":0, "floor_seed":"camp_v2", "name":"归途营地", "rows":ROWS,
		"entities": {"2,3":{"type":"camp_knight", "name":"神秘的老骑士"},
			"7,4":{"type":"camp_death", "name":"死神"},
			"5,1":{"type":"camp_tower", "name":"魔塔入口"},
			"6,6":{"type":"camp_decor", "name":"营火石圈"},
			"6,7":{"type":"camp_fire", "name":"归途灯"}}}

static func walkable(cell: Vector2i) -> bool:
	return cell.x >= 0 and cell.y >= 0 and cell.x < 11 and cell.y < 11 and ROWS[cell.y][cell.x] != "#" and not floor_data().entities.has("%d,%d" % [cell.x,cell.y])

static func interaction(cell: Vector2i) -> String:
	if cell == KNIGHT: return "knight"
	if cell == DEATH: return "death"
	if cell == TOWER: return "tower"
	return ""

static func path(from: Vector2i, target: Vector2i) -> Array[Vector2i]:
	var result: Array[Vector2i] = []
	if not walkable(from): return result
	var is_interaction := not interaction(target).is_empty()
	if not is_interaction and not walkable(target): return result
	var frontier: Array[Vector2i] = [from]
	var previous := {from: from}
	var cursor := 0
	while cursor < frontier.size():
		var cell := frontier[cursor]
		cursor += 1
		if cell == target or (is_interaction and absi(cell.x-target.x) + absi(cell.y-target.y) == 1):
			while cell != from:
				result.push_front(cell)
				cell = previous[cell]
			return result
		for direction in [Vector2i.UP, Vector2i.LEFT, Vector2i.RIGHT, Vector2i.DOWN]:
			var next: Vector2i = cell + direction
			if walkable(next) and not previous.has(next):
				previous[next] = cell
				frontier.append(next)
	return result
