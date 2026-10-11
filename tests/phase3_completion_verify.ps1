param([switch]$CaptureHost, [switch]$Walking, [switch]$Minotaur, [switch]$Golem)
$ErrorActionPreference = 'Stop'
$projectPath = [IO.Path]::GetFullPath((Join-Path $PSScriptRoot '..'))
$evidencePath = Join-Path $projectPath 'build/verification/phase3/07-completion'
$previousAppData = $env:APPDATA
$previousLocalAppData = $env:LOCALAPPDATA
try {
    $suites = @('phase3_hero_map_test','phase3_ruin_art_test','phase3_enemy_player_test')
    if ($Walking) { $suites += 'walking_test_runner' }
    foreach ($suite in $suites) {
        $profile = if ($suite -eq 'walking_test_runner') { "$evidencePath/walking" } else { $evidencePath }
        $env:APPDATA = "$profile/appdata"
        $env:LOCALAPPDATA = "$profile/localappdata"
        New-Item -ItemType Directory -Force -Path $env:APPDATA,$env:LOCALAPPDATA | Out-Null
        $arguments = @('--path',$projectPath,'--script',"res://tests/$suite.gd",'--quit-after','1800')
        if ($suite -in @('phase3_ruin_art_test','phase3_enemy_player_test')) { $arguments = @('--headless') + $arguments }
        $logPath = "$evidencePath/$suite.log"
        $ErrorActionPreference = 'Continue'
        & $(if ($env:GODOT_BIN) { $env:GODOT_BIN } else { 'godot' }) @arguments 2>&1 | Out-File -LiteralPath $logPath
        $exitCode = $LASTEXITCODE
        $ErrorActionPreference = 'Stop'
        Get-Content -LiteralPath $logPath -Tail 2
        if ($exitCode -ne 0 -or (Select-String -LiteralPath $logPath -Pattern 'SCRIPT ERROR|Parse Error|Compilation failed|FAIL ' -Quiet)) {
            throw "Completion verification failed: $suite ($exitCode), see $logPath"
        }
    }
    if ($CaptureHost) { & "$PSScriptRoot/phase3_host_verify.ps1" -Capture }
    $bossSuites = @()
    if ($Minotaur) { $bossSuites += 'phase3_minotaur_host_capture' }
    if ($Golem) { $bossSuites += 'phase3_golem_host_capture' }
    foreach ($bossSuite in $bossSuites) {
        $profile = "$projectPath/build/verification/phase3/03-combat/integration"
        $env:APPDATA = "$profile/appdata"
        $env:LOCALAPPDATA = "$profile/localappdata"
        New-Item -ItemType Directory -Force -Path $env:APPDATA,$env:LOCALAPPDATA | Out-Null
        $bossName = if ($bossSuite -eq 'phase3_minotaur_host_capture') { 'minotaur' } else { 'golem' }
        $logPath = "$evidencePath/$bossName-host-capture.log"
        $ErrorActionPreference = 'Continue'
        & $(if ($env:GODOT_BIN) { $env:GODOT_BIN } else { 'godot' }) --path $projectPath --script "res://tests/$bossSuite.gd" --quit-after 36000 2>&1 | Out-File -LiteralPath $logPath
        $exitCode = $LASTEXITCODE
        $ErrorActionPreference = 'Stop'
        Get-Content -LiteralPath $logPath -Tail 2
        if ($exitCode -ne 0 -or (Select-String -LiteralPath $logPath -Pattern 'SCRIPT ERROR|Parse Error|Compilation failed|P3 INTEGRATION:' -Quiet)) {
            throw "$bossName host verification failed ($exitCode), see $logPath"
        }
    }
} finally {
    $env:APPDATA = $previousAppData
    $env:LOCALAPPDATA = $previousLocalAppData
}
