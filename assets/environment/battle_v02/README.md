# Moonlit battle stages v02

Created 2026-10-04 with the built-in imagegen tool. Three original paintings and complete prompts are retained in `source/`; the originals are flat paintings, not falsely labelled PSD layers. Style references: `tools/wechat/assets/source/moonlit-tower.png` and `assets/ui/main_menu/title_trio_v01.png`, visually inspected before generation. Reference characters and lettering are not part of these environments.

`textures/` contains independent 576 × 768 RGB runtime assets. Godot imports them with lossy quality 0.72, without mipmaps. `tools/battle_polish_bake.gd` reproduces resizing from originals under the shared Godot lock. The source directory is excluded from Godot import and the existing WeChat packaging rule excludes `source/`.

Editable presentation layers live in `scripts/ui/art_polish_c_stage.gd`: painted backdrop with aspect-preserving crop, independently drawn contact shadows, edge shade, and separate cue-driven foreground effects. `environment_kind` and `show_contact_shadows` are exposed to the inspector. The three `scenes/*_editable.tscn` files are native standalone backdrop scenes, directly editable and runnable by path; identical source copies are retained. This does not replace actor animation with a painting.

Environment selection is deterministic presentation metadata: normal hall by default; skeleton/bat/warlock/ember-channeler use ruined cloister ambience; minotaur/golem or boss rank use sealed sanctum. An optional valid `environment` replay option overrides this. These are encounter-themed backdrops, not a claim that a character is fighting inside one of the interactive ruin event panels. No save/report schema changes are required.

The native scene and runtime scripts remain editable; painted lanterns and architectural pieces are flattened in each original. Ambient lighting is static, so pause and reduced motion introduce no new moving effects.
