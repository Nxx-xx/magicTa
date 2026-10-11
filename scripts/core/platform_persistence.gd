extends RefCounted
## The WeChat bridge writes the virtual filesystem to native private storage.
## Desktop and ordinary browser exports retain their existing save behavior.

static func flush() -> bool:
	if not OS.has_feature("web"):
		return true
	var bridge = JavaScriptBridge.get_interface("__towerPersistence")
	if bridge == null:
		return true
	return bool(bridge.flush())
