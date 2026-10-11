# ① 构筑与物品交付

当前状态：模块完成待集成（2026-10-01）

## 已实现清单

- 六件遗物定义齐全：稳定 ID、名称、机制说明、价格、阶级、构筑标签、初始可用标记、候选楼层/主题、唯一持有、图标引用。
- `phase3_items.gd` 独立实现旧 22 件静态效果及副本叠加、五种战斗效果输出、鎏金灯芯战前条件防御和来源说明。
- 纯奖励事务支持原 `cost/effects/item_id`，新增 `cost.max_hp`。先校验全部输入和唯一持有，再扣成本、再发奖励；失败无部分扣费或发放。生命上限成本扣基础值、保留装备增益、当前生命立即按扣费后派生上限截断；不会治疗，也不对缺血玩家额外扣 10 当前 HP。
- `resolve` 保留旧结果字段，准确显示持币攻击变化、灯芯防御变化、治疗/溢出和当前/上限生命差额；旧上限物品每领取一件治疗一次。
- 内容和输出均深复制；模拟/事务只使用传入的本局内容快照，不访问全局新定义、不消耗 RNG、不读写玩家存档。
- 构筑组件提供混搭标签、每件物品说明、灯芯当前生效状态、完整领取前后差异、标记敌人反击次数/受伤/胜负比较；战斗比较调用注入的真实模拟器。
- 六个原创矢量图标、六张 256×256 RGBA 母版、六张 128×128 RGBA 正式图标，含来源、SHA-256、安全边距检查及32px深浅底预览。

## 公开接口

### 核心接口

```gdscript
const Items = preload("res://scripts/core/phase3_items.gd")
var definitions: Dictionary = Items.definitions()
var frozen_content: Dictionary = Items.merge_content(base_content, definitions)
var stats: Dictionary = Items.player_stats(player, frozen_content)
var preview: Dictionary = Items.resolve(frozen_content, player, reward)
```

- `definitions() -> Dictionary`：返回本模块 items 字典副本；读失败返回 `{ok:false,error}`。
- `merge_content(content, item_definitions={}) -> Dictionary`：返回完整内容副本；空定义选用默认，显式定义用于冻结快照；失败返回错误字典。成功为完整内容，不额外包 `content` 字段。
- `validate_definitions(definitions)` / 补充 `validate_player(player, content)`：`{ok,error}`。拒绝未知效果、无效类型/分数/NaN/无限值、负价格、0 间隔、无限次数、新遗物取消唯一配置、重复持有及错误物品栏。数值上限 1,000,000，与③战斗属性限制一致；本物品模块 charges/interval 范围 1～100；单栏最多 4096 条。
- `player_stats(player, content)`：成功有 `ok,error,attack,defense,max_hp,kill_heal,gold_bonus,combat_effects,effect_sources`。五种 combat_effects 数值输出为整数，均含 `source_item_id`。灯芯的 `gold_defense_threshold` 只放 `effect_sources`，防御已在 `stats.defense` 中，③不要重复加。
- `effect_sources`：静态条目 `{id,amount,source_item_id,active}`；持币攻击另含 `step`；灯芯另含 `threshold,configured_amount`，未触发时 `amount:0,active:false`。来源是说明数据，不是待执行战斗命令。
- `resolve(content, player, reward)`：成功返回协议全部字段 `player,before,after,healing,overflow,attack_delta,defense_delta,max_hp_delta,hp_delta,gold_delta` 及 `ok,error`。
- `cost.max_hp` 即使与 `effects.max_hp` 同交易也必须先付得起成本；后续上限增益不恢复扣费时已截断的生命，只有显式 heal 或新物品上限治疗可以恢复。

### 构筑组件

```gdscript
const BuildSummary = preload("res://scripts/ui/phase3_build_summary.gd")
var panel = BuildSummary.new()
host_scroll_container.add_child(panel)
var comparison = BuildSummary.reward_comparison(frozen_content, player, reward,
    discovered_enemy, Phase3Combat.simulate)
panel.present(player, frozen_content, comparison)
```

- `describe(player, content)` 返回 `{ok,error,stats,tags,rows}`，tags 为 assault/guard/wealth 物品计数，无套装加成。
- `reward_comparison(content, player, reward, enemy={}, simulator=Callable())` 返回 `{ok,error,transaction,text}`；提供敌人时另含 `combat_before,combat_after`，必须注入本局模拟器。组件不获取未知敌人，不暴露剧情。
- `present(player, content, comparison={})` 在 VBoxContainer 展示；大量物品时由宿主包 ScrollContainer。继承宿主 Theme，不修改主 UI。

## 修改文件

- `data/phase3_items.json`
- `scripts/core/phase3_items.gd`
- `scripts/ui/phase3_build_summary.gd`
- `tests/phase3_items_test_runner.gd`：独立核心/说明组件测试。
- `tests/phase3_items_combat_test_runner.gd`：读取③实际战斗模块的接口联测。
- `tests/phase3_items_assets.gd`：矢量图标栅格化、透明和边距校验、接触表。
- `tests/phase3_items_preview.gd`：独立 Godot 窄屏/宽屏 UI 夹具及截图。
- `assets/items/phase3/**`：仅本模块素材、manifest、来源说明。
- 本文件及 `build/verification/phase3/01-items/**` 证据。没有修改任何既有共享入口、旧内容、生成器、版本常量或他人文件；没有提交、推送、重置、创建聊天/子代理或发送跨聊天消息。

