# B 组 · 13 敌人原生部件精修交付

## 2026-10-04 正式接入及追加修订完成

**正式 `assets/monsters/phase3/manifest.json` 已接入全部 13 敌人、26 独立地图／战斗源、90 时间轴、821 PNG。** 先对 v07 全部候选完成图像二审并通过原精确 SHA 门控发布；收到用户追加暗部轮廓、材质与地图／战斗一致性要求后，另建 v08，保留 v07 的所有源、候选、批准、像素和证据。最终 58 条动作使用 v07，32 条使用 v08，没有剩余 v03/v04/v05/v06 运行帧引用。

v08 进一步修改术士、焰祷、典狱长、骑士、金库骑士和狂战士，12 原生源、242 PNG：术士胸袍／袖口局部提亮并保持暖金与暗兜帽；典狱长胸甲、头盔和链条提高暗侧可读性；骑士系头胸局部轮廓收敛。其他 7 敌人沿用已审 v07。骨架、握点、接触路径、固定根构图、z、alpha、动作、事件、帧数、FPS、hold、锚点和魔像五档持续石甲不变。没有改生产播放器、核心机制、舞台、UI、加载页或图标。

v07 候选 SHA：`1ef9a58b8aee7fc6215049d000f9fb65f673c48a1b6b26a292ee07ce4c424bf3`。

v08 候选 SHA：`337c82345bb950238de0c036ac9724e2195d2da62d7e45923a5eaa64d1adee94`。新候选保留 draft；正式清单的对应动作通过门控变为 accepted。v08 的两轮图像审阅由同一代理完成，记录明确说明身份，不声称独立人员或真人签收，始终 `human_signoff=false`。没有用旧候选批准覆盖新像素。

### 最新图像与审阅证据

| 内容 | 证据 |
| --- | --- |
| 术士、典狱长、焰祷的地图／战斗与 v07/v08 全尺寸并排 | [造型与材质 1](../build/verification/art-polish-b-v08/identity_material_0.png) |
| 骑士、金库、狂战士并排 | [造型与材质 2](../build/verification/art-polish-b-v08/identity_material_1.png) |
| 同背景 26/33/47px | [战斗](../build/verification/art-polish-b-v08/battle_comparison.png)、[地图](../build/verification/art-polish-b-v08/map_comparison.png) |
| 正式路径战斗截图 | [术士 390](../build/verification/art-polish-b-v08/production/runtime/warlock_390.png)、[典狱长 320](../build/verification/art-polish-b-v08/production/runtime/warden_320.png)、[焰祷 540](../build/verification/art-polish-b-v08/production/runtime/p3_ember_channeler_540.png) |
| 正式路径地图截图 | [首层 390](../build/verification/art-polish-b-v08/production/map/floor1_overview_390.png)、[魔像 320](../build/verification/art-polish-b-v08/production/map/floor10_near_320.png) |
| v08 原生逐帧和原速／0.25 倍 | `build/verification/art-polish-b-v08/sheets/`、`native/`、`native_sheets/`、`native_summary_0.png` 至 `native_summary_3.png`；12 源、32 动作、300 定时样本 |
| 审阅与精确批准 | [v07 二审](../assets/monsters/phase3/source/art_polish_b_v07/art_polish_b_coordinator_review.json)、[v08 制作审阅](../assets/monsters/phase3/source/art_polish_b_v08/art_polish_b_publish_review.json)、[v08 第二轮](../assets/monsters/phase3/source/art_polish_b_v08/art_polish_b_coordinator_review.json)、[v08 说明](../assets/monsters/phase3/source/art_polish_b_v08/REVIEW.md) |

正式截图包含其他聊天同期接入的舞台、地图和 UI，仅用于组合运行验证；B 组改动应以同背景敌人对比图归因。

### 最新验证

- 原源／动作／native 哈希检查 142 项通过；v08 另核对 32 时间轴和 12 源，最终正式清单严格等于“旧根字段 + 审批 v07 + 审批 v08”，五档魔像映射原样保留。
- 正式清单读取路径（未调用 preview loader）：协议 1,723 项、播放器 210 项、13 敌人 × 三尺寸 × 正常／减动效回放 703 项，均 0 失败；78 张正式回放截图。
- 正式地图 1/2/5/10 层、全图／近景、320/390/540，26 张截图；动画变化、减动效冻结及状态不变通过，最终 UI 溢出记录为 0。
- 本轮第一遍地图测试因共享 UI 的 320px 底栏溢出停住；保留 `published-map-20261004-022308-041.log` 失败记录。夹具改为继续采集但仍累计失败、最终非零退出；同期 UI 修改后重跑完整通过，B 组未修 UI 或放宽通过条件。
- 242 个 v08 导入 sidecar 的全部 `[params]` 与替换前一致。去重动画 image data 峰值 43,515,904 bytes（41.50MiB），敌人 LRU ≤8MiB、地图 ≤4MiB。不是设备 RAM 或真机性能结论。
- 所有项目 Godot 操作使用 `MagicTa_Phase3_Parallel_Godot` 公共锁和隔离 APPDATA；实际游戏存档未使用。根证书存储告警保留，不混同脚本失败。

