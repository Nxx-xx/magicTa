# 本批图像工具与提示词

2026-10-01。使用内置 imagegen，无CLI/API回退、无第三方下载。所有调用 `transparent_background=true`。身份参考来自本工程批准静态资源；原始输出另存workspace，没有覆盖旧资源。来源与使用条件沿用项目 imagegen 素材记录，不额外声称第三方授权。

## 1 公主组件母版

参考：assets/characters/hero/source/normalized/idle_right_256.png。
保存：assets/characters/hero/phase3/source/rig_v02/components_draft.png。

Use case: stylized-concept. Asset type: production 2D cutout animation master component atlas, NOT animation frames. Reference image defines exact existing princess identity and painterly 2.5D style. Create a high resolution transparent 4 by 4 component atlas, evenly spaced cells with generous transparent gaps, no grid lines/text. All parts from ONE same right-facing side-view princess, silver-white short hair, teal hood/cape with gold embroidery, dark brown leather armor and boots. Separate complete isolated parts, hidden joint areas painted in, no parts touching. Cells row-major: 1 hooded head facing RIGHT (complete silver fringe face teal hood); 2 torso with belt and waist pouch, no arms/head/legs/cape; 3 flowing back teal cape; 4 front cape flap. Row2: right upper arm, right forearm with empty gripping hand, straight silver sword with ancient gold hilt pointing down-right, left upper arm. Row3: left forearm with empty gripping hand, gold lantern with handle (no hand), right thigh, right shin boot. Row4: left thigh, left shin boot, small gold clasp ornament, soft translucent ground shadow. These are paintable individual layers for an articulated rig, NOT 16 complete characters, NOT walking poses. Keep camera slight orthographic elevation and exact reference design. Do not add weapons, shields, hats. Preserve true alpha. Full atlas 2048x2048 or highest native square resolution available. Parts need clean joint overlaps. Right hand sword, left hand lantern; never mirror.

## 2 史莱姆组件母版

参考：assets/monsters/v01/textures/slime.png。
保存：assets/monsters/phase3/source/rig_v02/slime_components_draft.png。

Use case: stylized-concept. Asset type: layered cutout animation master atlas for this EXACT green slime. Reference only for identity/style. Transparent 2 by 2 square atlas, four isolated parts in separate quadrants with ample transparent gaps, no text/grid. Top left: complete green translucent gel outer membrane WITHOUT eyes or mouth or core, facing left with same curl, highlights and puddle feet; top right: ONLY the two dark oval eyes and tiny mouth, coherent LEFT-facing arrangement, no body. Bottom left: a separate soft green luminous round internal core, no eyes or body; bottom right: separate soft translucent ground shadow. Maintain painterly polished fantasy orthographic view. Do not draw four finished slimes. Original body is almost round with asymmetrical top curl; keep same color and delicate highlighted shell. Native square resolution at least 1536 if possible. True transparency. This sheet will be separated into editable layers and articulated with hand-authored animation timeline, so keep core and face completely separate.

## 3 牛头组件母版

参考：assets/monsters/phase2/textures/minotaur.png。
保存：assets/monsters/phase3/source/rig_v02/minotaur_components_draft.png。

Use case: stylized-concept. Asset: editable 2D cutout model components, one minotaur, reference exact identity chest armor brown fur gold black plates large axe. Native 1536 square or highest available transparent image. 3 columns by 3 rows of SEPARATE body parts, clean generous gaps no text/grid. Consistent LEFT-facing three-quarter combat view throughout, not frontal. Row1 head with horns facing LEFT; torso with belt kilt no head arms legs; complete axe alone. Row2 near upper arm shoulder armor; near forearm with gripping hand; far arm with hand. Row3 near leg with hoof; far leg with hoof; separate glowing rage rune only. Paint rounded hidden joint overlaps. Every component belongs to same one warrior and keeps exact reference armor motifs and volume. No duplicate assembled characters. No contact shadow baked into parts. True alpha. These nine isolated parts will be connected by editable shoulder elbow hip pivots; do not draw multiple poses. Both hooves face LEFT. Axe attachment hand must be unambiguous.

## 4 公主靴向修订

