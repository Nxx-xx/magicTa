extends SceneTree
## Original code-authored vector masters; no third-party images or model generation.
const DIR := "res://assets/ui/phase3/progression/"

func _initialize() -> void:
	DirAccess.make_dir_recursive_absolute(ProjectSettings.globalize_path(DIR))
	var tower := '<path d="M45 85V49h10V35h18v14h10v36H45z M40 91h48"/><path d="M59 83V68h10v15" fill="#142536"/>'
	var lantern := '<path d="M49 50h30l5 42H44l5-42z M44 45h40 M51 39v-8a13 13 0 0 1 26 0v8"/><path d="M64 59c-15 17-10 23 0 25 10-2 15-8 0-25z" fill="#83d5bf" stroke="none"/>'
	var shapes := {
		"p3_c0": ['<circle cx="64" cy="64" r="49"/>', tower, "#d7a77c"],
		"p3_c1": ['<circle cx="64" cy="64" r="53"/><circle cx="64" cy="64" r="43"/>', tower, "#d4e5ef"],
		"p3_c2": ['<path d="M19 101V40l17 10V23l17 12 11-21 11 21 17-12v27l17-10v61H19z"/>', tower, "#f0cf76"],
		"default": ['<path d="M64 11l46 27v52l-46 27-46-27V38z"/>', lantern, "#e0bf80"],
		"p3_vanguard": ['<path d="M64 10l47 35-15 51-32 22-32-22-15-51z"/>', '<path d="M64 25l9 15-4 40H59l-4-40 9-15z M43 82h42 M64 82v21"/><path d="M33 39l9 9 M95 39l-9 9"/>', "#e9aa91"],
		"p3_keeper": ['<path d="M20 26l44-13 44 13v42c0 25-25 43-44 50-19-7-44-25-44-50V26z"/>', lantern, "#83d5bf"],
		"p3_trader": ['<path d="M36 17h56l25 47-25 47H36L11 64z"/>', '<path d="M37 83l27-41 27 41 M37 51h54 M64 27v67 M44 99h40"/><path d="M25 78h24l-5 12H30z M79 78h24l-5 12H84z" fill="#e0bf80"/>', "#e7cd80"]}
	for id in shapes:
		var parts: Array = shapes[id]
		var svg := '<svg xmlns="http://www.w3.org/2000/svg" width="128" height="128" viewBox="0 0 128 128"><g fill="#142536" stroke="%s" stroke-width="4" stroke-linejoin="round" stroke-linecap="round">%s<g stroke-width="4">%s</g></g></svg>' % [parts[2],parts[0],parts[1]]
		var file := FileAccess.open(DIR + id + ".svg", FileAccess.WRITE)
		file.store_string(svg)
		file.close()
		var image := Image.new()
		if image.load_svg_from_string(svg, 4.0) != OK:
			quit(1)
			return
		image.resize(128,128,Image.INTERPOLATE_LANCZOS)
		image.convert(Image.FORMAT_RGBA8)
		if image.save_png(DIR + id + ".png") != OK:
			quit(1)
			return
	print("PHASE3_PROGRESS_ASSETS 7 original SVG + RGBA PNG badges")
	quit()
