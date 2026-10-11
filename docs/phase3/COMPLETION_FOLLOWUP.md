# 第三阶段续做记录

2026-10-02 · Godot 4.7.2 · Windows 本机源码验证。

**本次并行分工的动画已全部接入：七种剩余基础敌人战斗四动作、三种变体四基础动作及独立机制动作、十一种独立地图待机。生产敌人目录现在有70条已批准动作、342身体帧位、152特效帧位。第三阶段仍未整体完成：模型精修、真人试玩及目标客户端验收尚未关闭。** 本文是最新状态；此前 `INTEGRATION_RESULTS` 和 `ANIMATION_BALANCE_DELIVERY` 中的“零正式新增帧 / 原几何 / 静态回退”是各自交付时的历史记录。

## 实际接入

| 范围 | 本轮结果 | 保留的边界 |
| --- | --- | --- |
| 地图 | 新开第三阶段在第 2/6/9 层使用 `ruin_spokes`，八种朝向由已冻结楼层种子决定 | 原 v1 和未声明布局字段的旧 v2 局继续原几何；已生成楼层不重排，同种子重试保留冻结配置；未知配置拒绝 |
| 公主地图 | 四个独立方向，各 idle 4 / walk 6 / interact 4，共 56 帧位；原生分层场景、肩肘腕与髋膝接触求解；主地图读取已审阅帧 | 原移动插值、连走、摇杆与脚步节奏保留；交互反馈来自已提交交易，减动效停稳态；旧局仍保留旧表现 |
| 公主战斗 | idle 6 / attack 8 / guard 4 / hit 3 / victory 8 / defeat 6，共 35 帧位；在已保存战报上播放 | 攻击回位、胜利停顿有两处显式 pose hold，91 帧位包含 89 个动作内独立像素姿态，不宣称 91 幅新原画 |
| 史莱姆 | 外膜、内核、表情分层；idle 4 / attack 6 / hit 2 / defeat 6，共 18 战斗帧位；新增独立地图idle 4 | 原战斗v03不变；地图新母版v05，源保持draft、生产副本显式accepted |
| 七基础 v05 | skeleton/bat/sentinel/warlock/knight 各18战斗帧位；berserker/warden 各23，共136；各含idle/attack/hit/defeat与可编辑原生分层 | bat idle8FPS；普通defeat10FPS、精英12FPS；精英锚点(128,237)保留。26px细纹丢失、术士暗轮廓及部分共享靴腿绘制层在各REVIEW披露 |
| 三变体 v05 | 各18基础＋4机制帧位，共66；盾壳guard、焰祷charge、金库threat；实体塔盾、三叉炉环、钥齿冠/钥匙孔盾独立轮廓 | 物理附件与可关效果分离；实际战报驱动机制姿态，播放窗口可压缩；金库退场为蹲伏塌落，真人自然度待签 |
| 十一地图 v05 | slime、七基础、三变体均为另画前向轻俯视母版，4帧256×256、锚点(128,224)，共44；连同旧Boss地图共52 | bat8FPS、其他6FPS；地图只idle，完整分层不等于行走关节动画；warden细链跟随胸衣，金库肩锁以俯视钥孔肩板简化 |
| 牛头 v04 | 15 个战斗绘制层＋握点，独立髋膝踝；idle 6 / attack 8 / hit 3 / rage 6 / defeat 10，共 33 帧位；独立地图八层 idle 4 | 两张新增组件原图；战斗 31 个动作内独立姿态和两处 hold；怒纹独立叠层。退场松手后收臂、落斧、收蹄屈膝；真人自然度签收未完成 |
| 魔像 v04 | 20 个战斗绘制层，独立髋膝踝、头肩、核心与闭合甲板；idle 6 / attack 10 / hit 3 / armor 6 / defeat 12，共 37 帧位；独立地图九层 idle 4 | 三张新增原图；战斗 35 个动作内独立姿态及两处 hold；石甲纹样独立。退场核心熄暗、部件塌落。五档累计防御对应的持续 idle 外形尚未制作 |
| 三座遗迹 | 三幅新底座原画＋可编辑符文/光环层；15 条时间轴、75 帧位；待机、九种实际选项反馈、已解决状态 | 75 为烘焙帧位，不是 75 幅新原画；读取实际 selected_option，保存失败/重载/回访均不重播解决动画 |
| 场景反馈 | 两态原生 SVG 回溯标记弱呼吸；石台/锻台/灯台分别复用 door/hit/pickup 短音 | 非新录制音效；遵守静音和现有节流，无新增微信音频 ID；减动效标记静止 |
| 兼容修复 | 旧两层试炼菜单按引擎能力显示战役入口，修复访问不存在 meta 的脚本错误 | 不修改旧战斗、奖励数值或用户账户 |

