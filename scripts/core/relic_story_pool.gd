extends RefCounted
## A run-local story draw, independent from combat and map RNG.
## Materialize all prose, choices and callbacks into the existing frozen snapshot.
const Ruins = preload("res://scripts/core/phase3_ruins.gd")
const IDS := ["p3_oath_ruin", "p3_oath_forge", "p3_lantern_sanctuary"]
const STORY_IDS := ["ilei", "luoan", "sefu", "heduo", "twins", "aolun"]
const CHAIN := "unreturned_lamp_v1"

static func catalog() -> Dictionary:
	var parsed: Variant = JSON.parse_string(FileAccess.get_file_as_string("res://data/relic_story_pool.json"))
	if not parsed is Dictionary or parsed.get("version") != 1 or not parsed.get("stories") is Dictionary: return {}
	var stories: Dictionary = parsed.stories
	if stories.size() != STORY_IDS.size(): return {}
	for id in STORY_IDS:
		var story = stories.get(id)
		if not story is Dictionary or not _text(story.get("title")) or not _text(story.get("conclusion")): return {}
		if not story.get("chapters") is Array or story.chapters.size() != 3 or not story.get("knight") is Array or story.knight.size() != 3: return {}
		for index in 3:
			if not _text(story.knight[index]): return {}
			var chapter = story.chapters[index]
			if not chapter is Dictionary: return {}
			for field in ["title", "evidence", "clue", "lead", "standalone"]:
				if not _text(chapter.get(field)): return {}
			if not chapter.get("link") is String or (index > 0 and not _text(chapter.link)): return {}
			if not chapter.get("variants") is Array or chapter.variants.size() != 2: return {}
			var seen := []
			for variant in chapter.variants:
				if not variant is Dictionary or variant.get("id") not in ["sealed", "disturbed"] or variant.id in seen or not _text(variant.get("description")): return {}
				seen.append(variant.id)
				if not variant.get("options") is Array or variant.options.size() != 3: return {}
				var choices := []
				for option in variant.options:
					if not option is Dictionary or option.get("id") not in Ruins.OPTIONS[IDS[index]] or option.id == "leave" or option.id in choices: return {}
					choices.append(option.id)
					for field in ["name", "description", "item", "outcome"]:
						if not _text(option.get(field)): return {}
	return stories

static func recent_ids(meta: Dictionary) -> Array:
	var recent := []
	var records: Array = meta.get("records", [])
	for index in range(records.size()-1, -1, -1):
		var id: String = records[index].get("relic_story_id", "")
		if id in STORY_IDS and id not in recent: recent.append(id)
		if recent.size() == STORY_IDS.size()-1: break
	return recent

static func for_run(base: Dictionary, seed_value: int, meta: Dictionary) -> Dictionary:
	var stories := catalog()
	if stories.is_empty(): return {}
	var recent := recent_ids(meta)
	var eligible := []
	for id in STORY_IDS:
		if id not in recent: eligible.append(id)
	var random := RandomNumberGenerator.new()
	random.seed = (str(seed_value) + ":relic-stories:v1:" + str(int(meta.get("runs",0))) + ":" + ",".join(recent)).hash()
	var selected: String = eligible[random.randi_range(0,eligible.size()-1)]
	var variants: Array = []
	for index in 3: variants.append(random.randi_range(0,1))
	return materialize(base, selected, variants, stories)

static func materialize(base: Dictionary, story_id: String, variants: Array, stories: Dictionary = {}) -> Dictionary:
	if stories.is_empty(): stories = catalog()
	if not Ruins.validate_definitions(base).ok or not stories.has(story_id) or variants.size() != 3: return {}
	var result := base.duplicate(true)
	var story: Dictionary = stories[story_id]
	for index in 3:
		if variants[index] not in [0,1]: return {}
		var id: String = IDS[index]
		var chapter: Dictionary = story.chapters[index]
		var variant: Dictionary = chapter.variants[int(variants[index])]
		var definition: Dictionary = result[id]
		definition.name = chapter.title
		definition.description = variant.description
		var trail := {"chain":CHAIN,"story_id":story_id,"story_title":story.title,
			"variant_id":variant.id,"title":story.title + " · " + chapter.title,
			"evidence":chapter.evidence,"clue":chapter.clue,"lead":chapter.lead,
			"previous":"" if index == 0 else IDS[index-1],"link":chapter.link,
			"standalone":chapter.standalone,"conclusion":story.conclusion,
			"knight_memory":story.knight[index],"finds":{}}
		var options := []
		for source in variant.options:
			var option: Dictionary = source.duplicate(true)
			trail.finds[option.id] = {"name":option.item,"outcome":option.outcome}
			option.erase("item")
			option.erase("outcome")
			options.append(option)
		options.append({"id":"leave","name":"暂时离开","description":"不取用物资，也不消耗事件，可返回调查。"})
		definition.options = options
		definition.trail = trail
	return result if Ruins.validate_definitions(result).ok else {}

static func story_id(run: Dictionary) -> String:
	return str(run.get("ruin_definitions_snapshot", {}).get(IDS[0], {}).get("trail", {}).get("story_id", ""))

static func _text(value: Variant) -> bool:
	return value is String and not value.strip_edges().is_empty()