### 微信独立验证包

输出仅在 `build/wechat-enemy-polish/`，Godot 4.6.1 / 插件 0.2.1，沿用既有 `high-performance` 模式和导入画质。**未修改 20MiB 总包／4MiB 主包预算，未降全局画质；未上传或发布线上。** `build/wechat-current` 与所有既有 latest 指针未变；本次使用 `--no-latest`，不创建新 latest 指针。

- 总包 **20,857,892 bytes（19.89MiB）**，主包 **2,427,533 bytes**；总包剩余 **113,628 bytes**，后续联合美术更新需重新检查。
- 导出 ZIP 内正式敌人清单与工作区相同，821 个运行帧 remap／纹理载荷全部存在；1,063 张历史 PNG（原 821 + 被 v08 替换的 242 张 v07）及其 sidecar 不在包中。原工程素材全部保留。整体 1,169 个生产 PNG remap／载荷核验通过，2,510 个退役路径确认未导出。
- staging 按精确历史路径清单排除资源，生产清单和脚本直接引用优先保留；候选 JSON、制作源和工具不入包。5 项导出引用／缺失载荷／退休边界测试通过。
- [包体及资源核验](../build/verification/art-polish-b-v08/export-verification.json)、[完整构建报告](../build/wechat-runs/20261004-023615-756395/build-report.json)、[独立 ZIP](../build/wechat-runs/20261004-023615-756395/TowerRealm-WeChat.zip)。这证明本地导出，不声称微信开发者工具或真机通过。

复核命令：`tests/art_polish_b_contract_test.py --production`、`tools/art_polish_b_v08.py production-contracts`、`tests/wechat_art_budget_test.py`。Godot 捕获使用原公共锁脚本，测试参数为 `--production --v08`；再次导出使用 `tools/art_polish_b_wechat_verify.ps1 -AppId <既有AppID>`。发布后的纹理不可原位重跑 stage；工具会拒绝，后续需新版本和新 SHA 批准。

剩余限制：地图短身与战斗长身仍为原有两套镜头，本轮改善局部轮廓和材质身份而非统一解剖重建；26px 金纹与魔像相邻甲档继续依赖机制文字。真人美术、微信客户端和真机验证尚未完成。

## 2026-10-03 制作交付历史（保留）

以下记录为初次交付时状态，当时正式 manifest 尚未切换；其“待统筹”项目由上面的 2026-10-04 记录更新。

## 实际改动

先读并核实 golem_v06 REVIEW/HANDOFF：五档持续石甲、各档动作和独立地图早已完成，本轮完整沿用。选择小尺寸偏暗的术士为实际样板，原生烘焙并看图后扩展至13种敌人，两套独立镜头共26原生源、90时间轴、490身体帧位、331独立效果帧位。

| 范围 | 本轮精修 | 保留 |
| --- | --- | --- |
| 术士 / 焰祷 | 兜帽、胸袍、袖口局部轮廓增宽，暗布提亮与冷反光分区 | 物理法杖、炉环、三叉头、独立暖火与 charge |
| 狂战士 / 典狱长 | 胸肩、头盔及肢体局部宽度，旧金属暗部层次 | 斧、盾、链、释放与接触路径 |
| 骷髅 / 骑士 / 金库 | 头部、胸甲、盾面可读性及旧金属色材 | 剑握点、冠与钥匙孔盾、threat |
| 守卫 / 盾壳 / 魔像 | 灰蓝石面、局部胸肩与头部边界；魔像幅度较小 | 盾壳 guard，魔像全部五档实体甲、核心、armor与残骸 |
| 蝙蝠 / 史莱姆 / 牛头 | 头部与翼膜分区、表情局部宽度；牛头局部体块轻修 | 翼关节、软体形变、牛头斧与 rage，原整体体量 |

