<#
.SYNOPSIS
  Runs every headless Chiptorio verification step.

.DESCRIPTION
  First runs the smoke test (load, map creation, benchmark), then runs the
  contract probe (data assertions plus runtime checks on the fresh map).
  Any failure exits non-zero.

.EXAMPLE
  powershell -ExecutionPolicy Bypass -File tools\test-all.ps1

.EXAMPLE
  powershell -ExecutionPolicy Bypass -File tools\test-all.ps1 -Keep -Ticks 600
#>

param(
  [string]$Factorio,
  [int]$Ticks = 600,
  [switch]$Keep
)

$ErrorActionPreference = "Stop"

$smoke = Join-Path $PSScriptRoot "test-mod.ps1"
$contract = Join-Path $PSScriptRoot "test-contract.ps1"
$common = @{}
if ($Factorio) { $common["Factorio"] = $Factorio }
if ($Ticks) { $common["Ticks"] = $Ticks }
if ($Keep) { $common["Keep"] = $true }

Write-Host "=== Chiptorio smoke test ===" -ForegroundColor Cyan
& $smoke @common
if ($LASTEXITCODE -ne 0) {
  Write-Host "Smoke test failed; skipping the contract probe." -ForegroundColor Red
  exit $LASTEXITCODE
}

Write-Host ""
Write-Host "=== Chiptorio contract probe ===" -ForegroundColor Cyan
& $contract @common
if ($LASTEXITCODE -ne 0) {
  exit $LASTEXITCODE
}

Write-Host ""
Write-Host "All Chiptorio checks passed." -ForegroundColor Green
