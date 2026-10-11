# 牛头 v04 补充源图

2026-10-01，内置 imagegen，真实透明背景。原有 torso/head/axe 来源沿用 ../rig_v02/README.md；旧源逐字节复制为 minotaur_components.png。

## minotaur_joints.png

参考：assets/monsters/phase2/textures/minotaur.png；../rig_v02/minotaur_components_joint_fix_draft.png。

完整提示词：

Use case: stylized-concept. Asset type: production cutout animation supplementary component atlas for MagicTa minotaur. Image 1 is approved identity, image 2 is existing layered combat source/style reference. Create ONE transparent 3-column by 3-row atlas with nine isolated complete components, generous empty gutters, no labels or grid. Consistent LEFT-facing three-quarter view, brown fur, black iron and antique gold trim matching references. Row1: near furry thigh with knee armor, near separate furry shin with rounded hidden knee overlap NO hoof, near separate armored cloven hoof pointing LEFT. Row2: far furry thigh with smaller knee armor, far separate furry shin with hidden knee overlap NO hoof, far armored cloven hoof pointing LEFT. Row3: far upper arm with shoulder pauldron, far forearm with relaxed open hand, near open empty hand for releasing axe. Joints have rounded painted fur overlap, no severed flesh or flat discs. NO full legs or assembled characters. All six leg parts need consistent side camera and compatible thickness for a muscular heavy bull warrior. Keep hand and feet anatomy readable. True alpha transparent background, no ground shadows. Highest native resolution square image.

生成文件：exec-bd5ba75d-d888-4f8e-9d2b-27ef8105530e.png。图中组件需逐个审阅后绑定；生成成功不等于验收。

## minotaur_map_components.png

参考：assets/monsters/phase2/textures/minotaur.png；内置 imagegen；真实透明背景。

Use case: stylized-concept. Asset type: independent TOP-DOWN MAP CAMERA cutout model for the approved minotaur enemy in MagicTa. Reference approved minotaur defines brown bull face, horns, black armor antique gold, heavy axe and painterly fantasy sprite style. Create transparent 3x3 atlas of independent parts, consistent front facing slightly to camera LEFT with elevated orthographic map camera (see top of shoulders and hooves). Do not reuse side combat camera. Row1: horned head looking down toward viewer, armored chest plus leather waist/kilt no arms head legs, complete axe alone blade down-left. Row2: near upper arm with gold black pauldron, near forearm and CLOSED gripping hand, far arm with open hand. Row3: near leg with armored hoof pointing down-left, far leg with armored hoof pointing down-right (natural frontal stance), faint soft separate oval contact shadow. All components complete and isolated, rounded hidden joint overlap under adjacent parts, no cut discs. Keep chunky strong boss proportions. No assembled character. No text, grid, border or backdrop. Large transparent gutters. True alpha. Highest native square resolution. Nine parts must belong to same coherent frontal elevated map view.

生成文件：exec-adbd263a-97fe-470c-a33d-e7be43bb7019.png。
