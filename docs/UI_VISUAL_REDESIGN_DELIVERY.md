# 塔境 · 界面视觉改造 V01 交付

日期：2026-09-29。工作目录：`.`。引擎：Godot 4.7.2 标准版，Windows / OpenGL Compatibility（RTX 5070）。

本批已按先保存计划、再实施、再真实渲染检查的顺序完成。属于整体美化计划 M1 / M2 的界面细化，不代表完整美术集成或最终平台验收完成。

## 本批修改

| 文件 | 结果 |
| --- | --- |
| `scripts/ui/map_screen.gd` | 固定 HUD 背板、金币与三钥匙分区、8px 生命条、地图外 3px 细框；目标名称与损失独立行；商店 / 奖励 / 事件 / 休息 / 楼层选择独立卡片；行囊分项；营地主操作前置；确认弹窗与背景遮罩；结果面板可见焦点 |
| `assets/ui/map_theme.tres` | 普通、主要、次要、方向和危险按钮；悬停 / 按下 / 禁用 / 金色焦点；HUD、卡片、目标、弹层与地图框；滚动条和确认窗口统一主题 |
| `assets/ui/visual_v01/body_font.tres`、`title_font.tres`、`README.md` | 沿用 Noto Sans SC，界面正文 450 / 标题 600 字重；资源来源与维护说明 |
| `tests/ui_visual_v01_runner.gd` | 继承全部 M1 断言，新增真实界面、六种普通怪极窄摘要、按钮状态、确认焦点、页面操作和长中文检查 |
| `tests/ui_visual_v01_review_runner.gd` | 继承原独立审核，仅把生成证据转存本批目录；保留原隔离路径约束及断言 |
| `tests/ui_visual_v01_verify.ps1` | 可复现的隔离导入 / 回归 / 渲染 / 独立审核入口；超时仅终止本脚本启动的进程，退出恢复环境变量 |
| `docs/UI_VISUAL_REDESIGN_PLAN.md` | 先行开发计划及完成记录 |

所有按钮仍至少 44px，主要动作 48px；铜 / 银 / 金钥匙有文字区分。古金主要用于细边和标题，青绿用于生命与主要操作，暖红用于危险与错误。未新增栅格装饰或第三方素材。

没有修改 `grid_board.gd`、共享核心、场景 API、`project.godot` 或三条美术线程的资产 / 预览代码。地图尺寸计算与移动、战斗、交易、楼层、存档格式和数值规则保持原有实现；未提交或推送。

## 实测发现与修订

1. 原字体资源的字符串 `wght` 设置未得到预期字重，真实截图接近 Thin。引擎报告支持的轴是数字 `2003265652`（范围 100–900，默认 100）；界面专属资源改用数字标签后，450 / 600 字重真实渲染明显清晰。共享字体与地图内字体未修改。
2. 字重修正后，320 宽的怪物长分类使原两行混合摘要吞掉净损失 / 致死文案。现在标题可省略，但损失在独立全宽行显示；六种普通怪增加断言和截图，实际检查损失行完整可见。360 / 540 / 900 宽也复查通过。
3. 确认窗口统一主题、默认为取消，背景加暗；存档异常面板位于遮罩之上，四档窗口都不与确认窗口相交。取消会恢复输入与原焦点。
4. 死亡结果原来尝试聚焦隐藏的关闭按钮，现改为可见的重新开始操作；Tab 仍不能进入背后地图控件。
5. 初次导入曾扫描本批备份并报告重复 Theme UID。验证目录已设置 `.gdignore`，最终重新导入无重复 UID 警告；测试入口也会先创建此标记。截图 / 备份 / 对照图不作为生产资源导入。

## 验证结果

日志根目录：`./build/verification/ui_visual_v01/logs/`。

| 检查 | 结果 | 证据 |
| --- | --- | --- |
| Godot 编辑器导入 | 通过，无脚本错误 | `import-final.log` / `.stderr.log` |
| 既有七组回归 | 4,847 项，零失败：55 + 274 + 3072 + 954 + 24 + 459 + 9 | `combat`、`map`、`random_map`、`keys`、`monster_ui`、`reward`、`reward_ui` 日志 |
| 本批 + 全部 M1 无窗口断言 | 523 项，零失败 | `headless-final.log` |
| 本批 + 全部 M1 真实渲染 | 639 项，零失败，含 116 张 PNG 保存检查 | `visual-final.log` |
| 继承独立审核：布局 / 焦点 / 保存异常 / 场景往返 | 66 项，零失败 | `review-review-final.log` |
| 独立进程保存，再启动读档 / 领取奖励 / 购买 | 4 + 16 项，零失败 | `review-write-final.log`、`review-read-final.log` |
| 历史地图与随机地图 Python 检查 | 通过 | `static-maps.log`、`static-random.log` |
| 本批 6 个 GDScript / Theme / Font 资源源文件引用检查 | 通过 | `static-ui.log` |
| 通用 `tools/check_project.py` | **未通过**：将其他线程人物预览中的 `res://assets/characters/hero/` 目录常量当成缺失文件 | `static-project.log` |

