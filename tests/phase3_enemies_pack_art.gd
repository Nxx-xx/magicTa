extends SceneTree
## Deterministic atlas extraction, uniform sheet scaling and translation only.
## This never invents intermediate frames or promotes drafts to accepted artwork.
const ROOT := "res://assets/monsters/phase3/"
const OUTPUT := "res://build/verification/phase3/03-combat/"
const SHEETS := {
	"minotaur_attack": {"grid": Vector2i(4, 2), "size": 384, "actions": {"minotaur_attack": [0, 8, 12, false]}},
	"minotaur_idle_rage": {"grid": Vector2i(4, 3), "size": 384, "actions": {"minotaur_idle": [0, 6, 6, true], "minotaur_rage": [6, 6, 12, false]}},
	"minotaur_hit": {"grid": Vector2i(3, 1), "size": 384, "actions": {"minotaur_hit": [0, 3, 12, false]}},
	"minotaur_defeat": {"grid": Vector2i(5, 2), "size": 384, "actions": {"minotaur_defeat": [0, 10, 12, false]}},
	"slime_all": {"grid": Vector2i(6, 3), "size": 256, "actions": {"slime_idle": [0, 4, 6, true], "slime_hit": [4, 2, 12, false], "slime_attack": [6, 6, 12, false], "slime_defeat": [12, 6, 10, false]}}
}
var failures: Array[String] = []
var audit: Array = []

func _initialize() -> void:
	var previous: Variant = JSON.parse_string(FileAccess.get_file_as_string(ROOT+"manifest.json"))
	DirAccess.make_dir_recursive_absolute(ROOT + "textures")
	DirAccess.make_dir_recursive_absolute(ROOT + "effects")
	DirAccess.make_dir_recursive_absolute(OUTPUT)
	var manifest := {"version": 1, "status": "draft", "production_ready": false,
		"view": "combat_only", "source_method": "built-in imagegen; original sheet crops, no interpolated poses",
		"actions": {}, "effects": {}, "missing_creatures": ["skeleton", "bat", "sentinel", "warlock", "knight", "berserker", "warden", "golem", "p3_shield_sentinel", "p3_ember_channeler", "p3_vault_knight"],
		"missing_deliverables": ["layered editable masters and rig", "native 768/512 master resolution", "independent map camera idle", "final frame-by-frame art acceptance"]}
	for sheet_id in SHEETS:
		_pack(sheet_id, manifest)
	for effect in ["rage", "stone_armor", "p3_shield", "p3_ember", "p3_ambush", "retaliation"]:
		_pack_effect(effect, manifest)
	# Reproducing the historical draft sheets must not unpublish reviewed rigs.
	if previous is Dictionary and previous.get("actions") is Dictionary:
		for id in previous.actions:
			if previous.actions[id].get("status") == "accepted":
				manifest.actions[id] = previous.actions[id].duplicate(true)
		for field in ["status","view","source_method","accepted_entities","missing_creatures","missing_deliverables"]:
			if previous.has(field): manifest[field] = previous[field]
	FileAccess.open(ROOT + "manifest.json", FileAccess.WRITE).store_string(JSON.stringify(manifest, "\t"))
	FileAccess.open(OUTPUT + "art-audit.json", FileAccess.WRITE).store_string(JSON.stringify({"failures": failures, "sheets": audit, "status": "draft; technical checks do not certify art quality"}, "\t"))
	print("Phase3 historical art packing: 51 draft frame slots, %d effect tracks, %d failures; reviewed production actions preserved" % [manifest.effects.size(), failures.size()])
	quit(0 if failures.is_empty() else 1)

