# 第三阶段开发协作台账

启动：2026-10-01。用户已确认采用五个独立开发聊天与当前聊天统筹的方式实施五份设计。工作区：`.`。

## 当前批次

2026-10-01 续接状态：独立模块交付后，①完成入口分派；②③④⑤在集成轮受到用量限制中断。统筹接管其未完成的集成文件，修复并验证，当前无需继续并行写入。程序集成结果见 [INTEGRATION_RESULTS.md](INTEGRATION_RESULTS.md)。下方“启动检查”和第一批分工保留为历史；新文件边界以 INTEGRATION.md 为准。

第一批交付独立模块、数据、专项测试和可运行预览；统筹负责公共接口、接入主游戏、版本化存档和集成回归。不能把独立模块完成标为完整第三阶段交付。每个聊天在完成所属完整范围时持续推进，不因主入口尚未接线而停留在规划。

### 启动检查

- 五个开发聊天已创建并确认进入 active / inProgress；ID与标题保存在 [THREADS.json](THREADS.json)。各聊天正在读取基线、建立交付记录并开发独立模块。
- 公共接口 v1 已下发，见 [INTERFACES.md](INTERFACES.md)。采用同目录、唯一文件负责人的分工；本次未创建 worktree 或切换分支。
- 统筹新增 `scripts/core/phase3_contract.gd`：旧/新规则识别、混合版本拒绝、已解锁配置与冻结快照检查。尚未接入主游戏，因此不改变现有旅程玩法。
- Godot 4.7.2 实际执行 `tests/phase3_contract_test_runner.gd`：66 项通过，0 失败。日志 `build/verification/phase3/00-contract/contract.log`。测试未访问玩家存档；仅有既有系统证书读取提示。
- 待办：各模块交付后评审其协议一致性，再由统筹串行接入共享入口与保存封装；整塔集成尚未完成。

## 开发基线

启动前工作区含微信适配、方向控制与新增运行时行走等未提交修改。已备份 465 个非忽略文件，约 164 MiB 原始内容，保存于 `build/integration/phase3-baseline-20261001/workspace-before-phase3.zip`；同目录有 SHA-256 清单、Git HEAD 与原变更补丁。不得恢复整个备份覆盖后来工作；需要恢复时由统筹按文件比对。

设计稿的“静态主角”描述是编写当时基线。启动开发时已有 `scripts/ui/hero_walk.gd` 和 `floating_joystick.gd`，⑤必须先读取并保留；第三阶段动作以独立资源/组件开发，统筹接入，不覆盖这些新实现。

## 文件负责人

| 聊天 | 可直接写入 | 只读/交给统筹 |
| --- | --- | --- |
| ① 构筑物品 | `data/phase3_items.json`、`scripts/core/phase3_items.gd`、`scripts/ui/phase3_build_summary.gd`、`assets/items/phase3/**`、`tests/phase3_items*`、`docs/phase3/DELIVERY_01.md` | 旧 content/rewards/content_db 与生成器 |
| ② 地图遗迹 | `data/phase3_ruins.json`、`scripts/core/phase3_ruins.gd`、`scripts/core/phase3_map_recipe.gd`、`scripts/ui/phase3_ruin_panel.gd`、`assets/environment/ruins/phase3/**`、`tests/phase3_ruins*`、`docs/phase3/DELIVERY_02.md` | 旧地图生成/校验/引擎/存档 |
| ③ 敌人首领 | `data/phase3_enemies.json`、`scripts/core/phase3_combat.gd`、`scripts/core/phase3_enemies.gd`、`assets/monsters/phase3/**`、`tests/phase3_combat*`、`tests/phase3_enemies*`、`docs/phase3/DELIVERY_03.md` | 旧 combat/enemy_rules；与⑤约定战报，不改其组件 |
| ④ 挑战解锁 | `data/phase3_challenges.json`、`data/phase3_unlocks.json`、`scripts/core/phase3_progress.gd`、`scripts/ui/phase3_codex_panel.gd`、`scripts/ui/phase3_challenge_panel.gd`、`assets/ui/phase3/progression/**`、`tests/phase3_progress*`、`docs/phase3/DELIVERY_04.md` | 旧 campaign_progress/campaign_save 与营地主入口 |
| ⑤ 引导动画 | `scripts/ui/phase3_tutorial.gd`、`scripts/ui/phase3_animation_catalog.gd`、`scripts/ui/phase3_combat_player.gd`、`assets/characters/hero/phase3/**`、`assets/ui/phase3/tutorial/**`、`tests/phase3_animation*`、`tests/phase3_tutorial*`、`docs/phase3/DELIVERY_05.md` | 旧 map_screen/grid_board/hero_walk/combat_presentation/settings/audio |
| 统筹 | `scripts/core/phase3_contract.gd`、`tests/phase3_contract*`、`docs/phase3/COORDINATION.md`、`INTERFACES.md`、`THREADS.json`、既有共享模块的第三阶段集成改动 | 不改开发聊天正在写的文件 |

每个开发聊天可增加自己专属前缀的测试、预览和辅助脚本，输出统一写 `build/verification/phase3/<01-items|02-ruins|03-combat|04-progress|05-animation>/`。新增文件也应归属明确。跨范围需求写在自己的交付文件的“统筹接入需求”段，不能抢改共享文件。

## 协作与检查规则

- 共享目录开发，文件负责人唯一；不切分支、不提交、不推送、不 reset、不清理他人未跟踪文件。
- 开始先读取本文件、`INTERFACES.md`、所属设计与实际源码。遵循现有代码风格和Godot类型要求。
- 接口文件由统筹维护，变更需求写交付文件；其他模块先使用约定输入夹具进行独立验证。
- 测试必须隔离 APPDATA/LOCALAPPDATA，不读写真实玩家存档。已有 Godot 位于 `godot`。
- 不同时执行全工程 `--editor --import`、主游戏导出或修改导出配置。确需素材导入由统筹串行执行；可先验证纯逻辑并记录待导入。
- 生成素材使用相关技能与来源记录；逐帧不合格不能以静态拉伸或多帧相同图片冒充完成。缺少可验证资源时明确列剩余项。
- 不创建额外聊天或子代理。用户已经安排五个工作流，进一步拆分需统筹决定。
- 不自动给别的聊天发消息；在自己的交付文件和本聊天中报告。统筹读取文件与聊天状态进行协调。

## 每个聊天的交付格式

`DELIVERY_0N.md` 必须包含：当前状态（进行中/模块完成待集成/受阻）、已实现清单、公开接口、修改文件、测试命令与实际结果、图/动画来源与实显检查、统筹接入需求、未完成内容。开始实施即建立交付文件，避免统筹只能猜测进度。

## 合入顺序

1. 统筹冻结协议与版本识别；①③完成效果和战斗，②④⑤同时实现独立模块。
2. 统筹接入新规则入口、快照与存档校验；旧两层/旧十层继续旧分支。
3. 接入①②③前五层与⑤样板，完成第五层闭环。
4. 后五层、④挑战与图鉴、⑤完整教学与动画分批接入。
5. 旧局、资源预算、100种子参考路线、真实界面和完整旅程验证；所有证据集中登记。

当前不能把平台排障、第三阶段本身或动画制作标记完成。微信验收不在此次开发范围。
