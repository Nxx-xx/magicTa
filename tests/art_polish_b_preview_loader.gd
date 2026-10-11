extends RefCounted
## Explicit isolated opt-in only. Draft stays draft on disk and in production.
const Catalog = preload("res://assets/monsters/phase3/phase3_enemy_animation_catalog.gd")
static func enable() -> void:
	assert(ProjectSettings.globalize_path("user://").replace("\\","/").contains("08-parallel/art-polish-b/"))
	var candidate: Dictionary = JSON.parse_string(FileAccess.get_file_as_string("res://assets/monsters/phase3/art_polish_b_candidate.json"))
	assert(candidate.art_polish_b.status == "draft_explicit_preview_only")
	for action in candidate.actions.values():
		if str(action.get("source", "")).contains("/art_polish_b_v07/"):
			assert(action.status == "draft")
			# The existing production consumer has no preview flag. Only this
			# isolated process supplies its private metadata snapshot.
			action.status = "accepted"
	Catalog._manifest = candidate
