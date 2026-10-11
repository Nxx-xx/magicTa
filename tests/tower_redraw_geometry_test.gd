extends SceneTree
## Render the 16 orthogonal wall configurations and inspect passage interiors.
const Masonry = preload("res://scripts/ui/tower_masonry.gd")
const TowerEnvironment = preload("res://scripts/ui/tower_environment.gd")
var checks := 0
var failures := 0

class Edges extends Control:
	var map: Dictionary = {}
	func _draw() -> void:
		for y in 11:
			for x in 11:
				var cell := Vector2i(x,y)
				if Masonry.wall(map,cell): Masonry.edges(self,map,cell,Rect2(Vector2(cell)*40,Vector2(40,40)))

func check(value: bool, label: String) -> void:
	checks += 1
	if not value:
		failures += 1
		push_error("FAIL " + label)

func _initialize() -> void: run.call_deferred()

func run() -> void:
	var viewport := SubViewport.new()
	viewport.size = Vector2i(440,440)
	viewport.transparent_bg = true
	viewport.render_target_update_mode = SubViewport.UPDATE_ALWAYS
	root.add_child(viewport)
	var board := Edges.new()
	viewport.add_child(board)
	for mask in 16:
		var cells: Array[Vector2i] = [Vector2i(5,5)]
		for i in 4:
			if mask & (1 << i): cells.append(Vector2i(5,5)+[Vector2i.UP,Vector2i.RIGHT,Vector2i.DOWN,Vector2i.LEFT][i])
		var rows: Array[String] = []
		for y in 11:
			var row := ""
			for x in 11: row += "#" if Vector2i(x,y) in cells else "."
			rows.append(row)
		for floor_number in [1,5,10]:
			board.map = {"rows":rows,"floor":floor_number,"entities":{"4,5":{"type":"door","key_kind":"gold"}}}
			var snapshot := board.map.duplicate(true)
			board.queue_redraw()
			await process_frame
			await RenderingServer.frame_post_draw
			var pixels := viewport.get_texture().get_image()
			var clear := true
			for y in range(3,8):
				for x in range(3,8):
					if Vector2i(x,y) in cells: continue
					for py in range(y*40+2,(y+1)*40-2):
						for px in range(x*40+2,(x+1)*40-2):
							if pixels.get_pixel(px,py).a > .01: clear = false
			check(clear,"wall geometry stays in blocked cells, mask=%d floor=%d" % [mask,floor_number])
			check(board.map == snapshot,"drawing preserves map data")
			var env := TowerEnvironment.new()
			env.prepare(board.map)
			for lamp in env.lamps:
				check(Masonry.wall(board.map,lamp),"lamp belongs to wall")
				check(not Masonry.wall(board.map,lamp+Vector2i.DOWN),"lamp faces passage")
	check(Masonry.staircase("up") != Masonry.staircase("down"),"distinct staircase resources")
	check(Masonry.tier({"floor":1}) == 0 and Masonry.tier({"floor":5}) == 1 and Masonry.tier({"floor":10}) == 2,"three architectural families")
	print("TOWER REDRAW GEOMETRY checks=%d failures=%d" % [checks,failures])
	quit(1 if failures else 0)
