# M1 主界面样板交付

日期：2026-09-29

工作副本：`.`

仅在此工作副本实施；未写入 `.`，未推送或创建其他聊天。

## 整合文件

- `scripts/ui/map_screen.gd`：固定 HUD、持久地图与方向按钮、响应式目标摘要、独立滚动详情面板、输入拦截及焦点恢复。普通移动不重建主界面；行囊内容按属性/装备变化缓存。
- `scenes/map_prototype.tscn`：引用统一 Theme。
- `assets/ui/map_theme.tres`：暗石色、暖金、青绿主题，按钮正常/悬停/按下/禁用/焦点、生命条及公共字体。
- `tests/ui_polish_m1_runner.gd`：本批专用验证与截图入口，不替代 M0 baseline runner。

本次没有修改 core、数值、存档格式、grid_board、monster_art 或 item_icon。`project.godot`、两份 UI 计划和 reward 测试 UID 在任务开始时已带入，不能当作本次新改动覆盖集成目录。Godot 导入让四个既有 `.import` 文件出现换行格式状态噪声，`git diff` 无内容变化，不需要整合。

## 行为

- 540×960：516×516 完整方形地图；状态、目标摘要和独立方向按钮无需整页滚动。
- 360×640：288×288 完整地图；目标摘要收为两行，通过「详情」打开面板。
- 900×960：532×532 地图居中，内容最大宽 600，没有放大成宽矩形。
- 320×640：额外极窄回归；不改变项目承诺的最小窗口 360×640。
- 待确认目标、行囊、战斗记录打开时阻止地图/方向输入；关闭恢复。完整预览局部滚动，返回按钮固定。
- 普通怪和致死怪显示不同成本；致死挑战保留额外确认。击杀奖励与守护奖励分列，现有商店/奖励/药剂等预览继续使用原逻辑。
- 为让断点响应实际窗口大小，主场景进入时临时关闭 Window canvas 缩放，退出时恢复原 Window 设置；没有改写 `project.godot`。

## 验证

引擎：`godot`

隔离环境：

```powershell
$env:APPDATA = Join-Path $PWD 'build/verification/appdata'
$env:LOCALAPPDATA = Join-Path $PWD 'build/verification/localappdata'
& 'godot' --headless --path . --script tests/ui_polish_m1_runner.gd --log-file build/verification/m1_layout.log
Start-Process -FilePath 'godot' -ArgumentList '--path', '.', '--script', 'tests/ui_polish_m1_runner.gd', '--log-file', 'build/verification/m1_capture.log', '--', '--capture' -WindowStyle Hidden
```

七组既有无窗口测试：112 + 274 + 3072 + 954 + 24 + 459 + 9 = **4,904 项，零失败**。日志为 `build/verification/m1_*test_runner.log`。

新增 M1 无窗口验证：初次交付 78 项；保存失败与后台 Tab 焦点修复后 **260 项，零失败**。覆盖四种尺寸、方形与边界、节点身份/键盘焦点保留、详情输入拦截与取消、死亡额外确认及取消、重复按钮信号只结算一次、预览与实际 HP/金币一致、死亡重开、营地继续，以及下述真实存档写入失败、跨面板可见性、恢复路径和键盘 GUI 焦点遍历。

M1 图形验证：初次交付 98 项；保存失败与后台 Tab 焦点修复后 **296 项，零失败**（含 36 张 PNG 保存检查）。使用真实 Godot OpenGL Compatibility 渲染；设备 NVIDIA GeForce RTX 5070，驱动 616.92。

奖励图形验证：**13 项，零失败**（含药剂、商店、二选一及极窄商店四张 PNG）。

Python 三组检查通过。`check_project.py` 的可选 fontTools 字形覆盖和 gdtoolkit 语法检查因依赖未安装而跳过；Godot 已实际加载并运行脚本。日志 `m1_check_project.log`、`m1_check_maps.log`、`m1_check_random_maps.log`。

环境会打印系统根证书读取失败；两组旧存档测试会按预期打印无效 JSON 诊断。最终 M1 日志没有脚本解析、运行时或布局断言错误。

## 截图

目录：`./build/verification/m1`

每种尺寸 540x960、360x640、900x960、320x640 均有以下五张：

- `explore_<尺寸>.png`：普通探索，种子 42。
- `selected_monster_<尺寸>.png`：查看普通怪物。
- `monster_preview_<尺寸>.png`：待确认普通战斗。
- `lethal_selected_<尺寸>.png`：收起状态下致死文字提示。
- `lethal_preview_<尺寸>.png`：展开完整致死战斗成本。

怪物样例是种子 42 上受控替换相邻格的验证场景，并非声称该地图自然生成这些位置。截图在最后一轮图形验证后实际打开检查。

商店兼容截图：`./build/verification/reward_shop.png`；其他 `reward_potion.png`、`reward_choice.png`、`reward_mobile.png` 同目录。

## 后续限制

