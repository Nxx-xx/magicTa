class_name TowerCombat
extends RefCounted
## Pure, deterministic simulation. Preview and resolution both call this function.
## The enemy's third-attack rage applies before that turn's counterattack.
## Golem armor updates after every hit, including hits crossing multiple thresholds.
const Phase3Combat = preload("res://scripts/core/phase3_combat.gd")

static func simulate(player: Dictionary, enemy: Dictionary, stats: Dictionary, rules_version: int = 1) -> Dictionary:
	if rules_version == 2:
		return Phase3Combat.simulate(player, enemy, stats)
	if rules_version != 1:
		return {"ok": false, "error": "不支持的战斗规则版本：%d" % rules_version}
	var hp := int(player.hp)
	var start_hp := hp
	var enemy_hp := int(enemy.hp)
	var enemy_max_hp := enemy_hp
	var enemy_attack := int(enemy.attack)
	var enemy_defense := int(enemy.defense)
	var ability := str(enemy.get("ability_id", ""))
	var turns := 0
	var counters := 0
	var incoming := 0
	var log: Array = []
	while hp > 0 and enemy_hp > 0:
		turns += 1
		var hit := maxi(1, int(stats.attack) - enemy_defense)
		enemy_hp = maxi(0, enemy_hp - hit)
		var entry := {"turn": turns, "hit": hit, "enemy_hp": enemy_hp,
			"counter": 0, "hp": hp, "note": ""}
		if enemy_hp == 0:
			log.append(entry)
			break
		if ability == "rage" and turns % 3 == 0:
			enemy_attack += 2
			entry.note = "狂怒：敌人攻击 +2"
		if ability == "stone_armor":
			enemy_defense = int(enemy.defense) + int((enemy_max_hp - enemy_hp) / 50) * 2
			entry.note = "石甲：当前防御 %d" % enemy_defense
		var counter := maxi(0, enemy_attack - int(stats.defense))
		incoming += counter
		hp = maxi(0, hp - counter)
		counters += 1
		entry.counter = counter
		entry.hp = hp
		log.append(entry)
	var won := enemy_hp == 0 and hp > 0
	var healing := 0
	if won:
		healing = mini(int(stats.kill_heal), int(stats.max_hp) - hp)
		hp += healing
	return {
		"turns": turns, "counterattacks": counters, "incoming": incoming,
		"healing": healing, "loss": start_hp - hp, "hp_after": hp,
		"lethal": not won, "won": won, "enemy_hp_after": enemy_hp,
		"gold_reward": int(enemy.get("gold_reward", 0)) + int(stats.gold_bonus) if won else 0,
		"log": log
	}

