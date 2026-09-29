# M1 集成前独立复核

日期：2026-09-29。**当前结论：最终修订版通过本轮独立复核，68 checks、0 failures，退出码 0。R01 保存失败提示、R02 后台 Tab 焦点、R03 旧版入口均已修复并验证，本轮范围内无剩余阻断项，可交统筹整合。** QA 只复制授权修订，不自行修改产品实现；整合后完整七组回归由统筹执行。

## 当前最终候选与结果

| 文件 | 最终 SHA256 | 来源 |
| --- | --- | --- |
| `scripts/ui/map_screen.gd` | `D2DCE9AA6943466CBC33838203FB99F76260836269174E3C9ED19D98DF76BBB7` | 0a52 最终保存提示 / 焦点修订 |
| `tests/ui_polish_m1_runner.gd` | `9B0066C22FF1A3FE45E829D7B7E2AA5CEF8F713F69391BA141AF43AE184B4EF0` | 0a52 最终作者测试；本轮未重复执行 |
| `scenes/map_prototype.tscn` | `F77CA3F94BC2AB18B8E08FF96633AD820175ED7E5328260C61D042AC971347E1` | 0a52，未变 |
| `assets/ui/map_theme.tres` | `DD30E2BCFCE96AE51A2BD4A3544BBE314F6A211D65F2DC6F2A888DC6E91FE078` | 0a52，未变 |
| `scripts/ui/main.gd` | `2C1004834CAFD2EF34C91A4E31661330293A304BA13434ED012B934BC965F0C4` | 经授权从统筹原目录只读复制的一行 bool 修复 |

执行工作副本仍为 `.`，输出根目录仍为 `./build/verification/m1_review`。最终清单另见 `candidate-final-hashes.json`。

| 最终复核 | 独立结果与证据 |
| --- | --- |
| R01：540×960 / 360×640 × 探索 / 选敌 / 待确认，六格矩阵 | 六格全部通过。实际阻塞临时存档写入后，独立“存档异常”区域始终可见，窄屏错误正文两行完整，待确认面板不会遮挡它。`screenshots/final_540_save_error_*.png`、`final_360_save_error_*.png` |
| R02：真正路由的 Tab 和 Shift+Tab | 详情、商店各正向 8 次和反向 8 次，32 次均未进入后台控件；Enter 打开、Escape 关闭及发起焦点恢复通过。日志记录每次真实 focus owner。`screenshots/final_360_target_tab.png`、`final_360_target_shift_tab.png`、`final_360_shop_tab.png`、`final_360_shop_shift_tab.png` |
| R03：真实旧版往返 | 菜单按钮进入旧卡片，旧卡片返回按钮回到新地图，均实际执行。离开地图恢复 540×960 逻辑伸缩，返回后为物理 360×640，再退出恢复原设置。`screenshots/final_360_legacy_after_map.png`、`final_360_returned_map.png` |

最终独立日志为 `logs/final_risks.log`（**68 checks，0 failures**）、`logs/final_risks.stderr.log`（仅系统证书提示，无脚本错误），结构化证据为 `final_risks_observations.json`；最终截图 **12 张**，统一 `final_` 前缀。已逐项检查保存提示截图、面板焦点截图和旧版修复渲染。保存错误可见性检查同时验证屏幕/祖先裁切与绘制层次；新错误区域绘制在 overlay 之后，因此不会误把“非 overlay 子节点”当成被遮挡。

最终复现：使用文末相同隔离环境，以 `-- --final-risks` 启动 `tests/ui_polish_m1_review_runner.gd`。该模式只运行这三项约定风险复核，不重跑原七组、作者 260/296 项或额外扩展测试。作者报告的最新七组 4,904、M1 headless 260、图形 296 全通过是上游报告，本文不记为 QA 本轮独立执行。

