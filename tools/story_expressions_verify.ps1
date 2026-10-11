param([ValidateSet('before','after','import','package','regression','packed','intro')][string]$Mode='after')
$ErrorActionPreference='Stop'
$project=[IO.Path]::GetFullPath((Join-Path $PSScriptRoot '..'))
$evidence=Join-Path $project 'build/verification/story-expressions'
New-Item -ItemType Directory -Force $evidence | Out-Null
$mutex=[Threading.Mutex]::new($false,'MagicTa_Phase3_Parallel_Godot')
$acquired=$false
$oldAppData=$env:APPDATA
$oldLocalAppData=$env:LOCALAPPDATA
try {
    Write-Host "Waiting for shared Godot mutex: story-expressions / $Mode"
    try {$acquired=$mutex.WaitOne([TimeSpan]::FromMinutes(30))} catch [Threading.AbandonedMutexException] {$acquired=$true}
    if (-not $acquired) {throw 'Godot mutex timeout'}
    $env:APPDATA=Join-Path $evidence 'appdata'
    $env:LOCALAPPDATA=Join-Path $evidence 'localappdata'
    New-Item -ItemType Directory -Force $env:APPDATA,$env:LOCALAPPDATA | Out-Null
    if ($Mode -eq 'package') {
        & python (Join-Path $project 'tools/build_wechat.py') --appid wx57ebf150a77fedb9 --ios-mode high-performance --output-folder wechat-story-expressions --no-latest 2>&1 | Tee-Object -FilePath (Join-Path $evidence 'export.log')
        if ($LASTEXITCODE -ne 0) {throw 'Story export failed'}
    } else {
        $arguments=@('--path',$project)
        if ($Mode -eq 'import') {$arguments+=@('--headless','--editor','--import')}
        elseif ($Mode -eq 'regression') {$arguments+=@('--headless','--script','res://tests/campaign_story_test_runner.gd')}
        elseif ($Mode -eq 'intro') {
            $intro=[IO.File]::ReadAllText((Join-Path $project 'tests/story_intro_ui_test_runner.gd')).Replace('verification/story-intro/','verification/story-expressions/')
            # Force an actually overflowing external-text fixture at the widest
            # viewport; the original 15 repeats can legitimately fit there.
            $intro=$intro.Replace('.repeat(15)','.repeat(40)').Replace('root.size = dimensions',"root.size = dimensions`n`t`troot.content_scale_size = dimensions")
            [IO.File]::WriteAllText((Join-Path $evidence 'intro-regression.gd'),$intro)
            $arguments+=@('--headless','--script','res://build/verification/story-expressions/intro-regression.gd')
        }
        else {$arguments+=@('--script','res://tests/story_expressions_capture.gd','--',('--'+$Mode))}
        $info=[Diagnostics.ProcessStartInfo]::new()
        $info.FileName=$(if ($env:GODOT_BIN) { $env:GODOT_BIN } else { 'godot' })
        if ($Mode -eq 'packed') {
            $packed=Join-Path $evidence 'packed-runtime'
            New-Item -ItemType Directory -Force $packed | Out-Null
            [IO.File]::WriteAllText((Join-Path $packed 'project.godot'),"config_version=5`n[application]`nconfig/name=`"Story expressions package audit`"`n[rendering]`nrenderer/rendering_method=`"gl_compatibility`"`n")
            Copy-Item -LiteralPath (Join-Path $project 'tests/story_expressions_packed.gd') -Destination (Join-Path $packed 'verify.gd')
            $info.FileName=Join-Path $project 'build/wechat-toolchain/editor/Godot_v4.6.1-stable_win64_console.exe'
            $arguments=@('--path',$packed,'--script','res://verify.gd','--',('--package='+ (Join-Path $project 'build/wechat-story-expressions/engine/godot.zip')),('--output='+(Join-Path $evidence 'packed')))
        }
        $info.WorkingDirectory=$project
        $info.UseShellExecute=$false
        $info.CreateNoWindow=$true
        $info.RedirectStandardOutput=$true
        $info.RedirectStandardError=$true
        foreach($argument in $arguments){$info.ArgumentList.Add($argument)}
        $process=[Diagnostics.Process]::new()
        $process.StartInfo=$info
        [void]$process.Start()
        $stdout=$process.StandardOutput.ReadToEndAsync()
        $stderr=$process.StandardError.ReadToEndAsync()
        if(-not $process.WaitForExit(900000)){$process.Kill($true);throw 'Godot timeout'}
        $output=$stdout.GetAwaiter().GetResult()+"`n"+$stderr.GetAwaiter().GetResult()
        [IO.File]::WriteAllText((Join-Path $evidence "$Mode.log"),$output)
        Write-Host $output
        if($process.ExitCode -ne 0 -or $output -match 'SCRIPT ERROR|Parse Error|FAIL |Assertion failed'){throw "Godot $Mode failed"}
    }
} finally {
    $env:APPDATA=$oldAppData
    $env:LOCALAPPDATA=$oldLocalAppData
    if($acquired){$mutex.ReleaseMutex()}
    $mutex.Dispose()
}
