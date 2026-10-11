# ① 显式版本分派集成

当前状态：模块完成待集成（2026-10-01）。三个公共入口显式分派已完成；当前共享工程旧奖励回归待④存档依赖落盘后重跑。

已读取 INTEGRATION.md 和当前三个共享模块；开始前 `git diff` 确认 content_db.gd / rewards.gd / combat.gd 均无未提交差异。本批仅修改这三个生产文件与①前缀测试、证据和本报告。

## 已实现与公开接口

- `ContentDB.rules_version: int = 1`。版本2的 `player_stats(player)` 直接调用 `Phase3Items.player_stats(player, data)`，严格使用调用者内容快照。版本1原函数主体不变，未知整数版本返回 `{ok:false,error}`。
- `RewardRules.resolve(db, player, reward)` 根据 `db.rules_version` 分派，2调用 `Phase3Items.resolve(db.data, player, reward)`，1保留原奖励逻辑和结果结构，未知版本明确拒绝。
- `TowerCombat.simulate(player, enemy, stats, rules_version: int = 1)`：只有2调用 `Phase3Combat.simulate`；三参数旧调用、显式1均保留原战斗循环、结果键集合及完整日志，未知版本明确拒绝。
- 不检查 `p3_*` 物品存在与否来推断规则。分派测试也验证“有新物品仍走显式v1”和“没有新物品也能显式v2”。
- 依赖为 `ContentDB/Rewards → Phase3Items`、`Combat → Phase3Combat`；两个目标叶子模块无反向 preload，无循环依赖。
- 三个文件总计18行新增、1行签名替换，未改旧算法主体。`git diff --check`通过。

调用示例：

```gdscript
db.rules_version = int(validated_run.reward_rules_version)
var stats: Dictionary = db.player_stats(player)
var preview: Dictionary = Rewards.resolve(db, player, reward)
var report: Dictionary = Combat.simulate(player, enemy, stats,
    int(validated_run.combat_rules_version))
```

统筹必须在通过快照/版本验证后显式设置；开始旧局或载入旧局时重置 `db.rules_version=1`，避免重用DB遗留v2。未知版本的错误须由外层阻断，不能继续取 `.attack` 等字段。本聊天没有修改引擎、存档或UI来处理该接线。

## 修改文件

- 生产：`scripts/core/content_db.gd`、`scripts/core/rewards.gd`、`scripts/core/combat.gd`。
- 新测试：`tests/phase3_items_dispatch_baseline.gd`、`tests/phase3_items_dispatch_test_runner.gd`、`tests/phase3_items_legacy_isolation.py`。
- 本报告及 `build/verification/phase3/01-items/integration/**` 证据。
- 没有修改 campaign_engine/map_engine/save/UI，也没有回滚、提交、推送、导入全工程或发送跨聊天消息。

## 实际测试结果

| 测试 | 结果 | 证据（integration目录） |
| --- | --- | --- |
| 修改前旧输出录制 | 138组玩家/奖励输入，414份完整战报；含旧三个源码SHA-256 | `legacy-before-dispatch.json`、`baseline.log` |
| 显式版本分派与完整旧输出对照 | **1133检查，0失败，退出0** | `dispatch-results.json`、`dispatch.log` |
| 现有旧战斗回归 | **55检查，0失败，退出0** | `combat_test_runner.log` |
| 独立物品专项 | **775检查，0失败，退出0** | `phase3_items_test_runner.log` |
| ①③实际模块联测 | **481检查，0失败，退出0** | `phase3_items_combat_test_runner.log` |
| 现有旧奖励回归／当前共享工程 | **首轮失败，不记为通过**；加载存档依赖失败并导致3项断言失败 | `reward_test_runner.log` |
| 现有旧奖励回归／旧基线隔离工程 + 本次入口 | **459检查，0失败，退出0** | `reward-isolated-baseline.log`、`legacy-fixture-manifest.json` |

1133项包含修改前全部旧属性/奖励结果和旧战报逐键、逐回合对照（对JSON整数按数值比较，但不忽略结果或日志字段）；v2真实委派完全相等、R2上限与HP截断、唯一持有、灯芯只加一次防御、可变冻结定义、-1/0/3/99未知版本明确拒绝、调用纯度、切回v1和新DB默认v1。

隔离奖励回归不是替换生产工程：`phase3_items_legacy_isolation.py` 从已批准的 `build/integration/phase3-baseline-20261001/workspace-before-phase3.zip` 读取90个原core/data/test文件至自己的证据目录，再覆盖本次3个入口及其2个phase3叶子模块。没有向工作区原路径写回任何旧文件。manifest逐文件记录来源SHA-256，证明旧地图/存档基线加本次分派可以完成原奖励回归；不把它冒充④新存档集成验证。

Godot每次在当前受限系统输出 `Failed to read the root certificate store`；与本地规则/文件回归无关，成功测试退出码均为0。所有APPDATA/LOCALAPPDATA和user://都隔离到①证据子目录，不使用玩家存档。

## 复现命令

以下PowerShell命令从工程目录执行；Godot为4.7.2：

```powershell
$env:APPDATA = './build/verification/phase3/01-items/integration/appdata'
$env:LOCALAPPDATA = './build/verification/phase3/01-items/integration/localappdata'
$itemsGodot = 'godot'
& $itemsGodot --headless --path . --script res://tests/phase3_items_dispatch_test_runner.gd --quit-after 600
& $itemsGodot --headless --path . --script res://tests/combat_test_runner.gd --quit-after 3600
& $itemsGodot --headless --path . --script res://tests/reward_test_runner.gd --quit-after 3600
& $itemsGodot --headless --path . --script res://tests/phase3_items_test_runner.gd --quit-after 3600
& $itemsGodot --headless --path . --script res://tests/phase3_items_combat_test_runner.gd --quit-after 3600
python tests/phase3_items_legacy_isolation.py
& $itemsGodot --headless --path ./build/verification/phase3/01-items/integration/legacy-fixture --script res://tests/reward_test_runner.gd --quit-after 3600
```

不要重新生成 `legacy-before-dispatch.json`；录制脚本已拒绝覆盖它，保存的是修改前三个生产入口的输出。隔离夹具仅验证旧分支，不能用于第三阶段新保存验证。

## 剩余问题与接口差异

- 无接口偏离。当前共享工程 `map_save.gd:6` 已引用 `phase3_save_validation.gd`，本次最后检查该文件尚未存在，这是④并行施工中的外部依赖，未越界修改。依赖就绪后统筹需重跑原 `reward_test_runner.gd`；不要根据其首轮“455检查/3失败”摘要忽略此前的脚本加载错误。
- 统筹负责将已验证版本写入DB、在所有战斗预览与提交传第四参数，并在旧局入口重置版本；③负责实际生产路线/存读档联调。
- 本交付不宣称主游戏第三阶段已集成完毕。
