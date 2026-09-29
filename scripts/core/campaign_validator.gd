extends RefCounted
## Validate freshly generated geometry separately from mutated save state.
static func validate(map: Dictionary) -> Array[String]:
	var errors: Array[String] = []
	if map.get("rows", []).size() != 11:
		return ["战役地图尺寸错误。"]
	var entry := Vector2i(map.entry[0],map.entry[1])
	var exit := Vector2i(map.exit[0],map.exit[1])
	var safe := reachable(map, entry, true)
	var all_cells := reachable(map, entry, false)
	if not all_cells.has(exit):
		errors.append("楼梯之间不连通。")
	if bool(map.boss_floor):
		if safe.has(exit):
			errors.append("Boss 进度门槛可以绕过。")
		if not safe.has(Vector2i(5,8)):
			errors.append("Boss 前无法安全撤退。")
	elif not safe.has(exit):
		errors.append("普通层缺少安全往返主路。")
	for key in map.entities:
		var entity: Dictionary = map.entities[key]
		var pos := Vector2i(entity.pos[0],entity.pos[1])
		if not all_cells.has(pos):
			errors.append("实体无法到达：" + str(key))
		if entity.type == "door":
			var matching := false
			for other in map.entities.values():
				if other.type == "key" and other.get("key_kind", "copper") == entity.get("key_kind", "copper") and safe.has(Vector2i(other.pos[0],other.pos[1])):
					matching = true
			if not matching:
				errors.append("门前缺少可达同色钥匙。")
	for branch in map.get("branch_paths", []):
		var guard: Dictionary = map.entities.get("%d,%d" % branch[0], {})
		if guard.get("type", "") in ["enemy","door"]:
			if safe.has(Vector2i(branch[-1][0],branch[-1][1])):
				errors.append("支路守卫可绕过。")
	return errors

static func reachable(map: Dictionary, start: Vector2i, block: bool) -> Dictionary:
	var visited := {start:true}
	var queue: Array[Vector2i] = [start]
	while not queue.is_empty():
		var current: Vector2i = queue.pop_front()
		for d in [Vector2i.UP,Vector2i.DOWN,Vector2i.LEFT,Vector2i.RIGHT]:
			var cell: Vector2i = current + d
			if cell.x < 0 or cell.y < 0 or cell.x >= 11 or cell.y >= 11 or visited.has(cell):
				continue
			if str(map.rows[cell.y]).substr(cell.x,1) == "#":
				continue
			var entity: Dictionary = map.entities.get("%d,%d" % [cell.x,cell.y], {})
			if block and entity.get("type", "") in ["enemy","door"]:
				continue
			visited[cell] = true
			queue.append(cell)
	return visited

