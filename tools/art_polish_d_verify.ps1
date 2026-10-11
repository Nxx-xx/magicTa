param([switch]$Capture, [switch]$Play)
$ErrorActionPreference = 'Stop'
$lock = Join-Path $PSScriptRoot 'phase3_v05_godot_locked.ps1'
if ($Play) {
    & $lock -Group art-polish-d -Label playable -GodotArgs @('--rendering-method','gl_compatibility','--script','res://tests/art_polish_d_play.gd')
    return
}
foreach ($suite in @('main_menu','story_intro_ui','action_choices','compact_screens','phase3_ui_host','item_icons')) {
    & $lock -Group art-polish-d -Label "verify-$suite" -GodotArgs @('--rendering-method','gl_compatibility','--position=-2000,-2000','--script',"res://tests/art_polish_d_${suite}_test.gd")
}
if ($Capture) {
    & $lock -Group art-polish-d -Label verify-capture -GodotArgs @('--rendering-method','gl_compatibility','--position=-2000,-2000','--script','res://tests/art_polish_d_capture.gd','--','--after')
}
