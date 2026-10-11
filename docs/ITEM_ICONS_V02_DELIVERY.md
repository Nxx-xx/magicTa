# 装备、遗物与交互图标绘画版 v02

2026-10-04。完成审查清单第 3 项：22 件基础物品、6 件第三阶段遗物全部重绘并正式接入，另新增 3 类遗迹交互图标。物品 ID、数值、效果、存档结构、玩法数据均未修改。content.json 与 phase3_items.json 的前后 SHA-256 完全一致。

## 美术与版本

采用内置 image_gen，每件独立生成透明绘画原图。冷青阴影、左上主光、旧金属高光；金属、皮革、木材、骨、宝石、丝穗分别表现。先展示铁剑、决斗手套、提灯护符三个样板，再扩展全套。四把剑、三种护甲、弓盾、冠环及各类遗物保持独立轮廓。生命吊坠首稿链条出框，已通过图像编辑补为完整闭合链条；拒绝稿保留。

- 原始源图与精确提示词：`assets/items/source/painted_v02/`，含 prompts.json、interaction-prompts.json、provenance.json、修订提示词。
- v01 PNG 与旧清单：`assets/items/source/baseline_v01/`；既有 SVG 与第三阶段 256px 母版保留。
- 当前全量清单：`assets/items/painted_v02_manifest.json`；unique/manifest.json、phase3/manifest.json 同步当前来源及哈希。
- 烘焙工具：`tools/item_icons_v02_bake.gd`。只按透明边界等比缩小，最大主体 100px，输出 128×128 RGBA、至少约 14px 留白；不描画替代图、不抠白、不破坏生成 alpha。

## 正式接入与协作边界

28 件物品沿用 item_icon_registry.gd 的原有路径：22 张 assets/items/unique/icons，6 张 assets/items/phase3/icons。商店、背包、图鉴、奖励和详情直接消费同一资源，旧旅程也可使用。注册表新增 ART_VERSION 和 ACTION_PATHS。

三张新交互位于 assets/items/interactions/icons：salvage（物资袋）、temper（铁砧与剑钢）、sacrifice（灼血磨刀石）。ActionIcon.for_reward 按这三个既有展示选项 ID 选择资源；其余攻击、防御、治疗、金币、地图、日志、设置等通用符号保留。遗迹故事池可能替换展示名称，但操作仍按相同 ID 与既有收益描述解释。

公共 action_icon.gd 仅增加两个资源 preload、已注册交互的纹理分支，以及上述 ID 查表；原有底座、边框和通用符号绘制未改。没有编辑 item_icon.gd、页面布局、按钮样式、环境／敌人／战斗资产、加载页或游戏图标。工作区中这些文件的其他差异属于已有／并行成果。本轮未修改共享构建脚本。

## 视觉证据与验证

- `build/verification/item-icons-v02/all-items.png`：31 张的 96／48／32px 标注总览；`before/all-items.png` 为旧版对照。
- `before/` 与 `after/`：320×600、390×700、540×960 的实际 Godot 商店、背包各分页、奖励、部分详情。`after/shop_320.png`、`after/inventory_320_0_0.png` 可直接查看。
- `after/p3_oath_ruin_320.png`、`after/p3_oath_forge_320.png`：真实遗迹面板的 3 类新交互。测试通过夹具提供物品和待处理实体，截图不是自然通关记录。
- `asset-audit.json`：31 张 RGBA、尺寸、透明安全边界、像素唯一性和哈希通过；正式 PNG 合计 478,810 bytes。
- `tests/item_icons_v02_test.gd`：专属隔离测试，商店／奖励／背包／图鉴逐件真实输入点击，查看与详情不改变状态、说明分页完整、资源身份一致；新增遗迹交互身份和点击。最终 **4,116 项，0 失败**。
- Godot 4.7.2 导入通过。所有导入、烘焙、截图、测试经 `MagicTa_Phase3_Parallel_Godot` 公共锁；APPDATA/LOCALAPPDATA 隔离到 item-icons-v02 证据目录。引擎证据位于 `build/verification/phase3/08-parallel/item-icons-v02/`。
- `python tools/check_project.py`：内容引用、资源路径、事件／奖励配置及地图静态检查通过；可选 fontTools/gdtoolkit 未安装而跳过，实际 Godot 编译已另行通过。

## 独立微信包

`build/wechat-item-icons/`，Godot 4.6.1，现有 AppID 与 high-performance-plus 模式。最终报告：`build/wechat-runs/20261004-025826-230526/build-report.json`；归档：同目录 `TowerRealm-WeChat.zip`。

总大小 **20,837,980 bytes（19.87 MiB）**，主包 **2,427,542 bytes**，20 MiB 限额剩余 **133,540 bytes**。31 张包内纹理合计 **109,212 bytes**。22 张基础图标沿用构建的 96px 限制，6 张第三阶段和 3 张交互保留 128px；工作区均为 128px。没有全面降质或扩大预算。

同一资源路径在当前共享包中的旧 28 张纹理合计 67,980 bytes，本轮 31 张纹理净增 41,232 bytes（约 40.3 KiB）。总包同时包含并行聊天在构建快照时的成果，不能把整个包的差额都归因于图标。

source 与旧版备份被 staging 排除；历史 phase3/masters 增加 .gdignore 保留但不导出。package-audit.json 确认所有 31 张的导入重映射和纹理有效、源图哈希及数据一致、历史图未入包；所有构建文件哈希校验通过。独立无项目美术旁路的 harness 用 Godot 4.6.1 挂载实际 ZIP，**31 项加载，0 失败**；`packed-small-icons.png` 是真实包内压缩纹理 48／32px 对照。

复现顺序：公共锁运行 item_icons_v02_bake.gd；导入；锁内运行 tests/item_icons_v02_test.gd --capture；运行 tools/item_icons_v02_wechat.ps1；python tools/item_icons_v02_package.py；tools/item_icons_v02_packed.ps1。总览用 bundled Python 运行 tools/item_icons_v02_review.py。

独立构建使用 --no-latest，未覆盖共享 current/latest，未上传或发布。桌面与 ZIP 验证不代表微信开发者工具或真机验收。日志存在环境已有根证书读取告警。首次手动包验证漏设可写用户目录而触发 Godot 日志目录崩溃；已改为独立 APPDATA/LOCALAPPDATA 包装器，重跑成功；最终验证以 packed-runtime.log 为准。
