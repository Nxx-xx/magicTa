# 主角四向素材 V01

> 2026-10-01 更新：V01 继续作为旧局和缺失资源回退；第三阶段新局已接入四向分层与完整 91 帧位目录，见 [v03 审阅](phase3/source/rig_v03/REVIEW.md)。本文下述“行走尚未完成”仅描述历史 V01，不代表当前第三阶段运行状态。

制作日期：2026-09-29。美术由 **Codex 内置 image_gen** 生成，身份与风格来源为用户批准的 `assets/art_concepts/hero_design_v01.png`，整体风格另参考 `tower_character_map_v01.png`。没有直接裁切带背景设定图作为游戏素材，没有镜像人物，没有脚本绘制替代人物。

**交付状态：四向静态可用；基础行走尚未完成。** 两轮各 16 帧的行走生成均未通过步态审查，只保留为明确标记的草稿。正式 SpriteFrames 仅包含四个单帧 idle，不包含 walk。主游戏入口、绘制路径、地图和玩法均未修改。

## 正式文件

- `textures/idle_down.png`：朝屏幕下/正面。角色右手剑在画面左，角色左手灯在画面右。
- `textures/idle_left.png`：朝屏幕左。近侧左手提灯，远侧右手短剑部分遮挡。
- `textures/idle_up.png`：朝屏幕上/背面。灯在画面左，剑在画面右，修正了设定图底部背向持灯错误。
- `textures/idle_right.png`：朝屏幕右。近侧右手持剑，远侧左手提灯。
- `hero_idle.tres`：四个动画名为 `idle_down`、`idle_left`、`idle_up`、`idle_right`；各 1 帧，帧编号 0，loop=true，1 FPS（单帧无可见动作）。

每张纹理为 **128×128 RGBA PNG**，保留真实 alpha。统一脚底锚点 **(64,116)**，主体约高 104 px，外围至少 3 px 完全透明。精绘轻 2.5D、小比例银白短发、青绿眼睛、青绿兜帽斗篷、古金纹饰、深色皮甲、腰包、长靴、右剑左灯均保留。镜头为轻微俯视的正交游戏视图，侧面道具有自然遮挡，不保证两只手都能完整看见。

Godot 建议：`AnimatedSprite2D.sprite_frames = hero_idle.tres`，`centered = false`，`offset = Vector2(-64,-116)`，脚底锚点放在目标位置。`flip_h` / `flip_v` 均保持 false，方向切换播放对应 idle。线性过滤，纹理无损导入，mipmap=false，fix_alpha_border=true。

## 分辨率与网格

当前 `grid_board.gd` 使用 `min(size.x,size.y)/11`。已实际实例化当前 M1 界面验证：

| 窗口 | 棋盘宽 | 单格 | 素材主体显示高度 |
|---|---:|---:|---:|
| 540×960 | 516 | 46.91 px | 38.11 px |
| 384×720 | 360 | 32.73 px | 26.59 px |
| 360×640 | 288 | 26.18 px | 21.27 px |

以上为无存档错误面板的正常探索布局；出现错误面板时棋盘还会缩小。预览使用 `scale = tile_size/128.0`，脚底位于格子横向中点、纵向 93%。47 px 下可辨斗篷、剑、灯与朝向；26 px 下金纹、眼睛与握持细节无法可靠辨认，主要依靠轮廓、发色与暖光。不要把高分辨率细节在小格内不可见误判为缺少素材。

## 源图与加工

`source/idle_generated_v01.png` 是内置 image_gen 的原始透明四向图集，**实际输出 1254×1254**，2×2 单元为 627×627，按下、左、上、右顺序。提示词请求的尺寸不作为实际尺寸保证。

`source/normalized/idle_*_256.png` 为统一 256×256 的中间母版，脚底 (128,232)，主体高 208 px。`tools/export_hero.gd` 只做确定性的图集拆分、按靴底定位、透明画布注册、预乘 alpha 的 Lanczos 缩放及透明边缘 RGB 处理；不创作或替换人物局部，不改持物方向。所有原始 alpha 图保留可追溯。正式纹理从母版降至 128×128，在目标格子进一步线性缩小。

最终实际使用的完整提示词及两轮行走修订提示词均在 `source/prompts.md`。源图和报告目录各有 `.gdignore`，中间图、草稿和截图不会作为游戏纹理导入。正式资源引用仅指向 `textures/` 中四张 PNG。预览在编辑器/本地项目中通过原始文件读取草稿，不应将草稿作为游戏导出依赖。

