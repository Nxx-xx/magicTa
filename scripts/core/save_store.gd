class_name SaveStore
extends RefCounted
## One envelope commits run + meta together, so a finished run cannot award twice.
## RNG seed/state are stored as decimal strings (JSON numbers lose 64-bit precision).

const DEFAULT_PATH := "user://tower_save.json"
const VERSION := 1
var path: String
var last_error := ""

func _init(save_path: String = DEFAULT_PATH) -> void:
	path = save_path

func read() -> Dictionary:
	last_error = ""
	if not FileAccess.file_exists(path) and not FileAccess.file_exists(path + ".bak"):
		return {}
	for candidate in [path, path + ".bak"]:
		var file := FileAccess.open(candidate, FileAccess.READ)
		if file == null:
			continue
		var value = JSON.parse_string(file.get_as_text())
		if _valid(value):
			if candidate != path:
				last_error = "主存档损坏，已读取上一次备份。"
			return value
	last_error = "存档无法读取。原文件已保留；开始新旅程会建立新存档。"
	return {}

func write(run: Dictionary, meta: Dictionary) -> bool:
	last_error = ""
	var temporary := path + ".tmp"
	var file := FileAccess.open(temporary, FileAccess.WRITE)
	if file == null:
		last_error = "无法写入存档：请检查存储空间或浏览器权限。"
		return false
	file.store_string(JSON.stringify({"version": VERSION, "run": run, "meta": meta}))
	file.flush()
	var write_error := file.get_error()
	file.close()
	if write_error != OK:
		last_error = "存档写入失败，本次进度尚未保存。"
		return false
	var absolute := ProjectSettings.globalize_path(path)
	var temp_absolute := ProjectSettings.globalize_path(temporary)
	var backup := absolute + ".bak"
	if FileAccess.file_exists(path):
		if FileAccess.file_exists(path + ".bak"):
			DirAccess.remove_absolute(backup)
		if DirAccess.rename_absolute(absolute, backup) != OK:
			last_error = "无法轮换旧存档，本次进度尚未保存。"
			return false
	if DirAccess.rename_absolute(temp_absolute, absolute) != OK:
		last_error = "无法提交存档；旧进度仍保存在备份中。"
		return false
	return true

func _valid(value: Variant) -> bool:
	if not value is Dictionary or value.get("version", 0) != VERSION:
		return false
	if not value.get("meta") is Dictionary or not value.get("run") is Dictionary:
		return false
	var meta: Dictionary = value.meta
	if not meta.get("upgrades") is Dictionary:
		return false
	for key in ["hp", "attack", "gold"]:
		if not meta.upgrades.has(key) or int(meta.upgrades[key]) < 0 or int(meta.upgrades[key]) > 3:
			return false
	if not meta.has("souls") or int(meta.souls) < 0:
		return false
	if meta.has("records"):
		if not meta.records is Array:
			return false
		for record in meta.records:
			if not record is Dictionary:
				return false
			for key in ["seed", "result", "floor", "souls", "seconds"]:
				if not record.has(key):
					return false
	var run: Dictionary = value.run
	if run.is_empty():
		return true
	for key in ["seed", "rng_state", "floor", "player", "room_options", "phase",
			"completed", "result", "history", "selected_room", "pending_choices", "kills",
			"last_report", "last_message", "played_seconds", "soul_reward"]:
		if not run.has(key):
			return false
	if not run.player is Dictionary or not run.room_options is Array:
		return false
	for key in ["hp", "max_hp", "attack", "defense", "gold", "keys", "equipment_ids", "relic_ids"]:
		if not run.player.has(key):
			return false
	if not run.player.equipment_ids is Array or not run.player.relic_ids is Array:
		return false
	if not run.history is Array or not run.pending_choices is Array or not run.last_report is Dictionary:
		return false
	if not run.selected_room is Dictionary or not run.completed is bool:
		return false
	if not str(run.seed).is_valid_int() or not str(run.rng_state).is_valid_int():
		return false
	for entry in run.history:
		if not entry is Dictionary or not entry.has("floor") or not entry.has("summary"):
			return false
	if not run.last_report.is_empty():
		for key in ["incoming", "healing", "loss", "log"]:
			if not run.last_report.has(key):
				return false
		if not run.last_report.log is Array:
			return false
		for entry in run.last_report.log:
			if not entry is Dictionary:
				return false
			for key in ["turn", "hit", "enemy_hp", "counter", "hp", "note"]:
				if not entry.has(key):
					return false
	if int(run.floor) < 1 or int(run.floor) > 10:
		return false
	if run.phase not in ["rooms", "shop", "event", "rest", "reward", "ended"]:
		return false
	if bool(run.completed) != (run.phase == "ended"):
		return false
	if run.phase == "rooms" and run.room_options.size() != (1 if int(run.floor) in [5, 10] else 3):
		return false
	for room in run.room_options:
		if not _valid_room(room):
			return false
	if run.phase in ["shop", "event", "rest", "reward"] and not _valid_room(run.selected_room):
		return false
	if run.phase == "reward" and run.pending_choices.size() != 2:
		return false
	return true

func _valid_room(room: Variant) -> bool:
	if not room is Dictionary:
		return false
	for key in ["id", "floor", "type", "name", "enemy_id", "event_id", "lock_cost"]:
		if not room.has(key):
			return false
	match str(room.type):
		"normal", "elite", "boss":
			return not str(room.enemy_id).is_empty() and room.get("rewards") is Array
		"shop":
			return room.get("offers") is Array and room.offers.size() == 3
		"chest":
			return room.has("item_id") and room.has("gold") and room.has("reward_text")
		"event":
			return not str(room.event_id).is_empty()
		"rest":
			return true
	return false
