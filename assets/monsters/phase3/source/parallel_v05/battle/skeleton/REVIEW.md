# Skeleton battle draft review

2026-10-01. Built-in imagegen original preserved as skeleton_components.png; complete actual prompt in PROMPTS.md. 16 painted components plus named weapon_grip, shoulder/elbow and hip/knee/ankle hierarchy, fixed root. Editable source skeleton_rig.json and skeleton_editable_draft.tscn. Source remains draft.

Battle LEFT camera, 512 master → 256 RGBA, anchor (128,224). idle 4/6 FPS loop; attack 6/12 FPS hit frame 3; hit 2/12 FPS; defeat 6/10 FPS release frame 2 / ground frame 4. Intentional holds: attack 5→0 and defeat 5→4. 18 frame slots, 16 within-action non-hold poses. Sword slash is separate optional effect channel.

Agent inspected all four contact sheets and all frames at 26/33/47px. Fixed initial head-neck gap by lowering the head 16 master pixels and corrected named sword grip to the painted fist. Final contact sheets show left swing, recoil recovery, bent knees and released sword reaching the ground without clipping. Smaller silhouettes retain skull, sword, shield and kneeling change; fine bone detail is naturally not readable at 26px.

Native Godot baking/reload passed using the shared mutex wrapper and isolated base_a APPDATA/LOCALAPPDATA. Technical evidence is separate and does not approve art. Browser refused local file:// review under its URL security policy and explicitly prohibited alternate-route circumvention. No bypass attempted. Original-speed and 0.25-speed WebP files and a pause/frame-step/size/effect HTML preview were created.

2026-10-02 final native review: AnimationPlayer actually played all four actions at speed_scale 1 and .25; 36 wall-clock samples plus animation positions are preserved in base_a/skeleton_native_timing.json and the two skeleton_native_*x_contact.png images. Agent actually viewed both timestamped sequence sheets and final per-action/small-size sheets. This is review of native playback samples, NOT uninterrupted video viewing or successful browser playback. Native sampled review passed. Publish review now binds final exact frame/effect hashes and records accepted for coordinator review; human_signoff remains false.

Final correction: sword release switches to an independent no-hilt forearm paint reused from the atlas (17 drawable layer instances, 16 original painted components, plus weapon_grip). Two extra open-hand imagegen attempts contained a diffuse halo and are preserved as rejected originals with exact prompts; neither is consumed. Discrete native transform tracks match the baked frame cadence and avoid between-frame root-sword interpolation drift. Failed pre-fix defeat contact sheets are retained under evidence/rejected_before_fix.

No production assets, manifests, gameplay or saves changed. No claim of runtime integration, whole-stage completion, or human art signoff.
