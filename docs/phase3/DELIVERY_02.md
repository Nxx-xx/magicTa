# ② 地图与遗迹交付

当前状态：**模块完成待集成**（2026-10-01）。逻辑、数据、专项验证、可运行几何/面板与草稿预览已交付；正式动画验收仍未完成。只写②专属新增文件；没有改旧生成器/引擎/存档/公共入口，没有提交、推送、重置或新建聊天/子代理。

## 已实现清单

- 三遗迹数据、选项转奖励、只读面板和预览适配已写入；实际交易调用① `phase3_items.resolve`。
- 生产安全槽变换、2/6主题两候选、唯一预留/解锁回填、可选变体计划、机会与直接效果账本已写入。
- 新四支路加独立遗迹支路样板支持八向旋转/镜像；不能完整容纳实体则回退原几何。
- 只读回溯提示消费已计算战报，不更新原比较基准、不暴露未发现目标。
- 纯交易候选适配返回玩家/耗尽实体/稳定交易键/选择指标；未提交输入不扣费，已耗尽拒绝再次获益。此接口不写存档。
- 生产 seed 0–199 的 12,000 个楼层变换已通过；三套环境图集草稿与可运行审阅预览已交付，全部美术仍未通过生产动画验收。

## 公开接口

### 遗迹规则

```gdscript
const Ruins = preload("res://scripts/core/phase3_ruins.gd")
const Items = preload("res://scripts/core/phase3_items.gd")
var frozen_ruins = Ruins.definitions() # 开局冻结；后续传快照
content.events.merge(Ruins.event_definitions(frozen_ruins), true)
var reward = Ruins.reward_for_option(ruin_id, option_id, frozen_ruins)
# reward: {ok,error,reward,consumes,requires_healing}
var previews = Ruins.preview_options(ruin_id, player, content,
    Callable(Items, "resolve"), frozen_ruins)
# previews.options[option_id] 与 Items.resolve 结果兼容；leave 无交易数值。
```

另有 `validate_definitions(defs)`、`direct_effect_budget(defs)`。定义校验拒绝未知/重复选项、未知效果、负数/非整数/非有限成本、收费离开等。

可选事务候选入口：

```gdscript
var candidate = Ruins.prepare_resolution(ruin_id, option_id, entity,
    content, player, Callable(Items, "resolve"), run_id, frozen_ruins)
# 成功获益返回 player, ruin_state, reward_result, metric_choice, consumes=true。
# entity 支持既有 id 或 entity_id，要求 ruin_id/rules_version/status。
# 交易键 = run_id + ":" + entity_id + ":resolve"。
# 主事务一次保存 player、ruin_state 与 metrics.ruin_choices 的更新。
```

leave 返回输入副本与 consumes=false，不执行奖励或改变指标。主引擎确认时重新读取当前实体/玩家，再调用本函数；保存成功后才提交候选。函数重新检查费用与满血治疗，拒绝耗尽状态、冲突记录与未知已选项；它不代替写盘/回滚。

`marked_target_hint(mark,current_report)` 输入 mark 为 `{discovered,entity_id,floor,previous_report}`，两战报至少含 `won:bool`。未发现目标返回 `show_hint:false` 且不返回身份/战报。已发现目标仅在原不可存活→现可存活时返回提示；不改标记基准。提示去重和主动重新标记由主导航入口维护。

### 地图变换

```gdscript
const Recipe = preload("res://scripts/core/phase3_map_recipe.gd")
var decorated = Recipe.decorate_floor(fresh_floor, content, {
    "freshly_generated":true, "floor":number, "theme":chosen_theme,
    "unlocked_ids":frozen_unlocks,
    "used_unique_ids":reserved_in_other_slots,
    "variant_plan":{"3":"p3_shield_sentinel", "6":"p3_ember_channeler",
        "8":"p3_vault_knight"},
    "ruin_definitions":frozen_ruins,
    "geometry":"existing", # 可选 "ruin_spokes"
    "orientation":0 # 0..7，仅新样板使用
})
```

`freshly_generated=true` 是额外显式保护，不替代外层版本分派。模块拒绝已装饰、visited、已消费或有遗迹持久状态的地图；floor/theme 必须匹配。Boss 主题传生产值 `boss`。

返回 `{ok,error,floor_map,new_unique_ids,report}`。失败不返回可提交楼层。`used_unique_ids` 表示**其他槽**预留，不应包含本槽；统筹将返回的 new_unique_ids 原子纳入全塔表。

`variant_plan` 为完整开局冻结字典，可为空，楼层键必须为字符串；三类允许层依次是3/4、6/7、8/9，全塔同变体最多一处。只匹配生产支路第3/4条的 `role=campaign_branch` 原守卫。蓄焰变体匹配第4支路 warlock，另两种匹配第3支路 sentinel/knight；无匹配槽时记录 skip，不额外加怪。变体须已存在 content。

`floor_map.phase3_recipe` 保存模块 version=1、报告、机会数和直接效果上界；**不是 generator_version**。原生成版本由统筹外层 v2 分派处理。`opportunity_counts(map,content)` 计算全候选实际分类；第2层原装备/遗物组合替换为两遗物后仍满足本层上限。

新 `ruin_spokes` 为四条奖励支路＋独立遗迹支路，不是照抄只能容纳三分支的规划图。完整搬迁实体、安全槽、守卫和楼梯；八向变换后重新检查，摆不下则回退原几何并保留全部实体。

### 面板

