param([Parameter(Mandatory=$true)][string]$AppId)
$ErrorActionPreference = 'Stop'
$projectPath = [IO.Path]::GetFullPath((Join-Path $PSScriptRoot '..'))
$mutex = [Threading.Mutex]::new($false, 'MagicTa_Phase3_Parallel_Godot')
$acquired = $false
try {
    Write-Host 'Waiting for shared Godot lock: isolated enemy export'
    try { $acquired = $mutex.WaitOne([TimeSpan]::FromMinutes(30)) }
    catch [Threading.AbandonedMutexException] { $acquired = $true }
    if (-not $acquired) { throw 'Godot lock timeout' }
    $python = $(if ($env:PYTHON_BIN) { $env:PYTHON_BIN } else { 'python' })
    & $python (Join-Path $projectPath 'tools/build_wechat.py') --appid $AppId --ios-mode high-performance --output-folder wechat-enemy-polish --no-latest
    if ($LASTEXITCODE -ne 0) { throw "Enemy export failed: $LASTEXITCODE" }
} finally {
    if ($acquired) { $mutex.ReleaseMutex() }
    $mutex.Dispose()
}
