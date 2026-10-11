"""Read-only acceptance plus isolated corruption checks of the publication gate."""
import importlib.util,json,tempfile,shutil,unittest
from pathlib import Path
ROOT=Path(__file__).resolve().parents[1]
spec=importlib.util.spec_from_file_location('publisher',ROOT/'tools/phase3_v06_golem_publish.py')
p=importlib.util.module_from_spec(spec);spec.loader.exec_module(p)
class Gate(unittest.TestCase):
    def test_real_approval(self):self.assertEqual(len(p.prepare()),26)
    def _fixture(self,mutation):
        with tempfile.TemporaryDirectory(prefix='golem_v06_gate_') as name:
            sandbox=Path(name);source=sandbox/'assets/monsters/phase3/source/golem_v06'
            source.parent.mkdir(parents=True)
            shutil.copytree(ROOT/'assets/monsters/phase3/source/golem_v06',source)
            evidence=sandbox/'build/verification/phase3/09-refinement/golem'
            evidence.mkdir(parents=True)
            shutil.copytree(ROOT/'build/verification/phase3/09-refinement/golem/native',evidence/'native')
            old=p.ROOT,p.SRC,p.OUT
            p.ROOT,p.SRC,p.OUT=sandbox,source,evidence
            try:
                mutation(source,sandbox)
                with self.assertRaises(AssertionError):p.prepare()
            finally:p.ROOT,p.SRC,p.OUT=old
    def test_changed_frame_rejected(self):
        def change(src,root):
            image=src/'golem_frames/idle/00.png';image.write_bytes(image.read_bytes()+b'changed')
        self._fixture(change)
    def test_changed_timing_rejected(self):
        def change(src,root):
            image=root/'build/verification/phase3/09-refinement/golem/native/battle/timing.json'
            image.write_bytes(image.read_bytes()+b' ')
        self._fixture(change)
    def test_existing_different_texture_rejected(self):
        def change(src,root):
            image=root/'assets/monsters/phase3/textures/v06/golem/armor/body/00.png'
            image.parent.mkdir(parents=True);image.write_bytes(b'protected existing bytes')
        self._fixture(change)
if __name__=='__main__':unittest.main()