已接入的 `accepted` 表示通过本次资源格式、逐动作画面检查并显式发布到运行目录，不代表真人美术签收或全部第三阶段退出条件通过。公主脚踝目前是接触节点，靴/小腿共用绘制层，头发主要跟随头部；完整独立发层与更细的人体关节、自然动作仍属精修项。

## 源文件与预览

- 公主：[模型与审阅](../../assets/characters/hero/phase3/source/rig_v03/REVIEW.md)、[完整提示词](../../assets/characters/hero/phase3/source/rig_v03/PROMPTS.md)、[运行目录](../../assets/characters/hero/phase3/manifest.json)。四个 `hero_*_editable.tscn` 可继续编辑。
- 史莱姆：[审阅及限制](../../assets/monsters/phase3/source/rig_v03/REVIEW.md)、[新增退场提示词](../../assets/monsters/phase3/source/rig_v03/PROMPTS.md)。旧组件沿用 v02 来源，未覆盖旧样板。
- 牛头：[审阅](../../assets/monsters/phase3/source/rig_v04/REVIEW.md)、[完整实际提示词](../../assets/monsters/phase3/source/rig_v04/PROMPTS.md)、[六动作原速/慢速/逐帧预览](../../assets/monsters/phase3/source/rig_v04/minotaur_review.html)。战斗与地图原生场景均可编辑，帧哈希批准记录与烘焙分离。
- 魔像：[审阅及限制](../../assets/monsters/phase3/source/golem_v04/REVIEW.md)、[完整实际提示词](../../assets/monsters/phase3/source/golem_v04/PROMPTS.md)、[六动作预览](../../assets/monsters/phase3/source/golem_v04/golem_review.html)。修正头盔朝向、切片碎屑和崩解裁切后显式批准。
- 遗迹：[分层源与提示词](../../assets/environment/ruins/phase3/source/layered_v02/README.md)、[本次运行清单](../../assets/environment/ruins/phase3/runtime_v02.json)。旧 `manifest.json` 仍是历史草稿；生产读取 `runtime_v02.json`。
- [统一动画预览](../../build/verification/phase3/07-completion/animation-review.html)：104 条时间轴，可原速、0.25 倍、暂停、逐帧、独立纹样开关和 26/33/47/128/256px 检查；用浏览器本地打开，不需要联网。由 `python tools/phase3_completion_preview.py` 重建。
- [真实战斗结束截图](../../build/verification/phase3/06-animation-balance/host-frames/20.png)、[320px 主界面](../../build/verification/phase3/00-integration/ruin_resolved_320.png)。战斗连续 26 张实拍在 `06-animation-balance/host-frames/`，当前批次未新编码视频。
- [真实第五层牛头连续回放](../../build/verification/phase3/07-completion/minotaur-host/main-game-replay.webp)、[主地图独立镜头](../../build/verification/phase3/07-completion/minotaur-host/map-camera.png)、[实测与战报](../../build/verification/phase3/07-completion/minotaur-host/results.json)。C0 种子 42、零火种默认起点，通过移动/奖励/休息/遗迹公开 API 到达第五层，保存失败后重试；112 张主 UI 实拍，20 FPS，非直接修改属性的动画夹具。
- [真实第十层魔像连续回放](../../build/verification/phase3/07-completion/golem-host/main-game-replay.webp)、[独立地图镜头](../../build/verification/phase3/07-completion/golem-host/map-camera.png)、[衔接归途剧情](../../build/verification/phase3/07-completion/golem-host/post-combat.png)、[实测与战报](../../build/verification/phase3/07-completion/golem-host/results.json)。同一公开路线继续击败第五层、领取军械和后半程奖励/遗迹后进入第十层，119 张 20 FPS 实拍。

