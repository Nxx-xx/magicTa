# 塔境 · 战斗动画与胜利结算 V01

状态：待用户审核，尚未接入游戏。

设计图：combat_victory_v01.png

使用内置 image_gen 生成。沿用现有主角、铁甲骑士、地牢与竖屏界面视觉。

## 演出提案

- 聚焦对峙 0.2 秒 → 冲刺命中 0.4 秒 → 怪物消散 0.3 秒 → 胜利绽放 0.5 秒；为关键节拍示意，多回合实际播放节奏实施时调整。
- 剑光、命中火花、轻微震动、伤害飘字；结算采用金色桂冠、放射光、主角庆祝姿态、金币跳出。
- 展示金币、实际受伤、击杀恢复、剩余生命；继续探索为主要操作，查看战报为次要操作。
- 普通战斗可跳过；精英和首领强化庆祝。
- 不新增经验、评级或装备掉落。守卫后的宝箱保持独立领取。

## 审核说明

这是静态概念图，非运行截图或可播放动画。数字仅为示意。生成图的顶部 HUD 仍显示回血前的 88/100、金币 0，而结算区为回血后的 92/100、金币 +12；实施时需统一同步最终生命与金币，并屏蔽背后移动输入。特效和布局需适配现有手机窄屏。

## 最终生成提示词

```text
Use case: ui-mockup.
Create one polished high fidelity Chinese game UI design approval board for existing Godot fantasy dungeon game “塔境”. Landscape 2304x1536 composition, extremely legible, carefully typeset Chinese, professional art direction. It is a concept proposal, not a real implemented screenshot.
References: image 1 approved art style/environment and hero identity, image 2 actual hero portrait (keep silver bob, teal eyes, teal hooded cape, charcoal leather outfit and antique gold trim), image 3 existing armored knight enemy (keep dark steel armor, gold edges and shield), image 4 CURRENT mobile gameplay screenshot, preserve its portrait proportions and compact header/footer visual grammar. All are visual references, do not simply collage them.
Board layout: dark midnight blue background with ample gutters; top heading “塔境 · 战斗与胜利结算” and small subtitle “视觉提案 V01 · 数值仅作示意”. Two large equally sized portrait game screens occupy left and middle 72% of board, rightmost 28% is a clean vertical four-beat storyboard. Fine antique-gold frame details, teal accents, sophisticated hand-painted 2.5D fantasy, no pixel art. Both phone screens have fully readable hierarchy and comfortable button spacing. No physical phones.
LEFT SCREEN external label “01  交战演出”. Inside screen keep small top HUD “塔境 · 第1层”, HP “生命 88 / 100”. Dimmed blue-grey tiled dungeon behind a central dynamic duel stage overlay. Silver-haired teal-cloaked heroine at lower-left makes a fast short sword strike toward armored knight upper-right. Hero holds short sword in anatomical right hand and small amber lantern in left. Use game-character medium proportions, polished readable silhouettes. Beautiful curved turquoise-white sword trail, tiny bright gold impact spark on shield, small white damage number “−24” over knight. Knight recoils, short motion trails, no gore. Enemy name “铁甲骑士” and a nearly empty thin red health bar above stage. Lower stage caption “最后一击”. Bottom slim control “跳过演出”. Surrounding dim map still visible with darkened controls. Concentrate effects on the collision; no thick particle fog obscuring actors. Make the scene energetic.
MIDDLE SCREEN external label “02  胜利结算”. Preserve the dungeon dimmed behind a victory overlay filling most of portrait. At upper third a magnificent but tasteful golden laurel crest with sword/light emblem, radiating warm sunbeams and small rising golden motes. Huge embossed warm-gold Chinese title “战斗胜利” readable at first glance, small subtitle “已击败 · 铁甲骑士”. Below title show hero waist-up in a joyful confident victory pose, recognizable silver-haired teal hooded heroine, short sword raised safely to side, cape lifted, bright rim light, genuinely celebratory. Golden glints and few floating coins integrate around hero; leave numbers and face clear. Lower third dark translucent navy reward panel, one LARGE gold coin icon with “金币 +12”; a clear compact two-column line “受到伤害 12” and “击杀恢复 +4”; next line teal “剩余生命 92 / 100” and teal HP bar at 92%. Large accessible bottom warm-gold illuminated button “继续探索”, smaller text action below “查看战报”. Reward visuals and gold light are the focal point, avoid random loot, treasure chests, experience points, star ratings, grades, or unlocks because current system only gives coins and kill healing. Do not imply entire game completion.
RIGHT STORYBOARD external label “03  动画节奏”. Four compact separate thumbnail frames stacked vertically with clear captions, tied together by a thin gold vertical progress line. Thumb 1 encounter focus, faceoff silhouette caption “聚焦对峙 · 0.2秒”; thumb 2 lunge and curved sword arc caption “冲刺命中 · 0.4秒”; thumb 3 armored enemy breaking into gold motes caption “怪物消散 · 0.3秒”; thumb 4 golden victory crest and coin pop caption “胜利绽放 · 0.5秒”. At bottom small elegant two-line note “普通战斗可快速跳过” / “精英与首领强化庆祝”.
Keep UI crisp and restrained outside the celebratory moment. Chinese text exactly as supplied, no extra invented labels or gibberish, avoid excessive ornament and tiny illegible text. Gold and teal contrast with existing dark dungeon style, not a mobile casino style. Finish as a beautiful review-ready game design sheet with excellent hierarchy and art quality.
```

