"""Build a read-only-baseline regression fixture; writes only 01-items evidence.

Extracts the approved pre-phase3 backup's core, data and old test sources, then
overlays the three dispatch entry points plus their two leaf modules. Does not
restore, edit or delete anything in the live project.
"""
from pathlib import Path
import hashlib
import json
import zipfile

project = Path(__file__).resolve().parents[1]
evidence = project / "build/verification/phase3/01-items/integration"
fixture = evidence / "legacy-fixture"
archive = project / "build/integration/phase3-baseline-20261001/workspace-before-phase3.zip"
manifest = {"baseline_archive": str(archive), "baseline_files": {}, "overlays": {}}
with zipfile.ZipFile(archive) as bundle:
    for entry in bundle.infolist():
        name = entry.filename.replace("\\", "/")
        if not (name == "project.godot" or name.startswith(("scripts/core/", "data/", "tests/"))):
            continue
        if entry.is_dir():
            continue
        target = (fixture / name).resolve()
        if not target.is_relative_to(fixture.resolve()):
            raise ValueError(f"Unsafe archive entry: {name}")
        content = bundle.read(entry)
        target.parent.mkdir(parents=True, exist_ok=True)
        target.write_bytes(content)
        manifest["baseline_files"][name] = hashlib.sha256(content).hexdigest()
for name in ("content_db.gd", "rewards.gd", "combat.gd", "phase3_items.gd", "phase3_combat.gd"):
    relative = "scripts/core/" + name
    content = (project / relative).read_bytes()
    target = fixture / relative
    target.parent.mkdir(parents=True, exist_ok=True)
    target.write_bytes(content)
    manifest["overlays"][relative] = hashlib.sha256(content).hexdigest()
(evidence / "legacy-fixture-manifest.json").write_text(json.dumps(manifest, indent=2), encoding="utf-8")
print(f"Prepared {len(manifest['baseline_files'])} baseline files + 5 overlays in {fixture}")
