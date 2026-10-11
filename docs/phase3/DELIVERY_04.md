# ④ 挑战、解锁与图鉴交付

当前状态：**模块完成待集成**（2026-10-01）。仅覆盖独立模块、数据、徽记、面板和专项夹具，不代表第三阶段已完成。

## 已实现清单

- 三档挑战、四个起点、11 个稳定成就与解锁映射、五种图鉴类目。
- 保留所有旧账户字段的 schema 2 扩展迁移。旧 wins>0 / first_victory 只认可 C0 通关，不补猜治疗、商店、牛头回合。
- 原始属性→起点差值→火种→满血开局。零火种默认/剑士/守灯/行商为 100/10/5/0、100/12/4/0、110/8/6/0、90/10/5/20；金币火种三级的行商为35金币。未知/未解锁选择拒绝。
- C1/C2直接相对基线计算，生命向上取整，输出标记拒绝重复缩放。C2只缩放potion/rest显式治疗，向下取整，正值至少1，0仍为0。
- 局末纯候选、永久run_id防重、结算前保护接口；不发旧灵魂、不增加原runs/wins、不改原records。主动放弃不发新成就，缺证据不猜测。
- 图鉴局中/局末登记、结算后剧情登记与独立事件防重。怪物纪录按敌人/版本/难度分组；缺受伤证据只计击败次数，不伪造零伤。
- 独立挑战/图鉴面板，未知剧情/藏品不泄露名称、效果、图片路径；发现后可看正文与调用方提供的插图。图鉴无音频播放。解锁显现0.15秒徽记+0.25秒文字，最多三条，支持更多折叠、跳过及减少动效。
- 7枚原创SVG母版与128×128 RGBA PNG；难度单环/双环/塔冠，起点提灯/剑盾/弧盾提灯/天平。

## 公开接口

所有纯函数不修改输入、不写盘、不消耗RNG。失败返回`{ok:false,error}`。migrate_meta按冻结协议返回账户副本，之后必须验证；未知版本保留原文但验证拒绝。

| phase3_progress.gd 接口 | 返回/用途 |
| --- | --- |
| `definitions()` | `{challenges:挑战JSON完整根,unlocks:解锁JSON完整根}` 独立副本 |
| `default_extensions()` | 仅新增扩展字段，不替代旧账户 |
| `migrate_meta(meta)` | 加载账户时、旧settle之前迁移 |
| `validate_meta_extensions(meta)` | 验证版本、结构、图鉴计数与防重表 |
| `initial_player(meta,config_id="default",custom={})` | `{ok,error,player}`，从原始基础重新构造 |
| `select_start(meta,challenge_id,config_id,custom={})` | `{ok,error,player,challenge_snapshot,start_config_snapshot,unlocked_pool_snapshot,challenge_rules_version}` |
| `apply_challenge(content,challenge_id,custom={})` | `{ok,error,content}`，输出带phase3_challenge_applied；输入须合并完战役覆盖及新敌人的基线 |
| `scale_heal(amount,source_kind,challenge_id)` | int；合法来源potion/rest/shop/ruin/kill/max_hp/event。非法返回 **-1**，调用方必须阻断交易 |
| `settlement_guard(run,meta)` | `{ok,error,already_settled}`；必须在旧settle之前调用 |
| `evaluate_unlocks(run,meta,custom={})` | `{ok,error,meta,new_unlocks,new_achievements}`；扩展旧候选，同run_id+结果幂等空新增，结果冲突拒绝 |
| `record_discoveries(meta,run_id,events)` | `{ok,error,meta}`；局中或结算后实际剧情登记，不结算、不发成就 |

custom可传definitions()整份冻结字典，避免模拟读取热更新定义。scale_heal是固定challenge_rules_version=1的规则。

- 挑战面板extends VBoxContainer：`setup(meta,custom={})`、`select_ids(challenge,config)`、`show_unlocks(new_achievement_ids,reduced_motion=false)`；信号`selection_changed(selection)`、`start_requested(selection,seed_text)`，不创建局、不保存。显示解锁时用提交后账户setup。
- 图鉴面板extends VBoxContainer：`setup(meta,content,challenge="p3_c0")`、`show_category(category)`；静态`view_rows(meta,content,category,challenge)`可单测。content分类enemies/items/ruins/story，值为ID→定义，字段name/description，可选illustration；剧情支持原lines:[{speaker,text}]。敌人内容必须是**基准快照**，不能传已缩放内容再算一次。

### 精确账户扩展 schema

