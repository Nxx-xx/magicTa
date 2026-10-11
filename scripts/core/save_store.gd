class_name SaveStore
extends RefCounted
## Atomic JSON envelope with a backup; map_save.gd validates the map state.
## RNG seed/state are stored as decimal strings (JSON numbers lose 64-bit precision).

const VERSION := 1
var path: String
var last_error := ""

func _init(save_path: String) -> void:
	path = save_path

func read() -> Dictionary:
	last_error = ""
	if not FileAccess.file_exists(path) and not FileAccess.file_exists(path + ".bak"):
		return {}
	for candidate in [path, path + ".bak"]:
		var file := FileAccess.open(candidate, FileAccess.READ)
		if file == null:
			continue
		var parser := JSON.new()
		var parsed := parser.parse(file.get_as_text())
		file.close()
		if parsed != OK:
			continue
		var value = parser.data
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
	file.store_string(JSON.stringify({"version": _envelope_version(), "run": run, "meta": meta}))
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
		# A corrupt primary must never overwrite the good backup we just recovered.
		# Retain its bytes separately for diagnosis; no silent deletion of player data.
		var previous := FileAccess.open(path, FileAccess.READ)
		var parser := JSON.new()
		var previous_valid := false
		if previous != null:
			previous_valid = parser.parse(previous.get_as_text()) == OK and _valid(parser.data)
			previous.close()
		var destination := backup if previous_valid else absolute + ".corrupt." + str(Time.get_ticks_usec())
		if previous_valid and FileAccess.file_exists(path + ".bak"):
			if DirAccess.remove_absolute(backup) != OK:
				last_error = "无法更新存档备份，本次进度尚未保存。"
				return false
		if DirAccess.rename_absolute(absolute, destination) != OK:
			last_error = "无法轮换旧存档，本次进度尚未保存。"
			return false
	if DirAccess.rename_absolute(temp_absolute, absolute) != OK:
		last_error = "无法提交存档；旧进度仍保存在备份中。"
		return false
	if not preload("res://scripts/core/platform_persistence.gd").flush():
		last_error = "微信本地存档写入失败，请检查存储空间后重试。"
		return false
	return true

func _envelope_version() -> int:
	# CampaignSave opts into v2; the original two-floor store remains v1.
	return VERSION

func _valid(value: Variant) -> bool:
	# Subclasses validate their mode-specific state; keep the shared envelope stable.
	return value is Dictionary and value.get("version", 0) == VERSION and value.get("run") is Dictionary and value.get("meta") is Dictionary
