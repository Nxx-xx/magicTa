param([switch]$Play, [ValidateSet('menu','shop','inventory')][string]$Screen='menu', [switch]$Capture, [switch]$Baseline)
$ErrorActionPreference='Stop'
$lock=Join-Path $PSScriptRoot 'phase3_v05_godot_locked.ps1'
if ($Play) {
    $playArgs=@('--rendering-method','gl_compatibility','--script','res://tests/ui_polish_v02_play.gd')
    if ($Screen -ne 'menu') {$playArgs+=@('--',"--$Screen")}
    & $lock -Group ui-polish-v02 -Label "play-$Screen" -GodotArgs $playArgs
    return
}
if ($Baseline) {
    & $lock -Group ui-polish-v02 -Label before -RunTimeoutSeconds 120 -GodotArgs @('--rendering-method','gl_compatibility','--position=-2000,-2000','--script','res://tests/ui_polish_v02_capture.gd')
    return
}
foreach ($suite in @('main_menu','action_choices','compact_screens','phase3_ui_host','item_icons','touch_scroll')) {
    & $lock -Group ui-polish-v02 -Label "verify-$suite" -RunTimeoutSeconds 180 -GodotArgs @('--rendering-method','gl_compatibility','--position=-2000,-2000','--script',"res://tests/ui_polish_v02_${suite}_test.gd")
}
if ($Capture) {
    & $lock -Group ui-polish-v02 -Label after -RunTimeoutSeconds 120 -GodotArgs @('--rendering-method','gl_compatibility','--position=-2000,-2000','--script','res://tests/ui_polish_v02_capture.gd','--','--after')
}