实例化 `phase3_ruin_panel.gd`，调用 `present(ruin_definition,previews.options,state={},comparisons={})`。只发 `option_selected(option_id)`、`leave_requested`。比较项为 `{option_id:{discovered:true,text:"调用方已计算的战损比较"}}`；未发现项不显示。

## 修改文件

- `data/phase3_ruins.json`
- `scripts/core/phase3_ruins.gd`、`scripts/core/phase3_map_recipe.gd`
- `scripts/ui/phase3_ruin_panel.gd`
- `tests/phase3_ruins_test_runner.gd`、`tests/phase3_ruins_preview.gd`、`tests/phase3_ruins_verify.ps1`
- `assets/environment/ruins/phase3/`：三张 draft PNG、manifest、提示词、来源记录
- `docs/phase3/DELIVERY_02.md`
- 证据：`build/verification/phase3/02-ruins/`。

## 测试命令与实际结果

```powershell
pwsh -NoProfile -File tests/phase3_ruins_verify.ps1
pwsh -NoProfile -File tests/phase3_ruins_verify.ps1 -Capture
pwsh -NoProfile -File tests/phase3_ruins_verify.ps1 -Preview # 手动交互审阅
```

脚本使用指定 Godot 4.7.2，将 APPDATA/LOCALAPPDATA 隔离至证据子目录，并在 finally 恢复进程环境；不调用玩家存档接口。

- 最终实际结果：**12,000 个生产楼层变换、73,267 项检查、0 失败，退出码0**，包含追加的纯事务候选/冲突状态检查。
- seed **0–99 与100–199**，三主题、原/新几何两模式、八方向；六原普通模板与两Boss模板均覆盖。
- 固定军械/其守卫、Boss/奖励语义不变；实体数守恒；生产校验器的安全楼梯、同色钥匙安全可达与守卫不可绕均通过。模块额外逐个隔离守卫，检查其确为对应奖励割点。
- 每塔装备机会≤14、遗物机会≤17、商人=2、休息=2、事件=3。三类变体各出现400次，均来自合法主题槽。
- ①真实交易边界：R1 HP12/13、金币14/15；R2基础上限10/11、满血/缺血截断、装备上限保留且不能代付基础上限；R3满血禁用与有效治疗/溢出。输入和全局RNG不变。
- 直接效果互斥选项逐字段上界：HP成本24、基础上限成本10、金币成本40、攻击6、防御3、金币收益53、治疗35；不能当作可同时领取的奖励包。
- 面板：不足选项可读禁用、免费离开、信号、已耗尽只读、320宽出口可见；六张实显截图已生成，长说明在内部滚动。
- 环境日志有 Windows 根证书存储读取警告，测试与OpenGL截图退出0；本任务没有网络请求，不将此警告误报为玩法失败。

证据包含 `results.json`、`tests.log`、`preview.log`。纯候选丢弃/同键重试仅验证输入不扣费与幂等状态拒绝，**不是实际保存失败、跨层读档或旅程通过证明**。

## 图/动画来源与实显检查

使用 imagegen 内置工具分别生成三图集并复制到独占工作区目录；提示词与原始文件名见 `assets/environment/ruins/phase3/PROMPTS.md`、`SOURCES.md`。

实际 Godot 预览支持 idle/resolve/spent、暂停与逐帧，展示256px/48px。通过原始PNG读取，不需要全项目导入。三张宽屏和三张320宽截图，以及 `atlas-audit.json` 已输出。

35个拟定帧位区域哈希均不同且有alpha；此结果**不能证明动画验收**。R1/R3为362px方格源图，R2为不能整除的近似网格；底座/锚点均有漂移，R3治疗/防御标记必须按选项拆分。缺512分层母版、合格256运行帧及单格/1.2格光晕遮挡验收。manifest 为 `draft_not_accepted`、`gameplay_enabled=false`。没有静态形变冒充已完成动画。

## 统筹接入需求

1. 仅新第三阶段：生产生成→本模块装饰→主事务保存。旧两层、旧十层与已访问层不调用。冻结遗迹定义/内容/解锁/变体计划/唯一预留，不热替换旧快照。
2. 合入事件字典；免费离开不耗尽、已耗尽不再获益、满血恢复禁用。建议用 prepare_resolution，外层一次保存玩家/地图实体/metrics.ruin_choices，成功后才演出。
3. v2存档校验允许新遗迹ID/选项/状态/交易键与phase3_recipe；规则/预算校验支持两新候选和新模板字符串。保持既有固定军械和Boss门槛。
4. 先接 `geometry=existing`；跨层楼梯验证后再启用 `ruin_spokes`。旋转后entry/exit必须从地图读取，不假定固定(5,9)/(5,1)。Boss从不旋转。
5. 变体生成测试只使用身份/名称协议夹具；不复制③战斗公式。正式content需合入③定义再做整塔平衡。交易已使用①实际实现。
6. 正式地图暂沿用既有事件表达，draft atlas只作审阅。资源导入/导出由统筹串行处理；不把草稿启用为正式动画。

## 未完成内容

- 主游戏接线、存档v2/失败回滚/跨层返回、导航提示去重属于统筹共享入口。
- 事件削弱后的前五层/整塔参考路线须经生产移动、奖励、战斗、保存联调；多种子几何通过**不是可通或平衡证明**。未开展多人试玩。
- 正式环境35帧验收、512分层母版、256运行帧、回溯标记2帧未完成；三套真实生成草稿与审阅工具已交付。
- 新几何仅验证生成状态；主旅程旋转楼梯坐标适配待集成。不声称第三阶段整体完成。
