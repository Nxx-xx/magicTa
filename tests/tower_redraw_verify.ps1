param([switch]$Capture, [switch]$SkipImport)
$ErrorActionPreference = 'Stop'
$project = [IO.Path]::GetFullPath((Join-Path $PSScriptRoot '..'))
$locked = Join-Path $project 'tools/phase3_v05_godot_locked.ps1'
if (-not $SkipImport) {
    & $locked -Group tower-redraw -Label import -RunTimeoutSeconds 180 -GodotArgs @('--headless','--editor','--import')
}
& $locked -Group tower-redraw -Label geometry -RunTimeoutSeconds 120 -GodotArgs @('--rendering-method','gl_compatibility','--position','10000,10000','--script','res://tests/tower_redraw_geometry_test.gd')
if ($Capture) {
    & $locked -Group tower-redraw -Label after -RunTimeoutSeconds 120 -GodotArgs @('--rendering-method','gl_compatibility','--position','10000,10000','--script','res://tests/tower_redraw_capture.gd','--','--after')
}
foreach ($test in @('keys_test_runner','random_map_test_runner','map_test_runner')) {
    & $locked -Group tower-redraw -Label $test -RunTimeoutSeconds 120 -GodotArgs @('--headless','--script',"res://tests/$test.gd")
}
& $locked -Group tower-redraw-mobile-map -Label mobile -RunTimeoutSeconds 120 -GodotArgs @('--headless','--script','res://tests/mobile_map_test_runner.gd')
& $locked -Group tower-redraw-walking -Label walking -RunTimeoutSeconds 120 -GodotArgs @('--headless','--script','res://tests/walking_test_runner.gd')
