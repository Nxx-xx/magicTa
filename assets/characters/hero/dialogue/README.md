# 主角对话半身立绘 V01

用户要求：同一主角的较大上半身立绘，用于文字对话；成年女性身材、丰满胸型、明显腰身曲线和精致面容。

正式文件：`textures/hero_dialogue_neutral_v01.png`，**1024×1536 RGBA PNG**。画面包含兜帽至腰带及上胯，适合对话框覆盖底部；保留银白短发、青绿眼睛、青绿兜帽斗篷、古金纹饰、深色贴身皮甲。采用约 25 岁的成年人物比例，默认表情为温和微笑。胸甲合体并强化丰满胸型，服装完整。

参考：`assets/art_concepts/hero_design_v01.png` 中成年主立绘的身份、服装和风格。使用 Codex 内置 image_gen 生成，原图保存在 `source/portrait_generated_v01.png`；最终完整提示词在 `source/prompts.md`。没有修改四向地图小人，也没有接入主游戏对话逻辑。

Godot 使用建议：作为 `TextureRect.texture`，保持宽高比（2:3），使用 `STRETCH_KEEP_ASPECT_CENTERED`、线性过滤。可在约 360–600 px 显示高度下展示；按实际对话布局调整，不要水平拉伸。人物靠近左右下边缘，对话框可以覆盖底部腰带以形成半身构图。角色自身左右和胸甲细节不需要通过翻转图片适配布局。

真实 alpha 已用 Godot 4.7.2 检查：443,294 个完全透明像素，1,129,570 个带 alpha 的人物/边缘像素；无不透明矩形底图。生成器保留了透明像素下的 RGB 颜色，查看原始 RGB 时可能显示背景色，正确 alpha 合成时不可见。边缘和内部 alpha 多为 252–254/255，保留生成器原始输出，未粗暴二值化抠图。

`source/` 与 `reports/` 含 `.gdignore`，只应将 `textures/` 的 PNG 作为游戏纹理导入。验证报告为 `reports/alpha_check.json`，验证在隔离 APPDATA/LOCALAPPDATA 下进行，未访问玩家存档。
