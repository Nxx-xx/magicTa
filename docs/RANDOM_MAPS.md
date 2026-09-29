# 随机地图生成脚本

**第3版更新**：新开局采用生成器版本3；在原地形与固定成长路线之上，战斗遗物和金门宝库改为二选一，宝藏开放支路改为事件，商店治疗支路改为休息点，商品第三格改为药剂 / 吊坠。配置见 `data/reward_rules.json`，操作与兼容见[奖励系统使用说明](REWARDS.md)。第1 / 2版旧局的后续楼层继续使用原规则。下文第2版描述保留为基础生成结构和历史兼容说明。

新开局使用 `scripts/core/map_generator.gd`，已接入当前两层方格原型。楼层首次生成后保存在存档中；返回旧楼层只读取状态，不调用生成器。

## 已实现

- 固定 11×11 格，三套不同拓扑模板，8 种旋转 / 镜像变换，总计 18 种不同的墙体布局。
- 4 条支路的用途随机排列；每条支路内再随机选择守卫、锁门与奖励的位置。
- 主路钥匙、金币、药水的位置和部分数量随机。
- 钥匙和门分为铜、银、金三种，仅同类型可开门；每种钥匙单独计数，图标同时标注颜色和文字。
- 按主题配置抽取怪物与装备，战斗层、宝藏层、商店层的支路构成不同。
- 商人从靠近入口的安全位置抽取，三类商品各选一件，保证没有重复商品。
- 主要装备与遗物放在支路守卫或门后；点击敌人 / 门时显示其守护奖励。
- 首次生成时检查边界、连通性、楼梯通路、钥匙预算、商人位置和守卫—奖励关系；失败最多重试配置次数，不无限循环。
- 每层独立种子。人物走动、战斗、商店购买、取消主题选择不会消耗楼层生成随机数。
- 新局使用 `generator_version = 2`。缺少该字段或值为 0 的旧存档继续使用历史手工布局；第 1 版随机存档继续使用全铜门规则，包括尚未进入的第二层。已有楼层不重新生成。

当前范围仍是**两层模板随机地图**。墙体通过模板选择、旋转、镜像发生变化，不是每个格子独立随机挖墙，也没有扩展到十层 Boss 或灵魂系统。

怪物身份、档次、图标与详情已按 [怪物设计](MONSTER_DESIGN.md) 接入。入口 / 战斗 / 宝藏 / 商店主题分别放 2 / 3 / 1 / 2 只怪。运行时验证器会拒绝强度档与支路职责不匹配、缺少成长史莱姆 / 长枪 / 板甲、缺少回溯骑士 / 目标奖励，以及守卫与奖励错配的地图；既有合法抽取和种子不变。

## 在游戏中使用

导入 `project.godot` 后，开始新的地图试炼即可使用三种钥匙与门。旧的“继续探索”读取原地图；已有 `keys` 库存保留为铜钥匙，缺少的银 / 金库存补零。

菜单种子填 `42` 可固定输入；留空则产生随机本局种子。一层自动生成“入口层”，第一次上楼再选择第二层的主题。相同版本的引擎、生成器与内容配置，以及相同本局种子 / 楼层编号 / 主题，会得到同一张地图。

随机位置会改变入口朝向，人物出生坐标取生成地图的 `entry`。上下楼的到达位置也取各自楼层的 `entry` / `exit`，没有依赖旧版固定坐标。

## API

```gdscript
const Generator = preload("res://scripts/core/map_generator.gd")
var generator = Generator.new()

# 入口层只能用 entrance；二层支持 battle / treasure / shop。
var first_floor: Dictionary = generator.generate("42", 1, "entrance")
var second_floor: Dictionary = generator.generate("42", 2, "treasure")
if second_floor.is_empty():
    push_error(generator.last_error)
else:
    # 此后保存这个字典，回访时读取。不要重新 generate。
    run_state.floors["2"] = second_floor
```

生成结果沿用已有地图结构：`rows`、`entities`、`entry`、`exit`、`floor`、`theme`、`name`。另外增加：

```text
generator.version      生成器版本
generator.seed         当前楼层独立种子（字符串，防 JSON 精度损失）
generator.template     采用的布局模板 ID
generator.symmetry     旋转 / 镜像编号 0～7
generator.attempt      第几次生成通过检查
guard_links[]          每个守卫 / 门与身后奖励的坐标及用途
entities["x,y"].role   稳定用途标签，供调试与测试使用
entities["x,y"].key_kind  门 / 钥匙类型：copper、silver、gold；旧实体缺省为 copper
```

