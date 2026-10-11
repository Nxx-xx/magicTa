"""Build an isolated, version-matched Godot WeChat project. No source assets are modified."""
from __future__ import annotations
import argparse
import datetime
import hashlib
import json
import os
from pathlib import Path
import re
import shutil
import subprocess
import sys
import urllib.request
import zipfile

ROOT = Path(__file__).resolve().parents[1]
# Local build budgets; actual upload eligibility is checked by WeChat.
TOTAL_PACKAGE_BUDGET_BYTES = 30 * 1024 * 1024
MAIN_PACKAGE_BUDGET_BYTES = 4 * 1024 * 1024
# Preserve source import quality for assets previously reduced for the 20 MiB budget.
SOURCE_QUALITY_TEXTURE_ROOTS = (
    'assets/environment/ruins/phase3/textures',
    'assets/environment/camp/v3',
    'assets/items/unique/icons',
)
CACHE = ROOT / 'build/wechat-toolchain'
PLUGIN = 'godot_mini_game_v0.2.1.zip'
EDITOR = 'Godot_v4.6.1-stable_win64.exe.zip'
DOWNLOADS = {
    PLUGIN: ('https://github.com/AnranS/godot_for_minigame/releases/download/v0.2.1/' + PLUGIN,
             '8f0cc36a925f828a980126cb19e864bfd4b79d0cd443412718e090a5089d552f'),
    EDITOR: ('https://github.com/godotengine/godot-builds/releases/download/4.6.1-stable/' + EDITOR,
             '088da0457e2d1f7f8a45e6d4605a42b756ea33b9ccd75059bdbc01bb31c2b40d'),
}

PRODUCTION_ART_MANIFESTS = (
    'assets/characters/hero/phase3/manifest.json',
    'assets/monsters/phase3/manifest.json',
    'assets/environment/ruins/phase3/runtime_v02.json',
)

def retired_art_exclusions(root):
    """Exclude only audited historical art, and only from the isolated copy.

    Do not infer general resource liveness from string searches: Godot also loads
    dynamic paths (notably hero_gait). Limit candidates to known replaced sets;
    production manifest references always win, including future republished art.
    """
    referenced = set()
    for relative in PRODUCTION_ART_MANIFESTS:
        manifest = json.loads((root / relative).read_text(encoding='utf-8'))
        def collect(value):
            if isinstance(value, str) and value.startswith('res://') and value.endswith('.png'):
                path = value.removeprefix('res://')
                if '..' in Path(path).parts or not (root / path).is_file():
                    raise RuntimeError('Missing or unsafe production art: ' + value)
                referenced.add(path)
            elif isinstance(value, dict):
                for child in value.values():
                    collect(child)
            elif isinstance(value, list):
                for child in value:
                    collect(child)
        collect(manifest)
    # Respect direct runtime references as well as animation catalog references.
    for folder in ('scripts', 'scenes', 'data'):
        for path in (root / folder).rglob('*'):
            if path.suffix in ('.gd', '.gdshader', '.tscn', '.tres', '.json'):
                referenced.update(relative for relative in re.findall(r'res://([^"\s\']+\.png)', path.read_text(encoding='utf-8-sig'))
                                  if (root / relative).is_file())
    referenced.update('assets/characters/hero/phase3/textures/gait/' + direction + '.png'
                      for direction in ('down', 'left', 'up', 'right'))
    candidates = set()
    for folder in ('assets/characters/hero/phase3/textures/v03',
                   'assets/monsters/phase3/textures/v04/golem'):
        candidates.update((root / folder).rglob('*.png'))
    # B polish frames are an isolated draft until published into manifest.json.
    # The production-reference guard below retains any frames once published.
    for revision in ('art_polish_b_v07', 'art_polish_b_v08'):
        candidates.update((root / 'assets/monsters/phase3/textures' / revision).rglob('*.png'))
    # Exact historical frames replaced by B v07; never prune whole version trees.
    # Live manifest/direct references above always override this retirement list.
    for retirement in (root / 'assets/monsters/phase3/source').glob('art_polish_b_v*/retired_runtime_frames.json'):
        for relative in json.loads(retirement.read_text(encoding='utf-8'))['paths']:
            path = root / relative.removeprefix('res://')
            if not path.resolve().is_relative_to((root / 'assets/monsters/phase3/textures').resolve()) or path.suffix != '.png':
                raise RuntimeError('Unsafe B retirement path: ' + relative)
            if path.is_file():
                candidates.add(path)
    candidates.update((root / 'assets/monsters/phase3/textures').glob('*.png'))
    candidates.update((root / 'assets/environment/ruins/phase3').glob('r[123]-atlas-draft.png'))
    excluded = {path.relative_to(root).as_posix() for path in candidates
                if path.relative_to(root).as_posix() not in referenced}
    # Import sidecars must follow their source; leave all workspace files intact.
    excluded.update(path + '.import' for path in tuple(excluded) if (root / (path + '.import')).is_file())
    return excluded, referenced

