<#
.SYNOPSIS
  Statically audits Chiptorio's runtime registrations (P1.8).
#>

param(
  [string]$Root = (Resolve-Path (Join-Path $PSScriptRoot "..")).Path
)

$ErrorActionPreference = "Stop"

$scripts = Join-Path $Root "scripts"
if (-not (Test-Path -LiteralPath $scripts)) {
  throw "scripts directory not found at $scripts"
}

$forbidden = @(
  "script.on_event",
  "script.on_nth_tick",
  "script.on_init",
  "script.on_configuration_changed",
  "remote.add_interface"
)

$allowed_interface_modules = @{
  "scripts/answer_engine.lua" = $true
  "scripts/runtime/qln_runtime.lua" = $true
}

$failures = @()

foreach ($file in (Get-ChildItem -LiteralPath $scripts -Filter "*.lua" -Recurse)) {
  $rel = $file.FullName.Substring($Root.Length + 1).Replace("\", "/")
  if ($rel -eq "scripts/control.lua") { continue }

  $content = Get-Content -LiteralPath $file.FullName -Raw

  foreach ($pattern in $forbidden) {
    if ($pattern -eq "remote.add_interface" -and $allowed_interface_modules.ContainsKey($rel)) {
      continue
    }
    $regex = [regex]::Escape($pattern) + "\s*\("
    $matches = [regex]::Matches($content, $regex)
    foreach ($match in $matches) {
      $lineStart = $match.Index
      $lineEnd = $content.IndexOf("`n", $lineStart)
      if ($lineEnd -lt 0) { $lineEnd = $content.Length }
      $line = $content.Substring($lineStart, $lineEnd - $lineStart).Trim()
      $failures += ($rel + ": registers a forbidden pattern (" + $line + ")")
    }
  }
}

if ($failures.Count -gt 0) {
  Write-Host "FAILED: P1.8 registration audit" -ForegroundColor Red
  $failures | Select-Object -Unique | ForEach-Object { Write-Host "  $_" -ForegroundColor Red }
  exit 1
}

Write-Host "OK: P1.8 registration audit passed." -ForegroundColor Green
exit 0
