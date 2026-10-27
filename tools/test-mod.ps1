<#
.SYNOPSIS
  Loads Chiptorio headlessly, creates a map, and runs a short benchmark.

.DESCRIPTION
  Copies the mod into an isolated mod directory, asks Factorio to generate a
  map with it enabled, then runs the save for a few hundred ticks so runtime
  code is exercised too. Finally scans factorio-current.log for errors.

  This is the fastest way to catch prototype and control-stage mistakes without
  clicking through the menu.

  The Factorio executable is resolved from -Factorio, the FACTORIO_EXE
  environment variable, .env, or common Steam install locations.

.EXAMPLE
  powershell -ExecutionPolicy Bypass -File tools\test-mod.ps1

.EXAMPLE
  powershell -ExecutionPolicy Bypass -File tools\test-mod.ps1 -Keep -Ticks 1200

.EXAMPLE
  powershell -ExecutionPolicy Bypass -File tools\test-mod.ps1 -Factorio "D:\Games\Factorio\bin\x64\factorio.exe"
#>

param(
  [string]$Factorio,
  [int]$Ticks = 600,
  [switch]$Keep
)

$ErrorActionPreference = "Stop"
. (Join-Path $PSScriptRoot "common.ps1")

$root = Split-Path -Parent $PSScriptRoot
$work = Join-Path $env:TEMP "chiptorio-test"
$mods = Join-Path $work "mods"
$dest = Join-Path $mods "chiptorio"
$save = Join-Path $work "test.zip"
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

Write-Host "Creating a map with mod directory: $mods"
$create = Start-Process -FilePath $Factorio `
  -ArgumentList @("--mod-directory", "`"$mods`"", "--create", "`"$save`"") `
  -PassThru -Wait

$problems = @()
if ($create.ExitCode -ne 0) {
  # only treat non-zero exit as failure if there are actual error messages
  # Factorio returns exit code 1 when the Steam API requires a restart,
  # but the map may have been created successfully anyway.
  $log = Get-Content -LiteralPath $logPath -Raw
  if ($log -match "(?im)Error|Failed|chiptorio.*error|cannot be loaded|Invalid prototype|Unknown prototype") {
    $problems += "map creation exited with code $($create.ExitCode)"
  } elseif (-not (Test-Path -LiteralPath $save)) {
    $problems += "map creation produced no save at $save (exit code $($create.ExitCode))"
  }
}
$problems += Get-LogProblems -LogPath $logPath
if ($problems.Count -gt 0) { Show-Failure -Problems $problems }

if (-not (Test-Path $save)) {
  Show-Failure -Problems @("map creation produced no save at $save")
}

Write-Host "Running a $Ticks-tick benchmark"
$bench = Start-Process -FilePath $Factorio `
  -ArgumentList @("--mod-directory", "`"$mods`"", "--benchmark", "`"$save`"", "--benchmark-ticks", "$Ticks") `
  -PassThru -Wait

$problems = @()
if ($bench.ExitCode -ne 0) {
  # same logic for benchmark: Factorio may return 1 on Steam restart
  $log = Get-Content -LiteralPath $logPath -Raw
  if ($log -match "(?im)Error|Failed|chiptorio.*error|cannot be loaded|Invalid prototype|Unknown prototype") {
    $problems += "benchmark exited with code $($bench.ExitCode)"
  }
}
$problems += Get-LogProblems -LogPath $logPath
if ($problems.Count -gt 0) { Show-Failure -Problems $problems }

Write-Host ""
Write-Host "--- mods loaded ---"
if (Test-Path $logPath) {
  Select-String -Path $logPath -Pattern "(?i)chiptorio" | Select-Object -First 5 | ForEach-Object { Write-Host $_.Line.Trim() }
}

Write-Host ""
Write-Host "OK: data stage loaded, a map was created, and $Ticks ticks ran." -ForegroundColor Green
Write-Host "Save: $save"

if (-not $Keep) {
  Remove-Item $work -Recurse -Force -ErrorAction SilentlyContinue
}

exit 0
