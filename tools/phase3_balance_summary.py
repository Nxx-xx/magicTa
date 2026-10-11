"""Summarize actual route evidence without changing game data or accounts."""
import csv,json,statistics,collections
from pathlib import Path
ROOT=Path(__file__).resolve().parents[1]
OUT=ROOT/'build/verification/phase3/06-animation-balance'
report={}
for mode,filename in [('minimal','balance-quick.json'),('supplied','supplied/balance-batch.json'),('prepared','prepared/balance-batch.json'),('variants','variants/balance-batch.json')]:
    if not (OUT/filename).exists():continue
    data=json.loads((OUT/filename).read_text(encoding='utf-8'))
    actual_variants=collections.Counter()
    groups=collections.defaultdict(lambda:dict(routes=0,wins=0,battles=0,zero_damage_battles=0,boss_damage=[],floors=collections.defaultdict(list)))
    for route in data['routes']:
        ctx=route['context'];key='/'.join([ctx['challenge'],ctx['start_config'],route['build']]);g=groups[key]
        g['routes']+=1;g['wins']+=int(route['won'])
        for cp in route['checkpoints']:
            g['floors'][str(cp['floor'])].append({k:cp['player'][k] for k in ['hp','gold'] }|{k:cp['stats'][k] for k in ['attack','defense','max_hp']})
        trace=json.loads((OUT/Path(filename).parent/route['trace_file']).read_text(encoding='utf-8'))
        for a in trace['actions']:
            if a.get('kind')!='fight':continue
            if a['enemy_id'] in ('p3_shield_sentinel','p3_ember_channeler','p3_vault_knight'):
                actual_variants[a['enemy_id']]+=1
            g['battles']+=1;g['zero_damage_battles']+=int(a['report']['incoming']==0)
            if a['enemy_id'] in ('minotaur','golem'):g['boss_damage'].append(a['report']['incoming'])
    for g in groups.values():
        g['zero_damage_ratio']=round(g['zero_damage_battles']/max(1,g['battles']),3)
        g['boss_damage_range']=[min(g['boss_damage']),max(g['boss_damage'])] if g['boss_damage'] else []
        del g['boss_damage']
        g['floors']={f:{k:{'min':min(x[k] for x in entries),'median':statistics.median(x[k] for x in entries),'max':max(x[k] for x in entries)} for k in ['hp','gold','attack','defense','max_hp']} for f,entries in g['floors'].items()}
    variants=[o for o in data['observations'] if 'extra_incoming' in o]
    report[mode]=dict(routes=data['route_count'],wins=data['wins'],checks=data['checks'],failed_checks=len(data['failures']),groups=groups,
       variant_samples=len(variants),variant_over20=sum(o['exceeds_20_percent'] for o in variants),
       variant_extra_range=[min(o['extra_incoming'] for o in variants),max(o['extra_incoming'] for o in variants)] if variants else [],
       actual_variant_battles=dict(actual_variants),
       variant_skipped_lethal=sum(bool(o.get('optional_variant_skipped_lethal')) for o in data['observations']),
       provenance=data['account_provenance'])
(OUT/'balance-summary.json').write_text(json.dumps(report,ensure_ascii=False,indent=2),encoding='utf-8')
with (OUT/'late-floor-curves.csv').open('w',newline='',encoding='utf-8-sig') as fp:
    writer=csv.writer(fp);writer.writerow(['challenge/start/build','floor','hp_min','hp_median','max_hp_median','attack_median','defense_median','gold_median'])
    for key,g in report['prepared']['groups'].items():
        for floor,values in g['floors'].items():
            if int(floor)>=6:writer.writerow([key,floor,values['hp']['min'],values['hp']['median'],values['max_hp']['median'],values['attack']['median'],values['defense']['median'],values['gold']['median']])
for mode,data in report.items():print(mode, data['wins'],'/',data['routes'],'variants',data['variant_samples'],'over20',data['variant_over20'])
for key,g in report['prepared']['groups'].items():
    if key.endswith('/defense'):print(key,'zero damage',g['zero_damage_ratio'],'boss damage',g['boss_damage_range'])
