$ErrorActionPreference = 'Stop'
$project = Split-Path -Parent $PSScriptRoot
$evidence = Join-Path $project 'build/verification/phase3/04-progress'
New-Item -ItemType Directory -Force -Path $evidence | Out-Null
$previousApp = $env:APPDATA
$previousLocal = $env:LOCALAPPDATA
try {
    $env:APPDATA = Join-Path $evidence 'appdata'
    $env:LOCALAPPDATA = Join-Path $evidence 'localappdata'
    New-Item -ItemType Directory -Force -Path $env:APPDATA, $env:LOCALAPPDATA | Out-Null
    $godot = $(if ($env:GODOT_BIN) { $env:GODOT_BIN } else { 'godot' })
    $ErrorActionPreference = 'Continue'
    $suites = @('phase3_progress_save_test', 'campaign_integration_edge_runner', 'keys_test_runner', 'map_test_runner')
    foreach ($suite in $suites) {
        $log = Join-Path $evidence ($suite + '.log')
        & $godot --headless --path $project --quit-after 20000 --script ('res://tests/' + $suite + '.gd') 2>&1 | Tee-Object $log
        if ($LASTEXITCODE -ne 0) { throw ($suite + ' failed') }
        if (Select-String -Path $log -Pattern 'SCRIPT ERROR|Parse Error|Compile Error|FAIL ' -Quiet) { throw ($suite + ' logged a script failure') }
        if (-not (Select-String -Path $log -Pattern 'failures=0|0 failures' -Quiet)) { throw ($suite + ' did not finish') }
    }
} finally {
    $env:APPDATA = $previousApp
    $env:LOCALAPPDATA = $previousLocal
}
