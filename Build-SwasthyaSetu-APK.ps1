$ErrorActionPreference = "Stop"

if (-not $env:ANDROID_HOME -and -not $env:ANDROID_SDK_ROOT) {
    $defaultSdk = "C:\Users\krish\AppData\Local\Android\Sdk"
    if (Test-Path -LiteralPath $defaultSdk) {
        $env:ANDROID_HOME = $defaultSdk
        $env:ANDROID_SDK_ROOT = $defaultSdk
    }
}

if (-not $env:ANDROID_HOME -and -not $env:ANDROID_SDK_ROOT) {
    throw "Android SDK is not installed or configured. Install Android Studio or command-line tools, then set ANDROID_HOME to the SDK path."
}

Push-Location "C:\nvdia\app"
try {
    & "C:\nvdia\flutter\bin\flutter.bat" build apk --debug
    Write-Host "APK ready: C:\nvdia\app\build\app\outputs\flutter-apk\app-debug.apk"
}
finally {
    Pop-Location
}
