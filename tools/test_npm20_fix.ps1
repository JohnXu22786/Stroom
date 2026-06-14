<#
.SYNOPSIS
    Validate that the NPM 20 deprecation warning fix is correctly applied
    to Release build GitHub Actions workflow files.

.DESCRIPTION
    Checks that FORCE_JAVASCRIPT_ACTIONS_TO_NODE24: true is present in the
    env section of release.yml and build.yml (Release build workflows).
#>

$ErrorActionPreference = "Stop"

$workflowsPath = Resolve-Path (Join-Path (Join-Path (Split-Path $PSScriptRoot -Parent) ".github") "workflows")

$files = @(
    "release.yml",
    "build.yml"
)

$failed = $false
$expectedKey = "FORCE_JAVASCRIPT_ACTIONS_TO_NODE24"
$expectedValue = "true"

Write-Host "=== NPM 20 Deprecation Warning Fix Validation ===" -ForegroundColor Cyan
Write-Host ""

foreach ($file in $files) {
    $filePath = Join-Path $workflowsPath $file
    if (-not (Test-Path $filePath)) {
        Write-Host "[FAIL] $file - File not found!" -ForegroundColor Red
        $failed = $true
        continue
    }

    $content = Get-Content $filePath -Raw
    $lines = Get-Content $filePath

    # Check 1: File exists and has content
    if ([string]::IsNullOrWhiteSpace($content)) {
        Write-Host "[FAIL] $file - File is empty!" -ForegroundColor Red
        $failed = $true
        continue
    }

    # Check 2: env section exists
    $envSectionFound = $false
    $envKeyFound = $false
    $envKeyLine = ""

    for ($i = 0; $i -lt $lines.Count; $i++) {
        $line = $lines[$i].Trim()
        if ($line -eq "env:") {
            $envSectionFound = $true
        }
        if ($envSectionFound -and $line -match "${expectedKey}:\s*${expectedValue}") {
            $envKeyFound = $true
            $envKeyLine = "Line $($i+1): $($lines[$i])"
        }
    }

    if (-not $envSectionFound) {
        Write-Host "[FAIL] $file - No 'env:' section found!" -ForegroundColor Red
        $failed = $true
        continue
    }

    if ($envKeyFound) {
        Write-Host "[PASS] $file - ${expectedKey}: ${expectedValue} found at ${envKeyLine}" -ForegroundColor Green
    } else {
        Write-Host "[FAIL] $file - ${expectedKey}: ${expectedValue} NOT found in env section!" -ForegroundColor Red
        $failed = $true
    }
}

Write-Host ""
if ($failed) {
    Write-Host "=== VALIDATION FAILED ===" -ForegroundColor Red
    exit 1
} else {
    Write-Host "=== ALL CHECKS PASSED ===" -ForegroundColor Green
    exit 0
}
