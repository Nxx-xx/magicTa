# C 组 · 战斗舞台与反馈交付

> **2026-10-04 更新：绘画舞台 v02 已接入。** 最新交付见 [BATTLE_STAGE_V02_DELIVERY.md](BATTLE_STAGE_V02_DELIVERY.md)，包含普通石厅、月夜遗迹、Boss 圣堂的原画/完整提示词/独立运行资产、手机实拍、兼容回归及实际导出预算。本页以下保留 2026-10-03 几何舞台的历史交付，原“新增 PNG 0”等结论仅适用于当时版本。

2026-10-03。主工程 Godot 4.7.2；本组已直接接入生产战斗播放器，供统筹整合。`human_signoff=false`，未更新 current/latest，未导出微信包，未声称微信模拟器或真机通过。

## 实际变更

- 第三阶段战斗由纯色空场改为冷青石厅：错缝灰蓝墙、旧金属柱箍、分块拱券、内凹门槛、透视大石板、墙脚暗部和人物接触阴影。两盏已有实体火把对应局部暖金光池。舞台为原生可编辑绘制代码；复用 tower_v01 的 floor_1 / torch，没有新增栅格、生成提示词或新图像来源。
- 保留正式公主/13 敌人的动作帧、方向、持物、动画事件与时间轴。人物改为使用各自已发布 anchor 落在同一地面；根据已有透明画布比例调整舞台显示跨度，使重甲精英/Boss 体量合理。未修改角色原画、生产 manifest 或敌人播放器。
- 已提交 cue 驱动局部金色剑痕、反击碎光、致死地面碎尘、实际格挡弧、盾壳盾形、蓄焰/狂怒上升火痕、突袭夹击标记、石甲地面碎片、反伤环和增伤弧。机制来源放在正确施放者位置；零收益格挡无额外护盾图形。
- 伤害数字在角色轮廓上方，敌方暖白、玩家受伤浅赤；同一承受者仅保留最近数字，短回合不堆叠。下方原机制事实文本继续保留。没有增加战报事件、延长演出或改变音效节流。
- 减动效继续直接进入安静战报；修复“已跳过/已结算后才开启减动效”未切换到安静战报的边界问题。暂停、跳过、只读回放与只结算一次均保留。
- 旧局 `combat_presentation.gd` 仅增加同一石厅背景绘制，保留旧局原有表现/时序/结果页；不是把第三阶段正式动画换为旧静态图。

第一轮实际截图发现石材过密与受击数字压脸，已改为大石板透视并抬高数字；随后按 13 敌实际小尺寸复核并调整精英体量。第三阶段静态环境仅在布局尺寸改变时重绘，瞬态反馈随回放时间绘制，不创建无限累积的粒子/节点。

## 文件清单与运行入口

| 文件 | 本组用途 |
| --- | --- |
| `scripts/ui/art_polish_c_stage.gd` | 新增原生舞台及战报反馈 helper；背景/前景分层 |
| `scripts/ui/phase3_combat_player.gd` | 引用 helper、按锚点布局、显示比例、数字/机制反馈、减动效边界修复 |
| `scripts/ui/combat_presentation.gd` | 本组仅两处插入：preload helper 与背景绘制；已有 auto_close 改动保留 |
| `tools/art_polish_c_play.gd` | 专属可玩入口，真实主 UI、C0 seed42、新隔离存档 |
| `tools/art_polish_c_capture.gd` | 13 敌 × 320/390/540，正常与两类减动效，布局/只读/六秒检查 |
| `tools/art_polish_c_host_capture.gd` | 继承首战回归的隔离副本；只适配输出与 profile、纠正旧 provenance 版本文字 |
| `tools/art_polish_c_boss_capture.gd` | 继承公开路线；牛头 / `--golem`，独立 profile 与证据路径 |
| `tools/art_polish_c_motion_capture.gd` | 史莱姆、蓄焰术士、魔像的实际墙钟原速 / 0.25× 视口捕获 |
| `tools/art_polish_c_timing_test.gd` | 原时序套件的隔离入口，不改断言 |
| `tools/art_polish_c_legacy_test.gd` | 原旧局套件副本，仅 profile/输出路径适配，不改语义断言 |
| `tools/art_polish_c_verify.ps1` | 统一复现，各次 Godot 均经公共锁，Group=art-polish-c |
| `tools/art_polish_c_review.py` | 证据拼图、WebP、逐帧 HTML、源码压缩估算；不生成游戏资产 |
| `docs/ART_POLISH_C_DELIVERY.md` | 本交付 |

