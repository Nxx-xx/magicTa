# 战斗舞台 v02 · 月夜石厅 / 遗迹 / 封印圣堂

2026-10-04。普通石厅原画样板已先在聊天中展示，随后接入实际播放器。三张环境由内置 imagegen 生成，风格参考为已完成的月夜魔塔加载页与主菜单人物插画。

## 实际接入

- 普通石厅：雕刻尖拱、旧铜双灯、冷青石板与后窗月光。
- 遗迹：不对称断拱、破损窗棂、远方魔塔、边缘藤蔓和单灯。
- Boss 圣堂：封印铜门、天象浮雕、暗红垂旗和低位火盆。
- 运行底图等比填充，裁切以角色站立地面为基准；角色锚点、显示尺寸与正式动画沿用现有实现。接地阴影、边缘遮光和前景战斗反馈仍为原生可编辑绘制层。
- 默认普通石厅；骷髅、蝙蝠、术士和蓄焰术士采用遗迹氛围；牛头人、魔像或 boss rank 使用圣堂。可选 `environment` 参数支持明确指定三种环境，非法值安全回退。这里是按遭遇区分环境，不新增遗迹事件战斗或改变地图规则。
- 旧局播放器采用同一环境选择；不更改旧局演出时序与结算页逻辑。

## 保存与可编辑内容

原画与完整提示词：`assets/environment/battle_v02/source/`。运行纹理：`assets/environment/battle_v02/textures/`，各 576×768 RGB，Godot 有损质量 0.72，无 mipmap。原画为完整平面绘画，不冒充 PSD 分层源；可编辑场景：`assets/environment/battle_v02/scenes/*_editable.tscn`；环境、接地阴影与反馈分层代码：`scripts/ui/art_polish_c_stage.gd`。

源目录带 `.gdignore`，现有微信构建脚本也排除 `source/`。不需要改动构建资源白名单。全提示词、原画和运行文件 SHA256 位于 `build/verification/battle-polish/asset-provenance.json`。

## 行为保留

相对本聊天开始时快照，第三阶段播放器仅增加环境字段、configure 选择和 ready 设置；旧局播放器仅扩展背景绘制调用。44 个受保护函数内容一致，伤害数字与战斗反馈函数逐字一致。证据：`build/verification/battle-polish/preservation-audit.json` 及同目录三个 `.diff`。

未编辑敌人 manifest、候选图、敌人贴图或发布记录；敌人资源可能由并行聊天继续更新，截图采用执行时的正式 manifest。未编辑核心战报、动作事件、玩法数值、结算或存档协议，未覆盖其他未提交成果。

## 复现入口

```powershell
./tools/battle_polish_verify.ps1 -Capture
# 原画重新缩放及验证：
./tools/battle_polish_verify.ps1 -Bake -Capture
# 真实游戏，独立存档；退出窗口才释放公共锁：
./tools/phase3_v05_godot_locked.ps1 -Group art-polish-c -Label battle-v02-play -RunTimeoutSeconds 7200 -GodotArgs @('--script','res://tools/art_polish_c_play.gd')
# 仅独立本地微信包，不上传：
./tools/battle_polish_wechat.ps1
```

所有 Godot 运行遵守 `MagicTa_Phase3_Parallel_Godot` 公共锁。手机截图及实际战斗证据输出在 `build/verification/battle-polish/`。独立微信目标为 `build/wechat-battle-polish`，不修改共享 current/latest。

## 验证、预算与限制

| 验证 | 本次结果 |
| --- | --- |
| Godot 4.7.2 导入 | 最终导入通过，无脚本错误 |
| 13 敌 × 320/390/540 宽度 | 482 检查，0 失败；环境路由、布局、数字/正文分离、六秒目标、暂停、跳过只读、初始/中途减动效与像素冻结 |
| 原回放时序 | 20 检查，0 失败 |
| 旧局战斗表现 | 88 检查，0 失败 |
| 真实首战存档失败、重试、关闭、重载 | 9 检查，0 失败 |
| 真实第五层牛头人公开路线 | 201 检查，0 失败 |
| 真实第十层魔像公开路线 | 374 检查，0 失败 |
| 史莱姆 / 蓄焰术士 / 魔像原速及 0.25× | 六组真实定时渲染序列完成，无脚本/引擎错误；属于模拟已提交战报夹具 |
| 独立 Godot 4.6.1 微信导出 | 导入、导出及资源核验完成；整包预算检查失败，未发布 |

以上套件检查范围重叠，不相加为唯一检查数。普通小怪、13 敌联系表、320 宽魔像、390 宽牛头、第三回合蓄焰/反伤与减动效图均经模型视觉检查；真实路线连续帧证明角色动画保留。审阅页：[review.html](../build/verification/battle-polish/review.html)，三舞台：[three-stages.jpg](../build/verification/battle-polish/three-stages.jpg)。完整分辨率 PNG 保存在 mobile/ 及 host-* 下。复建审阅页需使用带 Pillow 的 Python 运行 `tools/battle_polish_review.py`。

实测新增三套背景、纹理 remap、三份可编辑场景及其 remap 在 `engine/godot.zip` 中压缩条目合计 **210,787 bytes（205.85 KiB，0.201 MiB）**，低于原 C 组 0.35 MiB 建议额度；未包含 ZIP 条目头与共享脚本差值，也不是整包前后净增。原画/提示词未进入导出。三张纹理解码 RGB 总量 **3,981,312 bytes**；按 RGBA 估算上限 **5,308,416 bytes**，非手机实测内存。此实现预加载三张纹理，不随每帧重新加载。

独立微信包总量 **22,310,055 bytes（21.28 MiB）**，主包 **2,427,542 bytes（2.32 MiB）**；超过项目总量 20 MiB 门槛。即使扣除上述全部舞台条目，仍为 **21.08 MiB**，因此不能仅通过移除本次背景恢复预算。未调整其他组的资源或预算规则，未更新任何共享 current/latest。原始构建报告：`build/wechat-runs/20261004-023346-864060/build-report.json`；本组核算：`build/verification/battle-polish/package-audit.json`。`build/wechat-battle-polish/` 为完成导出的本地检查目录，不是通过预算的可发布交付；预算检查失败后未生成成功的 archive/latest 指针。

构建期间保留失败日志：最初命令行数组传参错误导致错误启动；首次导入发现绘制 API 两个参数顺序错误，已修正并重新通过导入。原画读取的工具期告警只属于离线缩放脚本，生产运行只加载已导入纹理。系统根证书库提示与脚本错误分开记录。

绘画灯光静态，不增加环境动画或粒子负担；减动效仍进入安静战报。桌面窗口截图与自动检查不代表手机真机、微信客户端性能或人工最终美术签收。未上传、未发布线上。
