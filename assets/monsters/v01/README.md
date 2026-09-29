# 普通怪物静态素材 v01

六种已完成静态素材与独立 Godot 预览，尚未接入主游戏。仅前五种属于当前地图投放，余烬术士为素材储备。本批不包含精英、Boss、四方向或动画。

| enemy_id | 最终 RGBA PNG | 主体外框含边缘余量 | 当前投放 |
| --- | --- | --- | --- |
| slime | textures/slime.png | 141×116 | 是 |
| skeleton | textures/skeleton.png | 154×204 | 是 |
| bat | textures/bat.png | 204×156 | 是 |
| sentinel | textures/sentinel.png | 218×201 | 是 |
| knight | textures/knight.png | 145×212 | 是 |
| warlock | textures/warlock.png | 116×202 | 否 |

全部画布为 256×256，地面锚点 (128,224)，归一化为 (0.5,0.875)。蝙蝠悬浮基准仍使用同一地面锚点，身体底部预先上移 34 画布像素；绘制时不要再补一次悬浮偏移。史莱姆为小体量，石卫最宽，骑士最高。透明边框均大于零。完整矩形、尺寸和路径见 asset_manifest.json。

## 导入与缩放

Godot 4.7.2 已实际导入：Lossless、mipmaps=true、fix_alpha_border=true、premult_alpha=false。CanvasItem 使用 TEXTURE_FILTER_LINEAR_WITH_MIPMAPS；不要使用 nearest 像素过滤或有损纹理压缩。原始图与截图目录均有 .gdignore，不导入为生产纹理。

后续集成到 grid_board 时，按 enemy_id 读取清单，把整张 256 画布绘制到一格正方形。若已有中心坐标 center 与格宽 tile，可使用 Rect2(center - Vector2.ONE * tile * 0.5, Vector2.ONE * tile)；不要将主体外框单独拉满格子，否则会破坏体量与地面基准。现有绘制先按 tile/44 缩放的分支中，对应局部矩形为 Rect2(-22,-22,44,44)，无需再次乘 tile。没有烘焙地面投影，后续需要阴影时可单独在地面锚点下画柔和小阴影。

本预览读到的布局：540×960 正常界面格宽 516/11≈46.91 px；360×640 紧凑界面格宽 288/11≈26.18 px（无保存错误条时）。额外展示 44px 绘制基准与 28px 对照。手机小格主要靠轮廓与色块识别，纹理细节应在详情大图展示。

## 查看与验证

入口：res://scenes/previews/monster_art_v01.tscn。空格切换主背景深浅色。预览不创建玩法对象、不访问玩家存档。

从项目根目录运行 scripts/previews/monster_art_v01/verify.ps1，重新打包、导入并渲染两张实际截图。脚本将 APPDATA / LOCALAPPDATA 指向 build/verification/monster_art_v01，避免使用玩家存档路径。

- previews/gallery_dark.png：深底大图 + 浅底缩图 + 实际小格
- previews/gallery_light.png：浅底大图 + 深底缩图 + 实际小格
- previews/alpha_report.json：透明像素及边界检查
- previews/VALIDATION.md：验证结论与限制
- source/PROMPTS.md、source/SOURCES.md：完整提示词及来源

## 后续集成

将六种纹理按清单接入敌人绘制层，保留敌人身份角标、回溯标记、选中框和已有详情。五种当前投放优先；不要为了术士素材新增投放。对精英/Boss 继续使用原有图标，除非另行制作。主游戏接入后需重新核验角标遮挡及手机选中态；本批没有修改 grid_board、project.godot、怪物数值、投放或战斗规则。
