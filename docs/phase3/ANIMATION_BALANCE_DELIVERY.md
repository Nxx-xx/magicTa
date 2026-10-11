# 正式模型、演出与平衡交付记录

> 后续更新：本记录中的“正式新增仍 0 帧”是上一批交付状态。公主 91、史莱姆 18、遗迹 75 帧位及遗迹新几何已经接入，最新结果与未完项见 [续做记录](COMPLETION_FOLLOWUP.md)。以下保留原批次审阅证据。

2026-10-01，**进行中，整批未完成**。已经实施源文件制作、演出修复、真实路线与存档回归；不是只有计划。正式新增动画仍0帧，当前三个绑定样板均为draft，不能把下面程序结果解释为完整动画/第三阶段验收。

## 已实际修改的生产行为

`scripts/ui/phase3_combat_player.gd`：

- 按生产战报事件顺序分出攻击前后机制：牛头狂怒/直接攻击触发的石甲先于反击；荆棘跨阈值的石甲晚于反伤。无需重算战斗或迁移旧战报。
- 命中数字优先使用actual_hit，避免过量伤害当作实际扣血。零收益格挡仍保留次数消耗的文字，但不播放收益音。
- 同回合机制说明持续到下一回合，防止相隔数毫秒的压缩节点让说明一闪而过。
- 显示对手的现有正式静态素材；变体/缺失新动作继续旧资源回退。没有启用draft。
- 区分用户暂停与后台暂停，返回前台不会擅自解除用户暂停。减动效隐藏双方图像，保留完整战报与结算。
- 提供实际命中/反伤/格挡的短音映射，复用已随Windows与微信旧包提供的hit/door音频，不新增微信不认识的音效ID。

`scripts/ui/map_screen.gd`：只补传敌人ID与显示名、连接以上短音映射，切后台停止当前音频。没有改战斗/奖励/存档规则、剧情节点或地图几何；营救→团聚→背叛/揭露仍由原剧情流程承担。

原 `hero_walk.gd` / `floating_joystick.gd` SHA256前后相同，见证据目录 `preserved-controls-final.json`。未reset、提交、推送或覆盖整仓；已有微信适配文件未修改。初始Git状态单独保存。

## 可编辑模型与草稿

| 对象 | 可编辑源 | 本轮烘焙帧位 | 当前缺口 |
|---|---|---:|---|
| 公主 | 14命名图层，右剑/左灯父子绑定、肩肘/髋膝枢轴、JSON和Godot场景 | idle4 + attack8 + hit3 = 15 | 四向/行走/脚接触、完整踝部、头发分层、全身蓄力与其余动作 |
| 史莱姆 | 3基础层＋6重绘外膜形状，JSON与离散贴图时间轴 | idle4 + attack6 + hit2 = 12 | 体量/接触与衔接人工验收、退场；不能只靠面部轻摆称完整idle |
| 牛头 | 9命名图层，肩肘/斧绑定、独立怒纹，JSON和Godot场景 | idle6 + attack8 + hit3 + rage6 = 23 | 胸头朝向、关节遮挡、完整膝踝/下肢运动、退场 |

合计50是**烘焙时间轴帧位**，不是50张新原画；有合法回位重复帧，独立像素数见 `draft-frame-audit.json`，没有拿它们填236帧已完成数量。旧51张敌人草稿保留。新资料位于：

- `assets/characters/hero/phase3/source/rig_v02/`
- `assets/monsters/phase3/source/rig_v02/`

每套有 `*_rig.json`、`*_editable_draft.tscn`、命名透明PNG/RES、动作帧、draft manifest、原速/0.25速/暂停/逐帧HTML与47/33/26px预览。原生场景实际保存/重载并保留动画通过。目录有`.gdignore`，主游戏不引用这些草稿。三张组件原图实际1280×1280；768/512为组合场景画布，不把低分辨率单张图放大后冒充原生母版。

已修订靴向、武器裁切、史莱姆核心外露/表情脱层/相邻图格碎片；牛头重绘肘端毛发及重复肩甲，并修正前臂/怒纹混入邻格的裁切框。最终50帧位的外缘检测均留≥4透明像素；逐帧联系图已实看。但这不等于±1px脚接触、动作原速自然、模型全规格通过。需要补齐缺口后再做真实地图/战斗新动画验收，未先铺开剩余怪物/变体/遗迹，以免复制尚未合格的样板。

工具：内置imagegen。完整实际提示词、输入角色、尺寸与透明判断在 [ANIMATION_BALANCE_PROMPTS.md](ANIMATION_BALANCE_PROMPTS.md)。没有CLI回退或外购素材。Godot做确定性分层打包与动画烘焙；Python只生成可编辑JSON、分析和封装已有帧为GIF/WebP。

## 平衡证据与结论

四轮数据分目录保留，不覆盖失败来伪造通过。所有路线使用真实生产移动、战斗、领取、商店、遗迹、上下楼、写盘重载，不改state.player。

| 轮次 | 样本 | 通关 | 检查/失败 | 发现 |
|---|---:|---:|---:|---|
| C0原精简路线直接用于高难度 | 种子42 × C1/C2 × 四起点 × 三构筑 = 24 | 11 | 7501 / 13 | C2全部在3–5层停下；行商C1强攻也在4层停止 |
| 使用可达药剂、一次商店药剂、致死前休息 | 种子0–9，同24组合 = 240 | 210 | 102500 / 30 | 20次牛头、10次魔像门槛失败；不是程序异常 |
| 三层用30金币补齐另一类军械，再合理使用补给 | 同240组合 | 240 | 109068 / 0 | 所测低攻守御和行商混搭可行；无需改挑战数据 |
| 在准备路线中实际击杀出现的三类变体并领取奖励 | 同240组合 | 240 | 118188 / 0 | 216场变体实战，盾壳/蓄焰/金库各72场；无致死跳过 |