def verify_export_art(archive, excluded, referenced):
    """Verify actual exported remaps and texture payloads, not just source files."""
    with zipfile.ZipFile(archive) as package:
        names = set(package.namelist())
        for path in sorted(excluded):
            if path in names:
                raise RuntimeError('Retired art unexpectedly exported: ' + path)
        for path in sorted(referenced):
            remap = path + '.import'
            if remap not in names:
                raise RuntimeError('Production art remap missing from export: ' + path)
            text = package.read(remap).decode('utf-8')
            targets = re.findall(r'path="res://([^"]+)"', text)
            if not targets or any(target not in names for target in targets):
                raise RuntimeError('Production art payload missing from export: ' + path)
    return {'verified_png_remaps_and_payloads': len(referenced), 'retired_paths_absent': len(excluded)}

def sha(path):
    return hashlib.file_digest(path.open('rb'), 'sha256').hexdigest()

def dependency(name):
    url, digest = DOWNLOADS[name]
    path = CACHE / name
    if not path.exists() or sha(path) != digest:
        print('Downloading', name, flush=True)
        with urllib.request.urlopen(url, timeout=60) as response, path.with_suffix('.download').open('wb') as output:
            shutil.copyfileobj(response, output)
        if sha(path.with_suffix('.download')) != digest:
            raise RuntimeError('Checksum mismatch: ' + name)
        path.with_suffix('.download').replace(path)
    return path

def extract(archive, destination):
    with zipfile.ZipFile(archive) as z:
        for name in z.namelist():
            if not (destination / name).resolve().is_relative_to(destination.resolve()):
                raise RuntimeError('Unsafe archive path')
        z.extractall(destination)

def run(command, env, log):
    print('Running:', ' '.join(map(str, command)), flush=True)
    with log.open('w', encoding='utf-8') as out:
        result = subprocess.run(list(map(str, command)), env=env, stdout=out, stderr=subprocess.STDOUT, timeout=300)
    content = log.read_text(encoding='utf-8', errors='replace')
    if result.returncode or 'SCRIPT ERROR:' in content or 'Parse Error:' in content:
        print(content[-12000:])
        raise RuntimeError('Godot failed; see ' + str(log))

