# ③ 敌人与首领交付

当前状态：**模块完成待集成**（2026-10-01）。确定性战斗/敌人数据与专项验证完成；第一批动作草稿和独立预览已交付。**不代表03完整美术或第三阶段完成。**

## 已实现清单

- 已完整读取协作台账、冻结接口、总册、03设计及旧战斗/敌人实现。
- 已实现五种战斗效果、狂怒、石甲、三种变体、事件列表、反伤最后一击、最低生命和明确输入错误。
- 三变体定义及验证、纯复制合并、冲突快照拒绝已实现。
- 五种物品效果组合测试、600组旧敌人对照、三变体准备水平对照均有实际结果。
- 牛头33帧、史莱姆18帧重绘源及透明运行帧；6种独立机制特效共28帧。角色帧均明确标draft，默认加载器拒绝投入正式演出。
- 可运行Godot独立预览：播放、暂停、逐帧、重新播放、96/64px显示、可关闭特效与只读战报；真实SpriteFrames加载入口及静态回退。

## 公开接口

- `phase3_combat.gd.simulate(player, enemy, stats)`：沿用旧战报并增加 `ok,error,combat_rules_version:2,min_hp,effects_triggered`。
- `phase3_combat.gd.validate_inputs(player, enemy, stats)`：不模拟，返回 `ok/error`。
- `phase3_enemies.gd.definitions()`：独立JSON定义副本；文件无效时返回明确错误。
- `phase3_enemies.gd.merge_content(content, enemy_definitions={})`：完整内容副本，空定义用默认；重复相同定义幂等，拒绝覆盖不同快照；错误返回 `ok:false,error`。
- `phase3_enemies.gd.validate_definitions(definitions)`：身份、数值、技能、楼层与替换来源校验。可传入合法变体子集。
- `assets/monsters/phase3/phase3_enemy_animation_catalog.gd.load_action(enemy_id, action_id, allow_drafts=false)`：默认拒绝草稿；审阅显式传true返回 `sprite_frames,animation,anchor,status,events`。缺失动作返回明确错误。
- 同一资源加载器的 `static_fallback(enemy_id)` 返回原图路径/锚点；变体附 `requires_mechanic_badge:true`，不将旧图冒充变体新轮廓。

## 修改文件

仅03专属新增文件：

- `scripts/core/phase3_combat.gd`、`scripts/core/phase3_enemies.gd`、`data/phase3_enemies.json`。
- `tests/phase3_combat_test_runner.gd`、`tests/phase3_combat_verify.ps1`。
- `tests/phase3_enemies_pack_art.gd`、`tests/phase3_enemies_preview.gd`。
- `assets/monsters/phase3/`：原始源/提示词/来源清单、51张角色PNG、28张FX PNG及对应SVG、manifest、来源与审阅说明、动画加载器。
- 本文及 `build/verification/phase3/03-combat/` 证据。

未改旧 `combat.gd`、`enemy_rules.gd` 或任何共享入口；未重置、提交、推送、全项目导入或导出。

## 测试命令与实际结果

Godot 4.7.2 最终实际结果：

| 命令（均带 `--path .`） | 实际结果 |
| --- | --- |
| `--headless --script res://tests/phase3_combat_test_runner.gd` | **44,725 checks，0 failures** |
| `--headless --script res://tests/phase3_enemies_pack_art.gd` | 9动作、51角色帧、6特效轨，0打包失败 |
| `--script res://tests/phase3_enemies_preview.gd -- --smoke` | **96 checks，0 failures**；OpenGL原生渲染3张截图 |

600组旧敌人输入逐字段比对，包括旧log.note与未截断hit；新边界覆盖首击击杀、狂怒3/6与致死不触发、石甲49/50/99/100和多阈值、反伤跨石甲、等伤害死亡无反伤/治疗、盾壳最低1、零伤消耗护符、反伤最后一击、赏金分类、五效果组合、非法输入和10,000回合终止上限。

五效果组合夹具：盾壳卫兵，玩家30HP/18攻/10防，五遗物效果与旧击杀治疗8、金币加12同时存在。5回合、4反击、incoming8、min_hp22、healing8、hp_after30、金币46；实际扣血总量守恒且逐回合事件与effects_triggered完全对应。

三变体与原敌人准备水平对照（玩家max_hp100；仅单怪例，不宣称整塔平衡）：盾壳18攻/9防，损失16→20（+4）；蓄焰24攻/12防，14→10（-4，因其基础攻击17）；金库30攻/15防，15→19（+4）。本组均未超过20%复核线，低攻路线仍需整塔验证。

