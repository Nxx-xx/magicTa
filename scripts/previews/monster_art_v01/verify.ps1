$ErrorActionPreference = 'Stop'
$projectRoot = (Resolve-Path (Join-Path $PSScriptRoot '../../..')).Path
$verificationRoot = Join-Path $projectRoot 'build/verification/monster_art_v01'
$engine = $(if ($env:GODOT_BIN) { $env:GODOT_BIN } else { 'godot' })
New-Item -ItemType Directory -Force "$verificationRoot/appdata", "$verificationRoot/localappdata" | Out-Null
$env:APPDATA = "$verificationRoot/appdata"
$env:LOCALAPPDATA = "$verificationRoot/localappdata"
& $engine --headless --path $projectRoot --script scripts/previews/monster_art_v01/pack_assets.gd --log-file "$verificationRoot/pack.log"
if ($LASTEXITCODE -ne 0) { throw 'Asset packing failed' }
& $engine --headless --editor --path $projectRoot --import --log-file "$verificationRoot/import.log"
if ($LASTEXITCODE -ne 0) { throw 'Godot import failed' }
foreach ($mode in @('dark', 'light')) {
    $runArgs = @('--path', $projectRoot, '--rendering-method', 'gl_compatibility', '--log-file', "$verificationRoot/render_$mode.log", 'res://scenes/previews/monster_art_v01.tscn', '--', '--capture')
    if ($mode -eq 'light') { $runArgs += '--light' }
    $process = Start-Process -FilePath $engine -ArgumentList $runArgs -WindowStyle Hidden -PassThru
    if (-not $process.WaitForExit(20000)) { $process.Kill(); throw "Timed out rendering $mode" }
    if ($process.ExitCode -ne 0) { throw "Rendering failed: $mode" }
    $log = Get-Content "$verificationRoot/render_$mode.log" -Raw
    if ($log -notmatch 'MONSTER_RENDER_OK') { throw "No render success marker: $mode" }
    Write-Output $log
}