def main():
    parser = argparse.ArgumentParser()
    parser.add_argument('--appid', required=True)
    parser.add_argument('--ios-mode', choices=('high-performance-plus', 'high-performance'),
                        default='high-performance-plus', help='Use high-performance for the iOS crash comparison build')
    parser.add_argument('--output-folder', default='wechat', help='Dedicated folder name under build/')
    parser.add_argument('--no-latest', action='store_true', help='Do not write any latest pointer for an isolated verification build')
    args = parser.parse_args()
    if not re.fullmatch(r'wx[0-9a-fA-F]{16}', args.appid):
        parser.error('Expected a WeChat AppID, not AppSecret')
    if not re.fullmatch(r'wechat(?:-[a-z0-9-]+)?', args.output_folder):
        parser.error('Output folder must be wechat or wechat-<lowercase-name>')
    CACHE.mkdir(parents=True, exist_ok=True)
    sys.path.insert(0, str(CACHE / 'python'))
    from fontTools import subset
    from fontTools.ttLib import TTFont

    extract(dependency(EDITOR), CACHE / 'editor')
    extract(dependency(PLUGIN), CACHE / 'plugin')
    godot = CACHE / 'editor/Godot_v4.6.1-stable_win64_console.exe'
    stamp = datetime.datetime.now().strftime('%Y%m%d-%H%M%S-%f')
    work = ROOT / 'build/wechat-runs' / stamp
    stage = work / 'source'
    output = ROOT / 'build' / args.output_folder
    stage.mkdir(parents=True)
    excluded_art, production_art = retired_art_exclusions(ROOT)
    art_audit = {
        'policy': 'audited-retired-art-only; production-manifest-and-direct-references-retained',
        'production_manifests': list(PRODUCTION_ART_MANIFESTS),
        'referenced_png_count': len(production_art),
        'excluded_files': {path: (ROOT / path).stat().st_size for path in sorted(excluded_art)},
    }
    (work / 'asset-exclusions.json').write_text(json.dumps(art_audit, indent=2), encoding='utf-8')
    ignored = {'source', 'preview', 'previews', 'tools', 'reports', 'art_concepts', 'art_samples', '__pycache__'}
    def ignore(directory, names):
        # Keep the original camp painting in the workspace for comparison, but
        # do not ship the retired background alongside its runtime replacement.
        retired_camp = Path(directory) == ROOT / 'assets/environment/camp'
        return [n for n in names if n in ignored or n.endswith(('.md', '.py', '.ps1'))
                or (retired_camp and n == 'v2')
                or (Path(directory) == ROOT / 'assets/monsters/phase3' and n.startswith('art_polish_b') and n.endswith('candidate.json'))
                or (Path(directory) / n).relative_to(ROOT).as_posix() in excluded_art]
    for folder in ('assets', 'data', 'scenes', 'scripts'):
        shutil.copytree(ROOT / folder, stage / folder, ignore=ignore)
    shutil.copytree(CACHE / 'plugin/addons', stage / 'addons')
    shutil.copy2(ROOT / 'tools/wechat/export.gd.in', stage / 'export.gd')
    config = (ROOT / 'project.godot').read_text(encoding='utf-8')
    config = config.replace('"4.7"', '"4.6"')
    config = config.replace('pointing/emulate_touch_from_mouse=true', 'pointing/emulate_touch_from_mouse=false')
    config = config.replace('run/main_scene="res://scenes/map_prototype.tscn"', 'run/main_scene="res://scenes/wechat_entry.tscn"')
    (stage / 'project.godot').write_text(config, encoding='utf-8')
    shutil.copy2(ROOT / 'tools/wechat/safe_area.gd.in', stage / 'scripts/ui/wechat_safe_area.gd')
    (stage / 'scenes/wechat_entry.tscn').write_text('''[gd_scene load_steps=3 format=3]
[ext_resource type="Script" path="res://scripts/ui/wechat_safe_area.gd" id="1"]
[ext_resource type="PackedScene" path="res://scenes/map_prototype.tscn" id="2"]
[node name="WeChatRoot" type="Control"]
layout_mode = 3
anchors_preset = 15
anchor_right = 1.0
anchor_bottom = 1.0
grow_horizontal = 2
grow_vertical = 2
script = ExtResource("1")
[node name="Game" parent="." instance=ExtResource("2")]
''', encoding='utf-8')
    # All text, including decoded JSON, contributes glyphs; ASCII supports seed entry.
    corpus = ''.join(chr(i) for i in range(32, 127))
    for path in stage.rglob('*'):
        if path.suffix in {'.gd', '.json', '.tscn', '.tres', '.godot'}:
            text = path.read_text(encoding='utf-8-sig')
            corpus += text
            if path.suffix == '.json':
                corpus += json.dumps(json.loads(text), ensure_ascii=False)
    font_path = stage / 'assets/fonts/NotoSansSC.ttf'
    original_font_size = font_path.stat().st_size
    font = TTFont(font_path)
    options = subset.Options()
    options.name_IDs = ['*']
    sub = subset.Subsetter(options=options)
    sub.populate(text=corpus)
    sub.subset(font)
    # Modified font receives its own family name; retain upstream license records.
    for record in font['name'].names:
        if record.nameID in (1, 3, 4, 6, 16, 17):
            record.string = ('TowerRealmSubset' if record.nameID != 17 else 'Regular').encode(record.getEncoding())
    font.save(font_path)
    missing = sorted(set(ord(c) for c in corpus if '\u3400' <= c <= '\u9fff') - set(font.getBestCmap()))
    if missing:
        raise RuntimeError('Missing Chinese glyphs: ' + repr(missing))
    # Keep these assets' lossless imports, native dimensions and mipmap settings.
    # Other assets retain the existing mobile export preset.
    for path in (stage / 'assets').rglob('*.png.import'):
        if any(path.is_relative_to(stage / folder) for folder in SOURCE_QUALITY_TEXTURE_ROOTS):
            continue
        text = path.read_text(encoding='utf-8')
        text = text.replace('compress/mode=0', 'compress/mode=1')
        text = text.replace('process/size_limit=0', 'process/size_limit=1024')
        path.write_text(text, encoding='utf-8')
    (stage / 'export_presets.cfg').write_text('''[preset.0]
name="WeChat"
platform="Web"
runnable=true
export_filter="all_resources"
include_filter="data/*.json,assets/fonts/OFL.txt"
exclude_filter="addons/*,export.gd"
script_export_mode=0

[preset.0.options]
variant/thread_support=false
variant/extensions_support=false
vram_texture_compression/for_desktop=false
vram_texture_compression/for_mobile=false
''', encoding='utf-8')
    env = os.environ.copy()
    env['APPDATA'] = str(work / 'profile')
    env['LOCALAPPDATA'] = str(work / 'profile/local')
    Path(env['APPDATA']).mkdir(parents=True)
    Path(env['LOCALAPPDATA']).mkdir(parents=True)
    run([godot, '--headless', '--path', stage, '--editor', '--import'], env, work / 'import.log')
    run([godot, '--headless', '--path', stage, '--script', 'res://export.gd', '--', args.appid, output], env, work / 'export.log')
    art_audit['export_verification'] = verify_export_art(output / 'engine/godot.zip', excluded_art, production_art)
    game_config_path = output / 'game.json'
    game_config = json.loads(game_config_path.read_text(encoding='utf-8'))
    game_config['iOSHighPerformance'] = True
    game_config['iOSHighPerformance+'] = args.ios_mode == 'high-performance-plus'
    game_config_path.write_text(json.dumps(game_config, indent=2), encoding='utf-8')
    diagnostic = (ROOT / 'tools/wechat/startup_diagnostics.js').read_text(encoding='utf-8')
    diagnostic = diagnostic.split("if (typeof module !== 'undefined')")[0]
    build_id = stamp + '/' + args.ios_mode
    diagnostic += '\ninstallTowerStartupDiagnostics(wx, GameGlobal, ' + json.dumps(build_id) + ');\n'
    (output / 'js/startup_diagnostics.js').write_text(diagnostic, encoding='utf-8')
    entry = output / 'game.js'
    entry.write_text('import "./js/startup_diagnostics";\n' + entry.read_text(encoding='utf-8'), encoding='utf-8')
    # Replace the upstream no-op IndexedDB storage with synchronous native persistence.
    js = output / 'js/libs/godot.js'
    text = js.read_text(encoding='utf-8')
    anchor = 'Module["initFS"]=GodotFS.init;'
    if text.count(anchor) != 1:
        raise RuntimeError('Pinned engine persistence hook changed')
    patch = (ROOT / 'tools/wechat/persistence.js').read_text(encoding='utf-8')
    patch = patch.split("if (typeof module !== 'undefined')")[0]
    audio_patch = (ROOT / 'tools/wechat/native_audio.js').read_text(encoding='utf-8')
    audio_patch = audio_patch.split("if (typeof module !== 'undefined')")[0]
    keyboard_patch = (ROOT / 'tools/wechat/native_keyboard.js').read_text(encoding='utf-8')
    keyboard_patch = keyboard_patch.split("if (typeof module !== 'undefined')")[0]
    text = text.replace(anchor, anchor + patch + audio_patch + keyboard_patch + ';installTowerPersistence(Module,FS,GodotFS,wx);installTowerAudio(wx,window);installTowerKeyboard(wx,window);')
    js.write_text(text, encoding='utf-8')
    # Project-owned loader keeps presentation, progress and GL handoff together.
    # Native persistence restoration remains in the engine patch above.
    for name in ('loader.js', 'loading_screen.js'):
        shutil.copy2(ROOT / 'tools/wechat' / name, output / 'js' / name)
    shutil.copy2(ROOT / 'tools/wechat/assets/loading-background.jpg', output / 'images/loading-background.jpg')
    # Same artwork as the application icon and the WeChat account avatar.
    shutil.copy2(ROOT / 'assets/icon.png', output / 'images/logo.png')
    # Keep native touch for ScrollContainer drags plus mouse events for Web GUI.
    # emulate_touch_from_mouse=false in staging avoids synthesizing touch twice.
    adapter = output / 'adapter.js'
    text = adapter.read_text(encoding='utf-8')
    # Godot's Web touchscreen probe checks this property, not maxTouchPoints.
    anchor = 'innerWidth: _viewportWidth, innerHeight: _viewportHeight,'
    if text.count(anchor) != 1:
        raise RuntimeError('Pinned touchscreen probe changed')
    text = text.replace(anchor, anchor + '\n  ontouchstart: null,')
    anchor = 'function _toPointerEvt(type, t) {\n  return { type,'
    replacement = '''let _towerLastPointer = {x: 0, y: 0};
function _toPointerEvt(type, t) {
  const dx = type === "pointermove" ? t.clientX - _towerLastPointer.x : 0;
  const dy = type === "pointermove" ? t.clientY - _towerLastPointer.y : 0;
  _towerLastPointer = {x: t.clientX, y: t.clientY};
  return { type,'''
    if text.count(anchor) != 1:
        raise RuntimeError('Pinned pointer adapter changed')
    text = text.replace(anchor, replacement)
    start = text.index('function _toPointerEvt')
    text = text[:start] + text[start:].replace('movementX: 0, movementY: 0,', 'movementX: dx, movementY: dy,', 1)
    # Cancel the native owner before pointercancel can become a mouse release.
    # Otherwise a canceled map touch can be mistaken for a completed tap.
    cancel_anchor = '''    if (r.changedTouches[0]) _dispatchEvent("pointercancel", _toPointerEvt("pointercancel", r.changedTouches[0]));
    _dispatchEvent("touchcancel", _toTouchEvt("touchcancel", r));'''
    if text.count(cancel_anchor) != 1:
        raise RuntimeError('Pinned touch cancellation hook changed')
    text = text.replace(cancel_anchor, '''    _dispatchEvent("touchcancel", _toTouchEvt("touchcancel", r));
    if (r.changedTouches[0]) _dispatchEvent("pointercancel", _toPointerEvt("pointercancel", r.changedTouches[0]));''')
    anchor = '    return orig.call(native, path, imports).catch(function (e) {'
    if text.count(anchor) != 1:
        raise RuntimeError('Pinned WASM diagnostic hook changed')
    text = text.replace(anchor, '''    _global.__towerStartup.mark("wasm-instantiate", path);
    return orig.call(native, path, imports).then(function (result) {
      _global.__towerStartup.mark("wasm-ready", path);
      return result;
    }).catch(function (e) {
      _global.__towerStartup.mark("wasm-failed", e && (e.stack || e.message) || e);''')
    adapter.write_text(text, encoding='utf-8')
    notices = output / 'licenses'
    notices.mkdir(exist_ok=True)
    for name in ('LICENSE', 'GODOT_COPYRIGHT.txt', 'THIRD_PARTY_NOTICES.md'):
        shutil.copy2(stage / 'addons/godot_mini_game' / name, notices / name)
    shutil.copy2(ROOT / 'assets/fonts/OFL.txt', notices / 'FONT-OFL.txt')
    manifest_path = output / '.godot-mini-game-export.json'
    manifest = json.loads(manifest_path.read_text(encoding='utf-8'))
    for audio in (output / 'audio/native').glob('*.wav'):
        relative = audio.relative_to(output).as_posix()
        if relative not in manifest['required_files']:
            manifest['required_files'].append(relative)
        manifest['output_artifacts'][relative] = {'size': audio.stat().st_size, 'sha256': sha(audio)}
    for relative in ('js/libs/godot.js', 'js/loader.js', 'adapter.js', 'game.js', 'game.json', 'js/startup_diagnostics.js', 'js/loading_screen.js', 'images/loading-background.jpg', 'images/logo.png'):
        if relative not in manifest['required_files']:
            manifest['required_files'].append(relative)
        manifest['output_artifacts'][relative] = {'size': (output / relative).stat().st_size, 'sha256': sha(output / relative)}
    manifest['towerrealm_patches'] = ['native-persistence-v1', 'native-audio', 'native-keyboard-v1', 'touch-deduplication', 'touchscreen-probe', 'pointer-deltas', 'safe-area', 'loading-viewport', 'startup-diagnostics', 'moonlit-loading-v1']
    manifest['towerrealm_ios_mode'] = args.ios_mode
    manifest_path.write_text(json.dumps(manifest, indent=2), encoding='utf-8')
    files = {p.relative_to(output).as_posix(): {'bytes': p.stat().st_size, 'sha256': sha(p)}
             for p in output.rglob('*') if p.is_file()}
    total = sum(v['bytes'] for v in files.values())
    main_bytes = sum(v['bytes'] for k, v in files.items() if not k.startswith(('engine/', 'subpacks/')))
    report = {'appid': args.appid, 'godot': '4.6.1.stable', 'plugin': '0.2.1',
              'ios_mode': args.ios_mode, 'build_id': build_id,
              'font_before': original_font_size, 'font_after': font_path.stat().st_size,
              'asset_exclusions': art_audit,
              'source_quality_texture_roots': list(SOURCE_QUALITY_TEXTURE_ROOTS),
              'main_bytes': main_bytes, 'total_bytes': total, 'files': files,
              'package_budget': {'total_bytes': TOTAL_PACKAGE_BUDGET_BYTES,
                                 'main_bytes': MAIN_PACKAGE_BUDGET_BYTES},
              'validation': {'export': True, 'devtools': False, 'device': False}}
    (work / 'build-report.json').write_text(json.dumps(report, indent=2, ensure_ascii=False), encoding='utf-8')
    if total > TOTAL_PACKAGE_BUDGET_BYTES or main_bytes > MAIN_PACKAGE_BUDGET_BYTES:
        raise RuntimeError(f'Local package budget exceeded: total={total}/{TOTAL_PACKAGE_BUDGET_BYTES}, '
                           f'main={main_bytes}/{MAIN_PACKAGE_BUDGET_BYTES} bytes')
    archive = shutil.make_archive(str(work / 'TowerRealm-WeChat'), 'zip', output)
    if not args.no_latest:
        (ROOT / 'build' / (args.output_folder + '-latest.json')).write_text(json.dumps({'project': str(output), 'source': str(stage), 'report': str(work / 'build-report.json'), 'archive': archive}, indent=2), encoding='utf-8')
    print(json.dumps({'project': str(output), 'archive': archive, 'total_MiB': round(total / 1048576, 2), 'font_KiB': round(font_path.stat().st_size / 1024)}, ensure_ascii=False), flush=True)

if __name__ == '__main__':
    main()