源继续使用原生层编辑，没有新栅格原画。原图按字节复制，完整生成提示词仍保留于对应 v03/v04/v05/v06 源；逐源映射与改动部件写入新 rig 的 `art_polish` 和 [routes](../assets/monsters/phase3/source/art_polish_b_v07/art_polish_b_routes.json)。不是13套重绘或新增长度的动画。

局部宽度发生在图像部件内，骨架、握点、父子关系、接触路径、固定根构图、z层级、动作姿态、FPS、loop、事件、hold、大小与锚点保持一致。色材 shader 只用于源烘焙，运行仍是身体/效果 PNG 与原播放器。未修改任何核心规则、数值、战报、存档协议或其他组脚本。

## 文件与运行接入

- 新源：`assets/monsters/phase3/source/art_polish_b_v07/`，有 `.gdignore`、26份 rig、可编辑 `.tscn`、组件、原图、draft manifest、帧和审阅记录。
- 独立运行候选帧：`assets/monsters/phase3/textures/art_polish_b_v07/`，821 PNG；全部保留原大小与导入参数。
- 候选：[art_polish_b_candidate.json](../assets/monsters/phase3/art_polish_b_candidate.json)。磁盘状态仍为 draft。
- 专属可玩入口：[art_polish_b_playable.gd](../tests/art_polish_b_playable.gd)。使用真实 `map_screen` / `campaign_engine`，seed42，可正常进行游戏；隔离档 `user://art_polish_b_playable.json`。
- [preview_loader](../tests/art_polish_b_preview_loader.gd) 只在 B 组隔离进程内把候选供应给生产读取器；断言隔离 APPDATA。没有增加正式游戏后门、开关或改动生产默认路径。
- 工具：`tools/art_polish_b_author.py`、`art_polish_b_bake.gd`、`art_polish_b_stage.py`、`art_polish_b_native_capture.gd`、`art_polish_b_sheets.py`、`art_polish_b_review.py`、`art_polish_b_publish.py`。
- 检查与捕获：`tests/art_polish_b_contract_test.py`、`art_polish_b_production_test.gd`、`art_polish_b_enemy_regression.gd`、`art_polish_b_runtime_capture.gd`、`art_polish_b_map_capture.gd`。
- [完整逐文件清单](../build/verification/art-polish-b/files.txt)。未改 `phase3_enemy_player.gd` / `phase3_enemy_map_art.gd`，它们沿用既有协议即可读取候选。

## 实际看图与证据

[本地交互审阅](../build/verification/art-polish-b/review.html) 可选全部90动作、原速/0.25倍/暂停/逐帧/效果开关；[制作审阅说明](../assets/monsters/phase3/source/art_polish_b_v07/REVIEW.md) 和 [精确SHA批准](../assets/monsters/phase3/source/art_polish_b_v07/art_polish_b_publish_review.json) 独立于烘焙。

| 证据 | 链接 |
| --- | --- |
| 战斗与地图相同背景旧/新比较，含26/33/47px | [战斗](../build/verification/art-polish-b/battle_comparison.png)、[地图](../build/verification/art-polish-b/map_comparison.png) |
| 320/390/540全13敌人实际回放 | [320](../build/verification/art-polish-b/after/ui_contact_320.png)、[390](../build/verification/art-polish-b/after/ui_contact_390.png)、[540](../build/verification/art-polish-b/after/ui_contact_540.png) |
| 术士样板390 / 典狱长320 | [术士](../build/verification/art-polish-b/after/runtime/warlock_390.png)、[典狱长](../build/verification/art-polish-b/after/runtime/warden_320.png) |
| 首层全图390 / 牛头近景540 / 魔像近景320 | [首层](../build/verification/art-polish-b/after/map/floor1_overview_390.png)、[牛头](../build/verification/art-polish-b/after/map/floor5_near_540.png)、[魔像](../build/verification/art-polish-b/after/map/floor10_near_320.png) |
| 90动作精确逐帧 / 980张native原速与慢速定时采样 | `build/verification/art-polish-b/sheets/`、`native/`、`native_sheets/`，总览 `native_summary_0.png` 至 `native_summary_8.png` |

改前目录 `before/` 保留39张正常回放与26张地图；改后 `after/` 有78张正常/减动效回放与26张地图。四层为生产生成器的seed42美术夹具，不是自然通关。减动效生产回放直接进入结算页，敌人稳态及效果禁用由播放器检查覆盖，不把空结算页当作角色细节证据。

共享工作区 A/C/D 组在捕获期间接入了主角、舞台与UI；这些实际截图可用于联合外观复核，不能把所有前后差异归功于B组。上面的同背景敌人对比用于隔离B组变化。原速定时采样可能迟于目标时间，完整 timing JSON 保留实际秒数；逐帧静态图覆盖所有帧位。不声称连续视频感知或真人签收。