编辑目标：第1次组件母版。保存：同目录 components_boot_fix_draft.png。远侧靴改为朝右；修订后重新切层/绑定，未镜像整个角色。

Use case: precise-object-edit. Edit this component atlas. Change ONLY bottom row second-column leather boot to face RIGHT (toe points right), matching the right-facing boot at row3 column4. Keep every other component pixel placement, silhouette, size, color and cell arrangement unchanged. This is the far boot of the same princess; not a reflected entire character. Preserve transparent background. Do not add background or text. Deliver whole corrected atlas at the same resolution.

## 5 史莱姆轮廓动作源

参考：批准旧史莱姆，保存：assets/monsters/phase3/source/rig_v02/slime_shapes_draft.png。

Use case: stylized-concept. Production animation shape-key layers for the reference green translucent slime, consistent left-facing combat view. Transparent 3 by 2 atlas of SIX outer-membrane silhouettes ONLY, no eyes no mouth no core; same painterly green shell with yellow-green rim highlights, same top curl, no detachable droplets, no shadows. Cells ample padding strictly no overlap. Each cell the same body volume and fixed baseline. Row1 left to right: A neutral round slime; B anticipation compress low and wide, top curl recoils RIGHT; C pushes off, body leans LEFT and curls forward, lower contact narrows. Row2: D attack peak: distinct broad gel lobe thrust to LEFT, rear body rounded at RIGHT, anchored foot base; E lobe retracting, body recoils gently; F recovery neutral with top curl slight follow-through. These are new redrawn contour poses for the SAME single body. Do not merely stretch the same shape. Keep total gel volume, facial region blank, lighting same across six. Full native high resolution landscape atlas, each body painted at sufficient resolution for 512px layered master. No textual labels, no grid borders, no props, no extra finished characters.

## 6 轮廓源透明清理

编辑目标：第5次轮廓源。保存：同目录 slime_shapes_cleanup_draft.png。

Use case: background-extraction. Edit the six-slime membrane layer atlas. Remove ALL broad green glow, backdrop, haze and ground shadows outside the six gel silhouettes, making those pixels fully transparent alpha=0. Keep the six exact membrane contours, poses, positions, internal colors and highlights unchanged. No new texture behind or between sprites. Clean alpha edge just along each membrane silhouette; large completely empty transparent gutters. Preserve the 3x2 atlas layout and six painted bodies. This is an alpha cleanup for sprite extraction, NOT a composition change. No eyes or face.

## 7 牛头关节与胸甲重叠修订

编辑目标：第3次组件母版；保存：assets/monsters/phase3/source/rig_v02/minotaur_components_joint_fix_draft.png。

Use case: precise-object-edit. Edit this minotaur component atlas for correct rigging. Change only top-middle torso to a coherent LEFT-facing three-quarter view matching top-left head; remove both attached shoulder pauldrons from torso so its arms can attach independently. Keep chest armor, leather kilt, belt and gold motifs. On isolated arm and leg joint ends replace visible flat circular cut-discs with smoothly painted rounded fur overlaps; no mechanical socket or cut flesh visible. All parts retain their same atlas positions and approximate bounds. Keep axe and head unchanged, same fantasy painterly style, true transparent background and ample gutters. This remains a separated components atlas, do not assemble the character.

## 实测与修改边界

前三张母版实际1280×1280；公主修订也是1280×1280。史莱姆轮廓两张1536×1024。请求尺寸不是实际产出保证。组件没有放大冒充单帧768/512原画；768/512是可编辑组合场景的画布，使用原生组件降采样装配。

轮廓原图/清理图都有真实alpha和超过100万完全透明像素，工具预览的绿色背景观感不能单独用于判断透明。清理图仍有极低alpha边缘/不规则单元，按等分切图出现邻帧碎片；后改为明确矩形抽取与保留原单元偏移。未用逐帧居中掩盖接触位置变化。

Godot只负责确定性切层、注册、命名关节、绑定、时间轴、渲染、缩小和联系图；Python源脚本只写JSON，编码脚本只将已经捕获的帧封装GIF/WebP，不用程序绘制人物替代原画。全部资源仍为draft。