func _pack(sheet_id: String, manifest: Dictionary) -> void:
	var source_path := ROOT + "source/" + sheet_id + ".png"
	var source := Image.load_from_file(source_path)
	if source == null or source.is_empty():
		failures.append("missing source: " + source_path)
		return
	source.convert(Image.FORMAT_RGBA8)
	var spec: Dictionary = SHEETS[sheet_id]
	var grid: Vector2i = spec.grid
	var side := int(spec.size)
	var cell := Vector2i(source.get_width() / grid.x, source.get_height() / grid.y)
	var sprites := _segment_sprites(source, grid)
	if sprites.size() != grid.x * grid.y:
		failures.append("source segmentation failed: " + sheet_id)
		return
	var largest := 1
	for sprite in sprites:
		var bounds: Rect2i = sprite.bounds
		largest = maxi(largest, maxi(bounds.size.x, bounds.size.y))
	var scale_factor := float(side) * 0.80 / float(largest)
	var frame_audit: Array = []
	for action_id in spec.actions:
		var action_spec: Array = spec.actions[action_id]
		var frames: Array[String] = []
		var hashes := {}
		var contact := Image.create(int(action_spec[1]) * side, side, false, Image.FORMAT_RGBA8)
		contact.fill(Color(0.08, 0.10, 0.15, 1))
		for i in range(int(action_spec[1])):
			var slot := int(action_spec[0]) + i
			var rect: Rect2i = sprites[slot].bounds
			var cropped := Image.create(rect.size.x, rect.size.y, false, Image.FORMAT_RGBA8)
			cropped.fill(Color.TRANSPARENT)
			# Copy assigned alpha components only, preventing neighbouring-frame fragments.
			for component in sprites[slot].components:
				for pixel in component.pixels:
					var point := Vector2i(pixel % source.get_width(), int(pixel / source.get_width()))
					cropped.set_pixelv(point - rect.position, source.get_pixelv(point))
			var used := _visible_bounds(cropped)
			if used.size.x == 0 or used.size.y == 0:
				failures.append("empty frame " + action_id + str(i))
				continue
			var edge_touched := rect.position.x <= 1 or rect.position.y <= 1 or rect.end.x >= source.get_width() - 1 or rect.end.y >= source.get_height() - 1
			cropped.resize(maxi(1, roundi(rect.size.x * scale_factor)), maxi(1, roundi(rect.size.y * scale_factor)), Image.INTERPOLATE_LANCZOS)
			var scaled_used := _visible_bounds(cropped)
			var frame := Image.create(side, side, false, Image.FORMAT_RGBA8)
			frame.fill(Color.TRANSPARENT)
			# Fixed sheet scale preserves crouch/collapse height; translate ground to anchor.
			var offset := Vector2i(int((side - cropped.get_width()) / 2), int(side * 0.875) - scaled_used.end.y)
			frame.blit_rect(cropped, Rect2i(Vector2i.ZERO, cropped.get_size()), offset)
			var path: String = ROOT + "textures/" + action_id + "_%02d.png" % i
			if frame.save_png(path) != OK:
				failures.append("cannot save " + path)
			var hash_value := str(hash(frame.get_data()))
			if hashes.has(hash_value):
				failures.append("pixel-identical frame: " + path)
			hashes[hash_value] = true
			frames.append(path)
			contact.blend_rect(frame, Rect2i(Vector2i.ZERO, frame.get_size()), Vector2i(i * side, 0))
			frame_audit.append({"action": action_id, "frame": i, "source_region": [rect.position.x, rect.position.y, rect.size.x, rect.size.y],
				"source_visible_rect": [used.position.x, used.position.y, used.size.x, used.size.y], "source_edge_touched": edge_touched,
				"pixel_hash": hash_value, "runtime_size": side, "ground_anchor": [side / 2, int(side * 0.875)]})
		contact.save_png(OUTPUT + action_id + "_contact.png")
		manifest.actions[action_id] = {"status": "draft", "frames": frames, "fps": action_spec[2], "loop": action_spec[3],
			"size": [side, side], "anchor": [side / 2, int(side * 0.875)], "source": source_path,
			"events": {"hit": 4} if action_id.ends_with("attack") else {}, "review": "See SOURCE_AND_REVIEW.md; not accepted for production"}
	audit.append({"sheet": sheet_id, "native_size": [source.get_width(), source.get_height()], "native_cell": [cell.x, cell.y],
		"native_master_spec_met": cell.x >= (768 if side == 384 else 512) and cell.y >= (768 if side == 384 else 512),
		"has_alpha": source.detect_alpha() != Image.ALPHA_NONE, "frames": frame_audit})

