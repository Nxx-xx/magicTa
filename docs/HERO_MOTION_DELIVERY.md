# 公主战斗动作精修交付

2026-10-04。本项已接入正式战斗入口，按当前 **30 MiB 总包／4 MiB 主包** 配置重新评估通过；原先任务的净增 ≤ 0 目标也已达成。

## 交付范围

沿用原有手绘人物部件、右手剑／左手灯、分层节点及两节骨骼 IK，精修攻击 8 帧、防御 4 帧、受击 3 帧、胜利 8 帧，共 23 个独立身体姿态及对应可关闭 FX。没有重新生成 91 张人物图，也没有增加运行脚本。

- 攻击：后撤蓄力、肩部前送、髋部推进、接触后分段制动；披风与下摆分时跟随。
- 防御：降低重心，抬灯护住上身，剑手进入可辨识的防御位置。第一帧已开始进入防御，适配正式回放中较短的防御窗口。
- 受击：第一帧开始后缩，峰值时躯干后仰、肩部收紧，披风延迟回落。
- 胜利：提灯逐步展开，峰值后回落稳定，剑手保持放松。

攻击仍在第 3 帧、16 FPS，即 0.1875 秒命中；动作帧数、FPS、循环标记、事件、384×384 画布和 (192,348) 锚点完全保留。骨骼脚底固定在源画布 y=696，剑及灯仍挂接于真实手部握点。未改镜像、运行缩放、完整动作目录、玩法、存档、剧情文案或顺序，也未修改 `phase3_combat_player.gd`。

正式链路：`map_screen.gd` 已提交战报 → `phase3_combat_player.gd` → `phase3_animation_catalog.gd` → `assets/characters/hero/phase3/manifest.json` → 对应 `textures/v06/combat_*` 的替换资源。

源稿与可编辑动画位于 `assets/characters/hero/phase3/source/motion_v07/`，包含原部件、四动作 AnimationPlayer 场景、原版纹理备份、原清单、握点/落脚数据和视觉评审哈希。该目录及父 source 均有 `.gdignore`，实际导出也确认无源稿、辅助工具进入包。

## 对照与入口证据

- [改前四动作](../build/verification/hero-motion/before_four_actions.png)
- [改后四动作](../build/verification/hero-motion/after_contact.png)
- [原生分层动画预览](../build/verification/hero-motion/motion_preview.gif)：依实际 AnimationPlayer 采样生成，GIF 仅为审阅文件，不进入运行包。
- [手机视口改前／改后](../build/verification/hero-motion/phone_before_after.png)：同一正式 Player 的动作协议夹具，同一命中帧；不是自然战斗事件截图。
- [真实战斗入口](../build/verification/hero-motion/host/host-frames/02.png)：正式 C0、seed 42 首次史莱姆战斗，360×640 实际 viewport。

实际截图像素尺寸为 320×568、540×960，另有正式宿主 360×640。320 宽样本的窗口请求为 320×640，但项目纵横比规则实际渲染为 320×568；此处明确记录实际 viewport，未将缩放截图冒称为 320×640。全部截图由 Godot viewport 直接保存。

## 验证

全部 Godot 导入、烘焙、测试和导出持有 `MagicTa_Phase3_Parallel_Godot` 命名互斥锁，隔离 APPDATA／LOCALAPPDATA 位于 `build/verification/hero-motion/`。证据均保存于该目录。

| 检查 | 结果 |
|---|---|
| 正式动作读取、完整目录、缓存上限、FX 关闭、减弱动效、缺失 FX/身体回退、地图原生层级 | 408 项通过；重复资源共享后重新通过 |
| 回放命中／机制顺序、暂停、减弱动效、跳过及战报保持 | 20 项通过 |
| 320/540 宽正式 Player 动作样本、FX 开关、UI 边界及战报无写入 | 改前、改后各 76 项通过 |
| 正式宿主真实战斗、失败存档重试、结算、关闭、重新载入 | 9 项通过 |
| 1× 和 0.25× 原生 AnimationPlayer、握点父子关系、脚底与缩放 | 276 项通过，46 张原生采样；脚底最大误差 0.00001526 运行像素 |
| 23 身体姿态唯一性、画幅边界、源骨骼握点与脚底数据 | 全部通过 |
| 未改 14 个动作的导出纹理 | 136 个身体／FX 引用位置与基线 payload 字节一致 |
| 导出完整性 | 两层 ZIP CRC、全部文件 SHA256／长度通过；18 动作、91 身体帧位置保留 |

