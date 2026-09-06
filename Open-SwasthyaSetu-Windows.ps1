$ErrorActionPreference = "Stop"

$exe = "C:\nvdia\app\build\windows\x64\runner\Release\swasthyasetu_ai.exe"

if (-not (Test-Path -LiteralPath $exe)) {
    Push-Location "C:\nvdia\app"
    try {
        & "C:\nvdia\flutter\bin\flutter.bat" build windows --release
    }
    finally {
        Pop-Location
    }
}

Start-Process -FilePath $exe -WorkingDirectory (Split-Path -Parent $exe)
