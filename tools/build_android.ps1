param(
    [string]$Godot = $(if ($env:GODOT_BIN) { $env:GODOT_BIN } else { 'godot' }),
    [string]$JavaSdk = '',
    [string]$AndroidSdk = ''
)
$ErrorActionPreference = 'Stop'
$projectRoot = (Resolve-Path (Join-Path $PSScriptRoot '..')).Path
$outputRoot = Join-Path $projectRoot 'build/android'
$toolchain = Join-Path $outputRoot 'toolchain'
if (-not $JavaSdk) {
    $JavaSdk = (Get-ChildItem (Join-Path $toolchain 'java') -Directory | Select-Object -First 1).FullName
}
if (-not $AndroidSdk) { $AndroidSdk = Join-Path $toolchain 'sdk' }
$godotCommand = Get-Command -Name $Godot -CommandType Application -ErrorAction SilentlyContinue
if ($godotCommand) { $Godot = $godotCommand.Source }
$keytool = Join-Path $JavaSdk 'bin/keytool.exe'
foreach ($required in @($Godot, $keytool, (Join-Path $AndroidSdk 'platform-tools/adb.exe'), (Join-Path $AndroidSdk 'build-tools/35.0.1/apksigner.bat'), (Join-Path $toolchain 'templates/android_debug.apk'))) {
    if (-not (Test-Path -LiteralPath $required)) { throw "Missing Android build dependency: $required" }
}
$profileRoot = Join-Path $outputRoot 'profile'
$settingsRoot = Join-Path $profileRoot 'Godot'
New-Item -ItemType Directory -Force $settingsRoot | Out-Null
$debugKey = Join-Path $toolchain 'debug.keystore'
if (-not (Test-Path -LiteralPath $debugKey)) {
    & $keytool -genkeypair -keystore $debugKey -storepass android -alias androiddebugkey -keypass android -dname 'CN=Android Debug,O=Android,C=US' -keyalg RSA -keysize 2048 -validity 10000
    if ($LASTEXITCODE -ne 0) { throw 'Could not generate test signing key.' }
}
$javaPath = $JavaSdk.Replace('\', '/')
$sdkPath = $AndroidSdk.Replace('\', '/')
$keyPath = $debugKey.Replace('\', '/')
@"
[gd_resource type="EditorSettings" format=3]

[resource]
export/android/java_sdk_path = "$javaPath"
export/android/android_sdk_path = "$sdkPath"
export/android/debug_keystore = "$keyPath"
export/android/debug_keystore_user = "androiddebugkey"
export/android/debug_keystore_pass = "android"
"@ | Set-Content -Encoding utf8 (Join-Path $settingsRoot 'editor_settings-4.7.tres')

$savedEnv = @{}
foreach ($name in @('APPDATA', 'LOCALAPPDATA', 'JAVA_HOME', 'GODOT_ANDROID_KEYSTORE_DEBUG_PATH', 'GODOT_ANDROID_KEYSTORE_DEBUG_USER', 'GODOT_ANDROID_KEYSTORE_DEBUG_PASSWORD')) {
    $savedEnv[$name] = [Environment]::GetEnvironmentVariable($name, 'Process')
}
try {
    $env:APPDATA = $profileRoot
    $env:LOCALAPPDATA = Join-Path $profileRoot 'local'
    $env:JAVA_HOME = $JavaSdk
    $env:GODOT_ANDROID_KEYSTORE_DEBUG_PATH = $debugKey
    $env:GODOT_ANDROID_KEYSTORE_DEBUG_USER = 'androiddebugkey'
    $env:GODOT_ANDROID_KEYSTORE_DEBUG_PASSWORD = 'android'
    $apk = Join-Path $outputRoot 'TowerRealm-Android.apk'
    & $Godot --headless --path $projectRoot --export-debug Android $apk 2>&1 | Tee-Object -FilePath (Join-Path $outputRoot 'export.log')
    if ($LASTEXITCODE -ne 0) { throw 'Android export failed; see build/android/export.log.' }
    & (Join-Path $AndroidSdk 'build-tools/35.0.1/apksigner.bat') verify --verbose $apk 2>&1 | Tee-Object -FilePath (Join-Path $outputRoot 'signature-verification.txt')
    if ($LASTEXITCODE -ne 0) { throw 'APK signature verification failed.' }
    $apkHash = (Get-FileHash -Algorithm SHA256 $apk).Hash.ToLowerInvariant()
    "$apkHash  TowerRealm-Android.apk" | Set-Content -Encoding ascii (Join-Path $outputRoot 'SHA256.txt')
    Get-Item -LiteralPath $apk | Select-Object FullName,Length
} finally {
    foreach ($name in $savedEnv.Keys) { [Environment]::SetEnvironmentVariable($name, $savedEnv[$name], 'Process') }
}
