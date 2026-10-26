<#
.SYNOPSIS
  Runtime regression test for the sustained-compute gate.

.DESCRIPTION
  Builds a throwaway map with a tiny probe mod that starts a gated technology
  (Photolithography) and records research progress every five seconds. With no
  production and no labs, the gate must freeze progress and apply the documented
  2%-per-minute decay. The script asserts that slope, so a change from
  "0.02 per minute" to "0.02 per second" cannot slip through again.

  The Factorio executable is resolved from -Factorio, the FACTORIO_EXE
  environment variable, .env, or common Steam install locations.

.EXAMPLE
  powershell -ExecutionPolicy Bypass -File tools\test-gate.ps1

.EXAMPLE
  powershell -ExecutionPolicy Bypass -File tools\test-gate.ps1 -Ticks 600 -Keep

.EXAMPLE
  powershell -ExecutionPolicy Bypass -File tools\test-gate.ps1 -Factorio "D:\Games\Factorio\bin\x64\factorio.exe"
#>

param(
  [string]$Factorio,
  [int]$Ticks = 300,
  [switch]$Keep
)

$ErrorActionPreference = "Stop"
. (Join-Path $PSScriptRoot "common.ps1")

$root = Split-Path -Parent $PSScriptRoot
$work = Join-Path $env:TEMP "chipotrio-gate-test"
$mods = Join-Path $work "mods"
$dest = Join-Path $mods "chipotrio"
$probe = Join-Path $mods "gateprobe"
$save = Join-Path $work "gate.zip"
$logPath = Join-Path $env:APPDATA "Factorio\factorio-current.log"

if ($Ticks -lt 60 -or ($Ticks % 60) -ne 0) {
  throw "Ticks must be a positive multiple of 60"
}

$Factorio = Resolve-FactorioExecutable -Factorio $Factorio
Write-Host "Factorio: $Factorio"

if (Test-Path $work) { Remove-Item $work -Recurse -Force }
New-Item -ItemType Directory -Force -Path $mods | Out-Null

robocopy $root $dest /E /XD .git tools dist /NFL /NDL /NJH /NJS | Out-Null
if ($LASTEXITCODE -ge 8) { throw "robocopy failed with code $LASTEXITCODE" }

New-Item -ItemType Directory -Force -Path $probe | Out-Null
@'
{
  "name": "gateprobe",
  "version": "0.0.1",
  "title": "gateprobe",
  "author": "chipotrio tests",
  "factorio_version": "2.1",
  "dependencies": ["chipotrio"]
}
'@ | Set-Content (Join-Path $probe "info.json")

# The probe starts a gated tech with no labs and no production. If the gate is
# working, progress can only decay from the point where it was seeded.
@'
local function report(tag)
  local force = game.forces.player
  local tech = force.current_research
  log(string.format(
    "GATEPROBE %s tick=%d tech=%s progress=%.6f",
    tag, game.tick, tech and tech.name or "none", force.research_progress
  ))
end

script.on_init(function()
  local force = game.forces.player
  for _, name in ipairs({
    "electromechanics", "thermionics", "semiconductor-physics",
    "crystal-growth", "chemical-science-pack", "advanced-circuit",
    "sulfur-processing", "automation-science-pack", "electronics", "steam-power",
  }) do
    if force.technologies[name] then
      force.technologies[name].researched = true
    end
  end
  if not force.add_research("photolithography") then
    log("GATEPROBE FAIL could not start photolithography")
    return
  end
  force.research_progress = 0.5
  report("seed")
end)

script.on_nth_tick(60, function() report("sample") end)
'@ | Set-Content (Join-Path $probe "control.lua")

Write-Host "Creating gate-test map with mod directory: $mods"
$create = Start-Process -FilePath $Factorio `
  -ArgumentList @("--mod-directory", "`"$mods`"", "--create", "`"$save`"") `
  -PassThru -Wait
if ($create.ExitCode -ne 0) { throw "map creation exited with code $($create.ExitCode)" }

Write-Host "Running a $Ticks-tick benchmark"
$bench = Start-Process -FilePath $Factorio `
  -ArgumentList @("--mod-directory", "`"$mods`"", "--benchmark", "`"$save`"", "--benchmark-ticks", "$Ticks") `
  -PassThru -Wait
if ($bench.ExitCode -ne 0) { throw "benchmark exited with code $($bench.ExitCode)" }

if (-not (Test-Path $logPath)) { throw "no Factorio log at $logPath" }
$log = Get-Content $logPath -Raw
if ($log -match "(?im)^.*Error while running.*$") {
  throw "runtime error in log: $($Matches[0])"
}

$samplePattern = "GATEPROBE sample tick=(\d+) tech=(\S+) progress=([0-9.]+)"
$samples = [regex]::Matches($log, $samplePattern)
if ($samples.Count -lt 2) {
  throw "expected at least two GATEPROBE samples, found $($samples.Count)"
}

$first = $samples[0]
$last = $samples[$samples.Count - 1]
$firstTick = [int]$first.Groups[1].Value
$lastTick = [int]$last.Groups[1].Value
$firstProgress = [double]::Parse($first.Groups[3].Value, [Globalization.CultureInfo]::InvariantCulture)
$lastProgress = [double]::Parse($last.Groups[3].Value, [Globalization.CultureInfo]::InvariantCulture)
if ($first.Groups[2].Value -ne "photolithography") {
  throw "probe lost its research: first sample is $($first.Groups[2].Value)"
}

$seconds = ($lastTick - $firstTick) / 60.0
$expected = $seconds * (0.02 / 60.0)
$actual = $firstProgress - $lastProgress
$tolerance = 0.00005
$ok = [Math]::Abs($actual - $expected) -le $tolerance

Write-Host ""
Write-Host ("progress: {0:F6} at tick {1} -> {2:F6} at tick {3}" -f $firstProgress, $firstTick, $lastProgress, $lastTick)
Write-Host ("decay:    {0:F6} actual, {1:F6} expected over {2:F1}s (2%/min)" -f $actual, $expected, $seconds)

if (-not $ok) {
  Write-Host "FAILED: gate decay does not match 2% per minute." -ForegroundColor Red
  Write-Host "Full log: $logPath"
  if (-not $Keep) { Remove-Item $work -Recurse -Force -ErrorAction SilentlyContinue }
  exit 1
}

Write-Host ""
Write-Host "OK: gated research freezes and decays at 2% per minute." -ForegroundColor Green

if (-not $Keep) {
  Remove-Item $work -Recurse -Force -ErrorAction SilentlyContinue
}
