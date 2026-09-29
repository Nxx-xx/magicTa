extends RefCounted
## Godot Dictionary equality distinguishes int from float. JSON round-trips
## normalize both sides while still comparing every persisted key and value.
static func equal(left: Variant, right: Variant) -> bool:
	return JSON.parse_string(JSON.stringify(left)) == JSON.parse_string(JSON.stringify(right))
