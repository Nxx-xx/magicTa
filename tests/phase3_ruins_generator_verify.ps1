$ErrorActionPreference = 'Stop'
$projectDir = [IO.Path]::GetFullPath((Join-Path $PSScriptRoot '..'))
$evidenceDir = Join-Path $projectDir 'build/verification/phase3/02-ruins'
New-Item -ItemType Directory -Force -Path $evidenceDir, (Join-Path $evidenceDir 'generator-appdata'), (Join-Path $evidenceDir 'generator-localappdata') | Out-Null
$oldAppData = $env:APPDATA
$oldLocalAppData = $env:LOCALAPPDATA
try {
    $env:APPDATA = Join-Path $evidenceDir 'generator-appdata'
    $env:LOCALAPPDATA = Join-Path $evidenceDir 'generator-localappdata'
    $ErrorActionPreference = 'Continue'
    $logPath = Join-Path $evidenceDir 'generator-tests.log'
    & $(if ($env:GODOT_BIN) { $env:GODOT_BIN } else { 'godot' }) --headless --path $projectDir --script res://tests/phase3_ruins_generator_test_runner.gd 2>&1 | Tee-Object $logPath
    $resultCode = $LASTEXITCODE
    $ErrorActionPreference = 'Stop'
    if ($resultCode -ne 0 -or (Select-String -LiteralPath $logPath -Pattern 'SCRIPT ERROR|Parse Error|Compilation failed' -Quiet)) { throw "Generator verification failed; see $logPath" }
} finally {
    $env:APPDATA = $oldAppData
    $env:LOCALAPPDATA = $oldLocalAppData
}
