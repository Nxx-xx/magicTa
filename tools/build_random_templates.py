"""Author geometry/placement constraints, not the game's runtime generator.

Runtime generation is scripts/core/map_generator.gd. Existing hand-built maps
remain separate fixtures for old saves and regression tests.
"""
import json
from pathlib import Path
from build_map_design import terrain

ROOT = Path(__file__).resolve().parents[1]


def branch(gates, rewards):
    return {"gates": gates, "rewards": rewards}


def build():
    legacy = json.loads((ROOT / "data/map_layouts.json").read_text(encoding="utf-8"))
    templates = [
        {
            "id": "crossroads", "name": "分岔前厅",
            "rows": legacy["floor_1"]["rows"], "entry": [1,9], "exit": [9,1],
            "safe_slots": [[1,8],[1,6],[2,5],[3,5],[4,5],[6,5],[7,4],[7,2],[8,1]],
            "shop_slots": [[1,8],[1,6],[2,5]],
            "branches": [
                branch([[1,3],[1,2]], [[2,1],[3,1]]),
                branch([[2,7]], [[3,7]]),
                branch([[5,6],[5,7],[5,8]], [[6,9],[7,9]]),
                branch([[9,4],[9,5]], [[9,7],[8,7]]),
            ],
        },
        {
            "id": "long_gallery", "name": "四岔长廊", "entry": [5,9], "exit": [5,1],
            "rows": terrain([
                ((5,1),(5,9)), ((1,3),(9,3)), ((1,1),(1,3)), ((9,1),(9,3)),
                ((1,7),(9,7)), ((1,7),(1,9)), ((9,7),(9,9)),
            ]),
            "safe_slots": [[5,8],[5,6],[5,5],[5,4],[5,2]],
            "shop_slots": [[5,8],[5,6]],
            "branches": [
                branch([[3,3],[2,3]], [[1,2],[1,1]]),
                branch([[7,3],[8,3]], [[9,2],[9,1]]),
                branch([[3,7],[2,7]], [[1,8],[1,9]]),
                branch([[7,7],[8,7]], [[9,8],[9,9]]),
            ],
        },
        {
            "id": "winding_hall", "name": "曲径回廊", "entry": [1,9], "exit": [1,1],
            "rows": terrain([
                ((1,9),(9,9)), ((9,5),(9,9)), ((1,5),(9,5)), ((1,1),(1,5)),
                ((3,7),(3,9)), ((1,7),(3,7)), ((7,7),(7,9)), ((5,7),(7,7)),
                ((3,1),(3,5)), ((3,1),(5,1)), ((7,1),(7,5)), ((7,1),(9,1)),
            ]),
            "safe_slots": [[2,9],[4,9],[5,9],[6,9],[8,9],[9,8],[9,6],[8,5],[6,5],[5,5],[4,5],[2,5],[1,4],[1,2]],
            "shop_slots": [[2,9],[4,9]],
            "branches": [
                branch([[3,8],[3,7]], [[2,7],[1,7]]),
                branch([[7,8],[7,7]], [[6,7],[5,7]]),
                branch([[3,3],[3,2]], [[4,1],[5,1]]),
                branch([[7,3],[7,2]], [[8,1],[9,1]]),
            ],
        },
    ]
    # Recipes fill one branch each. Their order is shuffled onto the four branches.
    recipes = {
        "return_guard": {"gate": "enemy", "enemy_pool": ["knight"], "guardian": True,
                         "reward": "chest", "item_pool": ["sovereign_ring"], "gold": [25,35], "objective": True},
        "starter_armor": {"gate": "door", "key_kind": "copper", "reward": "chest", "item_pool": ["iron_armor","tower_shield"], "gold": [0,5]},
        "small_fight": {"gate": "enemy", "enemy_pool": ["slime","skeleton"], "reward": "gold", "amount": [20,35]},
        "healing_branch": {"gate": "none", "reward": "potion", "amount": [30,45]},
        "weapon_trial": {"gate": "enemy", "enemy_pool": ["slime"], "reward": "chest",
                         "item_pool": ["dawn_spear"], "gold": [0,5]},
        "armor_trial": {"gate": "door", "key_kind": "silver", "reward": "chest", "item_pool": ["knight_plate"], "gold": [0,5]},
        "relic_fight": {"gate": "enemy", "enemy_pool": ["bat","sentinel"], "reward": "chest",
                        "item_pool": ["wolf_fang","blood_sword","stone_heart","gold_sword"], "gold": [20,35]},
        "gold_fight": {"gate": "enemy", "enemy_pool": ["slime","skeleton"], "reward": "gold", "amount": [35,50]},
        "treasure_vault": {"gate": "door", "key_kind": "gold", "reward": "chest", "item_pool": ["hunter_bow","tower_shield","sun_emblem"], "gold": [15,25]},
        "open_chest": {"gate": "none", "reward": "chest", "item_pool": ["heart_pendant","duelist_gloves"], "gold": [5,15]},
    }
    themes = {
        "entrance": {"name": "回声前厅", "description": "绕过强敌，在别层强化后回来领取奖励。",
                     "recipes": ["return_guard","starter_armor","small_fight","healing_branch"]},
        "battle": {"name": "战斗层", "description": "三条战斗支路和一条钥匙支路，装备与遗物由守卫看守。主路可以绕行。",
                   "recipes": ["weapon_trial","armor_trial","relic_fight","gold_fight"]},
        "treasure": {"name": "宝藏层", "description": "两条锁门支路、一条守宝支路和一只开放宝箱。钥匙在安全区域。",
                     "recipes": ["weapon_trial","armor_trial","treasure_vault","open_chest"]},
        "shop": {"name": "商店层", "description": "商人在入口附近的安全通路，三件商品随机；支路可赚金币、找装备。",
                 "recipes": ["weapon_trial","armor_trial","gold_fight","healing_branch"]},
    }
    return {"version": 2, "size": 11, "max_attempts": 12, "templates": templates,
            "recipes": recipes, "themes": themes,
            "shop_pools": [["buy_sword","buy_bow"],["buy_armor","buy_shield"],["buy_potion","buy_key"]],
            "safe_gold": [8,15], "safe_heal": [15,25]}


if __name__ == "__main__":
    (ROOT / "data/random_maps.json").write_text(json.dumps(build(), ensure_ascii=False, indent=2)+"\n", encoding="utf-8")
    print("Wrote data/random_maps.json (3 templates, 4 themes, 10 branch recipes)")
