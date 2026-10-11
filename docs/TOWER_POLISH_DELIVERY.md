# 塔内空间精修 · 第一阶段交付

2026-10-03。全局方向和后续阶段见 [FULL_GAME_ART_POLISH_PLAN.md](FULL_GAME_ART_POLISH_PLAN.md)。本次交付塔内环境首批可玩成果，不表示角色、战斗、UI、剧情和全平台验收已全部完成。

## 已接入

- 将地图绘制拆为地形、环境、实体/徽记/选框三个顺序层；正式角色、怪物和遗迹动画继续使用原生产清单。
- 墙脚接触阴影、分块磨损石檐、石柱接缝和跨格裂隙改善墙地层次；复用 v01 火把、挂旗，按墙格放置装饰。局部暖光检查墙格遮挡，仅换层计算可见源，减少动效固定明暗。
- 门和楼梯增加基座与暗部，遗迹和两种 Boss 增加克制的地面纹样。营地返回口与塔顶终点使用新石拱原画，保留“营 / 终”徽记及原交互格。
- 新原画由内置 image_gen 生成，1254×1254 透明 PNG 与完整提示词保存在 assets/environment/tower_v02/；按实际单格显示用途导入为 256px 并保留 mipmaps。没有放大其他资源或全面降画质。
- 绘制 helper 为 scripts/ui/tower_environment.gd，接入点为 grid_board.gd。CampBoard 自己绘制底图，营地 v3 保持原有外观。地图 rows、实体位置、碰撞、数值、输入、存档和正式动画未修改。

画面经历三轮实际审阅：第一轮石檐过亮、柱面像金属架，已减弱并改成磨损石块；第二轮石拱过于简化，改用新原画。大块墙顶仍使用既有 v01 石材，角色比例和不同来源风格仍属第二阶段待办，不将本批称为全套重绘。

## 对比与验收

同 seed 42、同机位、同实际 viewport，1/2/5/10 层各有 320×640、390×700、540×960 全图和近景。教学提示通过生产“跳过教学”事件收起以便看清场景；教学与操作控件仍由现有 UI 回归覆盖。

| 场景 | 修改前 | 修改后 |
| --- | --- | --- |
| 首层近景 540 | [before](../build/verification/tower-polish/before/floor1_near_540.png) | [after](../build/verification/tower-polish/after/floor1_near_540.png) |
| 遗迹全图 390 | [before](../build/verification/tower-polish/before/floor2_overview_390.png) | [after](../build/verification/tower-polish/after/floor2_overview_390.png) |
| 牛头近景 390 | [before](../build/verification/tower-polish/before/floor5_near_390.png) | [after](../build/verification/tower-polish/after/floor5_near_390.png) |
| 塔顶全图 320 | [before](../build/verification/tower-polish/before/floor10_overview_320.png) | [after](../build/verification/tower-polish/after/floor10_overview_320.png) |

完整前后各 26 张，含两张动效样本；浏览对照见 [review.html](../build/verification/tower-polish/review.html)。高层通过生产生成器直接建立截图夹具，不冒充自然通关。主线程已看首层、遗迹和两个 Boss 的手机全图/近景，以及微信压缩资源塔内和营地画面；路线、标记、文字与底部操作保持可辨。未改变输入区域；320 宽底部控件仍由现有 UI 布局管理。

正常模式帧变化、减少动效画面像素冻结、渲染前后游戏状态不变均通过。截图来自 Godot 实际 viewport，不是生成的效果图。微信压缩资源桌面截图在 build/verification/tower-polish/wechat/。

## 验证记录

主工程 Godot 4.7.2，隔离存档；以下套件共 2,980 条检查，各自零失败，不把重叠测试数量当作美术质量证明。

| 既有套件 | 检查数 |
| --- | ---: |
| mobile_map_test_runner | 144 |
| walking_test_runner | 31 |
| walking_polish_test_runner | 180 |
| camp_map_test_runner（无 capture） | 582 |
| phase3_ui_host_test_runner | 130 |
| phase3_v06_hero_regression_phase3_hero_map_test | 47 |
| phase3_ruin_art_test | 143 |
| phase3_v06_golem_production_test | 1,723 |

首轮误选旧 tests/phase3_hero_map_test.gd，其 v03 的 1.5 MiB 缓存断言失败；当前 v06 包含四个无效果减动效姿态，现有 v06 套件明确期望 1.75 MiB，重新执行通过。未改变生产动画或放宽原测试；失败日志仍保留。截图夹具最初误用 spawn 字段，已改为生产 entry，保留 before.log。环境证书存储提示单独列为运行环境告警，最终没有脚本/资源编译错误。

Godot 4.6.1 微信隔离源码：塔内 26 张捕获、营地全图/近景和动效检查、v06 主角 47 项、全 13 敌人生产动画 1,723 项均通过。复制验证脚本发生在导出后，不打入 ZIP。桌面闲置 120 帧样本中位约 6.95 ms、P95 7.17 ms（RTX 5070、VSync 包含在内）；不是手机或完整战斗性能承诺。

微信音频、持久化、启动与指针四组 Node 测试通过；退休资产筛选安全测试 4 项通过。60 个核心/动画相关文件及 3 份生产 manifest 与本轮前哈希一致。日志根目录：build/verification/tower-polish/。

## 最新试玩包

- 当前可导入目录：`build/wechat-current`。
- 独立同内容目录：`build/wechat-tower-final`。
- 构建及归档：`build/wechat-runs/20261003-143432-609450/TowerRealm-WeChat.zip`。
- 回退目录：`build/wechat-current-before-tower-20261003`；原独立 `build/wechat-camp-polish` 也保留。
- `build/wechat-latest.json` 与 `build/wechat-current-latest.json` 已更新；42 个交付文件逐一验证 SHA256，两个 ZIP 均通过 CRC。
- 总包 **18,079,024 bytes（17.24 MiB）**，主包 **1,267,927 bytes**，20 MiB 阈值下余 **2,892,496 bytes（2.76 MiB）**。原阈值未调整。
- 仅 staging 排除 192 张已退休历史图及 sidecar；生产 1,162 个 PNG remap/纹理 payload 完整，384 个退休路径不在包内。主工程历史图与可编辑源均保留。完整预算审查见 TOWER_POLISH_PACKAGE_AUDIT.md。

本次没有完成微信开发者工具或真机复验；build-report 中 devtools/device 保持 false。Windows/Android 历史安装包未重建。源码和压缩资源桌面通过，不等同于微信客户端、低端机性能或真人玩法签收。

## 复现

```powershell
./tests/tower_polish_verify.ps1 -Capture
python tests/wechat_art_budget_test.py
python tools/build_wechat.py --appid wx57ebf150a77fedb9 --ios-mode high-performance --output-folder wechat-tower-final
./tests/tower_polish_stage_verify.ps1
python tools/verify_tower_polish_package.py
```

重建时建议另取新 output-folder 保留现有交付；stage_verify 和 verify 工具目前读取 wechat-tower-final-latest.json。测试仅使用 build/verification 下隔离存档。current 更新是最后单独步骤，不由构建自动执行。

## 2026-10-04 后续：墙地与建筑组件 v03

审查清单第 2 项的新材质、墙角/墙脚/门框/楼梯及三组楼层建筑风格已正式接入，独立包为 `build/wechat-tower-redraw`，没有更新 current/latest。前后截图、原画来源、验证和实际包体见 [TOWER_REDRAW_DELIVERY.md](TOWER_REDRAW_DELIVERY.md)。上文保留为 2026-10-03 的历史交付记录。
