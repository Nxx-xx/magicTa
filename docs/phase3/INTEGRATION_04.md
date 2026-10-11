# ④ 存档封装集成交付

> 统筹续接更新（2026-10-01）：本聊天的集成轮因用量限制中断，以下“进行中”为当时记录。统筹已完成程序接线与验证，实际结果、截图和剩余美术范围见 [INTEGRATION_RESULTS.md](INTEGRATION_RESULTS.md)。

当前状态：**模块完成待集成**（2026-10-01）。本批存档代码已接入当前共享工程，并以真实 start_phase3/choose_ruin/settle/retry_save 验证。全工程集成与整阶段完成仍由统筹判定。

## 已实现

- CampaignSave保持new(path)、read()/write(run,meta)接口。写入封装version=2，读取封装1/2；旧两层/十层run不改版本、内容、计划或战斗规则。
- SaveStore新增可覆盖_envelope_version()，默认仍1，CampaignSave返回2。原.tmp写入/flush、备份轮换、坏主档保留.corrupt副本、原platform_persistence.flush()均保留。
- 读取旧账户后只迁移meta扩展；写入前验证原账户，再迁移候选、验证完整v2封装后保存。不就地修改调用方run/meta。已有schema2缺字段/坏类型不通过migrate默默修补。
- Contract.classify/validate_snapshots明确分派新旧规则。v1封装不能伪装新规则；试炼不能带第三阶段标记或新战斗/奖励版本；未知主版本拒绝，读取时仍可回退有效备份。
- MapSave公共结构、坐标、玩家生命、设施、旧奖励校验保留；新路径传rules_version=2到专用phase3_save_validation。没有剥掉新字段再无条件调用旧验证。
- phase3_save_validation验证：冻结progress/挑战/起点/遗迹定义、profile与解锁池、生成器plan/config、内容挑战标记、唯一遗物持有与预留/候选、防重表、图鉴事件、扩展metrics、伤害和回合击杀证据。
- 新物品效果、条件效果、负费用/最大生命费用、新敌人能力、战报逐回合数值与effect_events/effects_triggered一致性、实际incoming/min_hp、胜负和反击次数均验证。
- 楼层phase3_recipe、机会预算、模板/支路、变体计划、phase3_new_unique_ids、phase3_healing和potion/rest.phase3_heal_base交叉验证。C1/C2敌人覆盖按冻结挑战换算验证；治疗只能从原显式量缩放一次。
- resolved遗迹保留实体，校验稳定遗迹ID/楼层、合法非leave选项、transaction_id=`run_id:entity_id:resolve`、metrics.ruin_choices与已发生事件一致，不接受可用状态携带旧交易记录。
- 局末run.result必须与永久phase3_settled_runs一致；进行中run不能已有永久结算键。既有灵魂/火种退款/记录数量等旧账户约束继续执行。
- 修正原本组phase3_progress迁移的一行：旧通关成就键使用字符串下标，不用点赋值形成StringName；真实旧通关账户现在能迁移、通过严格校验并落盘。

## 修改文件

- scripts/core/campaign_save.gd
- scripts/core/map_save.gd
- scripts/core/save_store.gd（保留已有微信持久化改动）
- 新 scripts/core/phase3_save_validation.gd
- scripts/core/phase3_progress.gd：上述迁移键单行修复
- 新 tests/phase3_progress_save_test.gd、tests/phase3_progress_save_verify.ps1
- 本文件。未改campaign_engine、地图生成器或UI；未提交、推送、重置或执行导入/导出。

统筹同期补入的Contract.same_json调用已保留，用于JSON整数/浮点往返的冻结树比较；重复的治疗校验块已整理。新验证模块仍由本组维护。

## 接口注意

- CampaignSave.read返回的旧run保持原规则，meta会新增schema2字段；返回envelope.version保留实际读取的封装版本，下一次write写2。
- CampaignSave.write不会改变调用方账户；旧测试若逐字典比较读回meta与迁移前meta，需改为比较migrate_meta(original_meta)或逐个原字段。
- _valid_plan/_valid_campaign_rules保留默认rules_version=1供旧新局预检；可选第三/第四参数传2。完整新局应直接使用_valid({version:2,run,meta})，当前root已如此接线。
- 不同难度的enemy_overrides与已缩放content一致性按冻结challenge_snapshot计算，不能再把golem.attack=28与C1/C2最终攻击直接比较。
- 新floor必须包含phase3_recipe、phase3_new_unique_ids与phase3_healing；普通层必须四支路，potion/rest显式heal必须携带原量。当前②生产生成器输出满足。
- 成就记录source=run须有对应永久结算键；legacy_account只用于p3_c0_clear。对旧局内容不新增击杀证据要求；第三阶段defeated_entities要求turns/incoming。

## 实际验证

```powershell
powershell -ExecutionPolicy Bypass -File tests/phase3_progress_save_verify.ps1
```

Godot 4.7.2.stable.official.ed1daf0bf，APPDATA/LOCALAPPDATA隔离至build/verification/phase3/04-progress/appdata及localappdata。测试仅在该隔离user目录创建按进程ID划分的fixture，保留证据，不使用玩家存档。无全工程import/export。

| 测试 | 实际结果 |
| --- | --- |
| phase3_progress_save_test | **225 checks / 0 failures** |
| campaign_integration_edge_runner | **25 checks / 0 failures** |
| keys_test_runner | **954 checks / 0 failures** |
| map_test_runner | **274 checks / 0 failures** |
| 原本组phase3_progress_test_runner（迁移修复后） | **413 checks / 0 failures** |

保存专项覆盖：真实C0/C1/C2新局与前四层存读盘；真实choose_ruin消费后实体保留；新战报；错误版本/深层坏类型；唯一物品、未知效果/敌人、负费用、挑战/治疗篡改；非法写入不改主/备份原字节；坏JSON主档恢复整包备份；未知版本主档回退；主备都坏拒绝且保留文件；恢复后再保存；真实缺目录写盘失败与重试；真实引擎新局/局末IO失败回滚内存与重复重试；旧v1十层、旧两层空meta、可信旧胜利账户迁移。

最新日志：build/verification/phase3/04-progress/phase3_progress_save_test.log、campaign_integration_edge_runner.log、keys_test_runner.log、map_test_runner.log、logic.log。

最终保存专项无SCRIPT ERROR/Parse Error/Compile Error，进程退出码0。环境仍打印Failed to read the root certificate store，不影响本地存盘。原413测试直接读徽记源图时出现Godot导出提示，来自测试源码图片检查，非保存代码；生产UI已有ResourceLoader优先路径。

## 剩余事项/明确边界

1. 原campaign_story_test_runner曾运行71项，**1项旧断言不再适用**：第141行Equal.equal(recovered.meta,core.meta)期望meta不新增字段。实际读回现为schema2扩展，原字段均由新225项中的逐字段测试验证保持。未在本批越权修改该旧测试；统筹需将预期更新为迁移后账户，再纳入完整回归。不能把这次71项称为全过。
2. 100种子完整生产旅程、所有Boss结算和手机交互等由③/统筹集成验收，本组不以保存夹具冒充整塔路线。
3. 本地真实IO失败已验证；微信平台bridge.flush的设备行为沿用原实现，此批未做微信真机验收。保存层未增加外部防回滚服务：人为恢复早于某次交易的整包历史无法得知未来交易，永久键随完整主/备份保留。
4. 运行时永久防重仍须由引擎在旧settle前guard、后evaluate_unlocks；本组验证结果和ledger一致性，不替代引擎结算。当前root已有此接线。

状态保持“模块完成待集成”，不宣称第三阶段整体完成。