- 本批只交付 M1；新美术未接入，地图/怪物/物件复用现有绘制。
- 宽窗口采用居中布局，没有增加可选侧栏；窄窗口目标摘要可能省略长说明，完整文字在详情内。
- 完整六阶段、手机实机、Windows 导出、长时间人工鼠标键盘试玩和性能量测未在本批验证。
- 原 `monster_ui_test_runner.gd` 的 `screen.scroll` 现在指详情面板滚动区；其旧截图“把整页滚到怪物详情”的方式不再适用，M1 截图应使用本批新 runner。旧行为断言全部仍通过；后续由测试聊天适配正式验收入口。
- 没有需要修改其他聊天所属源码的阻塞依赖。保留未提交改动供统筹选择上述四个文件整合。

## 保存失败阻断项修复（统筹复查后）

本次补丁只继续修改 `scripts/ui/map_screen.gd` 与 `tests/ui_polish_m1_runner.gd`；主题、场景沿用上一版。没有写入原目录或 QA 工作副本。

根因：保存错误原先只写入目标摘要的 hint。窄窗口选中怪物时显示战斗 copy 并隐藏 hint；展开详情时整个摘要被面板遮住。应用失焦时的自动保存也没有触发 UI 刷新。

修复：新增持久 `PersistentSaveError` 提示区，位于状态栏下方、详情面板上方，并作为详情遮罩之后的独立兄弟节点绘制。提示采用“存档异常”标题及核心返回的原文，避免把读档异常误写成成功或未经证实的状态。普通探索、选怪、完整详情、待确认、行囊及死亡结果均保持可见。错误文字换行，长诊断在固定高度内独立滚动。状态栏和方向按钮保持原位；地图仍为完整正方形，360×640 报错时临时缩至 196×196，恢复后回到 288×288。确认/返回按钮没有被错误区遮盖。保存错误不再替换战斗成本摘要。

应用失焦/暂停的自动保存完成后只刷新错误区域与布局；常规动作继续通过现有局部刷新路径同步。只有引擎实际清空错误时才隐藏提示，不添加“保存成功”文案，也不更改保存逻辑、玩法或退出行为。

真实失败验证：在独立 `user://` 环境建立 `<测试存档>.tmp` 目录，使 `FileAccess.open(..., WRITE)` 确实失败。通过应用失焦通知调用原 `game.save_game()`，不手动调用 `_render` 来显示提示；确认存档文件不存在、核心错误非空。标准/最小窗口分别检查探索、选怪、完整详情、待确认、行囊与结果的可见性、层级、换行、地图及按钮边界。额外长文本用例仅为布局压力测试，在真实核心报错后追加测试文字，并明确验证局部滚动可到达剩余文本。

恢复验证：将存档路径改到同一隔离环境中的可写文件，通过同一个后台保存入口完成真实写入；确认文件存在、核心错误清空、提示及文字消失，地图和详情面板矩形恢复到错误前的值，没有显示虚假保存成功。

本轮日志：

- `build/verification/m1_save_error_layout.log`：260 项、零失败。
- `build/verification/m1_save_error_capture.log`：296 项、零失败。
- `build/verification/m1_save_error_*test_runner.log`：修复后重新跑完既有七组，4,904 项、零失败。
- `build/verification/m1_save_error_static.log`：项目/地图/随机地图静态检查通过；可选 fontTools/gdtoolkit 仍跳过。

保存错误图形证据目录仍为 `build/verification/m1`，标准与最小窗口各八张：`save_error_explore_*`、`save_error_selected_*`、`save_error_details_*`、`save_error_pending_*`、`save_error_inventory_*`、`save_error_long_*`、`save_error_result_*`、`save_error_cleared_*`（后缀为 `540x960.png` / `360x640.png`）。

已实际打开检查 360×640 普通战斗待确认截图：怪物名称/档次、攻防血、净损失、实际受伤/回血、金币，以及确认与返回按钮均可读；保存错误同时可见。也检查了窄屏选怪、长错误及错误清除截图。无新增阻塞项；仍需统筹同步后由 QA 在集成工作区复核。

## 后台 Tab 焦点修复

QA 发现禁用按钮仍可能参与 Godot Tab 遍历。`_set_map_input` 现在为每个后台按钮保存原 `focus_mode`，禁用时设为 `FOCUS_NONE`，恢复操作时还原原值，覆盖营地、详情、四向按钮、行囊及记录入口。

M1 runner 在 360×640 打开目标详情、行囊及待确认三类面板，通过 `Input.parse_input_event` 向 Godot 输入管线注入按下/释放的 Tab、Shift+Tab、Escape（不是直接调用 `_input` 或强制跳转焦点）。每类验证八次正反向遍历，焦点始终在面板内；Escape 关闭并取消待确认，恢复原触发按钮的焦点及模式，随后 Tab 能继续遍历地图控件。该验证在无窗口和真实图形渲染两种运行下均通过。

未编辑旧版 `main.gd`；其编译修复由统筹独立负责。
