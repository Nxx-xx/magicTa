param(
    [Parameter(Mandatory=$true)][ValidatePattern('^[a-z0-9][a-z0-9_-]*$')][string]$Group,
    [Parameter(Mandatory=$true)][string[]]$GodotArgs,
    [ValidatePattern('^[a-zA-Z0-9][a-zA-Z0-9_.-]*$')][string]$Label = 'godot',
    [int]$LockTimeoutSeconds = 1800,
    [int]$RunTimeoutSeconds = 900
)
$ErrorActionPreference = 'Stop'
$projectPath = [IO.Path]::GetFullPath((Join-Path $PSScriptRoot '..'))
$evidencePath = Join-Path $projectPath "build/verification/ruins-polish"
New-Item -ItemType Directory -Force -Path $evidencePath | Out-Null
$mutex = [Threading.Mutex]::new($false, 'MagicTa_Phase3_Parallel_Godot')
$acquired = $false
$previousAppData = $env:APPDATA
$previousLocalAppData = $env:LOCALAPPDATA
$exitCode = 1
try {
    Write-Host "Waiting for MagicTa Godot lock: $Group / $Label"
    try { $acquired = $mutex.WaitOne([TimeSpan]::FromSeconds($LockTimeoutSeconds)) }
    catch [Threading.AbandonedMutexException] { $acquired = $true }
    if (-not $acquired) { throw 'Timed out waiting for shared Godot import/bake/test mutex' }
    $env:APPDATA = Join-Path $evidencePath 'appdata'
    $env:LOCALAPPDATA = Join-Path $evidencePath 'localappdata'
    New-Item -ItemType Directory -Force -Path $env:APPDATA,$env:LOCALAPPDATA | Out-Null
    $stamp = Get-Date -Format 'yyyyMMdd-HHmmss-fff'
    $logPath = Join-Path $evidencePath "$Label-$stamp.log"
    $started = [DateTime]::UtcNow
    $arguments = @('--path', $projectPath) + $GodotArgs
    if ($GodotArgs -contains 'res://tools/phase3_rig_bake.gd') {
        if ($GodotArgs -notcontains '--') { $arguments += '--' }
        $arguments += "--output=res://build/verification/ruins-polish$Group/"
    }
    # Launch without an interactive console. The environment belongs only to this invocation.
    $processInfo = [Diagnostics.ProcessStartInfo]::new()
    $processInfo.FileName = $(if ($env:GODOT_BIN) { $env:GODOT_BIN } else { 'godot' })
    $processInfo.WorkingDirectory = $projectPath
    $processInfo.UseShellExecute = $false
    $processInfo.CreateNoWindow = $true
    $processInfo.RedirectStandardOutput = $true
    $processInfo.RedirectStandardError = $true
    foreach ($argument in $arguments) { $processInfo.ArgumentList.Add($argument) }
    $process = [Diagnostics.Process]::new()
    $process.StartInfo = $processInfo
    if (-not $process.Start()) { throw 'Could not launch Godot' }
    [ordered]@{group=$Group; label=$Label; process_id=$process.Id; started_utc=$started.ToString('o'); arguments=$arguments} | ConvertTo-Json -Depth 5 | Set-Content -LiteralPath (Join-Path $evidencePath "$Label-$stamp-started.json") -Encoding utf8
    $stdout = $process.StandardOutput.ReadToEndAsync()
    $stderr = $process.StandardError.ReadToEndAsync()
    $timedOut = -not $process.WaitForExit($RunTimeoutSeconds*1000)
    if ($timedOut) {
        $process.Kill($true)
        $process.WaitForExit()
    }
    $exitCode = $process.ExitCode
    $outputText = $stdout.GetAwaiter().GetResult() + "`n" + $stderr.GetAwaiter().GetResult()
    $process.Dispose()
    [IO.File]::WriteAllText($logPath, $outputText)
    $copiedReviews = @()
    foreach ($relative in @('06-animation-balance','07-completion',"08-parallel/$Group")) {
        $sharedReview = Join-Path $projectPath "build/verification/phase3/$relative/rig-review.json"
        if ((Test-Path -LiteralPath $sharedReview) -and (Get-Item -LiteralPath $sharedReview).LastWriteTimeUtc -ge $started) {
            $reviewKind = $relative.Replace('/', '-')
            $destination = Join-Path $evidencePath "$Label-$stamp-$reviewKind-rig-review.json"
            Copy-Item -LiteralPath $sharedReview -Destination $destination
            $copiedReviews += $destination
        }
    }
    $scriptError = $outputText -match 'SCRIPT ERROR|Parse Error|Compilation failed|FAIL '
    $engineError = [bool]($outputText.Replace("`r",'').Split("`n") | Where-Object { $_ -match '^ERROR:' -and $_ -notmatch '^ERROR: Failed to read the root certificate store\.$' })
    [ordered]@{group=$Group; label=$Label; arguments=$arguments; started_utc=$started.ToString('o'); exit_code=$exitCode; script_error=$scriptError; engine_error=$engineError; timed_out=$timedOut; log=$logPath; copied_reviews=$copiedReviews; appdata=$env:APPDATA; localappdata=$env:LOCALAPPDATA} | ConvertTo-Json -Depth 5 | Set-Content -LiteralPath (Join-Path $evidencePath "$Label-$stamp-result.json") -Encoding utf8
    Write-Host ($outputText.TrimEnd().Split("`n") | Select-Object -Last 5 | Out-String)
    Write-Host "Godot evidence: $logPath"
    if ($exitCode -ne 0 -or $scriptError -or $engineError -or $timedOut) { throw "Godot failed ($exitCode; script_error=$scriptError; engine_error=$engineError; timed_out=$timedOut): $logPath" }
} finally {
    $env:APPDATA = $previousAppData
    $env:LOCALAPPDATA = $previousLocalAppData
    if ($acquired) { $mutex.ReleaseMutex() }
    $mutex.Dispose()
}