func _segment_sprites(source: Image, grid: Vector2i) -> Array:
	var width := source.get_width()
	var height := source.get_height()
	var bytes := source.get_data()
	var visited := PackedByteArray()
	visited.resize(width * height)
	var components: Array = []
	for origin in range(width * height):
		if visited[origin] != 0 or bytes[origin * 4 + 3] < 4:
			continue
		var pixels := PackedInt32Array([origin])
		visited[origin] = 1
		var low := Vector2i(origin % width, int(origin / width))
		var high := low
		var cursor := 0
		while cursor < pixels.size():
			var pixel := pixels[cursor]
			cursor += 1
			var x := pixel % width
			var y := int(pixel / width)
			low.x = mini(low.x, x)
			low.y = mini(low.y, y)
			high.x = maxi(high.x, x)
			high.y = maxi(high.y, y)
			for next in [pixel - 1 if x > 0 else -1, pixel + 1 if x < width - 1 else -1, pixel - width if y > 0 else -1, pixel + width if y < height - 1 else -1]:
				if next >= 0 and visited[next] == 0 and bytes[next * 4 + 3] >= 4:
					visited[next] = 1
					pixels.append(next)
		if pixels.size() >= 4:
			components.append({"pixels": pixels, "bounds": Rect2i(low, high - low + Vector2i.ONE)})
	components.sort_custom(func(a: Dictionary, b: Dictionary) -> bool: return a.pixels.size() > b.pixels.size())
	var count := grid.x * grid.y
	if components.size() < count:
		return []
	var main := components.slice(0, count)
	main.sort_custom(func(a: Dictionary, b: Dictionary) -> bool: return a.bounds.get_center().y < b.bounds.get_center().y)
	var result: Array = []
	for row in range(grid.y):
		var row_components := main.slice(row * grid.x, (row + 1) * grid.x)
		row_components.sort_custom(func(a: Dictionary, b: Dictionary) -> bool: return a.bounds.get_center().x < b.bounds.get_center().x)
		for component in row_components:
			result.append({"bounds": component.bounds, "primary_bounds": component.bounds, "components": [component]})
	for component in components.slice(count):
		var best := 0
		var distance := INF
		for i in range(result.size()):
			var a: Rect2i = component.bounds
			var b: Rect2i = result[i].primary_bounds
			var dx := maxi(0, maxi(a.position.x - b.end.x, b.position.x - a.end.x))
			var dy := maxi(0, maxi(a.position.y - b.end.y, b.position.y - a.end.y))
			var candidate := float(dx * dx + dy * dy)
			if candidate < distance:
				distance = candidate
				best = i
		result[best].components.append(component)
		result[best].bounds = result[best].bounds.merge(component.bounds)
	return result

func _visible_bounds(image: Image) -> Rect2i:
	var low := image.get_size()
	var high := Vector2i(-1, -1)
	for y in range(image.get_height()):
		for x in range(image.get_width()):
			if image.get_pixel(x, y).a >= 0.08:
				low.x = mini(low.x, x)
				low.y = mini(low.y, y)
				high.x = maxi(high.x, x)
				high.y = maxi(high.y, y)
	return Rect2i(low, high - low + Vector2i.ONE) if high.x >= 0 else Rect2i()

func _pack_effect(id: String, manifest: Dictionary) -> void:
	var count := 6 if id in ["rage", "stone_armor"] else 4
	var frames: Array[String] = []
	for i in range(count):
		var t := float(i + 1) / float(count)
		var svg := '<svg xmlns="http://www.w3.org/2000/svg" width="384" height="384" viewBox="0 0 384 384">'
		var color := "#f59d52"
		match id:
			"rage":
				for j in range(3):
					var x := 155 + j * 32
					svg += '<path d="M%d 210 l-10 -%d l18 -12 l-4 -%d" fill="none" stroke="#ff7a52" stroke-width="6" opacity="%f"/>' % [x, 18 + i * 3, 12 + i * 2, sin(t * PI) * 0.6 + 0.4]
			"stone_armor", "p3_shield":
				color = "#a5bfd5" if id == "stone_armor" else "#e5c775"
				var inset := 30 - roundi(t * 25)
				svg += '<path d="M%d 150 l-30 14 v53 l30 28 M%d 150 l30 14 v53 l-30 28" fill="none" stroke="%s" stroke-width="9" opacity="0.85"/>' % [160 - inset, 224 + inset, color]
				if id == "stone_armor":
					svg += '<path d="M177 175 l15 -12 l15 12 l-15 16 Z" fill="%s" opacity="%f"/>' % [color, t]
			"p3_ember":
				for j in range(i + 1):
					svg += '<circle cx="192" cy="188" r="%d" fill="none" stroke="#ffb65c" stroke-width="4" opacity="0.75"/>' % [20 + j * 12]
			"p3_ambush":
				svg += '<path d="M%d 115 L%d 270" stroke="#ffe8a6" stroke-width="%d" stroke-linecap="round" opacity="%f"/>' % [270 - i * 18, 112 - i * 10, 8 - i, 1.0 - t * 0.5]
			"retaliation":
				for j in range(5):
					var a := j * TAU / 5.0
					var center := Vector2(192, 192) + Vector2(cos(a), sin(a)) * (20 + 35 * t)
					svg += '<path d="M%f %f l-6 18 l12 -2 Z" fill="#d8a1db" opacity="%f"/>' % [center.x, center.y, 1.0 - t * 0.4]
		svg += "</svg>"
		var stem := ROOT + "effects/" + id + "_%02d" % i
		FileAccess.open(stem + ".svg", FileAccess.WRITE).store_string(svg)
		var frame := Image.new()
		if frame.load_svg_from_string(svg) != OK or frame.save_png(stem + ".png") != OK:
			failures.append("effect render failed " + stem)
		frames.append(stem + ".png")
	manifest.effects[id] = {"frames": frames, "fps": 12 if id != "p3_ember" else 8, "loop": false,
		"size": [384, 384], "anchor": [192, 336], "source": "original code-native SVG paths in effects/; no external assets", "status": "technical_preview"}
