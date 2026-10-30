<#
.SYNOPSIS
  Runs the Chiptorio power-grid probe (P1.7) on a hosted headless server.

.DESCRIPTION
  `--benchmark` raises tick handlers at tick 0 only, so suites that need real
  elapsed time must run on a live server. This script creates a map, hosts it
  long enough for the staged power-grid probe to charge and then isolate the
  Construction Core, and requires the probe to log PASS power-grid.

.EXAMPLE
  powershell -ExecutionPolicy Bypass -File tools\test-power-grid.ps1

.EXAMPLE
  powershell -ExecutionPolicy Bypass -File tools\test-power-grid.ps1 -Keep -TimeoutSeconds 180
#>

param(
  [string]$Factorio,
  [int]$TimeoutSeconds = 180,
  [switch]$Keep
)

$ErrorActionPreference = "Stop"
. (Join-Path $PSScriptRoot "common.ps1")

$root = Split-Path -Parent $PSScriptRoot
$probe = Join-Path $PSScriptRoot "test-probe"
$work = Join-Path $env:TEMP "chiptorio-power-grid"
$mods = Join-Path $work "mods"
$dest = Join-Path $mods "chiptorio"
$probeDest = Join-Path $mods "chiptorio-test-probe"
$map = Join-Path $work "power-grid-map.zip"
$writeData = $work
$logPath = Join-Path $writeData "factorio-current.log"
$configPath = Join-Path $work "config.ini"
$serverSettings = Join-Path $work "server-settings.json"
$serverLog = Join-Path $work "server.log"
$serverOut = Join-Path $work "server-out.log"
$serverErr = Join-Path $work "server-err.log"

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

# Opt the probe into the power-grid server suite. control.lua branches on this.
Set-Content -LiteralPath (Join-Path $probeDest "server_suite.lua") -Value 'return "power-grid"' -Encoding ASCII

$gameRoot = Split-Path -Parent (Split-Path -Parent (Split-Path -Parent $Factorio))
$config = @(
  "[path]",
  "read-data=$gameRoot\data",
  "write-data=$work",
  "",
  "[general]",
  "locale=auto"
) -join "`r`n"
Set-Content -LiteralPath $configPath -Value $config -Encoding ASCII

$example = Join-Path $gameRoot "data\server-settings.example.json"
if (-not (Test-Path -LiteralPath $example)) {
  throw "missing server settings template: $example"
}
$settings = Get-Content -LiteralPath $example -Raw | ConvertFrom-Json
$settings.name = "chiptorio-power-grid"
$settings.description = "Chiptorio power-grid probe"
$settings.visibility.public = $false
$settings.visibility.lan = $false
$settings.username = ""
$settings.password = ""
$settings.token = ""
$settings.game_password = ""
$settings.require_user_verification = $false
$settings.auto_pause = $false
$settings.autosave_interval = 0
$settings.only_admins_can_pause_the_game = $false
$settings | ConvertTo-Json -Depth 10 | Set-Content -LiteralPath $serverSettings -Encoding ASCII

function Get-LogProblems {
  param([string[]]$Paths)
  $found = @()
  $patterns = @(
    "Error while running",
    "Failed to load mod",
    "Unknown prototype",
    "Invalid prototype",
    "CHIPTORIO-TEST FAIL",
    "cannot be loaded",
    "Failed to authenticate"
  )
  foreach ($path in $Paths) {
    if (-not (Test-Path -LiteralPath $path)) { continue }
    $log = Get-Content -LiteralPath $path -Raw
    foreach ($p in $patterns) {
      $m = [regex]::Matches($log, "(?im)^.*$p.*$")
      foreach ($hit in $m) {
        if ($hit.Value -match "CHIPTORIO-TEST INFO") { continue }
        $found += $hit.Value.Trim()
      }
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
  Write-Host "Server log: $serverLog"
  Write-Host "Factorio log: $logPath"
  if (-not $Keep) {
    Remove-Item $work -Recurse -Force -ErrorAction SilentlyContinue
  }
  exit 1
}

Write-Host "Creating a power-grid map"
$create = Start-Process -FilePath $Factorio `
  -ArgumentList @("--mod-directory", "`"$mods`"", "--create", "`"$map`"") `
  -PassThru -Wait
if ($create.ExitCode -ne 0 -and -not (Test-Path -LiteralPath $map)) {
  Write-Host "Map creation exited with code $($create.ExitCode), retrying..." -ForegroundColor Yellow
  Start-Sleep -Seconds 3
  $create = Start-Process -FilePath $Factorio `
    -ArgumentList @("--mod-directory", "`"$mods`"", "--create", "`"$map`"") `
    -PassThru -Wait
}
if (-not (Test-Path -LiteralPath $map)) {
  Show-Failure -Problems @("map creation produced no save at $map (exit code $($create.ExitCode))")
}

Write-Host "Hosting the map for $TimeoutSeconds seconds (power-grid probe needs real ticks)"
$server = Start-Process -FilePath $Factorio `
  -ArgumentList @(
    "--mod-directory", "`"$mods`"",
    "--config", "`"$configPath`"",
    "--start-server", "`"$map`"",
    "--server-settings", "`"$serverSettings`"",
    "--bind", "127.0.0.1",
    "--port", "34199"
  ) `
  -RedirectStandardOutput $serverOut `
  -RedirectStandardError $serverErr `
  -PassThru

$deadline = (Get-Date).AddSeconds($TimeoutSeconds)
while ((Get-Date) -lt $deadline) {
  if ($server.HasExited) { break }
  Start-Sleep -Milliseconds 500
}

if (-not $server.HasExited) {
  Start-Sleep -Seconds 1
  Stop-Process -Id $server.Id -Force -ErrorAction SilentlyContinue
}
$server.WaitForExit(5000) | Out-Null

$serverLogs = @($logPath, (Join-Path $env:APPDATA "Factorio\factorio-current.log"))
$problems = @()
$problems += Get-LogProblems -Paths $serverLogs
if ($problems.Count -gt 0) { Show-Failure -Problems $problems }

if (Test-Path -LiteralPath $logPath) {
  $log = Get-Content -LiteralPath $logPath -Raw
  if ($log -notmatch "CHIPTORIO-TEST PASS power-grid") {
    $problems += "power-grid probe did not log PASS"
  }
} else {
  $problems += "no Factorio log at $logPath"
}

Copy-Item -LiteralPath $logPath -Destination $serverLog -Force -ErrorAction SilentlyContinue

if ($problems.Count -gt 0) { Show-Failure -Problems $problems }

Write-Host ""
Write-Host "OK: power-grid probe passed." -ForegroundColor Green

if (-not $Keep) {
  Remove-Item $work -Recurse -Force -ErrorAction SilentlyContinue
}

exit 0
