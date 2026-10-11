# Skeleton original generation

Built-in imagegen; transparent_background=true. Reference: assets/monsters/v01/textures/skeleton.png, inspected before generation. New original is a component atlas, not 18 new painted full poses.

Generated original: exec-d7596cc8-e920-424e-9500-7c0bfc0cf365.png, copied byte-for-byte to skeleton_components.png. Actual image 1254×1254 RGBA, alpha 0–255. No procedural painting or background removal.

## Actual prompt

Supplemental open hand original exec-dda2aed4-769e-43ee-bc7f-6347d5c5a43f.png retained as skeleton_open_forearm_rejected_glow.png. Rejected due to diffuse background halo. Actual prompt:

Use case: stylized-concept. Asset type: one transparent skeletal animation component. Reference is style/material identity of the rusty sword skeleton only. Draw one complete detached NEAR FOREARM with a relaxed OPEN bony hand after releasing a sword. Elbow at top, two long forearm bones down to weathered brown leather wrist cuff then visible loose ivory fingers pointing downward and slightly LEFT. Three-quarter LEFT-facing battle camera. Same handpainted warm ivory bones and dark brown outlines as reference. NO weapon, no handle, no sword hilt, no upper arm, no torso, no extra objects. Include round elbow overlap and all fingertips fully uncropped, centered upright, large transparent padding, true RGBA transparent background. This is an animation replacement hand/forearm piece for a defeated skeleton, stylized game art, no blood or gore, no labels/text/grid/backdrop.

Main component atlas prompt:

Second rejected edit exec-d3517a74-9737-4be8-a21f-7e52ef665409.png retained as skeleton_open_forearm_rejected_glow_v2.png; still has diffuse halo, unused. Actual edit prompt:

Edit the provided skeletal forearm component. Remove ALL brown glow, halo, smoke, haze and backdrop completely. Keep ONLY the painted bones, leather wrist cuff and relaxed open hand, preserving their shape, colors and detail exactly. Everything outside the hard silhouette and tiny anti-aliased contour must have alpha ZERO. True transparent RGBA cutout suitable for skeletal animation. No drop shadow or ambient glow at all. Keep full forearm and fingertips uncropped.

Final release hand uses the existing atlas far-forearm paint as an independently articulated near_open_fore replacement, with no weapon stub. No rejected halo image is referenced by the rig.

Component atlas actual prompt:

Use case: stylized-concept. Asset type: production 2D skeletal-animation painted component atlas, genuine transparent RGBA, square 1536x1536. Reference image is identity/style reference only. Match this game's chibi rusty sword skeleton: ivory weathered large skull dark sockets, rib cage, tattered dark brown waistcloth, rusty long sword and round wooden iron-rim shield. THREE-QUARTER SIDE BATTLE VIEW FACING LEFT. Paint 16 SEPARATE isolated complete parts in strict 4 columns x 4 rows equal cells, one part centered per cell with generous transparent gap, no touching. Row1: skull facing LEFT; ribcage torso with neck; pelvis with tattered waistcloth; round wooden shield. Row2: near upper arm humerus pointing down; near forearm with CLOSED sword gripping bony hand pointing down; far upper arm pointing down; far forearm and shield-gripping hand pointing down. Row3: near thigh femur pointing down; near shin tibia pointing down; near skeletal foot toes facing left; rusty sword upright tip at top handle bottom. Row4: far thigh femur pointing down; far shin tibia pointing down; far skeletal foot toes facing left; subtle pale ochre sword-slash crescent VFX only. Exposed round joint ends, entire parts uncropped, no attached neighboring body segments, shoulder and elbow sockets covered by bone ends when assembled. Handpainted polished dark-fantasy game sprite, warm cream highlights, dark brown readable outlines, same proportion and materials as reference. No assembled character, no ground, no letters or labels, no border, no checkerboard painted into image. True transparency. Each part within its own cell, all cells filled only by named component.