Godot 自动生成的上述脚本 `.uid` 与脚本同行保留。证据统一在 `build/verification/art-polish-c/`；锁日志在 `build/verification/phase3/08-parallel/art-polish-c/`。

可玩入口（正式游戏逻辑，可手动移动/战斗；保持独立存档）：

```powershell
./tools/phase3_v05_godot_locked.ps1 -Group art-polish-c -Label play -RunTimeoutSeconds 7200 -GodotArgs @('--script','res://tools/art_polish_c_play.gd')
```

该入口已通过启动 smoke。请在其他组 Godot 工作结束后运行，退出窗口才释放公共锁。正式主游戏亦已通过两个播放器引用本组 helper，无需修改 map_screen 或额外开关。

## 图像证据与审阅

- [可暂停、0.25×、逐帧的审阅页](../build/verification/art-polish-c/review.html)。包含原图链接、公开路线序列与定时夹具；不是生成效果图。
- 同样 390px 常规样板：[改前](../build/verification/art-polish-c/before/slime_390.png) / [改后](../build/verification/art-polish-c/after/slime_390.png)。另有 320/540 同名对照。
- 13 敌全图联系表：[320](../build/verification/art-polish-c/contact_320.jpg) / [390](../build/verification/art-polish-c/contact_390.jpg) / [540](../build/verification/art-polish-c/contact_540.jpg)。各原尺寸 PNG 在 after/；机制事件额外采样 `*_mechanism_*.png`。
- 真正初始减动效：[320](../build/verification/art-polish-c/reduced_contact_320.jpg) / [390](../build/verification/art-polish-c/reduced_contact_390.jpg) / [540](../build/verification/art-polish-c/reduced_contact_540.jpg)。两演员和瞬态反馈隐藏，完整战报仍可访问。
- 真实首战保存失败后重试：[26 帧回放](../build/verification/art-polish-c/host-slime/replay.webp) / [联系表](../build/verification/art-polish-c/host-slime/contact.jpg)。C0 seed42，生产移动与交易 API。
- 真实第五层牛头：[112 帧回放](../build/verification/art-polish-c/host-minotaur/replay.webp) / [联系表](../build/verification/art-polish-c/host-minotaur/contact.jpg) / [报告与每帧记录](../build/verification/art-polish-c/host-minotaur/results.json)。同一公开路线，包含狂怒、攻击、退场。
- 真实第十层魔像：[119 帧回放](../build/verification/art-polish-c/host-golem/replay.webp) / [联系表](../build/verification/art-polish-c/host-golem/contact.jpg) / [报告与每帧记录](../build/verification/art-polish-c/host-golem/results.json)。保留石甲累计外形、退场残骸及原归途剧情队列。
- 实际墙钟原速/慢速：[魔像 0.25×](../build/verification/art-polish-c/timed/golem_0.25/contact.jpg)、[蓄焰术士 0.25×](../build/verification/art-polish-c/timed/p3_ember_channeler_0.25/contact.jpg)。三敌共 860 张：史莱姆 33/123、蓄焰术士 57/223、魔像 86/338。各 timing.json 记录真实墙钟与回放时间；WebP/HTML 使用记录的帧间隔。模拟已提交战报夹具，不冒充自然路线。
- [旧局 320 实拍](../build/verification/art-polish-c/legacy/fight_320x640.png)，旧局另覆盖 360/540/900 的战斗、胜利、战报。

已实际查看三尺寸全敌联系表、正常/减动效原尺寸、首战/两 Boss 连续序列采样、三敌原速与慢速有序实拍、旧局 320 战斗。[visual_review.json](../build/verification/art-polish-c/visual_review.json) 记录本组审阅状态、运行源码与证据 SHA，提交统筹终审。对方向/握点/动作的资产级审查沿用 A/B 源交付；本组只改变布局与叠加反馈。没有宣称真人连续视频感知或最终真人美术签收。

