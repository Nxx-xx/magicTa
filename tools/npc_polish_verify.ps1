param([ValidateSet('before','after','import','shop','bake','package','packed','baseline-packed')][string]$Mode = 'after')
$ErrorActionPreference = 'Stop'
$projectPath = [IO.Path]::GetFullPath((Join-Path $PSScriptRoot '..'))
$evidence = Join-Path $projectPath 'build/verification/npc-polish'
New-Item -ItemType Directory -Force $evidence | Out-Null
$mutex = [Threading.Mutex]::new($false, 'MagicTa_Phase3_Parallel_Godot')
$acquired = $false
$previousAppData = $env:APPDATA
$previousLocalAppData = $env:LOCALAPPDATA
try {
    Write-Host "Waiting for shared Godot lock: npc-polish / $Mode"
    try { $acquired = $mutex.WaitOne([TimeSpan]::FromMinutes(30)) }
    catch [Threading.AbandonedMutexException] { $acquired = $true }
    if (-not $acquired) { throw 'Shared Godot lock timed out' }
    $env:APPDATA = Join-Path $evidence 'appdata'
    $env:LOCALAPPDATA = Join-Path $evidence 'localappdata'
    New-Item -ItemType Directory -Force $env:APPDATA,$env:LOCALAPPDATA | Out-Null
    if ($Mode -eq 'package') {
        & python (Join-Path $projectPath 'tools/build_wechat.py') --appid wx57ebf150a77fedb9 --ios-mode high-performance --output-folder wechat-npc-polish --no-latest 2>&1 | Tee-Object -FilePath (Join-Path $evidence 'package.log')
        if ($LASTEXITCODE -ne 0) { throw 'Export failed' }
    } else {
        $godotArgs = @('--path', $projectPath)
        switch ($Mode) {
            'import' { $godotArgs += @('--headless','--editor','--import') }
            'shop' { $godotArgs += @('--headless','--script','res://tests/shop_floor_test_runner.gd') }
            'bake' { $godotArgs += @('--headless','--script','res://tools/npc_polish_bake.gd') }
            default { $godotArgs += @('--rendering-method','gl_compatibility','--script','res://tests/npc_polish_capture.gd','--',"--$Mode") }
        }
        $info = [Diagnostics.ProcessStartInfo]::new()
        $info.FileName = $(if ($env:GODOT_BIN) { $env:GODOT_BIN } else { 'godot' })
        if ($Mode -in @('packed','baseline-packed')) {
            $info.FileName = Join-Path $projectPath 'build/wechat-toolchain/editor/Godot_v4.6.1-stable_win64_console.exe'
            $godotArgs = @('--path',(Join-Path $evidence 'packed-runtime'),'--rendering-method','gl_compatibility','--script','res://verify.gd')
            if ($Mode -eq 'baseline-packed') { $godotArgs[-1] = 'res://baseline.gd'; $godotArgs += @('--','--baseline-packed') }
        }
        $info.WorkingDirectory = $projectPath
        $info.UseShellExecute = $false
        $info.CreateNoWindow = $true
        $info.RedirectStandardOutput = $true
        $info.RedirectStandardError = $true
        foreach ($argument in $godotArgs) { $info.ArgumentList.Add($argument) }
        $process = [Diagnostics.Process]::new()
        $process.StartInfo = $info
        [void]$process.Start()
        $stdout = $process.StandardOutput.ReadToEndAsync()
        $stderr = $process.StandardError.ReadToEndAsync()
        if (-not $process.WaitForExit(600000)) { $process.Kill($true); throw 'Godot timed out' }
        $outputText = $stdout.GetAwaiter().GetResult() + "`n" + $stderr.GetAwaiter().GetResult()
        [IO.File]::WriteAllText((Join-Path $evidence "$Mode.log"), $outputText)
        Write-Host $outputText
        if ($process.ExitCode -ne 0 -or $outputText -match 'SCRIPT ERROR|Parse Error|FAIL:|FAIL |Assertion failed') { throw 'Godot validation failed' }
    }
} finally {
    $env:APPDATA = $previousAppData
    $env:LOCALAPPDATA = $previousLocalAppData
    if ($acquired) { $mutex.ReleaseMutex() }
    $mutex.Dispose()
}
