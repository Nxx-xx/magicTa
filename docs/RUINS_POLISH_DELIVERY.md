# 三座遗迹精修交付

2026-10-04（Asia/Hong_Kong）。已接入正式地图使用的 `scripts/ui/phase3_ruin_art.gd` 和 accepted `assets/environment/ruins/phase3/runtime_v02.json`，沿用 `textures/v02/` 路径白名单。预算口径已根据用户提醒与最新构建报告更新为总包30 MiB、主包4 MiB。

## 按当前配置重新评估（14:10新导出）

重新读取 `tools/build_wechat.py` 中当前阈值，并从当前并行工作区执行独立导出，未沿用上一份整体包体数字。新快照为 `20261004-141032-081895`，输出目录为 `build/wechat-ruins-polish-reeval`，仍使用命名互斥锁、隔离配置及 `--no-latest`。

| 范围 | 当前实测 bytes | 配置上限 bytes | 剩余 bytes | 结果 |
|---|---:|---:|---:|---|
| 总包 | 20,230,849（19.2936 MiB） | 31,457,280（30 MiB） | 11,226,431（10.7064 MiB） | 通过 |
| 主包 | 2,427,533（2.3151 MiB） | 4,194,304（4 MiB） | 1,766,771（1.6849 MiB） | 通过 |

**重评结论：目前有充足包体空间，遗迹无需为旧20 MiB门槛继续压缩画质或减少动画。** 现有共享底图是消除重复内容的存储优化，保留该方案；256px、15条时间线、75帧位继续完整保留。旧的本项净增≤0只作为最初分配目标的历史对照，不再作为本次整体评估的强制断言；当前以构建配置的30/4 MiB为准，未擅自分配其余任务的共享余量。

遗迹自身压缩条目合计仍为221,109 bytes，比初始基线净减少651,549 bytes；整体快照变化单独计算。新包内全部遗迹载荷与已通过行为、手机viewport及包内读取检查的版本逐字节一致，当前遗迹源码也与新导出暂存源一致，因此不重复运行未受影响的玩法测试。新包文件SHA256、两层ZIP CRC、78个遗迹PNG引用与旧重复载荷排查再次通过。

证据：[本次构建报告](../build/wechat-runs/20261004-141032-081895/build-report.json)、[按当前配置的审计](../build/verification/ruins-polish/reevaluation/package-audit.json)、[运行资源一致性](../build/verification/ruins-polish/reevaluation/runtime-consistency.json)、[本次独立归档](../build/wechat-runs/20261004-141032-081895/TowerRealm-WeChat.zip)。未改共享预算、current/latest，未上传或真机验证。以下保留首次交付的截图、验证与历史快照。

## 视觉与动画

- 誓约遗迹：窄长断裂石碑、剑形青色誓约纹、双石脚；移除三联龛与宽圆台轮廓。
- 熔炉遗迹：低宽炉膛、侧烟囱、铁砧与工具，暖炉火定位于炉口；底座为矩形踏步。
- 圣所遗迹：展开的庇护屋顶、悬灯与内凹座椅、浅弧形门阶；移除辐射状圆台。
- 材质保持冷青灰石材、旧金饰边与暖灯火。可交互态有缓慢光源变化；选择后保留对应剑/盾/治疗/钱币结果符号及触发圈；耗尽态熄灭动画光并降低亮度。

新母版由内置 image_gen 参考原三张母版分别生成；全尺寸母版、三份可编辑 Godot 场景、提示词及旧帧备份在 [source/polish_v03](../assets/environment/ruins/phase3/source/polish_v03/README.md)，由 `.gdignore` 排除导出。没有以程序几何替代建筑原画；光焰/符号/触发圈沿用已有原生动画实现，校准位置与颜色。

完整保留 **15条时间线、75帧位、9个选择分支、fps、loop、持续时间、256×256运行尺寸、(128,224)脚点**。母版烘焙固定底图3张，75个原路径PNG保存动画覆盖层；读取器按原时序合成并缓存最终256px纹理，耗尽态对底图应用固定色调。缓存上限仍为6 MiB。既有 `observe()` 提交事件逻辑未改，减弱动效仍跳过结算动画并固定空闲帧。

## 改前改后与手机画面

截图来自真实 `map_screen.gd` / `grid_board.gd` 正式读取链。为同屏对比，使用生成楼层中的受控遗迹摆放夹具；这些截图不是完整游玩通关证据。实际viewport为320×640、390×844、540×960，已断言截图尺寸，没有把大图缩小冒充手机viewport。

| 宽度 | 改前可交互 | 改后可交互 | 改后触发 | 改后耗尽 |
|---|---|---|---|---|
| 320 | [截图](../build/verification/ruins-polish/before/available_320.png) | [截图](../build/verification/ruins-polish/after/available_320.png) | [截图](../build/verification/ruins-polish/after/triggered_320.png) | [截图](../build/verification/ruins-polish/after/spent_320.png) |
| 390 | [截图](../build/verification/ruins-polish/before/available_390.png) | [截图](../build/verification/ruins-polish/after/available_390.png) | [截图](../build/verification/ruins-polish/after/triggered_390.png) | [截图](../build/verification/ruins-polish/after/spent_390.png) |
| 540 | [截图](../build/verification/ruins-polish/before/available_540.png) | [截图](../build/verification/ruins-polish/after/available_540.png) | [截图](../build/verification/ruins-polish/after/triggered_540.png) | [截图](../build/verification/ruins-polish/after/spent_540.png) |

