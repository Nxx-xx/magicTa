$ErrorActionPreference = 'Stop'
$rootPath = [IO.Path]::GetFullPath((Join-Path $PSScriptRoot '..'))
$evidencePath = Join-Path $rootPath 'build/verification/item-icons-v02'
$mutex = [Threading.Mutex]::new($false, 'MagicTa_Phase3_Parallel_Godot')
$acquired = $false
$savedAppData = $env:APPDATA
$savedLocalData = $env:LOCALAPPDATA
try {
    Write-Host 'Waiting for shared Godot lock: item icon WeChat build'
    try { $acquired = $mutex.WaitOne([TimeSpan]::FromMinutes(30)) }
    catch [Threading.AbandonedMutexException] { $acquired = $true }
    if (-not $acquired) { throw 'Godot lock timeout' }
    $env:APPDATA = Join-Path $evidencePath 'wechat-appdata'
    $env:LOCALAPPDATA = Join-Path $evidencePath 'wechat-localappdata'
    New-Item -ItemType Directory -Force $env:APPDATA,$env:LOCALAPPDATA | Out-Null
    $started = Get-Date
    & python (Join-Path $rootPath 'tools/build_wechat.py') --appid wx57ebf150a77fedb9 --output-folder wechat-item-icons --no-latest *> (Join-Path $evidencePath 'wechat-build.log')
    $buildExit = $LASTEXITCODE
    $reports = Get-ChildItem (Join-Path $rootPath 'build/wechat-runs') -Directory | Where-Object { $_.CreationTime -ge $started.AddSeconds(-1) } | ForEach-Object { Join-Path $_.FullName 'build-report.json' } | Where-Object { Test-Path $_ }
    [ordered]@{exit_code=$buildExit;reports=@($reports);output='build/wechat-item-icons';latest_modified=$false} | ConvertTo-Json -Depth 3 | Set-Content (Join-Path $evidencePath 'wechat-result.json')
    Get-Content (Join-Path $evidencePath 'wechat-build.log') -Tail 8
    if ($buildExit -ne 0) { throw "Item icon build failed: $buildExit" }
} finally {
    $env:APPDATA = $savedAppData
    $env:LOCALAPPDATA = $savedLocalData
    if ($acquired) { $mutex.ReleaseMutex() }
    $mutex.Dispose()
}
