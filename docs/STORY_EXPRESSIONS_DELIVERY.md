# 剧情人物表情差分交付

2026-10-04，当前本地 checkout。公主、王子、魔王共五个局部表情已接入正式剧情入口；原立绘、故事文本、顺序、事件标识及结局揭示插画保留。

## 按当前配置重新评估包体

按用户最新要求，本报告采用 `tools/build_wechat.py` 当前配置：**总包 30 MiB（31,457,280 bytes），主包 4 MiB（4,194,304 bytes）**。这是项目本地构建预算，不等同于已确认的该 AppID 平台上限。本任务没有修改该工具或预算。本项原分配 **64 KiB（65,536 bytes）**仍满足，无需用新增余量扩大资源。

| 项目 | 实际字节 | 当前配置/分配 | 剩余字节 |
| --- | ---: | ---: | ---: |
| 独立包整体快照 | 20,230,848 | 31,457,280 | 11,226,432 |
| 主包 | 2,427,533 | 4,194,304 | 1,766,771 |
| 本项压缩条目净增量 | 29,693 | 65,536 | 35,843 |

整体快照约 **19.2936 MiB**，当前总包余量约 **10.7064 MiB**。主包约 **2.3151 MiB**，余量约 **1.6849 MiB**。初始指令中的 20 MiB 只作为历史参考；此快照相对它仍有 740,672 bytes 余量。

统计口径是导出目录文件字节总和，非外层交付 ZIP 文件大小。独立输出：[build/wechat-story-expressions](../build/wechat-story-expressions/)。构建记录：[20261004-140441-800678/build-report.json](../build/wechat-runs/20261004-140441-800678/build-report.json)，存档：[TowerRealm-WeChat.zip](../build/wechat-runs/20261004-140441-800678/TowerRealm-WeChat.zip)。没有覆盖 `wechat-current` 或 latest 指针，没有上传发布。

### 本项归因

相对指定基线 `20261004-134105-179524`，按实际 `engine/godot.zip` 内各条目的 `compress_size` 计算：

| 本项内容 | 压缩字节净增 |
| --- | ---: |
| 公主警惕 `hero_guarded_v01.png` 的运行 ctex | 6,355 |
| 公主受伤惊愕 `hero_shock_v01.png` 的运行 ctex | 6,517 |
| 王子疲惫 `prince_weary_v01.png` 的运行 ctex | 5,023 |
| 王子冷笑 `prince_sneer_v01.png` 的运行 ctex | 5,223 |
| 魔王严厉 `demon_stern_v01.png` 的运行 ctex | 3,619 |
| 五个纹理 remap | 835 |
| 新 helper 脚本 | 1,991 |
| `campaign_panels.gd` 压缩差额 | 113 |
| `story_intro_stage.gd` 压缩差额 | 17 |
| **合计** | **29,693** |

新增 ZIP 条目头另计 2,242 bytes，连同上述净增共 **31,935 bytes**，仍低于 64 KiB。未移除任何历史资源，也未降低现有纹理质量。三张原立绘及揭示插画的实际运行纹理与基线逐字节相同。

整个并行快照比初始基线减少 607,121 bytes；这包含其他任务的变化，**不归因于本项**。本项自身是正增量。可重复审计：[package-audit.json](../build/verification/story-expressions/package-audit.json)，脚本 [story_expressions_audit.py](../tools/story_expressions_audit.py) 自动读取当前共享配置，不硬编码当前总包阈值。

## 美术和呈现

使用内置 **ImageGen** 的 identity-preserve 编辑模式；先查看三张正式原画后生成，每个变体一条独立编辑请求。保持原人设、发型、服装、脸部朝向和光线，仅改眉眼与嘴部。不是色调滤镜或位置偏移。

| 角色 | 差分 | 使用位置 |
| --- | --- | --- |
| 公主 | 警惕 | 序章追问王室印记、2/4/8/9/10 层疑点与对峙、部分回营对白 |
| 公主 | 受伤后的惊愕 | `victory` 背刺已发生后的三句质问 |
| 王子 | 囚禁疲惫 | 序章呼救及印记疼痛、8/10 层和部分死亡回声 |
| 王子 | 人类形态的冷笑 | `victory` 背叛后的五句对白，使用事件 ID 与完整台词双重匹配 |
| 魔王 | 严厉、威胁 | 中段封印裂开、10 层对峙、死亡回声中的威胁 |

王子前期没有冷笑、犄角、黑纹或其他新增怪物特征；实际怪物揭示仍由 `prince_monster_reveal_v01.png` 承担，未替换为历史 `rescue_ending.png`。

资源在 [assets/story/expressions/textures](../assets/story/expressions/textures/)：仅五张 176×188 至 250×219 的小差分，复用原 1024×1536 底图。母版、候选合成、生成文件映射、裁切坐标及完整请求词在带 `.gdignore` 的 [source](../assets/story/expressions/source/) 中；[prompts.json](../assets/story/expressions/source/prompts.json) 记录五条最终生成请求。

提取脚本只裁切已生成画面和处理遮罩边缘，不生成或拼接替代性脸部几何。发梢外的生成背景经原图 alpha 轮廓去除，提取边界柔化。原画大多数实体像素的 alpha 为 252–253，遮罩按这一实际数据处理。已人工查看原尺寸脸部对照及实际导出纹理的手机视口合成，未见方块背景、重复五官或明显接缝。

