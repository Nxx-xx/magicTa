"""Compose inspectable native playback evidence. Never writes asset pixels."""
import argparse
import json
from pathlib import Path

from PIL import Image, ImageDraw

ROOT = Path(__file__).resolve().parents[1]


def compose(evidence):
    data = json.loads((evidence / 'timing.json').read_text(encoding='utf-8'))
    for speed in (1, .25):
        observations = [o for o in data['observations'] if o['speed'] == speed]
        ids = list(dict.fromkeys(o['action'] for o in observations))
        groups = [[o for o in observations if o['action'] == action] for action in ids]
        columns = max(map(len, groups))
        sheet = Image.new('RGB', (columns * 260, len(groups) * 290), '#25323b')
        draw = ImageDraw.Draw(sheet)
        for row, group in enumerate(groups):
            for col, observation in enumerate(group):
                path = ROOT / observation['path'].removeprefix('res://')
                picture = Image.open(path).convert('RGBA')
                sheet.paste(picture, (col*260, row*290), picture)
                draw.text((col*260+4, row*290+258), f"{observation['action']} #{observation['sample']} wall={observation['wall_seconds']:.3f}s\nanim={observation['animation_seconds']:.3f}s x{speed}", fill='white')
        sheet.save(evidence / f'playback_{speed}x.png')
    print(evidence)


def compose_draft(draft_path, evidence):
    data = json.loads(draft_path.read_text(encoding='utf-8'))
    actions = list(data['actions'].items())
    columns = max(len(a['frames']) for _, a in actions)
    sheet = Image.new('RGB', (columns*260, len(actions)*286), '#25323b')
    effects = Image.new('RGB', sheet.size, '#25323b')
    small = Image.new('RGB', (columns*95+100, len(actions)*160), '#25323b')
    draw, fxdraw, small_draw = ImageDraw.Draw(sheet), ImageDraw.Draw(effects), ImageDraw.Draw(small)
    for row, (name, action) in enumerate(actions):
        for col, frame in enumerate(action['frames']):
            picture = Image.open(draft_path.parent/frame).convert('RGBA')
            sheet.paste(picture, (col*260,row*286),picture)
            draw.text((col*260+4,row*286+260),f'{name} #{col}',fill='white')
            if action.get('effects_frames'):
                effect = Image.open(draft_path.parent/action['effects_frames'][col]).convert('RGBA')
                effects.paste(effect,(col*260,row*286),effect)
            fxdraw.text((col*260+4,row*286+260),f'{name} FX #{col}',fill='white')
            for size_index, size in enumerate((26,33,47)):
                thumbnail=picture.resize((size,size),Image.Resampling.LANCZOS)
                small.paste(thumbnail,(100+col*95,row*160+size_index*50),thumbnail)
                small_draw.text((2,row*160+size_index*50),f'{name} {size}px',fill='white')
    evidence.mkdir(parents=True,exist_ok=True)
    sheet.save(evidence/'keyframes.png')
    effects.save(evidence/'effects.png')
    small.save(evidence/'small_sizes.png')


if __name__ == '__main__':
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument('evidence')
    parser.add_argument('--draft')
    options = parser.parse_args()
    evidence=(ROOT/options.evidence).resolve()
    if options.draft:
        compose_draft((ROOT/options.draft).resolve(),evidence)
    else:
        compose(evidence)
