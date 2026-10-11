"""Inspect runtime pixels and create labelled QA contact sheets; no art editing."""
from pathlib import Path
import os
import hashlib, json
from PIL import Image, ImageDraw, ImageFont
ROOT = Path(__file__).resolve().parents[1]
OUT = ROOT / 'build/verification/item-icons-v02'
manifest = json.loads((ROOT/'assets/items/painted_v02_manifest.json').read_text())
items = json.loads((ROOT/'data/content.json').read_text(encoding='utf-8'))['items']
items.update(json.loads((ROOT/'data/phase3_items.json').read_text(encoding='utf-8'))['items'])
names = {'salvage':'取用物资','temper':'锻入剑钢','sacrifice':'灼血磨刀石'}
font = ImageFont.truetype(str(Path(os.environ['WINDIR']) / 'Fonts' / 'msyh.ttc'),18)
small = ImageFont.truetype(str(Path(os.environ['WINDIR']) / 'Fonts' / 'msyh.ttc'),12)
sheet = Image.new('RGB',(1120,1400),'#12232b')
d = ImageDraw.Draw(sheet)
d.text((20,16),'塔境 · 绘画图标 v02 / 28 件物品 + 3 类遗迹交互',font=font,fill='#e1c38b')
d.text((20,46),'96 / 48 / 32 px — actual runtime RGBA, upper-left light',font=small,fill='#a5c5c4')
checks=[]
assert len({row['icon_sha256'] for row in manifest['assets']}) == 31, 'Duplicate runtime art'
for i,row in enumerate(manifest['assets']):
    path=ROOT/row['icon'].removeprefix('res://')
    im=Image.open(path)
    assert im.mode=='RGBA' and im.size==(128,128),row['id']
    bounds=im.getchannel('A').getbbox()
    assert min(bounds[:2])>=13 and max(bounds[2:])<=115,(row['id'],bounds)
    assert hashlib.sha256(path.read_bytes()).hexdigest()==row['icon_sha256']
    assert len(set(im.get_flattened_data()))>100,row['id']
    x,y=(i%4)*280+8,(i//4)*164+78
    d.rounded_rectangle((x,y,x+270,y+156),radius=6,fill='#203641',outline='#42555b')
    for size,dx,dy in [(96,3,3),(48,112,26),(32,196,34)]:
        thumb=im.resize((size,size),Image.Resampling.LANCZOS)
        sheet.paste(thumb,(x+dx,y+dy),thumb)
    d.text((x+10,y+102),items.get(row['id'],{}).get('name',names.get(row['id'],row['id'])),font=font,fill='#e3e8e6')
    d.text((x+10,y+130),row['id'],font=small,fill='#b1cfcb')
    checks.append({'id':row['id'],'bounds':bounds,'bytes':path.stat().st_size,'sha256':row['icon_sha256']})
sheet.save(OUT/'all-items.png')
(OUT/'asset-audit.json').write_text(json.dumps({'assets':checks,'count':len(checks),'total_runtime_png_bytes':sum(x['bytes'] for x in checks)},indent=2))
print(f'{len(checks)} RGBA icons passed; {sum(x["bytes"] for x in checks)} runtime PNG bytes')