## 验证结果

Godot 4.7.2，所有导入/渲染/测试通过 `tools/phase3_v05_godot_locked.ps1 -Group art-polish-b`，真实玩家存档未读取。锁日志在 `build/verification/phase3/08-parallel/art-polish-b/`。

| 检查 | 结果 |
| --- | --- |
| 原生结构、动作协议、manifest未改、native源哈希 | 142项通过 |
| 最新v06全13敌人生产协议的B隔离副本 | 1,723项，0失败 |
| 既有敌人播放器回归的B隔离入口 | 210项，0失败 |
| 正式回放UI，13敌人 × 320/390/540 × 正常/减动效 | 703项，0失败；78截图 |
| 正式地图1/2/5/10层，全图/近景三尺寸 | 26截图；动画变化、减动效冻结及游戏状态不变通过 |
| 原生AnimationPlayer原速与0.25倍 | 26源、90动作、980定时样本，源重新加载成功 |
| 专属实际可玩入口 | 刷新导入后正常打开seed42，最终无脚本错误 |

UI压力夹具实测去重 image data 峰值43,515,904 bytes（41.50MiB），敌人LRU≤8MiB、地图≤4MiB；包括当时主角、遗迹与显示纹理，不是进程RAM或手机性能。

过程保留：初轮烘焙材质未显式继承节点alpha，随后修复并全量重烘焙，只有后者进入候选；一次Python默认GBK读取中文源失败，改UTF-8后重跑；首次试玩入口因A组新资源正在接入、尚未导入产生preload错误，公共锁刷新导入后最终通过。系统根证书存储告警单独记录，不作为脚本失败忽略。

## 包体与统筹所需具体补丁

[PNG预算](../build/verification/art-polish-b/budget.json)：旧20,019,669 / 新20,368,469 bytes压缩，替换净增348,800 bytes（0.33MiB）。[桌面导入纹理预算](../build/verification/art-polish-b/imported-budget.json)：旧16,379,712 / 新16,519,478 bytes，净增139,766 bytes（0.13MiB）。二者都不是微信最终包；本组未导出或修改20MiB阈值。

1. 统筹实际二审后，创建独立JSON记录 `reviewer_role="coordinator"`、`decision="accepted"`、`human_signoff=false`、自己的 `review_method`，并绑定与制作审批相同的 `candidate_sha256` 和90项 `approved_actions`。不能把技术检查自动当成二审。
2. 运行 `python tools/art_polish_b_publish.py --review <统筹审阅文件> --publish`。该工具检查旧manifest仍等于B基线、候选精确帧SHA、原协议、源/native哈希，只替换90动作；其他manifest根字段（含魔像五档映射）保持。若基线已被其他集成改动，门控拒绝覆盖，需先对账。
3. 使用 [retirement-candidates.json](../build/verification/art-polish-b/retirement-candidates.json) 做引用审查后，在staging排除821个被替换的旧身体/效果PNG及sidecar。保留主工程原图与历史资源。**不能将两套821帧重复打入包内**。候选清单与制作工具/源本身也不需打入正式微信包。
4. 统筹在最终组合版本运行现有集成检查、Godot4.6.1隔离导出及实际包体核对，按既有流程更新current/latest。本组没有需要其他组改播放器/核心逻辑的补丁。

## 复现与边界

```powershell
# 使用项目已有Python/Pillow运行时；不要重跑author/bake覆盖已经审阅的候选后沿用旧审批。
./tools/phase3_v05_godot_locked.ps1 -Group art-polish-b -Label playable -GodotArgs @('--script','res://tests/art_polish_b_playable.gd')
./tools/phase3_v05_godot_locked.ps1 -Group art-polish-b -Label protocol -GodotArgs @('--headless','--script','res://tests/art_polish_b_production_test.gd','--','--after')
./tools/phase3_v05_godot_locked.ps1 -Group art-polish-b -Label runtime -GodotArgs @('--script','res://tests/art_polish_b_runtime_capture.gd','--','--after')
./tools/phase3_v05_godot_locked.ps1 -Group art-polish-b -Label map -GodotArgs @('--script','res://tests/art_polish_b_map_capture.gd','--','--after')
```

仍需统筹二审发布、最终微信资源导出/客户端/真机与真人美术签收。地图短比例与战斗长比例仍是原有两套镜头，本轮未完全重建解剖比例；26px金纹和相邻甲档继续依赖文字。没有把这些限制标成已完成，也没有以测试数量代替画面质量。
