## Isolated local export. Never promotes current or writes a latest pointer.
param(
    [ValidatePattern('^wechat-ruins-polish(?:-[a-z0-9-]+)?$')][string]$OutputFolder = 'wechat-ruins-polish',
    [ValidatePattern('^[a-z0-9-]+$')][string]$EvidenceFolder = 'package'
)
$ErrorActionPreference = 'Stop'
$project = [IO.Path]::GetFullPath((Join-Path $PSScriptRoot '..'))
$evidence = Join-Path $project "build/verification/ruins-polish/$EvidenceFolder"
New-Item -ItemType Directory -Force $evidence | Out-Null
$mutex = [Threading.Mutex]::new($false, 'MagicTa_Phase3_Parallel_Godot')
$acquired = $false
$oldAppData = $env:APPDATA
$oldLocalAppData = $env:LOCALAPPDATA
try {
    Write-Host 'Waiting for shared Godot lock: isolated ruins polish export'
    try { $acquired = $mutex.WaitOne([TimeSpan]::FromMinutes(30)) }
    catch [Threading.AbandonedMutexException] { $acquired = $true }
    if (-not $acquired) { throw 'Shared Godot lock timed out' }
    $env:APPDATA = Join-Path $evidence 'appdata'
    $env:LOCALAPPDATA = Join-Path $evidence 'localappdata'
    New-Item -ItemType Directory -Force $env:APPDATA,$env:LOCALAPPDATA | Out-Null
    & python (Join-Path $project 'tools/build_wechat.py') --appid wx57ebf150a77fedb9 --ios-mode high-performance --output-folder $OutputFolder --no-latest 2>&1 | Tee-Object -FilePath (Join-Path $evidence 'export.log')
    if ($LASTEXITCODE -ne 0) { throw 'Isolated export failed; inspect package/export.log' }
} finally {
    $env:APPDATA = $oldAppData
    $env:LOCALAPPDATA = $oldLocalAppData
    if ($acquired) { $mutex.ReleaseMutex() }
    $mutex.Dispose()
}
