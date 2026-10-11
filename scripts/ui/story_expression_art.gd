extends Control
## Small ImageGen facial patches share the unchanged production portrait.
## Coordinates use the master canvas, independent of export texture resizing.
const Art = preload("res://scripts/ui/runtime_art.gd")
const HERO := "res://assets/characters/hero/dialogue/textures/hero_dialogue_neutral_v01.png"
const PRINCE := "res://assets/story/phase2/prince_dialogue.png"
const DEMON := "res://assets/story/phase2/demon_dialogue.png"
const CANVAS := Vector2(1024,1536)
const CLOSEUP := Rect2(220,0,660,790)
const PATCHES := {
	"hero_guarded": Rect2(470,246,250,219),
	"hero_shock": Rect2(470,246,250,219),
	"prince_weary": Rect2(480,204,224,210),
	"prince_sneer": Rect2(480,204,224,210),
	"demon_stern": Rect2(514,208,176,188),
}
# Text anchors prevent old saved dialogue queues from revealing the betrayal
# early if their line numbering differs. No story state is read or changed.
const BETRAYAL_LINES := [
	"他逼我写，好让你带灯来。可那三道线，是我自己添的。我知道你会来。",
	"真是感谢你，帮我解决了那个蠢蛋啊。",
	"王室守着深渊几百年，只肯拿一点残火续命。我带工具来，取走了他们不敢碰的那一颗。",
	"可他把我锁住，想把我身体里的力量抽进石像。他要你的灯补好裂口，我要你替我打断最后那根链。",
	"疼是真的。想让你救我，也是真的。只有回家以后做什么，我没有告诉你。",
]
var patch: Texture2D
var patch_rect := Rect2()
var view := Rect2(Vector2.ZERO,CANVAS)

static func expression(event: Dictionary, line: Dictionary, index: int) -> String:
	if not str(line.get("illustration", "")).is_empty(): return ""
	var id := str(event.get("id", ""))
	var speaker := str(line.get("speaker", ""))
	if "公主" in speaker:
		if id == "victory" and str(line.get("text", "")) in ["求救的信……也是你写的？","封印……是你先打开的。","所以你连那些回声……"]: return "hero_shock"
		if id in ["floor_2","floor_4","mid_boss","floor_8","floor_9","floor_10","death_2","death_4"] or (id == "intro" and index == 10): return "hero_guarded"
	elif "王子" in speaker:
		if id == "victory" and str(line.get("text", "")) in BETRAYAL_LINES: return "prince_sneer"
		if id in ["death_1","death_2","death_4","floor_8","floor_10"] or (id == "intro" and index in [7,13]): return "prince_weary"
	elif "魔王" in speaker and id in ["mid_boss","floor_10","death_3","death_5"]:
		return "demon_stern"
	return ""

static func present(portrait: TextureRect, path: String, event: Dictionary, line: Dictionary, index: int, closeup: bool = false) -> void:
	var base: Texture2D = Art.texture(path) if not path.is_empty() else null
	portrait.texture = base
	var layer = portrait.get_node_or_null("StoryExpressionPatch")
	if layer == null:
		layer = load("res://scripts/ui/story_expression_art.gd").new()
		layer.name = "StoryExpressionPatch"
		layer.mouse_filter = Control.MOUSE_FILTER_IGNORE
		portrait.add_child(layer)
		layer.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
		layer.resized.connect(layer.queue_redraw)
	layer.patch = null
	layer.view = Rect2(Vector2.ZERO,CANVAS)
	portrait.set_meta("story_expression", "")
	var character := path in [HERO,PRINCE,DEMON] and str(line.get("illustration", "")).is_empty()
	if base != null and character:
		if closeup:
			layer.view = CLOSEUP
			var atlas := AtlasTexture.new()
			atlas.atlas = base
			atlas.region = Rect2(CLOSEUP.position / CANVAS * base.get_size(), CLOSEUP.size / CANVAS * base.get_size())
			portrait.texture = atlas
		var key := expression(event,line,index)
		if PATCHES.has(key):
			layer.patch = Art.texture("res://assets/story/expressions/textures/%s_v01.png" % key)
			layer.patch_rect = PATCHES[key]
			if layer.patch != null: portrait.set_meta("story_expression", key)
	layer.queue_redraw()

func _draw() -> void:
	if patch == null: return
	var scale_factor := minf(size.x/view.size.x,size.y/view.size.y)
	var offset := (size-view.size*scale_factor)*0.5
	draw_texture_rect(patch,Rect2(offset+(patch_rect.position-view.position)*scale_factor,patch_rect.size*scale_factor),false)
