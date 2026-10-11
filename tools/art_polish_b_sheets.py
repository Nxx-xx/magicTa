"""Compose review evidence from unchanged rendered PNGs."""
import json, math
from pathlib import Path
from PIL import Image, ImageDraw
ROOT=Path(__file__).resolve().parents[1]
SRC=ROOT/'assets/monsters/phase3/source/art_polish_b_v07'
OUT=ROOT/'build/verification/art-polish-b'
def read(p):return json.loads(p.read_text(encoding='utf-8-sig'))
def sheet(rows,path):
    im=Image.new('RGB',(1240,len(rows)*116),(24,37,45));d=ImageDraw.Draw(im)
    for r,(name,files) in enumerate(rows):
        d.text((4,r*116+3),name,fill='white')
        for i,f in enumerate(files):
            a=Image.open(f).convert('RGBA');a.thumbnail((92,92),Image.Resampling.LANCZOS)
            im.paste(a,(i*100+4,r*116+20),a)
    path.parent.mkdir(parents=True,exist_ok=True);im.save(path)
def run():
    for p in SRC.glob('*/*/*_draft_manifest.json'):
        m=read(p);entity=p.parent.parent.name;view=p.parent.name
        groups={}
        for name,a in m['actions'].items():
            group=name.rsplit('_armor_',1)[-1] if '_armor_' in name else '0'
            groups.setdefault(group,[]).append((name,[p.parent/f for f in a.get('combined_frames',a['frames'])]))
        for g,rows in groups.items():sheet(rows,OUT/'sheets'/f'{entity}_{view}_{g}.png')
    for p in (OUT/'native').glob('*/timing.json'):
        m=read(p);groups={}
        for o in m['observations']:
            name=o['action'];stage=name.rsplit('_armor_',1)[-1] if '_armor_' in name else '0'
            key=(stage,o['speed']);groups.setdefault(key,{})
            groups[key].setdefault(name,[]).append(ROOT/o['path'].removeprefix('res://'))
        for (stage,speed),actions in groups.items():sheet(list(actions.items()),OUT/'native_sheets'/f'{p.parent.name}_{stage}_{speed}.png')
    # Actual production screenshots, preserve full frame and label fixture status.
    for phase in ('before','after'):
        folder=OUT/phase/'runtime'
        for width in (320,390,540):
            paths=sorted(folder.glob(f'*_{width}.png'))
            if not paths:continue
            im=Image.new('RGB',(5*216,math.ceil(len(paths)/5)*435),(24,37,45));d=ImageDraw.Draw(im)
            for i,p in enumerate(paths):
                a=Image.open(p);a.thumbnail((208,410));x=i%5*216;y=i//5*435
                im.paste(a,(x,y+20));d.text((x,y+4),p.stem,fill='white')
            im.save(OUT/phase/f'ui_contact_{width}.png')
    print('Evidence sheets composed; no approvals written')
if __name__=='__main__':run()
