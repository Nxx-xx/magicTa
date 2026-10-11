param([switch]$Capture, [string[]]$Only = @(), [string]$GodotPath = $(if ($env:GODOT_BIN) { $env:GODOT_BIN } else { 'godot' }))
$ErrorActionPreference = 'Stop'
$projectPath = [IO.Path]::GetFullPath((Join-Path $PSScriptRoot '..'))
$evidencePath = Join-Path $projectPath 'build/verification/exploration-view'
$oldAppData = $env:APPDATA
$oldLocalAppData = $env:LOCALAPPDATA
try {
    foreach ($entry in @(@('exploration_view_test_runner','exploration-view'), @('mobile_map_test_runner','mobile-map'), @('walking_test_runner','walking'), @('camp_map_test_runner','camp-map'), @('phase3_ui_host_test_runner','phase3/00-integration'))) {
        $name = $entry[0]
        if ($Only.Count -and $name -notin $Only) { continue }
        $profilePath = Join-Path $projectPath "build/verification/$($entry[1])/exploration-follow"
        $env:APPDATA = "$profilePath/appdata"
        $env:LOCALAPPDATA = "$profilePath/localappdata"
        New-Item -ItemType Directory -Force -Path $env:APPDATA,$env:LOCALAPPDATA,$evidencePath | Out-Null
        $arguments = @('--headless','--path',$projectPath,'--script',"res://tests/$name.gd")
        if ($Capture) { $arguments = @('--path',$projectPath,'--rendering-method','gl_compatibility','--position','10000,10000','--script',"res://tests/$name.gd",'--','--capture') }
        $logPath = Join-Path $evidencePath "$name$(if ($Capture) {'-render'} else {'-headless'}).log"
        $errorPath = "$logPath.stderr"
        $process = Start-Process -FilePath $GodotPath -ArgumentList $arguments -WindowStyle Hidden -PassThru -RedirectStandardOutput $logPath -RedirectStandardError $errorPath
        $null = $process.Handle
        if (-not $process.WaitForExit(60000)) { $process.Kill(); throw "Timed out: $name" }
        Get-Content -LiteralPath $logPath -Tail 1
        if ($process.ExitCode -ne 0 -or (Select-String -LiteralPath $logPath,$errorPath -Pattern 'SCRIPT ERROR|Parse Error|Compilation failed|FAIL[: ]' -Quiet)) { throw "Verification failed: $name" }
    }
} finally {
    $env:APPDATA = $oldAppData
    $env:LOCALAPPDATA = $oldLocalAppData
}
