param([switch]$Capture)
$ErrorActionPreference = 'Stop'
$projectPath = [IO.Path]::GetFullPath((Join-Path $PSScriptRoot '..'))
$evidencePath = Join-Path $projectPath 'build/verification/phase3/00-integration'
$oldAppData = $env:APPDATA
$oldLocalAppData = $env:LOCALAPPDATA
$failures = @()
try {
    New-Item -ItemType Directory -Force -Path "$evidencePath/appdata", "$evidencePath/localappdata" | Out-Null
    $env:APPDATA = "$evidencePath/appdata"
    $env:LOCALAPPDATA = "$evidencePath/localappdata"
    $ErrorActionPreference = 'Continue'
    foreach ($name in @('phase3_save_host_test_runner', 'phase3_ui_host_test_runner', 'phase3_animation_test_runner', 'campaign_story_test_runner', 'reward_test_runner', 'phase3_items_dispatch_test_runner', 'phase3_contract_test_runner')) {
		$profilePath = if ($name -eq 'phase3_animation_test_runner') { "$evidencePath/05-animation" } else { $evidencePath }
		$env:APPDATA = "$profilePath/appdata"
		$env:LOCALAPPDATA = "$profilePath/localappdata"
		New-Item -ItemType Directory -Force -Path $env:APPDATA, $env:LOCALAPPDATA | Out-Null
        $arguments = @('--headless', '--path', $projectPath, '--script', "res://tests/$name.gd")
        if ($Capture -and $name -eq 'phase3_ui_host_test_runner') { $arguments = @('--path', $projectPath, '--script', "res://tests/$name.gd", '--', '--capture') }
        $logPath = "$evidencePath/$name.log"
        & $(if ($env:GODOT_BIN) { $env:GODOT_BIN } else { 'godot' }) @arguments 2>&1 | Out-File -LiteralPath $logPath
        if ($LASTEXITCODE -ne 0) { $failures += "${name}:$LASTEXITCODE" }
        if (Select-String -LiteralPath $logPath -Pattern 'SCRIPT ERROR|Parse Error|Compilation failed|FAIL ' -Quiet) { $failures += "${name}:log-error" }
        Get-Content -LiteralPath $logPath -Tail 2
    }
} finally {
    $env:APPDATA = $oldAppData
    $env:LOCALAPPDATA = $oldLocalAppData
}
if ($failures.Count -gt 0) { throw ('Host verification failed: ' + ($failures -join ', ')) }
