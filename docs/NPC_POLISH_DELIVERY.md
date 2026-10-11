# 死神与烛火商人表现精修

2026-10-04。正式营地死神已接入原画网格待机，正式商店已接入高清母版上半身近景、呼吸及灯火。死神对话近景 helper 已完成并验证；遵守本轮文件归属限制，其正式对话调用以独立补丁交付，**尚未写入 `campaign_panels.gd`**，不可将预览截图当成该入口已经接入的证明。

## 当前配置下的包体评估

按用户最新要求重新读取 `tools/build_wechat.py:18–19`：总包 **30 MiB / 31,457,280 bytes**，主包 **4 MiB / 4,194,304 bytes**。审核脚本直接导入这两个配置常量，未修改公共打包脚本、策略或阈值。原先 20 MiB 不再作为当前总包预算；32 KiB 是本项最初分配的历史参考，当前打包配置未定义单独 NPC 额度。本项也仍低于这个原参考值。

| 项目 | 实际字节 | 当前配置限额 | 余量 |
|---|---:|---:|---:|
| 导出目录总文件 | 20,230,851（19.2936 MiB） | 31,457,280（30 MiB） | 11,226,429（10.7064 MiB） |
| 主包 | 2,427,533（2.3151 MiB） | 4,194,304（4 MiB） | 1,766,771（1.6849 MiB） |
| 本项压缩净增量 | **14,624（14.2813 KiB）** | 当前配置无 NPC 子额度 | 相对原 32 KiB 参考余 18,144 |

本地预算检查通过。这是当前配置值，不代表已核实当前 AppID 的平台上传额度；未上传微信开发者工具、未发布、未做真机验证。体积统计为导出目录文件总和，并非最终交付 ZIP 的文件大小。

独立包：`build/wechat-npc-polish/`。不可自动提升为 `wechat-current`。本次命令使用 `--no-latest`，未更新任何 latest 指针。

- 构建 ID：`20261004-140323-534746/high-performance`。
- 构建报告：`build/wechat-runs/20261004-140323-534746/build-report.json`。
- 可交付 ZIP：`build/wechat-runs/20261004-140323-534746/TowerRealm-WeChat.zip`。
- 重新评估结果：`build/verification/npc-polish/package-audit.json`。

整体快照相对初始审计包减少 **607,118 bytes**，含其他同时工作的聊天变更，**不归因于 NPC 精修**。本项归因来自两份实际 `engine/godot.zip` 的压缩条目；对两个共用脚本先验证“只逆转本项局部修改即可逐字节还原初始包”，再计入条目差额。没有把别人的脚本变化计入本项。

| 本项条目 | 实际压缩增量 bytes |
|---|---:|
| 原死神纹理及 remap | 0 |
| 原商人全身纹理及 remap | 0 |
| 商人 conversation.png 的 ctex + remap | 12,364 |
| camp_death_art.gd | 1,054 |
| npc_portrait.gd | 773 |
| npc_portrait.gdshader | 512 |
| camp_board.gd 单行死神绘制调用 | 0 |
| map_screen.gd 商店 portrait 局部替换 | -79 |
| **合计** | **14,624** |

## 实现与资源归属

- `camp_death_art.gd` 保留原 `TEXTURE` 和 `ANCHOR` 接口。营地仅把原绘制语句替换成 `DeathArt.draw()`：有界 48 姿态网格缓存复用原像素，轻微呼吸、斗篷起伏、绿灯明暗；脚点、选择矩形、前后遮挡顺序不变。减弱动效使用中性姿态。
- `npc_portrait.gd` 和配套 shader 只承担显示，不读取游戏 RNG、不写存档、不修改数值，始终 `MOUSE_FILTER_IGNORE`。每帧读取减弱动效设置，静止后恢复到同一中性画面。
- 商人 `textures/conversation.png` 从原 `source/merchant_v01.png` 的 `(192,0,896,832)` 裁切后，以 Lanczos 缩为 192×178。保留紫兜帽、胡须、灯笼与行囊，沿用原母版，没有重画身份。地图仍使用原 256×256 全身 idle。
- 正式商店默认显示 96×88 近景；视口高度小于 640 时显示 80×68，保持最小手机页面完整。招呼语、价格、商品顺序、限购规则和购买回调均未改。
- 死神高清母版备份至带 `.gdignore` 的 `assets/characters/camp_death/source/death_v01.png`；商人母版继续保留在原 `source/`。运行纹理清晰度和原图未降低，原死神和商人 idle 的最终压缩 payload SHA256 与初始审计完全相同。
- 未修改 `runtime_art.gd`、老骑士美术、剧情文案、顺序、公主/王子/魔王立绘或公共打包策略。其他聊天的未提交修改保留。

