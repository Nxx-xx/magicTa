"""Engine-free checks: data, assets, font coverage, resource paths, optional grammar.

Does NOT claim Godot compilation or runtime correctness.
Run: python tools/check_project.py
Optional: python tools/check_project.py --gdtoolkit-path <temporary package directory>
"""
from __future__ import annotations

import argparse
import json
import re
import sys
import xml.etree.ElementTree as ET
from pathlib import Path

ROOT = Path(__file__).resolve().parents[1]


def main() -> None:
    parser = argparse.ArgumentParser()
    parser.add_argument("--gdtoolkit-path", type=Path)
    args = parser.parse_args()
    if args.gdtoolkit_path:
        sys.path.insert(0, str(args.gdtoolkit_path))
    data = json.loads((ROOT / "data/content.json").read_text(encoding="utf-8"))
    enemies, items, events, shop = (data[k] for k in ("enemies", "items", "events", "shop"))
    assert len(enemies) == 10
    assert sum(v["kind"] == "equipment" for v in items.values()) == 12
    assert sum(v["kind"] == "relic" for v in items.values()) == 10
    assert len(events) == len(shop) == 10
    effect_keys = {"attack", "defense", "max_hp", "heal", "gold", "keys", "kill_heal", "gold_bonus", "gold_attack_step"}
    for key, enemy in enemies.items():
        assert enemy["id"] == key and enemy["hp"] > 0
        assert enemy["attack"] >= 0 and enemy["defense"] >= 0
        assert enemy["ability_id"] in ("", "rage", "stone_armor")
        assert enemy["rank"] in {"normal", "elite", "boss"} and enemy["combat_hint"]
        if enemy["rank"] == "boss":
            assert enemy["boss_floor"] in {5, 10} and "tier" not in enemy
        else:
            assert enemy["tier"] in {1, 2, 3} and "boss_floor" not in enemy
    assert {rank: sum(e["rank"] == rank for e in enemies.values()) for rank in ("normal", "elite", "boss")} == {"normal": 6, "elite": 2, "boss": 2}
    assert {e["boss_floor"] for e in enemies.values() if e["rank"] == "boss"} == {5, 10}
    for key, item in items.items():
        assert key == item["id"] and 1 <= item["tier"] <= 3
        assert item["effects"].keys() <= effect_keys
        assert all(isinstance(value, int) and value >= 0 for value in item["effects"].values())
    for event in events.values():
        assert len(event["options"]) == 2
        for option in event["options"]:
            assert option["name"] and option["description"]
            assert option.get("effects", {}).keys() <= effect_keys
            assert option.get("cost", {}).keys() <= {"hp", "gold", "keys"}
            if "item_id" in option:
                assert option["item_id"] in items
        assert any(not option.get("cost") for option in event["options"]), "Each event must have an affordable exit."
    for offer in shop.values():
        assert offer["price"] > 0 and 1 <= offer["min_floor"] <= 9
        assert ("item_id" in offer) != ("effects" in offer)
        if "item_id" in offer:
            assert offer["item_id"] in items
    assert set(data["floor_pools"]) == {str(n) for n in range(1, 11) if n not in (5, 10)}
    for pool in data["floor_pools"].values():
        assert pool["normal"] and pool["elite"] and pool["events"]
        assert all(key in enemies for key in pool["normal"] + pool["elite"])
        assert all(enemies[key]["rank"] == "normal" for key in pool["normal"])
        assert all(enemies[key]["rank"] == "elite" for key in pool["elite"])
        assert all(key in events for key in pool["events"])
    print("PASS content counts, effect schemas, event exits, floor pools, item/enemy references")

    rewards = json.loads((ROOT / "data/reward_rules.json").read_text(encoding="utf-8"))
    assert rewards["version"] == 1
    for field in ("relic_choices", "direct_relics", "vault_choices"):
        assert len(rewards[field]) >= 2 and len(rewards[field]) == len(set(rewards[field]))
        assert set(rewards[field]) <= items.keys()
    assert set(rewards["direct_relics"]) <= set(rewards["relic_choices"])
    assert all(items[key]["kind"] == "relic" for key in rewards["relic_choices"])
    assert rewards["event_pool"] and set(rewards["event_pool"]) <= events.keys()
    assert rewards["shop_supply"] and set(rewards["shop_supply"]) <= shop.keys()
    assert len(rewards["rest_options"]) == 2
    for option in rewards["rest_options"]:
        assert option["name"] and option["effects"].keys() <= effect_keys
        assert all(isinstance(n, int) and n >= 0 for n in option["effects"].values())
    print("PASS reward choices, event pool, shop supply and rest configuration")

    scripts = sorted(ROOT.rglob("*.gd"))
    sources = scripts + [ROOT / "project.godot"] + sorted(ROOT.rglob("*.tscn")) + sorted(ROOT.rglob("*.tres"))
    for path in sources:
        source = path.read_text(encoding="utf-8")
        for resource in re.findall(r'res://([^"\s]+)', source):
            assert (ROOT / resource).is_file(), f"Missing resource in {path}: {resource}"
    ET.parse(ROOT / "assets/icon.svg")
    assert "SIL OPEN FONT LICENSE" in (ROOT / "assets/fonts/OFL.txt").read_text(encoding="utf-8")
    print(f"PASS resource references ({len(sources)} files), SVG XML, bundled font license")
    try:
        from fontTools.ttLib import TTFont
    except ImportError:
        print("SKIP Chinese glyph coverage: optional fontTools unavailable")
    else:
        font = TTFont(ROOT / "assets/fonts/NotoSansSC.ttf")
        cmap = font.getBestCmap()
        text = "".join(p.read_text(encoding="utf-8") for p in sources)
        text += json.dumps(data, ensure_ascii=False)
        text += (ROOT / "data/map_layouts.json").read_text(encoding="utf-8")
        text += (ROOT / "data/random_maps.json").read_text(encoding="utf-8")
        han = {ord(c) for c in text if "\u3400" <= c <= "\u9fff"}
        assert han <= cmap.keys(), f"Missing glyphs: {sorted(han - cmap.keys())}"
        print(f"PASS bundled Chinese font covers all {len(han)} Han characters in game content")
    try:
        from gdtoolkit.parser import parser as gdparser
    except ImportError:
        print("SKIP GDScript grammar: optional gdtoolkit unavailable")
    else:
        for path in scripts:
            gdparser.parse(path.read_text(encoding="utf-8"))
        print(f"PASS GDScript grammar ({len(scripts)} files; not Godot semantic compilation)")
    from check_maps import check as check_maps
    check_maps()
    from check_random_maps import check as check_random_maps
    check_random_maps()
    print("Godot import, engine tests, visual/mobile checks and balance: still require Godot.")


if __name__ == "__main__":
    main()
