# 塔内精修：微信资源预算审查

2026-10-03。审查基线为 `build/wechat-runs/20261003-033854-219559`，本记录没有启动新构建，也没有更新 current。

## 实际发现与修改

当前包 20,971,363 bytes，20 MiB 检查仅余 157 bytes。检查 `build/wechat-current/engine/godot.zip` 的实际条目发现，Godot 的 `all_resources` 导出将已经停用的历史纹理一并打包。

| 已停用集合 | PNG 数 | ZIP 中纹理压缩数据 bytes |
| --- | ---: | ---: |
| 公主 phase3/textures/v03 | 91 | 594,273 |
| 怪物 phase3/textures 根目录历史帧 | 51 | 886,566 |
| 魔像 phase3/textures/v04/golem | 47 | 658,450 |
| 遗迹三张 r1/r2/r3-atlas-draft | 3 | 671,658 |

这些集合共 192 张图。连同对应 remap 数据和 ZIP 文件头，基线中可移除约 **2,920,594 bytes**；预估总包 **18,050,769 bytes**，新增美术前余量 **2,920,751 bytes**。这是基于旧包条目的预算估计，最终新包大小以真实导出报告为准。

`tools/build_wechat.py` 现在只在隔离源码复制期间过滤上述明确审查过的集合。三个生产 manifest 中的 PNG 和脚本/场景/数据的完整直接 PNG 引用优先保留；以后重新发布到旧路径的图也不会被误删。不做全工程“无字符串引用即删除”的推断。`hero_gait.gd` 动态读取的 gait 四方向图仍保留；v05/v06、当前牛头、史莱姆、遗迹 v02、旧局静态回退、母版和工作区文件全部保留。

未提高预算阈值，未降低任何生产图的现有分辨率、压缩质量或 mipmaps 配置。

## 验证与交付门槛

- `python tests/wechat_art_budget_test.py`：4 个测试通过，覆盖重新引用旧图优先保留、直接引用优先保留、缺失生产图阻止构建、导出缺失纹理 payload 阻止构建、动态 gait 与 v05/v06 保留。
- 基线 ZIP 中 **1,161 个**生产/完整直接引用/gait 图的 remap 和实际纹理 payload 均存在。
- 每次新构建生成 `asset-exclusions.json`，构建报告也记录过滤清单；新导出会再次核对生产图的 remap 和 payload，以及退休路径不在 ZIP 中。
- 包体证据：`build/verification/tower-polish/package-audit.json`，含基线 ZIP SHA-256、各分组大小、完整排除清单、三个生产 manifest SHA-256。

完整构建和 Godot 运行回归留给塔内接入完成后的统一验证。上述检查不代表微信开发者工具、Android 或 iOS 真机通过。

## 隔离构建与替换 current

先构建独立输出，保持旧 current 和旧构建 ZIP 可回退：

```powershell
python tests/wechat_art_budget_test.py
python tools/build_wechat.py --appid wx57ebf150a77fedb9 --ios-mode high-performance --output-folder wechat-tower-polish
```

成功后先检查 `build/wechat-tower-polish-latest.json` 指向的报告、文件 SHA、ZIP CRC，并运行隔离源码回归与压缩资源画面检查。该命令只更新专用 latest 文件，不会更新全局 `wechat-latest.json`。

完成上述验证后执行以下本地替换；旧 current 移到独立回退目录，不删除旧构建：

```powershell
$buildRoot = (Resolve-Path './build').Path
$latest = Get-Content -LiteralPath "$buildRoot\wechat-tower-polish-latest.json" -Raw | ConvertFrom-Json
$candidate = (Resolve-Path -LiteralPath $latest.project).Path
$current = [IO.Path]::GetFullPath("$buildRoot\wechat-current")
$rollback = [IO.Path]::GetFullPath("$buildRoot\wechat-current-before-tower-$(Get-Date -Format yyyyMMdd-HHmmss)")
foreach ($target in @($candidate, $current, $rollback)) {
    if (-not $target.StartsWith($buildRoot + '\', [StringComparison]::OrdinalIgnoreCase)) {
        throw "Path outside build: $target"
    }
}
if ($candidate -eq $current -or (Test-Path -LiteralPath $rollback)) { throw 'Unsafe promotion paths' }
if (Test-Path -LiteralPath $current) { Move-Item -LiteralPath $current -Destination $rollback -ErrorAction Stop }
Copy-Item -LiteralPath $candidate -Destination $current -Recurse -ErrorAction Stop
$report = Get-Content -LiteralPath $latest.report -Raw | ConvertFrom-Json
foreach ($file in $report.files.PSObject.Properties) {
    $copied = Join-Path $current $file.Name
    if ((Get-FileHash -LiteralPath $copied -Algorithm SHA256 -ErrorAction Stop).Hash -ne $file.Value.sha256) {
        throw "Copied file mismatch; rollback retained at ${rollback}: $($file.Name)"
    }
}
$latest.project = $current
$record = $latest | ConvertTo-Json -Depth 10
Set-Content -LiteralPath "$buildRoot\wechat-current-latest.json" -Value $record -Encoding utf8 -ErrorAction Stop
Set-Content -LiteralPath "$buildRoot\wechat-latest.json" -Value $record -Encoding utf8 -ErrorAction Stop
```

脚本在复制完成并与构建报告逐文件 SHA 一致后才切换 latest；失败时旧目录仍保留在 rollback。此步骤只交付本地可导入目录；不上传微信、不提交审核。
