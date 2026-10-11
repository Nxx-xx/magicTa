param([switch]$Preview, [switch]$Capture, [switch]$ArtReview)
$ErrorActionPreference = 'Stop'
$projectRoot = Split-Path $PSScriptRoot -Parent
$evidence = Join-Path $projectRoot 'build/verification/phase3/05-animation'
$oldAppData = $env:APPDATA
$oldLocalAppData = $env:LOCALAPPDATA
New-Item -ItemType Directory -Force -Path $evidence | Out-Null
try {
    $env:APPDATA = Join-Path $evidence 'appdata'
    $env:LOCALAPPDATA = Join-Path $evidence 'localappdata'
    New-Item -ItemType Directory -Force -Path $env:APPDATA, $env:LOCALAPPDATA | Out-Null
    $arguments = @('--path', $projectRoot)
    if ($ArtReview) {
        $arguments += @('--headless', '--script', 'res://tests/phase3_animation_art_review.gd')
    } elseif ($Preview -or $Capture) {
        $arguments += @('--script', 'res://tests/phase3_animation_preview.gd')
        if ($Capture) { $arguments += @('--', '--capture') }
    } else {
        $arguments += @('--headless', '--script', 'res://tests/phase3_animation_test_runner.gd')
    }
    $logPath = Join-Path $evidence $(if ($ArtReview) { 'art_review.log' } elseif ($Preview -or $Capture) { 'preview.log' } else { 'tests.log' })
    & $(if ($env:GODOT_BIN) { $env:GODOT_BIN } else { 'godot' }) @arguments 2>&1 | Tee-Object -FilePath $logPath
    if ($LASTEXITCODE -ne 0) { throw "Godot exited with $LASTEXITCODE" }
    if (Select-String -LiteralPath $logPath -Pattern 'SCRIPT ERROR|Parse Error|Compilation failed' -Quiet) { throw 'Godot script errors in log' }
} finally {
    $env:APPDATA = $oldAppData
    $env:LOCALAPPDATA = $oldLocalAppData
}
