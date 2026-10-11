"""Audit the dedicated local build; never reads or writes a shared latest pointer."""
import hashlib,json,re,zipfile
from pathlib import Path
ROOT=Path(__file__).resolve().parents[1]
OUT=ROOT/'build/verification/item-icons-v02'
result=json.loads((OUT/'wechat-result.json').read_text(encoding='utf-8-sig'))
assert result['exit_code']==0,result
report_path=Path(result['reports'][-1])
report=json.loads(report_path.read_text())
stage=report_path.parent/'source'
project=ROOT/'build/wechat-item-icons'
pack=project/'engine/godot.zip'
manifest=json.loads((ROOT/'assets/items/painted_v02_manifest.json').read_text())
checks=[]
with zipfile.ZipFile(pack) as z:
    assert not any('assets/items/source/' in n or 'assets/items/phase3/masters/' in n for n in z.namelist()),'Historical/source art shipped'
    for row in manifest['assets']:
        path=row['icon'].removeprefix('res://')
        assert hashlib.sha256((stage/path).read_bytes()).hexdigest()==row['icon_sha256'],path
        config=z.read(path+'.import').decode()
        remap=re.search(r'^path="res://([^"]+)"',config,re.M).group(1)
        assert z.read(remap),remap
        checks.append({'id':row['id'],'path':path,'packed_texture':remap,'bytes':len(z.read(remap))})
    for relative in ['scripts/ui/item_icon_registry.gd','scripts/ui/action_icon.gd','data/content.json','data/phase3_items.json']:
        assert z.read(relative)==(ROOT/relative).read_bytes(),relative
for relative,rec in report['files'].items():
    assert hashlib.sha256((project/relative).read_bytes()).hexdigest()==rec['sha256'],relative
(OUT/'package-audit.json').write_text(json.dumps({'report':str(report_path),'archive':str(report_path.parent/'TowerRealm-WeChat.zip'),'total_bytes':report['total_bytes'],'main_bytes':report['main_bytes'],'icons':checks,'historical_art_absent':True,'source_data_match':True,'runtime_texture_bytes':sum(x['bytes'] for x in checks)},indent=2))
harness=OUT/'packed-runtime'
harness.mkdir(exist_ok=True)
(harness/'project.godot').write_text('config_version=5\n[application]\nconfig/name="Item v02 package audit"\n')
code='''extends SceneTree
func _initialize() -> void:
    if not ProjectSettings.load_resource_pack(PACK):
        push_error("Package mount failed")
        quit(1)
        return
    var registry = load("res://scripts/ui/item_icon_registry.gd")
    var paths: Dictionary = registry.PATHS.duplicate()
    paths.merge(registry.ACTION_PATHS)
    var failures := 0
    var sheet := Image.create(7*128,5*96,false,Image.FORMAT_RGBA8)
    sheet.fill(Color("203541"))
    var index := 0
    for id in paths:
        var texture = load(paths[id])
        var expected := Vector2(96,96) if str(paths[id]).contains("/unique/") else Vector2(128,128)
        if texture == null or texture.get_size() != expected:
            push_error("Packed texture mismatch: " + str(id))
            failures += 1
        else:
            var preview: Image = texture.get_image()
            preview.convert(Image.FORMAT_RGBA8)
            if preview.detect_alpha() == Image.ALPHA_NONE: failures += 1
            preview.resize(48,48,Image.INTERPOLATE_LANCZOS)
            sheet.blend_rect(preview,Rect2i(0,0,48,48),Vector2i(index%7*128+12,index/7*96+24))
            preview.resize(32,32,Image.INTERPOLATE_LANCZOS)
            sheet.blend_rect(preview,Rect2i(0,0,32,32),Vector2i(index%7*128+80,index/7*96+32))
        index += 1
    if paths.size() != 31: failures += 1
    sheet.save_png(PREVIEW)
    print("PACKED_ITEM_V02 count=%d failures=%d" % [paths.size(),failures])
    quit(1 if failures else 0)
'''.replace('PACK',json.dumps(pack.as_posix()),1).replace('PREVIEW',json.dumps((OUT/'packed-small-icons.png').as_posix()))
(harness/'verify.gd').write_text(code)
print(f'31 packed remaps verified; runtime textures {sum(x["bytes"] for x in checks)} bytes; total {report["total_bytes"]} bytes')
