"""Exhaustively validate authored random-placement constraints without Godot.

This checks all template symmetries and allowed gate combinations. It does not
execute or reimplement MapGenerator's RNG/placement algorithm.
"""
import itertools
import json
from collections import deque
from pathlib import Path
from check_maps import reachable

ROOT = Path(__file__).resolve().parents[1]


def transformed(cell, symmetry):
    x, y = cell
    if symmetry >= 4:
        x = 10 - x
    for _ in range(symmetry % 4):
        x, y = 10 - y, x
    return x, y


def distance(layout, target):
    start = tuple(layout["entry"])
    queue, seen = deque([(start, 0)]), {start}
    while queue:
        (x,y), cost = queue.popleft()
        if (x,y) == tuple(target):
            return cost
        for point in ((x-1,y),(x+1,y),(x,y-1),(x,y+1)):
            nx,ny = point
            if not (0 <= nx < 11 and 0 <= ny < 11) or layout["rows"][ny][nx] == "#" or point in seen:
                continue
            seen.add(point)
            queue.append((point, cost+1))
    return 1000


def check():
    data = json.loads((ROOT / "data/random_maps.json").read_text(encoding="utf-8"))
    content = json.loads((ROOT / "data/content.json").read_text(encoding="utf-8"))
    assert data["version"] == 2 and data["size"] == 11 and 1 <= data["max_attempts"] <= 32
    key_types = {"copper", "silver", "gold"}
    assert set(data["themes"]) == {"entrance", "battle", "treasure", "shop"}
    for role, recipe in data["recipes"].items():
        assert recipe["gate"] in {"none", "enemy", "door"}
        if recipe["gate"] == "door":
            assert recipe.get("key_kind") in key_types, f"Unknown door key type: {role}"
        assert recipe["reward"] in {"chest", "gold", "potion"}
        for key, category in (("enemy_pool", "enemies"), ("item_pool", "items")):
            if key in recipe:
                assert recipe[key] and set(recipe[key]) <= content[category].keys()
        if recipe["gate"] == "enemy":
            assert recipe.get("enemy_pool"), role
        if recipe["reward"] == "chest":
            assert recipe.get("item_pool"), role
        bounds = recipe["gold"] if recipe["reward"] == "chest" else recipe["amount"]
        assert len(bounds) == 2 and 0 <= bounds[0] <= bounds[1]
    for name, theme in data["themes"].items():
        assert len(theme["recipes"]) == len(set(theme["recipes"])) == 4
        assert set(theme["recipes"]) <= data["recipes"].keys()
        count = sum(data["recipes"][role]["gate"] == "enemy" for role in theme["recipes"])
        assert count == {"entrance": 2, "battle": 3, "treasure": 1, "shop": 2}[name]
    for role, tiers in {"small_fight": {1}, "gold_fight": {1}, "weapon_trial": {1}, "relic_fight": {1, 2}, "return_guard": {3}}.items():
        for enemy_id in data["recipes"][role]["enemy_pool"]:
            enemy = content["enemies"][enemy_id]
            assert enemy["rank"] == "normal" and enemy["tier"] in tiers, (role, enemy_id)
        assert data["recipes"][role].get("guardian", False) == (role == "return_guard")
    assert data["recipes"]["return_guard"]["enemy_pool"] == ["knight"]
    assert data["recipes"]["weapon_trial"]["enemy_pool"] == ["slime"]
    assert data["recipes"]["weapon_trial"]["item_pool"] == ["dawn_spear"]
    assert data["recipes"]["armor_trial"]["item_pool"] == ["knight_plate"]
    assert "return_guard" in data["themes"]["entrance"]["recipes"]
    for name in ("battle", "treasure", "shop"):
        assert {"weapon_trial", "armor_trial"} <= set(data["themes"][name]["recipes"])
    assert data["recipes"]["starter_armor"]["key_kind"] == "copper"
    assert data["recipes"]["armor_trial"]["key_kind"] == "silver"
    assert data["recipes"]["treasure_vault"]["key_kind"] == "gold"
    assert len(data["shop_pools"]) == 3
    flat = [entry for pool in data["shop_pools"] for entry in pool]
    assert len(flat) == len(set(flat)) and set(flat) <= content["shop"].keys()
    template_ids, unique_geometry = set(), set()
    scenarios, cut_checks = 0, 0
    for template in data["templates"]:
        assert template["id"] not in template_ids
        template_ids.add(template["id"])
        assert len(template["rows"]) == 11 and all(len(row) == 11 for row in template["rows"])
        assert all(set(row) <= {".", "#"} for row in template["rows"])
        assert set(template["rows"][0] + template["rows"][-1]) == {"#"}
        assert all(row[0] == row[-1] == "#" for row in template["rows"])
        assert set(map(tuple, template["shop_slots"])) <= set(map(tuple, template["safe_slots"]))
        assert all(distance(template, slot) <= 5 for slot in template["shop_slots"]), "Merchant too far from entry"
        assert len(template["branches"]) == 4
        for name, theme in data["themes"].items():
            key_budgets = {kind: 0 for kind in key_types}
            for role in theme["recipes"]:
                recipe = data["recipes"][role]
                if recipe["gate"] == "door":
                    key_budgets[recipe["key_kind"]] += 1
            key_budget = sum(key_budgets.values())
            assert len(template["safe_slots"]) >= key_budget + 2 + (name == "shop")
        for symmetry in range(8):
            walkable = {transformed((x,y), symmetry) for y,row in enumerate(template["rows"]) for x,c in enumerate(row) if c == "."}
            rows = ["".join("." if (x,y) in walkable else "#" for x in range(11)) for y in range(11)]
            layout = {"rows": rows, "entry": transformed(template["entry"],symmetry), "exit": transformed(template["exit"],symmetry)}
            unique_geometry.add(tuple(rows))
            assert reachable(layout, layout["entry"]) == walkable
            reserved = {layout["entry"], layout["exit"]}
            slots = [transformed(cell,symmetry) for cell in template["safe_slots"]]
            assert len(slots) == len(set(slots)) and not reserved.intersection(slots)
            reserved.update(slots)
            branches = []
            for branch in template["branches"]:
                gates = [transformed(cell,symmetry) for cell in branch["gates"]]
                rewards = [transformed(cell,symmetry) for cell in branch["rewards"]]
                branch_cells = set(gates+rewards)
                assert gates and rewards and not set(gates).intersection(rewards)
                assert not reserved.intersection(branch_cells), "Placement slots overlap"
                reserved.update(branch_cells)
                assert branch_cells <= walkable
                for gate, reward in itertools.product(gates, rewards):
                    assert reward not in reachable(layout, layout["entry"], [gate]), "Guarded reward bypass"
                    cut_checks += 1
                branches.append(gates)
            assert set(slots) <= walkable
            for gates in itertools.product(*branches):
                safe = reachable(layout, layout["entry"], gates)
                assert layout["exit"] in safe and set(slots) <= safe, "Blocked stairs, keys or shop"
                for x,y in gates:
                    assert any(point in safe for point in ((x-1,y),(x+1,y),(x,y-1),(x,y+1))), "Guard inaccessible"
                scenarios += 1
    print(f"PASS random constraints: {len(template_ids)} templates / 8 symmetries / {len(unique_geometry)} distinct geometries")
    print(f"PASS {scenarios} gate combinations and {cut_checks} guard-reward cuts; all placements preserve safe stairs/keys/shop")
    print("PASS copper/silver/gold door recipes, matching-key slot budgets, reward pools and shop offers")
    print("PASS monster ranks/tiers, theme encounter counts, fixed growth and return guardians")
    return {"templates": len(template_ids), "geometries": len(unique_geometry), "scenarios": scenarios, "cuts": cut_checks}


if __name__ == "__main__":
    check()
