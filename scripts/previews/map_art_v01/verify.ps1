param([string]$Godot = $(if ($env:GODOT_BIN) { $env:GODOT_BIN } else { 'godot' }))
$ErrorActionPreference = 'Stop'
$projectRoot = (Resolve-Path (Join-Path $PSScriptRoot '../../..')).Path
$verificationRoot = Join-Path $projectRoot 'build/verification/map_art_v01'
New-Item -ItemType Directory -Force $verificationRoot | Out-Null
$previousAppData = $env:APPDATA
$previousLocalAppData = $env:LOCALAPPDATA
try {
    $env:APPDATA = Join-Path $verificationRoot 'appdata'
    $env:LOCALAPPDATA = Join-Path $verificationRoot 'localappdata'
    & $Godot --headless --path $projectRoot --script res://scripts/previews/map_art_v01/build_assets.gd *> (Join-Path $verificationRoot 'build_assets.log')
    if ($LASTEXITCODE -ne 0) { throw 'Asset build failed' }
    & $Godot --headless --path $projectRoot --editor --import --quit *> (Join-Path $verificationRoot 'import.log')
    if ($LASTEXITCODE -ne 0) { throw 'Import failed' }
    & $Godot --headless --path $projectRoot --script res://scripts/previews/map_art_v01/verify_assets.gd *> (Join-Path $verificationRoot 'verify_assets.log')
    if ($LASTEXITCODE -ne 0) { throw 'Asset verification failed' }
    foreach ($mode in @('overall', 'small', 'gallery', 'phone', 'small_open')) {
        $previewArgs = @('--path', $projectRoot, 'res://scenes/previews/map_art_v01.tscn', '--', '--capture')
        if ($mode -eq 'small_open') { $previewArgs += @('--small', '--open') }
        elseif ($mode -ne 'overall') { $previewArgs += "--$mode" }
        & $Godot @previewArgs *> (Join-Path $verificationRoot "render_$mode.log")
        if ($LASTEXITCODE -ne 0) { throw "Render $mode failed" }
    }
    Get-ChildItem -LiteralPath $verificationRoot -Filter '*.log' | ForEach-Object {
        $problems = Select-String -LiteralPath $_.FullName -Pattern 'SCRIPT ERROR|ERROR:' | Where-Object { $_.Line -notmatch 'Failed to read the root certificate store' }
        if ($problems) { throw ($problems | Out-String) }
    }
    Write-Output 'MAP_ART_V01 verification passed; screenshots in assets/environment/tower_v01/previews/'
} finally {
    $env:APPDATA = $previousAppData
    $env:LOCALAPPDATA = $previousLocalAppData
}

