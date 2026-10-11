# D 组 UI 原生主题 v01

2026-10-03。来自现有 `assets/ui/map_theme.tres` 的独立可编辑版本。保留原字体、角色插画、剧情场景和物品纹理；没有新增栅格图、AI 原画或替换 `assets/items`。

- 深灰蓝底板、古金主要动作、石板卡片下沿厚度、边缘阴影与清晰焦点；保留危险动作红色和资源原有语义颜色。
- `scripts/ui/art_polish_d_frame.gd` 提供分辨率独立的刻线、角部短边、铆点和低对比石缝；装饰不接收鼠标输入。
- 正式 `map_screen.gd` 引用此主题。主菜单、HUD、二级目录、商店与其他交互面板继承；不修改动画播放器、数值、奖励、战报或存档契约。
- 静态 UI 没有新时间轴；减动效行为保持原有设置。正文和控件使用实拍检查，非生成效果图。

实际审阅与版本 SHA 见 `build/verification/art-polish-d/art_polish_d_review.json`；截图、回归、范围和限制见 `docs/ART_POLISH_D_DELIVERY.md`。agent 审阅不代表真人美术签收或微信设备验收。
