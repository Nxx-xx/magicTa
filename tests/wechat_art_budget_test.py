"""Guard isolated export pruning against dropping production/dynamic art."""
import importlib.util
import json
from pathlib import Path
import tempfile
import unittest
import zipfile

ROOT = Path(__file__).resolve().parents[1]
spec = importlib.util.spec_from_file_location('build_wechat', ROOT / 'tools/build_wechat.py')
build = importlib.util.module_from_spec(spec)
spec.loader.exec_module(build)


class ArtBudgetTest(unittest.TestCase):
    def write(self, root, path, text=''):
        target = root / path
        target.parent.mkdir(parents=True, exist_ok=True)
        target.write_text(text, encoding='utf-8')

    def test_republished_and_direct_references_override_retirement(self):
        with tempfile.TemporaryDirectory() as folder:
            root = Path(folder)
            base = 'assets/characters/hero/phase3/textures/v03/'
            for relative in build.PRODUCTION_ART_MANIFESTS:
                self.write(root, relative, '{}')
            for name in ('old', 'republished', 'direct'):
                self.write(root, base + name + '.png')
                self.write(root, base + name + '.png.import')
            self.write(root, build.PRODUCTION_ART_MANIFESTS[0], json.dumps({'frames': ['res://' + base + 'republished.png']}))
            self.write(root, 'scripts/art.gd', 'const ART = "res://' + base + 'direct.png"')
            self.write(root, 'assets/characters/hero/phase3/textures/future/new.png')
            excluded, _ = build.retired_art_exclusions(root)
            self.assertEqual(excluded, {base + 'old.png', base + 'old.png.import'})

    def test_missing_production_frame_fails_before_copy(self):
        with tempfile.TemporaryDirectory() as folder:
            root = Path(folder)
            for relative in build.PRODUCTION_ART_MANIFESTS:
                self.write(root, relative, '{}')
            self.write(root, build.PRODUCTION_ART_MANIFESTS[0], '{"frames":["res://assets/missing.png"]}')
            with self.assertRaisesRegex(RuntimeError, 'Missing or unsafe production art'):
                build.retired_art_exclusions(root)

    def test_export_requires_actual_texture_payload(self):
        with tempfile.TemporaryDirectory() as folder:
            archive = Path(folder) / 'art.zip'
            with zipfile.ZipFile(archive, 'w') as package:
                package.writestr('assets/live.png.import', '[remap]\npath="res://.godot/imported/live.ctex"')
            with self.assertRaisesRegex(RuntimeError, 'payload missing'):
                build.verify_export_art(archive, set(), {'assets/live.png'})
            with zipfile.ZipFile(archive, 'a') as package:
                package.writestr('.godot/imported/live.ctex', b'texture')
            result = build.verify_export_art(archive, {'assets/old.png'}, {'assets/live.png'})
            self.assertEqual(result['verified_png_remaps_and_payloads'], 1)
            with self.assertRaisesRegex(RuntimeError, 'Retired art unexpectedly exported'):
                build.verify_export_art(archive, {'assets/live.png.import'}, set())

    def test_current_manifest_frames_and_dynamic_gait_are_retained(self):
        excluded, referenced = build.retired_art_exclusions(ROOT)
        self.assertFalse(excluded & referenced)
        self.assertTrue(excluded)
        for direction in ('down', 'left', 'up', 'right'):
            self.assertIn('assets/characters/hero/phase3/textures/gait/' + direction + '.png', referenced)
        retirement = json.loads((ROOT / 'assets/monsters/phase3/source/art_polish_b_v07/retired_runtime_frames.json').read_text(encoding='utf-8'))
        audited = {path.removeprefix('res://') for path in retirement['paths']}
        for path in excluded:
            if '/v05/' in path or '/v06/' in path:
                self.assertIn(path.removesuffix('.import'), audited)

    def test_enemy_retirement_keeps_republished_and_direct_frames(self):
        with tempfile.TemporaryDirectory() as folder:
            root = Path(folder)
            for relative in build.PRODUCTION_ART_MANIFESTS:
                self.write(root, relative, '{}')
            base = 'assets/monsters/phase3/textures/v06/golem/'
            paths = [base + name + '.png' for name in ('old', 'live', 'direct')]
            for path in paths:
                self.write(root, path)
                self.write(root, path + '.import')
            self.write(root, 'assets/monsters/phase3/source/art_polish_b_v07/retired_runtime_frames.json', json.dumps({'paths': paths}))
            self.write(root, build.PRODUCTION_ART_MANIFESTS[1], json.dumps({'frames': ['res://' + paths[1]]}))
            self.write(root, 'scripts/enemy.gd', 'const ART = "res://' + paths[2] + '"')
            excluded, _ = build.retired_art_exclusions(root)
            self.assertEqual(excluded, {paths[0], paths[0] + '.import'})


if __name__ == '__main__':
    unittest.main()
