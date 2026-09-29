# 第二阶段界面与表现交付

日期：2026-09-29。这里仅记录界面线程的实现和验证；整塔生成、数值、存档等完整验收见统筹交付。

## 已接入

- 营地同时保留两层试炼和十层营救入口；进行中重开通过放弃确认，存档待提交期间禁止新开局。
- 分页故事对白、现有公主立绘、新王子 / 魔王立绘；固定继续与跳过按钮、滚动长字幕、焦点隔离。跳过只确认故事，不重复结算。死亡读档静态摘要不播放声音。
- 楼层索引列出已到达层、守卫、待领取奖励、剩余休息点和商店状态；展开只读地图。目标可在详情标记，索引显示标记时与当前敌人损失，已完成目标仍能对照。个人标记存于独立 presentation.cfg，不改地图随机数或玩法状态。
- 十层失败 / 成功 / 放弃结果页：灵魂来源、击杀、受伤、治疗、溢出、回溯、消费、路线、种子、装备和地图复盘；同种子、新种子、营地入口。营地支持三级火种、预览属性、明确价格购买、确认免费重置和最近五局记录。
- 原子存档失败时出现“尚未保存 · 请重试”阻断页；错误始终可见、可以重试，保存成功后恢复。退出按钮与窗口关闭都会明确确认丢弃未保存变化，默认取消；上次成功存档保留。仅保存结果成功后播放故事。
- 四向主角静态贴图、地面 / 连墙 / 门钥匙等环境资源、六普通怪与四精英 / Boss 贴图接入；墙体遮罩按四向连接，深层采用冷色调。保留三色钥匙文字、怪物强度 / 回溯角标、目标选择框与缺图矢量回退。
- 角色短距离平移、拾取 / 受伤闪光；声音含短步伐 / 开门 / 拾取 / 命中 / 胜利合成提示音。死亡优先播放系统 TTS 加工的王子人声原型，素材不存在时退回非人声回声咒。静音、分立语音 / 效果音音量、关闭受罚语音、减少动效均保存。

主要文件：scripts/ui/map_screen.gd、grid_board.gd、campaign_panels.gd、runtime_art.gd、presentation_settings.gd、audio_feedback.gd。

## 验证

Godot 4.7.2，独立 APPDATA / LOCALAPPDATA 为 build/verification/phase2-ui，未读取玩家存档。

- tests/phase2_ui_test_runner.gd：无头 118 检查通过，0 失败；实际 OpenGL Compatibility / NVIDIA RTX 5070 GPU 149 检查通过，0 失败。
- 包含 540×960、360×640、900×960、320×640 布局、长中文字幕滚动、固定继续 / 跳过、实际 Tab / 方向输入隔离、只读地图、标记、真实致死战斗仅结算一次、音频只首播、导入的 prince_cry_1.wav 被使用、按钮购买 / 确认退款、真实磁盘写入失败及重试恢复、取消退出保留未保存事务、两层进行中配置火种不改试炼属性、四新增敌人贴图加载与首领角色名、静音与减动效。
- 沿用 tests/ui_visual_v01_runner.gd，包括原 M1 回归，526 检查通过，0 失败。
- 证据在 build/verification/phase2-ui：headless_test.log、gpu_test.log、legacy_ui_test.log、map_*、story_*、prince_*、floors_*、save_blocked_*、result_*、camp_*、monsters_*、failure_360x640.png。已目视检查小屏与标准尺寸，修复墙路对比和错误条遮挡标题。
- result_* 使用专门界面夹具构造完成状态，仅证明结果页布局，不是全塔通关证据；failure_360x640 来自真实生产战斗结算。整塔可解验证由核心测试提供。

运行方式（PowerShell，项目根目录）：

```powershell
$env:APPDATA = Join-Path (Get-Location) 'build/verification/phase2-ui/appdata'
$env:LOCALAPPDATA = Join-Path (Get-Location) 'build/verification/phase2-ui/localappdata'
& 'godot' --headless --path . --script res://tests/phase2_ui_test_runner.gd
& 'godot' --path . --rendering-method gl_compatibility --script res://tests/phase2_ui_test_runner.gd -- --capture
```

## 已知限制

人物仍使用合格的四向静态图，短距离平移不是逐帧走路动画；十种敌人均有静态贴图，缺图仍可退回矢量图标，尚无敌人逐帧动画。声音是合成原型，不是真人演出；目前未进行外部玩家试听、手机真机或移动浏览器验证。楼层索引不传送，也不修改结束局。系统根证书读取告警不涉及本地资源播放；最终新旧界面 runner 均未出现脚本错误或资源泄漏告警。
