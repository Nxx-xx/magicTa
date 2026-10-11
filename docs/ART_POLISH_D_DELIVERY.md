# D 组 · UI 与剧情画面精修交付

2026-10-03。已实施、接入生产 `map_screen.gd` 并完成本机 Godot 4.7.2 审阅。范围为主菜单、HUD、二级目录、交互面板、图标底座与剧情阅读布局。没有替换人物/敌人动画、物品原画或剧情背景，没有导出或更新 current/latest。

## 实际变更

- 主菜单：沿用三人标题插画，增加独立深色动作底板、古金刻线与角部收边；主按钮用古金底色，禁用/次级按钮与键盘焦点清楚区分。四个小入口从 40px 提升到 44px，菜单仍在单屏内，入口/导航不变。
- HUD：信息内容和数值不变；增加内侧留白、垂直居中和资源槽高度，压窄生命条，边框使用可编辑刻线与铆点。未改变地图、移动按钮、点击路线或状态结算。
- 统一主题：深灰蓝石材底、旧金属边、卡片底部厚边与接触阴影。二级页面显示对应页面标题，设置页去掉重复标题。目录副说明从 11px 提升为 12px；沿用分类、翻页、详情/返回与弹窗，不增加常规滚动列表。
- 图标：复用所有现有 item registry/纹理，调整 UI 图标底座为石板金属边、功能符号为刻纹圆章；没有改 `assets/items`、物品映射或效果。
- 序章与再启旅程：根据最终文字宽度测量段落高度，修复 320px 首段末句被滚动区挤出的情况；每段重新测量，短句不会留下过高面板。立绘按对白上方实际空间缩放，顶部至少留出章节区域。继续/跳过按钮有不透明底色，保留原剧情顺序、存档和跳过行为。异常超长外部文本保持原滚动兜底，正常 14 段均完整显示。

新增 UI 是原生 Theme / StyleBoxFlat / Control 绘制，非栅格效果图。原主题完整保留，新主题独立放在 `assets/ui/art_polish_d_v01/`；本轮未调用 image_gen，亦没有需要保存的新原画提示词。

## 文件与接入

生产文件仅以下八项：

| 文件 | 作用 |
| --- | --- |
| `scripts/ui/map_screen.gd` | 引用 D v01 主题、HUD 间距与饰边、二级页标题 |
| `scripts/ui/main_menu.gd` | 动作底板、刻线和 44px 小入口 |
| `scripts/ui/story_intro_stage.gd` | 对白测量、立绘边界、按钮可读性 |
| `scripts/ui/paged_catalog.gd` | 目录卡片主题、12px 副说明 |
| `scripts/ui/item_icon.gd` | 复用原图的图标底座 |
| `scripts/ui/action_icon.gd` | 原生功能符号刻纹底章 |
| `scripts/ui/art_polish_d_frame.gd` | 新增、静态装饰且不消费输入 |
| `assets/ui/art_polish_d_v01/art_polish_d_theme.tres` | 新增独立主题，保留原字体和语义色 |

另有主题说明 `assets/ui/art_polish_d_v01/art_polish_d_REVIEW.md`、复现工具 `tools/art_polish_d_verify.ps1` / `tools/art_polish_d_report.py`。专属可玩入口为 `tests/art_polish_d_play.gd`：

```powershell
./tools/art_polish_d_verify.ps1 -Play
```

390×700 实际主菜单开始，可进入营地、开新局和操作所有生产页面；存档在 D 组公共锁的独立 appdata 中。正常退出窗口结束；公共锁默认最长运行 900 秒。不会读真实玩家存档。

专项捕获与六份既有回归的 D 组隔离入口位于 `tests/art_polish_d_capture.gd`、`tests/art_polish_d_{main_menu,story_intro_ui,action_choices,compact_screens,phase3_ui_host,item_icons}_test.gd`。另保留 `art_polish_d_baseline_screen.gd` 与 `art_polish_d_baseline_menu_test.gd` 用于旧弹窗断言复现。没有改共享原测试。

生产精确 SHA、修改前后差值：[版本记录](../build/verification/art-polish-d/art_polish_d_review.json)、[D 组范围补丁](../build/verification/art-polish-d/owned-changes.patch)。补丁以本轮开始的工作区文件为基线，不以 Git HEAD 为基线，避免把用户已有未提交成果当作本轮变更；paged_catalog 两处旧值由明确反向替换重建，其他已有文件使用保存的快照。

## 画面证据

[完整前后画廊](../build/verification/art-polish-d/art_polish_d_review.html) 包含 24 张修改前与 42 张最终截图。尺寸 320×640、390×700、540×960，seed 42，均是实际 Godot viewport。商店使用明确的奖励实体夹具；不是自然通关证据。共享工作区中的角色、怪物、营地画面可能同时包含其他组制作进展，不归为 D 组绘制。

