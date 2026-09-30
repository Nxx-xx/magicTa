# 手机地图与浮动方向键

2026-09-30，源码界面更新。现有 Android APK / Windows 便携包尚未重新打包此改动。

## 布局与交互

- 删除底部横排方向按钮，左下角使用半透明十字方向键，每个方向的点击区域为 48×48 逻辑像素。点击走一格，不自动连续移动。
- 顶部集中显示楼层、生命、攻防、金币及钥匙；底部只保留行囊、楼层、记录、全图四个入口。
- 取消常驻的大块详情区域。有选中物件时，地图顶部浮出摘要，战斗损失保留独立一行；完整内容在详情页滚动显示。
- 地图视口在 360×640 为 344×461（高度约 72%），在 540×960 为 524×781（约 81%）。默认约 7.5 格宽，窄屏每格至少 44 逻辑像素。
- 镜头有跟随缓冲区，移动时平滑跟随；减少动效设置下直接更新。角色的跟随区域避开方向键和摘要，地图边界附近可能出现背景留白。
- 拖动超过 10 逻辑像素后进入查看模式，松手不触发格子交互；点击“回到角色”恢复跟随。重新使用方向键也会恢复跟随。
- 全图模式显示完整的 11×11 地图并隐藏十字键，点击格子只打开详情。点击“探索”回到角色，键盘移动在全图模式下停用。
- 剧情、交互确认、行囊等弹层打开时隐藏并禁用十字键，移除其键盘焦点；关闭后恢复。后台切换取消未完成的地图点击。

## 验证

使用当前机器可用的 Godot 4.5.1，所有测试使用独立 APPDATA / LOCALAPPDATA，不修改正式玩家存档。

- `tests/mobile_map_test_runner.gd`：无窗口 140 项通过；OpenGL 实际渲染 152 项通过，包含 12 张截图。覆盖 320×640、360×640、540×960、900×960，真实输入管线中的鼠标与合成触控事件、方向键单步、拖动不误触、放大后的点击坐标、角色四角可见性、全图只读选择、摘要文字可见性、弹层输入隔离。
- `tests/ui_visual_v01_runner.gd`：517 项通过，包含原 M1 回归及长文案、奖励、商店、死亡确认、键盘焦点、真实保存失败与恢复。修复了折叠摘要文字高度及窄屏弹层异步换行后没有重新收回屏幕内的问题。
- `tests/phase2_ui_test_runner.gd`：118 项通过，覆盖十层剧情及界面集成。
- `python tools/check_project.py`：内容、资源引用、中文字体覆盖、地图与投放约束通过；可选 gdtoolkit 不可用，脚本编译由实际 Godot 执行覆盖。
- `git diff --check` 通过。

日志位于 `build/verification/mobile-map-*.log`，截图位于 `build/verification/mobile-map/`。环境仍输出根证书读取提示；综合旧界面测试退出时有 ObjectDB 泄漏提示。新手机专项无脚本或断言错误。

尚未验证 Android 真机触感、多指同时操作、刘海屏安全区域及 Godot 4.7.2 导出。上述合成触控测试不替代真机验收。

复现专项（PowerShell，先设置本机 Godot 路径）：

```powershell
$env:APPDATA = "$PWD/build/verification/mobile-map/profile"
$env:LOCALAPPDATA = "$PWD/build/verification/mobile-map/profile/local"
& $godotExe --headless --path . --script tests/mobile_map_test_runner.gd
& $godotExe --path . --rendering-method gl_compatibility --script tests/mobile_map_test_runner.gd -- --capture
```