种子由固定整数运算计算：`版本 | 本局种子 | 层号 | 主题`。生成器内部创建自己的 `RandomNumberGenerator`，不调用全局随机函数，不使用人物当前攻击、防御或行走步数。怪物不会在玩家变强后自动变强。

生成失败返回空字典，并设置 `last_error`。接入层只有在成功生成后才写入 `floors` 或替换本局状态；失败会保留原地图和未完成的主题选择。

## 配置

`data/random_maps.json` 是运行时配置，修改后重新启动项目 / 开新局生效。现有存档地图不受修改影响。

| 字段 | 用途 |
| --- | --- |
| `templates` | 墙体、入口出口、支路候选位置、安全补给位置、入口附近商人位置 |
| `recipes` | 单条支路的门 / 怪物类型、奖励池与数量区间 |
| `recipes.*.key_kind` | 门配方对应的钥匙类型：`copper` / `silver` / `gold` |
| `themes.*.recipes` | 一个主题采用的四条支路配方 |
| `shop_pools` | 三个不重叠商品池，目前分别为攻击、防御、药剂或钥匙 |
| `safe_gold` / `safe_heal` | 主路金币、药水数量区间 |
| `max_attempts` | 生成失败重试次数，默认 12，运行时最多 32 |

一层包含回溯骑士支路、铜门护甲支路、小怪金币支路和开放治疗支路。

二层三种主题都保留用于验证回溯的两条成长支路：史莱姆守护破晓长枪，银门守护骑士板甲。宝藏主题的额外宝库使用金门，其余支路体现各自主题。强装备不再直接摆在入口主路上，但这些固定装备仍是两层试炼的数值支撑，不能据此认为完整十层已平衡。

按必要路线获取上述装备最多先承受史莱姆的 6 点伤害，再返回一层，骑士预计造成 77 点损失。参与其他可选战斗会改变生命预算；生成器检查结构，不保证任意选择都能存活。

钥匙采用保守规则：每层在所有门和怪物之外，分别按铜 / 银 / 金门的数量放置对应钥匙，不依赖上一层剩余钥匙。验证器分别检查三类库存预算，总数足够但类型不匹配也会失败。钥匙点的位置随机，玩家仍要找到并拾取。后续若要做跨层钥匙稀缺，需要另行加入整塔资源预算检查。

`map_keys.gd` 统一类型、名称与配色。玩家字段 `keys`、`silver_keys`、`gold_keys` 分别记录铜、银、金钥匙；地图商店原有的钥匙商品明确显示为铜钥匙。开门消耗一把对应钥匙并移除门实体，跨层与读档均保留结果。第 1 版生成兼容由 `generate(seed, floor, theme, 1)` 保留；默认调用生成第 2 版地图。

`tools/build_random_templates.py` 是模板配置的编写源。修改该脚本后执行 `python tools/build_random_templates.py` 可重新生成 JSON；这会覆盖 JSON 的手动修改。游戏运行只读取 JSON，不依赖 Python。

## 检查

无需 Godot：

```powershell
python tools/check_random_maps.py
python tools/check_project.py
```

已执行静态结构检查：3 套模板 × 8 种变换，352 种守卫位置组合、376 组守卫与奖励位置组合均通过；验证了所有允许的补给位置安全可达、商人靠近入口、无物件位置重叠、钥匙数量与门匹配、守卫不可绕过。该检查针对模板约束，不是执行了 GDScript 随机数或生成脚本。

有 Godot 后执行：

```powershell
godot --headless --path . --editor --import
godot --headless --path . --script tests/random_map_test_runner.gd
godot --headless --path . --script tests/map_test_runner.gd
godot --headless --path . --script tests/keys_test_runner.gd
```

新增测试直接调用生产代码，覆盖 80 个种子 × 4 个主题的生成与复现、9 条随机地图回溯路径、战利品与楼层持久化、随机商店交易、待选主题读档、独立 RNG、无效布局有限重试以及旧存档兼容。**已在 Godot 4.5.1 执行通过：随机地图 3,091 项检查，无失败。**

三色钥匙测试另外覆盖逐类型拾取、错误钥匙拒绝且不扣资源、正确扣除、不能重复领取或开门、30 个种子 × 4 个主题的类型预算、门与库存存档、跨层持久化、旧库存迁移和第 1 版生成兼容。**已在 Godot 4.5.1 执行通过：926 项检查，无失败。**

GDScript 静态解析、Godot 4.5.1 导入与运行回归已通过；已检查地图和怪物详情的实际渲染。浏览器 / 手机触控与导出仍需后续验收。最新记录见 [VALIDATION.md](VALIDATION.md)。
