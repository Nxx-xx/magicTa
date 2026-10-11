extends "res://tests/phase3_minotaur_host_capture.gd"
## Same public C0 route, extended through the actual floor-five boss/reward.
func _suite() -> void:
	boss_id = "golem"
	target_floor = 10
	mechanism = "armor"
	capture_out = "res://build/verification/phase3/07-completion/golem-host/"
	await super._suite()
