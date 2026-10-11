# Dense map walking frames

Generated from the existing four independent `source/refine_v06/hero_*_editable.tscn`
rigs by `tools/bake_hero_gait.gd`. The source art and original animation manifest
are unchanged. These are samples of interpolated joint transforms, not raster
crossfades or mirrored views.

Each 768 × 768 atlas contains 36 cells of 128 × 128 pixels:

- Cells 0–23: one two-foot walking cycle, sampled uniformly from the rig.
- Cells 24–29: first foot contact to idle, with a smooth transform interpolation.
- Cells 30–35: opposite foot contact to idle.

`scripts/ui/hero_gait.gd` shares the four sheets and their AtlasTexture regions.
The movement phase selects frames, keeping two steps per cycle and the existing
0.22-second travel per tile. Settling takes 0.09 seconds without changing game
position or emitting another footstep. Reduced motion and interactions retain
the original catalog poses. No gameplay RNG is consumed.

Regenerate with Godot's Compatibility renderer (not headless, because this
captures SubViewports), using `--script res://tools/bake_hero_gait.gd`, then import
the updated textures. Use isolated APPDATA and LOCALAPPDATA for tooling.

Validation: `tests/walking_polish_test_runner.gd`,
`tests/walking_test_runner.gd`, and `tests/wechat_audio.test.cjs`.
