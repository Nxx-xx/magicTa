extends SceneTree

const Core = preload("res://scripts/core/campaign_engine.gd")
var checks := 0
var failures := 0
var path := "user://shop_floor_test_%d.json" % OS.get_process_id()

class FailedStore extends RefCounted:
	var last_error := "test write failure"
	func write(_run: Dictionary, _meta: Dictionary) -> bool:
		return false

func _initialize() -> void:
	_run()
	for suffix in ["", ".bak", ".tmp"]:
		DirAccess.remove_absolute(ProjectSettings.globalize_path(path + suffix))
	print("Shop / floor tests: %d checks, %d failures" % [checks, failures])
	quit(1 if failures else 0)

func check(value: bool, label: String) -> void:
	checks += 1
	if not value:
		failures += 1
		push_error("FAIL: " + label)

func stairs(core) -> void:
	var cell := Vector2i(int(core.floor_data().exit[0]), int(core.floor_data().exit[1]))
	core.state.position = [cell.x, cell.y]
	check(core.interact(cell).is_empty(), "open stairs")
	check(core.state.pending.get("kind") == "stairs", "new floor has no theme selection")

func _run() -> void:
	var core = Core.new(path)
	check(core.start_phase3("shop-floor-redesign").is_empty(), "start production campaign")
	stairs(core)
	var theme: String = core.automatic_floor_theme(2)
	check(core.state.floors.size() == 1, "stairs preview does not generate floor")
	var resumed = Core.new(path)
	resumed.load_game()
	check(not resumed.state.is_empty() and resumed.state.pending.kind == "stairs", "save restores unvisited stairs")
	check(resumed.confirm_interaction().is_empty(), "enter new floor without a choice")
	check(resumed.state.floor == 2 and resumed.floor_data().theme == theme, "automatic theme applies")
	core.cancel_pending()
	stairs(core)
	core.rng.randi()
	check(core.confirm_interaction().is_empty(), "cancel and retry stairs")
	check(core.floor_data() == resumed.floor_data(), "same seed yields same floor across reload and gameplay RNG")
	stairs(core)
	check(core.confirm_interaction().is_empty() and core.state.floor == 3, "enter merchant floor")
	var merchants: Array = []
	for entity in core.floor_data().entities.values():
		if entity.type == "shop": merchants.append(entity)
	check(merchants.size() == 1, "one merchant provides all shop offers")
	if merchants.size() != 1: return
	var merchant: Dictionary = merchants[0]
	var cell := Vector2i(int(merchant.pos[0]), int(merchant.pos[1]))
	core.state.position = merchant.pos.duplicate()
	core.state.player.gold = 500
	core.state.player.hp = 1
	check(core.interact(cell).is_empty(), "open merchant")
	var gold_before := int(core.state.player.gold)
	var first_id := str(merchant.offers[0])
	var price := int(core.shop_offer(first_id).price)
	check(core.buy(0).is_empty(), "buy first offer")
	check(not merchant.purchased and core.shop_offer_sold(merchant, first_id), "only purchased offer is sold")
	check(core.state.pending.get("kind") == "entity", "shop stays open for more purchases")
	check(int(core.state.player.gold) == gold_before - price, "purchase debits exact price")
	var snapshot: Dictionary = core.state.duplicate(true)
	check(not core.buy(0).is_empty() and core.state == snapshot, "duplicate purchase changes nothing")
	resumed.load_game()
	check(not resumed.state.is_empty() and resumed.shop_offer_sold(resumed.entity_at(cell), first_id), "per-offer stock survives reload")
	resumed.cancel_pending()
	check(resumed.interact(cell).is_empty(), "return to partially stocked merchant")
	for index in range(1, merchant.offers.size()):
		price = int(resumed.shop_offer(str(merchant.offers[index])).price)
		check(resumed.buy(index).is_empty(), "buy remaining offer %d" % index)
		check(not resumed.transaction_pending, "purchase passes production save validation")
	check(resumed.entity_at(cell).purchased, "whole shop sold only after every offer")
	check(int(resumed.state.metrics.shop_gold_spent) == gold_before - int(resumed.state.player.gold), "achievement metrics count all purchases")
	var obtained := {}
	for event in resumed.state.codex_events:
		if event.get("source") == "shop" and event.kind == "item_obtained": obtained[event.id] = true
	check(obtained.size() >= 2, "separate purchases produce distinct discovery events")
	check(not resumed.buy(1).is_empty(), "sold out merchant rejects purchases")
	var reloaded = Core.new(path)
	reloaded.load_game()
	check(not reloaded.state.is_empty() and reloaded.entity_at(cell).purchased, "fully sold stock survives reload")
	var invalid: Dictionary = resumed.state.duplicate(true)
	invalid.floors["3"].entities[Core.cell_key(cell)].purchased_ids.append(first_id)
	check(not resumed.store._valid({"version":2,"run":invalid,"meta":resumed.meta}), "duplicate sold stock rejected")
	var legacy := {"offers":["buy_sword", "buy_plate"], "purchased":true, "purchased_id":"buy_sword"}
	check(core.shop_offer_sold(legacy, "buy_plate"), "legacy exhausted merchant stays exhausted")
	# Failed saves must roll back both currency and independent inventory together.
	var valid_store = core.store
	core.store = FailedStore.new()
	snapshot = core.state.duplicate(true)
	core.buy(1)
	check(core.transaction_pending and core.state == snapshot, "failed purchase restores currency and stock")
	core.store = valid_store
	check(core.retry_save() and core.shop_offer_sold(core.entity_at(cell), str(merchant.offers[1])), "retry commits purchase exactly once")
	# Legacy pending floor selections resume through the same single stair action.
	var trial = preload("res://tests/legacy_map_core_fixture.gd").new(path + ".legacy")
	trial.persistence_enabled = false
	trial.start("42")
	stairs(trial)
	trial.state.pending.kind = "floor_choice"
	check(trial.confirm_interaction().is_empty() and trial.state.floor == 2, "legacy pending selection needs no theme choice")