## 验证结果

所有 Godot 运行均为主工程 4.7.2，经公共锁并使用 art-polish-c 隔离 APPDATA/LOCALAPPDATA。正常渲染捕获，不以 headless 代替图像证据。

| 套件 | 本次结果 |
| --- | --- |
| 13 敌 × 三尺寸：布局、六秒目标、暂停、跳过只读、像素冻结、初始/中途减动效 | 438 检查，0 失败；mechanisms-final 日志（含三变体实际触发机制断言） |
| 原回放时序 | 20 检查，0 失败；timing-final 日志 |
| 原敌人播放器协议 | 210 检查，0 失败 |
| 真实首战保存失败/重试/关闭后只读/重新加载 | 9 检查，0 失败 |
| 真实第五层公开路线与回放 | 201 检查，0 失败 |
| 真实第十层公开路线与回放/结局队列 | 374 检查，0 失败 |
| 原旧局战斗 UI、失败重试及减动效 | 100 检查，0 失败；legacy-isolated 日志 |
| 原速/0.25×实际定时捕获、专属入口启动 | 正常完成，无脚本/引擎错误 |

套件检查范围重叠，未相加作为唯一测试数量或美术质量证明。两 Boss 夹具动画纹理解码峰值分别为 20,054,016 / 20,512,768 bytes，敌人 LRU 峰值均 7,667,712 bytes。渲染器总峰值更高，详见 results.json；这些不是手机内存或整机 RAM 指标。

保留失败日志：首轮 helper 的 GDScript 类型推断错误、慢速工具 delta 的类型推断错误、旧局套件对旧隔离目录的拒绝。已修正类型/新增本组隔离副本，最终对应运行通过。系统根证书库提示单独保留，不计作通过的脚本错误。早期蓄焰夹具两回合即击败敌人，未触发第三次反击；现仅降低该夹具的测试攻击并加真实触发断言，机制截图与定时序列已重拍，没有修改玩法数值。早期减动效截图曾只检查“跳过后开启”，现已由真正初始减动效截图替换，最终断言同时覆盖两条路径。

复现：

```powershell
./tools/art_polish_c_verify.ps1 -Capture -Timed
# 使用已配置带 Pillow 的 Python，重建证据页：
python tools/art_polish_c_review.py
```

`--before` 仅用于修改前快照，当前代码不要用它覆盖已有 before/。公开路线连续帧按回放时间 10/20FPS 采样；timed/ 则另记录真实墙钟间隔，两种证据已区分。

## 包体、保留边界与统筹事项

新增/替换 PNG：**0**。复用已发布 `assets/environment/tower_v01/textures/floor_1.png` 和 `torch.png`，不退休任何资产。新增 helper 源码约 9.4 KiB、zlib 约 3.4 KiB；三份完整运行脚本（含大量既有代码）的 zlib 总量约 16 KiB。详见 [source-audit.json](../build/verification/art-polish-c/source-audit.json)。这只是源码压缩估算，**不是实际微信 ZIP 净增**，最终由统筹 Godot 4.6.1 隔离构建测量；预计明显低于 C 组 0.35 MiB 建议额度。

没有写入敌人播放器、A/B 资产/manifest、map_screen、核心结算、战报、存档协议、玩法数值、构建脚本或 current/latest。既有大量未提交内容保留；没有 reset/clean。`combat_presentation.gd` 中已有的 auto_close 行在工作开始时已存在，不能归因于本组。

本组不需要跨所有权代码补丁。统筹需：

1. 整合 A/B 最新正式帧后，再看本组 13 敌联系表，重点复核 `STAGE_SPANS` 对更新轮廓的适配；不要更改动画原始锚点。
2. 用既定 4.6.1 微信源码/压缩纹理重跑 C 的手机截图及首战/两 Boss 回归，实测包体与客户端性能后再发布 current/latest。
3. 本组证据与工具留在源工程，不将 build/verification 当运行资源。无需新增白名单、修改预算或退休原图。

待后续整体验收：真人对力度与节奏的签收、手机性能/微信客户端、与 A/B 最终角色精修混合后的终审。没有把这些项目宣布完成。