普通对白原本把整幅人物压到约 160px 高，脸部太小。现在仅三位主角的普通对白复用原画头肩区域，手机头像区为 214px 高；不增加头肩底图纹理。序章构图保留。显式 illustration、老骑士仍使用原尺寸逻辑。

## 接入和回退

- [story_expression_art.gd](../scripts/ui/story_expression_art.gd)：纯显示层，按 1024×1536 母版坐标绘制差分；微信导出缩放底图时仍按相同比例对齐。没有动画计时器或状态写入。
- [campaign_panels.gd](../scripts/ui/campaign_panels.gd)：仅修改 story 呈现和对应插画方法；显式 illustration 优先，`CampKnightArt.PORTRAIT` 修复保留。
- [story_intro_stage.gd](../scripts/ui/story_intro_stage.gd)：沿用现有序章舞台，增加同一差分 helper。
- 未命中事件/台词、缺少差分资源时保留中性头像；换到中性或旁白行时清除旧差分。
- `data/story.json` 与任务起点、指定基线包一致，SHA256：`7f3e51dc3d71577a7751378665acd601a0cdd32f1cc779a46d7009c0bdf08d38`。
- 未改 `map_screen.gd`、`runtime_art.gd`、战斗动作、NPC 资源、全局项目设置或打包策略。保留工作区已有修改，未提交 Git。

## 改前改后证据

截图是正式 `map_screen.gd` / `CampaignPanels.story` 界面，测试仅将实际剧情事件排入队列并选择实际台词，非独立预览 UI，也不声称完整通关。改前对照由启动时保存的呈现代码快照重放，不回滚共享工作区。序章用相同原底图关闭差分层。对照图右侧来自实际导出的 ZIP 运行资源。

| 对照 | 390×700 改前 / 导出后 |
| --- | --- |
| 公主警惕 | [对照图](../build/verification/story-expressions/hero_guarded_comparison_390.png) |
| 王子疲惫 | [对照图](../build/verification/story-expressions/prince_weary_comparison_390.png) |
| 魔王严厉 | [对照图](../build/verification/story-expressions/demon_stern_comparison_390.png) |
| 公主惊愕 | [对照图](../build/verification/story-expressions/hero_shock_comparison_390.png) |
| 王子冷笑 | [对照图](../build/verification/story-expressions/prince_sneer_comparison_390.png) |

完整改前：[before](../build/verification/story-expressions/before/)；桌面资源改后：[after](../build/verification/story-expressions/after/)；导出运行纹理：[packed](../build/verification/story-expressions/packed/)。原尺寸脸部对照为验证目录下五个 `*_face_review.png`。

## 验证结果

所有 Godot 导入、测试和微信导出均持有 `MagicTa_Phase3_Parallel_Godot` 命名互斥锁，使用本项独立 APPDATA、LOCALAPPDATA 和输出目录。

| 验证 | 结果 |
| --- | --- |
| 正式入口实际 320×640 / 390×700 / 540×960 viewport、截图尺寸、按钮边界、无水平溢出、角色回退、揭示时机、状态不变、减弱动效 | **295 检查，0 失败** |
| 原剧情/存档回归 | **71 检查，0 失败** |
| 序章继续/跳过、长文本滚动、普通面板恢复、重试与结局 | **72 检查，0 失败** |
| Godot 4.6.1 从空项目挂载实际 `engine/godot.zip`，加载五张压缩纹理，在 320×640 / 390×700 正式 UI 截图 | **68 检查，0 失败** |
| 原呈现快照重放及截图布局 | **126 检查，0 失败** |
| 五份 remap/payload、源图未导出、三张底图和揭示纹理不变、故事 JSON 不变、两层 ZIP CRC、导出目录全部文件 SHA256/大小 | **通过** |

序章原测试在最宽视口使用 15 次重复文本时可能完整容纳，原“应滚动”断言曾失败；本项隔离测试副本改为 40 次重复，明确制造超长外部文本，并设置实际 viewport。未改正式文案或原测试文件。初次表情截图测试也曾因新事件自动归零而选错台词，测试现先完成事件进入，再定位目标行；上表仅列修复后的结果。

引擎日志中存在 Windows 根证书读取告警，改前和改后均出现；没有脚本解析或资源加载失败。尚未做微信开发者工具上传或真机验证；原生运行时挂载 ZIP 不等同于微信设备验证。

重复执行命令：

```powershell
pwsh -NoProfile -File tools/story_expressions_verify.ps1 -Mode import
pwsh -NoProfile -File tools/story_expressions_verify.ps1 -Mode after
pwsh -NoProfile -File tools/story_expressions_verify.ps1 -Mode regression
pwsh -NoProfile -File tools/story_expressions_verify.ps1 -Mode intro
pwsh -NoProfile -File tools/story_expressions_verify.ps1 -Mode package
pwsh -NoProfile -File tools/story_expressions_verify.ps1 -Mode packed
python tools/story_expressions_audit.py
```

日志及机器可读证据全部位于 [build/verification/story-expressions](../build/verification/story-expressions/)。当前结果无需继续压缩本项资源，也未利用本轮配置增加去掩盖初始 64 KiB 分配超支。
