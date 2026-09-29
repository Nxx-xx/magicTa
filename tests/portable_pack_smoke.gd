extends SceneTree
## Run with the portable executable outside the source project, against its PCK.
const Campaign = preload("res://scripts/core/campaign_engine.gd")
var failures := 0

func _check(value: bool, label: String) -> void:
	if not value:
		failures += 1
		push_error("FAIL: " + label)

func _initialize() -> void:
	if not ProjectSettings.globalize_path("user://").replace("\\","/").contains("phase2-export"):
		push_error("Requires an isolated phase2-export profile.")
		quit(2)
		return
	_check(OS.get_executable_path().replace("\\","/").contains("build/phase2/windows/"), "using bundled executable")
	_check(not FileAccess.file_exists("res://README.md"), "development README excluded from pack")
	_check(not ResourceLoader.exists("res://scenes/previews/map_art_v01.tscn"), "preview scene excluded")
	for path in ["res://data/story.json","res://data/campaign_rules.json","res://assets/fonts/OFL.txt"]:
		_check(FileAccess.file_exists(path), "data included: " + path)
	for path in ["res://assets/story/phase2/prince_dialogue.png","res://assets/story/phase2/demon_dialogue.png","res://assets/story/phase2/rescue_ending.png","res://assets/audio/phase2/prince_cry_1.wav","res://assets/monsters/phase2/textures/minotaur.png","res://assets/monsters/phase2/textures/golem.png"]:
		_check(ResourceLoader.exists(path) and load(path) != null, "dynamic resource loads from pack: " + path)
	var core = Campaign.new("user://portable_smoke.json")
	_check(core.start_campaign("portable-smoke").is_empty(), "new campaign starts from pack")
	var resumed = Campaign.new("user://portable_smoke.json")
	resumed.load_game()
	_check(not resumed.state.is_empty() and resumed.state.run_id == core.state.run_id, "pack save continues")
	if not resumed.state.is_empty():
		resumed.acknowledge_story()
		_check(resumed.step(Vector2i.UP).is_empty(), "production movement in pack")
	var licenses := FileAccess.open(OS.get_executable_path().get_base_dir().path_join("Godot-LICENSE.txt"),FileAccess.WRITE)
	if licenses != null:
		licenses.store_string(Engine.get_license_text())
		licenses.close()
	var third_party := FileAccess.open(OS.get_executable_path().get_base_dir().path_join("Godot-THIRDPARTY.json"),FileAccess.WRITE)
	if third_party != null:
		third_party.store_string(JSON.stringify({"licenses":Engine.get_license_info(),"copyright":Engine.get_copyright_info()},"  "))
		third_party.close()
	print("Portable pack smoke: %d failures; using %s" % [failures,OS.get_executable_path()])
	quit(1 if failures else 0)