母版目录 `.gdignore` 隔离于运行导入；运行帧复制到独立 textures 目录。烘焙工具只生成 draft 审阅结果，公主与史莱姆的提升由独立发布脚本完成，不用批量技术检查自动替代画面审阅。所有源图已放入项目，不依赖用户生成缓存目录。

## 验证证据

各套件存在重叠，数字不相加当作唯一测试数量。全部使用隔离 APPDATA/LOCALAPPDATA，不读取或修改真实玩家档案。

| 验证 | 本轮实际结果 | 证据位置（build/verification/phase3 下） |
| --- | --- | --- |
| 生成器、八朝向、三挑战、冻结旧配置 | 131,257 检查，0 失败；12,000 层 | `02-ruins/generator-results.json` |
| C0，0–99 种子，三构筑整塔持久化路线 | 138,846 检查，0 失败；300/300 第五层及通关 | `03-combat/integration/batch.log` |
| 种子 42 三路线与保存失败/重试 | 1,572 检查，0 失败 | `03-combat/integration/quick.log` |
| C1/C2，四起点，三构筑，实际变体支路 | 123,420 检查，0 失败；240/240 通关 | `06-animation-balance/phase3_balance_runner.log` |
| 真实账户 C0→C1→C2 合法解锁准备 | 2,988 检查，0 失败；6 路线 | `06-animation-balance/phase3_legal_progression_runner.log` |
| 保存主/备份、旧 v2 几何与重试 | 92 检查，0 失败 | `00-integration/phase3_save_host_test_runner.log` |
| 540×960、360×640、900×960、320×640 主 UI | 166 检查，0 失败；包含遗迹失败写盘→无成功反馈→重试一次反馈 | `00-integration/phase3_ui_host_test_runner.log` |
| 公主目录、帧与教学/回放协议 | 94 检查，0 失败 | `00-integration/phase3_animation_test_runner.log` |
| 地图公主、真实移动、交互、减动效与回退 | 47 检查，0 失败 | `07-completion/phase3_hero_map_test.log` |
| 遗迹 75 帧格式、各选项、回访/重载/只读 | 143 检查，0 失败 | `07-completion/phase3_ruin_art_test.log` |
| 敌人命中、两种致死、暂停/跳过、纹样开关、减动效、地图和缓存回退 | 210 检查，0 失败；逐帧遍历两个完整 Boss 后确认旧纹理弱引用已释放 | `07-completion/phase3_enemy_player_test.log` |
| 真实第五层保存失败/重试、狂怒/攻击/退场、只读回放与纹理驻留 | 205 检查，0 失败 | `07-completion/minotaur-host-capture.log`、`minotaur-host/results.json` |
| 真实第十层保存失败/重试、石甲/攻击/退场、只读回放和原结局剧情队列 | 378 检查，0 失败 | `07-completion/golem-host-capture.log`、`golem-host/results.json` |
| 历史草稿重新打包后保留批准资源 / 原生独立预览 | 16 条 accepted 动作元数据及 108 个身体/叠层路径哈希全部不变；预览 148 检查、0 失败 | `07-completion/draft-repack-preservation.json`、`enemies-preview-v04.log` |
| 战报机制时序 / 真实主游戏失败写盘后回放 | 20 / 9 检查，均 0 失败 | `06-animation-balance/phase3_replay_*` |
| 原按住连走、触摸、一步收尾与步态连续性 | 31 检查，0 失败 | `07-completion/walking_test_runner.log` |
| 旧剧情 / 旧奖励 / 规则分派 / 协议 | 71 / 459 / 1,133 / 66 检查，均 0 失败 | `00-integration/` 对应日志 |
| 微信现有音频 / 指针 / 持久化 / 启动适配 | Node 四组通过，0 失败；配额故障为预期注入 | `tests/wechat_*.test.cjs`；本轮终端执行记录，非真实微信客户端验证 |

高难度 240 路线采用已注明的解锁账户夹具，另用 6 条生产链验证合法解锁，不冒充全部账户自然游玩样本。既有数值未因动画修改；本次重新验证整塔是因为遗迹几何实际改变。早期旧几何生成/批测证据保留在 `07-completion/baseline/`。