## 行走未通过原因

`source/walk_generated_v01_rejected.png` 和 `source/walk_generated_v02_rejected.png` 保留两轮原图。第二轮明确要求修正第 3 帧为相反脚接触，但仍未稳定实现。

- 每行从左至右原计划：左脚接触、右脚经过、右脚接触、左脚经过；实际前后视图大多仍为同一侧领先腿，侧面也没有可靠的相反腿接触关系。
- 部分帧有小幅外形与脚部位置变化，但这不足以构成完整行走循环；循环播放有跳动，不能宣称脚底稳定或动作完成。
- 左视角武器和提灯手臂的重叠在草稿中更明显；头、斗篷局部与静态图也有差异。
- 第二轮原图按 4×4 拆分为 `reports/draft_frames/`，**仅为审查**。草稿保留原始单元内的位置变化，未用强制对齐掩盖漂移。预览按 0→1→2→3、6 FPS 播放，速度只是检视设定，不是发布动画参数。

下一步仍需得到稳定交替腿的四向动作画格（或在这些已确认静态母版上做人工分层动画），再验收脚底与头身稳定性，才可新增正式 walk SpriteFrames。

## 独立预览和验证

场景入口：`preview/hero_preview.tscn`。窗口 1060×900；按 **1** 查看静态，**2** 查看未通过草稿，**空格** 暂停，**右箭头** 逐帧。顶部大图用于轮廓和边缘检查，下方显示真实 47/33/26 px 格子，不缩放截图冒充小尺寸效果。

推荐使用 PowerShell 启动器（自动隔离 APPDATA/LOCALAPPDATA 到 `build/verification/hero/` 并在结束后恢复环境变量）：

```powershell
& './assets/characters/hero/tools/preview.ps1'
& './assets/characters/hero/tools/preview.ps1' -Validate
& './assets/characters/hero/tools/preview.ps1' -Capture
```

`-Rebuild` 可重新执行确定性导出并导入 Godot 资源。预览脚本本身不引用游戏存档模块；验证仅在检查隔离路径后实例化无持久化的当前界面，用单独 `user://hero_layout_fixture.json` 读取路径。没有读取玩家 APPDATA 存档。

Godot **4.7.2 stable** 验证结果：**25 项通过，0 项失败**。检查包括正式 SpriteFrames 名称与帧数、四图尺寸、真实 alpha、三像素透明边界、四向脚底在 y=116±1 内、源图与报告忽略标记、三个实际窗口的棋盘尺寸。采用独立 PNG，无共用图集采样，杜绝正式资源邻帧串图。静态单帧没有帧间漂移；四方向切换的脚底基线已校准，造型本身仍存在自然的透视差异。

实际 GPU 渲染：OpenGL Compatibility / NVIDIA GeForce RTX 5070，已生成并目视检视 `reports/idle_godot.png` 和 `reports/walk_rejected_phase_0.png`，另保存草稿 phase 1–3 截图。深浅棋盘背景未见矩形底色或明显白边。正式素材放大预览使用运行时 128px 纹理，会比 256px 母版柔和，符合运行时过滤行为。

机器报告：`reports/validation.json`、`reports/texture_metrics.json`。引擎启动输出过系统根证书库读取告警；本任务无联网依赖，离线导出、资源加载和 GPU 截图均成功。未提交、推送或重置 Git；项目原有改动与其他并行工作保留。

## 2026-10-01 主地图运行时行走

主地图现使用 `scripts/ui/hero_walk.gd` 的纹理网格与 CanvasItem shader，在上述四张正式 idle 素材上实时表现交替迈腿、身体起伏和斗篷轻摆；原 PNG、静态 SpriteFrames 和未通过的生成草稿均未改动。此为运行时形变动画，不是新增手绘 walk 帧序列。`grid_board.gd` 以连续插值衔接移动，朝向在步段交界切换，落脚发出脚步事件。减少动效关闭姿态起伏但保留平滑位移。

`tests/walking_test_runner.gd` 验证持续输入、跨格连续性、转向、停步及音频；实际 OpenGL 录屏见 `build/verification/walking/continuous-walk.gif`。这是主地图集成更新，以上早期静态素材交付记录保留。
