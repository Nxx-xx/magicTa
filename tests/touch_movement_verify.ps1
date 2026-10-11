param([switch]$Capture)
$ErrorActionPreference = 'Stop'
$projectPath = [IO.Path]::GetFullPath((Join-Path $PSScriptRoot '..'))
$evidencePath = Join-Path $projectPath 'build/verification/touch-movement'
$godotPath = $(if ($env:GODOT_BIN) { $env:GODOT_BIN } else { 'godot' })
$oldAppData = $env:APPDATA
$oldLocalAppData = $env:LOCALAPPDATA
$failures = @()
try {
    foreach ($entry in @(@('mobile_map_test_runner','mobile-map'), @('walking_test_runner','walking'), @('touch_scroll_test_runner','touch-scroll'))) {
        $name = $entry[0]
        $profilePath = Join-Path $projectPath "build/verification/$($entry[1])/touch-delivery"
        $env:APPDATA = "$profilePath/appdata"
        $env:LOCALAPPDATA = "$profilePath/localappdata"
        New-Item -ItemType Directory -Force -Path $env:APPDATA,$env:LOCALAPPDATA,$evidencePath | Out-Null
        $arguments = @('--headless','--path',$projectPath,'--script',"res://tests/$name.gd")
        if ($Capture) { $arguments = @('--path',$projectPath,'--rendering-method','gl_compatibility','--script',"res://tests/$name.gd",'--','--capture') }
        $logPath = Join-Path $evidencePath "$name$(if ($Capture) {'-render'} else {'-headless'}).log"
        $errorPath = "$logPath.stderr"
        $process = Start-Process -FilePath $godotPath -ArgumentList $arguments -WindowStyle Hidden -PassThru -RedirectStandardOutput $logPath -RedirectStandardError $errorPath
        $null = $process.Handle
        if (-not $process.WaitForExit(120000)) { $process.Kill(); throw "Timed out: $name" }
        if ($process.ExitCode -ne 0 -or (Select-String -LiteralPath $logPath,$errorPath -Pattern 'SCRIPT ERROR|Parse Error|Compilation failed|FAIL:' -Quiet)) { $failures += $name }
        Get-Content -LiteralPath $logPath -Tail 1
    }
} finally {
    $env:APPDATA = $oldAppData
    $env:LOCALAPPDATA = $oldLocalAppData
}
if ($failures.Count -gt 0) { throw ('Touch verification failed: ' + ($failures -join ', ')) }
