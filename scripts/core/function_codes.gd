extends RefCounted
## Keep the activation code and the one-time equipment baseline together.
const DEFAULT_CODE := "NXX"
const VALUE := 1000
const FIELDS := ["attack", "defense", "max_hp"]

static func valid(player: Dictionary) -> bool:
	if not player.has("function_code_offsets"): return true
	var offsets: Variant = player.function_code_offsets
	if not offsets is Dictionary or offsets.size() != FIELDS.size(): return false
	for field in FIELDS:
		var value: Variant = offsets.get(field)
		if not (value is int or value is float): return false
		if not is_finite(float(value)) or value < 0 or value > 1000000000 or floorf(float(value)) != float(value): return false
	return true

static func apply_stats(player: Dictionary, stats: Dictionary) -> void:
	var offsets: Dictionary = player.get("function_code_offsets", {})
	for field in FIELDS:
		stats[field] = maxi(0 if field == "defense" else 1, int(stats[field]) - int(offsets.get(field, 0)))
