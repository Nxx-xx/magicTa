import json,sys
from pathlib import Path
from PIL import Image,ImageDraw
ROOT=Path(__file__).resolve().parents[1]
E=ROOT/'build/verification/phase3/08-parallel/base_a'
entity=sys.argv[1]
samples=json.loads((E/f'{entity}_native_timing.json').read_text(encoding='utf8'))
for speed in [1,.25]:
    selected=[s for s in samples if s['speed']==speed]
    canvas=Image.new('RGB',(6*170,4*192),'#243440'); d=ImageDraw.Draw(canvas)
    for row,act in enumerate(['idle','attack','hit','defeat']):
        for s in [x for x in selected if x['action']==act]:
            col=s['sample'];path=ROOT/s['path'].removeprefix('res://')
            im=Image.open(path).convert('RGBA').resize((170,170),Image.Resampling.LANCZOS)
            canvas.paste(im,(col*170,row*192),im)
            d.text((col*170+2,row*192+165),f"{act} {col} t={s['wall_seconds']:.3f}",fill='white')
            d.text((col*170+2,row*192+178),f"anim={s['animation_seconds']:.3f} {speed}x",fill='white')
    canvas.save(E/f'{entity}_native_{speed}x_contact.png')
print(f'{entity}: {len(samples)} timed native screenshots grouped for actual visual review; no approval generated')
