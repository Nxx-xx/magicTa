# 月夜魔塔启动页

用户于 2026-10-03 确认设计稿，采用内置 imagegen 制作，未使用 CLI/API fallback。

- `source/approved-loading.png`：已确认的完整设计稿。
- `source/moonlit-tower.png`：移除底部界面文字与进度条的原始背景，保留标题、塔楼、公主、月夜构图。
- `loading-background.jpg`：原尺寸 941×1672 JPEG（质量 95），460,346 bytes，进入微信主包。由无损背景重新编码，原始图不进入游戏包。此前质量 83 的版本为 255,670 bytes。
- 百分比、进度条、微光和下方文案由 `../loading_screen.js` 实时绘制。

背景加工的完整提示词：

> Edit this approved mobile game loading screen to prepare its production background asset. Preserve the ENTIRE image composition, exact tower, moon, princess, path, lighting, colors, upper title 塔境 and subtitle 公主救援记, ornamentation and framing unchanged. Only remove ALL lower loading-interface elements: the text 正在唤醒塔境…, the number 68%, the full gold progress bar with its spark and side diamonds, and the bottom slogan with horizontal rules. Inpaint those small removed lower elements seamlessly with the same dark teal mist and dark ground already behind them. Keep the bottom 22 percent of the canvas dark and quiet for live interface overlay. Do not add anything new. Do not reposition or repaint the scene or top title. Exact same 9:16 dimensions and crop as reference. Output only the clean background with the top logo preserved.
