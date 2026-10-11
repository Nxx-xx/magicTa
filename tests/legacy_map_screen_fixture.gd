extends "res://scripts/ui/map_screen.gd"
## Historical map fixtures only; excluded from player entry points.

func _start(seed_text: String) -> void:
	var result: String = game.start(seed_text)
	if not result.is_empty():
		notice = result
		_render(true)
		return
	selected = Vector2i(-1, -1)
	notice = ""
	overlay_kind = ""
	_open_map()

