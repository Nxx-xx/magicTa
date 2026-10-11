# 第三阶段集成批次

2026-10-01。五个独立程序模块已交付，用户通知可进入统筹集成。本批重新明确修改权限，覆盖 COORDINATION 中第一批的只读限制。未验收的角色/怪物/遗迹动画不启用，保留正式静态与既有行走。

| 工作流 | 本批独占范围 |
| --- | --- |
| 统筹 | campaign_engine.gd、新局/交易/指标/发现/结算接线、集成交付记录 |
| ① | content_db.gd、rewards.gd、combat.gd 的显式规则分派及专项测试；旧默认语义不变 |
| ② | 新 phase3_campaign_generator.gd、必要地图适配与生成专项测试；不改存档、UI、引擎 |
| ③ | 新 tests/phase3_integration* 生产路线/存读档/战斗联调测试与独立审核；先不改生产文件 |
| ④ | campaign_save.gd、map_save.gd、save_store.gd及必要新验证模块；保存封装v2与旧局兼容；不改引擎 |
| ⑤ | map_screen.gd、campaign_panels.gd、combat_presentation.gd、runtime_art.gd/monster_art.gd/item_icon.gd、必要教程偏好；UI与正式资源接线；不改核心 |

公共接口：

- ContentDB新增 `rules_version:int=1`；v2派生属性/奖励用①，原默认走旧逻辑。Combat.simulate新增可选第四参rules_version=1，v2转③。
- 引擎新增 `is_phase3()`、`start_phase3(seed_text="",challenge_id="p3_c0",start_config_id="default",replay_snapshot={})`，保留start_campaign为旧模式及回归入口。
- `choose_ruin(option_id)`、`ruin_previews(entity)`供②面板；`record_phase3_discoveries(events)`供查看详情/候选等已发生事件。保存失败沿用全局阻断，不能从UI直接写meta。
- 新生成器具有原 config/content_snapshot/errors/last_error、plan(seed)、generate(plan,floor,theme,boss_choice) 接口，另有 `phase3_context`（冻结遗迹/解锁/变体与其他槽唯一预留）。输出 generator_version=2、plan/config.version=2；装饰返回的new_unique_ids写为floor.phase3_new_unique_ids，外层加入reserved_unique_ids。
- 新run字段：phase3_contract_version=1、combat_rules_version=2、reward_rules_version=2、generator_version=2、challenge_id、challenge_snapshot、start_config_snapshot、unlocked_pool_snapshot、progress_rules_snapshot、ruin_definitions_snapshot、variant_plan、reserved_unique_ids、codex_events；原campaign_plan/campaign_rules_snapshot/content冻结保留。
- 消耗后的遗迹保留event实体，status=resolved、selected_option与transaction_id，玩家可回看；不重复领奖。leave不消耗。
- 指标/击杀按INTERFACES与DELIVERY_04：战斗turns/incoming、真实kill healing、商店支出、三遗迹codex_events；old settle前guard，之后evaluate_unlocks，同一保存事务。
- UI默认新入口开启第三阶段；旧存档继续旧流程，同种子重试旧局仍旧规则，新局第三阶段。新局从replay_snapshot冻结整个内容/进度规则/计划，唯一run_id重新分配。

除本批分工文件，不修改其他任务内容。每条工作流交付 INTEGRATION_0N.md，确切列测试、剩余问题与接口差异；共享源码修改前先检查现有未提交改动。

## 统筹续接

②③④⑤集成轮遭遇用量限制后停止，统筹确认其均非运行状态并接管已落盘文件完成修复。当前程序接线和集成检查已完成；美术、人工试玩与高难度全旅程平衡仍按 INTEGRATION_RESULTS.md 单列，不标记完整第三阶段完成。
