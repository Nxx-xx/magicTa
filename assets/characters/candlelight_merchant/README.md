# 烛火商人 V01

2026-10-02，使用内置 image_gen 生成，透明背景。人物为紫色兜帽的行商，携带行囊、钱袋与暖色烛灯。

- 原始生成图：`source/merchant_v01.png`，保留原生透明通道；source 目录不参与 Godot 导入和发布。
- 游戏素材：`textures/idle.png`，256×256 RGBA，完整画布等比缩小，不裁切人物。
- 生成提示词：`source/PROMPT.md`。
- 导出脚本：`tools/prepare_merchant.gd`，使用 Godot Lanczos 缩小，保留 alpha。
- 地图接入：`scripts/ui/runtime_art.gd` 的 shop 纹理；地图仍占一格，售罄沿用现有灰色调制。
- 商店窗口：`scripts/ui/map_screen.gd` 使用 `npc_portrait.gd` 显示母版上半身近景，原招呼语和商店逻辑保留。

2026-10-04 精修：`textures/conversation.png` 为母版 `(192,0,896,832)` 的 192×178 透明裁切。`tools/npc_polish_bake.gd` 可重复制作；母版不变。默认近景 96×88，矮于 640 的视口采用 80×68，手机入口无新增滚动。`npc_portrait.gdshader` 只对原像素施加不足一像素的呼吸与灯火亮度变化，无新增逐帧图；减弱动效时完全静止。地图继续复用原来的 256×256 全身图。
