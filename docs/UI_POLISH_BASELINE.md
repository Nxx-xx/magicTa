# M0 原始界面测试基线

日期：2026-09-29。范围：美化前原始界面与现有回归，不代表 M1 新界面、手机触控、Windows 导出或完整项目已验收。

## 工作副本与交付

- 工作副本：`.`。
- 起点提交：`3d0cd4c38c772b9a7b42173505bd9a858881b659`，并保留分派时已有的 Godot 4.7 项目配置、两份计划文件及 reward 测试 UID。
- 本批仅新增 `tests/ui_polish_baseline_runner.gd`、对应 `.gd.uid`、本文档；未改产品 UI、核心、项目配置、美术或原有测试。未推送、未创建其他聊天。
- 没有编辑 `.`。导入产生的四个既有 `.import` 文件仅有换行变化，已在本工作副本恢复原换行；最终无这些文件的差异。
- 原始 `scripts/ui/map_screen.gd` SHA256：`4702951C9F0B598E2AD729CD6C497FFD13FAE0EB2A7D75088E4AB889370EBE6B`。
- 保留的 `project.godot` SHA256：`9C65BE689B4EF7CDFC7874915420FB7997298F7F2724E9C5998387A23D645E31`。

输出根目录：`./build/verification/baseline`（Git 忽略）。

