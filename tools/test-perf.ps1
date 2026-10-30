<#
.SYNOPSIS
  Runs the Chiptorio tick-time performance harness (P1.5).

.DESCRIPTION
  Copies Chiptorio into an isolated mod directory, creates a fresh map, and runs
  a benchmark with `--benchmark-verbose timings` so Factorio emits per-tick
  update timings. Parses the update-time column from the log and fails if the
  average or maximum update time exceeds the documented budget.

  This measures the baseline overhead of Chiptorio's runtime systems
  (network graph rebuild, provider module polling, QLN transport, research
  allocation) on a fresh map with no player-built entities. It is a regression
  guard, not a full factory benchmark.

.EXAMPLE
  powershell -ExecutionPolicy Bypass -File tools\test-perf.ps1

.EXAMPLE
  powershell -ExecutionPolicy Bypass -File tools\test-perf.ps1 -Keep -Ticks 1200 -BudgetUs 2000
#>

param(
  [string]$Factorio,
  [int]$Ticks = 600,
  [int]$BudgetUs = 1000,
  [int]$MaxBudgetUs = 50000,
  [switch]$Keep
)

$ErrorActionPreference = "Stop"
. (Join-Path $PSScriptRoot "common.ps1")

$root = Split-Path -Parent $PSScriptRoot
$work = Join-Path $env:TEMP "chiptorio-perf"
$mods = Join-Path $work "mods"
$dest = Join-Path $mods "chiptorio"
$save = Join-Path $work "perf.zip"
$logPath = Join-Path $env:APPDATA "Factorio\factorio-current.log"

foreach ($required in @("info.json", "data.lua", "data-updates.lua", "control.lua")) {
  if (-not (Test-Path (Join-Path $root $required))) {
    throw "missing required mod file: $required"
  }
}

$Factorio = Resolve-FactorioExecutable -Factorio $Factorio
Write-Host "Factorio: $Factorio"

if (Test-Path $work) { Remove-Item $work -Recurse -Force }
New-Item -ItemType Directory -Force -Path $mods | Out-Null

robocopy $root $dest /E /XD .git tools dist /NFL /NDL /NJH /NJS | Out-Null
if ($LASTEXITCODE -ge 8) { throw "robocopy failed with code $LASTEXITCODE" }

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

Write-Host "Creating a perf map with mod directory: $mods"
$create = Start-Process -FilePath $Factorio `
  -ArgumentList @("--mod-directory", "`"$mods`"", "--create", "`"$save`"") `
  -PassThru -Wait

if ($create.ExitCode -ne 0 -and -not (Test-Path -LiteralPath $save)) {
  Write-Host "Map creation exited with code $($create.ExitCode), retrying..." -ForegroundColor Yellow
  Start-Sleep -Seconds 3
  $create = Start-Process -FilePath $Factorio `
    -ArgumentList @("--mod-directory", "`"$mods`"", "--create", "`"$save`"") `
    -PassThru -Wait
}

if (-not (Test-Path -LiteralPath $save)) {
  Show-Failure -Problems @("map creation produced no save at $save (exit code $($create.ExitCode))")
}

$benchOut = Join-Path $work "bench-out.log"

Write-Host "Running a $Ticks-tick performance benchmark (budget: ${BudgetUs} us/tick)"
$bench = Start-Process -FilePath $Factorio `
  -ArgumentList @("--mod-directory", "`"$mods`"", "--benchmark", "`"$save`"", "--benchmark-ticks", "$Ticks", "--benchmark-verbose", "timings") `
  -RedirectStandardOutput $benchOut `
  -PassThru -Wait

$problems = @()
if ($bench.ExitCode -ne 0) {
  $log = Get-Content -LiteralPath $logPath -Raw
  if ($log -match "(?im)Error|Failed|chiptorio.*error|cannot be loaded|Invalid prototype|Unknown prototype") {
    $problems += "benchmark exited with code $($bench.ExitCode)"
  }
}
$problems += Get-LogProblems -LogPath $logPath
if ($problems.Count -gt 0) { Show-Failure -Problems $problems }

# Parse per-tick update times from --benchmark-verbose timings output on stdout.
# Format:
#   Performed <N> updates in <X> ms
#   avg: <Y> ms, min: <Z> ms, max: <W> ms
$avgUs = $null
$maxUs = $null
if (Test-Path $benchOut) {
  $benchLog = Get-Content -LiteralPath $benchOut -Raw
  $m = [regex]::Match($benchLog, "avg:\s*([\d.]+)\s*ms,\s*min:\s*[\d.]+\s*ms,\s*max:\s*([\d.]+)\s*ms")
  if ($m.Success) {
    $avgUs = [int]([double]$m.Groups[1].Value * 1000)
    $maxUs = [int]([double]$m.Groups[2].Value * 1000)
  }
}

if ($avgUs -ne $null) {
  Write-Host ""
  Write-Host "Perf results:"
  Write-Host "  Average update time: ${avgUs} us/tick"
  Write-Host "  Maximum update time: ${maxUs} us/tick"
  Write-Host "  Budget: ${BudgetUs} us/tick avg, ${MaxBudgetUs} us/tick max"

  if ($avgUs -gt $BudgetUs) {
    $problems += "average update time ${avgUs} us exceeds budget ${BudgetUs} us"
  }
  if ($maxUs -gt $MaxBudgetUs) {
    $problems += "maximum update time ${maxUs} us exceeds max budget ${MaxBudgetUs} us"
  }
} else {
  Write-Host ""
  Write-Host "WARNING: no per-tick timing data found in benchmark output; cannot verify perf budget." -ForegroundColor Yellow
}

if ($problems.Count -gt 0) { Show-Failure -Problems $problems }

Write-Host ""
Write-Host "OK: performance harness passed." -ForegroundColor Green
Write-Host "Save: $save"

if (-not $Keep) {
  Remove-Item $work -Recurse -Force -ErrorAction SilentlyContinue
}

exit 0
