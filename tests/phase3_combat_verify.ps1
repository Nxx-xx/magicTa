param([switch]$PackArt, [switch]$Preview)
$ErrorActionPreference = 'Stop'
$projectPath = [IO.Path]::GetFullPath((Join-Path $PSScriptRoot '..'))
$evidencePath = Join-Path $projectPath 'build/verification/phase3/03-combat'
$previousAppData = $env:APPDATA
$previousLocalAppData = $env:LOCALAPPDATA
try {
    New-Item -ItemType Directory -Force -Path "$evidencePath/appdata", "$evidencePath/localappdata" | Out-Null
    $env:APPDATA = "$evidencePath/appdata"
    $env:LOCALAPPDATA = "$evidencePath/localappdata"
    $godotPath = $(if ($env:GODOT_BIN) { $env:GODOT_BIN } else { 'godot' })
    # Windows PowerShell wraps native stderr as ErrorRecord; use the process exit code.
    $ErrorActionPreference = 'Continue'
    & $godotPath --headless --path $projectPath --script res://tests/phase3_combat_test_runner.gd 2>&1 | Tee-Object -FilePath "$evidencePath/test.log"
    if ($LASTEXITCODE -ne 0) { throw "Combat tests failed: $LASTEXITCODE" }
    if ($PackArt) {
        & $godotPath --headless --path $projectPath --script res://tests/phase3_enemies_pack_art.gd 2>&1 | Tee-Object -FilePath "$evidencePath/art.log"
        if ($LASTEXITCODE -ne 0) { throw "Art packing failed: $LASTEXITCODE" }
    }
    if ($Preview) {
        & $godotPath --path $projectPath --script res://tests/phase3_enemies_preview.gd
        if ($LASTEXITCODE -ne 0) { throw "Preview failed: $LASTEXITCODE" }
    }
} finally {
    $env:APPDATA = $previousAppData
    $env:LOCALAPPDATA = $previousLocalAppData
}
