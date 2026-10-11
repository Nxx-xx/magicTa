# 全游戏精修 · 并行聊天分工

2026-10-03。用户要求把剩余分阶段计划下发给几个独立聊天同步实施。四个制作聊天在同一工作区 . 工作；本统筹聊天负责全局方向、共享文件协调、整合验收和更新试玩包。

## 已下发聊天

- A「画面精修 A · 主角与营地 NPC」：01a100bd-d7bf-7211-9c3f-9864244f65e4。
- B「画面精修 B · 怪物与 Boss」：01a100bd-eb64-7c10-a099-7bffc3a4457f。
- C「画面精修 C · 战斗舞台与反馈」：01a100bd-fc76-74d0-894e-ad93f9dd83e4。
- D「画面精修 D · UI 与剧情画面」：01a100be-18fb-7091-8a59-98b9530393d8。
- 统筹「全游戏画面精修 · 分阶段实施」：01a10067-7a29-72b0-ab7d-8af9253915af。

四组均已下发可直接实施的完整任务，使用项目本地环境，不需要手工转发计划。

## 制作范围与文件归属

| 聊天分工 | 任务 | 专属主要文件 | 不得直接修改 |
| --- | --- | --- | --- |
| A 主角与营地 NPC | 先统一老骑士，再精修主角和其他 NPC 的比例、材质、握点、接地与已有动作 | assets/characters/**，scripts/ui/camp_board.gd、camp_knight_art.gd、camp_death_art.gd、phase3_animation_catalog.gd；独立命名的制作工具/测试 | grid_board、hero_walk、hero_gait、map_screen、公共战斗播放器；怪物资产 |
| B 怪物与 Boss | 现有 13 敌人的轮廓、材质、动作与地图尺寸一致性；核实并处理最新魔像精修欠项 | assets/monsters/**，scripts/ui/phase3_enemy_player.gd、phase3_enemy_map_art.gd；独立命名工具/测试 | phase3_combat_player、grid_board、主角资产；核心规则 |
| C 战斗舞台与反馈 | 舞台环境、接触阴影、命中/受击/退场、机制特效和文字层级 | scripts/ui/phase3_combat_player.gd、combat_presentation.gd；新增 assets/effects/art_polish/**、assets/environment/combat_polish/**，独立 helper/工具/测试 | 敌人播放器、角色原画/manifest、map_screen、核心结算与战报 |
| D UI 与剧情 | 主菜单/HUD/交互面板/图标/剧情画面风格统一，维持已有单屏和二级入口设计 | map_screen.gd、main_menu.gd、camp_map.gd、UI 面板/主题；assets/ui/**、assets/story/**；独立工具/测试 | camp_board、grid_board、角色/敌人资产、战斗播放器、核心规则 |
| 统筹 | 美术复核、冲突处理、最终全流程与导出 | grid_board.gd、tower_environment.gd、runtime_art.gd、构建脚本、全局计划与交付、current/latest | 不覆盖各组正在制作的文件 |

需要跨所有权修改时，先在自己交付文件中给出具体补丁/契约；由统筹处理，避免整文件覆盖。新建工具/测试使用 art_polish_a_/b_/c_/d_ 前缀。各组文档分别为 docs/ART_POLISH_A_DELIVERY.md 等，不编辑本文与全局计划。

## 统一执行要求

先读 FULL_GAME_ART_POLISH_PLAN.md、TOWER_POLISH_DELIVERY.md、phase3/COMPLETION_FOLLOWUP.md 和当前资产的 v06 REVIEW/HANDOFF；历史 README 不代表当前生产状态。已有大量用户未提交成果，禁止 reset/clean/批量覆盖。先实际看图，直接开始制作并接入专属运行入口，不停在方案；已授权范围内不逐阶段索要批准。

美术统一为冷青环境、暖金光源、灰蓝石材与旧金属；控制角色/物件比例、材质和轮廓。已有原生分层资产优先继续编辑，新栅格使用内置 image_gen，保留项目内源图与提示词。新版本独立存放；保留方向、持物、锚点、事件、动画时序、旧局兼容和源文件。不要用调色或分辨率代替精修。

每组先一个实际样板，再扩展到本组范围。保存改前/改后 320/390/540 实际游戏截图、全图/近景或角色逐帧；正常/慢速/减少动效和相关回归都要检查。使用隔离存档。Godot 导入/渲染/测试通过 tools/phase3_v05_godot_locked.ps1 公共锁串行执行，Group 分别 art-polish-a/b/c/d；需特定 profile 的既有测试沿用适当隔离目录，不能读真实存档。不要同时运行未加锁的 Godot。

当前微信 18,079,024 bytes / 20 MiB，剩余 2,892,496 bytes。各组只报告新增/替换资源及预算，禁止改构建预算、更新 current/latest 或各自全量导出。优先复用与新版本替换，统筹会排除已退休历史运行图。建议净增压缩预算 A 0.75 MiB、B 0.90 MiB、C 0.35 MiB、D 0.40 MiB，保留约 0.36 MiB 缓冲；最终以统一实际包为准，不能全面降质凑预算。

当前可回退包与 source 见 TOWER_POLISH_DELIVERY.md。微信构建固定 Godot 4.6.1，主工程 4.7.2；桌面截图不等于微信开发者工具/真机验收。

每组完成后，在自己的交付文档写清变更文件、运行接入、截图、测试、包体影响、未完成项及跨组补丁。统筹从聊天状态和文件取回结果，无需让用户手动转发。阶段 5 的最终集成在四组交付后执行。
