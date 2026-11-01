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
  $log = Get-Content -LiteralPath $LogPath -Raw
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
    foreach ($hit in $m) {
      if ($hit.Value -match "CHIPTORIO-TEST INFO") { continue }
      $found += $hit.Value.Trim()
    }
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

# --- Create a save with mods directly ---
Write-Host "Creating save with mods"
Remove-Item $save -ErrorAction SilentlyContinue
$create = Start-Process -FilePath $Factorio `
  -ArgumentList @("--mod-directory", "`"$mods`"", "--create", "`"$save`"") `
  -PassThru -Wait
if ($create.ExitCode -ne 0 -and -not (Test-Path -LiteralPath $save)) {
  throw "Map creation failed with exit code $($create.ExitCode)"
}
if (-not (Test-Path $save)) {
  throw "Save was not created at $save"
}
Write-Host "Save created: $save"

# --- Run the benchmark with mods ---
Write-Host "Running a $Ticks-tick contract benchmark"
$bench = Start-Process -FilePath $Factorio `
  -ArgumentList @("--mod-directory", "`"$mods`"", "--benchmark", "`"$save`"", "--benchmark-ticks", "$Ticks") `
  -PassThru -Wait

$problems = @()
if ($bench.ExitCode -ne 0) {
  $log = Get-Content -LiteralPath $logPath -Raw
  if ($log -match "(?im)Error|Failed|chiptorio.*error|cannot be loaded|Invalid prototype|Unknown prototype") {
    $problems += "benchmark exited with code $($bench.ExitCode)"
  }
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
  if ($log -notmatch "CHIPTORIO-TEST PASS force-isolation") {
    $problems += "force-isolation probe did not log PASS"
  }
  if ($log -notmatch "CHIPTORIO-TEST PASS playthrough") {
    $problems += "playthrough probe did not log PASS"
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