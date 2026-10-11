extends RefCounted
## Presentation-only registry; gameplay data and saved item dictionaries stay unchanged.
## Painted v02 replaces pixels at stable runtime paths; sources live in assets/items/source.
const ART_VERSION := "painted_v02"
const ACTION_PATHS := {
	"salvage": "res://assets/items/interactions/icons/salvage.png",
	"temper": "res://assets/items/interactions/icons/temper.png",
	"sacrifice": "res://assets/items/interactions/icons/sacrifice.png",
}
const PATHS := {
	"iron_sword": "res://assets/items/unique/icons/iron_sword.png",
	"iron_armor": "res://assets/items/unique/icons/iron_armor.png",
	"hunter_bow": "res://assets/items/unique/icons/hunter_bow.png",
	"tower_shield": "res://assets/items/unique/icons/tower_shield.png",
	"heart_pendant": "res://assets/items/unique/icons/heart_pendant.png",
	"duelist_gloves": "res://assets/items/unique/icons/duelist_gloves.png",
	"steel_blade": "res://assets/items/unique/icons/steel_blade.png",
	"knight_plate": "res://assets/items/unique/icons/knight_plate.png",
	"vital_crown": "res://assets/items/unique/icons/vital_crown.png",
	"dawn_spear": "res://assets/items/unique/icons/dawn_spear.png",
	"obsidian_mail": "res://assets/items/unique/icons/obsidian_mail.png",
	"sovereign_ring": "res://assets/items/unique/icons/sovereign_ring.png",
	"blood_sword": "res://assets/items/unique/icons/blood_sword.png",
	"gold_sword": "res://assets/items/unique/icons/gold_sword.png",
	"wolf_fang": "res://assets/items/unique/icons/wolf_fang.png",
	"stone_heart": "res://assets/items/unique/icons/stone_heart.png",
	"spring_seed": "res://assets/items/unique/icons/spring_seed.png",
	"lucky_coin": "res://assets/items/unique/icons/lucky_coin.png",
	"crimson_chalice": "res://assets/items/unique/icons/crimson_chalice.png",
	"merchant_seal": "res://assets/items/unique/icons/merchant_seal.png",
	"sun_emblem": "res://assets/items/unique/icons/sun_emblem.png",
	"guardian_oath": "res://assets/items/unique/icons/guardian_oath.png",
	"p3_dawn_sigil": "res://assets/items/phase3/icons/p3_dawn_sigil.png",
	"p3_lantern_aegis": "res://assets/items/phase3/icons/p3_lantern_aegis.png",
	"p3_bounty_ledger": "res://assets/items/phase3/icons/p3_bounty_ledger.png",
	"p3_rhythm_blade": "res://assets/items/phase3/icons/p3_rhythm_blade.png",
	"p3_thorn_clasp": "res://assets/items/phase3/icons/p3_thorn_clasp.png",
	"p3_gilded_lantern": "res://assets/items/phase3/icons/p3_gilded_lantern.png",
}

static func path_for(item: Dictionary) -> String:
	var id := str(item.get("id", ""))
	if PATHS.has(id): return PATHS[id]
	var explicit := str(item.get("icon", ""))
	return explicit if explicit.begins_with("res://assets/items/") else ""
