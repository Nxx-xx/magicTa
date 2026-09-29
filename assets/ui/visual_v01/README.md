# UI Visual V01

本目录仅存放界面专属资源，不包含人物、地图或怪物纹理。

- `body_font.tres`：Noto Sans SC 450 字重。
- `title_font.tres`：同一字体的 600 字重。
- 复用 `assets/fonts/NotoSansSC.ttf`，授权沿用 `assets/fonts/OFL.txt`，无新增字体下载。
- OpenType 的 `wght` 在当前 Godot 4.7.2 字体接口中返回数字标签 `2003265652`；使用该标签设置字重。原共享字体资源未修改。
- 配色、面板和按钮状态由 `assets/ui/map_theme.tres` 原生 Theme / StyleBoxFlat 维护。
- 截图、字体探针和对照图仅位于带 `.gdignore` 的 `build/verification/ui_visual_v01/`，不作为生产纹理导入。

实施与验证见 `docs/UI_VISUAL_REDESIGN_DELIVERY.md`。
