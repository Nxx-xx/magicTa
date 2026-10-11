$ErrorActionPreference = 'Stop'
$rootPath = [IO.Path]::GetFullPath((Join-Path $PSScriptRoot '..'))
$evidencePath = Join-Path $rootPath 'build/verification/ruins-polish'
$mutex = [Threading.Mutex]::new($false,'MagicTa_Phase3_Parallel_Godot')
$acquired = $false
$savedAppData = $env:APPDATA
$savedLocalData = $env:LOCALAPPDATA
try {
    try { $acquired = $mutex.WaitOne([TimeSpan]::FromMinutes(30)) }
    catch [Threading.AbandonedMutexException] { $acquired = $true }
    if (-not $acquired) { throw 'Godot lock timeout' }
    $env:APPDATA = Join-Path $evidencePath 'packed-appdata'
    $env:LOCALAPPDATA = Join-Path $evidencePath 'packed-localappdata'
    New-Item -ItemType Directory -Force $env:APPDATA,$env:LOCALAPPDATA | Out-Null
    & (Join-Path $rootPath 'build/wechat-toolchain/editor/Godot_v4.6.1-stable_win64_console.exe') --headless --path (Join-Path $evidencePath 'packed-runtime') --script res://verify.gd *> (Join-Path $evidencePath 'packed-runtime.log')
    $code = $LASTEXITCODE
    $logText = Get-Content (Join-Path $evidencePath 'packed-runtime.log') -Raw
    Write-Host $logText
    if ($code -ne 0 -or $logText -notmatch 'PACKED_RUINS 75 frames') { throw 'Packed ruin load failed' }
} finally {
    $env:APPDATA = $savedAppData
    $env:LOCALAPPDATA = $savedLocalData
    if ($acquired) { $mutex.ReleaseMutex() }
    $mutex.Dispose()
}
