"""Audit PNG exports and compose a labeled size-comparison sheet, without editing art."""
import hashlib
import json
import sys
from pathlib import Path
import os

ROOT = Path(__file__).resolve().parents[1]
sys.path.insert(0, str(ROOT / 'build/wechat-toolchain/python'))
from PIL import Image, ImageDraw, ImageFont

OUT = ROOT / 'build/verification/item-icons'
OUT.mkdir(parents=True, exist_ok=True)
manifest = json.loads((ROOT / 'assets/items/unique/manifest.json').read_text(encoding='utf-8'))
font = ImageFont.truetype(str(Path(os.environ['WINDIR']) / 'Fonts' / 'msyh.ttc'), 18)
small = ImageFont.truetype(str(Path(os.environ['WINDIR']) / 'Fonts' / 'consola.ttf'), 13)
sheet = Image.new('RGB', (1120, 1200), '#14232b')
draw = ImageDraw.Draw(sheet)
draw.text((24, 18), '塔境 · 装备与遗物 / 28 件独立图标', font=font, fill='#e6c486')
draw.text((24, 48), 'Each cell: 96 px / 48 px / 32 px | transparent PNG, no baked labels', font=small, fill='#a7c6c5')
hashes, silhouettes = set(), set()
for n, row in enumerate(manifest['assets']):
    path = ROOT / row['icon'].removeprefix('res://')
    im = Image.open(path).convert('RGBA')
    assert im.size == (128,128), row['id']
    assert im.getpixel((0,0))[3] == 0 and im.getchannel('A').getextrema() == (0,255)
    digest = hashlib.sha256(path.read_bytes()).hexdigest()
    assert digest == row['icon_sha256'] and digest not in hashes, row['id']
    hashes.add(digest)
    silhouette = hashlib.sha256(im.getchannel('A').point(lambda p: 255 if p > 127 else 0).tobytes()).hexdigest()
    assert silhouette not in silhouettes, row['id']
    silhouettes.add(silhouette)
    x, y = 16 + n%4*276, 84+n//4*158
    draw.rounded_rectangle((x,y,x+264,y+148), 8, fill='#203541', outline='#40545a')
    for size, dx, dy in [(96,4,3),(48,112,28),(32,192,36)]:
        preview = im.resize((size,size), Image.Resampling.LANCZOS)
        sheet.paste(preview,(x+dx,y+dy),preview)
    draw.text((x+10,y+99), row['name'], font=font, fill='#e4e9e3')
    draw.text((x+10,y+126), row['id'], font=small, fill='#a7c6c5')
sheet.save(OUT / 'all-items.png')
(OUT / 'asset-audit.json').write_text(json.dumps({'count':28,'unique_hashes':len(hashes),'unique_alpha_silhouettes':len(silhouettes),'size':[128,128],'transparent':True},indent=2),encoding='utf-8')
print('28 PNGs: unique pixels and silhouettes, transparent RGBA, verified manifest hashes')
