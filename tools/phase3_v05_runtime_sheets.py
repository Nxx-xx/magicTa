"""Compose production UI screenshot evidence for visual inspection; no asset edits."""
from pathlib import Path
from PIL import Image, ImageDraw

ROOT = Path(__file__).resolve().parents[1]
OUT = ROOT / 'build/verification/phase3/08-parallel/coordinator/runtime'

for width in (540, 320):
    paths = sorted(OUT.glob(f'*_{width}.png'))
    sheet = Image.new('RGB', (7 * 245, 2 * 495), '#25323b')
    draw = ImageDraw.Draw(sheet)
    for index, path in enumerate(paths):
        picture = Image.open(path).convert('RGB')
        picture.thumbnail((235, 465))
        x, y = (index % 7) * 245, (index // 7) * 495
        sheet.paste(picture, (x, y))
        draw.text((x + 3, y + 470), path.stem, fill='white')
    sheet.save(OUT / f'ui_contact_{width}.png')
    print(f'{width}: {len(paths)} production UI screenshots')
