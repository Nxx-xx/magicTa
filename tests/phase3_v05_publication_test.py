"""Exercise tamper rejection and battle/map merging in an isolated fixture tree."""
import importlib.util
import json
import tempfile
import unittest
from pathlib import Path

from PIL import Image, ImageDraw

PROJECT = Path(__file__).resolve().parents[1]
spec = importlib.util.spec_from_file_location('v05_publish', PROJECT / 'tools/phase3_v05_publish.py')
module = importlib.util.module_from_spec(spec)
spec.loader.exec_module(module)


class PublicationTests(unittest.TestCase):
    def setUp(self):
        self.workspace = tempfile.TemporaryDirectory(prefix='v05-publication-')
        self.root = Path(self.workspace.name)
        self.assets = self.root / 'assets/monsters/phase3'
        self.assets.mkdir(parents=True)
        self.old_globals = module.ROOT, module.ASSETS
        module.ROOT, module.ASSETS = self.root, self.assets
        self.boss = {'status': 'accepted', 'frames': ['res://existing/boss.png'], 'fps': 12}
        self.manifest = self.assets / 'manifest.json'
        self.manifest.write_text(json.dumps({'version': 1, 'actions': {'golem_armor': self.boss}}))

    def tearDown(self):
        module.ROOT, module.ASSETS = self.old_globals
        self.workspace.cleanup()

    def delivery(self, category, action):
        folder = self.assets / f'source/parallel_v05/{category}/skeleton'
        folder.mkdir(parents=True)
        count, fps, loop = module.timeline('skeleton', action)
        paths = []
        for index in range(count):
            path = folder / f'{index:02}.png'
            picture = Image.new('RGBA', (256, 256))
            ImageDraw.Draw(picture).rectangle((80+index, 100, 150, 220), fill=(60+index, 80, 90, 255))
            picture.save(path)
            paths.append(path.name)
        source_action = 'idle' if action == 'map_idle' else action
        draft = {'size': [256, 256], 'anchor': [128, 224], 'source': 'res://fixture/rig.json', 'actions': {
            source_action: {'frames': paths, 'fps': fps, 'loop': loop, 'events': {}, 'pose_holds': {}}}}
        (folder / 'draft.json').write_text(json.dumps(draft))
        approval = {'decision': 'accepted', 'draft_manifest': 'draft.json', 'source_action': source_action,
                    'frame_slots': count, 'pose_holds': {}, 'frame_sha256': [module.sha(folder / p) for p in paths]}
        review = {'entity': 'skeleton', 'review_method': module.METHOD, 'human_signoff': False, 'actions': {action: approval}}
        (folder / 'skeleton_publish_review.json').write_text(json.dumps(review))
        coordinator = self.root / f'{category}-coordinator.json'
        coordinator.write_text(json.dumps(review))
        return folder, coordinator

    def test_map_and_battle_are_merged_and_boss_untouched(self):
        battle, battle_review = self.delivery('battle', 'idle')
        map_source, map_review = self.delivery('map', 'map_idle')
        module.publish('skeleton', battle, battle_review)
        first = module.read(self.manifest)
        module.publish('skeleton', map_source, map_review)
        final = module.read(self.manifest)
        self.assertEqual(first['actions']['skeleton_idle'], final['actions']['skeleton_idle'])
        self.assertEqual(self.boss, final['actions']['golem_armor'])
        self.assertEqual(4, len(final['actions']['skeleton_map_idle']['frames']))
        self.assertIn('skeleton', final['accepted_entities'])

    def test_changed_frame_is_rejected_without_manifest_or_texture_write(self):
        folder, approval = self.delivery('battle', 'idle')
        initial = self.manifest.read_bytes()
        picture = Image.open(folder / '01.png')
        picture.putpixel((90, 120), (255, 20, 80, 255))
        picture.save(folder / '01.png')
        with self.assertRaisesRegex(ValueError, 'Changed frames require new'):
            module.publish('skeleton', folder, approval)
        self.assertEqual(initial, self.manifest.read_bytes())
        self.assertFalse((self.assets / 'textures').exists())

    def test_worker_pending_motion_needs_coordinator_accepted(self):
        folder, approval = self.delivery('battle', 'idle')
        worker_path = folder / 'skeleton_publish_review.json'
        worker = module.read(worker_path)
        worker['actions']['idle'].update(decision='pending_motion_review', static_visual_decision='accepted')
        worker_path.write_text(json.dumps(worker))
        module.publish('skeleton', folder, approval, dry_run=True)
        denied = module.read(approval)
        denied['actions']['idle']['decision'] = 'pending'
        approval.write_text(json.dumps(denied))
        with self.assertRaisesRegex(ValueError, 'Unapproved'):
            module.publish('skeleton', folder, approval)


if __name__ == '__main__':
    unittest.main()
