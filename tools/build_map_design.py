"""Author the two hand-built 11x11 layouts and a reviewable design diagram.

This generates design assets, not random levels or a Godot screenshot.
Run after editing this file: python tools/build_map_design.py
"""
import json
from pathlib import Path

ROOT = Path(__file__).resolve().parents[1]


def terrain(segments):
    cells = [["#"] * 11 for _ in range(11)]
    for (x1, y1), (x2, y2) in segments:
        assert x1 == x2 or y1 == y2
        for y in range(min(y1, y2), max(y1, y2) + 1):
            for x in range(min(x1, x2), max(x1, x2) + 1):
                assert 0 < x < 10 and 0 < y < 10
                cells[y][x] = "."
    return ["".join(row) for row in cells]


def obj(x, y, kind, name, **extra):
    return {"pos": [x, y], "type": kind, "name": name, **extra}


def generate():
    first = {
        "name": "回声前厅", "theme": "entrance", "entry": [1, 9], "exit": [9, 1],
        "rows": terrain([
            ((1, 9), (1, 1)), ((1, 5), (7, 5)), ((7, 5), (7, 1)), ((7, 1), (9, 1)),
            ((1, 1), (3, 1)), ((1, 7), (3, 7)),
            ((5, 5), (5, 9)), ((5, 9), (7, 9)),
            ((7, 3), (9, 3)), ((9, 3), (9, 7)), ((8, 7), (9, 7)),
        ]),
        "entities": [
            obj(1, 9, "camp", "入口营地", description="原型从这里开始。往上探索，可随时回来。"),
            obj(9, 1, "up", "通往第二层", description="首次上楼选择下一层类型，之后自由往返。"),
            obj(2, 5, "key", "铜钥匙", amount=1),
            obj(1, 3, "door", "铜锁门", cost=1),
            obj(3, 1, "chest", "锁门后的护甲", item_id="iron_armor", gold=0),
            obj(2, 7, "enemy", "金币守卫", enemy_id="slime"),
            obj(3, 7, "gold", "旅人钱袋", amount=30),
            obj(5, 7, "enemy", "留待归来的强敌", enemy_id="knight", guardian=True),
            obj(7, 9, "chest", "回溯试炼宝箱", item_id="sovereign_ring", gold=30, objective=True),
            obj(9, 5, "enemy", "泉边骷髅", enemy_id="skeleton"),
            obj(8, 7, "potion", "疗愈药水", amount=35),
        ],
        "notes": ["主路无需战斗即可上楼", "先取钥匙，再开西侧锁门", "南侧骑士守宝箱，二层变强后返回"],
    }
    second = {
        "name": "分岔回廊", "entry": [1, 9], "exit": [9, 1],
        "rows": terrain([
            ((1, 9), (5, 9)), ((5, 9), (5, 1)), ((1, 9), (1, 5)), ((1, 5), (9, 5)),
            ((9, 5), (9, 1)), ((1, 1), (5, 1)), ((1, 1), (1, 3)),
            ((9, 5), (9, 9)), ((7, 9), (9, 9)),
        ]),
        "entities": [
            obj(1, 9, "down", "返回第一层", description="回到第一层上行楼梯，已清理的内容不会刷新。"),
            obj(9, 1, "summit", "未完的阶梯", description="两层地图原型到此。可以回到第一层挑战骑士、领取试炼宝箱。"),
            obj(3, 9, "chest", "回溯补给 · 长枪", item_id="dawn_spear", gold=0),
            obj(5, 7, "chest", "回溯补给 · 板甲", item_id="knight_plate", gold=0),
            obj(1, 5, "potion", "静谧泉水", amount=45),
            obj(1, 7, "gold", "商旅遗金", amount=30),
        ],
        "notes": ["三类主题共用相同尺寸与通路", "枪、甲、泉水为三主题共有补给", "主题支路一次生成，回访不刷新"],
    }
    themes = {
        "battle": {"name": "战斗层", "description": "两条支路有怪物守卫，胜利可取金币与遗物。共有补给无须战斗。", "entities": [
            obj(5, 3, "enemy", "北侧守卫", enemy_pool=["skeleton", "bat"]),
            obj(1, 1, "chest", "战利品箱", item_pool=["wolf_fang", "blood_sword"], gold=25),
            obj(9, 7, "enemy", "东侧守卫", enemy_pool=["slime", "skeleton"]),
            obj(7, 9, "gold", "守卫积蓄", amount=45),
        ]},
        "treasure": {"name": "宝藏层", "description": "支路以奖励为主。北侧锁门消耗钥匙，东侧宝箱可直接领取。", "entities": [
            obj(5, 3, "door", "宝库铜门", cost=1),
            obj(1, 3, "key", "备用钥匙", amount=1),
            obj(1, 1, "chest", "北侧宝库", item_pool=["hunter_bow", "tower_shield"], gold=20),
            obj(9, 7, "key", "宝库钥匙", amount=1),
            obj(7, 9, "chest", "东侧宝箱", item_pool=["heart_pendant", "duelist_gloves"], gold=15),
        ]},
        "shop": {"name": "商店层", "description": "东侧商人提供三件商品，每位商人最多售出一件；没钱可先离开再回来。", "entities": [
            obj(5, 3, "enemy", "钱袋守卫", enemy_pool=["slime", "skeleton"]),
            obj(1, 1, "gold", "北侧钱袋", amount=35),
            obj(9, 7, "shop", "烛火商人", offers=["buy_bow", "buy_shield", "buy_potion"], purchased=False),
            obj(7, 9, "key", "商路钥匙", amount=1),
        ]},
    }
    return {"size": 11, "prototype_floors": 2, "floor_1": first, "floor_2": second, "themes": themes}


