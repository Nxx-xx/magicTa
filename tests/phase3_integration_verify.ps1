param([switch]$Batch, [switch]$Three, [switch]$Legacy)
$ErrorActionPreference = 'Stop'
$projectPath = [IO.Path]::GetFullPath((Join-Path $PSScriptRoot '..'))
$evidencePath = Join-Path $projectPath 'build/verification/phase3/03-combat/integration'
$previousAppData = $env:APPDATA
$previousLocalAppData = $env:LOCALAPPDATA
$failedRuns = @()
try {
    New-Item -ItemType Directory -Force -Path "$evidencePath/appdata", "$evidencePath/localappdata" | Out-Null
    $env:APPDATA = "$evidencePath/appdata"
    $env:LOCALAPPDATA = "$evidencePath/localappdata"
    $godotPath = $(if ($env:GODOT_BIN) { $env:GODOT_BIN } else { 'godot' })
    $ErrorActionPreference = 'Continue'
    $suiteArgs = @('--headless', '--path', $projectPath, '--script', 'res://tests/phase3_integration_runner.gd', '--')
    $logName = 'quick.log'
    if ($Batch) { $suiteArgs += '--batch'; $logName = 'batch.log' }
    if ($Three) { $suiteArgs += '--three' }
    & $godotPath @suiteArgs 2>&1 | Tee-Object -FilePath "$evidencePath/$logName"
    if ($LASTEXITCODE -ne 0) { $failedRuns += "phase3:$LASTEXITCODE" }
    if (Select-String -LiteralPath "$evidencePath/$logName" -Pattern 'SCRIPT ERROR|Parse Error|Compilation failed' -Quiet) { $failedRuns += 'phase3:script-error' }
    if ($Legacy) {
        foreach ($scriptName in @('combat_test_runner', 'map_test_runner', 'campaign_story_test_runner', 'campaign_integration_edge_runner', 'campaign_test_runner')) {
            & $godotPath --headless --path $projectPath --script "res://tests/$scriptName.gd" 2>&1 | Tee-Object -FilePath "$evidencePath/legacy_$scriptName.log"
            if ($LASTEXITCODE -ne 0) { $failedRuns += "${scriptName}:$LASTEXITCODE" }
            if (Select-String -LiteralPath "$evidencePath/legacy_$scriptName.log" -Pattern 'SCRIPT ERROR|Parse Error|Compilation failed' -Quiet) { $failedRuns += "${scriptName}:script-error" }
        }
    }
} finally {
    $env:APPDATA = $previousAppData
    $env:LOCALAPPDATA = $previousLocalAppData
}
if ($failedRuns.Count -gt 0) { throw ('Integration failures: ' + ($failedRuns -join ', ')) }
