"""Compose full production UI captures for review; source PNGs stay untouched."""
from pathlib import Path
from PIL import Image, ImageDraw

ROOT = Path(__file__).resolve().parents[1]
OUT = ROOT / 'build/verification/phase3/09-refinement/hero'

def sheet(paths, destination, columns, size=(270, 480)):
    rows = (len(paths) + columns - 1) // columns
    canvas = Image.new('RGB', (columns * size[0], rows * (size[1] + 24)), '#27333d')
    draw = ImageDraw.Draw(canvas)
    for i, path in enumerate(paths):
        picture = Image.open(path).convert('RGB')
        picture.thumbnail(size, Image.Resampling.LANCZOS)
        x, y = i % columns * size[0], i // columns * (size[1] + 24)
        canvas.paste(picture, (x + (size[0] - picture.width) // 2, y))
        draw.text((x + 4, y + size[1] + 3), path.stem, fill='white')
    canvas.save(destination)

actions = ['idle', 'attack', 'guard', 'hit', 'victory', 'defeat']
for width in [540, 320]:
    paths = [OUT / 'action-ui' / f'{a}_{width}_{channel}.png'
             for channel in ['fx', 'body'] for a in actions]
    sheet(paths, OUT / 'action-ui' / f'contact_{width}.png', 6)

runtime = sorted((OUT / 'runtime').glob('*.png'))
for width in [540, 320]:
    paths = [p for p in runtime if str(width) in p.stem]
    if paths:
        sheet(paths, OUT / 'runtime' / f'contact_{width}.png', 5, (216, 384))

host = OUT / 'regression/host-frames'
sheet([host / f'{i:02d}.png' for i in [0, 5, 10, 15, 20, 25]],
      OUT / 'regression/host_contact.png', 6)
print('Production UI evidence composed without changing source captures.')
