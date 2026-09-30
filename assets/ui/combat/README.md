# 战斗专用人物素材

2026-09-30，使用内置 image_gen，根据已批准战斗结算设计和既有角色立绘生成。PNG 使用真实 alpha；不是从完整设计图裁切的界面截图。

- `hero_attack.png`：右向冲刺出剑，右手剑、左手灯，运行时用位移与特效播放。
- `hero_victory.png`：举剑提灯的庆祝姿态，用于结算卡片。

角色、桂冠、剑光、粒子、奖励和按钮分开绘制，数值不烘焙在贴图里。怪物复用现有运行时资源。

## hero_victory.png 最终提示词

参考图：`assets/characters/hero/dialogue/textures/hero_dialogue_neutral_v01.png` 和 `assets/art_concepts/combat_victory_v01.png`。

```text
Use case: stylized-concept. Production game UI asset: single transparent-background victory character cutout for fantasy game 塔境. Reference 1 exact character identity and painterly quality. Reference 2 approved victory pose in center screen. Render ONLY the heroine in that joyful victorious pose, waist-up, silver bob haircut, teal eyes, hooded dark teal cape with antique gold embroidery, practical charcoal leather outfit. Short sword raised in anatomical RIGHT hand on image LEFT, brass lantern held proudly in anatomical LEFT hand on image RIGHT. Beautiful confident smile, energetic lifted cape, warm golden rim lighting. Keep entire sword blade, hands, lantern and head within frame with generous transparent padding. Both arms anatomically correct. Square 1024x1024 composition; waist ends softly but cleanly near bottom. Premium hand-painted 2.5D anime fantasy illustration matching refs. True alpha transparent background. No text, no UI, no crest, no coins, no floating particles, no scenery, no checkerboard. Character is the only subject, clean cutout usable over dark navy UI.
```

## hero_attack.png 最终提示词

参考图：`assets/art_concepts/combat_victory_v01.png` 和 `assets/characters/hero/dialogue/textures/hero_dialogue_neutral_v01.png`。

```text
Use case: stylized-concept. Create ONE production game animation cutout on true transparent background, 1024 square. Reference 1 left combat screen gives the EXACT desired protagonist lunging attack pose, reference 2 gives same protagonist face and outfit identity. Only draw this silver bob-haired teal-eyed heroine, adult woman, deep teal hood and cloak, gold embroidered edges, charcoal leather tunic and trousers, brown boots. Full body in dynamic low forward lunge attacking toward IMAGE RIGHT with short sword in anatomical RIGHT hand extended diagonally up and to right, brass lantern in anatomical LEFT hand held back near waist. Left leg trails behind to image left, front bent knee and front boot land to image right. Cloak streams to left. Readable game character medium heroic proportions, face visible in 3/4 facing right. Premium hand-painted 2.5D anime fantasy exactly matching game refs, crisp detailed silhouette, proper anatomy. Entire sword, feet, cape, hands and lantern fit inside image with 6% transparent margin. No environment, no enemy, no slash trail, no particles, no UI, no words, no frame. True alpha transparency. Ready to animate via transform in engine. Never mirror sword and lantern hands.
```
