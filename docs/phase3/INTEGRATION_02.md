# ② v2 战役生成器集成

> 统筹续接更新（2026-10-01）：本聊天的集成轮因用量限制中断，以下“进行中”为当时记录。统筹已完成程序接线与验证，实际结果、截图和剩余美术范围见 [INTEGRATION_RESULTS.md](INTEGRATION_RESULTS.md)。

当前状态：**模块完成待集成**（2026-10-01）。已读取 INTEGRATION.md；本批仅新增生成器、必要②适配与专项测试，不改引擎/存档/UI。

## 实现与调用

新增 `scripts/core/phase3_campaign_generator.gd`，保留 `config/content_snapshot/errors/last_error`、`plan(seed)`、`generate(plan,floor,theme,boss_choice)`、`count_opportunities(map)`。另有 `phase3_context`、`validate_plan(plan)` 和纯函数 `apply_healing_snapshot(map,challenge_snapshot)`。

```gdscript
const Generator = preload("res://scripts/core/phase3_campaign_generator.gd")
var generator = Generator.new() # 新局：初始化既有战役规则的v2副本
# 读档也可 Generator.new(frozen_campaign_rules)，或之后赋值 generator.config。
generator.content_snapshot = frozen_content.duplicate(true)
generator.phase3_context = {
    "ruin_definitions":frozen_ruins,
    "unlocked_ids":frozen_unlocks,
    "used_unique_ids":reserved_in_other_slots,
    "variant_plan":frozen_variant_plan,
    "challenge_snapshot":frozen_challenge, # 必須 version:1,id,heal_percent
    "challenge_id":frozen_challenge.id, # 可省略；若提供必须相同
    "geometry":"existing"
}
var plan = generator.plan(seed_text)
var floor = generator.generate(plan,1,"entrance")
# 外层成功提交时把 floor.phase3_new_unique_ids 加入 reserved_unique_ids。
```

- `config.version=2`，event_floors固定为2/6/9层的p3遗迹；`plan.version=2`、`floor.generator_version=2`。
- 内部只给旧生产生成器传入 v1 配置/计划**副本**，恢复临时 library/forge/hermit 事件ID；几何生成后立即装饰，临时旧事件不会输出到v2楼层。
- 内部覆写旧生成器的机会计数方法，直接使用传入的冻结内容，避免每生成一层创建 ContentDB 再热读当前表。临时旧事件仅需无物品机会的占位定义，不加载旧奖励公式。
- 原生成器源码未修改。初始构造会由其构造器读取战役默认配置；有冻结config时立即使用冻结副本，此默认读取不决定读档结果。plan/generate不热读遗迹、物品或挑战定义。
- 必需上下文缺失或ruin_definitions为空时拒绝；冻结事件与content对应定义不一致、缺少新机制遗物/计划变体也拒绝，不能默默用当前表补齐。
- 首层兼容原 `entrance`；仅首层允许。Boss层必须为 `boss`。必要②改动只有地图装饰校验增加该主题。
- 固定 existing 几何，传 `ruin_spokes` 明确拒绝；八向新几何仍留在独立预览，不进入本批主旅程。
- 预留表由外层事务维护；本模块不就地改变context、content、计划或玩家状态。保持固定军械、Boss门槛、原预算和设施位置。
- JSON数值比较复用统筹新增的 `phase3_contract.gd::same_json`，允许冻结/读回后的同值int/float；数值范围与整数要求仍由专门校验处理。

## 治疗字段协议（供④保存校验与⑤显示）

每个新楼层（含Boss/C0/C1）带：

```json
{"phase3_healing":{"version":1,"challenge_id":"p3_c2","heal_percent":80,
  "sources":["potion","rest"],"explicit_heal_only":true}}
```

仅C2采用冻结 challenge_snapshot.heal_percent；C0/C1必须为100。百分比接受1–100的有限整数；不热读当前挑战表，也不调用写死80%的旧辅助函数覆盖冻结值。

- 地图 potion：`phase3_heal_base` 保存缩放前 amount，`amount` 保存最终整数，description重写为准确的“恢复 N HP。”。
- rest 的每个有显式 `effects.heal` 的选项：`option.phase3_heal_base` 保存基线，`effects.heal` 保存最终整数。文案保留最大生命增益并写出实际治疗，例如“最大生命 +20，恢复 16 HP”。
- 实际公式：基线0仍0；正数为 `max(1,floor(base*percent/100))`。35→28、45→36；休息70→56、20→16。
- 不改商店、遗迹、击杀治疗、`max_hp` 效果或其隐含恢复。缺少显式heal的休息选项不加基线字段。
- 第二次调用看到楼层phase3_healing即拒绝；即使删除楼层标记，药剂/休息残留的phase3_heal_base仍阻止再次缩放。
- 主引擎直接使用已生成的 amount/effects.heal，**不得领取时再次调用 scale_heal**。每次generate先生成全新基线，所以重复生成同冻结输入可复现而非累计打折。

④现有 `phase3_save_validation.valid_floor` 已读取了上述同名结构；此次只读核对，未改其代码。

## 文件

- 新 `scripts/core/phase3_campaign_generator.gd`
- `scripts/core/phase3_map_recipe.gd`：首层entrance兼容
- 新 `tests/phase3_ruins_generator_test_runner.gd`
- 新 `tests/phase3_ruins_generator_verify.ps1`
- 本报告。没有改引擎、存档或UI。

## 测试

命令：`pwsh -NoProfile -File tests/phase3_ruins_generator_verify.ps1`。指定Godot4.7.2，隔离APPDATA/LOCALAPPDATA至 `build/verification/phase3/02-ruins/generator-appdata` 与 `generator-localappdata`；没有玩家存档访问，没有编辑器导入/导出。

实际结果：**80,855项检查、12,000个楼层、0失败，进程退出0**。seed0–99×C0/C1/C2×三主题×十层，加seed100–199×C0×三主题×十层；覆盖三个挑战各六个普通模板、两个Boss模板，共24种挑战/模板组合。

验证了JSON快照完整复现、原生成器语义不变、冻结缺失与矛盾拒绝、预留回填、治疗一次缩放、0/1/2边界、冻结百分比变化、准确文案，以及既有安全路/钥匙/割点、固定军械/Boss实体不变和预算。证据为 `generator-results.json`、`generator-tests.log`。

日志仅出现环境既有的Windows根证书存储读取警告，无脚本错误或失败检查。此次没有网络请求。

## 剩余事项

- 外层新局/读档传完整冻结context，在生成保存事务中接受phase3_new_unique_ids；统筹消息已确认接线。
- ④负责存档封装和所有持久状态校验，③负责真实生产路线/保存联调。本模块生成测试不等于整塔可通或保存验收。
- 本批不启用新几何和草稿美术；不声称第三阶段已完成。
