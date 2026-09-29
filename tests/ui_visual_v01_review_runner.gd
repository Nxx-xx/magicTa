extends "res://tests/ui_polish_m1_review_runner.gd"
## Keep the independent review assertions and its required user-data suffix intact.
## APPDATA: build/verification/ui_visual_v01/build/verification/m1_review/appdata
## Only redirect generated evidence; never write into the original review artifacts.
func _path(file: String) -> String:
	return ProjectSettings.globalize_path("res://").path_join("build/verification/ui_visual_v01/review").path_join(file)