```text
meta_schema_version: 2
unlock_rules_version: 1
unlocked_ids: Array[String]  # 默认p3_c0/default，配置、池、徽记、纪念页使用稳定ID
achievement_ids: Array[String]
achievement_records: {achievement_id: {run_id:String,completed_at:String,source:"run"|"legacy_account"}}
phase3_settled_runs: {run_id: "death"|"victory"|"abandoned"}
phase3_codex_events: {run_id: {event_id: 原事件Dictionary}}
codex: {
  seen_enemies:Array[String], seen_items:Array[String], obtained_items:Array[String],
  seen_ruins:Array[String], seen_story_nodes:Array[String],
  enemy_records: {
    "enemy_id|combat_rules_version|challenge_id": {
      enemy_id:String,combat_rules_version:int,challenge_id:String,
      count:int,samples:int,min_incoming:int|null
    }
  },
  item_records: {item_id:{count:int,sources:Array[String]}},
  ruin_records: {ruin_id:{count:int,options:Array[String]}}
}
```

count为击败次数；samples为有实际incoming的样本数；无样本min_incoming=null。日期从冻结run.completed_at字符串读取，缺失留空，不编造旧日期。数值为有限非负整数；火种0～3。

两张防重表和图鉴累计不能随最近30局裁剪，必须和主/备份同事务保存。携带ledger的JSON备份恢复已验证。人为恢复到从未包含某次结算的更早整包历史时，纯离线模块无法得知被回滚的未来交易，保存层需定义备份恢复策略。

### run输入与事件证据

- run_id唯一，result必须death/victory/abandoned；新规则要求mode=tower_campaign_v1、campaign_kind=tower_10f、combat_rules_version=2、reward_rules_version=2。旧局不发新指标成就，未知规则版本拒绝。
- challenge_id或challenge_snapshot.id；零火种必须明确start_config_snapshot.id=default及meta_snapshot.upgrades.{hp,attack,gold}=0，缺失不视为零。
- 金币读取player.gold，最高层取highest_floor/floor/floors有效最高值。
- defeated_entities沿用id/enemy_id/rank/floor，建议从③完整战报追加turns/incoming。牛头必须minotaur/boss/5，同实体不得重复；只有获胜才能追加。
- metrics.actual_kill_healing累计真实击杀恢复；shop_gold_spent只统计成功商店实付。midboss_turns/lowest_elite_incoming还要求对应击杀证据，不能用总治疗/总消费/战后净损失代替。
- metrics.ruin_choices按冻结接口保留entity_id→option_id；该结构没有稳定遗迹ID，三遗迹成就明确使用ruin_choice事件，不解析entity_id猜遗迹类型。

run.codex_events及record_discoveries事件格式：

```gdscript
{"event_id":"f2:inspect:slime","kind":"enemy_seen","id":"slime"}
{"event_id":"f3:offer:iron_sword","kind":"item_seen","id":"iron_sword"}
{"event_id":"f3:buy:iron_sword","kind":"item_obtained","id":"iron_sword","source":"shop"}
{"event_id":"f2:ruin:inspect","kind":"ruin_seen","id":"p3_oath_ruin"}
{"event_id":"f2:ruin:consume","kind":"ruin_choice","id":"p3_oath_ruin","option_id":"edge"}
{"event_id":"story:victory:finished","kind":"story_seen","id":"victory","triggered":true,"status":"completed"}
```

story状态也支持skipped；仅排入剧情队列不算实际到达。event_id同局稳定，同ID相同事件幂等，冲突拒绝；不同取得机会需不同ID。leave只登记看见，不计遗迹使用。合法遗迹选项按02设计验证。保存失败丢弃候选，不提前改内存账户或展示解锁。

### 统筹调用顺序

```gdscript
# 加载账户时先迁移验证，随版本化保存封装提交。
var account = P3.migrate_meta(loaded_meta)
assert(P3.validate_meta_extensions(account).ok)
# 新局：先合并战役覆盖/新敌人，再应用挑战一次并冻结所有返回快照。
var selected = P3.select_start(account, challenge_id, config_id, frozen_progress_defs)
var scaled = P3.apply_challenge(baseline_content, challenge_id, frozen_progress_defs)
# selected.player直接作为初始玩家，不能再调用旧initial_player叠加火种。

var ending = run.duplicate(true)
ending.result = result
var guard = P3.settlement_guard(ending, account)
# guard.ok=false阻断；already_settled=true返回已提交结果，绝不能再调用Old.settle。
var old_candidate = Old.settle(ending, account, result)
var extension = P3.evaluate_unlocks(old_candidate.state, old_candidate.meta, frozen_progress_defs)
# 各步都检查ok；一次write(old_candidate.state,extension.meta)，成功才展示新增。

# 结算后实际观看/跳过剧情：同事务提交story状态及账户候选。
var discovered = P3.record_discoveries(committed_meta, run.run_id, story_events)
```

