# 独立道具图标交付

> 当前版本已于 2026-10-04 更新为绘画版 v02：28 件物品全部重绘，新增 3 类遗迹交互，正式 PNG 路径保留。最新交付、截图、独立微信包及验证见 [ITEM_ICONS_V02_DELIVERY.md](ITEM_ICONS_V02_DELIVERY.md)。下文为 v01 历史记录，其 PNG 哈希、包与“保留第三阶段”描述不再代表当前美术。

本次覆盖全部 28 件道具：12 件装备、16 件遗物。实际数据名称为“猎人长弓”。检索 data 下实际定义后，道具来源仅为 content.json（22）及 phase3_items.json（6）；商店、奖励、事件和解锁配置引用这些 ID。

## 美术与生成依据

22 张新增图标以现有第三阶段 SVG 美术为依据，使用同一深青灰描边、金属高光、金色点缀、透明背景和约 12% 安全留白。四把剑分别采用直剑、弯刃、倒钩刃、仪式阔刃；三件护甲分别为简胸甲、肩甲板甲、尖角层叠黑曜甲；弓、盾、手套、戒指、吊坠与遗物各有独立轮廓。无文字烘焙。保留 6 张已有高质量第三阶段图标及其原始文件哈希。

遵循 imagegen 技能中扩展现有 SVG 图标体系的原生编辑路径；本次没有调用图像模型或 API。可编辑源为 256×256 SVG，经 Godot SVG 光栅器输出 128×128 透明 PNG。tools/build_item_icon_sources.py 保存全部造型依据与可复现几何；tools/bake_item_icons.gd 导出图标并记录源文件/PNG 哈希；tools/preview_item_icons.py 生成 96/48/32 像素对照预览。没有调整数值、ID、规则或存档语义。

## 接入

scripts/ui/item_icon_registry.gd 是仅用于展示的 28 项 ID→路径注册表；独立于运行/存档中的旧道具字典，因此旧旅程也直接获得新版图标。

scripts/ui/item_icon.gd 统一查表并等比绘制，runtime_art.gd 取消只接受 phase3 目录的限制。未知或缺失资源才用通用回退。paged_catalog.gd 原有背包/图鉴入口以及 action_choices.gd 的商店/奖励入口沿用统一 ItemIcon；详情标题新增 48px 同源图标。一屏概览、点击只看详情、显式确认才购买/领取的交互保留。缩减详情说明区最低高度，仍使用完整分页，以确保 320×600 商店固定返回按钮可见。

## 对照映射