```powershell
Set-Location '.'
$reviewRoot = Join-Path $PWD 'build/verification/m1_review'
$env:APPDATA = "$reviewRoot/appdata"
$env:LOCALAPPDATA = "$reviewRoot/localappdata"
$arguments = @('--path', '.', '--rendering-method', 'gl_compatibility', '--position=-2000,-2000', '--script', 'tests/ui_polish_m1_review_runner.gd', '--', '--final-risks')
$reviewProcess = Start-Process -FilePath 'godot' -ArgumentList $arguments -WorkingDirectory $PWD -WindowStyle Hidden -PassThru -RedirectStandardOutput "$reviewRoot/logs/final_risks.log" -RedirectStandardError "$reviewRoot/logs/final_risks.stderr.log"
$reviewProcess.WaitForExit()
"final risks exit=$($reviewProcess.ExitCode)"
```

M0 原始基线完全保留。原候选报告为 `review_initial_report.md`，四份初始候选快照位于 `candidate_initial/`；旧失败日志保留并另存 `logs/review-before-fixes.log` 与 `logs/review-before-fixes.stderr.log`。**下文均为历史初审及修复过程记录，不是当前阻断结论。**

## 历史初审：候选与隔离范围

- 只读来源：`.`。
- 独立测试副本：`.`。
- 经补充分派授权，仅将下列四个候选文件原样复制到测试副本。没有写来源副本或 `.`，没有修改核心、项目配置或其他产品脚本。
- 本批独立新增 `tests/ui_polish_m1_review_runner.gd`（及其 UID）、本文档。原有候选测试文件没有调整断言。
- M0 报告、24 张截图与日志均保留；被覆盖的 M0 `map_screen.gd` 和 `map_prototype.tscn` 另存于 `build/verification/m1_review/m0_sources/`，不能再在 M1 产品代码上重跑 M0 harness 并覆盖原始证据。

候选 SHA256（本次执行的固定快照）：

| 文件 | SHA256 |
| --- | --- |
| `scripts/ui/map_screen.gd` | `1AB7680245E3ECE1D3F11B24ABF2506CDD81638CCFE8A77296905FAAFF0638E6` |
| `scenes/map_prototype.tscn` | `F77CA3F94BC2AB18B8E08FF96633AD820175ED7E5328260C61D042AC971347E1` |
| `assets/ui/map_theme.tres` | `DD30E2BCFCE96AE51A2BD4A3544BBE314F6A211D65F2DC6F2A888DC6E91FE078` |
| `tests/ui_polish_m1_runner.gd` | `97B185A7C82054C909167C0FECDD0ADB86D2DA6B1A21CD33B6F5F35ABF0D9729` |

输出根目录 **R**：`./build/verification/m1_review`。下文所有日志/截图路径均相对此根目录。

