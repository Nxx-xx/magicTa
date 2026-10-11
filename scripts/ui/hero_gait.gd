extends RefCounted
## Dense transform samples of the original four-facing rig, shared by boards.
const WALK_FRAMES := 24
const SETTLE_SECONDS := 0.09
const ROOT := "res://assets/characters/hero/phase3/textures/gait/"
static var frames: Dictionary = {}

static func warm() -> void:
	if not frames.is_empty(): return
	for facing in ["down", "left", "up", "right"]:
		var path: String = ROOT + facing + ".png"
		var sheet: Texture2D = load(path) if ResourceLoader.exists(path) else ImageTexture.create_from_image(Image.load_from_file(path))
		var poses: Array[AtlasTexture] = []
		for index in 36:
			var texture := AtlasTexture.new()
			texture.atlas = sheet
			texture.region = Rect2(index % 6 * 128, int(index / 6) * 128, 128, 128)
			texture.filter_clip = true
			poses.append(texture)
		frames[facing] = poses

static func pose(facing: String, phase: float, settling: float = -1.0) -> Dictionary:
	warm()
	var index := int(fposmod(phase, TAU) / TAU * WALK_FRAMES) % WALK_FRAMES
	if settling >= 0:
		var side := posmod(roundi(phase / PI), 2)
		index = WALK_FRAMES + side * 6 + mini(5, int(settling / SETTLE_SECONDS * 6))
	return {"ok": true, "fallback": false, "texture": frames[facing][index], "frame": index, "anchor": Vector2(64, 116)}
