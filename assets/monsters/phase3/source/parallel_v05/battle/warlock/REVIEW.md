# Warlock battle draft review

18 battle frame slots: idle 4/6 loop, attack 6/12 (cast 2, hit 3), hit 2/12, defeat 6/10 (staff release/flame extinguish 3). 512 master to 256 RGBA, anchor (128,224). All 18 body poses have distinct hashes; no pose holds. Map camera is assigned to map_b and is not included here.

One built-in imagegen transparent original, unchanged in components.png; actual prompt in PROMPTS.md. Nine painted components, two named grip/contact joints, independent shoulder/elbow tracks, fixed root, torso/hood/skirt follow separate tracks. Flame has independent body/effects/combined PNG streams for all four actions. Amber staff gem is a physical painted material, not the flame overlay.

Actually reviewed four contact sheets, browser original and 0.25 speed, pause/step poses 1,3,5, and actual 26/33/47px silhouettes. Hood faces left, casting arm unfolds toward left, sleeve joints overlap, staff follows named far-hand grip before release. Defeat sinks torso into independently fixed skirt while staff tips down-left, extinguishing the flame. Browser effect toggle checked at terminal pose. Original and quarter-speed lossless WebP previews and small strips live in build/verification/phase3/08-parallel/base_c.

Corrected failed initial bake: lower skirt/staff clipping during defeat. Fixed skirt hem registration and release trajectory; final technical evidence reports no edge touch. First failed logs remain in evidence; final contact sheets reflect corrected bytes. The first images had been overwritten before failure preservation; rejected_initial_reconstruction explicitly reconstructs those original wrong skirt-parent/staff-release parameters, is labelled reconstructed/rejected, and never enters the approved manifest.

Agent accepts these four draft actions for coordinator review, bound to exact hashes in warlock_publish_review.json. human_signoff remains false. Robe conceals lower limbs; no walking/leg claims. Small silhouettes preserve hood/staff/casting direction but fine gold embroidery is intentionally unreadable at 26px. Native JSON and scene remain draft; coordinator owns production release and actual game UI acceptance.
