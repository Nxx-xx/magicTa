"""Prepare an explicit preview candidate, NEVER mutate production manifest."""
import copy, hashlib, json, shutil, zipfile, io
from pathlib import Path
from PIL import Image, ImageDraw
ROOT=Path(__file__).resolve().parents[1]
SRC=ROOT/'assets/monsters/phase3/source/art_polish_b_v07'
OUT=ROOT/'build/verification/art-polish-b'
CANDIDATE=ROOT/'assets/monsters/phase3/art_polish_b_candidate.json'
def read(p):return json.loads(p.read_text(encoding='utf-8-sig'))
def sha(p):return hashlib.sha256(p.read_bytes()).hexdigest()
def run():
    live=read(ROOT/'assets/monsters/phase3/manifest.json')
    assert not any('/'+SRC.name+'/' in a.get('source','') for a in live['actions'].values()),'Published textures are immutable; author a new revision instead'
    baseline=read(OUT/'baseline-manifest.json'); routes=read(SRC/'art_polish_b_routes.json')
    candidate=copy.deepcopy(baseline); records={}; oldfiles=set(); newfiles=set()
    for key,a in baseline['actions'].items():
        if a['status']!='accepted':continue
        if a['source'] not in routes:continue
        source=ROOT/routes[a['source']].removeprefix('res://'); rig=read(source)
        folder=source.parent; draft_path=folder/(rig['entity']+'_draft_manifest.json'); draft=read(draft_path)
        entity=rig['entity'].removesuffix('_map'); action='idle' if rig['entity'].endswith('_map') else key[len(entity)+1:]
        d=draft['actions'][action]
        for field in ('fps','loop','events'):assert d[field]==a[field],(key,field)
        for field in ('size','anchor'):assert draft[field]==a[field],(key,field)
        assert len(d['frames'])==len(a['frames'])
        assert d.get('pose_holds',{})==a.get('pose_holds',{}),(key,'hold')
        assert not any(x['edge_touch'] for x in d['metrics']),(key,'clipping')
        n=copy.deepcopy(a)
        for field in ('publish_review','coordinator_review'):n.pop(field,None)
        n.update(status='draft',source=routes[a['source']],review='source/'+SRC.name+'/REVIEW.md')
        record={'baseline':a,'draft_manifest':draft_path.relative_to(ROOT).as_posix(),'source_action':action,'rig_sha256':sha(source),'draft_sha256':sha(draft_path),'channels':{}}
        for channel in ('frames','effects_frames'):
            assert (channel in a)==(channel in d),(key,channel)
            if channel not in a:continue
            paths=[]; hashes=[]
            for i,relative in enumerate(d[channel]):
                source_frame=folder/relative
                target=ROOT/'assets/monsters/phase3/textures'/SRC.name/entity/key[len(entity)+1:]/channel/f'{i:02}.png'
                target.parent.mkdir(parents=True,exist_ok=True)
                # Draft candidate may be re-baked before review, old released assets are untouched.
                shutil.copyfile(source_frame,target)
                paths.append('res://'+target.relative_to(ROOT).as_posix());hashes.append(sha(target));newfiles.add(target)
            oldfiles.update(ROOT/p.removeprefix('res://') for p in a[channel]);n[channel]=paths;record['channels'][channel]=hashes
        candidate['actions'][key]=n;records[key]=record
    candidate['art_polish_b']={'status':'draft_explicit_preview_only','human_signoff':False,'production_publication':'Requires coordinator exact-SHA review; original manifest remains unchanged.'}
    CANDIDATE.write_text(json.dumps(candidate,ensure_ascii=False,indent=2)+'\n',encoding='utf8')
    (SRC/'art_polish_b_review_inventory.json').write_text(json.dumps(records,ensure_ascii=False,indent=2)+'\n',encoding='utf8')
    def zipbytes(files):
        stream=io.BytesIO()
        with zipfile.ZipFile(stream,'w',zipfile.ZIP_DEFLATED,9) as z:
            for p in sorted(files):z.write(p,p.relative_to(ROOT).as_posix())
        return len(stream.getvalue())
    budget={'old_png_bytes':sum(p.stat().st_size for p in oldfiles),'new_png_bytes':sum(p.stat().st_size for p in newfiles),'old_png_zip_bytes':zipbytes(oldfiles),'new_png_zip_bytes':zipbytes(newfiles),'old_files':len(oldfiles),'new_files':len(newfiles),'scope':'Source PNG replacement estimate, NOT Godot imported texture or WeChat export size.'}
    budget['png_zip_delta']=budget['new_png_zip_bytes']-budget['old_png_zip_bytes']
    (OUT/'budget.json').write_text(json.dumps(budget,indent=2)+'\n',encoding='utf8')
    # Contact sheets are evidence composition only; source/output frames are not edited.
    for view in ('battle','map'):
        ids=sorted({k.removesuffix('_map_idle') if view=='map' else k.removesuffix('_idle') for k in records if (k.endswith('_map_idle') if view=='map' else k.endswith('_idle') and not k.endswith('_map_idle'))})
        sheet=Image.new('RGB',(1040,((len(ids)+3)//4)*270),(22,34,42));draw=ImageDraw.Draw(sheet)
        for i,entity in enumerate(ids):
            k=entity+('_map_idle' if view=='map' else '_idle');x=(i%4)*260;y=(i//4)*270
            draw.text((x+8,y+5),entity+' baseline / '+SRC.name.rsplit('_',1)[-1],fill='white')
            for j,m in enumerate((baseline,candidate)):
                im=Image.open(ROOT/m['actions'][k]['frames'][0].removeprefix('res://')).convert('RGBA')
                im.thumbnail((128,180),Image.Resampling.LANCZOS);sheet.paste(im,(x+j*130,y+28),im)
                for n,size in enumerate((26,33,47)):
                    tiny=im.resize((size,size),Image.Resampling.LANCZOS);sheet.paste(tiny,(x+j*130+n*40,y+208),tiny)
        sheet.save(OUT/(view+'_comparison.png'))
    print(json.dumps(budget));print(len(records),'candidate timelines; production unchanged')
if __name__=='__main__':run()
