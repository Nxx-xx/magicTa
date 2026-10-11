# 第三阶段物品图标来源与复现

> 2026-10-04：以下是保留的 v01 制作历史。当前六张运行 PNG 已由绘画版 v02 替换；当前映射与哈希见 `../painted_v02_manifest.json`，源图、提示词见 `../source/painted_v02/`，旧 PNG 和清单见 `../source/baseline_v01/`。`masters/` 已标记 `.gdignore`，不随运行包导出。完整新交付见 `docs/ITEM_ICONS_V02_DELIVERY.md`。

2026-10-01，Codex 原创六件 SVG。延续 `scripts/ui/item_icon.gd` 的深色描边、明确几何轮廓和冷暖金属配色；没有第三方图片、外部下载、AI 位图或既有图片编辑。参考 imagegen 技能的“延续项目原生图标体系优先编辑矢量/代码素材”路径。SVG 是可编辑源，PNG 是由 Godot 的 SVG 栅格器直接导出，不是占位文件。

## 图形设计

| ID | 轮廓与语义 |
| --- | --- |
| p3_dawn_sigil | 放射印章、斜剑、暖红内圈 |
| p3_lantern_aegis | 提环、盾形灯罩、灯焰 |
| p3_bounty_ledger | 紫色账簿、书脊、金色封扣 |
| p3_rhythm_blade | 串联三结、三束剑穗 |
| p3_thorn_clasp | 荆棘外轮廓、方形金属扣 |
| p3_gilded_lantern | 金属灯芯座、独立火焰、微光 |

## 文件与检查

- `source/*.svg`：6 份 256×256 可编辑源；完整颜色和几何均在文件内，无外链。
- `masters/*_256.png`：6 份 256×256 RGBA 母版。
- `icons/*.png`：6 份 128×128 RGBA 正式图标，数据表 `icon` 指向这里。
- `manifest.json`：源和 PNG 的 SHA-256、尺寸、非透明边界、透明检查。
- `tests/phase3_items_assets.gd`：无导入导出器；检查 12% 安全边距；同时输出深/浅底 128px、原尺寸 32px、32px 最近邻放大图。
- 视觉证据：`build/verification/phase3/01-items/icons-dark.png` 与 `icons-light.png`。六种轮廓均已人工查看；32px 可区分剑印、灯盾、书、三结穗、刺扣和火芯。三结穗在32px下最细，不能继续缩小至16px使用。
- 无动画资源；不将任何静态图或缩放图声明为逐帧动画。

## 导入约定

本聊天未运行全工程 `--editor --import`。统筹串行导入正式 PNG；256 母版与 SVG 保留为制作源。独立 Godot 预览把原始 PNG 读入临时纹理缓存，不修改导入设置。运行时从 `data/phase3_items.json` 的 `icon` 字段取 128px 图标。