| ID | 名称 | PNG 路径 | 来源 |
| --- | --- | --- | --- |
| `iron_sword` | 铁剑 | `res://assets/items/unique/icons/iron_sword.png` | 新增独立造型 |
| `iron_armor` | 铁甲 | `res://assets/items/unique/icons/iron_armor.png` | 新增独立造型 |
| `hunter_bow` | 猎人长弓 | `res://assets/items/unique/icons/hunter_bow.png` | 新增独立造型 |
| `tower_shield` | 塔盾 | `res://assets/items/unique/icons/tower_shield.png` | 新增独立造型 |
| `heart_pendant` | 生命吊坠 | `res://assets/items/unique/icons/heart_pendant.png` | 新增独立造型 |
| `duelist_gloves` | 决斗手套 | `res://assets/items/unique/icons/duelist_gloves.png` | 新增独立造型 |
| `steel_blade` | 淬钢刃 | `res://assets/items/unique/icons/steel_blade.png` | 新增独立造型 |
| `knight_plate` | 骑士板甲 | `res://assets/items/unique/icons/knight_plate.png` | 新增独立造型 |
| `vital_crown` | 翠玉冠 | `res://assets/items/unique/icons/vital_crown.png` | 新增独立造型 |
| `dawn_spear` | 破晓长枪 | `res://assets/items/unique/icons/dawn_spear.png` | 新增独立造型 |
| `obsidian_mail` | 黑曜战甲 | `res://assets/items/unique/icons/obsidian_mail.png` | 新增独立造型 |
| `sovereign_ring` | 王权指环 | `res://assets/items/unique/icons/sovereign_ring.png` | 新增独立造型 |
| `blood_sword` | 嗜血剑 | `res://assets/items/unique/icons/blood_sword.png` | 新增独立造型 |
| `gold_sword` | 黄金剑 | `res://assets/items/unique/icons/gold_sword.png` | 新增独立造型 |
| `wolf_fang` | 狼牙 | `res://assets/items/unique/icons/wolf_fang.png` | 新增独立造型 |
| `stone_heart` | 岩心 | `res://assets/items/unique/icons/stone_heart.png` | 新增独立造型 |
| `spring_seed` | 泉种 | `res://assets/items/unique/icons/spring_seed.png` | 新增独立造型 |
| `lucky_coin` | 幸运古币 | `res://assets/items/unique/icons/lucky_coin.png` | 新增独立造型 |
| `crimson_chalice` | 绯红圣杯 | `res://assets/items/unique/icons/crimson_chalice.png` | 新增独立造型 |
| `merchant_seal` | 商王印记 | `res://assets/items/unique/icons/merchant_seal.png` | 新增独立造型 |
| `sun_emblem` | 日轮徽记 | `res://assets/items/unique/icons/sun_emblem.png` | 新增独立造型 |
| `guardian_oath` | 守护誓约 | `res://assets/items/unique/icons/guardian_oath.png` | 新增独立造型 |
| `p3_dawn_sigil` | 破晓剑印 | `res://assets/items/phase3/icons/p3_dawn_sigil.png` | 保留第三阶段 |
| `p3_lantern_aegis` | 提灯护符 | `res://assets/items/phase3/icons/p3_lantern_aegis.png` | 保留第三阶段 |
| `p3_bounty_ledger` | 赏金账簿 | `res://assets/items/phase3/icons/p3_bounty_ledger.png` | 保留第三阶段 |
| `p3_rhythm_blade` | 三拍剑穗 | `res://assets/items/phase3/icons/p3_rhythm_blade.png` | 保留第三阶段 |
| `p3_thorn_clasp` | 荆棘扣 | `res://assets/items/phase3/icons/p3_thorn_clasp.png` | 保留第三阶段 |
| `p3_gilded_lantern` | 鎏金灯芯 | `res://assets/items/phase3/icons/p3_gilded_lantern.png` | 保留第三阶段 |

## 验证证据

- `build/verification/item-icons/all-items.png`：全套带名称/ID 的 96/48/32px 对照图。
- `asset-audit.json`：28 张 RGBA/透明度、唯一像素与唯一透明轮廓、资源哈希通过。
- `ui.log`：320×600、360×640，背包/图鉴逐件实际输入点击，详情对应、说明分页无损、查看不改变状态；商店与奖励图标同源。2,492 项零失败。
- `compact_screens_test_runner.log`：一屏界面 1,948 项零失败。
- `action_choices_test_runner.log`：选项/商店/奖励操作 1,205 项零失败。
- `static.log`：项目静态检查通过；可选 fontTools/gdtoolkit 跳过状态见日志。
- `inventory_320_0_0.png`、`hunter_bow_detail_320.png`、`choice_320.png` 等：实际 Godot 小屏截图。

微信构建保持当前包已有 AppID 与 high-performance-plus 模式。新增图标在隔离构建副本中限制为 96px（48px 显示的两倍），源码 PNG 保持 128px，其余图像导入策略不变。首次 128px 入包超出 20MiB 限额约 8KiB，因此只针对新资源做此构建优化。tools/verify_item_icon_package.py 检查归档内全部 .import→纹理路径、构建源码哈希，并生成无项目美术旁路的独立 ZIP 加载验证工程。

本轮为本地包更新，未上传或发布；Godot 小屏自动输入与包内加载检查不代表微信真机验收。Godot 测试日志含环境已有的根证书存储读取告警，不影响本地图标加载。

最终微信构建：`20261002-190752-079375/high-performance-plus`；总大小 20,962,837 bytes（19.99 MiB），主包 1,267,936 bytes。`build/wechat-current-latest.json` 指向本次报告和 ZIP。`package-audit.json` 记录 28 项图标入包路径与 42 个文件哈希校验；`packed-runtime.log` 为 Godot 4.6.1 实际从导出 ZIP 载入的 28 项零失败结果；`packed-small-icons.png` 为从包内纹理生成的 48/32px 对照图。
已同步 build/wechat-latest.json 与 build/wechat-current-latest.json，均指向本次本地包。
