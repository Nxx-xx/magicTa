param([switch]$Capture, [switch]$Validate, [switch]$Rebuild)
$ErrorActionPreference = 'Stop'
$heroProject = (Resolve-Path (Join-Path $PSScriptRoot '../../../..')).Path
$heroGodot = $(if ($env:GODOT_BIN) { $env:GODOT_BIN } else { 'godot' })
$heroOldAppData = $env:APPDATA
$heroOldLocalData = $env:LOCALAPPDATA
try {
    $env:APPDATA = Join-Path $heroProject 'build/verification/hero/appdata'
    $env:LOCALAPPDATA = Join-Path $heroProject 'build/verification/hero/localappdata'
    New-Item -ItemType Directory -Force $env:APPDATA,$env:LOCALAPPDATA | Out-Null
    if ($Rebuild) {
        & $heroGodot --headless --path $heroProject --script res://assets/characters/hero/tools/export_hero.gd --quit-after 2
        if ($LASTEXITCODE -ne 0) { throw 'Hero export failed' }
        & $heroGodot --headless --path $heroProject --editor --import --quit
        if ($LASTEXITCODE -ne 0) { throw 'Godot import failed' }
    }
    if ($Validate) {
        & $heroGodot --headless --path $heroProject --script res://assets/characters/hero/tools/validate_hero.gd
    } elseif ($Capture) {
        & $heroGodot --path $heroProject --rendering-method gl_compatibility res://assets/characters/hero/preview/hero_preview.tscn -- --capture
    } else {
        & $heroGodot --path $heroProject --rendering-method gl_compatibility res://assets/characters/hero/preview/hero_preview.tscn
    }
    if ($LASTEXITCODE -ne 0) { throw 'Hero preview or validation failed' }
} finally {
    $env:APPDATA = $heroOldAppData
    $env:LOCALAPPDATA = $heroOldLocalData
}
