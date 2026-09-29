class_name MapKeys
extends RefCounted
## Legacy `keys` and untyped map entities remain copper. No key is a wildcard.

const TYPES := ["copper", "silver", "gold"]
const FIELDS := {"copper": "keys", "silver": "silver_keys", "gold": "gold_keys"}
const LABELS := {"copper": "铜", "silver": "银", "gold": "金"}
const COLORS := {"copper": Color("c7925b"), "silver": Color("cddaea"), "gold": Color("f4d06f")}

static func kind(entity: Dictionary) -> String:
	return str(entity.get("key_kind", "copper"))

static func key_name(key_kind: String) -> String:
	return str(LABELS.get(key_kind, "未知")) + "钥匙"

static func door_name(key_kind: String) -> String:
	return str(LABELS.get(key_kind, "未知")) + "门"

static func count(player: Dictionary, key_kind: String) -> int:
	return int(player.get(FIELDS.get(key_kind, ""), 0))

static func ensure_inventory(player: Dictionary) -> void:
	for key_kind in TYPES:
		var field := str(FIELDS[key_kind])
		if not player.has(field):
			player[field] = 0
