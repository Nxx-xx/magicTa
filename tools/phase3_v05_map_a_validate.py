"""Check final handoff against explicit reviews; build a source-only overview.

Does not approve frames, publish production assets, or invoke Godot.
"""
import hashlib
import html
import json
import os
from pathlib import Path
from PIL import Image, ImageDraw

ROOT = Path(__file__).resolve().parents[1]
BASE = ROOT / 'assets/monsters/phase3/source/parallel_v05/map'
OUT = ROOT / 'build/verification/phase3/08-parallel/map_a'
ENTITIES = ['slime', 'skeleton', 'bat', 'sentinel', 'p3_shield_sentinel']

def read(path):
    return json.loads(path.read_text(encoding='utf-8'))

def digest(path):
    return hashlib.sha256(path.read_bytes()).hexdigest()

def relative(path):
    return os.path.relpath(path, OUT).replace('\\', '/')

def validate():
    rows, cards = [], []
    overview = Image.new('RGB', (1300, 332), (24, 34, 44))
    draw = ImageDraw.Draw(overview)
    results = [(path, read(path)) for path in OUT.glob('*-result.json')]
    for column, entity in enumerate(ENTITIES):
        folder = BASE / entity
        review_path = folder / f'{entity}_publish_review.json'
        review = read(review_path)
        assert review['human_signoff'] is False, entity
        assert set(review['actions']) == {'map_idle'}, entity
        approved = review['actions']['map_idle']
        assert approved['decision'] == 'accepted', entity
        assert approved['source_action'] == 'idle', entity
        manifest_path = folder / approved['draft_manifest']
        manifest = read(manifest_path)
        assert manifest['status'] == 'draft', entity
        assert manifest['size'] == approved['size'] == [256, 256], entity
        assert manifest['anchor'] == approved['anchor'] == [128, 224], entity
        action = manifest['actions']['idle']
        assert action['fps'] == approved['fps'] == (8 if entity == 'bat' else 6), entity
        assert action['loop'] == approved['loop'] is True, entity
        assert action['events'] == approved['events'] == {}, entity
        assert action.get('pose_holds', {}) == approved['pose_holds'] == {}, entity
        frames = [folder / p for p in action['frames']]
        effects = [folder / p for p in action.get('effects_frames', [])]
        assert len(frames) == approved['frame_slots'] == 4, entity
        assert len(effects) == (4 if entity in ['sentinel', 'p3_shield_sentinel'] else 0), entity
        assert [digest(p) for p in frames] == approved['frame_sha256'], entity
        assert [digest(p) for p in effects] == approved.get('effects_sha256', []), entity
        images = [Image.open(p) for p in frames + effects]
        for im in images:
            assert im.size == (256, 256) and im.mode == 'RGBA', entity
            alpha = im.getchannel('A')
            assert alpha.getextrema()[0] == 0, entity
            assert alpha.crop((0, 0, 256, 1)).getbbox() is None, entity
            assert alpha.crop((0, 255, 256, 256)).getbbox() is None, entity
            assert alpha.crop((0, 0, 1, 256)).getbbox() is None, entity
            assert alpha.crop((255, 0, 256, 256)).getbbox() is None, entity
        assert len({hashlib.sha256(im.tobytes()).hexdigest() for im in images[:4]}) == 4, entity
        rig_path = folder / f'{entity}_map_rig.json'
        rig = read(rig_path)
        assert rig['status'] == 'draft' and rig['canvas'] == 512, entity
        assert rig['anchor'] == [256, 448] and rig['runtime_size'] == 256, entity
        required = [folder / '.gdignore', folder / 'PROMPTS.md', folder / 'REVIEW.md',
                    folder / rig['source'], folder / f'{entity}_map_editable_draft.tscn',
                    folder / f'{entity}_map_review.html']
        assert all(p.is_file() for p in required), entity
        native_results = [(p, r) for p, r in results
                          if f'--source=res://{relative(rig_path).replace("../../../../../", "")}' in r.get('arguments', [])]
        assert native_results, f'{entity}: missing locked bake evidence'
        last_path, last_result = max(native_results, key=lambda item: item[1]['started_utc'])
        assert last_result['exit_code'] == 0 and last_result['script_error'] is False, entity
        native_log = Path(last_result['log']).read_text(encoding='utf-8')
        assert '0 source reload failures' in native_log, entity
        assert '--headless' not in last_result['arguments'], entity
        rows.append(dict(entity=entity, body_frames=4, effect_frames=len(effects), fps=action['fps'],
                         approved_body_sha256=approved['frame_sha256'],
                         approved_effect_sha256=approved.get('effects_sha256', []),
                         native_result=relative(last_path), human_signoff=False,
                         source_manifest_sha256=digest(manifest_path),
                         native_scene_sha256=digest(required[4]),
                         original_image_sha256=digest(folder / rig['source']),
                         prompt_sha256=digest(folder / 'PROMPTS.md'), review_sha256=digest(review_path)))
        first = images[0]
        overview.paste(first, (column * 260 + 2, 25), first)
        draw.text((column * 260 + 12, 7), f'{entity} | 4 frames | {int(action["fps"])} FPS', fill='white')
        x = column * 260 + 44
        for size in [26, 33, 47]:
            thumb = first.resize((size, size), Image.Resampling.LANCZOS)
            overview.paste(thumb, (x, 275), thumb)
            x += size + 24
        cards.append(f'<article><h2>{html.escape(entity)}</h2><p>4帧 · {int(action["fps"])} FPS</p>'
                     f'<img class="animation" src="{entity}_map_idle_original.webp" alt="{entity}原速动画">'
                     f'<div><a href="{relative(folder / f"{entity}_map_review.html")}">完整逐帧审阅</a> · '
                     f'<a href="{relative(review_path)}">批准哈希</a> · '
                     f'<a href="{relative(folder / "REVIEW.md")}">审阅说明</a></div></article>')
    report = dict(status='passed', scope='map_a source handoff only', human_signoff=False,
                  body_frames=20, effect_frames=8, new_imagegen_outputs=7,
                  size=[256, 256], anchor=[128, 224], entities=rows,
                  limitations=['Coordinator production integration is separate',
                               'Human art/naturalness signoff remains false',
                               'No measured device/cache performance claim'])
    (OUT / 'map_a_final_validation.json').write_text(json.dumps(report, indent=2) + '\n', encoding='utf-8')
    overview.save(OUT / 'map_a_overview.png')
    page = '<!doctype html><html lang="zh"><meta charset="utf-8"><title>MAP A 完整源稿交付</title>'
    page += '<style>body{background:#18222c;color:#eee;font:16px sans-serif;margin:24px}a{color:#8dd6ff}.grid{display:flex;flex-wrap:wrap;gap:16px}article{padding:16px;background:#25303a}.animation{width:256px;height:256px}h2{font-size:18px}</style>'
    page += '<h1>MAP A 完整源稿交付</h1><p>五种怪物 · 20身体帧 + 8独立效果帧 · 256×256 · 锚点(128,224)。本页原速动画显示身体；完整审阅页可切换效果、0.25倍及逐帧。</p>'
    page += '<p>Agent逐实体审阅及批准哈希核对通过。原生源稿为 draft，真人签收 false。生产整合与发布由统筹单独完成。</p>'
    page += '<p><a href="map_a_final_validation.json">最终一致性核对</a> · <a href="map_a_overview.png">总览图</a></p><div class="grid">' + ''.join(cards) + '</div></html>'
    (OUT / 'map_a_overview.html').write_text(page, encoding='utf-8')
    print(json.dumps(dict(status='passed', entities=ENTITIES, body_frames=20, effect_frames=8)))

if __name__ == '__main__':
    validate()
