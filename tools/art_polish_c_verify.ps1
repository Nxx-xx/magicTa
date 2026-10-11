param([switch]$Capture, [switch]$Timed)
$ErrorActionPreference = 'Stop'
$lock = Join-Path $PSScriptRoot 'phase3_v05_godot_locked.ps1'
& $lock -Group art-polish-c -Label timing -RunTimeoutSeconds 90 -GodotArgs @('--headless','--script','res://tools/art_polish_c_timing_test.gd')
& $lock -Group art-polish-c -Label enemy-protocol -RunTimeoutSeconds 90 -GodotArgs @('--headless','--script','res://tests/phase3_enemy_player_test.gd')
& $lock -Group art-polish-c -Label legacy -RunTimeoutSeconds 90 -GodotArgs @('--headless','--script','res://tools/art_polish_c_legacy_test.gd')
if ($Capture) {
    & $lock -Group art-polish-c -Label mobile -RunTimeoutSeconds 120 -GodotArgs @('--script','res://tools/art_polish_c_capture.gd')
    & $lock -Group art-polish-c -Label host-slime -RunTimeoutSeconds 120 -GodotArgs @('--script','res://tools/art_polish_c_host_capture.gd')
    & $lock -Group art-polish-c -Label host-minotaur -RunTimeoutSeconds 180 -GodotArgs @('--script','res://tools/art_polish_c_boss_capture.gd')
    & $lock -Group art-polish-c -Label host-golem -RunTimeoutSeconds 180 -GodotArgs @('--script','res://tools/art_polish_c_boss_capture.gd','--','--golem')
}
if ($Timed) {
    & $lock -Group art-polish-c -Label timed -RunTimeoutSeconds 180 -GodotArgs @('--script','res://tools/art_polish_c_motion_capture.gd')
}