## 死神对话的独立集成补丁

补丁：`tools/npc_polish_death_portrait.patch`。只将 `CampaignPanels.phase3_departure()` 中原 48×48 全身 `TextureRect` 的六行创建代码替换为：

```gdscript
var portrait = preload("res://scripts/ui/camp_death_art.gd").portrait(ui.settings)
```

返回的近景仍包含兜帽、骷髅脸、镰刀和绿灯，尺寸 88×80，继续使用原 heading 和标题。`git apply --check tools/npc_polish_death_portrait.patch` 已通过。没有应用到共享文件；测试只在已创建的界面树中做同等替换，证明集成后的布局、触摸选择器和动效均可用。待拥有 `campaign_panels.gd` 的集成方应用并统一导出。此补丁本身未计入正式运行包的脚本变化，helper 已包含在当前净增量中。

## 手机视口、交互和实际包验证

验证全程持有 Windows 命名互斥锁 `MagicTa_Phase3_Parallel_Godot`，APPDATA/LOCALAPPDATA 和截图放在本项目录。桌面验证使用 Godot 4.7.2；额外建立空白 harness，**仅挂载实际导出的 `engine/godot.zip`**，使用导出同版 Godot 4.6.1 加载正式资源，无本地源资源回退。

- 320×600、390×700、540×960 三种真实 viewport，23 张改后截图（含独立补丁预览）。内容 body/scroll 高度分别为 340/340、440/440、700/700，无隐藏的纵向溢出。
- 原生触摸点击营地死神身体，寻路后进入准备页；在死神补丁预览中可触摸打开挑战选择器。
- 原生触摸打开商品详情、购买，精确扣除原价；重复购买返回错误且游戏状态不变，购买按钮均在 viewport 内。
- 10 项动效不变量验证：营地死神静止/活动帧差异，商人和死神近景静止、活动、实时开关回归中性、玩法状态不变。
- 既有 `shop_floor_test_runner.gd`：**39 checks，0 failures**，包括限购、库存恢复、存档失败回滚和重试。
- 导出 44 个文件 SHA256/长度与构建报告一致；内层 `engine/godot.zip` 及外层交付 ZIP CRC 均通过；源母版、测试、工具没有进入运行包。

日志保留了本机证书存储读取提示。Godot 4.6.1 触摸购买流程另有 6 条 `can_process: !is_inside_tree()` 引擎日志；同一空白 harness 挂载**初始审计包**执行同样三种视口购买，复现相同 6 条，数值和交互断言仍通过。本项没有修改对应的购买/销毁流程，不将这类既存日志表述为“零引擎错误”。这也不能代替微信真机验证。

主要证据：

| 场景 | 改前 | 改后 |
|---|---|---|
| 正式商店 390×700 | `build/verification/npc-polish/before/shop_390.png` | `build/verification/npc-polish/packed/after/shop_390.png` |
| 正式商店 320×600 | `build/verification/npc-polish/before/shop_320.png` | `build/verification/npc-polish/packed/after/shop_320.png` |
| 正式营地相同镜头 | `build/verification/npc-polish/before/camp_390.png` | `build/verification/npc-polish/packed/after/camp_390.png` |
| 死神对话（改后为待集成预览） | `build/verification/npc-polish/before/death_390.png` | `build/verification/npc-polish/packed/after/death_integration_preview_390.png` |

营地完整近景：`packed/after/camp_death_near_390.png`。动画对照：`packed/after/merchant_motion_a.png` / `merchant_motion_b.png`，`death_preview_motion_a.png` / `death_preview_motion_b.png`。相对路径均以 `build/verification/npc-polish/` 为根。详情与触摸购买：`packed/after/shop_detail_320.png` 等。日志：`after.log`、`packed.log`、`baseline-packed.log`、`shop.log`、`package.log`。

重复验证入口：`tools/npc_polish_verify.ps1 -Mode after|shop|package|packed`。实际 ZIP 审计与干净 harness 生成：`python tools/npc_polish_audit.py build/wechat-runs/20261004-140323-534746`。审计每次重新读取当前包体配置。
