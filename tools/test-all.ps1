<#
.SYNOPSIS
  Runs every headless Chiptorio verification step.

.DESCRIPTION
  First runs the smoke test (load, map creation, benchmark), then runs the
  contract probe (data assertions plus runtime checks on the fresh map), then
  runs the save/load probe (hosts a save, writes runtime state, reloads it),
  then runs the power-grid probe (hosts a map on a live server because a
  benchmark cannot dispatch tick handlers after tick 0), then runs the static
  registration audit (P1.8), then runs the performance harness (P1.5).
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
$saveLoad = Join-Path $PSScriptRoot "test-save-load.ps1"
$powerGrid = Join-Path $PSScriptRoot "test-power-grid.ps1"
$registration = Join-Path $PSScriptRoot "test-registration.ps1"
$perf = Join-Path $PSScriptRoot "test-perf.ps1"
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
  Write-Host "Contract probe failed; skipping the save/load probe." -ForegroundColor Red
  exit $LASTEXITCODE
}

Write-Host ""
Write-Host "=== Chiptorio registration audit ===" -ForegroundColor Cyan
& $registration
if ($LASTEXITCODE -ne 0) {
  exit $LASTEXITCODE
}

Write-Host ""
Write-Host "=== Chiptorio save/load probe ===" -ForegroundColor Cyan
& $saveLoad @common
if ($LASTEXITCODE -ne 0) {
  exit $LASTEXITCODE
}

Write-Host ""
Write-Host "=== Chiptorio power-grid probe ===" -ForegroundColor Cyan
& $powerGrid @common
if ($LASTEXITCODE -ne 0) {
  exit $LASTEXITCODE
}

Write-Host ""
Write-Host "=== Chiptorio performance harness ===" -ForegroundColor Cyan
& $perf @common
if ($LASTEXITCODE -ne 0) {
  exit $LASTEXITCODE
}

Write-Host ""
Write-Host "All Chiptorio checks passed." -ForegroundColor Green
