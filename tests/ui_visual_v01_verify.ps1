param([switch]$SkipRegression)
$ErrorActionPreference = 'Stop'
$projectRoot = (Resolve-Path (Join-Path $PSScriptRoot '..')).Path
$verificationRoot = Join-Path $projectRoot 'build/verification/ui_visual_v01'
$enginePath = $(if ($env:GODOT_BIN) { $env:GODOT_BIN } else { 'godot' })
$previousAppData = $env:APPDATA
$previousLocalAppData = $env:LOCALAPPDATA

function Set-Isolation([string]$folder) {
    $env:APPDATA = Join-Path $folder 'appdata'
    $env:LOCALAPPDATA = Join-Path $folder 'localappdata'
    New-Item -ItemType Directory -Force $env:APPDATA,$env:LOCALAPPDATA | Out-Null
}

function Invoke-Verification([string]$name, [string[]]$engineArguments) {
    $stdout = Join-Path $verificationRoot "logs/$name.log"
    $stderr = Join-Path $verificationRoot "logs/$name.stderr.log"
    $process = Start-Process -FilePath $enginePath -ArgumentList $engineArguments -WorkingDirectory $projectRoot -WindowStyle Hidden -PassThru -RedirectStandardOutput $stdout -RedirectStandardError $stderr
    if (-not $process.WaitForExit(60000)) {
        Stop-Process -Id $process.Id
        throw "$name timed out; only this verification process was stopped."
    }
    $process.Refresh()
    Get-Content -LiteralPath $stdout -Tail 2
    if ($process.ExitCode -ne 0 -or (Select-String -LiteralPath $stderr -Pattern 'SCRIPT ERROR|Parse Error|FAIL:' -Quiet)) {
        Get-Content -LiteralPath $stderr -Tail 30
        throw "$name failed (exit $($process.ExitCode))."
    }
}

try {
    New-Item -ItemType Directory -Force (Join-Path $verificationRoot 'logs') | Out-Null
    New-Item -ItemType File -Force (Join-Path $verificationRoot '.gdignore') | Out-Null
    Set-Isolation $verificationRoot
    Invoke-Verification 'import-final' @('--headless','--path','.', '--editor','--import')
    if (-not $SkipRegression) {
        foreach ($suite in @('combat','map','random_map','keys','monster_ui','reward','reward_ui')) {
            Set-Isolation (Join-Path $verificationRoot "regression/$suite")
            Invoke-Verification $suite @('--headless','--path','.', '--script',"tests/${suite}_test_runner.gd")
        }
    }
    Set-Isolation $verificationRoot
    Invoke-Verification 'headless-final' @('--headless','--path','.', '--script','tests/ui_visual_v01_runner.gd')
    Invoke-Verification 'visual-final' @('--path','.', '--rendering-method','gl_compatibility','--position=-2000,-2000','--script','tests/ui_visual_v01_runner.gd','--','--capture')
    # Preserve the independent review's required /build/verification/m1_review/ suffix.
    # The whole subtree and overridden evidence path still belong to this batch.
    Set-Isolation (Join-Path $verificationRoot 'build/verification/m1_review')
    foreach ($phase in @('review','write','read')) {
        $reviewArguments = @('--path','.', '--rendering-method','gl_compatibility','--position=-2000,-2000','--script','tests/ui_visual_v01_review_runner.gd')
        if ($phase -ne 'review') { $reviewArguments += @('--',"--$phase-saves") }
        Invoke-Verification "review-$phase-final" $reviewArguments
    }
} finally {
    $env:APPDATA = $previousAppData
    $env:LOCALAPPDATA = $previousLocalAppData
}
