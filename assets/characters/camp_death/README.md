# 营地死神

2026-10-04 精修：营地调用 `camp_death_art.gd.draw()`，用有界 48 姿态网格缓存复用同一纹理，脚点、点击矩形及前后遮挡顺序不变。减弱动效使用中性姿态。`portrait(settings)` 提供包含兜帽、骷髅脸、镰刀及绿灯的上半身裁切；剧情面板接入单独交付 `tools/npc_polish_death_portrait.patch`，本项不改写其他聊天独占的 `campaign_panels.gd`。原始高清母版另保存在带 `.gdignore` 的 `source/death_v01.png`，不入运行包。详情见 `docs/NPC_POLISH_DELIVERY.md`。

`death.png` 是死神的独立透明贴图，使用内置 image_gen 生成（非 CLI），由 `scripts/ui/camp_death_art.gd` 引用。Godot 导入时限制长边 384，保留原始 PNG 和透明通道。

参考已确认的现有营地改稿 `exec-75c63963-38f8-440d-9266-56ca1e38a8c9.png`；生成源文件为 `exec-e8449338-d9b9-41ec-95aa-96892c2c5e23.png`。角色脚点在营地逻辑坐标 `(7,4)`，老骑士 `(2,3)`、塔门 `(5,1)` 与场景底图不变。

## 最终生成提示词

Use case: background-extraction. Asset type: isolated transparent game NPC sprite for the existing game. Extract and faithfully recreate ONLY the small Death NPC visible above-left of the pond in this reference camp screenshot, no labels and no environment. One full-body centered character on genuinely transparent background: charcoal black hooded robe, cute small ivory skull face with dark eye sockets, dark cloth layers, scythe held on image right with hooked curved gray blade, small muted emerald green lantern hanging on image right at hip height. Keep the exact approved silhouette and charming stylized 3D game sprite appearance, viewed from slightly elevated top-down game camera, facing camera slightly toward left. Suitable to be displayed at 64-90 pixels tall next to the existing old knight. Crisp readable silhouette, proportionally larger head and short compact body, subtle warm light from upper left, soft shaded detailed cloth. Entire hood, scythe, lantern and both feet visible, tight useful framing with 8 percent transparent margin. No scenery, no ground tile, no platform, no UI, no text, no other characters, no sheet, no multiple views. Preserve transparent alpha.