早期草稿曾出现一帧剑尖越界，已调整肩部前送及手部伸展，最终烘焙无越界。Godot 日志包含环境已有的证书存储读取提示；专用运行器明确排除此提示，未忽略脚本、解析、其他引擎错误或测试失败。

## 包体证据

基线：`build/wechat-runs/20261004-134105-179524`。

最终独立导出：`build/wechat-hero-motion`。

不可变本轮归档：`build/wechat-runs/20261004-135830-601305/TowerRealm-WeChat.zip`，同目录 `build-report.json`。

首版动作替换使实际压缩纹理增加 8,555 bytes。随后确认四方向 `map_interact` 首帧与各自 `map_idle` 首帧 PNG 完全相同，改为共享相同文件；重复原件及导入侧文件已移入 `source/motion_v07/retired_duplicates/`，SHA256 和引用映射见 `retired_duplicates.json`。这是等像素共享，地图动画帧数与显示内容不变。没有降低纹理分辨率、画质参数或修改全局打包策略。

| 本项核算，实际 engine/godot.zip 压缩条目 | 净变化 |
|---|---:|
| 公主 phase3 全部唯一运行纹理 payload（含 gait） | **−1,965 bytes** |
| 本项新增／修改运行脚本 | **0 bytes** |
| 包含 remap 与动作清单的本项条目合计 | **−2,525 bytes** |
| 原任务净增目标（历史记录） | ≤ 0，已达成 |

### 当前配置重新评估

核算脚本现直接读取 `tools/build_wechat.py` 的 `TOTAL_PACKAGE_BUDGET_BYTES` 和 `MAIN_PACKAGE_BUDGET_BYTES`，总包与主包分别判定；原任务的零净增目标作为历史交付结果单独记录。没有修改共享预算配置。

| 项目 | 现有独立包实测 | 当前预算 | 剩余额度 | 结论 |
|---|---:|---:|---:|---|
| 总包 | 20,455,602 bytes（19.507982 MiB） | 31,457,280 bytes（30 MiB） | **11,001,678 bytes（10.492018 MiB）** | 通过 |
| 主包 | 2,427,533 bytes（2.315076 MiB） | 4,194,304 bytes（4 MiB） | **1,766,771 bytes（1.684924 MiB）** | 通过 |

本次复核现有归档的两层 CRC、全部文件 SHA256 与长度，并重新核对总包／主包统计口径。当前工作区公主清单及全部身体／FX 源文件与该包 staging 一致，未改 14 个动作的 136 个纹理引用位置继续通过字节一致性检查。本次仅重新评估和更新审核工具，没有重新烘焙或导出；这些数字代表上述已交付快照，不代表此后其他并行工作全部合入的新包。

公主动作无需因旧 20 MiB 门槛继续压缩。现有四处共享是完全相同像素的去重，保留该优化不会损失动作表现。现有 384px 战斗纹理、原生分层动作及 23 个精修姿态可继续保留；后续若需要局部部件重绘或更清晰的姿态，应按手机视口效果、既定动作时序与实际导出增量评估。新配置未单独分配公主的新增额度，**10.492018 MiB 为该快照的全项目余量，不是公主专属额度**。

整体快照包含同 checkout 其他并行任务的变化，不将整体减少额归因于公主动作。30 MiB／4 MiB 是当前本地构建预算，**不是已确认的 AppID 平台额度**。原 20 MiB 口径及当时 515,918 bytes 余量保留于 [原预算审计](../build/verification/hero-motion/package-audit-original-budget.json)，不再作为当前配置的通过标准。

逐条明细与断言：[package-audit.json](../build/verification/hero-motion/package-audit.json)。重新核算命令：

```powershell
python tools/hero_motion_audit.py build/wechat-runs/20261004-135830-601305
```

导出由 `tools/hero_motion_package.ps1` 加锁执行，参数为指定 AppID、`--ios-mode high-performance --output-folder wechat-hero-motion --no-latest`。没有覆盖 current/latest，没有上传、发布或提交 Git。未完成微信开发者工具上传和真机验证；桌面 Godot 的真实 viewport 与包体检查不替代这两项验证。