全部Godot验证隔离 `APPDATA` / `LOCALAPPDATA` 到证据目录的 `appdata/`、`localappdata/`，不使用玩家存档。可复现包装命令：`powershell -NoProfile -ExecutionPolicy Bypass -File tests/phase3_combat_verify.ps1 -PackArt -Preview`（最后打开交互预览；不加两个开关只运行逻辑）。

实际证据：`combat-results.json`、`test.log`、`art-audit.json`、`art.log`、`preview-results.json`、`preview.log`、9张动作接触表、`preview_minotaur_attack.png`、`preview_minotaur_rage.png`、`preview_slime_attack.png`。Godot输出系统证书读取警告，本测试无网络、不影响退出0的结果。

## 图/动画来源与实显检查

使用内置imagegen技能，身份参考为项目原牛头/史莱姆图片；完整5组提示词、原始文件和SHA256都已保存。详情见 `assets/monsters/phase3/SOURCE_AND_REVIEW.md` 与 `source/sources.json`。

已实际目视检查牛头攻击/退场、史莱姆攻击接触表和原生Godot预览；观察到抬斧、屈膝、放斧、下跪、胶膜/核心重绘变化。源图不是等距格，初次等距裁切产生邻帧碎片，已通过透明连通区域分割修复并重验。最终51角色帧各自非空、具有透明、动作内像素互异、无源图边缘触碰；这些仅证明技术可用，**不证明所有动作流畅或美术验收通过**。

牛头384运行帧锚点(192,336)，史莱姆256帧锚点(128,224)。母版实际单格分辨率低于768/512目标，没有放大后冒充母版。没有可编辑分层/骨架源；牛头跨动作朝向、体量与肩甲一致性待修。manifest全部draft，缺失动作不引用空文件。FX为原创SVG路径及PNG烘焙，可独立关闭，不计为角色动作帧。

## 统筹接入需求

- 旧入口由统筹按 combat_rules_version 分派，03不修改旧 combat/enemy_rules。
- 运行时 stats 和敌人来自已冻结快照；十层魔像攻击28仍由原战役覆盖。
- 若新增素材需导入，由统筹串行导入，本聊天不执行全工程导入或导出。
- 兼容补充：`hit` 维持旧版未截断的名义伤害；新增 `actual_hit` 为实际扣血。事件amount按护盾/过量伤害后的边际实际收益记录；零收益触发仍有事件。`rank_gold_bonus` 记录在最后回合，金币只在胜利后计算。
- 接入调用：`preload("res://scripts/core/phase3_combat.gd").simulate(player, snapshot_enemy, derived_stats)`；先检查 `report.ok`，再读取战报。派生属性无 `combat_effects` 时按旧效果兼容。`enemy_hp_after_counter` 是反伤后的显示终态。
- 输入限额：HP/属性/奖励等有限整数0..1,000,000（存活HP和max_hp≥1），敌方HP 1..10,000；interval 1..10,000、charges 0..10,000；未知效果参数/技能、重复效果与不合法类型拒绝。JSON整数字面量的float表示可接受。
- `min_hp` 不含战后治疗；log.hp亦保持治疗前语义。`counterattacks` 包括零伤反击；护符零伤仍产生amount0事件并耗次数。`stone_armor` amount为本次实际防御增量，可能一次为4或以上；敌方来源在source_enemy_id。
- 反伤击杀仍只有本次玩家攻击回合：不要额外增加log行或玩家攻击。`enemy_hp` 是玩家攻击后HP，`enemy_hp_after_counter`才是该回合终态。零收益触发可用于计数，但不可显示虚假回血/减伤。
- 地图③定义仅声明合法替换范围，②/统筹需落实：3–4 sentinel、6–7 warlock、8–9 knight可选主题支路，每种全塔≤1、每层≤1，不改固定军械/首层骑士/Boss，没合法槽则不出现。
- ⑤可先消费逻辑战报；怪物新图默认继续原静态回退。只有审阅预览显式启用draft，不能把本批稿直接标accepted。

## 未完成内容

- 主入口版本分派、存档事务、快照/挑战完整校验、地图种子及合法槽集成、跳过/重进结算/营救剧情回归由统筹负责。本聊天没有跑主旅程或使用玩家存档，也不声称EN07–09的整塔集成通过。
- 美术：设计236帧中，**51帧已制作但仍草稿，185帧尚未制作，正式验收通过0帧**。缺骷髅/蝙蝠/卫兵/术士/骑士/两精英/魔像及三变体动作、变体独立轮廓附件、独立地图idle、分层模型与绑定母版。牛头/史莱姆现有稿需统一细节、朝向、原生分辨率和完整连续性验收。
- 100种子参考路线、后五层整局资源曲线和多人试玩尚未做；不得以本次纯逻辑对照或单怪准备夹具代替。
