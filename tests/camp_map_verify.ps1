param([switch]$Capture)
$ErrorActionPreference = 'Stop'
$projectPath = [IO.Path]::GetFullPath((Join-Path $PSScriptRoot '..'))
$evidencePath = Join-Path $projectPath 'build/verification/camp-map'
$godotPath = $(if ($env:GODOT_BIN) { $env:GODOT_BIN } else { 'godot' })
$savedAppData = $env:APPDATA
$savedLocalAppData = $env:LOCALAPPDATA
try {
    $runs = @(
        @{ Name = 'camp_map_test_runner'; Profile = $evidencePath; Log = 'test' },
        @{ Name = 'phase2_ui_test_runner'; Profile = "$projectPath/build/verification/phase2-ui/camp-regression"; Log = 'phase2-ui' },
        @{ Name = 'phase3_ui_host_test_runner'; Profile = "$projectPath/build/verification/phase3/00-integration/camp-regression"; Log = 'phase3-ui' },
        @{ Name = 'campaign_story_test_runner'; Profile = $evidencePath; Log = 'story' }
    )
    foreach ($run in $runs) {
        New-Item -ItemType Directory -Force -Path "$($run.Profile)/appdata", "$($run.Profile)/localappdata" | Out-Null
        $env:APPDATA = "$($run.Profile)/appdata"
        $env:LOCALAPPDATA = "$($run.Profile)/localappdata"
        $arguments = @('--headless', '--path', $projectPath, '--script', "res://tests/$($run.Name).gd")
        if ($Capture -and $run.Name -eq 'camp_map_test_runner') {
            $arguments = @('--path', $projectPath, '--rendering-method', 'gl_compatibility', '--position', '10000,10000', '--script', "res://tests/$($run.Name).gd", '--', '--capture')
        }
        $logPath = Join-Path $evidencePath "$($run.Log).log"
        # Windows PowerShell treats native stderr as an error record even for warnings.
        $ErrorActionPreference = 'Continue'
        & $godotPath @arguments 2>&1 | Out-File -LiteralPath $logPath -Encoding utf8
        $ErrorActionPreference = 'Stop'
        if ($LASTEXITCODE -ne 0 -or (Select-String -LiteralPath $logPath -Pattern 'SCRIPT ERROR|Parse Error|Compilation failed|FAIL ' -Quiet)) {
            Get-Content -LiteralPath $logPath
            throw "$($run.Name) failed"
        }
        Get-Content -LiteralPath $logPath -Tail 1
    }
} finally {
    $env:APPDATA = $savedAppData
    $env:LOCALAPPDATA = $savedLocalAppData
}
