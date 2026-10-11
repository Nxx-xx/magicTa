$ErrorActionPreference = 'Stop'
$projectPath = [IO.Path]::GetFullPath((Join-Path $PSScriptRoot '..'))
$mutex = [Threading.Mutex]::new($false, 'MagicTa_Phase3_Parallel_Godot')
$acquired = $false
try {
    Write-Host 'Waiting for MagicTa Godot lock: isolated wechat-battle-polish build'
    try { $acquired = $mutex.WaitOne([TimeSpan]::FromMinutes(30)) }
    catch [Threading.AbandonedMutexException] { $acquired = $true }
    if (-not $acquired) { throw 'Shared Godot lock timeout' }
    # The builder creates a fresh staged source tree and its own isolated profile.
    & python (Join-Path $PSScriptRoot 'build_wechat.py') --appid wx57ebf150a77fedb9 --output-folder wechat-battle-polish
    if ($LASTEXITCODE -ne 0) { throw 'Isolated battle package export failed' }
} finally {
    if ($acquired) { $mutex.ReleaseMutex() }
    $mutex.Dispose()
}
