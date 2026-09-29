param([switch]$SkipVisual, [switch]$SkipRegression)
$ErrorActionPreference = 'Stop'
$phaseRoot = (Resolve-Path (Join-Path $PSScriptRoot '..')).Path
$phaseEvidence = Join-Path $phaseRoot 'build/verification/phase2-integration'
$phaseEngine = $(if ($env:GODOT_BIN) { $env:GODOT_BIN } else { 'godot' })
$phaseOldAppData = $env:APPDATA
$phaseOldLocalAppData = $env:LOCALAPPDATA

function Invoke-PhaseCheck([string]$Name, [string[]]$Arguments, [int]$TimeoutSeconds = 120) {
    $suiteRoot = Join-Path $phaseEvidence $Name
    New-Item -ItemType Directory -Force $suiteRoot | Out-Null
    $env:APPDATA = Join-Path $suiteRoot 'appdata'
    $env:LOCALAPPDATA = Join-Path $suiteRoot 'localappdata'
    New-Item -ItemType Directory -Force $env:APPDATA,$env:LOCALAPPDATA | Out-Null
    $stdout = Join-Path $suiteRoot 'stdout.log'
    $stderr = Join-Path $suiteRoot 'stderr.log'
    $process = Start-Process -FilePath $phaseEngine -ArgumentList $Arguments -WorkingDirectory $phaseRoot -WindowStyle Hidden -PassThru -RedirectStandardOutput $stdout -RedirectStandardError $stderr
    $deadline = [DateTime]::UtcNow.AddSeconds($TimeoutSeconds)
    while (-not $process.WaitForExit(1000)) {
        if ([DateTime]::UtcNow -ge $deadline) {
            Stop-Process -Id $process.Id
            throw "$Name timed out; stopped only this verification process."
        }
    }
    $process.Refresh()
    Get-Content -LiteralPath $stdout -Tail 3
    if ($process.ExitCode -ne 0 -or (Select-String -LiteralPath $stderr -Pattern 'SCRIPT ERROR|Parse Error|FAIL:' -Quiet)) {
        Get-Content -LiteralPath $stderr -Tail 35
        throw "$Name failed with exit code $($process.ExitCode)."
    }
}

try {
    New-Item -ItemType Directory -Force $phaseEvidence | Out-Null
    New-Item -ItemType File -Force (Join-Path $phaseEvidence '.gdignore') | Out-Null
    Push-Location $phaseRoot
    try {
        python tools/check_project.py
        if ($LASTEXITCODE -ne 0) { throw 'Static project checks failed.' }
        Invoke-PhaseCheck 'import' @('--headless','--path','.', '--editor','--import','--quit')
        if (-not $SkipRegression) {
            foreach ($suite in @('combat','map','random_map','keys','monster_ui','reward','reward_ui')) {
                Invoke-PhaseCheck $suite @('--headless','--path','.', '--script',"tests/${suite}_test_runner.gd")
            }
        }
        # The explicit list is completed during integration, not inferred from filenames.
        foreach ($script in @('campaign_test_runner.gd','campaign_story_test_runner.gd','campaign_integration_edge_runner.gd','phase2_ui_test_runner.gd')) {
            if (-not (Test-Path -LiteralPath (Join-Path $PSScriptRoot $script))) { throw "Missing required Phase 2 suite: $script" }
            $suiteName = if ($script -eq 'phase2_ui_test_runner.gd') { 'phase2-ui' } else { $script -replace '.gd$','' }
            Invoke-PhaseCheck $suiteName @('--headless','--path','.', '--script',"tests/$script") 300
        }
        if (-not $SkipVisual) {
            Invoke-PhaseCheck 'phase2-ui-visual' @('--path','.', '--rendering-method','gl_compatibility','--position=-2000,-2000','--script','tests/phase2_ui_test_runner.gd','--','--capture') 180
        }
    } finally { Pop-Location }
} finally {
    $env:APPDATA = $phaseOldAppData
    $env:LOCALAPPDATA = $phaseOldLocalAppData
}