以上是顺序示意，各步必须检查ok。永久键前置检查是必要接入项：旧模块只检查最近30局和最后结算键，先让旧模块重发货币后，扩展不能凭空撤销。真实旧settle组合及完整重复调用已有专项测试。

## 修改文件

- data/phase3_challenges.json、data/phase3_unlocks.json
- scripts/core/phase3_progress.gd
- scripts/ui/phase3_challenge_panel.gd、scripts/ui/phase3_codex_panel.gd
- assets/ui/phase3/progression/：7 SVG、7 PNG、SOURCES.md
- tests/phase3_progress_assets.gd、phase3_progress_test_runner.gd、phase3_progress_preview.gd、phase3_progress_verify.ps1
- 本文件。未修改既有共享入口，未提交/推送/重置，未全工程导入或导出。

## 测试命令与实际结果

```powershell
powershell -ExecutionPolicy Bypass -File tests/phase3_progress_verify.ps1 -Capture
```

Godot godot，实际版本4.7.2.stable.official.ed1daf0bf。脚本隔离APPDATA/LOCALAPPDATA至build/verification/phase3/04-progress/appdata|localappdata，finally恢复环境变量，不读玩家存档。

最终结果：**413 checks / 0 failures**；实际OpenGL预览 **5 captures / 0 failures**；退出码0，无GDScript/解析/编译错误。环境固定打印Failed to read the root certificate store，未影响本地逻辑与OpenGL截图，不将此行隐藏或写成零引擎日志。

覆盖：19/20治疗、29/30商店、99/100金币及四层不达标、牛头6/7回合、精英10/11原始伤害、放弃全门槛不发解锁、缺证据、重复/冲突结算、30局裁剪前置防重、JSON备份往返、旧meta迁移、所有旧字段保持、四起点零/满火种、未知/未解锁选择、C0/C1/C2非叠乘及取整、来源治疗、输入不变、图鉴跨难度隔离/缺样本、事件防重、局中/局末不重计、结算后剧情、未知剧情遮蔽、非法数值/字段/版本、PNG尺寸格式透明。

证据目录build/verification/phase3/04-progress：assets.log、logic.log、preview.log；challenge-desktop.png、challenge-mobile.png、codex-enemies-mobile.png、codex-story-redacted.png、badges-contact-sheet.png。

## 图/动画来源与实显检查

assets/ui/phase3/progression/SOURCES.md记录原创路径和生产流程。沿用代码绘制图标系统，适合可编辑矢量母版，无生成位图技能依赖。Godot512px光栅化后缩至128px RGBA。七枚徽记实际检查96/48/32px轮廓；手机540×960属性、C2规则和解锁折叠无裁切。早期联络表受窗口缩放影响裁切，已修正独立预览缩放并重新截图。

这是静态徽记，面板仅显现动画，不冒充逐帧角色动画。运行时优先ResourceLoader，未导入预览用原始PNG回退；正式导入/导出资源包含检查交统筹串行进行。

## 统筹接入需求

- 保存封装/schema2版本分派、迁移与严格扩展校验；永久防重表随主/备份保存。冻结progress定义/快照，重试分配新run_id。
- 旧settle前接settlement_guard，候选后接evaluate_unlocks，同事务写盘；不在演出回调发奖。
- 生产战斗保存原始incoming/turns/min_hp/真实击杀治疗；商店实付及遗迹事件接入。首领战后固定恢复不能算击杀治疗。
- 营地新入口、图鉴基准内容、查看详情/候选展示发现事件、剧情完成回调待接。图鉴面板只读，调用方事务保存发现。
- C2地图药剂/rest显式heal接scale_heal，max_hp自动恢复不缩放；UI显示实际数值。此模块不自动全局改内容。
- unlocked_pool_snapshot只作用于未来新局，不替换本局content、商店或已访问楼层。三遗迹成就需明确稳定事件。
- 新资源由统筹串行导入及打包检查，本组未运行全项目import。

## 未完成内容

UN-10四起点生产整塔零火种参考路线、C1/C2通关、全UI数值接线、100种子、手机真机触控与真人平衡仍待集成验收。本次专项夹具不冒充完整旅程证据，也未开放主游戏C2入口。

本组独立实现、专项测试和可运行预览已交付，共享接线和整阶段完成判定由统筹负责。
