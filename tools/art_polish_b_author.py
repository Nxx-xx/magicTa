"""Versioned native component refinements. No raster repainting or publication."""
import json, shutil
from pathlib import Path

ROOT = Path(__file__).resolve().parents[1]
SRC = ROOT/'assets/monsters/phase3/source/art_polish_b_v07'
BASE = ROOT/'build/verification/art-polish-b/baseline-manifest.json'

def read(p): return json.loads(p.read_text(encoding='utf-8-sig'))

def author():
    SRC.mkdir(parents=True, exist_ok=True)
    (SRC/'.gdignore').touch()
    manifest = read(BASE)
    routes = {}
    for source in sorted({a['source'] for a in manifest['actions'].values() if a['status']=='accepted'}):
        origin = ROOT/source.removeprefix('res://')
        d = read(origin)
        entity = d['entity'].removesuffix('_map')
        view = 'map' if d['entity'].endswith('_map') else 'battle'
        dest = SRC/entity/view
        dest.mkdir(parents=True, exist_ok=True)
        references = {d['source']}
        references.update(l['source'] for l in d['layers'] if 'source' in l)
        for shapes in d.get('shape_layers', {}).values():
            references.update(s['source'] for s in shapes)
        for ref in references:
            target = dest/ref
            target.parent.mkdir(parents=True, exist_ok=True)
            if not target.exists(): shutil.copyfile(origin.parent/ref, target)
        changes = []
        effects = set(d.get('effect_layers', []))
        for l in d['layers']:
            n = l['name']
            if l.get('joint_only') or n in effects or n in ('shadow','core','face','membrane'):
                if entity=='slime' and n=='face':
                    l['art_scale']=[1.09,1.04]; changes.append(n)
                continue
            width = 1.0
            lift = 0.0
            cool = 0.0
            if n in ('head','helmet','hood'):
                width = 1.10 if entity not in ('golem','minotaur') else 1.035
            if n in ('torso','body','waist','pelvis'):
                width = 1.10 if entity in ('warlock','warden','berserker','p3_ember_channeler') else 1.045
            if any(x in n for x in ('upper_arm','forearm','thigh','shin')): width = 1.055
            if n in ('near_pauldron','far_pauldron','bastion_shoulder','lock_shoulder'): width=1.10
            if n=='shield': width=1.045
            if entity in ('warlock','p3_ember_channeler'):
                if n in ('hood','torso','skirt','near_upper_arm','near_forearm','far_upper_arm','far_forearm','cape'):
                    lift=.065; cool=.12
                if n=='skirt': width=1.06
            elif entity in ('knight','warden','berserker','p3_vault_knight'):
                if n not in ('sword','axe','mace','weapon','chain','ornament','key_crown'):
                    lift=.026; cool=.10
            elif entity in ('golem','sentinel','p3_shield_sentinel'):
                if n not in ('core','dark_flame','armor_rune','debris'):
                    lift=.015; cool=.07
            elif entity=='skeleton': lift=.012; cool=.035
            elif entity=='minotaur':
                if n in ('torso','head','upper_arm','forearm','far_upper_arm','far_forearm'): cool=.045
            elif entity=='bat':
                if 'wing' in n or 'tip' in n: cool=.065
            if width!=1 or lift or cool:
                l['art_scale']=[width,1.0]
                l['art_material']={'shadow_lift':lift,'cool_mix':cool}
                changes.append(n)
        d['art_polish']={'baseline_source':source,'description':'Local painted component width and material separation; unchanged bone pivots, contact paths, root, action poses/events/timing and physical accessories.', 'changed_components':changes,'human_signoff':False}
        target=dest/origin.name
        target.write_text(json.dumps(d,ensure_ascii=False,indent=2)+'\n',encoding='utf8')
        routes[source]='res://'+target.relative_to(ROOT).as_posix()
    (SRC/'art_polish_b_routes.json').write_text(json.dumps(routes,indent=2)+'\n',encoding='utf8')
    print('Prepared',len(routes),'native sources; production unchanged')

if __name__=='__main__':author()
