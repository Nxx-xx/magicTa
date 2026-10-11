# 点击移动与公共触摸滚动交付

日期：2026-10-02。源码修复、Windows 自动验证及独立微信导出已完成；本轮微信开发者工具与 Android / iOS 真机验收未完成。保留共享目录内的原有修改，未提交 Git，未覆盖旧测试包。

## 当前操作

- 删除浮动摇杆脚本、实例、方向回调及地图底部预留区。地图不再有摇杆激活区域。
- 探索与全图都支持点击可达地板。`click_path.gd` 使用四向 BFS，逐格经过现有引擎 `interact()`；不直接写玩家坐标，不斜穿墙角。
- 中间路径允许空地和按原规则自动拾取的金币、钥匙、宝箱等；敌人、门、楼梯、商店、药剂、选项事件、休息及遗迹不会作为自动穿越格。它们可以作为点击终点，角色先靠近，再按现有规则停下、确认或显示选择；路线不自动扣钥匙、战斗、上下楼或选奖励。
- 被墙 / 尚未处理的交互隔开的目标显示不可达提示，保持角色位置。沿途可绕开障碍；每一步重新检查相邻关系、墙和中间交互，地图状态变化时停止旧路径。
- 行走中点击新目标，先收完当前一步，再从当前位置规划最新目标。路径到达后停止；键盘方向输入可以接管路径。方向键 / WASD、0.22 秒逐格行走、正式角色素材、迈步动画与左右脚步声保留。`hero_walk.gd` 已检查，无需改动。
- 拖动地图超过 10 逻辑像素后只查看地图，松手不点击地板；全图中的拖动也不变成点击。保留“回到角色”、地图跟随与目标摘要。
- 弹层、待确认交互、保存事务失败、后台、失焦、缩放或界面拖动取消旧路径，收完当前视觉步；关闭弹层不恢复旧路线。公共拖动 / 后台取消同时覆盖营地路径。

## 公共滚动与微信桥接

`touch_scroll.gd` 在地图主界面的 `_input()` 中观察输入，按可见控件与裁剪区域寻找真正命中的最内层 ScrollContainer，覆盖营地 / 加点、图鉴、行囊、楼层、记录、设置、交互详情、战报、遗迹嵌套面板和存档诊断等同一主界面下的滚动容器。无需逐面板安装补丁。

超过 10 逻辑像素才开始滚动；发送滚动开始通知取消嵌套按钮的按下状态，消费后续拖动 / 松手，避免滑动触发按钮或地图点击。普通鼠标和触摸单击仍有效，原滚动条、滚轮、文本输入及水平滑块的原生操作保留。地图控件单独拥有地图手势，不被外层营地列表抢走。

处理原生触摸、真实鼠标以及引擎模拟事件；微信鼠标随后触摸的双流只滚动一次。触摸取消先送到游戏，再派发 pointercancel，避免鼠标释放先被解释为地图点击。旧的营地专用 `safe_area.gd.in` 滚动补丁已删除，该入口只保留安全区布局。

## 自动验证

所有 Godot 检查使用 `build/verification/` 下隔离的 APPDATA / LOCALAPPDATA，未使用玩家正式存档。

| 检查 | Windows Godot 4.7.2 无窗口 | Windows OpenGL 实际渲染 | 微信副本 Godot 4.6.1 无窗口 |
| --- | ---: | ---: | ---: |
| 地图输入、寻路、中断、四种布局 | 144 / 0 失败 | 156 / 0 失败 | 144 / 0 失败 |
| 连续行走、动画、脚步声 | 31 / 0 失败 | 32 / 0 失败 | 31 / 0 失败 |
| 公共滚动、按钮、多流与战报 | 99 / 0 失败 | 99 / 0 失败 | 99 / 0 失败 |

地图覆盖 320×640、360×640、540×960、900×960、原生触摸与鼠标、改点目标、绕墙 / 不可达、敌人 / 门 / 上下楼的确认成本、触摸取消及微信双流取消。滚动覆盖菜单、四类弹层、最内层嵌套列表、独立战报、存档诊断、普通触摸按钮点击、微信单击去重及营地行走取消；被滚动容器裁剪到页头后面的地图不会响应原生触摸。

补充回归：M1 界面 251 项、视觉界面 518 项、第二阶段界面 124 项、战斗演出 88 项、共享营地集成 576 项，均零失败。旧试炼保存布局测试使用带营地账户占位的原 MapEngine 测试子类，保留原保存失败语义；出发选项测试改经营地塔口，符合当前菜单结构。

- `python tools/check_project.py`：内容、资源引用、地图约束通过；可选系统 fontTools / gdtoolkit 跳过。实际 Godot 编译 / 执行与微信字体子集检查通过。
- 微信 Node 检查：存档、原生音频、启动诊断，以及针对新包的触摸指针 / 取消顺序检查通过。配额失败日志来自预期的故障注入。
- `git diff --check`：无空白错误；仅有已有文件 LF / CRLF 提示。
- 日志：`build/verification/touch-movement/`。地图截图：`build/verification/mobile-map/explore_*`、`overview_*`、`target_*`；行走 54 帧：`build/verification/walking/frames/`；滚动截图：`build/verification/touch-scroll/nested-and-diagnostics.png`。已检查窄屏地图实际渲染。
- 运行环境仍输出根证书读取提示。部分组合界面 / 营地夹具退出有 2 个 ObjectDB 实例提示，未作为真实客户端长期运行验收。

复现 Windows 专项：

```powershell
powershell -NoProfile -ExecutionPolicy Bypass -File tests/touch_movement_verify.ps1
powershell -NoProfile -ExecutionPolicy Bypass -File tests/touch_movement_verify.ps1 -Capture
python tools/check_project.py
node tests/wechat_pointer.test.cjs build/wechat-touch/adapter.js
node tests/wechat_persistence.test.cjs
node tests/wechat_audio.test.cjs
node tests/wechat_startup.test.cjs
```

## 本轮微信可导入包

- 导入目录：`./build/wechat-touch`。
- 最新索引：`build/wechat-touch-latest.json`。
- 构建报告 / ZIP：`build/wechat-runs/20261002-120132-510806/build-report.json`、同目录 `TowerRealm-WeChat.zip`。
- AppID：用户已有 `wx57ebf150a77fedb9`。Godot 4.6.1 / 插件 0.2.1，沿用 high-performance-plus 设置，未更改先前的 iOS 对照包。
- 主包约 1.21 MiB，总包约 18.88 MiB；字体子集覆盖检查、导入、导出、产物哈希记录通过。包含共享目录中当时已接入的营地代码；主游戏脚本与当前源码一致。
- 构建命令：`python tools/build_wechat.py --appid wx57ebf150a77fedb9 --output-folder wechat-touch`。

## 未完成的实际客户端验收

本轮未在微信开发者工具导入 / 编译 / 操作，也未上传新预览或生成新二维码。包报告保留 `devtools:false` 与 `device:false`。Godot 4.6.1 桌面上的构建副本检查不代表微信 Web/WASM 引擎或真机已通过。

待验收：Android / iOS 微信中点击远处地板、绕墙、改点目标、开门 / 战斗 / 楼梯确认，营地老骑士与加点长列表、战报 / 图鉴 / 遗迹 / 设置拖动，多指与系统边缘手势，切后台 / 重进 / 缩放及存档恢复。此前 iOS 闪退问题仍需独立真机反馈；本操作修复不宣称解决该问题。

Windows 便携导出与 Android APK 未重新打包本轮操作。源码可直接以 Godot 4.7.2 运行；旧 Windows / Android / 微信摇杆包不自动包含本修复。
