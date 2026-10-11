# 塔内墙地与建筑组件精修 · 审查清单第 2 项

2026-10-04。本轮完成探索地图环境的正式接入，承接 [上一轮交付](TOWER_POLISH_DELIVERY.md)。不是全游戏美术或真机验收。

## 实际接入

正式地图原来通过 `runtime_art.gd` 动态引用 tower_v01 的墙地贴图。已改为 `tower_masonry.gd` 采样 tower_v03 材质，跨格连续铺设；旧文件全部保留。旧 README 的“未接入”没有作为判断依据。

- 墙顶：连续低对比岩面，六格一个材质周期，消除每格同一条裂纹的重复。
- 地面：四格一周期的大石板错缝；高层使用另一组浅青仪式石板。
- 建筑：按真实墙邻接拼接石檐、墙脚暗槽、墙角端柱；中高层增加墙内扶壁、旧金属箍和饰带。第 5、10 层的冠形小刻纹只出现在墙面。
- 门：原门面和铜/银/金徽记保留，补同材质门框。楼梯：新生成的独立上行/下行组件，保留“上 / 下”徽记与原交互格。
- 灯火：复用既有真实墙格灯具、暖光遮挡检查、挂旗和实体接地。环境始终画在实体、选框和标记下面。
- 1–3 / 4–7 / 8–10 层形成三种建筑家族，不宣称十层各有独立原画。

公共 `grid_board.gd` 相对本轮基线仅两个改动：地形层调用和楼梯纹理选择。没有修改 runtime_art、敌人资源/manifest、战斗舞台、assets/items、公共 Theme、菜单、加载页和图标。没有调整地图 rows、碰撞、位置、生成器、门钥匙规则或存档。

## 原画与样板审阅

使用 **imagegen skill / 内置 image_gen**，无外部 CLI。源图、精确提示词、来源哈希见 [tower_v03/source](../assets/environment/tower_v03/source/) 和 [provenance.json](../assets/environment/tower_v03/source/provenance.json)。

- 原始材质 atlas 1254×1254；首轮实机审阅后以 imagegen 编辑收敛墙顶粗糙起伏，保留两个版本。
- 透明双楼梯源图 1774×887，保留 alpha。
- 运行 PNG 是选定源图的原样副本。仅这两张新图的导入尺寸分别设为 1024 / 512，开启 mipmaps。未全局降画质。
- 原生绘制石檐最初横线过硬、立面纵向压缩过多，实际近景审阅后改为材质石檐、单层砌块取样和更窄的边缘。首轮样板保存在 `build/verification/tower-redraw/sample-01/`。

## 前后截图

固定 seed 42、同镜头中心，1/2/5/10 层，320×640、390×700、540×960 全图和近景，前后各 26 张。高层由生产生成器建立美术夹具，不冒充自然通关。同期 UI/敌人属于其他聊天，不能把它们的画面变化算入本轮环境成果。

交互对照：[review.html](../build/verification/tower-redraw/review.html)。

| 场景 | 本轮基线 | 正式接入 |
| --- | --- | --- |
| 首层近景 540 | [before](../build/verification/tower-redraw/before/floor1_near_540.png) | [after](../build/verification/tower-redraw/after/floor1_near_540.png) |
| 首层手机全图 320 | [before](../build/verification/tower-redraw/before/floor1_overview_320.png) | [after](../build/verification/tower-redraw/after/floor1_overview_320.png) |
| 遗迹全图 390 | [before](../build/verification/tower-redraw/before/floor2_overview_390.png) | [after](../build/verification/tower-redraw/after/floor2_overview_390.png) |
| 中层扶壁近景 390 | [before](../build/verification/tower-redraw/before/floor5_near_390.png) | [after](../build/verification/tower-redraw/after/floor5_near_390.png) |
| 塔顶近景 390 | [before](../build/verification/tower-redraw/before/floor10_near_390.png) | [after](../build/verification/tower-redraw/after/floor10_near_390.png) |

