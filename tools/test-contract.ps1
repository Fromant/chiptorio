<#
.SYNOPSIS
  Runs the Chiptorio data-contract and runtime probe.

.DESCRIPTION
  Copies chiptorio and the test probe into an isolated mod directory, creates a
  map, runs a short benchmark, and requires the unit, data and runtime probe
  suites to log PASS. The probe is a separate mod so it runs after every
  chiptorio prototype and data-updates mutation.

.EXAMPLE
  powershell -ExecutionPolicy Bypass -File tools\test-contract.ps1

.EXAMPLE
  powershell -ExecutionPolicy Bypass -File tools\test-contract.ps1 -Keep -Ticks 600
#>

param(
  [string]$Factorio,
  [int]$Ticks = 300,
  [switch]$Keep
)

$ErrorActionPreference = "Stop"
. (Join-Path $PSScriptRoot "common.ps1")

$root = Split-Path -Parent $PSScriptRoot
$probe = Join-Path $PSScriptRoot "test-probe"
$work = Join-Path $env:TEMP "chiptorio-contract"
$mods = Join-Path $work "mods"
$dest = Join-Path $mods "chiptorio"
$probeDest = Join-Path $mods "chiptorio-test-probe"
$save = Join-Path $work "contract.zip"
$logPath = Join-Path $env:APPDATA "Factorio\factorio-current.log"

if ($Ticks % 60 -ne 0) {
  throw "-Ticks must be a multiple of 60 so the runtime probe runs."
}

foreach ($required in @("info.json", "data.lua", "data-updates.lua", "control.lua")) {
  if (-not (Test-Path (Join-Path $root $required))) {
    throw "missing required mod file: $required"
  }
}
foreach ($required in @("info.json", "data.lua", "control.lua")) {
  if (-not (Test-Path (Join-Path $probe $required))) {
    throw "missing probe file: tools\test-probe\$required"
  }
}

$Factorio = Resolve-FactorioExecutable -Factorio $Factorio
Write-Host "Factorio: $Factorio"

if (Test-Path $work) { Remove-Item $work -Recurse -Force }
New-Item -ItemType Directory -Force -Path $mods | Out-Null

robocopy $root $dest /E /XD .git tools dist /NFL /NDL /NJH /NJS | Out-Null
if ($LASTEXITCODE -ge 8) { throw "robocopy failed with code $LASTEXITCODE" }
New-Item -ItemType Directory -Force -Path $probeDest | Out-Null
robocopy $probe $probeDest /E /NFL /NDL /NJH /NJS | Out-Null
if ($LASTEXITCODE -ge 8) { throw "probe robocopy failed with code $LASTEXITCODE" }

function Get-LogProblems {
  param([string]$LogPath)
  if (-not (Test-Path $LogPath)) { return @("No Factorio log at $LogPath") }
  $log = Get-Content $LogPath -Raw
  $found = @()
  $patterns = @(
    "Error while running",
    "Failed to load mod",
    "Unknown prototype",
    "Invalid prototype",
    "CHIPTORIO-TEST FAIL",
    "chiptorio.*error",
    "cannot be loaded"
  )
  foreach ($p in $patterns) {
    $m = [regex]::Matches($log, "(?im)^.*$p.*$")
    foreach ($hit in $m) { $found += $hit.Value.Trim() }
  }
  return $found
}

function Show-Failure {
  param([string[]]$Problems)
  Write-Host ""
  Write-Host "FAILED" -ForegroundColor Red
  $Problems | Select-Object -Unique | ForEach-Object { Write-Host "  $_" -ForegroundColor Red }
  Write-Host ""
  Write-Host "Full log: $logPath"
  if (-not $Keep) {
    Remove-Item $work -Recurse -Force -ErrorAction SilentlyContinue
  }
  exit 1
}

Write-Host "Creating a contract map with mod directory: $mods"
$create = Start-Process -FilePath $Factorio `
  -ArgumentList @("--mod-directory", "`"$mods`"", "--create", "`"$save`"") `
  -PassThru -Wait

$problems = @()
if ($create.ExitCode -ne 0) {
  $problems += "map creation exited with code $($create.ExitCode)"
}
$problems += Get-LogProblems -LogPath $logPath
if ($problems.Count -gt 0) { Show-Failure -Problems $problems }

if (-not (Test-Path $save)) {
  Show-Failure -Problems @("map creation produced no save at $save")
}

Write-Host "Running a $Ticks-tick contract benchmark"
$bench = Start-Process -FilePath $Factorio `
  -ArgumentList @("--mod-directory", "`"$mods`"", "--benchmark", "`"$save`"", "--benchmark-ticks", "$Ticks") `
  -PassThru -Wait

$problems = @()
if ($bench.ExitCode -ne 0) {
  $problems += "benchmark exited with code $($bench.ExitCode)"
}
$problems += Get-LogProblems -LogPath $logPath

if (Test-Path $logPath) {
  $log = Get-Content $logPath -Raw
  if ($log -notmatch "CHIPTORIO-TEST PASS unit") {
    $problems += "unit probe did not log PASS"
  }
  if ($log -notmatch "CHIPTORIO-TEST PASS data") {
    $problems += "data probe did not log PASS"
  }
  if ($log -notmatch "CHIPTORIO-TEST PASS runtime") {
    $problems += "runtime probe did not log PASS"
  }
}

if ($problems.Count -gt 0) { Show-Failure -Problems $problems }

Write-Host ""
Write-Host "OK: data contract and runtime probe passed." -ForegroundColor Green
Write-Host "Save: $save"

if (-not $Keep) {
  Remove-Item $work -Recurse -Force -ErrorAction SilentlyContinue
}

exit 0
