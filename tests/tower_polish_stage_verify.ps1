$ErrorActionPreference = 'Stop'
$projectPath = [IO.Path]::GetFullPath((Join-Path $PSScriptRoot '..'))
$latest = Get-Content -LiteralPath "$projectPath/build/wechat-tower-final-latest.json" -Raw | ConvertFrom-Json
$stage = [IO.Path]::GetFullPath($latest.source)
if (-not $stage.StartsWith("$projectPath\build\wechat-runs\",[StringComparison]::OrdinalIgnoreCase)) { throw 'Unsafe staging path' }
$godot = "$projectPath/build/wechat-toolchain/editor/Godot_v4.6.1-stable_win64_console.exe"
$evidence = "$projectPath/build/verification/tower-polish/staging"
New-Item -ItemType Directory -Force -Path $evidence,"$stage/tests","$stage/tools","$stage/build/verification/phase3/09-refinement/golem","$stage/build/verification/phase3/09-refinement/hero/regression" | Out-Null
$savedAppData = $env:APPDATA
$savedLocalAppData = $env:LOCALAPPDATA
$records = @()
try {
    foreach ($run in @(
        @{Name='tower_polish_capture';Folder='tests';Profile='tower-polish';Render=$true;After=$true},
        @{Name='camp_polish_capture';Folder='tests';Profile='camp-polish';Render=$true},
        @{Name='phase3_v06_hero_regression_phase3_hero_map_test';Folder='tools';Profile='phase3/08-parallel/hero_refine';Render=$true},
        @{Name='phase3_v06_golem_production_test';Folder='tools';Profile='phase3/08-parallel/golem_refine'}
    )) {
        Copy-Item -LiteralPath "$projectPath/$($run.Folder)/$($run.Name).gd" -Destination "$stage/$($run.Folder)/$($run.Name).gd"
        $env:APPDATA = "$evidence/verification/$($run.Profile)/appdata"
        $env:LOCALAPPDATA = "$evidence/verification/$($run.Profile)/localappdata"
        New-Item -ItemType Directory -Force $env:APPDATA,$env:LOCALAPPDATA | Out-Null
        $arguments = @('--headless','--path',$stage,'--script',"res://$($run.Folder)/$($run.Name).gd")
        if ($run.Render) { $arguments = @('--path',$stage,'--rendering-method','gl_compatibility','--position','10000,10000','--script',"res://$($run.Folder)/$($run.Name).gd") }
        if ($run.After) { $arguments += @('--','--after') }
        $log = "$evidence/$($run.Name).log"
        $process = Start-Process -FilePath $godot -ArgumentList $arguments -WindowStyle Hidden -PassThru -RedirectStandardOutput $log -RedirectStandardError "$log.stderr"
        $null = $process.Handle
        if (-not $process.WaitForExit(180000)) { $process.Kill(); throw "Timed out: $($run.Name)" }
        $bad = $process.ExitCode -ne 0 -or (Select-String -LiteralPath $log,"$log.stderr" -Pattern 'SCRIPT ERROR|Parse Error|Compilation failed|FAIL[: ]' -Quiet)
        $errors = @(Get-Content "$log.stderr" | Where-Object { $_ -match '^ERROR:' -and $_ -notmatch 'Failed to read the root certificate store' })
        $records += @{name=$run.Name;exit_code=$process.ExitCode;failed=[bool]$bad;unexpected_errors=$errors;log=$log}
        $records | ConvertTo-Json -Depth 5 | Set-Content "$evidence/results.json" -Encoding utf8
        Get-Content -LiteralPath $log -Tail 1
        if ($bad -or $errors.Count) { throw "Staging validation failed: $log" }
    }
} finally {
    $env:APPDATA = $savedAppData
    $env:LOCALAPPDATA = $savedLocalAppData
}
