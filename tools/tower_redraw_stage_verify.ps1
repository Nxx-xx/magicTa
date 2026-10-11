param([Parameter(Mandatory=$true)][string]$Source)
$ErrorActionPreference = 'Stop'
$project = [IO.Path]::GetFullPath((Join-Path $PSScriptRoot '..'))
$stage = (Resolve-Path -LiteralPath $Source).Path
if (-not $stage.StartsWith((Join-Path $project 'build/wechat-runs'), [StringComparison]::OrdinalIgnoreCase)) { throw 'Expected isolated export source' }
$evidence = Join-Path $project 'build/verification/tower-redraw/wechat'
New-Item -ItemType Directory -Force $evidence | Out-Null
$mutex = [Threading.Mutex]::new($false, 'MagicTa_Phase3_Parallel_Godot')
$acquired = $false
$oldAppData = $env:APPDATA
$oldLocalAppData = $env:LOCALAPPDATA
try {
    Write-Host 'Waiting for shared Godot lock: compressed tower resource verification'
    try { $acquired = $mutex.WaitOne([TimeSpan]::FromMinutes(30)) }
    catch [Threading.AbandonedMutexException] { $acquired = $true }
    if (-not $acquired) { throw 'Shared Godot lock timed out' }
    $env:APPDATA = Join-Path $evidence 'appdata'
    $env:LOCALAPPDATA = Join-Path $evidence 'localappdata'
    New-Item -ItemType Directory -Force $env:APPDATA,$env:LOCALAPPDATA,"$stage/tests" | Out-Null
    foreach ($name in @('tower_redraw_geometry_test','tower_redraw_capture')) {
        # Post-export test fixtures do not enter the delivered archive.
        Copy-Item -LiteralPath "$project/tests/$name.gd" -Destination "$stage/tests/$name.gd"
        $arguments = @('--path',$stage,'--rendering-method','gl_compatibility','--position','10000,10000','--script',"res://tests/$name.gd")
        if ($name -eq 'tower_redraw_capture') { $arguments += @('--','--after') }
        $log = Join-Path $evidence "$name.log"
        $process = Start-Process -FilePath "$project/build/wechat-toolchain/editor/Godot_v4.6.1-stable_win64_console.exe" -ArgumentList $arguments -WindowStyle Hidden -PassThru -RedirectStandardOutput $log -RedirectStandardError "$log.stderr"
        $null = $process.Handle
        if (-not $process.WaitForExit(120000)) { $process.Kill($true); throw "Timed out: $name" }
        $text = (Get-Content $log,"$log.stderr" -Raw) -join "`n"
        $bad = $process.ExitCode -ne 0 -or $text -match 'SCRIPT ERROR|Parse Error|Compilation failed|FAIL[: ]'
        $errors = @($text.Split("`n") | Where-Object { $_ -match '^ERROR:' -and $_ -notmatch 'Failed to read the root certificate store' })
        Get-Content $log -Tail 2
        if ($bad -or $errors.Count) { throw "Staging validation failed: $log" }
    }
    Copy-Item -LiteralPath "$stage/build/verification/tower-redraw/after" -Destination "$evidence/frames" -Recurse
} finally {
    $env:APPDATA = $oldAppData
    $env:LOCALAPPDATA = $oldLocalAppData
    if ($acquired) { $mutex.ReleaseMutex() }
    $mutex.Dispose()
}
