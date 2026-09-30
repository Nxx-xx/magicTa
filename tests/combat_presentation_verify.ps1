param([Parameter(Mandatory=$true)][string]$GodotPath, [switch]$Capture)
$ErrorActionPreference = 'Stop'
$projectRoot = (Resolve-Path (Join-Path $PSScriptRoot '..')).Path
$verificationRoot = Join-Path $projectRoot 'build/verification/combat-presentation'
$previousAppData = $env:APPDATA
$previousLocalAppData = $env:LOCALAPPDATA
try {
    New-Item -ItemType Directory -Force "$verificationRoot/appdata", "$verificationRoot/localappdata" | Out-Null
    New-Item -ItemType File -Force "$verificationRoot/.gdignore" | Out-Null
    $env:APPDATA = "$verificationRoot/appdata"
    $env:LOCALAPPDATA = "$verificationRoot/localappdata"
    $engineArguments = @('--path', $projectRoot, '--script', 'tests/combat_presentation_test_runner.gd')
    if ($Capture) {
        $engineArguments += @('--rendering-method', 'gl_compatibility', '--position=-2000,-2000', '--', '--capture')
    } else {
        $engineArguments += '--headless'
    }
    $log = Join-Path $verificationRoot $(if ($Capture) { 'visual.log' } else { 'headless.log' })
    & $GodotPath @engineArguments *> $log
    $engineExitCode = $LASTEXITCODE
    Get-Content -LiteralPath $log -Tail 8
    if ($engineExitCode -ne 0 -or (Select-String -LiteralPath $log -Pattern 'SCRIPT ERROR|Parse Error|FAIL:' -Quiet)) {
        throw "Combat presentation verification failed; see $log"
    }
} finally {
    $env:APPDATA = $previousAppData
    $env:LOCALAPPDATA = $previousLocalAppData
}