| 产物 | 输出根目录下路径 |
| --- | --- |
| 所有日志 | `logs\` |
| 24 张真实渲染 PNG | `screenshots\` |
| 控件矩形、裁切、滚动位置、窗口尺寸和弹窗记录 | `observations.json` |
| 隔离 APPDATA | `appdata\` |
| 隔离 LOCALAPPDATA | `localappdata\` |

实际 Godot 用户数据目录：`./build/verification/baseline/appdata/Godot/app_userdata/塔境 · 肉鸽魔塔`。截图脚本额外关闭持久化，并检查用户数据目录在 baseline 内，避免误用玩家存档。现有七组测试的存档同样全部位于该隔离目录。

## 测试结果

引擎：`godot`，版本 `4.7.2.stable.official.ed1daf0bf`。

| 检查 | 结果 | 日志（相对输出根目录） |
| --- | --- | --- |
| 资源导入 | 退出码 0，无资源/脚本导入失败 | `logs/import.log`、`logs/import-engine.log` |
| check_project.py | 通过；原始 30 个源文件，新增 harness 后 31 个 | `logs/check_project.log`、`logs/check_project-final.log` |
| check_maps.py | 4 组布局、安全楼梯、钥匙可达和守卫关系通过 | `logs/check_maps.log` |
| check_random_maps.py | 3 模板 / 8 对称 / 18 地形；352 守卫组合、376 守卫奖励切断关系通过 | `logs/check_random_maps.log` |
| test_runner.gd | 112 checks，0 failures | `logs/test_runner.log` |
| map_test_runner.gd | 274 checks，0 failures | `logs/map_test_runner.log` |
| random_map_test_runner.gd | 3,072 checks，0 failures | `logs/random_map_test_runner.log` |
| keys_test_runner.gd | 954 checks，0 failures | `logs/keys_test_runner.log` |
| monster_ui_test_runner.gd | 24 checks，0 failures | `logs/monster_ui_test_runner.log` |
| reward_test_runner.gd | 459 checks，0 failures | `logs/reward_test_runner.log` |
| reward_ui_test_runner.gd | 9 checks，0 failures；包含 320 / 540 / 900 宽度回归 | `logs/reward_ui_test_runner.log` |
| **原有七组总计** | **4,904 checks，0 failures；全部退出码 0** | 每组另有 `*-engine.log` |
| 新增截图 harness | 70 checks，0 failures；24 次 PNG 保存包含在内 | `logs/ui_polish_baseline.log`、`logs/ui_polish_baseline.stderr.log` |

Python 可选子检查：当前 `python` 缺少 fontTools 和 gdtoolkit，**中文全量字形覆盖及独立 GDScript grammar 检查均 SKIP**；未安装额外依赖。不能沿用历史报告的 688 字覆盖结果作为本次执行结果。Godot 已真实编译执行涉及脚本，截图也显示中文实际渲染，但两者不等于字体全量覆盖检查。

### 错误日志分类

1. **预期损坏存档日志**：`test_runner.log`、`map_test_runner.log` 各一次 `Parse JSON failed ... Expected key`。分别来自 `tests/test_runner.gd:233–235` 写入 `{broken-json`、`tests/map_test_runner.gd:190–193` 写入 `{broken` 后验证备份恢复；两组零断言失败。出现 GDScript backtrace 是错误调用路径，并非脚本崩溃。
2. **环境提示**：`Failed to read the root certificate store` 来自 `platform/windows/os_windows.cpp:2582`，在隔离环境的引擎启动时出现。未据此判为游戏逻辑失败；本批不涉及网络功能验证。
3. **真正脚本错误**：新 harness 初稿有一处 Variant 推断导致的 `dimensions` 编译错误，保留于 `logs/harness_initial_compile.stderr.log`。已给变量显式 `PackedStringArray` 类型并成功重跑；这是 harness 开发过程中的已修复错误，不能与前两种日志混同。最终截图运行 stderr 只有证书提示，无 SCRIPT ERROR、FAIL 或资源加载失败。

## 截图场景与渲染方法

所有 PNG 来自 Godot OpenGL 实际 viewport 的 `get_texture().get_image()`，不是设计稿、图像生成或重绘。渲染环境：OpenGL 3.3.0 NVIDIA 616.92、GL Compatibility、NVIDIA GeForce RTX 5070。辅助进程使用 `Start-Process -WindowStyle Hidden`，窗口放到屏幕外。没有测量帧耗时，也不作性能或 60 FPS 结论。

四种 profile，每种六张，共 24 张：

| profile / 文件前缀 | 实际窗口 | 逻辑画布 | PNG 尺寸 | 含义 |
| --- | --- | --- | --- | --- |
| `540x960` | 540×960 | 540×960 | 540×960 | 项目实际设置，标准窗口 |
| `360x640` | 360×640 | 540×960 | 360×640 | 项目实际设置，画布按 2/3 缩放 |
| `900x960` | 900×960 | 540×960 | 540×960 | 项目保持纵横比；PNG 为游戏内容区域，不含窗口左右留边或 OS 边框 |
| `360x640_unscaled` | 360×640 | 360×640 | 360×640 | 仅 harness 关闭伸缩的额外压力检查，**不代表产品默认最小窗口行为** |

| 文件后缀 | 场景 / 复现 |
| --- | --- |
| `_menu.png` | 无存档菜单，开始按钮和操作说明 |
| `_explore.png` | 用种子 `42` 开始，初始 HP 100、攻击 10、防御 5、金币 0 |
| `_monster_selected.png` | 调用生产 `_select_cell` 查看远处自然生成的锈剑骷髅，不触发远程战斗 |
| `_monster_detail.png` | 同一目标，将滚动容器滚到详情面板完整可见 |
| `_lethal_preview.png` | 自然生成的回溯骑士，受控地将玩家放到其相邻通路后调用生产选择入口；初始属性不变，进入待确认 |
| `_lethal_dialog.png` | 调用生产 `_fight()`，确认出现“这场战斗会死亡”；取消后状态不变 |

明确的受控改动只有截图用玩家位置与 UI 滚动/选择状态；怪物、地形、奖励均来自 seed 42。致死场景不冒充通过正常走路已经到达骑士。每个 profile 独立创建 UI 和游戏状态。

为让 viewport PNG 同时包含生产 `ConfirmationDialog`，harness 设置 `root.gui_embed_subwindows = true`；不修改项目文件。弹窗正文和按钮由实际生产代码创建，OS 原生标题边框不在本批验收范围。取消测试调用生产信号处理路径，没有声称完成真实鼠标或触摸事件试玩。

`observations.json` 的普通控件可见性只计算 viewport 与祖先裁切，不计算模态窗口覆盖、字形溢出或颜色对比。Label / Button / Board 可见矩形两两相交检查在所有采样中均为 0；弹窗内部独立记录，不将正常模态覆盖误判为控件重叠。数值观察和截图检查共同使用，不能仅凭 70 项通过宣称未来布局目标已达成。

## 已发现的原始视觉问题

严重程度采用 P1（影响主要信息获取，应在本轮解决）、P2（可用性/风格问题）。没有发现阻止现有七组测试运行的 P0。

| ID / 严重程度 | 复现与证据 | 位置与后续建议 |
| --- | --- | --- |
| B01 / P1 | 540×960 开始 seed 42，点击远处锈剑骷髅。首屏出现名字/档次，但净损失位于逻辑 y=917、击杀奖励 y=973、守护奖励 y=1000；滚动裁切下沿为 y=862，三者不可见。查看完整详情需滚动 155，此时 498 高地图只露 397。对应 `540x960_monster_selected/detail.png`；默认 360×640 同样存在。 | `scripts/ui/map_screen.gd:230` `_map_view`、`:283` `_describe`、`:436` `_select_cell`。将核心预览移到固定详情区，长文局部滚动；保留分开的两种奖励信息。 |
| B02 / P1 | 进入骑士待确认后，顶部详情/确认面板把地图放到 y=597，498 高地图只露 265；同一详情还在地图下方重复。截图 `540x960_lethal_preview.png`、`360x640_lethal_preview.png`。待确认取消入口可见，方向按钮正确禁用，未发现误结算。 | `scripts/ui/map_screen.gd:230`、`:357`。约束详情高度、避免同一详情重复占据整页；最小窗口按计划采用可关闭展开面板。 |
| B03 / P2 | 默认 360×640 是缩放后的 540×960 画布：48 逻辑像素按钮仅 32 物理像素；14/11 逻辑字号约 9.3/7.3 物理像素。地图图例、怪物属性与操作说明小而难辨。见全部 `360x640_*.png`，尤其 menu / monster_detail。 | `project.godot:23–29` 尺寸/伸缩、`scripts/ui/map_screen.gd:98` 按钮高度、`:230` 图例。需要在新布局中明确逻辑尺寸与物理尺寸，不能用关闭缩放的测试替代产品实测。不是手机触控结论。 |
| B04 / P2 | 致死确认使用灰色默认窗口面板，与蓝黑/暖金主界面不一致；两个按钮仅 40 逻辑像素高（默认最小窗口约 26.7 物理像素）。标题、警告正文与确认/取消均能看见。见 `540x960_lethal_dialog.png`、`360x640_lethal_dialog.png`。 | `scripts/ui/map_screen.gd:453` `_confirm` 及主题创建段。统一弹窗主题与目标尺寸；原生窗口装饰需后续独立核查。 |
| B05 / P2 | 900×960 窗口仍使用 540×960 逻辑区域，详情仍在下方，没有利用额外宽度。`900x960_*` 是内容区截图，窗口尺寸和缩放参数见 JSON。 | `project.godot:29`、`scripts/ui/map_screen.gd:170` `_fit_width`。新宽窗口侧栏需与 stretch aspect 策略一起验证；不能只改变 root.size 就认为测试了 900 宽逻辑布局。 |
| S01 / 压力样本 | 关闭伸缩的 360×640 画布：致死预览时地图完全不可见，返回地图按钮低于可见底边；需整页滚动。`360x640_unscaled_lethal_preview.png`。 | 与 B02 同源。仅记录备选布局压力，不能记为默认 360×640 产品缺陷。 |

已确认的正面基线：默认标准/最小窗口普通探索同时显示完整地图、HP/攻防、金币、三色钥匙和四个方向按钮；没有横向容器溢出；远处选怪不会创建待确认战斗；骑士显示明确致死文字；额外确认及取消均不改变游戏状态。不要把问题描述为“原界面所有控件都随整页滚动”，HUD 和方向按钮已经固定。

## 可复现命令（PowerShell）

以下仅进入本独立工作副本。资源导入应在采集之前运行；引擎扫描可能给忽略目录的 PNG 生成同目录 `.import` 文件，这些不是交付源文件。

```powershell
Set-Location '.'
$engine = 'godot'
$baseline = Join-Path $PWD 'build/verification/baseline'
New-Item -ItemType Directory -Force -Path "$baseline/appdata", "$baseline/localappdata", "$baseline/logs", "$baseline/screenshots" | Out-Null
$env:APPDATA = "$baseline/appdata"
$env:LOCALAPPDATA = "$baseline/localappdata"
$env:PYTHONIOENCODING = 'utf-8'

& $engine --headless --path . --editor --import *> "$baseline/logs/import.log"
if ($LASTEXITCODE -ne 0) { throw 'Godot import failed' }
foreach ($check in @('check_project', 'check_maps', 'check_random_maps')) {
    python "tools/$check.py" *> "$baseline/logs/$check.log"
    if ($LASTEXITCODE -ne 0) { throw "$check failed" }
}
foreach ($test in @('test_runner', 'map_test_runner', 'random_map_test_runner', 'keys_test_runner', 'monster_ui_test_runner', 'reward_test_runner', 'reward_ui_test_runner')) {
    & $engine --headless --path . --script "tests/$test.gd" --log-file "$baseline/logs/$test-engine.log" *> "$baseline/logs/$test.log"
    if ($LASTEXITCODE -ne 0) { throw "$test failed" }
}

$captureArgs = @('--path', '.', '--rendering-method', 'gl_compatibility', '--position=-2000,-2000', '--script', 'tests/ui_polish_baseline_runner.gd', '--', '--capture')
$captureProcess = Start-Process -FilePath $engine -ArgumentList $captureArgs -WorkingDirectory $PWD -WindowStyle Hidden -PassThru -RedirectStandardOutput "$baseline/logs/ui_polish_baseline.log" -RedirectStandardError "$baseline/logs/ui_polish_baseline.stderr.log"
$captureProcess.WaitForExit()
if ($captureProcess.ExitCode -ne 0) { throw 'UI baseline capture failed' }
Get-Content "$baseline/logs/ui_polish_baseline.log" -Tail 1
```

脚本不修改任何永久用户环境变量；命令所在 PowerShell 进程的 APPDATA/LOCALAPPDATA 会保持隔离值，关掉该终端即可。后续整合新界面时需要适配 harness 的生产入口并重新运行；此文件记录的原始结果不能转移为新界面验收结果。
