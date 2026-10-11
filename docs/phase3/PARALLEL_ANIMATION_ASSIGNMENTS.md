# 剩余敌人动画并行制作

2026-10-01。用户明确要求一个统筹线程发布任务、多个独立线程分工制作。

## 分工与写入范围

| 角色 | 范围 | 专属源目录 |
| --- | --- | --- |
| 统筹 | 发布正式帧、清单与运行接入、串行验收、汇总状态 | 公共运行文件及本文件 |
| 基础 A | skeleton、bat 战斗四动作 | source/parallel_v05/battle/skeleton、battle/bat |
| 基础 B | sentinel、knight 战斗四动作 | source/parallel_v05/battle/sentinel、battle/knight |
| 基础 C | warlock、berserker、warden 战斗四动作 | source/parallel_v05/battle/warlock、battle/berserker、battle/warden |
| 变体 | 三个 p3_* ID 的独立附件、基础动作与 guard/charge/threat | source/parallel_v05/variants/<enemy_id> |
| 地图 A | slime、skeleton、bat、sentinel、p3_shield_sentinel 独立地图 idle | source/parallel_v05/map/<enemy_id> |
| 地图 B | warlock、knight、berserker、warden、p3_ember_channeler、p3_vault_knight 独立地图 idle | source/parallel_v05/map/<enemy_id> |

表内 source 相对 assets/monsters/phase3。每个制作线程只写自己目录、对应独有 tools/phase3_v05_<组名>_* 工具、build/verification/phase3/08-parallel/<组名> 验证目录。源目录放 .gdignore。制作线程禁止修改共同 manifest、textures/v04、公共烘焙/发布脚本、运行脚本、已有 Boss/史莱姆资源与公共文档。

## 交付要求

先读 COMPLETION_FOLLOWUP.md、03_ENEMIES_AND_BOSSES.md、05_ONBOARDING_AND_ANIMATION.md，以最新续做记录区分已完成与旧设计稿中的历史状态。参考牛头 rig_v04 与魔像 golem_v04 的可编辑绑定、提示词、视觉审阅及哈希批准记录。

普通怪 idle 4/6、attack 6/12、hit 2/12、defeat 6/10；bat idle 为 4/8。精英 idle 4/6、attack 8/12、hit 3/12、defeat 8/12。三变体分别 guard 4/12、charge 4/8、threat 4/8，并覆盖四个基础动作；独立轮廓附件不可仅调色。战斗朝左，512 母版到 256 运行帧。地图轻俯视正面独立母版，256 运行帧、锚点 (128,224)，idle 暂按 4 帧，常规 6 FPS、bat 8 FPS；此地图时间轴为沿用已接入 Boss 样板的制作选择，原设计未规定统一帧数。

位图原画使用内置 imagegen 并遵循 imagegen 技能；保存原图与完整实际提示词。不以整张静态图旋转缩放冒充完整动画。交付分层原生可编辑场景、关节与握点、动作源、透明身体帧及可独立关闭的特效帧、draft manifest、联系图、原速/0.25 倍/逐帧/26、33、47px 预览、REVIEW.md、绑定最终帧哈希的批准记录。实际看过的动作才批准；真人签收仍为 false。批准与烘焙分离，禁止自动技术检查冒充视觉审阅。

变体线程先制作独立附件，等待对应基础动画完成后组合四个基础动作。地图变体造型与附件需和变体线程协调。制作线程可以只读其他目录，不能覆盖其他线程产物。全部线程均已获用户授权就本次分工互相发送协调消息、向统筹汇报以及由统筹继续派发本次范围内任务；不创建额外线程或子代理。

## 并行工具与接入规则

Godot 的 .godot 导入缓存共享，所有导入、原生烘焙、原生场景测试与 UI 捕获必须获取同一 PowerShell 命名互斥锁 MagicTa_Phase3_Parallel_Godot，使用 try/finally 释放；锁等待可用短间隔并继续其他独立工作。统筹负责先准备安全包装器并发布路径。准备期间可以生成原图、编写源和浏览器审阅已存在帧，不自行启动无锁 Godot。每组验证用独立 APPDATA/LOCALAPPDATA，不读取真实玩家存档。公共烘焙输出如 rig-review.json 由包装器在锁内复制到本组证据目录。

生产发布和共同运行测试由统筹串行执行。保持实际 image-data 缓存预算，敌人 8 MiB、新增动画目标 48 MiB；不能把 PNG 体积或全渲染器纹理混为此预算。不可修改战斗数值、交易/存档/奖励逻辑、hero_walk.gd、floating_joystick.gd。保留现有未提交变更，不 reset、clean、提交、推送、部署或覆盖旧包。

## 当前状态

2026-10-02：六个制作线程全部交付，统筹已完成独立逐动作复核、精确帧哈希发布与生产回归。本轮分工的七基础战斗、三个变体五动作及十一独立地图待机全部接入；共新增54条时间轴、246身体帧位和140特效帧位。现有Boss/史莱姆战斗及Boss地图保留不变。本轮不包含公主精修、魔像五档持续石甲、真人试玩、Windows/微信新包及真实设备验收。

| 组 | 线程 ID | 状态 |
| --- | --- | --- |
| 统筹 | `01a0f827-3061-79b0-b7c9-c936763185dd` | 全部发布到 v05；1630资源/协议检查与235界面/缓存检查通过 |
| 基础 A / base_a | `01a0f828-68f2-72d0-8cf1-bac0dbe7432a` | skeleton、bat 战斗四动作已发布 |
| 基础 B / base_b | `01a0f828-7d05-7333-bb13-9af6fd1121b5` | sentinel、knight 战斗四动作已发布；静态制作审阅加统筹native定时复核 |
| 基础 C / base_c | `01a0f828-8c66-7690-ba51-66939c90039a` | warlock、berserker、warden 四动作已发布 |
| 变体 / variants | `01a0f828-a520-7701-8988-b703cfad11ff` | 三组各基础四动作＋机制动作全部发布 |
| 地图 A / map_a | `01a0f828-b5cc-76f2-844a-a546c7562249` | 五独立地图待机全部发布 |
| 地图 B / map_b | `01a0f828-ce23-7792-b72e-bb5944d43a98` | 六独立地图待机全部发布 |

### 统一 Godot 调用

使用 PowerShell 7，`GodotArgs` 为实际参数数组（渲染需要窗口时去掉 `--headless`）：

```powershell
& ./tools/phase3_v05_godot_locked.ps1 -Group base_a -Label skeleton-bake -GodotArgs @('--headless','--script','res://tools/phase3_rig_bake.gd','--','--source=res://assets/monsters/phase3/source/parallel_v05/battle/skeleton/skeleton_rig.json')
```

包装器独占 `MagicTa_Phase3_Parallel_Godot`；日志、运行结果、独立 APPDATA/LOCALAPPDATA 和本次共享 rig-review 副本写入对应组目录。退出码或 SCRIPT ERROR / Parse Error / Compilation failed / FAIL 任一失败均拒绝通过。公共 bake 已允许 `08-parallel` 的隔离用户目录。

地图审阅批准记录中的动作名为 `map_idle`（draft 的 `source_action` 可为 `idle`），战斗记录为实际战斗动作名；统筹按动作合并。既有16条 accepted 元数据、108个身体/效果帧哈希及原行走/摇杆/规则文件基线保存在 `build/verification/phase3/08-parallel/coordinator/baseline.json`。
