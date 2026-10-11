"""Package ImageGen facial edits as local patches; never synthesize facial artwork."""
from pathlib import Path
from PIL import Image, ImageDraw, ImageFilter, ImageChops
import json

ROOT = Path(__file__).resolve().parents[1]
SOURCE = ROOT / 'assets/story/expressions/source'
OUT = ROOT / 'assets/story/expressions/textures'
OUT.mkdir(parents=True, exist_ok=True)
REVIEW = ROOT / 'build/verification/story-expressions'
BOXES = {
    'hero_guarded': (470, 246, 720, 465),
    'hero_shock': (470, 246, 720, 465),
    'prince_weary': (480, 204, 704, 414),
    'prince_sneer': (480, 204, 704, 414),
    'demon_stern': (514, 208, 690, 396),
}
manifest = []
for name, _, base_path in json.loads((SOURCE / 'generation_manifest.json').read_text()):
    base = Image.open(ROOT / base_path).convert('RGBA')
    master = Image.open(SOURCE / (name + '_master.png')).convert('RGBA')
    box = BOXES[name]
    patch = master.crop(box)
    # Feather only the extraction boundary, retaining the generated eyes/brows/mouth.
    mask = Image.new('L', patch.size)
    ImageDraw.Draw(mask).rectangle((8, 8, patch.width-9, patch.height-9), fill=255)
    mask = mask.filter(ImageFilter.GaussianBlur(3))
    # The edit masters have a flattened backdrop. Never bring it across the
    # original transparent hair/face silhouette, including antialiased edges.
    silhouette = base.getchannel('A').crop(box).point(lambda a: 255 if a >= 245 else 0)
    mask = ImageChops.multiply(mask, silhouette)
    patch.putalpha(mask)
    patch.save(OUT / (name + '_v01.png'), optimize=True)
    composite = base.copy()
    composite.alpha_composite(patch, box[:2])
    composite.save(SOURCE / (name + '_composite.png'))
    # Native resolution close-up, base and extracted/composited result side by side.
    face_box = (360,160,780,540)
    contact = Image.new('RGB', (840, 380), '#13212a')
    for i, im in enumerate([base, composite]):
        face = im.crop(face_box)
        contact.paste(face, (i*420,0), face)
    contact.save(REVIEW / (name + '_face_review.png'))
    manifest.append({'name': name, 'base': base_path, 'box': box, 'size': patch.size})
(SOURCE / 'patch_manifest.json').write_text(json.dumps(manifest, indent=2))
print(json.dumps(manifest, indent=2))
