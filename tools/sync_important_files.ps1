<#
.SYNOPSIS
    Syncs critical project files into the 'Important Files' folder for AI context indexing.
.DESCRIPTION
    Replaces error-prone manual copying with a declarative, canonical file list.
    Preserves relative subfolder hierarchy and ensures zero drift across lib, test, firmware, and docs.
#>

$ErrorActionPreference = 'Stop'

$rootDir = Split-Path -Parent $PSScriptRoot
$destRoot = Join-Path $rootDir "Important Files"

if (-not (Test-Path $destRoot)) {
    New-Item -ItemType Directory -Path $destRoot -Force | Out-Null
}

# Canonical list of important files relative to repository root
$canonicalFiles = @(
    "GEMINI.md",
    "README.md",
    "NEXT_PHASE_GUIDELINES.md",
    "pubspec.yaml",
    "validation/VALIDATION.md",
    "validation/hr_spo2_temp_validation.csv",
    "lib/domain/rules/risk_engine.dart",
    "lib/core/services/edge_ai_service.dart",
    "lib/core/services/community_sync_service.dart",
    "lib/core/services/qnn_service.dart",
    "lib/core/services/ble_service.dart",
    "lib/features/screening/screens/triage_result_screen.dart",
    "lib/features/screening/widgets/clarke_error_grid_widget.dart",
    "lib/features/screening/widgets/poincare_plot_widget.dart",
    "lib/features/screening/widgets/trust_provenance_sheet.dart",
    "test/risk_engine_invariant_test.dart",
    "test/edge_ai_service_test.dart",
    "test/community_sync_privacy_test.dart",
    "tools/train_ecg_autoencoder.py",
    "assets/models/ecg_autoencoder_weights.json",
    "firmware/SSAI_SENSE_final/dsp_pure.h",
    "firmware/SSAI_SENSE_final/SSAI_SENSE_final.ino"
)

Write-Host "Syncing $($canonicalFiles.Count) important files to '$destRoot'..." -ForegroundColor Cyan

$syncedCount = 0
foreach ($relPath in $canonicalFiles) {
    $srcPath = Join-Path $rootDir $relPath
    if (Test-Path $srcPath) {
        $targetFile = Join-Path $destRoot $relPath
        $targetDir = Split-Path -Parent $targetFile
        if (-not (Test-Path $targetDir)) {
            New-Item -ItemType Directory -Path $targetDir -Force | Out-Null
        }
        Copy-Item -Path $srcPath -Destination $targetFile -Force
        $syncedCount++
    } else {
        Write-Warning "Source file not found: $srcPath"
    }
}

Write-Host "Successfully synchronized $syncedCount files to '$destRoot'." -ForegroundColor Green