公主目录的 JSON 数字数组比较已修复；有意停顿需声明 pose_holds，未声明同像素填帧继续拒绝。已导入贴图优先走 ResourceLoader，避免运行校验读取原 PNG 的导出告警。敌人改为按帧解码、按真实 image data 字节做 LRU 释放，保留全部动作的轻量元数据，不再因整动作超过预算而丢掉退场。战斗上限 8MiB；独立地图上限 4MiB，切楼层清空；遗迹上限 6MiB，公主目录各实例上限 24MiB。

两个 Boss 公开路线回放的动画缓存去重解码峰值均为 **20,250,624 bytes（19.31 MiB）**，敌人缓存峰值均为 **7,667,712 bytes（7.31 MiB）**。最新牛头渲染器总纹理峰值 51,688,841 bytes、魔像 60,601,729 bytes，各较战前增加 26,694,724 bytes；渲染器总值包含 UI/字体/其他纹理，不能说“总驻留低于 48MiB”。前两项统计本场公主、敌人地图、战斗和遗迹缓存的实际纹理 image data；后者是渲染器计数。均只证明这一台桌面机器和这条路线，不证明所有场景、进程 RAM 或目标客户端的新增动画 48MiB 条件。

Boss 强化片段原本受不足 0.1 秒的命中前窗口压缩，现仅为已提交战报的 cue 编排增加 0.18 秒机制停顿，强化姿态窗口约 0.25 秒，机制仍发生在对应玩家攻击之后、敌人反击之前；展示的 Boss 仍满足六秒目标。反伤后石甲另留停顿，不改变规则、战报、奖励或保存时序。

本机 RTX 5070，540×960，动态/静态各 120 个闲置渲染样本：中位 6.939/6.934ms，P95 7.529/8.215ms，包含 VSync；地图当前帧缓存 589,824 bytes，四向行走全帧单独审阅 1.5MiB。该测试只比较本机地图闲置场景，不证明微信、低端设备或完整战斗性能。详见 `07-completion/hero-map-performance.json`。

过程发现的失败日志保留：交互测试原夹具开启减动效却期待播放（已改为同时覆盖两种设置）；旧试炼菜单 meta 脚本错误（已修复）。最新对应套件均通过。系统根证书库告警不影响本次离线测试；退出码与脚本错误文本共同判断结果。原 `hero_walk.gd`、`floating_joystick.gd` SHA256 与续做前一致，见 `07-completion/preserved-controls.json`。

## 复现

```powershell
python tools/check_project.py
./tests/phase3_completion_verify.ps1 -Walking -CaptureHost -Minotaur -Golem
./tests/phase3_animation_balance_verify.ps1 -Presentation -Capture
python tools/phase3_completion_preview.py
python tools/phase3_minotaur_preview.py
python tools/phase3_minotaur_preview.py --entity golem --source assets/monsters/phase3/source/golem_v04
```

需要重新检查规则/地图时，再运行：

```powershell
./tests/phase3_ruins_generator_verify.ps1
./tests/phase3_integration_verify.ps1 -Batch -Three
./tests/phase3_animation_balance_verify.ps1 -Balance -Prepared -Variants -Batch
./tests/phase3_animation_balance_verify.ps1 -Legal
```

可选 Python fontTools/gdtoolkit 未安装；静态工具会标为 SKIP，不能把它们说成通过。Godot 原生导入与运行已执行。

## 尚未关闭的第三阶段项目

1. 魔像五档累计防御对应的持续石甲idle外形及最终细节精修；两个Boss规定动作与其余敌人本轮规定动画均已发布。旧牛头v02及历史失败源继续保持draft/rejected。
2. 公主与敌人的最终动作美术精修、逐帧/慢速/小尺寸人工签收。资源动作目录完整不等于模型全部细节符合最终设计。
3. 至少 5 人、每人两局的新手无提示试玩，20–40 分钟局时、构筑与放弃支路理由、选项偏好和趣味性记录。
4. 当前源码的 Windows/微信客户端包、真实客户端流程与目标设备性能。历史 Windows/微信包未被本轮替换，不能把旧包当作已包含这些动画和新布局。

因此当前可表述为“第三阶段玩法和本轮规定敌人动画全部接入，源码回归通过”，不能表述为“第三阶段全部完成”。