| 画面 | 修改前 | 最终 |
| --- | --- | --- |
| 主菜单 320 | [before](../build/verification/art-polish-d/before/menu_320.png) | [after](../build/verification/art-polish-d/after/menu_320.png) |
| HUD 320 | [before](../build/verification/art-polish-d/before/hud_320.png) | [after](../build/verification/art-polish-d/after/hud_320.png) |
| 指引 390 | [before](../build/verification/art-polish-d/before/guide_390.png) | [after](../build/verification/art-polish-d/after/guide_390.png) |
| 首段对白 320 | [before](../build/verification/art-polish-d/before/story_320.png) | [after](../build/verification/art-polish-d/after/story_320.png) |
| 商店/详情 320 | — | [列表](../build/verification/art-polish-d/after/shop_320.png)、[详情](../build/verification/art-polish-d/after/shop_detail_320.png) |
| 立绘与章节 540 | — | [公主](../build/verification/art-polish-d/after/story_portrait_540.png) |
| 长数字确认 320 | — | [弹窗](../build/verification/art-polish-d/after/confirmation_320.png) |
| 多件物品 320 | — | [目录](../build/verification/art-polish-d/regression/item-icons/inventory_320_0_0.png) |

已实际查看主菜单、HUD、目录、设置、商店/详情、图标目录、确认框、旁白/公主/王子画面，覆盖三种手机宽度。正常地图与减少动效各留三张；新增 UI 本身无动画，不改变其他组已有动画时序。正常剧情 14 段×3 尺寸均检查无滚动条及继续按钮边界。未声称真人签收。

## 回归结果

全部通过公共锁 `tools/phase3_v05_godot_locked.ps1 -Group art-polish-d`，独立 APPDATA/LOCALAPPDATA。日志在 `build/verification/phase3/08-parallel/art-polish-d/`，每次有 started/result JSON。下列数字含重复断言，不作为画面质量或唯一测试数。

| 套件 | 最终结果 | 日志前缀 |
| --- | --- | --- |
| 主菜单/保存继续/二级返回/弹窗 | 152 checks，0 failures | `final2-main_menu-20261003-160750-636` |
| 序章/立绘/异常长文/跳过恢复 | 72 checks，0 failures | `final2-story_intro_ui-20261003-160807-652` |
| 遗迹、商店、奖励、休息与长文分页 | 1,205 checks，0 failures | `action_choices-20261003-160013-980` |
| 单屏目录、营地功能、楼层、设置 | 1,948 checks，0 failures | `compact_screens-20261003-160042-917` |
| 主 UI/教学/遗迹保存失败重试 | 130 checks，0 failures | `final2-phase3_ui_host-20261003-160811-919` |
| 物品映射、真实图标点击、详情/分页 | 2,492 checks，0 failures；24 张截图 | `item-icons-20261003-160846-167` |
| 最终三尺寸 UI 与全部序章段落 | 42 张截图；边界/无滚动/只读检查通过 | `final3-capture-20261003-160947-882` |

保留的失败与处理：

1. 序章初次扩展面板后立绘侵入章节，已按剩余高度约束；短句曾因新 Label 的零宽缓存被测得过高，改为最终宽度下直接测量字体。最终截图和回归通过。
2. 旧主菜单测试要求长数字后总行数必须 >6；原基线在 540/900 下同样为 6 行，两个失败可由 `baseline-confirm` 日志复现。仅 D 测试副本改为“80 位数字追加至少两行”，并保留原全部可见、缩窄后边界及按钮不重叠检查。
3. 原剧情测试要求注入长文必须出现滚动条。900px 新面板能完整容纳该段，D 副本改为“全文在可视边界内或可滚动访问”，窄屏长文仍有滚动兜底；不为迎合旧断言强制出现滚动条。
4. 截图跳过教学写入 D 组偏好，使主 UI 初次回归的教学断言失败；D 夹具逐尺寸恢复初始教学，原生产代码未改。测试脚本曾有一次类型推断编译错误，已加显式 int 并保留日志。
5. 日志中的系统根证书存储提示为本机环境告警；最终运行没有脚本/资源加载错误。尝试用系统 Python 生成联系图时缺少 Pillow，未安装依赖，改交付原始截图和 HTML 画廊，不把失败工具步骤记为通过。

复现：

```powershell
./tools/art_polish_d_verify.ps1 -Capture
python tools/art_polish_d_report.py
```

## 包体、保留边界与统筹事项

- **新增栅格资源 0，新增字体 0。** 两个新运行文件合计 15,780 bytes；连同六个现有脚本差值，独立 zlib level 9 压缩源码估算 **3,433 bytes（3.35KiB，约 0.0033MiB）**，低于建议 0.40MiB。该估算不等于 Godot 编译资源或微信 ZIP 实测差值；[测量说明](../build/verification/art-polish-d/package-estimate.json)。未导出、未更改 20MiB 门槛、构建脚本或 current/latest。
- `camp_board`、`grid_board`、角色/敌人资产、战斗播放器、核心规则/战报/奖励/存档均未由 D 组编辑。营地仅继承公共 UI 主题，`camp_map.gd` 本轮无需修改。既有非序章剧情插画继续使用原资源和通用面板，没有重绘结局图。
- 当前仅确认 Godot 4.7.2 桌面源码。微信 4.6.1 staging、开发者工具/真机、触控手感、真人美术签收与全流程集成交统筹；不宣称这些通过。
- **跨所有权代码补丁：无。** 已在 D 组所有权内完成正式引用。统筹需要将八个生产文件及自动生成的必要 UID 纳入统一导出，确认新 `.tres` 与绘制脚本入包，保留旧主题作为源；继续排除 `tests/`、`tools/`、`build/verification/` 证据。
- 主题会由公共 UI 的子控件继承，统筹应在 C 组最终战斗舞台下复核主要按钮/焦点对比；不需要 D 组修改战斗播放器。最终实际包体和 current 发布由统筹执行。
