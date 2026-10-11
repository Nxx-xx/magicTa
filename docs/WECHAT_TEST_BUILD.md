# 微信小游戏第一阶段

交付目标：微信开发者工具可以直接导入的完整小游戏目录。当前 AppID 使用用户提供的 `wx57ebf150a77fedb9`，不使用 AppSecret。

## 2026-10-04 恢复旧预算下压缩的画质

- 遗迹 78 张纹理恢复无损 256×256；营地 v3 恢复无损 1254×1254 并保留 mipmaps；22 张基础独特物品图标恢复无损 128×128。源素材、遗迹读取器与 15 条时间线／75 帧位均未修改。
- 独立微信导入目录：`build/wechat-ruins-polish-quality-restored`；构建：`build/wechat-runs/20261004-142402-916571`，Godot 4.6.1、high-performance。总包 **23,884,912 bytes（22.78 MiB）**，主包 **2,427,533 bytes（2.32 MiB）**，总包剩余 **7,572,368 bytes（7.22 MiB）**。
- 5 项现有资源回归通过；全部导出文件哈希与两层 ZIP CRC 通过；101 张目标纹理的源素材哈希、导入参数、包内载荷与暂存导入载荷一致。Godot 4.6.1 仅加载导出包的 remap／ctex，核实全部目标尺寸、mipmaps，以及遗迹全部 75 帧合成与 6 MiB 缓存限制；已查看包内营地预览与熔炉结算联系图。
- 证据：[包体与资源审计](../build/verification/wechat-quality-restored/audit.json)、[包内运行日志](../build/verification/wechat-quality-restored/packed-runtime.log)。运行日志有环境已知的系统证书读取错误，资源验证通过。本次使用 `--no-latest`，没有替换 current/latest，没有上传或真机验收。后续正常构建会自动使用恢复后的导入规则。

## 2026-10-03 功能码手机系统键盘

- 功能码输入使用 `scripts/ui/mobile_code_input.gd`：原生端沿用 Godot 系统键盘，微信端通过 `tools/wechat/native_keyboard.js` 调用 `wx.showKeyboard`。输入同步、点击键盘完成启用、收起保留文字、关闭面板清理监听、切后台收起与调用失败重试均已接入。
- 键盘显示时输入框置于面板顶部，面板避让键盘；支持高度事件的平台使用实际高度，旧基础库没有高度事件时预留屏幕下半部分。功能码仍为单行、最长 32 字符。
- 已重新生成 `build/wechat-current`，构建记录 `build/wechat-runs/20261003-224626-349552/`，总包约 19.49 MiB，沿用 high-performance iOS 配置。构建脚本自动注入键盘桥接，清单包含 `native-keyboard-v1`。
- 验证：Godot 4.7.2 实际渲染 71 项通过；微信所用 4.6.1 隔离源码测试 68 项通过；键盘桥接 Node 测试和现有存档、音频、加载、启动、触摸适配测试通过；44 个导出文件哈希、脚本入包及 JavaScript 语法检查通过。截图：`build/verification/function-code/code-system-keyboard-layout.png`，该截图模拟键盘占用空间，并非手机键盘截图。
- 本次完成本地构建，没有上传新开发版本。安卓 / iOS 微信真机弹键盘、粘贴和系统完成按钮仍待验证。

## 构建与导入

```powershell
python -m pip install --target build/wechat-toolchain/python fonttools==4.66.1
python tools/build_wechat.py --appid wx57ebf150a77fedb9
```

成功后导入 `./build/wechat`，类型选「小游戏」。目录包含 `project.config.json`、`game.json`、`game.js`、引擎及游戏资源；不需要导入 Godot 项目，也不需要另行复制源代码。

`build/wechat-latest.json` 指向本次构建报告、ZIP 和隔离源码。每次构建保留独立日志；再次构建会更新同一个微信导入目录，原 Windows / Android 导出设置和素材不变。产物位于 Git 忽略的 build 下，需在新机器重新构建或复制 ZIP。

## 版本和适配

