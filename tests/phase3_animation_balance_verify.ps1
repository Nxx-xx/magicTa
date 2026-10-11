param([switch]$Batch, [switch]$Balance, [switch]$Presentation, [switch]$Supplies, [switch]$Prepared, [switch]$Legal, [switch]$Capture, [switch]$BakeRigs, [switch]$Variants)
$ErrorActionPreference = 'Stop'
$projectPath = [IO.Path]::GetFullPath((Join-Path $PSScriptRoot '..'))
$evidencePath = Join-Path $projectPath 'build/verification/phase3/06-animation-balance'
$previousAppData = $env:APPDATA
$previousLocalAppData = $env:LOCALAPPDATA
try {
    New-Item -ItemType Directory -Force -Path "$evidencePath/appdata", "$evidencePath/localappdata" | Out-Null
    $env:APPDATA = "$evidencePath/appdata"
    $env:LOCALAPPDATA = "$evidencePath/localappdata"
    $suiteNames = @()
    if ($Balance) { $suiteNames += 'phase3_balance_runner' }
    if ($Presentation) { $suiteNames += 'phase3_replay_timing_test' }
    if ($Legal) { $suiteNames += 'phase3_legal_progression_runner' }
    if ($Capture) { $suiteNames += 'phase3_replay_host_capture' }
    if ($BakeRigs) { $suiteNames += 'phase3_rig_bake' }
    foreach ($suiteName in $suiteNames) {
        $scriptPath = "res://tests/$suiteName.gd"
        if ($suiteName -eq 'phase3_rig_bake') { $scriptPath = "res://tools/$suiteName.gd" }
        $arguments = @('--path',$projectPath,'--script',$scriptPath,'--quit-after','36000','--')
        if ($suiteName -notin @('phase3_replay_host_capture','phase3_rig_bake')) { $arguments = @('--headless') + $arguments }
        if ($Batch) { $arguments += '--batch' }
        if ($Supplies) { $arguments += '--supplies' }
        if ($Prepared) { $arguments += '--prepared'; if (-not $Supplies) { $arguments += '--supplies' } }
        if ($Variants) { $arguments += '--variants' }
        $logPath = "$evidencePath/$suiteName.log"
        $ErrorActionPreference = 'Continue'
        & $(if ($env:GODOT_BIN) { $env:GODOT_BIN } else { 'godot' }) @arguments 2>&1 | Out-File -LiteralPath $logPath
        $exitCode = $LASTEXITCODE
        $ErrorActionPreference = 'Stop'
        Get-Content -LiteralPath $logPath -Tail 4
        if ($exitCode -ne 0 -or (Select-String -LiteralPath $logPath -Pattern 'SCRIPT ERROR|Parse Error|Compilation failed' -Quiet)) { throw "Verification failed: $suiteName (exit $exitCode); see $logPath" }
    }
} finally {
    $env:APPDATA = $previousAppData
    $env:LOCALAPPDATA = $previousLocalAppData
}