审阅结论：窄石碑、宽炉口和庇护屋顶在三档viewport均可区分；触发帧可见对应盾、剑和治疗符号，耗尽态明显变暗，底座没有漂移或裁边。全部15条动画联系图同时保存于验证目录；包内资源复合后的联系图位于 `packed-runtime/packed_*.png`。

## 验证结果

- [读取器检查](../build/verification/ruins-polish/behavior-result.json)：175项，0失败。覆盖RGBA、全部帧资源、原始清单时序逐项相等、选项触发、重复刷新不重播、回层/读档不重播、只读渲染、减弱动效、稳定脚点、9条结算各至少3个不同可见帧、缓存限制。
- [玩法回归](../build/verification/ruins-polish/gameplay-result.json)：73,268项检查，12,000张生成地图，0失败。沿用已有遗迹测试，只将输出隔离；不宣称真人完整通关。
- [包内运行检查](../build/verification/ruins-polish/packed-runtime.log)：使用匹配导出的Godot4.6.1，只提取包内正式reader、manifest、remap和ctex，**没有源PNG回退**；全部75帧合成成功并输出15条联系图。
- [保留项哈希](../build/verification/ruins-polish/preservation.json)：10项与起始审计的暂存源一致，包括遗迹规则、物品奖励处理、遗迹数据、选项面板、共同地图脚本、三枚交互图标。未修改存档、剧情文案及顺序、全局项目配置或共同打包工具。
- 所有Godot导入、烘焙、测试、导出都经 `MagicTa_Phase3_Parallel_Godot` 命名互斥锁，APPDATA/LOCALAPPDATA位于本项验证目录。日志仅有环境已知的Windows根证书读取错误；测试无脚本错误。源图检查出现的raw-image警告仅属于检查工具，正式reader的导出路径另经包内测试验证。

## 独立包体与归因

独立输出：[build/wechat-ruins-polish](../build/wechat-ruins-polish/)。归档：[TowerRealm-WeChat.zip](../build/wechat-runs/20261004-135330-025700/TowerRealm-WeChat.zip)。[构建报告](../build/wechat-runs/20261004-135330-025700/build-report.json)；[本项压缩条目审计](../build/verification/ruins-polish/package-audit.json)。没有覆盖current/latest指针，没有上传发布。

基线为 `20261004-134105-179524`。以下纹理数字统计实际 `engine/godot.zip` 内对应PNG remap与ctex压缩条目，不使用源PNG大小推算。

| 项目 | 基线 bytes | 本次 bytes | 净变化 bytes |
|---|---:|---:|---:|
| 本项运行纹理及remap | 870,692 | 218,731 | **−651,961** |
| 正式读取器压缩条目 | 1,254 | 1,622 | +368 |
| 正式manifest压缩条目 | 712 | 756 | +44 |
| **本项合计** | **872,658** | **221,109** | **−651,549** |

本项净增预算≤0：**通过**。旧的75张完整底座帧被原路径覆盖层替换；完整备份只在忽略导出的source目录。包内对全部ctex进行旧载荷哈希排查，重复旧纹理数量为0；运行只增加3张共享底图，没有牺牲256px分辨率，没有修改全局质量策略。

整体并行快照为 **20,211,652 bytes（约19.2753 MiB）**，主包 **2,427,533 bytes（约2.3151 MiB）**。本次构建报告 `package_budget` 已记录最新项目预算：总包 **30 MiB（31,457,280 bytes）**、主包 **4 MiB（4,194,304 bytes）**；总包余量为 **11,245,628 bytes（约10.7247 MiB）**，两项均通过。此预算与 [WECHAT_TEST_BUILD.md](WECHAT_TEST_BUILD.md) 一致，是本地构建预算，不代表已核实该AppID实际上传额度。

启动委派中20 MiB及本项净增≤0为旧分配口径；本项也已达到该更严格目标。审计保留旧20 MiB下759,868 bytes余量作为历史对照，不再将20 MiB描述为当前总包门槛。整体快照较基线减少626,317 bytes，**与本项净变化分开报告，不将其他并行工作或ZIP结构差异归因于本项**。本聊天未修改共同预算配置。

报告全部文件SHA256、引擎ZIP及外层ZIP CRC均通过；78个本项PNG引用（3底图＋75覆盖层）的remap/payload齐全，source和本项工具未导出。未做微信开发者工具上传或物理手机真机验证。

## 本项修改范围与重跑

正式范围：`assets/environment/ruins/phase3/`、`scripts/ui/phase3_ruin_art.gd`。专用工具：`tools/ruins_polish_*`。验证输出：`build/verification/ruins-polish/`。

烘焙、导入、行为/玩法测试和截图通过 `tools/ruins_polish_locked.ps1` 指定对应GD脚本；独立导出使用 `tools/ruins_polish_package.ps1`，其内部执行用户指定appid、高性能iOS模式、`--output-folder wechat-ruins-polish --no-latest`。`ruins_polish_package_audit.py` 对本次明确的两份快照进行压缩条目比较并准备包内验证项目，随后运行 `ruins_polish_packed.ps1`。