def draw_design(data):
    from PIL import Image, ImageDraw, ImageFont

    image = Image.new("RGB", (1440, 1060), "#0b111c")
    draw = ImageDraw.Draw(image)
    font_path = str(ROOT / "assets/fonts/NotoSansSC.ttf")
    fonts = {n: ImageFont.truetype(font_path, n) for n in (16, 19, 23, 27, 38)}
    for font in fonts.values():
        font.set_variation_by_axes([450])
    draw.text((52, 26), "塔境 / 两层回溯地图", fill="#e4c182", font=fonts[38])
    draw.text((54, 86), "11 × 11 固定网格 · 已探索楼层可往返 · 三选一仅在首次上楼时出现", fill="#9eafc0", font=fonts[19])
    labels = {"camp": "营", "up": "上", "down": "下", "enemy": "怪", "key": "钥",
              "door": "门", "chest": "箱", "gold": "金", "potion": "泉", "summit": "终", "shop": "店"}
    colors = {"enemy": "#cf6f73", "door": "#b68c59", "key": "#dec26a", "chest": "#d6b977",
              "gold": "#dec26a", "potion": "#70c7b8", "shop": "#ac91db"}
    for index, floor in enumerate((data["floor_1"], data["floor_2"])):
        ox, oy, tile = 54 + index * 704, 198, 51
        draw.text((ox, 140), f"0{index + 1}  {floor['name']}" + (" · 商店主题示例" if index else ""), fill="#e6e7e3", font=fonts[27])
        entities = list(floor["entities"])
        if index:
            entities += data["themes"]["shop"]["entities"]
        for y, row in enumerate(floor["rows"]):
            for x, value in enumerate(row):
                rect = (ox+x*tile, oy+y*tile, ox+(x+1)*tile-3, oy+(y+1)*tile-3)
                fill = "#253346" if value == "#" else "#14202e"
                draw.rounded_rectangle(rect, radius=4, fill=fill)
                if value == "#":
                    draw.line((rect[0]+5, rect[1]+12, rect[2]-5, rect[1]+12), fill="#304258", width=2)
        # Walkable main route; starts in camp/down and avoids the strong guardian.
        route = [(1,9),(1,5),(7,5),(7,1),(9,1)] if not index else [(1,9),(5,9),(5,5),(9,5),(9,1)]
        draw.line([(ox+(x+.5)*tile, oy+(y+.5)*tile) for x,y in route], fill="#365e61", width=5)
        for entity in entities:
            x,y = entity["pos"]
            cx,cy = ox+x*tile+tile//2, oy+y*tile+tile//2
            color = colors.get(entity["type"], "#8dc7d8")
            draw.rounded_rectangle((cx-19,cy-19,cx+17,cy+17),radius=6,fill=color)
            text = "强" if entity.get("guardian") else labels[entity["type"]]
            if entity.get("item_id") == "dawn_spear": text = "枪"
            if entity.get("item_id") == "knight_plate": text = "甲"
            if entity.get("objective"): text = "赏"
            draw.text((cx,cy-3), text, anchor="mm", font=fonts[23], fill="#101824")
        for line, note in enumerate(floor["notes"]):
            draw.text((ox, 783+line*32), "· " + note, fill="#a9b9c6", font=fonts[19])
    draw.rounded_rectangle((54,902,1382,984),radius=12,fill="#162434")
    draw.text((78,920), "体验路线：绕过一层强敌 → 上楼选择主题 → 拾取枪与甲 → 下楼回访 → 击败骑士、取走宝箱", fill="#e4c182",font=fonts[23])
    draw.text((54,1010), "地图设计稿（非 Godot 运行截图）。墙体为手工布局；主题支路内容按种子抽取并永久保存。", fill="#879cab",font=fonts[16])
    image.save(ROOT / "docs/map_design.png")


if __name__ == "__main__":
    content = generate()
    (ROOT / "data/map_layouts.json").write_text(json.dumps(content, ensure_ascii=False, indent=2)+"\n", encoding="utf-8")
    draw_design(content)
    print("Wrote data/map_layouts.json and docs/map_design.png")
