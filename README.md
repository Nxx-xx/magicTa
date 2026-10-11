# 塔境 · 公主救援记

**源码已接入第三阶段玩法与首批正式动画，保留旧十层存档，两层试炼已移除。** 新旅程增加六件机制遗物、三座遗迹及专用布局、三种敌人变体、挑战与起点解锁、图鉴、教学和战报回放。公主 91 帧位、史莱姆/牛头/魔像战斗 88 帧位及两个 Boss 独立地图 8 帧位、遗迹 75 帧位已接入；C0 300 条和 C1/C2 240 条整塔路线通过。其余敌人动画、模型精修、真人试玩和目标客户端验收仍未完成。最新状态见 [第三阶段续做记录](docs/phase3/COMPLETION_FOLLOWUP.md)；原剧情与火种基线见 [第二阶段交付记录](docs/PHASE_2_DELIVERY.md)。

## 运行

2026-10-03 当前微信包 `build/wechat-current` 已同步探索视角调整：约 5 格宽近景、主角始终居中、右下小地图，以及移除换层时脚下楼梯的自动详情。桌面与微信构建源码的实际渲染／输入检查通过，真机体验待验收。详见 [探索视角调整](docs/EXPLORATION_VIEW.md)。

2026-10-03 当前微信包 `build/wechat-current` 已更新营地地图精修：林缘与营火冷暖层次、塔门纵深、柔和角色阴影、池塘微波和环境衬底。营地及相关回归 935 项通过，并核验了 390/540 宽全图与近景、减少动效以及微信构建压缩资源的桌面渲染。本次微信模拟器和真机尚未验收，Windows / Android 历史构建未随本次更新。详见 [营地精修交付](docs/CAMP_POLISH_DELIVERY.md)。

- 微信小游戏测试包：微信开发者工具直接导入 `build/wechat-current`，或解压 `build/wechat-latest.json` 指向的 ZIP 后导入。构建、适配及真机验收状态见 [微信小游戏测试说明](docs/WECHAT_TEST_BUILD.md)。
- 安卓手机测试包：`build/android/TowerRealm-Android.apk`（约 79 MiB）；支持 Android 7.0 及以上 ARM32 / ARM64 手机。把 APK 发到手机后打开安装，详见 [Android 安装与打包说明](docs/ANDROID_BUILD.md)。已验证签名和打包资源，真机体验待验收。
- 本机试玩包：`build/phase2/TowerRealm-Phase2-Windows.zip`；解压整个目录后双击 `TowerRealm.exe`，点击“营救王子 · 十层旅程”。种子留空随机，也可填 `42`。
- 源码：用 Godot 4.7.2 标准版导入 `project.godot`，按 F5。入口为 `scenes/map_prototype.tscn`。
- 游戏运行无需 Python、账号或联网服务。Windows 包采用本机 Godot 可执行文件加载独立 PCK，属于便携测试包；尚未使用正式导出模板压缩运行时。

## 当前玩法

- 塔内底部“功能码”入口输入默认码 `NXX`，将当前生命、最大生命、攻击、防御设为 1000 并保存；大小写和首尾空格不影响识别。保留装备与旅程进度，后续正常成长仍生效，新旅程恢复正常初始属性。此功能已接入源码，已有安装包和微信包需重新构建。
- 十层均为 11×11 格，普通层采用六种走廊 / 环路布局及旋转镜像，两处 Boss 使用独立关隘。新层主题按种子自动确定，通过楼梯即可进入，无需三选一；三、八层保留固定商店，四、九层保留休息点。
- 默认探索视野约 5 格宽，主角在移动和地图边缘均保持居中；右下角小地图标出主角、敌人、物品、楼梯和可见区域，点击打开全图，“探索”返回近景。进入楼层不再自动显示脚下楼梯的详情卡片。见 [探索视角调整](docs/EXPLORATION_VIEW.md)。
- 点击可达地板，角色沿四向合法路径走到目标，探索与全图模式均支持；点击敌人、门或楼梯先靠近，再等待原有确认。方向键 / WASD 可连续行走，保留迈步动画与脚步声；探索地图拖动只取消点击和旧路线，查看远处使用小地图／全图。长列表可直接拖动内容，摇杆已移除。
- 铜、银、金钥匙分别开门；装备叠加，治疗可保留，奖励二选一、商店、事件和休息点一局内不刷新。每处商店由一个商人提供多件商品，每件限购一次，支持连续购买、离开后回来续购。早中期固定成长保障必要路线，支路提供额外风险与收益。
- 可在已访问楼层间往返，已拿奖励与已开门状态保留。楼层索引支持只读地图、目标标记及守卫属性查看。一层王权指环是可选回溯目标；十层模式须击败魔王才通关。
- 公主与王子通过传声石合作。战败触发非性化的“回声咒”故事与远处短促呼声；重复读档不重播、不重复结算。对白可跳过，语音可关闭。
- 击杀、Boss 和通关提供灵魂；生命、攻击、初始金币三条火种各三级，局后可免费重置。已验证零升级通关路线。
- 成功、失败和放弃都有结果页，支持同种子重试、新种子再战、营地和只读复盘。每次重试仍是独立旅程。
- 公主四向、六种普通怪、两种精英和两处 Boss 已接入静态贴图；王子 / 魔王对白有独立立绘。通关剧情先团聚，再揭示王子的背叛与怪物真身；怪物揭露插画从变身旁白开始显示，并用于结算页。支持效果音 / 语音音量、静音和减少动效。

