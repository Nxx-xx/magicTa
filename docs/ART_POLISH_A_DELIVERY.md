# A 组主角与营地 NPC 精修交付

2026-10-03。A 组资产、专属运行接入、手机尺寸实际 Godot 捕获和相关回归已完成。主工程 Godot 4.7.2；最终包、跨组肖像路径和微信设备验收由统筹处理。本组没有修改 current/latest。

## 实际变更

- 老骑士保留银发、盾徽、双手扶剑身份；改为与死神、营地一致的绘画灰蓝钢与旧金材质。原 3D 源及原 8 帧全部保留，新增 `assets/characters/mysterious_knight/art_polish_a_v03/`。先续修 3D 的未采用样板保留于旧 source 下的 `art_polish_a_native_v02/`。
- 新骑士为三层可编辑 Node2D 和 AnimationPlayer，继承 8 帧／4 FPS／原 anchor。头部和披风轻动，双手、剑尖与靴底固定；无静态退回。生成原图、实际提示词、draft、SHA 审批和生产资源分开存放。
- `camp_knight_art.gd` 正式引用新批准帧和肖像；`camp_board.gd` 营地主角开始复用已批准的 v06／现有密集 gait，修正透明画布缩放与脚底阴影位置。没有改地图移动、hero_gait、hero_walk、公共战斗播放器或核心存档。
- 查看公主 18 动作全部身体帧、死神与商人后保留现有绘画资产，不重制全套。营地仅老骑士、死神两个固定 NPC；商人为塔内 shop 资产。公主全 91 帧位、方向、灯剑、事件与时序保持原 manifest。

## 审阅入口

- [骑士逐帧与 26/33/47px](../build/verification/art-polish-a/knight_contact.png)
- [骑士真正原生实速／慢速采样](../build/verification/art-polish-a/native_contact.png)
- [公主四向全帧](../build/verification/art-polish-a/hero_map_contact.png)、[六种战斗动作](../build/verification/art-polish-a/hero_combat_contact.png)
- 专属可玩入口 `tests/art_polish_a_play.gd`：通过公共锁 Group `art-polish-a` 运行，390×700，正式营地／菜单／操作，隔离 `user://art_polish_a_play.json`。

## 实际截图

均为真实生产主 UI 的 Godot viewport，桌面按手机尺寸渲染，不是效果图或手机真机照片。改前 8 张、改后 20 张；前后截图期间 D 组更新了界面边缘样式，因此人物之外的 UI 差别不能归为 A 组成果。

| 尺寸 | 改前／改后近景 | 改后全图 | 单独 NPC 近景 |
| --- | --- | --- | --- |
| 320×640 | [前后并排](../build/verification/art-polish-a/comparison_320.png) | [全图](../build/verification/art-polish-a/after/overview_320.png) | [骑士](../build/verification/art-polish-a/after/focus_knight_320.png) |
| 390×700 | [前后并排](../build/verification/art-polish-a/comparison_390.png) | [全图](../build/verification/art-polish-a/after/overview_390.png) | [死神](../build/verification/art-polish-a/after/focus_death_390.png) |
| 540×960 | [前后并排](../build/verification/art-polish-a/comparison_540.png) | [全图](../build/verification/art-polish-a/after/overview_540.png) | [骑士](../build/verification/art-polish-a/after/focus_knight_540.png) |

after/ 另含三个尺寸的 `overview_normal_*`、`near_normal_*`、两张 motion 样本及全部 NPC 聚焦图。三个尺寸覆盖正常与减动效；540 实测减动效像素冻结、正常帧不同。320 默认居中近景会裁掉西侧骑士，已另拍聚焦图；全图可见两 NPC，这属于既有可拖动镜头设计，未移动 NPC 或点击位置。

## 相关回归

所有 Godot 导入、烘焙、捕获和测试通过 `tools/phase3_v05_godot_locked.ps1 -Group art-polish-a` 公共锁；APPDATA/LOCALAPPDATA 均隔离在本组目录。14 次锁运行成功，完整结果 [locked-results.json](../build/verification/art-polish-a/locked-results.json)，原始日志位于 `build/verification/phase3/08-parallel/art-polish-a/`。

| 既有语义套件的 A 组隔离副本 | 通过／失败 |
| --- | ---: |
| camp_map_test_runner（点击、拖动、路线、旧局、NPC 与营地功能） | 582 / 0 |
| v06 hero specific（91 帧、效果、锚点、原生关节与 LRU） | 408 / 0 |
| walking_test_runner | 31 / 0 |
| walking_polish_test_runner（密集步态与接触连续性） | 180 / 0 |
| v06 hero_map_test（四向、地图移动、回退与缓存） | 47 / 0 |

合计 1,248 条检查，0 失败；不以数量代替美术签收。副本只改隔离 guard 和输出目录，原测试文件未修改。捕获夹具另外验证营地四向减动效姿态均来自批准目录、旧 walk_art 隐藏。保留的 288 份公主纹理／manifest、旧骑士贴图／原生源 SHA 全部一致，见 [preservation.json](../build/verification/art-polish-a/preservation.json)。