## 2026-10-02 并行 v05 最终核对

本轮新增54条accepted时间轴、246身体帧位及140特效帧位，身体与效果独立透明；不是386幅新原画。七基础、三变体和十一地图源位于 `assets/monsters/phase3/source/parallel_v05/`，真实imagegen原图、实际完整提示词、分层rig/native场景、draft manifest、联系图、小尺寸与审批记录随各实体交付。只有统筹复制到 `textures/v05/` 的精确哈希帧接入生产。六组分工及线程交付见 [分工记录](PARALLEL_ANIMATION_ASSIGNMENTS.md)。

生产发布门控独立于烘焙，检查制作与统筹两份精确身体/效果SHA、帧数/FPS/loop/事件/锚点/透明边/声明hold，并拒绝替换已批准不同字节。基础B的制作记录保留静态已审、播放待二审；统筹完成真实AnimationPlayer原速及0.25倍定时捕获和有序采样图复核后批准。其他制作组的浏览器审阅及统筹native二审均保留。统筹没有声称持续视频感知或真人签收，所有 `human_signoff=false`。

| 本批验证 | 实际结果 | 证据（08-parallel/coordinator 下） |
| --- | --- | --- |
| 全部帧完成后的Godot导入 | 成功；source母版不导入，运行v05纹理已导入 | `v05-final-import-*.log` |
| 导入后的生产全13敌人动作/地图解码、透明数据、实际LRU、换敌释放、三变体战报机制/效果关闭/减动效/暂停跳过只读 | 1630检查，0失败 | `production-animation-results.json`、`v05-imported-production-test-*.log` |
| 导入后的生产Replay界面13敌人×540/320px、角色与机制文字分区、底部控件、实际缓存压力 | 235检查，0失败；26张截图及两张统筹已看总联系图 | `runtime/results.json`、`runtime/<enemy>_<width>.png`、`runtime/ui_contact_*.png`、`v05-imported-runtime-ui-*.log` |
| 敌人回放、公主地图、遗迹、机制时序、教学协议、四尺寸主UI、原连走 | 210 / 47 / 143 / 20 / 94 / 130 / 31，均0失败；UI本次无截图模式，不计旧166截图检查 | 本目录各对应最终日志 |
| 发布门控夹具 | 3测试通过：正确合并、篡改拒绝、制作待播放须统筹二审 | `tests/phase3_v05_publication_test.py` |
| 旧资源与控制规则保留 | 16accepted元数据、108纹理SHA、6控制/规则SHA全一致；新生产帧均匹配双审记录 | `production-preservation.json` |

同时预热公主地图/战斗、敌人地图/战斗及遗迹缓存，并纳入正在显示的角色纹理、按RID去重后测量 `Image.get_data_size()`，本桌面夹具峰值 **42,663,936 bytes（40.69 MiB）**，低于48MiB目标；敌人LRU始终≤8MiB、地图≤4MiB。此为生产UI使用模拟内存战报并标记已提交的压力夹具，不冒充自然解锁账户路线、进程RAM、渲染器总纹理或真实设备验收。典狱长链条位于角色区，与机制文字区不相交，截图已复核。

保留过程失败：skeleton初稿审批后改动被哈希门控拒绝；原生可见窗口试验失败；hero地图headless渲染等待超时后用正常渲染通过；新UI夹具最初遗漏基础配置、将窗口物理高度与逻辑画布混比，修正夹具后通过；盾壳机制采样最初错过压缩窗口，改为事件后0.03秒核对通过；walking隔离路径旧限定扩展为同样隔离的统筹目录后通过。失败日志均未删除。根证书库告警单独排除，其他引擎ERROR、脚本错误、超时及非零退出都拒绝通过。

复现本批：全部Godot运行经 `tools/phase3_v05_godot_locked.ps1 -Group coordinator` 获取公共锁并隔离存档；生产协议用 `--headless --script res://tests/phase3_v05_animation_test.gd`，界面/缓存用非headless `--script res://tests/phase3_v05_runtime_capture.gd`。`python tools/phase3_v05_verify_production.py` 核对双审和保留，`python tools/phase3_completion_preview.py` 重建总预览。