游戏仅提供十层营救旅程。旧两层试炼存档仅用于读取账户，灵魂和火种保留，不再恢复试炼地图；读取时不改写原存档。

## 存档

`user://tower_map_save.json` 与 `.bak` 保存当前旅程和局外账户；两种地图模式共用一个进行中的存档，不是两个独立存档槽。地图、坐标、属性、待确认交互、内容 / 规则快照与 RNG 一起保存。保存失败时阻断玩法，重试成功后继续；退出前明确确认丢弃尚未保存的变化，上一次成功存档保留。

Windows 正常运行时，`user://` 位于 `%APPDATA%/Godot/app_userdata/` 下的项目目录。设置与标记保存在独立的 `presentation.cfg`。早期卡片模式的 `tower_save.json` 不会转换或覆盖。

## 开发与验证

```powershell
python tools/check_project.py
# Godot 路径配置在此脚本顶部；自动隔离测试存档并执行核心、存档和实际渲染检查。
powershell -ExecutionPolicy Bypass -File tests/phase2_verify.ps1
```

最近集成验证：原七组回归 4,847 项、十层核心 19,117 项、剧情存档 71 项、异常集成 25 项、界面无窗口 118 项、实际渲染 149 项均通过；原界面另有 526 项回归通过。十层检查包含 100 种种子、三种路线方向共 300 次零升级完整通关。测试数量不替代真人平衡与操作体验验收。

静态脚本只依赖 Python 标准库；fontTools、gdtoolkit 是可选检查，本次因未安装而跳过。`build/verification/` 保存日志和截图，排除在游戏资源导出之外。

关键实现：`campaign_engine.gd`（十层流程）、`campaign_generator.gd` / `campaign_validator.gd`（地图与投放）、`campaign_progress.gd`（结算成长）、`campaign_save.gd`（账户与旅程）、`story_state.gd` / `data/story.json`（剧情）、`map_screen.gd` / `campaign_panels.gd`（界面）。核心脚本位于 `scripts/core/`，界面脚本位于 `scripts/ui/`。`map_engine.gd` 保留共用地图基础能力；历史两层地图仅供测试夹具使用，正式启动入口已禁用。

## 范围与后续

可玩内容已经交付；外部玩家试玩、20～40 分钟节奏目标、声音试听、Web 导出与手机真机触控仍待验收。Android 已使用 Godot 4.7.2 官方模板生成可安装的调试签名 APK；尚无标准 Windows 发布包、Web 成品或 iOS 原生包。角色与怪物目前是静态图加位移反馈，尚无逐帧战斗动画；语音为系统合成原型。

- [第二阶段开发计划](docs/PHASE_2_DEVELOPMENT_PLAN.md)、[剧情设计](docs/STORY_DESIGN_PHASE_2.md)、[接口约定](docs/PHASE_2_INTERFACES.md)。
- [第二阶段交付与证据](docs/PHASE_2_DELIVERY.md)、[界面交付](docs/PHASE_2_UI_DELIVERY.md)。
- 第一阶段参考：[随机地图](docs/RANDOM_MAPS.md)、[怪物设计](docs/MONSTER_DESIGN.md)、[奖励说明](docs/REWARDS.md)、[成长设计](docs/META_PROGRESSION.md)。这些文档中的计划与历史状态不能替代当前交付记录。

## 素材来源

中文字体 Noto Sans SC 使用 SIL Open Font License 1.1，授权全文为 `assets/fonts/OFL.txt`，便携包随附副本。新王子、魔王、结局插画及四种精英 / Boss 素材使用内置 image_gen 生成，来源与完整提示词记录在 `assets/story/phase2/` 和 `assets/monsters/phase2/source/PROMPTS.md`；四种怪物的源图与加工结果分开保留。王子短呼声使用 Windows Microsoft Kangkang 系统语音加工，非真人录音，说明见 `assets/audio/phase2/README.md`。其他已接入资源沿用各自目录的来源记录。
