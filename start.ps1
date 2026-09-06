#!/usr/bin/env pwsh
# SwasthyaSetu AI - Quick Start Script
# Run in PowerShell as Administrator from C:\nvdia

Set-Location "C:\nvdia"

Write-Host "============================================" -ForegroundColor Cyan
Write-Host "  SwasthyaSetu AI - Quick Start" -ForegroundColor Cyan
Write-Host "============================================" -ForegroundColor Cyan

# --- Backend ---
Write-Host "`n[1/3] Starting Backend..." -ForegroundColor Yellow
Set-Location "C:\nvdia\backend"

if (-not (Test-Path ".env")) {
    Copy-Item ".env.example" ".env"
    Write-Host "  Created .env from example - EDIT IT with your settings!" -ForegroundColor Red
}

if (-not (Test-Path "venv")) {
    Write-Host "  Creating virtual environment..." -ForegroundColor Yellow
    python -m venv venv
}

Write-Host "  Installing dependencies..." -ForegroundColor Yellow
& ".\venv\Scripts\pip.exe" install -r requirements.txt -q

Write-Host "  Running migrations..." -ForegroundColor Yellow
& ".\venv\Scripts\python.exe" -m alembic upgrade head

Write-Host "  Starting FastAPI on http://localhost:8000" -ForegroundColor Green
$backendProc = Start-Process -FilePath ".\venv\Scripts\uvicorn.exe" `
    -ArgumentList "app.main:app", "--reload", "--host", "0.0.0.0", "--port", "8000" `
    -WorkingDirectory "C:\nvdia\backend" `
    -PassThru

# --- Flutter App ---
Write-Host "`n[2/3] Starting Flutter App (Demo Mode)..." -ForegroundColor Yellow
Set-Location "C:\nvdia\app"

Write-Host "  Getting packages..." -ForegroundColor Yellow
flutter pub get

Write-Host "  Running on Chrome (web) / Android emulator..." -ForegroundColor Green
$flutterProc = Start-Process -FilePath "flutter" `
    -ArgumentList "run", "--dart-define=DEMO_MODE=true", "-d", "chrome" `
    -WorkingDirectory "C:\nvdia\app" `
    -PassThru

# --- Summary ---
Write-Host "`n============================================" -ForegroundColor Cyan
Write-Host "  RUNNING" -ForegroundColor Green
Write-Host "============================================" -ForegroundColor Cyan
Write-Host "Backend API:    http://localhost:8000" -ForegroundColor Cyan
Write-Host "API Docs:       http://localhost:8000/docs" -ForegroundColor Cyan
Write-Host "Flutter App:    Running in Chrome (demo mode)" -ForegroundColor Cyan
Write-Host "" -ForegroundColor Cyan
Write-Host "Press Ctrl+C to stop both processes" -ForegroundColor Yellow

# Wait for exit
try {
    Wait-Process -Id $backendProc.Id, $flutterProc.Id -ErrorAction SilentlyContinue
}
catch {
    Stop-Process -Id $backendProc.Id -Force -ErrorAction SilentlyContinue
    Stop-Process -Id $flutterProc.Id -Force -ErrorAction SilentlyContinue
}