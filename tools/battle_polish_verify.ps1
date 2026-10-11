param([switch]$Bake, [switch]$Capture)
$ErrorActionPreference = 'Stop'
$lock = Join-Path $PSScriptRoot 'phase3_v05_godot_locked.ps1'
if ($Bake) {
    & $lock -Group art-polish-c -Label battle-v02-bake -GodotArgs @('--headless','--script','res://tools/battle_polish_bake.gd')
}
& $lock -Group art-polish-c -Label battle-v02-import -RunTimeoutSeconds 180 -GodotArgs @('--headless','--editor','--import')
& $lock -Group art-polish-c -Label battle-v02-timing -RunTimeoutSeconds 90 -GodotArgs @('--headless','--script','res://tools/art_polish_c_timing_test.gd')
& $lock -Group art-polish-c -Label battle-v02-legacy -RunTimeoutSeconds 90 -GodotArgs @('--headless','--script','res://tools/art_polish_c_legacy_test.gd')
if ($Capture) {
    & $lock -Group art-polish-c -Label battle-v02-mobile -RunTimeoutSeconds 180 -GodotArgs @('--script','res://tools/battle_polish_capture.gd')
    & $lock -Group art-polish-c -Label battle-v02-host -RunTimeoutSeconds 120 -GodotArgs @('--script','res://tools/battle_polish_host_capture.gd')
    & $lock -Group art-polish-c -Label battle-v02-minotaur -RunTimeoutSeconds 240 -GodotArgs @('--script','res://tools/battle_polish_boss_capture.gd')
    & $lock -Group art-polish-c -Label battle-v02-golem -RunTimeoutSeconds 240 -GodotArgs @('--script','res://tools/battle_polish_boss_capture.gd','--','--golem')
}
