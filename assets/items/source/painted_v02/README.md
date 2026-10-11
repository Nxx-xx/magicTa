# Painted item icons v02

2026-10-04. 28 item paintings + 3 named ruin interactions. Generated individually with built-in image_gen, genuine transparent background. Prompts: prompts.json, interaction-prompts.json; full tool provenance: provenance.json. heart-pendant-revision.txt records the targeted chain-framing correction; the rejected cropped version remains here.

The original generated files are preserved without resampling. tools/item_icons_v02_bake.gd fits alpha bounds to a 100px maximum span on a 128px transparent canvas using Godot Lanczos downsampling. It writes existing runtime icon paths and all current manifests. Do not run the historical SVG bake tools to publish v02.

Source folder is ignored by Godot and excluded by the WeChat staging pipeline. Original v01 runtime PNGs and manifests are archived in ../baseline_v01. Historical SVG sources remain in their existing directories. Full evidence: build/verification/item-icons-v02; delivery: docs/ITEM_ICONS_V02_DELIVERY.md.
