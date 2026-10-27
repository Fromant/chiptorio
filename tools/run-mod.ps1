<#
.SYNOPSIS
  Launches Factorio with the current working tree as the active Chiptorio mod.

.DESCRIPTION
  Builds an isolated development mod directory under %TEMP%\chiptorio-dev\mods,
  places the repository in it as the chiptorio mod, enables it in mod-list.json,
  and starts Factorio with --mod-directory pointing at that folder.

  By default the repository is linked with a directory junction, so every launch
  sees the latest working tree with no copy step. Use -Copy to take a snapshot
  instead, or -ModDirectory to use a mod folder you already manage.

  After the game exits the script scans factorio-current.log for load and runtime
  errors and exits non-zero if it finds any. Use -NoWait to launch and return.

.PARAMETER Factorio
  Path to factorio.exe or its install directory. Otherwise FACTORIO_EXE, .env,
  or a detected Steam/common install is used.

.PARAMETER WorkDir
  Development work directory. Defaults to %TEMP%\chiptorio-dev.

.PARAMETER Copy
  Copy the working tree instead of creating a directory junction. Slower, but
  works when junctions are unavailable.

.PARAMETER ModDirectory
  Use this mod directory instead of the isolated development one. The script
  still creates or updates a chiptorio entry there.

.PARAMETER NoWait
  Start Factorio and return immediately instead of waiting for it to exit.

.PARAMETER GameArgs
  Extra arguments passed to factorio.exe, for example --fullscreen or
  --benchmark "C:\path\save.zip" --benchmark-ticks 600.

.EXAMPLE
  powershell -ExecutionPolicy Bypass -File tools\run-mod.ps1

.EXAMPLE
  powershell -ExecutionPolicy Bypass -File tools\run-mod.ps1 -Copy

.EXAMPLE
  powershell -ExecutionPolicy Bypass -File tools\run-mod.ps1 -NoWait -GameArgs --fullscreen
#>
param(
  [string]$Factorio,
  [string]$WorkDir = (Join-Path $env:TEMP "chiptorio-dev"),
  [switch]$Copy,
  [string]$ModDirectory,
  [switch]$NoWait,
  [Parameter(ValueFromRemainingArguments = $true)]
  [string[]]$GameArgs
)

$ErrorActionPreference = "Stop"
. (Join-Path $PSScriptRoot "common.ps1")

$root = Split-Path -Parent $PSScriptRoot

foreach ($required in @("info.json", "data.lua", "data-updates.lua", "control.lua")) {
  if (-not (Test-Path -LiteralPath (Join-Path $root $required))) {
    throw "missing required mod file: $required"
  }
}

$Factorio = Resolve-FactorioExecutable -Factorio $Factorio
$info = Get-Content -LiteralPath (Join-Path $root "info.json") -Raw | ConvertFrom-Json

$isolated = -not $ModDirectory
if ($ModDirectory) {
  $mods = $ExecutionContext.SessionState.Path.GetUnresolvedProviderPathFromPSPath($ModDirectory)
} else {
  $mods = Join-Path $WorkDir "mods"
}
New-Item -ItemType Directory -Force -Path $mods | Out-Null

$target = Join-Path $mods "chiptorio"

function Copy-ModTree {
  param([string]$Source, [string]$Destination)

  New-Item -ItemType Directory -Force -Path $Destination | Out-Null
  robocopy $Source $Destination /E /XD .git tools dist /XF .env /NFL /NDL /NJH /NJS | Out-Null
  if ($LASTEXITCODE -ge 8) {
    throw "robocopy failed with code $LASTEXITCODE"
  }
}