## 测试命令与实际结果

实际运行 Godot 4.7.2；所有命令隔离 APPDATA 和 LOCALAPPDATA，结果记录中的 `user_data_dir` 位于自己的证据目录。

```powershell
$env:APPDATA = './build/verification/phase3/01-items/appdata'
$env:LOCALAPPDATA = './build/verification/phase3/01-items/localappdata'
$godotItems = 'godot'
& $godotItems --headless --path . --script res://tests/phase3_items_test_runner.gd --quit-after 600
& $godotItems --headless --path . --script res://tests/phase3_items_combat_test_runner.gd --quit-after 600
& $godotItems --headless --path . --script res://tests/phase3_items_assets.gd --quit-after 600
& $godotItems --path . --script res://tests/phase3_items_preview.gd --rendering-method gl_compatibility --quit-after 600
& $godotItems --path . --script res://tests/phase3_items_preview.gd --rendering-method gl_compatibility --quit-after 600 -- --compact
```

| 实际验证 | 结果 | 证据 |
| --- | --- | --- |
| 独立核心及组件 | 775 checks / 0 failures，退出0 | `results.json`、`test-final.log` |
| 与③生产战斗模拟器联测 | 481 checks / 0 failures，退出0 | `combat-results.json`（含读取时③脚本SHA-256）、`combat-test.log` |
| 图标导出 | 6/6，RGBA透明与12%边距通过，退出0 | `assets.log`、素材 `manifest.json` |
| 宽屏实际渲染 | 1120×980，截图保存OK，检查无溢出 | `build-summary-wide.png`、`preview-wide.log` |
| 窄屏实际渲染 | 540×980，截图保存OK，检查六件说明完整换行 | `build-summary-compact.png`、`preview-compact.log` |

775项覆盖旧22件各两次领取的玩家值/派生值/差额精确对照、旧全部事件、44件混搭、金币24/25/49/50/99/100、财富购买净攻+4/防-2、五效果协议、六遗物重复交易无扣费、R2基础上限10/11边界、装备上限和缺血/满血截断、合并成本与治疗、三色钥匙、输入非法值、冻结内容隔离、组件实例化等。481项覆盖首击阈值、第三/六击、格挡2次、零伤消耗、反伤3次、死亡不治疗/反伤/发金币、反伤击杀奖励一次、赏金三档、灯芯不重复加防与旧22物品对三类敌人的战斗结果对照。

首次测试发现 GDScript 类型推断错误和 JSON float/int 的协议差异，均已修复；最终结果如上。每次 Godot 在此受限系统环境均输出 `Failed to read the root certificate store`，不涉及本地逻辑/截图且未影响退出码。未进行网络访问测试。

## 图/动画来源与实显检查

详见 `assets/items/phase3/SOURCES.md`。按 imagegen 技能对项目原生图标体系的适用指引，采用原创 SVG 延续已有 `item_icon.gd` 的几何图标风格；未使用外部图片、图片生成服务或 CLI。六张 PNG 均由 SVG 确定性栅格化。

已实际查看 `icons-dark.png`、`icons-light.png` 中128px、32px和放大检查图，以及两张 Godot 构筑面板截图。六种轮廓可区分；三结穗32px较细，不建议降至16px。本模块没有逐帧动画交付，静态素材没有冒充动画。

正式128图标PNG合计约70KiB；母版合计约98KiB。未执行全工程素材导入；独立预览仅把PNG读进临时资源缓存，不写导入设置。

## 统筹接入需求

1. 在第三阶段新局冻结内容时合入 `Items.merge_content`，存入本局 reward/content 快照；旧两层/旧十层继续原模块与原快照，不热更新旧局。
2. reward_rules_version=2 分派至本模块，stats 同样使用传入冻结内容。统一让商店/宝箱/遗迹调用 `resolve`，完整结果可直接作为确认页数据。商店一次购买、满血药剂禁用、实体耗尽属于宿主交互规则，本纯奖励函数没有实体状态。
3. 仅在最外层保存成功后提交候选 player 和实体耗尽；失败保留原玩家/实体，重试同一候选。模块验证了纯事务，不声明已通过真实写盘失败或恢复测试。
4. ②负责2/6层候选替换、独立内容RNG、全塔唯一预留、机会预算；④负责后三遗物解锁。`initially_available/candidate_floor/candidate_themes` 为数据辅助，不由本模块自动抽取或解锁。
5. 构筑面板与 `icon` 字段接入行囊/奖励确认；标记敌人比较仅传已发现敌人及本局模拟器。③只消费 `combat_effects`，不要把 `effect_sources` 重新执行。
6. 统筹串行导入 `assets/items/phase3/icons/*.png`，检查正式导出资源引用。SVG/256母版为制作源，按工程策略排除不需要的制作源可减少包体。
7. 实际①③联测已通过，仍需统筹统一快照校验、版本分派、地图/存档/UI集成回归及整塔平衡。

## 未完成内容

①可独立实施范围已完成。尚未完成、且属于统筹集成范围：主游戏接线、正式素材串行导入/导出、完整存档事务回归、生成预算与解锁投放、三路线前五层/整塔实例、100种子资源曲线及人工试玩。未将本模块完成标为整个第三阶段完成。