后两轮为明确的**解锁账户夹具、零火种**，只开放挑战/起点，不假装玩家已挣得解锁。真实合法解锁另测：全新隔离账户C0→C1→C2，C0走可选蝙蝠支路取嗜血剑、实际受伤后击杀恢复，三层实际消费30金币；随后以已挣得的先遣/守灯/行商起点各通C2。**6条路线，2722检查0失败**，全过程没有写入解锁夹具或升级玩家属性，见 `legal/legal-progression.json`。

准备路线216个变体对照是**真实路线当前属性下的可选支路预览对照**。独立的variants轮已进一步完成**216次真实变体击杀与领取奖励**，三类各72次、无致死跳过；实际当时属性相对原怪的额外损失范围为−2至+6，超过阶段max_hp20%的样本为0。比较原怪的数值仍是同属性生产战斗模拟，不是同一存档重复领取原怪奖励。原始证据见 `variants/balance-batch.json` 及其逐路线trace。

准备路线守御样本中20%～30%的已打战斗为零伤，Boss原始损失范围42～96；未观察到这组路线“无代价整塔”，不能据此否认未访问支路或更多遗物组合可能有雪球问题。`late-floor-curves.csv`记录6–10层HP/上限/攻防/金币的最小值和中位数；完整治疗/资源数据在route JSON的checkpoints/trace中。

**调参决定：本轮不改数值。** 目前失败可通过真实已有商店选择与补给解决，先改数值会把路线准备问题混入难度定义。高难度的趣味性、选择是否过窄、商店是否形成过强最优解仍需人工试玩；通关率不代替“好玩”。旧已保存局快照没有被改写。

## 验证与实拍

| 验证 | 实际结果 |
|---|---|
| 新回放时序/暂停/反伤石甲/实际命中/短音映射 | 19检查，0失败 |
| 真实主UI：故障保存→候选重试→回放→关闭→重载 | 9检查，0失败；26帧10fps，真实C0种子42首只史莱姆 |
| 四档主界面 | 140检查，0失败，截图已更新 |
| 现有教程/动画目录/回放组件 | 88通过，0失败 |
| 保存 / 剧情 / 奖励 / v2分派 / 协议 | 77 / 71 / 459 / 1133 / 66，各0失败 |
| C0种子42三路线及旧战斗/地图/边界/整塔 | 1492 / 55 / 274 / 25 / 19117，各0失败（各套件有重叠，不相加宣称独立用例数） |
| 微信现有Node音频/持久化/指针/启动 | 4组通过，0失败；这是模拟适配API检查 |
| 三个原生可编辑模型保存重载 | 0失败；没有自动标accepted |

本机渲染为Godot 4.7.2 / OpenGL Compatibility / NVIDIA RTX5070。证据统一在 `build/verification/phase3/06-animation-balance/`（既有固定guard套件仍写各自旧隔离目录）。所有APPDATA/LOCALAPPDATA均隔离；未访问真实Windows或微信玩家档案。Godot有已有根证书读取警告；判断同时使用退出码与SCRIPT ERROR/Parse Error，早期失败尝试不算最终通过。

实拍：`main-game-replay.gif`、`host-frames/04.png`。这些画面清楚展示**批准旧静态资源**与当前真实回放，不能冒充新动画接入。三角色草稿各动作WebP与联系图另有draft后缀。

## 复现

```powershell
# 演出、真实主UI与原生模型源
powershell -NoProfile -ExecutionPolicy Bypass -File tests/phase3_animation_balance_verify.ps1 -Presentation -Capture -BakeRigs
# 240高难度生产路线（显式解锁夹具），以及独立真实合法解锁
powershell -NoProfile -ExecutionPolicy Bypass -File tests/phase3_animation_balance_verify.ps1 -Balance -Prepared -Batch
powershell -NoProfile -ExecutionPolicy Bypass -File tests/phase3_animation_balance_verify.ps1 -Legal
# 真实变体支路扩展
powershell -NoProfile -ExecutionPolicy Bypass -File tests/phase3_animation_balance_verify.ps1 -Balance -Prepared -Variants -Batch
python tools/phase3_balance_summary.py
# 旧基线回归
powershell -NoProfile -ExecutionPolicy Bypass -File tests/phase3_host_verify.ps1 -Capture
powershell -NoProfile -ExecutionPolicy Bypass -File tests/phase3_integration_verify.ps1 -Three -Legacy
```

`tools/phase3_build_rig_sources.py`仅在重建初始JSON时运行，会覆盖手改JSON；普通编辑JSON后直接BakeRigs。`tools/phase3_encode_review.py`需Pillow，本次使用Codex随附Python，不安装外部软件。

## 尚未达到的交付条件

1. 正式样板四向/全动作/小格实际动画、美术逐帧和原速验收尚未达到；新资源未接主游戏，剩余角色/敌人/魔像/三变体独立动作与R1–R3场景动画未扩展。
2. 新手真人试玩、完整高难度手感评审、全部遗物组合/更大种子空间、48MiB正式动画驻留及Windows帧时尚未验收。
3. 用户指定Windows和微信小程序为目标。当前微信latest仍指向20260930包；本轮未重建/上传/发布平台包，现有Node通过不能代表本批微信客户端/真机通过。真实微信新内容包与设备性能需单独完成。

因此本文件是可复查的阶段性实施记录，不能将整批或正式模型动画标完成。
