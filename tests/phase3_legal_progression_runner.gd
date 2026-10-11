extends "res://tests/phase3_balance_runner.gd"
## Fresh isolated account, successive real clears. No account fixture assignment.
func _suite() -> void:
	supplies = true
	prepared = true
	evidence_out = BALANCE_OUT+"legal/"
	DirAccess.make_dir_recursive_absolute(evidence_out)
	for level in ["p3_c0","p3_c1","p3_c2"]:
		challenge = level
		start_config = "default"
		_route("0","defense",false)
		if not routes[-1].won: break
		_write_results()
		await process_frame
	if routes.size() == 3 and routes[-1].won:
		for config in ["p3_vanguard","p3_keeper","p3_trader"]:
			start_config = config
			_check(config in core.meta.unlocked_ids,"start unlocked by prior real routes: "+config)
			if config not in core.meta.unlocked_ids: continue
			_route("0","defense",false)
			_write_results()
			await process_frame
	_finish()

func _new_case(name: String, persist: bool = true) -> void:
	context = {"case":challenge+"_"+start_config+"_"+name,"challenge":challenge,"start_config":start_config,
		"account_provenance":"same fresh account; previous production clears and actual shop/kill-heal achievements; zero embers"}
	current_path = run_folder+"/legal_account.json"
	core = Core.new(current_path)
	if FileAccess.file_exists(current_path): core.load_game()
	core.persistence_enabled = persist
	trace = []
	early_rests = {}

func _travel_up(seed_text: String, number: int) -> bool:
	# Deliberate legal sustain achievement preparation: fight the optional bat and
	# take Blood Sword, then earn actual (non-overflow) healing in later combats.
	if number == 1 and challenge == "p3_c0":
		if not _branch(3,0): return false
	return super._travel_up(seed_text,number)

func _write_results() -> void:
	var result := {"checks":checks,"failures":failures,"routes":routes,"observations":observations,
		"account_provenance":"fresh isolated account, no fixture or player mutation; sequential production clears",
		"account":core.meta if core != null else {},"user_data_dir":ProjectSettings.globalize_path("user://")}
	FileAccess.open(evidence_out+"legal-progression.json",FileAccess.WRITE).store_string(JSON.stringify(result,"\t"))