环境提示：各运行出现系统根证书库告警；walking_polish 退出保留既有 4 个 ObjectDB 实例泄漏提示。无脚本错误、非证书引擎 ERROR、超时或失败断言。公主实测缓存峰值仍 24,313,856 bytes；并未测量手机性能。

## 文件清单与可编辑源

- 修改：`scripts/ui/camp_board.gd`、`scripts/ui/camp_knight_art.gd`。
- 新运行资源：`assets/characters/mysterious_knight/art_polish_a_v03/textures/idle_00.png` 至 `idle_07.png`、`portrait.png` 及各 import；`manifest.json`。
- 新绘画源：同版本 `source/art_polish_a_components.png`（完整1254×1254 RGBA原图）、3 个独立 .res 图层、`art_polish_a_knight_editable.tscn`、`PROMPT.md`、`REVIEW.md`、draft 9 PNG、`draft_manifest.json`、`visual_review.json`。source/.gdignore 防止原画进运行导入。
- 保留试稿：`assets/characters/mysterious_knight/source/art_polish_a_native_v02/`；旧 3D 源及旧 runtime 资源未覆盖。
- 制作／审阅工具：`tools/art_polish_a_knight_bake.gd`（未采用的原生3D续修）、`art_polish_a_knight_layer_bake.gd`、`art_polish_a_knight_playback.gd`、`art_polish_a_publish.py`、`art_polish_a_evidence.py`；跨组待应用补丁 `art_polish_a_campaign_portrait.patch`。
- 专属入口／验证：`tests/art_polish_a_play.gd`、`art_polish_a_capture.gd`、`art_polish_a_camp_regression.gd`、`art_polish_a_hero_regression.gd`、`art_polish_a_hero_map_regression.gd`、`art_polish_a_walking_regression.gd`、`art_polish_a_gait_regression.gd`。
- [完整路径与 SHA 清单](../build/verification/art-polish-a/file-inventory.json)。只有本组归属文件有制作写入；公共测试副本使用独立前缀。

发布精确 draft SHA：`6c25eb093279441d9ffa887eb24cc8a92418c9af3160bc29d4a33d573cfaf09b`。先显式批准此 SHA、再独立 publish，已发布同名不同字节会拒绝覆盖；human_signoff=false。

## 包体影响与统筹补丁

[asset-budget.json](../build/verification/art-polish-a/asset-budget.json)：9 张新 PNG 原始合计 443,339 bytes，ZIP 估计 442,879 bytes；9 个桌面导入 ctex ZIP 合计 **473,531 bytes（0.452 MiB）**，低于 A 组 0.75 MiB 预算，即使暂时保留旧 runtime 也在建议新增额以内。旧 9 个 ctex ZIP 为593,194 bytes；全部退休替换后估计净减119,663 bytes。该数字是桌面 lossless 导入资产压缩估计，不是 Godot4.6.1 微信最终包实测；未改导出压缩或预算阈值。

统筹必须处理以下两项：

1. **骑士故事／对话仍引用旧肖像**：`scripts/ui/campaign_panels.gd` 当前第33、75行，把字符串 `res://assets/characters/mysterious_knight/textures/portrait.png` 改为 `CampKnightArt.PORTRAIT.resource_path`。该文件已有 CampKnightArt preload。精确补丁在 `tools/art_polish_a_campaign_portrait.patch`；A 组未越权修改。新肖像已批准并可运行加载，需补丁后补拍对话。
2. 统一导出时检查两处肖像路径和其他生产引用后，才可在 staging 排除旧 `mysterious_knight/textures/` 的9张图及 sidecar。主工程原图必须保留。新版本 source 与未采用的 source/art_polish_a_native_v02 均按已有 source 排除规则不打包；不需要修改构建预算或全面降质。未要求地图、hero_walk、hero_gait 或公共战斗播放器补丁。

## 复现及保留边界

```powershell
# 可玩入口：关闭窗口退出；使用独立存档
./tools/phase3_v05_godot_locked.ps1 -Group art-polish-a -Label play -GodotArgs @('--script','res://tests/art_polish_a_play.gd')
# 320/390/540 正常／减动效与 NPC 聚焦捕获
./tools/phase3_v05_godot_locked.ps1 -Group art-polish-a -Label capture -GodotArgs @('--rendering-method','gl_compatibility','--script','res://tests/art_polish_a_capture.gd','--','--after')
# 原生真实定时采样
./tools/phase3_v05_godot_locked.ps1 -Group art-polish-a -Label native -GodotArgs @('--script','res://tools/art_polish_a_knight_playback.gd')
```

没有修改玩法数值、保存协议、战报、移动、方向、事件或正式动画时序；公主已有密集 gait 继续使用。新骑士身体层固定、只含原有方向待机，未宣称全关节战斗模型。细刻纹和手指在26px不可见，头部轻动也很克制。未执行微信开发者工具、真机、五人试玩或真人动作签收；没有更新 Windows／微信包、current 或 latest。最终全平台与真人验收仍需统筹安排。

