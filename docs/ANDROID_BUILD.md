# Android 手机测试包

输出位置：`build/android/TowerRealm-Android.apk`。

2026-09-30 已成功导出，大小为 80,384,617 字节（约 76.7 MiB），APK v2 / v3 签名验证通过，ZIP 完整性通过，剧情、规则、字体授权及 ARM32 / ARM64 原生库均确认包含。开发用脚本、测试和素材源图未进入安装包。

此包用于本地安装试玩，使用调试签名。包名为 `org.towerrealm.magicta`，版本为 `0.2.0-test`；同时包含 ARM64 和 ARMv7，最低 Android 7.0（API 24）。游戏采用竖屏、OpenGL Compatibility 渲染和触摸转鼠标输入，手机保留 540×960 逻辑画布缩放。手机上的存档保存在应用自己的数据目录，不会自动带入电脑存档。

## 安装

1. 将 APK 通过 USB 或文件传输发到安卓手机。
2. 在手机文件管理器中打开 APK；如系统提示，允许该文件管理器安装未知来源应用。
3. 安装后打开“塔境·公主救援记”。

已安装同包名、同签名版本时可直接覆盖升级，保留应用数据。请保留 `build/android/toolchain/debug.keystore`，后续测试包继续使用它签名。卸载应用会删除本地存档。APK 不能安装到 iPhone。

## 重新打包

本机 Godot 位于 `godot`。首次下载依赖：

```powershell
python tools/setup_android.py
```

该脚本从 Godot、Adoptium、Google 官方发布地址下载固定版本依赖，支持分段续传；所有文件都放在被 Git 忽略的 `build/android/toolchain` 中。使用官方预编译 Android APK 模板，无需 Android Studio、Gradle、NDK 或 CMake。JDK 使用官方 SHA-256 校验，SDK 使用官方仓库 SHA-1 校验，模板检查 APK 内部 ZIP 完整性。下载需能连接 GitHub 发布附件和 Google 下载服务器。

```powershell
pwsh -File tools/build_android.ps1
```

可通过 `-Godot`、`-JavaSdk`、`-AndroidSdk` 指定其他安装位置；Godot 和模板应保持 4.7.2 版本一致。脚本隔离 Godot 编辑器设置和构建时用户目录，生成测试签名并导出，再用 `apksigner verify` 验证签名。构建日志、签名结果和 APK 的 SHA-256 均保存在 `build/android/`。

## 验证范围

- 项目静态检查通过；可选的 fontTools、gdtoolkit 检查因未安装而跳过。
- 原有界面回归 118 项通过。
- 1080×1920 桌面渲染模拟手机逻辑画布，棋盘和操作区边界检查通过；截图为 `build/verification/android-layout.png`。
- 真机安装、系统返回手势、切到后台后的恢复、刘海屏安全区及不同 GPU 兼容性仍需手机验收。桌面渲染模拟不等同于 Android 真机测试。

官方导出文档：<https://docs.godotengine.org/en/4.7/tutorials/export/exporting_for_android.html>。
