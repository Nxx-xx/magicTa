# 第三阶段公共接口 v1

2026-10-01，统筹冻结的第一批协议。本文优先于设计稿中的示例文件名和未固定接口；不改变设计稿的玩法数值。只有统筹修改本文。开发模块必须可独立加载和测试，不要求主游戏先完成接入。

## 1. 共通规范

- 模块采用 `extends RefCounted` 与 `static func` 为主，不注册新的全局 class_name，减少并行导入依赖。
- 所有纯函数不改变输入 Dictionary/Array，不写存档，不消耗全局随机数，不操作UI。错误返回 `{ok:false,error:String}`；成功返回 `{ok:true,error:"",...}`。
- JSON顶层含 `version:1` 和对应分类键（`items`、`ruins`、`enemies`、`challenges`、`unlocks`）。稳定 ID 使用设计稿中的 `p3_*`。
- `content` 参数指完整内容字典，结构沿用原 `enemies/items/events/shop`，不是 ContentDB 对象。模块可直接载入自己的JSON，但运行入口使用已冻结定义；公开函数提供可传入定义的方式，不在模拟中偷偷读取最新全局数据。
- 玩家字段继续为 `hp,max_hp,attack,defense,gold,keys,silver_keys,gold_keys,equipment_ids,relic_ids`。上限增益的装备不写入基础属性。
- 数值为有限整数，实际范围由模块校验；不能接受负价格、NaN、错误类型、未知效果或无限循环配置。

## 2. ①物品模块 `phase3_items.gd`

公开函数至少提供：

```text
definitions() -> Dictionary                          # 载入文件的 items 字典副本
merge_content(content, item_definitions={}) -> Dictionary  # 完整内容副本；空定义使用本模块默认
player_stats(player, content) -> Dictionary          # 下述 stats；兼容全部旧效果
resolve(content, player, reward) -> Dictionary      # 与旧 RewardRules.resolve 返回字段兼容
validate_definitions(item_definitions) -> Dictionary # ok/error
```

`resolve` 返回 `player,before,after,healing,overflow,attack_delta,defense_delta,max_hp_delta,hp_delta,gold_delta`。支持原有 cost/effects/item_id，以及新增 `cost.max_hp`：扣基础上限、当前HP按新派生上限截断、不治疗，基础上限必须≥1。新唯一遗物重复交易拒绝且不扣费。①统一实现此交易，②只生成其输入。

`player_stats` 保留 `attack,defense,max_hp,kill_heal,gold_bonus`，新增 `combat_effects:Array[Dictionary]`。鎏金灯芯在此根据战前金币≥100为防御加2，同时输出来源说明；不在战斗中再加一次。静态无灯芯时应与旧 ContentDB 数值一致。

五种战斗效果协议（每种新遗物最多一件）：

| 遗物 | combat_effects条目 |
| --- | --- |
| 破晓剑印 | `{id:"first_hit_bonus",amount:4,source_item_id:"p3_dawn_sigil"}` |
| 提灯护符 | `{id:"counter_guard",amount:2,charges:2,source_item_id:"p3_lantern_aegis"}` |
| 赏金账簿 | `{id:"rank_gold_bonus",elite:10,boss:20,source_item_id:"p3_bounty_ledger"}` |
| 三拍剑穗 | `{id:"periodic_hit_bonus",amount:3,interval:3,source_item_id:"p3_rhythm_blade"}` |
| 荆棘扣 | `{id:"retaliation",amount:2,charges:3,source_item_id:"p3_thorn_clasp"}` |

鎏金灯芯可在物品定义存条件静态效果，但不能将未协定ID塞入上述combat_effects。来源/显示辅助字段另放 `effect_sources`，③不能凭此重复加属性。

## 3. ③战斗与敌人模块

`phase3_combat.gd`：`simulate(player,enemy,stats)->Dictionary`。返回全部旧战报字段，增加 `ok,error,combat_rules_version:2,min_hp,effects_triggered`。无新机制时与旧引擎既有伤害及奖励一致。未知效果/技能拒绝，返回错误而不是静默无效果。

每回合保留 `turn,hit,enemy_hp,counter,hp,note`；`enemy_hp`保留玩家攻击后生命，增加 `enemy_hp_after_counter,retaliation_damage,guard_reduction,effect_events`。effect_events条目为 `{id,source_item_id,amount}`，敌方事件可用 `source_enemy_id`。`amount`为实际效果数值，触发但零收益仍可记录0。完整战报 `effects_triggered` 建议为同类事件数组，标注turn；⑤不要假设是自由文本。

模拟时序严格遵守03第3节。min_hp是战中、战后治疗前最低HP；反伤死亡无下一次玩家攻击。保留旧 `log.size()==turns` 语义。

敌人能力ID：`p3_shield`（前两次被击减3最低1）、`p3_ember`（第三/六…次反击加5）、`p3_ambush`（首次反击加4）。原空字符串/rage/stone_armor继续支持。