通用静态检查失败来自 `assets/characters/hero/preview/hero_preview.gd` 的 `BASE` 目录常量及检查器的 `is_file()` 假设。该目录存在，Godot 导入通过；本批未修改该预览或共享检查器，交由后续集成处理，不能把通用检查记成通过。可选 fontTools 字形全量检查仍为 SKIP；真实截图已查看本批主要中文文案。

最终 UI / 审核 stderr 仅有环境根证书读取提示。核心备份恢复测试仍会故意触发损坏 JSON 诊断。测试期间的早期字体探针方法名错误仅发生在隔离诊断脚本，已修正并停止该进程，不属于最终生产脚本错误。

这些数量含重叠回归和截图保存断言，不合并宣传为独立功能数量。控件操作通过 Godot 输入事件和真实按钮信号验证，未宣称人工鼠标长时试玩或实机触屏验证。

## 截图与可视检查

所有路径均位于 `./build/verification/ui_visual_v01/`：

- `screenshots/before/`：本批修改前 M1 的 36 张原始截图。
- `screenshots/after/`：最终 116 张真实 Godot 截图。
- `review/screenshots/`：独立审核 21 张截图；`review/*_observations.json` 记录检查结果。
- `comparison.png`：540×960 探索界面前后对照，左前右后。
- `contact/`：四档窗口拼接查看图，仅用于审阅；小图会缩放，文字清晰度以原始 PNG 为准。
- `before/map_screen.gd`、`before/map_theme.tres`：本批开始时的原件，包含此前用户和 M1 改动；不是 Git HEAD。

四档窗口均采集探索、选中怪物、致死摘要、战斗预览、奖励及焦点、商店及禁用、事件、休息、行囊、确认与同时保存异常、菜单与新局确认、结果、药剂、钥匙不足、楼层选择、回访楼梯、目标完成继续探索、长中文。另有 360 窗口真实鼠标事件悬停 / 按下状态，六种普通怪 320 摘要，M1 的真实写入失败 / 恢复及长诊断局部滚动。

已查看主要状态的四档拼接图，并在原始窄屏与标准屏截图确认字体、长文案、底部关闭按钮、主次按钮及保存提示。地图没有被新边框缩小：540×960 中为 516px 方形，360×640 与 320×640 中为 288px，900×960 中为 532px；保存异常出现时沿用原先为错误面板留空间的行为。

主要原图：

- `screenshots/after/explore_540x960.png`
- `screenshots/after/lethal_selected_320x640.png`
- `screenshots/after/choice_540x960.png`
- `screenshots/after/shop_320x640.png`
- `screenshots/after/confirmation_save_error_320x640.png`
- `screenshots/after/menu_360x640.png`

## 复现与隔离

在项目目录执行：

```powershell
& ./tests/ui_visual_v01_verify.ps1
# 仅在核心已验证、改动限于界面时省略七组重复回归：
& ./tests/ui_visual_v01_verify.ps1 -SkipRegression
```

APPDATA / LOCALAPPDATA 默认在本批根目录，各核心回归使用 `regression/<suite>/` 独立子目录。独立审核使用本批下的 `build/verification/m1_review/` 子树，以满足既有审核脚本对路径后缀的硬约束；证据通过子类 `_path()` 转向本批 `review/`。保存失败使用隔离 `user://` 的临时目标制造，未访问玩家正式存档。

## 剩余范围与限制

- 人物、地图、怪物最终素材接入属于后续集成。本批截图中的地图与物品图标仍为已有程序占位；界面完成不依赖其他素材完成。
- 320 宽可省略较长目标名称 / 分类和一般探索提示；关键损失与致死提示单独显示，完整身份、机制和奖励在详情中可读。
- 窄屏选择项、商店和长正文需要局部滚动，固定关闭入口不滚动。地图小格仍以方向按钮补足触控目标。
- 宽窗口沿用居中布局，无新增侧栏；标题插画、完整装备插画、NPC、动效、音效均留后续。
- 未验证 Windows 导出包、Web、Android / iOS、手机实机触控或长时间性能；桌面窗口缩窄不能代表这些平台通过。
