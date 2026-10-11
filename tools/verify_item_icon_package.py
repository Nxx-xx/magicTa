"""Verify all icon imports inside the exported WeChat archive, then emit a clean
Godot harness that can load that archive without any source-project assets.
Run only after build_wechat.py has completed (the cached editor is shared).
"""
import hashlib
import json
import re
import zipfile
from pathlib import Path

ROOT = Path(__file__).resolve().parents[1]
OUT = ROOT / 'build/verification/item-icons'
latest = json.loads((ROOT/'build/wechat-current-latest.json').read_text())
report = json.loads(Path(latest['report']).read_text())
manifest = json.loads((ROOT/'assets/items/unique/manifest.json').read_text(encoding='utf-8'))
project = Path(latest['project'])
stage = Path(latest['source'])
pack = project/'engine/godot.zip'
checks = []
with zipfile.ZipFile(pack) as archive:
    for row in manifest['assets']:
        path = row['icon'].removeprefix('res://')
        assert hashlib.sha256((stage/path).read_bytes()).hexdigest() == row['icon_sha256']
        config = archive.read(path+'.import').decode()
        remap = re.search(r'^path="res://([^"]+)"', config, re.M).group(1)
        assert len(archive.read(remap)) > 0
        checks.append({'id':row['id'],'path':path,'packed_texture':remap})
    for relative in ['scripts/ui/item_icon_registry.gd','scripts/ui/item_icon.gd','scripts/ui/runtime_art.gd','scripts/ui/action_choices.gd','scripts/ui/paged_catalog.gd','data/content.json','data/phase3_items.json']:
        assert archive.read(relative) == (ROOT/relative).read_bytes(), relative
for relative, record in report['files'].items():
    assert hashlib.sha256((project/relative).read_bytes()).hexdigest() == record['sha256'], relative
result = {'build_id':report['build_id'],'total_bytes':report['total_bytes'],'main_bytes':report['main_bytes'],
          'icons':checks,'verified_build_files':len(report['files']),'data_and_ui_match':True}
(OUT/'package-audit.json').write_text(json.dumps(result,indent=2),encoding='utf-8')
harness = OUT/'packed-runtime'
harness.mkdir(exist_ok=True)
(harness/'project.godot').write_text('config_version=5\n[application]\nconfig/name="Item icon package check"\n')
code = '''extends SceneTree
func _initialize() -> void:
    if not ProjectSettings.load_resource_pack(PACK):
        push_error("Cannot mount exported zip")
        quit(1)
        return
    var registry = load("res://scripts/ui/item_icon_registry.gd")
    var art = load("res://scripts/ui/runtime_art.gd")
    var widget = load("res://scripts/ui/item_icon.gd")
    var failures := 0
    var items: Dictionary = JSON.parse_string(FileAccess.get_file_as_string("res://data/content.json")).items
    items.merge(JSON.parse_string(FileAccess.get_file_as_string("res://data/phase3_items.json")).items)
    var sheet := Image.create(7*128,4*96,false,Image.FORMAT_RGBA8)
    sheet.fill(Color("203541"))
    var index := 0
    for id in items:
        var path: String = registry.path_for(items[id])
        var texture = art.texture(path)
        var expected := Vector2(128,128) if id.begins_with("p3_") else Vector2(96,96)
        if texture == null or texture.get_size() != expected:
            push_error("Packed icon failed: " + id)
            failures += 1
        else:
            var preview: Image = texture.get_image()
            preview.convert(Image.FORMAT_RGBA8)
            preview.resize(48,48,Image.INTERPOLATE_LANCZOS)
            sheet.blend_rect(preview,Rect2i(0,0,48,48),Vector2i(index%7*128+12,index/7*96+24))
            preview.resize(32,32,Image.INTERPOLATE_LANCZOS)
            sheet.blend_rect(preview,Rect2i(0,0,32,32),Vector2i(index%7*128+80,index/7*96+32))
        index += 1
        var icon = widget.new()
        icon.item = items[id]
        icon.free()
    if items.size() != 28 or registry.PATHS.size() != 28: failures += 1
    sheet.save_png(PREVIEW)
    print("PACKED_ITEM_ICONS count=%d failures=%d" % [items.size(),failures])
    quit(1 if failures else 0)
'''.replace('PACK',json.dumps(pack.as_posix()),1).replace('PREVIEW',json.dumps((OUT/'packed-small-icons.png').as_posix()))
(harness/'verify.gd').write_text(code,encoding='utf-8')
print(f'Package: 28 imported textures, source data/UI identity, {len(report["files"])} file hashes passed; {report["total_bytes"]} bytes')
