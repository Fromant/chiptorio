<#
.SYNOPSIS
  Runs the Chiptorio save/load probe (P1.2).

.DESCRIPTION
  Creates a map, hosts it from a headless server long enough for the probe to
  build runtime state and write chiptorio-reload.zip, then benchmarks that save
  and requires the save-load suite to log PASS.

  The server is used instead of a benchmark because only a real game can call
  game.server_save; a benchmark process cannot write its own save. The reload
  is a benchmark because a created map has no player and no GUI can be tested
  headlessly.

.EXAMPLE
  powershell -ExecutionPolicy Bypass -File tools\test-save-load.ps1

.EXAMPLE
  powershell -ExecutionPolicy Bypass -File tools\test-save-load.ps1 -Keep -Ticks 180
#>

param(
  [string]$Factorio,
  [int]$Ticks = 180,
  [int]$TimeoutSeconds = 180,
  [switch]$Keep
)

$ErrorActionPreference = "Stop"
. (Join-Path $PSScriptRoot "common.ps1")

$root = Split-Path -Parent $PSScriptRoot
$probe = Join-Path $PSScriptRoot "test-probe"
$work = Join-Path $env:TEMP "chiptorio-save-load"
$mods = Join-Path $work "mods"
$dest = Join-Path $mods "chiptorio"
$probeDest = Join-Path $mods "chiptorio-test-probe"
$map = Join-Path $work "save-load-map.zip"
$writeData = Join-Path $work "write-data"
$saves = Join-Path $writeData "saves"
$reload = Join-Path $saves "chiptorio-reload.zip"
$configPath = Join-Path $work "config.ini"
$serverSettings = Join-Path $work "server-settings.json"
$logPath = Join-Path $writeData "factorio-current.log"
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
New-Item -ItemType Directory -Force -Path $mods, $writeData, $saves | Out-Null

robocopy $root $dest /E /XD .git tools dist /NFL /NDL /NJH /NJS | Out-Null
if ($LASTEXITCODE -ge 8) { throw "robocopy failed with code $LASTEXITCODE" }
New-Item -ItemType Directory -Force -Path $probeDest | Out-Null
robocopy $probe $probeDest /E /NFL /NDL /NJH /NJS | Out-Null
if ($LASTEXITCODE -ge 8) { throw "probe robocopy failed with code $LASTEXITCODE" }

# Opt the probe into the save-load server suite. control.lua branches on this.
Set-Content -LiteralPath (Join-Path $probeDest "server_suite.lua") -Value 'return "save-load"' -Encoding ASCII

# Redirect write-data so game.server_save lands in this test directory instead
# of the player's real save folder. read-data stays the resolved install.
$gameRoot = Split-Path -Parent (Split-Path -Parent (Split-Path -Parent $Factorio))
$config = @(
  "[path]",
  "read-data=$gameRoot\data",
  "write-data=$writeData",
  "",
  "[general]",
  "locale=auto"
) -join "`r`n"
Set-Content -LiteralPath $configPath -Value $config -Encoding ASCII

# Loopback-only, not advertised on LAN or the public server list, so no auth
# account is needed. The server parses the example's full schema strictly, so
# start from the shipped template and override only the test values.
$example = Join-Path $gameRoot "data\server-settings.example.json"
if (-not (Test-Path -LiteralPath $example)) {
  throw "missing server settings template: $example"
}
$settings = Get-Content -LiteralPath $example -Raw | ConvertFrom-Json
$settings.name = "chiptorio-save-load"
$settings.description = "Chiptorio save/load probe"
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
  Write-Host "Benchmark log: $logPath"
  if (-not $Keep) {
    Remove-Item $work -Recurse -Force -ErrorAction SilentlyContinue
  }
  exit 1
}

Write-Host "Creating a save/load map"
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

Write-Host "Hosting the map to write $reload"
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
$saved = $false
while ((Get-Date) -lt $deadline) {
  if (Test-Path -LiteralPath $reload) { $saved = $true; break }
  if ($server.HasExited) { break }
  Start-Sleep -Milliseconds 500
}

if (-not $server.HasExited) {
  # Give the server a moment to flush the save and log after the file appears.
  Start-Sleep -Seconds 1
  Stop-Process -Id $server.Id -Force -ErrorAction SilentlyContinue
}
$server.WaitForExit(5000) | Out-Null

$serverLogs = @($logPath, (Join-Path $env:APPDATA "Factorio\factorio-current.log"))
$problems = @()
if (-not $saved) {
  $problems += "the server did not write $reload within $TimeoutSeconds seconds"
}
$problems += Get-LogProblems -Paths $serverLogs
if ($problems.Count -gt 0) { Show-Failure -Problems $problems }

Copy-Item -LiteralPath $logPath -Destination $serverLog -Force -ErrorAction SilentlyContinue

Write-Host "Benchmarking the reloaded save for $Ticks ticks"
$bench = Start-Process -FilePath $Factorio `
  -ArgumentList @(
    "--mod-directory", "`"$mods`"",
    "--config", "`"$configPath`"",
    "--benchmark", "`"$reload`"",
    "--benchmark-ticks", "$Ticks"
  ) `
  -PassThru -Wait

$problems = @()
if ($bench.ExitCode -ne 0) {
  $problems += "benchmark exited with code $($bench.ExitCode)"
}
$problems += Get-LogProblems -Paths @($logPath)
if (Test-Path -LiteralPath $logPath) {
  $log = Get-Content -LiteralPath $logPath -Raw
  if ($log -notmatch "CHIPTORIO-TEST PASS save-load") {
    $problems += "save-load probe did not log PASS"
  }
}
if ($problems.Count -gt 0) { Show-Failure -Problems $problems }

Write-Host ""
Write-Host "OK: save/load probe passed." -ForegroundColor Green
Write-Host "Reload save: $reload"

if (-not $Keep) {
  Remove-Item $work -Recurse -Force -ErrorAction SilentlyContinue
}

exit 0
