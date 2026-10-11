param([switch]$Capture, [string[]]$Only = @())
$ErrorActionPreference = 'Stop'
$projectPath = [IO.Path]::GetFullPath((Join-Path $PSScriptRoot '..'))
$evidencePath = Join-Path $projectPath 'build/verification/tower-polish'
$godotPath = $(if ($env:GODOT_BIN) { $env:GODOT_BIN } else { 'godot' })
$savedAppData = $env:APPDATA
$savedLocalAppData = $env:LOCALAPPDATA
$results = @()
try {
    $runs = @(
        @{ Name='mobile_map_test_runner'; Profile='mobile-map/tower-polish' },
        @{ Name='walking_test_runner'; Profile='walking/tower-polish' },
        @{ Name='walking_polish_test_runner'; Profile='walking/tower-polish' },
        @{ Name='camp_map_test_runner'; Profile='camp-map/tower-polish' },
        @{ Name='phase3_ui_host_test_runner'; Profile='phase3/00-integration/tower-polish' },
        @{ Name='phase3_v06_hero_regression_phase3_hero_map_test'; Folder='tools'; Profile='phase3/08-parallel/hero_refine/tower-polish'; Render=$true },
        @{ Name='phase3_ruin_art_test'; Profile='phase3/07-completion/tower-polish' },
        @{ Name='phase3_v06_golem_production_test'; Folder='tools'; Profile='phase3/08-parallel/golem_refine/tower-polish' }
    )
    if ($Capture) { $runs += @{ Name='tower_polish_capture'; Profile='tower-polish'; Render=$true; After=$true } }
    foreach ($run in $runs) {
        if ($Only.Count -and $run.Name -notin $Only) { continue }
        $profilePath = Join-Path $projectPath ('build/verification/' + $run.Profile)
        $env:APPDATA = "$profilePath/appdata"
        $env:LOCALAPPDATA = "$profilePath/localappdata"
        New-Item -ItemType Directory -Force -Path $env:APPDATA,$env:LOCALAPPDATA,$evidencePath | Out-Null
        $folder = if ($run.Folder) { $run.Folder } else { 'tests' }
        $arguments = @('--headless','--path',$projectPath,'--script',"res://$folder/$($run.Name).gd")
        if ($run.Render) { $arguments = @('--path',$projectPath,'--rendering-method','gl_compatibility','--position','10000,10000','--script',"res://$folder/$($run.Name).gd") }
        if ($run.After) { $arguments += @('--','--after') }
        $logPath = Join-Path $evidencePath ($run.Name+'.log')
        $stderrPath = $logPath+'.stderr'
        $process = Start-Process -FilePath $godotPath -ArgumentList $arguments -WindowStyle Hidden -PassThru -RedirectStandardOutput $logPath -RedirectStandardError $stderrPath
        $null = $process.Handle
        if (-not $process.WaitForExit(180000)) { $process.Kill(); throw "Timed out: $($run.Name)" }
        $failed = $process.ExitCode -ne 0 -or (Select-String -LiteralPath $logPath,$stderrPath -Pattern 'SCRIPT ERROR|Parse Error|Compilation failed|FAIL[: ]' -Quiet)
        $unexpected = @(Get-Content -LiteralPath $stderrPath | Where-Object { $_ -match '^ERROR:' -and $_ -notmatch 'Failed to read the root certificate store' })
        $results += @{name=$run.Name;exit_code=$process.ExitCode;failed=[bool]$failed;unexpected_errors=$unexpected;log=$logPath}
        $results | ConvertTo-Json -Depth 5 | Set-Content -LiteralPath "$evidencePath/regression-results.json" -Encoding utf8
        Get-Content -LiteralPath $logPath -Tail 1
        if ($failed -or $unexpected.Count) { throw "Regression failed: $($run.Name); inspect $logPath" }
    }
} finally {
    $env:APPDATA = $savedAppData
    $env:LOCALAPPDATA = $savedLocalAppData
}
