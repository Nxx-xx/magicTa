# 游戏图标 · 月夜魔塔

2026-10-03 用户要求重新设计游戏图标，微信平台使用同款。采用已确认加载页的青黑、月光与金色塔门风格。

- 项目图标：`assets/icon.png`，512×512 PNG；`project.godot` 已引用。
- 微信头像上传文件：`build/branding/wechat-avatar.png`，与项目图标逐字节相同。
- 生成原图：`assets/art_concepts/tower_icon_source_v01.png`。原图目录不进入微信导出。
- 微信构建流程同时把项目图标复制为 `images/logo.png`，计入产物哈希；平台账户头像仍须单独通过微信后台设置，不由代码包自动修改。
- 原 `assets/icon.svg` 留存作为历史资产，已不是项目图标。已有 Windows EXE / Android APK 未重建。
- 微信后台已尝试在应用内浏览器打开，页面读取连续超时；无法确认登录状态，未修改平台头像。

使用内置 imagegen 生成，参考图为 `tools/wechat/assets/source/moonlit-tower.png`。完整提示词：

> Use case: stylized-concept. Create ONE final production square 1:1 app icon for the Chinese fantasy RPG 塔境, suitable for both the game application and WeChat Mini Game avatar. Input image is a style reference for the approved loading screen only. Design a striking iconic close-up of ONE mysterious gothic magic tower, centered and monumental, strong distinctive pointed silhouette, a large luminous ivory full moon behind its upper spire. An intensely warm gold light glows from a single tall arched doorway near the base, with a short glimpse of ascending stone steps leading to it. Deep midnight teal and blue-black stone against warm champagne-gold light, a few restrained gold embers and teal mist. Painterly high-end fantasy game art, rich sculpted stone masses, bold readable composition, beautiful crisp edge lighting. Tower should occupy approximately 70 percent of icon height and 55 percent width, moon occupies about 45 percent width; both centered within the middle 80 percent so circular and rounded-square crops retain all important shapes. Reduce tiny architectural details: 3 or 4 recognizable spires, substantial main tower, no busy landscape. Strong recognizability at 48 by 48 pixels. Entire square is fully opaque and filled with artwork right to its edges, no pre-rounded corners, no decorative external frame, no plain margins. No letters, no text, no numbers, no logo wording, no watermark, no characters or faces, no collage, no multiple options, no smartphone frame. The result should feel like a crafted fantasy game emblem illustrated as key art, NOT a generic flat vector symbol or a screenshot cropped from the supplied image. Output one finished square icon at high resolution.
