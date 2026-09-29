# 第二阶段实现接口与文件归属

状态：2026-09-29 开发中。三执行线程共享工作目录，各自只编辑归属文件；统筹负责集成修复与最终验收。现有两层接口和回归必须继续通过。

## 文件归属

- 地图玩法：新增 `campaign_engine.gd`（继承 `map_engine.gd`）、`campaign_generator.gd`、`campaign_validator.gd`、`data/campaign_rules.json`、`tests/campaign_test_runner.gd`。可调整原引擎以提取必要扩展点，但优先使用子类。
- 剧情成长：新增 `campaign_progress.gd`、`story_state.gd`、`campaign_save.gd`、`data/story.json`、对应测试；负责 `map_save.gd` / `save_store.gd` 的兼容与校验。不要编辑地图引擎和 UI。
- 界面表现：`map_screen.gd`、`grid_board.gd`、新增 UI 组件与界面测试，已有静态素材接入；不要编辑核心。
- 统筹：检查工具、整合测试、导出与文档；共享接口变化先通知有关线程。

## 核心约定

UI 改用 `campaign_engine.gd`，其继承旧地图引擎，保留 `start(seed_text, random_maps)` 两层行为。新增 `start_campaign(seed_text="") -> String`；错误返回非空字符串。

新增 `is_campaign() -> bool`；正式状态 `mode="tower_campaign_v1"`、`campaign_kind="tower_10f"`、`run_id`，楼层 1～10。试炼保持旧字段语义。引擎公开 `meta: Dictionary`，两种模式共用带 `run` / `meta` 的地图封装。

引擎新增 `story_event() -> Dictionary`（空字典表示无演出）、`acknowledge_story() -> void`、`purchase_upgrade(kind: String) -> String`、`reset_upgrades() -> String`、`abandon_run() -> String`、`retry_save() -> bool`。升级 kind 为 `hp` / `attack` / `gold`。保存待提交状态由 `transaction_pending: bool` 暴露；为 true 时禁止开始新局及玩法动作，仅允许重试保存或退出。

`state.story = {queue: Array[Dictionary], seen: Array[String]}`；队列元素形如 `{id, title, lines: [{speaker,text}], audio_cue}`。UI 不直接改队列。故事触发由核心操作，展示和声音不消耗地图 RNG。死亡演出为非性化回声咒。

`state.defeated_entities` 为记录数组，每条含 `id` / `rank` / `floor`；`state.result` 为 `""` / `death` / `victory` / `abandoned`。胜利 completed=true；复盘只读。每次不同旅程使用唯一 ID，种子相同也不能复用结算 ID。

## 剧情成长模块（静态纯函数）

- `Progress.default_meta() -> Dictionary`：包含 souls、upgrades、upgrade_spend、failure_count、runs、wins、records、last_settled_run_id；记录有界。
- `Progress.initial_player(meta) -> Dictionary`：返回带开局火种的 player，装备/遗物为空。
- `Progress.settle(state, meta, result) -> Dictionary`：返回 `{ok,error,state,meta}` 深拷贝候选，不执行磁盘 IO，不修改输入；按 run_id 幂等，登记灵魂和失败故事。
- `Progress.purchase(meta, kind) -> Dictionary`、`Progress.reset(meta) -> Dictionary`：返回 `{ok,error,meta}` 候选。
- `Story.initialize(state, meta) -> void`、`Story.enqueue(state, event_id) -> void`、`Story.on_floor(state) -> void`、`Story.on_failure(state, failure_count) -> void`、`Story.on_victory(state) -> void`：只改调用方候选故事状态。
- `CampaignSave` 继承旧 MapSave，接受旧试炼与新正式地图封装，校验 meta、状态和跨字段一致性；沿用原子写及备份。

地图线程负责把候选状态与账户一次提交并处理写入失败；剧情线程负责纯结算和数据验证。若接口需调整，先通知统筹和使用者。
