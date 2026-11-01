# Launch an isolated rack-art scenario; no changes to the normal mod directory.
param([string]$Factorio, [switch]$CollectScreenshot, [switch]$Reload, [switch]$StopOnly)
$ErrorActionPreference='Stop'
. (Join-Path $PSScriptRoot 'common.ps1')
$Factorio=Resolve-FactorioExecutable -Factorio $Factorio
if ($Reload) {
  foreach ($running in @(Get-CimInstance Win32_Process -Filter "Name='factorio.exe'")) {
    if ($running.CommandLine -like '*chiptorio-rack-preview/server-rack*') {
      $old=Get-Process -Id $running.ProcessId
      $null=$old.CloseMainWindow()
      if (-not $old.WaitForExit(10000)) { throw 'Close the disposable rack review window to reload the sprites.' }
    }
  }
}
$root=Split-Path -Parent $PSScriptRoot
if ($StopOnly) { exit 0 }
$work=Join-Path $env:TEMP 'chiptorio-rack-preview'
$mods=Join-Path $work 'mods'
New-Item -ItemType Directory -Force $mods | Out-Null
if ($CollectScreenshot) {
  Get-Content -LiteralPath (Join-Path $env:APPDATA 'Factorio/factorio-current.log') -Tail 35
  Copy-Item -LiteralPath (Join-Path $env:APPDATA 'Factorio/script-output/chiptorio/server-rack-preview.png') -Destination (Join-Path $PSScriptRoot 'graphics/blender/renders/final/in-game-preview.png')
  foreach ($tick in @(120,128)) {
    $capture=Join-Path $env:APPDATA "Factorio/script-output/chiptorio/animation-$tick.png"
    if (Test-Path -LiteralPath $capture) { Copy-Item -LiteralPath $capture -Destination (Join-Path $PSScriptRoot "graphics/blender/renders/final/in-game-$tick.png") }
  }
  exit 0
}
foreach ($pair in @(@('chiptorio',$root),@('chiptorio-rack-preview',(Join-Path $PSScriptRoot 'rack-preview')))) {
  $target=Join-Path $mods $pair[0]
  if (-not (Test-Path -LiteralPath $target)) {
    New-Item -ItemType Junction -Path $target -Target $pair[1] | Out-Null
  } else {
    $link=Get-Item -LiteralPath $target
    if ($link.LinkType -ne 'Junction' -or [System.IO.Path]::GetFullPath(@($link.Target)[0]) -ine [System.IO.Path]::GetFullPath($pair[1])) {
      throw "Unexpected existing preview mod path: $target"
    }
  }
}
@{mods=@(@{name='base';enabled=$true},@{name='chiptorio';enabled=$true},@{name='chiptorio-rack-preview';enabled=$true})} |
  ConvertTo-Json -Depth 5 | Set-Content (Join-Path $mods 'mod-list.json') -Encoding UTF8
# Visible because the purpose of this launcher is interactive visual review.
$env:SteamAppId='427520'
$env:SteamGameId='427520'
$launchArgs=@('--mod-directory', ('"'+$mods+'"'), '--load-scenario', 'chiptorio-rack-preview/server-rack')
$process=Start-Process -FilePath $Factorio -ArgumentList $launchArgs -PassThru -RedirectStandardOutput (Join-Path $work 'preview-stdout.txt') -RedirectStandardError (Join-Path $work 'preview-stderr.txt')
Start-Sleep -Seconds 2
if ($process.HasExited) {
  # The Steam build can request one restart after switching from headless use.
  $process=Start-Process -FilePath $Factorio -ArgumentList $launchArgs -PassThru -RedirectStandardOutput (Join-Path $work 'preview-stdout.txt') -RedirectStandardError (Join-Path $work 'preview-stderr.txt')
  Start-Sleep -Seconds 2
}
if ($process.HasExited) {
  Get-Content -LiteralPath (Join-Path $work 'preview-stdout.txt') -Tail 35
  Get-Content -LiteralPath (Join-Path $work 'preview-stderr.txt') -Tail 35
  $steam = @(Get-SteamInstallRoots | ForEach-Object { Join-Path $_ 'steam.exe' } | Where-Object { Test-Path -LiteralPath $_ }) | Select-Object -First 1
  if (-not $steam) { throw 'Factorio requested a Steam restart but steam.exe was not found.' }
  Start-Process -FilePath $steam -ArgumentList (@('-applaunch','427520') + $launchArgs)
  Write-Host 'Requested the preview through Steam.'
}
Write-Host 'Opened the isolated server-rack review scenario.'
# Keep the launcher alive so managed command sessions retain the game process.
if (-not $process.HasExited) { $process.WaitForExit() }
