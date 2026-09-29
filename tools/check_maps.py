"""Structural map validation without Godot. Does not execute game logic."""
import json
from collections import deque
from pathlib import Path

ROOT = Path(__file__).resolve().parents[1]


def reachable(layout, start, blocked=()):
    closed = set(blocked)
    visited, queue = {tuple(start)}, deque([tuple(start)])
    while queue:
        x, y = queue.popleft()
        for nx, ny in ((x-1,y),(x+1,y),(x,y-1),(x,y+1)):
            point = nx, ny
            if not (0 <= nx < 11 and 0 <= ny < 11):
                continue
            if layout["rows"][ny][nx] == "#" or point in closed or point in visited:
                continue
            visited.add(point)
            queue.append(point)
    return visited


def key_reachability(layout, entities):
    """Explore position + collected-key set + opened-door set, without fighting.

    This checks key ordering, not combat solvability or random balance.
    """
    by_pos = {tuple(e["pos"]): e for e in entities}
    start = tuple(layout["entry"]), frozenset(), frozenset(), 0
    queue, seen, cells = deque([start]), {start}, set()
    while queue:
        (x,y), collected, opened, keys = queue.popleft()
        cells.add((x,y))
        for point in ((x-1,y),(x+1,y),(x,y-1),(x,y+1)):
            nx, ny = point
            if not (0 <= nx < 11 and 0 <= ny < 11) or layout["rows"][ny][nx] == "#":
                continue
            entity = by_pos.get(point, {})
            kind = entity.get("type")
            if kind == "enemy":
                continue
            new_keys, new_collected, new_opened = keys, collected, opened
            if kind == "door" and point not in opened:
                if keys < entity["cost"]:
                    continue
                new_keys -= entity["cost"]
                new_opened = opened | {point}
            if kind == "key" and point not in collected:
                new_keys += entity["amount"]
                new_collected = collected | {point}
            state = point, new_collected, new_opened, new_keys
            if state not in seen:
                seen.add(state)
                queue.append(state)
    return cells


def check():
    data = json.loads((ROOT / "data/map_layouts.json").read_text(encoding="utf-8"))
    content = json.loads((ROOT / "data/content.json").read_text(encoding="utf-8"))
    assert data["size"] == 11 and data["prototype_floors"] == 2
    first, second = data["floor_1"], data["floor_2"]
    variants = [("entrance", first, first["entities"])]
    variants += [(theme, second, second["entities"] + detail["entities"]) for theme, detail in data["themes"].items()]
    for name, layout, entities in variants:
        rows = layout["rows"]
        assert len(rows) == 11 and all(len(row) == 11 and set(row) <= {"#", "."} for row in rows)
        assert set(rows[0] + rows[-1]) == {"#"} and all(row[0] == row[-1] == "#" for row in rows)
        walkable = {(x,y) for y,row in enumerate(rows) for x,c in enumerate(row) if c == "."}
        assert reachable(layout, layout["entry"]) == walkable, f"Disconnected geometry: {name}"
        positions = [tuple(e["pos"]) for e in entities]
        assert len(positions) == len(set(positions)), f"Overlapping content: {name}"
        assert set(positions) <= walkable
        for entity in entities:
            if "enemy_id" in entity:
                assert entity["enemy_id"] in content["enemies"]
            if "item_id" in entity:
                assert entity["item_id"] in content["items"]
            for key, category in (("enemy_pool","enemies"),("item_pool","items"),("offers","shop")):
                if key in entity:
                    assert entity[key] and all(value in content[category] for value in entity[key])
        blockers = [tuple(e["pos"]) for e in entities if e["type"] in ("enemy", "door")]
        safe = reachable(layout, layout["entry"], blockers)
        assert tuple(layout["exit"]) in safe, f"Main route requires combat or a key: {name}"
        if name != "entrance":
            for pos in ((3,9),(5,7),(1,5)):
                assert pos in safe, f"Common supplies blocked: {name} {pos}"
            assert any(e.get("item_id") == "dawn_spear" for e in entities)
            assert any(e.get("item_id") == "knight_plate" for e in entities)
        key_cells = key_reachability(layout, entities)
        for entity in entities:
            if entity["type"] == "door":
                assert tuple(entity["pos"]) in key_cells, f"Key locked behind its own door: {name}"
        print(f"PASS {name}: 11x11, {len(walkable)} connected cells, safe stairs, reachable keys, {len(entities)} entities")
    guardian = next(tuple(e["pos"]) for e in first["entities"] if e.get("guardian"))
    goal = next(tuple(e["pos"]) for e in first["entities"] if e.get("objective"))
    assert goal not in reachable(first, first["entry"], [guardian]), "Strong guard can be bypassed to take its reward"
    assert tuple(first["exit"]) in reachable(first, first["entry"], [guardian])
    door = next(tuple(e["pos"]) for e in first["entities"] if e["type"] == "door")
    assert (3,1) not in reachable(first, first["entry"], [door]), "Armor stash bypasses its lock"
    print("PASS first-floor strong guard and locked armor guard rewards without blocking ascent")
    return data


if __name__ == "__main__":
    check()