已实际查看上述代表画面，以及 Godot 4.6.1 微信压缩资源首层全图、塔顶近景。路线、门/楼梯标记、角色及交互物可读。压缩资源截图另存 `build/verification/tower-redraw/wechat/frames/`。

## 验证

所有 Godot 操作持有 `MagicTa_Phase3_Parallel_Godot` 公共锁；桌面测试通过既有锁脚本，微信导出及 staging 验证在同名互斥锁内。APPDATA/LOCALAPPDATA 位于本轮 build/verification 下；截图夹具关闭持久化。

| 检查 | 结果 |
| --- | --- |
| 16 种墙邻接 × 3 建筑家族，检测通路内部像素不被墙构件覆盖；灯具归属及数据不变 | 194 checks，0 failures |
| keys_test_runner | 952，0 failures |
| random_map_test_runner | 3,073，0 failures |
| map_test_runner | 274，0 failures |
| mobile_map_test_runner | 172，0 failures |
| walking_test_runner | 31，0 failures |
| 主工程 4.7.2 真实 viewport | 26 captures；正常动效变化、减少动效冻结、渲染不改状态通过 |
| 微信 staging / Godot 4.6.1 | 同样 194 几何检查及 26 captures 通过 |
| 42 份核心脚本/数据文件与本轮前 SHA256 | 全部一致 |
| 导出文件 SHA256、engine ZIP 与交付 ZIP CRC | 全部通过 |

日志位于 `build/verification/phase3/08-parallel/tower-redraw*`；哈希记录在 `build/verification/tower-redraw/rules-preservation.json`。新几何夹具最初的类名与 Godot 原生 Environment 冲突，已改名并通过。第一次基线遇到同期 UI 的 320 宽底部溢出，以及战斗模块尚在写入时的编译错误；保留失败日志。本轮只将旧 capture 的越界 assert 改为记录，之后重跑基线和最终捕获均无溢出记录，没有修改公共 UI。证书存储提示为环境告警，最终无脚本或资源编译错误。

## 独立微信包与预算

- 可导入目录：[build/wechat-tower-redraw](../build/wechat-tower-redraw/)。
- 交付 ZIP：[TowerRealm-WeChat.zip](../build/wechat-runs/20261004-024319-251294/TowerRealm-WeChat.zip)。
- 构建报告：[build-report.json](../build/wechat-runs/20261004-024319-251294/build-report.json)。
- 资源与校验审计：[audit.json](../build/verification/tower-redraw/package/audit.json)。
- 本地独立构建使用 `--no-latest`；没有覆盖 current/latest，没有上传、发布或提交微信审核。

预算计量总文件大小 **20,826,121 bytes（19.86 MiB）**；主包 **2,427,533 bytes**。原 20 MiB 阈值下剩 **145,399 bytes**。交付 ZIP 自身为 19,324,163 bytes。该构建包含当时其他并行工作的快照，不能把相对旧包的全部增量归因于塔内环境。

本轮新增运行纹理在 engine ZIP 中的压缩数据：materials **222,805 bytes**，stairs **51,288 bytes**，合计 **274,093 bytes（约 268 KiB）**，含各自 remap 数据，不含 ZIP 条目头。新原生 helper 脚本压缩数据 2,524 bytes。源图与提示词未进入运行包；未删除旧资源、提高阈值或修改全局画质。

**尚未做微信开发者工具或 Android/iOS 真机验收；报告中的 devtools/device 保持 false。** 源码/压缩资源桌面验证不代表手机性能承诺。当前包余量应在最终整合时继续核对。

## 复现

```powershell
./tests/tower_redraw_verify.ps1 -Capture
./tools/tower_redraw_package.ps1
./tools/tower_redraw_stage_verify.ps1 -Source './build/wechat-runs/20261004-024319-251294/source'
```

最后一条应指向对应新构建打印的隔离 source 目录；测试夹具在导出后复制，不进入 ZIP。主要改动文件：`scripts/ui/tower_masonry.gd`、`tower_environment.gd`、`grid_board.gd`；资产为 `assets/environment/tower_v03/`；新增验证与导出脚本均以 `tower_redraw_` 为前缀。