`phase3_enemies.gd` 至少提供 `definitions()->Dictionary`、`merge_content(content,enemy_definitions={})->Dictionary`、`validate_definitions(definitions)->Dictionary`。十层魔像attack=28仍由原战役覆盖设置，不能在旧基础表全局改28。

## 4. ②遗迹与地图模块

`phase3_ruins.gd` 至少提供：

```text
definitions() -> Dictionary
event_definitions(ruin_definitions={}) -> Dictionary   # 转为原事件结构name/description/options
reward_for_option(ruin_id, option_id, ruin_definitions={}) -> Dictionary # {ok,error,reward,consumes}
validate_definitions(ruin_definitions) -> Dictionary
```

R1/R2/R3 ID固定 `p3_oath_ruin`、`p3_oath_forge`、`p3_lantern_sanctuary`；选项ID沿用02表格。leave返回 `consumes:false`、空reward；其他返回原 RewardRules 格式（包括 R2 `cost.max_hp:10`）。不要在②复制①的物品和派生属性公式。专用面板通过传入已计算的选项预览显示成本/收益，发 `option_selected(option_id)`、`leave_requested`，不写状态。

`phase3_map_recipe.gd` 提供纯变换函数 `decorate_floor(floor_map, content, context)->Dictionary {ok,error,floor_map}`，只接收“刚生成、尚未提交”的楼层副本。context至少含 `floor,theme,unlocked_ids,used_unique_ids,variant_plan`。替换2/6/9原事件，替换2/6主题候选，按03合法支路计划替换变体。不得向旧已访问楼层补奖励，不修改固定军械和Boss门槛。具体守卫关系须从现有生成器字段读取。

如新模板尚不足以保持全部不变量，首批在既有安全槽上实现遗迹与候选替换，明确记录新几何仍待完成，不用删实体“修复”预算。

## 5. ④挑战与解锁模块

`phase3_progress.gd` 至少提供：

```text
default_extensions() -> Dictionary
migrate_meta(meta) -> Dictionary                     # 保留原字段的副本
initial_player(meta, config_id="default") -> Dictionary # {ok,error,player}
apply_challenge(content, challenge_id) -> Dictionary  # {ok,error,content}，敌人缩放
scale_heal(amount, source_kind, challenge_id) -> int  # only potion/rest in C2
evaluate_unlocks(run, meta) -> Dictionary             # {ok,error,meta,new_unlocks,new_achievements}
validate_meta_extensions(meta) -> Dictionary
```

挑战ID `p3_c0/p3_c1/p3_c2`、配置ID `default/p3_vanguard/p3_keeper/p3_trader`。敌人缩放应在合并十层覆盖和新敌人后执行一次；apply_challenge输入基线，输出不就地修改。

evaluate_unlocks只处理新解锁、图鉴/计数，不重复发放旧灵魂或增加原runs/wins。它由统筹在旧Progress.settle产生的候选上调用并同事务提交；输入run含真实result、metrics和击杀证据，缺乏数据不推测成就。主动放弃不得发新解锁。已发成就稳定ID幂等。

新增metrics约定：`actual_kill_healing,shop_gold_spent,min_hp_in_combat,ruin_choices,effect_counts,effect_actual_values,midboss_turns,lowest_elite_incoming`，前两个数值累计，后两个缺失表示无证据；ruin_choices为entity_id到option_id的字典。图鉴字段沿用04，精确 schema 在④交付报告中列出。

## 6. ⑤教学与动画模块

`phase3_tutorial.gd` 提供无UI依赖的状态/事件接口及独立可实例化提示组件。`phase3_animation_catalog.gd` 读取manifest并校验动作；`phase3_combat_player.gd`只读取③战报、选择演出节点、提供跳过/减动效，不调用奖励、保存或模拟器。

演出消费03兼容字段与effect_events；不要改③输出定义。主角新资源仅在hero/phase3，角色右剑左灯。既有hero_walk（网格形变行走）保留，真实帧动作通过独立预览确认后由统筹决定替换。新模型/帧必须有来源和验收，未达标标记草稿。

## 7. 版本接入责任

统筹负责保存封装v2、meta schema2、generator2、combat2、reward2的逐项分派。开发模块不全局改旧版本常量，不改现有启动默认行为。第一批新模块先由专项测试/预览运行，待模块交付再接入主游戏；没有接线不等于模块可以只写空壳。

统筹模块 `phase3_contract.gd` 提供只读版本/配置校验，不会自动切换主游戏。新run新增 `phase3_contract_version:1`，缺失它的旧局继续旧分支；有新版本字段却缺标记时拒绝静默回退。`challenge_snapshot` 与 `start_config_snapshot` 均包含 `version:1,id:<稳定ID>`，`unlocked_pool_snapshot`为字符串数组。版本校验只负责分派，完整内容/地图/事务校验仍由后续存档接入完成。