- 日志：`R\logs\`；截图：`R\screenshots\`，共 22 张 PNG。
- 数值与断言记录：`R\review_observations.json`、`R\write_observations.json`、`R\read_observations.json`。
- 候选哈希：`R\candidate-hashes.json`。
- APPDATA：`R\appdata`；LOCALAPPDATA：`R\localappdata`。实际存档位于 `R\appdata\Godot\app_userdata\塔境 · 肉鸽魔塔`。
- Godot：`godot`，4.7.2.stable.official.ed1daf0bf。图形运行采用 GL Compatibility / OpenGL 3.3.0 NVIDIA 616.92 / RTX 5070；辅助进程隐藏并置于屏幕外。

## 历史初审：缺陷证据（最终均已修复）

### R01 / P1：保存失败在选怪与待确认时不可见（原候选阻断，现已修复）

**实际触发文件写入失败，没有直接伪造错误文案。** 在隔离 user:// 下创建 `review_write_blocked_360.json.tmp` 目录，使 `SaveStore.write()` 无法按同名文件打开临时存档。用该路径创建 `MapEngine`，开启持久化并开始 seed 42。生产 `save_game()` 失败，`game.save_error` 为“无法写入存档：请检查存储空间或浏览器权限。”。

| 场景 | 540×960 | 360×640 |
| --- | --- | --- |
| 普通探索，未选敌人 | 错误可见 | 错误开头可见，后半句省略 |
| 选中敌人 | 错误可见 | **错误完全不可见** |
| 打开敌人待确认面板 | **错误完全不可见** | **错误完全不可见** |

证据：`screenshots/360_save_error_enemy.png`、`540_save_error_pending.png`、`360_save_error_pending.png`；对照为 `540_save_error_explore.png`、`360_save_error_explore.png`。`review_observations.json` 同时记录非空 `save_error` 与实际 UI 状态；`logs/review.log` 的三个保存提示可见性断言失败。

定位：`scripts/ui/map_screen.gd:451–456` 仅将错误赋给 `hint`，compact 敌人摘要拼接的是 `copy`；`:343` 又隐藏 `detail_hint`。此外，overlay 覆盖目标摘要，`:396` 附近的 `_populate_sheet()` 没有放置保存失败信息。这会使玩家在尚未保存成功时继续挑战/交易而不知道进度有风险。

建议由实现归属方提供始终可见的保存状态/错误区域，既不覆盖战斗致死信息，也不被详情或待确认面板遮挡。修复后至少重跑此六格矩阵，并验证成功写入后错误能清除。测试副本未自行修改实现。

### R02 / P2：Tab 焦点进入面板背后的禁用按钮（原候选缺陷，现已修复）

复现：360×640 地图，聚焦“详情”并按 Enter；面板开启且“返回地图”获得焦点。继续按 Tab，焦点会依次进入面板后方的“营地”“详情”“← 左”等已禁用按钮。商店待确认时，从关闭按钮按 Tab 同样会进入这些控件。

测试经 `Viewport.push_input()` 路由完整按下/松开事件，包含 GUI 焦点处理，没有仅直接调用 `_input()`。日志记录了真实 focus owner 的节点路径、按钮文字、`disabled=true`、可见状态。13 次焦点边界断言失败属于同一类缺陷，不是 13 个独立缺陷。

证据：`logs/review.log` 中 `FOCUS` 记录，以及 `screenshots/360_detail_focus.png`、`360_shop_keyboard_focus.png`（看不到活动面板中的焦点框）。

定位：`scripts/ui/map_screen.gd:500–508` `_set_map_input()` 只设置 disabled，没有限制这些控件参与键盘焦点遍历，也没有建立面板内的焦点循环。建议在开启面板时排除底层控件的 focus mode 或显式约束焦点邻居，并在关闭时恢复。

已通过的相关路径：Enter 开启详情、Escape 关闭详情、Enter 关闭详情、关闭后恢复原按钮焦点；待确认 Escape 正确取消并恢复发起按钮焦点；面板打开时方向键不移动玩家。未观察到由此次焦点逃逸造成的重复结算。

### R03 / P1：旧版卡片入口加载失败（既有问题，本次暴露并已修复）

从实际 `scenes/map_prototype.tscn` 菜单点击“打开旧版十层卡片原型”，场景切到 `scenes/main.tscn` 后空白，返回地图按钮不存在。Godot 报真实脚本错误：

```text
SCRIPT ERROR: Parse Error: Cannot infer the type of "won" variable because the value doesn't have a set type.
at: GDScript::reload (res://scripts/ui/main.gd:390)
```

定位：`scripts/ui/main.gd:390`，`var won := game.run.result == "victory"`。该文件不属于四个候选，本次没有变化，`git diff -- scripts/ui/main.gd` 为空。因此不归因于 M1 布局改动，但旧版入口兼容验收当前不能通过。

证据：`logs/review.stderr.log`、独立复现的 `logs/legacy-check-only.log`，以及 `screenshots/360_legacy_after_map.png`（空白内容）。独立编译命令退出码为 1：

```powershell
& 'godot' --headless --path . --script scripts/ui/main.gd --check-only
```

**缩放恢复本身有通过证据**：离开地图时恢复为原先 `content_scale_mode=1`、`content_scale_size=(540,960)`，旧版窗口逻辑画布也回到 540×960。由于旧版脚本无法加载，真实“旧版按钮返回地图”路径被阻断；harness 随后明确使用直接 `change_scene_to_file` 恢复地图，验证重新进入时为物理 360×640，再退出时也恢复原缩放。此恢复步骤不能冒充正常旧版往返操作通过。

修复应由统筹另行授权对应文件负责人处理，本测试未修 `main.gd`。原有 4,904 项及编辑器 import 通过，并不覆盖此旧版 UI 脚本实际场景加载。

## 已通过范围与 M0 对照

| 复核内容 | 独立结果 |
| --- | --- |
| 最小窗口真实尺寸 | 物理/逻辑均 360×640；M0 的 2/3 全局缩放已解除 |
| 方向按钮与字体 | 方向按钮高 44 物理像素，摘要 15px；比 M0 的 32px 按钮、约 10px 摘要明显改善 |
| 双行敌人摘要 | seed 42 自然锈剑骷髅，以及受控的 slime/skeleton/bat/sentinel/warlock/knight 全部 2 行、可见 2 行，240×39 内容区，未发现截断；地图与损失/致死摘要同时可见 |
| 详情打开/关闭 | Enter、Escape 的开关与返回焦点通过，底层移动拦截通过；Tab 限制见 R02 |
| 奖励待选存档 | 进程 A 保存二选一；独立进程 B 重新载入后完整 state 与预期 JSON 一致；待选面板可操作；选择嗜血剑精确增加 25 金币，结算后持久化 state 与再次加载一致 |
| 商店待选存档 | 进程 A 保存三件待购商品；独立进程 B 载入后完整 state 一致，商品不刷新；购买淬钢刃精确扣 42 金币，清除 pending，保存后的状态一致 |
| 窄屏待选面板 | choice / shop 无横向容器溢出，固定关闭按钮可见；正文和商品独立滚动 |
| Window 生命周期 | 地图退出恢复原设置，重新进入关闭伸缩，再退出恢复；真实旧版回程被 R03 阻断 |

对应截图：`360_explore.png`、`360_natural_skeleton.png`、六张 `360_summary_*.png`、`choice_before_process_exit.png` / `choice_after_process_restart.png`、`shop_before_process_exit.png` / `shop_after_process_restart.png`、`360_returned_map.png`。

M0 B01（首屏看不到损失）在本次六种普通怪最小窗口样本中已改善；B02（详情推动整页地图）改为独立展开面板，关闭可恢复地图与焦点，符合最小窗口可遮挡地图的计划；B03（最小窗口缩小所有字体按钮）明显改善。M0 B04 的致死原生弹窗风格、B05 宽窗口侧栏，本轮没有重复视觉验收，不能仅据实现聊天截图记为独立通过。窄屏精简摘要不直接显示全部受伤/奖励信息，但展开详情仍保留；全面页面风格属于后续阶段。

## 执行结果与日志分类

| 执行 | 结果 | 日志 |
| --- | --- | --- |
| 候选资源导入 | 退出 0，约 3.26 秒自行结束 | `logs/import.log` |
| 独立布局 / 焦点 / 错误提示 / 场景复核 | **65 checks，18 failures，退出 1** | `logs/review.log`、`logs/review.stderr.log` |
| 进程 A 写待选存档 | 4 checks，0 failures，退出 0 | `logs/write.log`、`logs/write.stderr.log` |
| 进程 B 读档及结算 | 16 checks，0 failures，退出 0 | `logs/read.log`、`logs/read.stderr.log` |
| 旧版 UI 单独编译 | 退出 1，main.gd:390 编译错误 | `logs/legacy-check-only.log` |

独立脚本共 **85 checks，18 failures**，其中包含 22 张 PNG 保存断言。失败归并为 R01 三次、R02 十三次、R03 两次。没有把失败改为预期通过。此次按新增风险选取验证，没有机械重跑原有七组 4,904 项或候选 78/98 项；前者是 M0 已执行的结果，后者是实现聊天报告的结果，均不能替代这里的失败记录。

证书 store 提示仍为环境日志。`review.stderr.log` 中 `main.gd:390` 是未解决的真实产品脚本编译错误。开发独立 harness 时曾有一次插入记录函数导致局部变量作用域错误，已修复，保留于 `logs/harness-initial-compile.stderr.log`；初稿未处理空返回按钮导致的 Nil 错误保留于 `logs/review-initial.stderr.log`，最终 harness 已用失败断言并明确恢复路径取代该崩溃。最终运行没有独立 harness 的 SCRIPT ERROR。

## `--import` 是否需要 `--quit`

本机 Godot 4.7.2 的 `--help` 原文：`--import ... waits for any resources to be imported, and then quits.`，已保存至 `logs/godot-help.log`。M0 和本次实际 `--headless --editor --import` 均自行退出，**不需要额外 `--quit` 才能自动结束**。保留 M0 历史报告原命令，不将其误记为阻塞命令。单独 `--editor` 没有同样保证。

## 复现（本测试副本 PowerShell）

```powershell
Set-Location '.'
$engine = 'godot'
$reviewRoot = Join-Path $PWD 'build/verification/m1_review'
New-Item -ItemType Directory -Force -Path "$reviewRoot/appdata", "$reviewRoot/localappdata", "$reviewRoot/logs", "$reviewRoot/screenshots" | Out-Null
$env:APPDATA = "$reviewRoot/appdata"
$env:LOCALAPPDATA = "$reviewRoot/localappdata"
foreach ($phase in @('review', 'write', 'read')) {
    $arguments = @('--path', '.', '--rendering-method', 'gl_compatibility', '--position=-2000,-2000', '--script', 'tests/ui_polish_m1_review_runner.gd')
    if ($phase -ne 'review') { $arguments += @('--', "--$phase-saves") }
    $reviewProcess = Start-Process -FilePath $engine -ArgumentList $arguments -WorkingDirectory $PWD -WindowStyle Hidden -PassThru -RedirectStandardOutput "$reviewRoot/logs/$phase.log" -RedirectStandardError "$reviewRoot/logs/$phase.stderr.log"
    $reviewProcess.WaitForExit()
    "$phase exit=$($reviewProcess.ExitCode)"
    Get-Content "$reviewRoot/logs/$phase.log" -Tail 1
}
```

保持 write → read 顺序，read 会真正领取奖励/购买，不能跳过 write 后连续重复 read 来期望待选状态仍未消费。所有可写存档和刻意阻塞目录仅位于隔离验证目录。独立脚本使用路由键盘事件与实际按钮信号、真实保存与重新启动进程，但不等同于人工鼠标试玩、手机触控或导出包验收。

## 追加：统筹修复旧版入口后的复核

补充授权允许只读复制 `./scripts/ui/main.gd` 到 QA 副本。复制后 diff 仅有第 390 行 `var won := ...` → `var won: bool = ...`，没有其他玩法改动。

- 修复前 SHA256：`9EA6EEC1BC99074ADB5A370CAA0B658955CCD63FD44681D13424C2D794BBB4BE`，源文件保存在 `R\m0_sources\main.gd`。
- 修复后 SHA256：`2C1004834CAFD2EF34C91A4E31661330293A304BA13434ED012B934BC965F0C4`。
- `logs/legacy-check-only-fixed.log`：独立编译退出 0。
- `logs/scene_fixed.log`：12 checks，0 failures，退出 0；stderr 仅证书提示。
- 截图：`screenshots/360_legacy_after_map_fixed.png`、`360_returned_map_fixed.png`。前一张确认旧版菜单真实渲染并有返回按钮，后一张确认返回后的新地图。
- 此次使用真实旧版返回按钮，未走 harness 恢复分支。地图 → 旧卡片时恢复原 540×960 伸缩；旧卡片 → 新地图后为物理 360×640，再退出时恢复原设置。R03 的兼容路径已通过。

复现方式：使用上节相同环境，以 `-- --scene-only` 启动独立复核脚本。它只运行场景往返，写入 `scene_fixed_observations.json`，截图后缀 `_fixed`，不覆盖原失败证据。
