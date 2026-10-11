extends RefCounted
## Small environmental stories, drawn inside the board's existing 44-unit cell.
## The board owns the clock; reduced motion uses an identical, frozen pose.
static func draw(board: CanvasItem, kind: String, texture: Texture2D, seconds: float, reduced: bool) -> void:
	var time := 0.0 if reduced else seconds
	if kind == "rest":
		var warmth := .5 + .5 * sin(time * 3.1)
		# Soft concentric light stays inside the tile and below the painted stones.
		for layer in range(8, 0, -1):
			board.draw_circle(Vector2(0, 5), 7.0 + float(layer) * 1.65, Color(1.0, .40, .09, .012 + warmth * .005))
	board.draw_texture_rect(texture, Rect2(-22, -22, 44, 44), false)
	if kind == "rest":
		if reduced: return
		# A few drifting embers suggest surviving heat without moving the stone ring.
		for index in 2:
			var phase := fposmod(time * .43 + float(index) * .5, 1.0)
			var point := Vector2(1.5 + sin(phase * 5.0 + index) * 2.0, -1.0 - phase * 13.0)
			board.draw_circle(point, .48, Color(1.0, .72, .31, sin(phase * PI) * .72))
	else:
		# A quiet cold reflection marks a discoverable relic, without a letter badge.
		var shimmer := .24 if reduced else .24 + .20 * pow(maxf(0, sin(time * 1.7)), 5)
		board.draw_line(Vector2(-7.5, -3), Vector2(-6.5, 1), Color(.69, .89, .92, shimmer), .65, true)