if (Test-Path -LiteralPath $target) {
  $item = Get-Item -LiteralPath $target -Force
  if ($item.LinkType) {
    $current = @($item.Target)[0]
    $resolved = $null
    if ($current) {
      $resolved = [System.IO.Path]::GetFullPath($current)
    }
    $same = $resolved -and ($resolved.TrimEnd('\') -ieq $root.TrimEnd('\'))
    if ($Copy -or -not $same) {
      # Removing a junction without -Recurse removes only the link.
      Remove-Item -LiteralPath $target -Force
    }
  } elseif ($Copy) {
    if (-not $isolated) {
      throw "$target already exists and is not a junction. Remove it or pick another -ModDirectory."
    }
  } else {
    if (-not $isolated) {
      throw "$target already exists and is not a junction. Remove it or use -Copy."
    }
    Remove-Item -LiteralPath $target -Recurse -Force
  }
}

if (-not (Test-Path -LiteralPath $target)) {
  if ($Copy) {
    Copy-ModTree -Source $root -Destination $target
  } else {
    try {
      New-Item -ItemType Junction -Path $target -Target $root | Out-Null
    } catch {
      Write-Warning "Could not create a directory junction: $($_.Exception.Message)"
      Write-Warning "Falling back to a copy. Re-run with -Copy to silence this warning."
      Copy-ModTree -Source $root -Destination $target
    }
  }
}

# Factorio only auto-enables an unlisted mod on first launch, which can open the
# mods window instead of the main menu. Write the list explicitly so the dev
# build is always enabled.
$listPath = Join-Path $mods "mod-list.json"
$list = $null
if (Test-Path -LiteralPath $listPath) {
  try {
    $list = Get-Content -LiteralPath $listPath -Raw | ConvertFrom-Json
  } catch {
    $list = $null
  }
}
if (-not $list) {
  $list = [pscustomobject]@{ mods = @() }
}

$entries = @()
if ($list.mods) {
  $entries = @($list.mods)
}

$hasBase = $false
$hasChip = $false
foreach ($entry in $entries) {
  if ($entry.name -eq "base") {
    $entry.enabled = $true
    $hasBase = $true
  } elseif ($entry.name -eq "chiptorio") {
    $entry.enabled = $true
    $hasChip = $true
  }
}
if (-not $hasBase) {
  $entries = @([pscustomobject]@{ name = "base"; enabled = $true }) + $entries
}
if (-not $hasChip) {
  $entries += [pscustomobject]@{ name = "chiptorio"; enabled = $true }
}
$list | Add-Member -NotePropertyName mods -NotePropertyValue $entries -Force
$list | ConvertTo-Json -Depth 8 | Set-Content -LiteralPath $listPath -Encoding UTF8

$mode = if ($Copy) { "copy" } else { "junction" }
Write-Host "Chiptorio $($info.version)"
Write-Host "Factorio: $Factorio"
Write-Host "Mod dir:  $mods ($mode)"

$arguments = @("--mod-directory", "`"$mods`"") + $GameArgs
$process = Start-Process -FilePath $Factorio -ArgumentList $arguments -PassThru
if ($NoWait) {
  Write-Host "Factorio started (PID $($process.Id))."
  exit 0
}

$process.WaitForExit()

# factorio-current.log is overwritten on every launch, so it only contains this
# session. Match the same load/runtime failures the test harness treats as fatal.
$logPath = Join-Path $env:APPDATA "Factorio\factorio-current.log"
$problems = @()
if (Test-Path -LiteralPath $logPath) {
  $log = Get-Content -LiteralPath $logPath -Raw
  foreach ($pattern in @(
      "Failed to load mod",
      "Error while running",
      "Unknown prototype",
      "Invalid prototype",
      "cannot be loaded"
    )) {
    foreach ($match in [regex]::Matches($log, "(?im)^.*$pattern.*$")) {
      $problems += $match.Value.Trim()
    }
  }
}

if ($problems.Count -gt 0) {
  Write-Host ""
  Write-Host "Factorio reported errors:" -ForegroundColor Red
  $problems | Select-Object -Unique | ForEach-Object { Write-Host "  $_" -ForegroundColor Red }
  Write-Host ""
  Write-Host "Full log: $logPath"
  exit 1
}

Write-Host "Factorio exited cleanly."
exit 0
