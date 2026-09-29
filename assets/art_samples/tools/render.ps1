param([string]$Godot = $(if ($env:GODOT_BIN) { $env:GODOT_BIN } else { 'godot' }))
$ErrorActionPreference = 'Stop'
$artRoot = (Resolve-Path (Join-Path $PSScriptRoot '../../..')).Path
$artOutput = Join-Path $artRoot 'build/verification/art_samples'
New-Item -ItemType Directory -Force $artOutput | Out-Null
@'
config_version=5
[application]
config/name="MagicTa isolated art preview"
[display]
window/size/viewport_width=1200
window/size/viewport_height=1390
[rendering]
renderer/rendering_method="gl_compatibility"
'@ | Set-Content -Encoding utf8 (Join-Path $artOutput 'project.godot')
$artPreviousAppData = $env:APPDATA
$artPreviousLocalAppData = $env:LOCALAPPDATA
try {
    $env:APPDATA = Join-Path $artOutput 'appdata'
    $env:LOCALAPPDATA = Join-Path $artOutput 'localappdata'
    & $Godot --path $artOutput --script (Join-Path $PSScriptRoot 'preview.gd') --log-file (Join-Path $artOutput 'godot.log') -- $artRoot
    if ($LASTEXITCODE -ne 0) { throw "Godot preview failed: $LASTEXITCODE" }
    Copy-Item -LiteralPath (Join-Path $artOutput 'metrics.json') -Destination (Join-Path $artRoot 'assets/art_samples/sample_metrics.json')
} finally {
    $env:APPDATA = $artPreviousAppData
    $env:LOCALAPPDATA = $artPreviousLocalAppData
}
