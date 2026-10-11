# Bat independent map idle

2026-10-02. Agent visual review accepted only `map_idle`: four 8 FPS looping frames, 256×256, anchor (128,224), no gameplay events/holds. Native source remains draft; human signoff false.

One actual built-in imagegen atlas and its complete prompt are retained. This is a separate elevated front map painting; battle frames were not resized into map art. Six painted layers form the native editable scene: body, paired claws, two independent wings and two wing tips. The wings retain the original painted pixels, split along their main spars with overlapping masks. Tips follow their named wing parents. This does not claim four newly painted whole-body originals or full flight simulation.

Final contact, original-speed and quarter-speed browser playback, all four numbered poses and 26/33/47px previews were actually viewed. Shoulder and wingtip joins stay covered through the flap loop, both claws remain attached, and the ears/body silhouette stays centered. An earlier component-isolation pass removed one claw; retaining both claw islands repaired that issue before final native bake and visual review. Ground projection stays at (128,224) beneath the airborne body. No separate glow/effect is needed.

Evidence in `build/verification/phase3/08-parallel/map_a/`: `bat_map_idle_visual_contact.png`, native draft contact, original/quarter WebP, `bat-browser-final.jpg`, technical candidate and `bat-bake-final` locked native logs. Native scene reload passed. Four unique body poses use 1 MiB decoded RGBA resource data; this is not a measured runtime cache/device budget.

`bat_publish_review.json` is the separate explicit reviewed-hash approval. `bat_map_review.html` offers original/quarter/pause/step/exact-frame controls. Coordinator production integration and final human art/naturalness signoff remain pending.
