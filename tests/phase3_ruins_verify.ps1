param([switch]$Preview, [switch]$Capture)
$ErrorActionPreference = 'Stop'
$projectDir = [IO.Path]::GetFullPath((Join-Path $PSScriptRoot '..'))
$evidenceDir = Join-Path $projectDir 'build/verification/phase3/02-ruins'
New-Item -ItemType Directory -Force -Path $evidenceDir, (Join-Path $evidenceDir 'appdata'), (Join-Path $evidenceDir 'localappdata') | Out-Null
$oldAppData = $env:APPDATA
$oldLocalAppData = $env:LOCALAPPDATA
try {
    $env:APPDATA = Join-Path $evidenceDir 'appdata'
    $env:LOCALAPPDATA = Join-Path $evidenceDir 'localappdata'
    $runner = 'res://tests/phase3_ruins_preview.gd' 
    if ($Capture) {
        & $(if ($env:GODOT_BIN) { $env:GODOT_BIN } else { 'godot' }) --path $projectDir --script $runner -- --capture 2>&1 | Tee-Object (Join-Path $evidenceDir 'preview.log')
    } elseif ($Preview) {
        & $(if ($env:GODOT_BIN) { $env:GODOT_BIN } else { 'godot' }) --path $projectDir --script $runner 2>&1 | Tee-Object (Join-Path $evidenceDir 'preview.log')
    } else {
        & $(if ($env:GODOT_BIN) { $env:GODOT_BIN } else { 'godot' }) --headless --path $projectDir --script res://tests/phase3_ruins_test_runner.gd 2>&1 | Tee-Object (Join-Path $evidenceDir 'tests.log')
    }
    exit $LASTEXITCODE
} finally {
    $env:APPDATA = $oldAppData
    $env:LOCALAPPDATA = $oldLocalAppData
}