- 微信构建固定 Godot **4.6.1.stable / 14d19694** 与 **AnranS/godot_for_minigame v0.2.1** 的同版本模板。现有主工程继续用 Godot 4.7.2。
- 脚本下载官方编辑器和插件发布包并校验固定 SHA-256，在 `build/wechat-runs/<时间>/source` 重新导入项目。没有将 4.7 的缓存、PCK 与 4.6 的运行时混用。
- 字体按全部脚本、场景、资源文本和解码后的 JSON 生成子集，保留 ASCII，检查中文覆盖，修改字体名称并保留 OFL。新增剧情后需要重建。
- 构建副本的一般 PNG 导入采用有损纹理压缩、最长边最多 1024；透明度和比例保留。2026-10-04 起，遗迹运行纹理（`assets/environment/ruins/phase3/textures`）、营地 v3 底图和基础独特物品图标（`assets/items/unique/icons`）保留源工程无损导入及原始尺寸：遗迹 256px、营地 1254px（保留 mipmaps）、图标 128px。取消营地质量 0.69 和图标 96px 的旧预算特例；动画时序、共享底图与源素材不变。目录由 `SOURCE_QUALITY_TEXTURE_ROOTS` 统一定义，新构建报告记录 `source_quality_texture_roots`。
- 引擎与资源放入 `engine` 分包。自 2026-10-04 起，本地构建总包预算从 20 MiB 提高为 **30 MiB（31,457,280 bytes）**，主包仍为 **4 MiB（4,194,304 bytes）**；超限会报错。阈值统一定义在 `tools/build_wechat.py`，包体验证脚本复用同一配置，新构建报告通过 `package_budget` 记录阈值。统计口径为导出目录的文件字节总和，不是最终交付 ZIP 的大小。
- 调整参考 [Cocos 微信小游戏分包文档](https://docs.cocos.com/creator/3.8/manual/zh/editor/publish/subpackage.html)列出的总量 30M、主包 4M；2026-10-04 未能直接读取微信官方规则页，也未核实当前 AppID 后台额度。本地使用 MiB 计量，这不是对平台单位口径或账号实际配额的承诺，实际上传仍以微信开发者工具和平台校验为准。历史交付记录中的 20 MiB 与剩余空间保留当时口径；本次仅调整预算，不重新导出或改动历史构建。
- 原模板的 IndexedDB stub 不能作为可靠存档。项目补丁在 Godot main 运行前恢复 `/userfs`，将文件写到微信私有目录 `/towerrealm-v1/userfs`。游戏存档和偏好设置提交时同步落盘；切后台及定时同步作为补充。写入失败返回游戏现有保存失败流程。
- `tools/wechat/persistence.js` 只管理本游戏专有目录；没有登录、支付、广告或后端依赖。
- 顶部避让微信胶囊按钮与刘海，底部避让系统手势区域。原模板加载画面的 DPR 与 GL 视口比例也已修正。
- 安卓真机首轮反馈无声，现改为微信 `InnerAudioContext` 播放预生成的原有音效和三段语音 WAV。保留静音、语音开关和音量设置，切后台停止当前短音，后续操作可再次播放。
- 触摸拖动修复：在 Web 适配窗口声明 `ontouchstart`，提供真实的 pointer movementX/Y；构建副本关闭 `emulate_touch_from_mouse`。当前源码在 GUI 分发前统一处理所有滚动容器，超过 10 像素后滚动内容并取消按钮按下状态，支持嵌套面板；微信入口仅负责安全区。桥接的原生触摸取消先于 pointercancel，避免取消手势被当作地图点击。2026-10-02 点击移动新版使用独立 `build/wechat-touch`，详情见 [操作修复交付](TOUCH_MOVEMENT_DELIVERY.md)。

## 验证范围

自动化检查：

```powershell
node tests/wechat_persistence.test.cjs
node tests/wechat_audio.test.cjs
node tests/wechat_pointer.test.cjs
```

覆盖启动前恢复、中文与二进制往返、存储配额失败、失败后旧存档可读、重试与切后台同步。模拟文件系统检查不能替代真实微信验证。

平台验收必须分别记录：

1. 开发者工具导入、编译和游戏首屏显示。
2. 新旅程、移动、遇敌、战斗、上下楼和设置。
3. 刷新模拟器后继续旅程，检查位置、生命、钥匙等不回退。
4. 安卓 / iOS 微信真机的触控、音效、切后台和重进续玩。

不能把“导出成功”或“触发刷新成功”记为模拟器或真机通过。正式发布不在本阶段范围。

## 第三方来源

- 插件：[v0.2.1 发布包](https://github.com/AnranS/godot_for_minigame/releases/tag/v0.2.1)，MIT。
- 编辑器：[Godot 4.6.1](https://github.com/godotengine/godot-builds/releases/tag/4.6.1-stable)。
- 交付目录的 `licenses/` 随附插件、Godot 及字体许可。

## 2026-09-30 验证记录

- 首轮验收构建（原 AppID `wx58b4fdccc27b706e`）：`build/wechat-runs/20260930-201502-263535`，主包文件约 1.20 MiB，总文件约 11.20 MiB；ZIP 与构建哈希记录在该目录。平台上传统计与本地文件统计口径可能不同。当前 AppID 的构建路径以 `build/wechat-latest.json` 为准。
- 项目静态检查、微信存档 / 原生音频 / 指针适配三组 Node 检查通过。字体子集构建检查通过；根目录静态检查中的可选 fontTools / GDScript grammar 检查跳过。
- Godot 4.6.1 隔离副本验证：十层核心 19,117 项、剧情 71 项、手机地图 140 项、战斗展示 88 项通过，日志在 `build/verification/wechat/compat-*.log`。
- 营地输入回归：拖动后滚动值 123，未触发新旅程；微信模拟器拖动截图见 `build/verification/wechat/camp-scroll-final.png`。
- 微信开发者工具已导入并运行；已操作进入地图、移动、遇敌及战斗。微信私有目录中读取到战斗后存档（生命 94，金币 18），重启后显示继续旅程。
- 用户第一轮安卓扫码可启动并进入游戏，反馈无声及营地拖动问题。修复包已于 20:20 成功上传预览，新二维码为 `build/verification/wechat/preview-fixed-qr.jpg`。
- 用户扫描修复包后确认：**安卓营地屏幕拖动和声音均正常。** 安卓后台恢复与退出重进仍未取得真机确认，iOS 未验收。导出检查报告中的 devtools/device 初始值不代替本节的平台验证记录。正式发布未执行。

后续按用户要求将 AppID 更换为 `wx57ebf150a77fedb9` 并重新构建。以上二维码和安卓验收属于原 AppID；新 AppID 需要重新预览或上传，原二维码不会自动切换账号。

## 2026-10-01 iOS 闪退排查

用户反馈：iPhone 16 / iOS 26.5.2 闪退；iPhone 18 / iOS 27 正常。微信版本、具体退出阶段与真机日志尚未取得，不能据此判定系统版本或内存为根因。

对照构建仅关闭 `iOSHighPerformance+`，保留 `iOSHighPerformance`，生成到独立目录：

```powershell
python tools/build_wechat.py --appid wx57ebf150a77fedb9 --ios-mode high-performance --output-folder wechat-ios-compat
```

导入 `build/wechat-ios-compat`，重新生成预览二维码后在两台手机测试。默认 `build/wechat` 与其已有二维码不随此构建更新。关闭高性能+是排查变量，不代表已修复或验证运行模式已生效。

新构建在 `towerrealm.startup-diagnostics.v1` 微信本地存储键记录设备、微信/基础库版本、构建标识和最后 16 个启动事件；不上传，也不改游戏存档。入口、WebGL、图片、引擎分包、WASM 实例化、引擎启动及运行阶段均有记录。重进时控制台 `[TowerStartup] previous run` 输出上一次启动记录，`GameGlobal.__towerStartup.previous` 可在调试器读取。系统原生闪退无法由 JavaScript 捕获，记录仅帮助缩小退出区间，不能证明内存不足；正常关闭也会留下记录。调试包启动日志可用 `node tests/wechat_startup.test.cjs` 检查。

对照包构建：`build/wechat-runs/20261001-172037-580214/TowerRealm-WeChat.zip`，约 11.20 MiB。启动记录、存档、原生音频、对照包指针测试与 JavaScript 语法检查通过；构建清单文件与哈希已检查。未取得 iPhone 16 真机结果。预览二维码生成被自动审批拒绝，理由是预览会上传构建包至微信且需要写入开发者工具状态目录，当前会话尚未取得该上传授权；没有生成新二维码。

## 2026-10-02 最新开发版本上传

用户要求上传最新版本。已使用登录中的微信开发者工具 CLI 将 **0.3.0** 上传到 AppID `wx57ebf150a77fedb9`，退出码 0 且返回 `√ upload`。本次完成的是开发版本上传。

- 最新导入目录：`build/wechat-release`。`build/wechat-latest.json` 与 `build/wechat-release-latest.json` 均指向本批源码、报告和 ZIP；旧 `build/wechat` 目录保留，直接打开旧目录仍是旧包。
- 构建记录：`build/wechat-runs/20261002-024712-742029/`，构建标识 `20261002-024712-742029/high-performance`。
- 包含第三阶段玩法、遗迹布局、全部规定敌人动画、公主 v06 分层精修及魔像 v06 五档持续石甲。导出 ZIP 的三份生产动画/遗迹清单与当前源码完全一致，含 556 个 v06 与 386 个 v05 资源条目。
- 平台上传统计：总包 19,662,212 bytes，主包 1,142,613 bytes，engine 分包 18,519,586 bytes；本地未上传文件统计为 18.87 MiB，两者统计口径不同。
- Godot 4.6.1 隔离导入与导出成功；新包在微信模拟器显示挑战/起点、图鉴等第三阶段入口。四组微信 Node 适配检查通过，42 项构建文件 SHA 核对通过。修正静态检查器对 tools 下负路径测试夹具的误报后，全项目静态检查通过；可选字形和 grammar 检查仍为 SKIP。
- 沿用 iOS 对照配置：`iOSHighPerformance=true`、`iOSHighPerformance+=false`；本次没有新增真机验证，不据此宣称 iOS 闪退已修复。
- 上传证据：`build/verification/wechat/phase3-release/upload.log`、`upload-result.json`；资源证据：`integrity.json`。

提交审核、正式上线与目标设备验收未在本次上传中执行。

## 2026-10-02 17:18 当前源码重建与本地导入

- 当前导入目录为 `./build/wechat-current`；`build/wechat-latest.json` 和 `build/wechat-current-latest.json` 指向本次构建。构建记录：`build/wechat-runs/20261002-171840-279145/`，总包约 19.59 MiB，沿用 `high-performance` iOS 配置。
- 包含林地营地 v2、老骑士模型帧及对话、新开场塔外背景与剧情文本、点击移动和公共拖动修复。关键素材与脚本同构建副本逐项一致，42 个导出文件哈希通过核对。
- 修复源码中缺失的 `_enemy_sheet()`，补回 `StoryIntroStage` 在主界面的创建、激活与布局连接。Godot 4.6.1 导入和导出通过，营地 478 项、开场剧情界面 72 项检查零失败；四组微信 Node 适配检查通过。测试存档使用隔离目录。
- 开发者工具 CLI 返回 `√ open`；实际窗口确认为 `wechat-current`，模拟器启动成功。已查看新版林地营地，并通过点击老骑士、自动行走到达、打开新立绘对话验证交互。截图保存在 `build/verification/wechat/current-import/`。
- 模拟器已有进行中的旅程，未覆盖或重开该存档；开场背景本轮通过入包与自动界面检查，尚未在微信模拟器新旅程中逐句验收。切换设置返回主菜单时控制台出现 `can_process: !is_inside_tree()` 日志，随后营地和对话可继续操作，未据此标记全流程无错误。
- 本次仅重新构建并本地导入；未上传新开发版本、提交审核或正式发布。上方 0.3.0 上传记录仍属于此前的 `wechat-release` 包，真机验收待完成。
