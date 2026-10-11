param([switch]$Capture)
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
    & $godot --headless --path $project --script res://tests/phase3_progress_assets.gd 2>&1 | Tee-Object (Join-Path $evidence 'assets.log')
    if ($LASTEXITCODE -ne 0) { throw 'Asset build failed' }
    & $godot --headless --path $project --quit-after 600 --script res://tests/phase3_progress_test_runner.gd 2>&1 | Tee-Object (Join-Path $evidence 'logic.log')
    if ($LASTEXITCODE -ne 0) { throw 'Progression tests failed' }
    if (-not (Select-String -Path (Join-Path $evidence 'logic.log') -Pattern 'PHASE3_PROGRESS_TEST checks=\d+ failures=0' -Quiet)) { throw 'Progression tests did not finish successfully' }
    if (Select-String -Path (Join-Path $evidence 'logic.log') -Pattern 'SCRIPT ERROR|Parse Error|Compile Error|FAIL ' -Quiet) { throw 'Progression tests logged a script failure' }
    if ($Capture) {
        & $godot --path $project --quit-after 600 --script res://tests/phase3_progress_preview.gd -- --capture 2>&1 | Tee-Object (Join-Path $evidence 'preview.log')
        if ($LASTEXITCODE -ne 0) { throw 'Progression preview failed' }
        if (-not (Select-String -Path (Join-Path $evidence 'preview.log') -Pattern 'PHASE3_PROGRESS_PREVIEW captures=5 failures=0' -Quiet)) { throw 'Progression preview did not finish successfully' }
        if (Select-String -Path (Join-Path $evidence 'preview.log') -Pattern 'SCRIPT ERROR|Parse Error|Compile Error' -Quiet) { throw 'Progression preview logged a script failure' }
    }
} finally {
    $env:APPDATA = $previousApp
    $env:LOCALAPPDATA = $previousLocal
}
