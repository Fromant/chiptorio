<# Compatibility entrypoint. Labs now export one actual game view, not four facings. #>
param(
  [string]$BlenderPath = 'blender',
  [ValidateSet('auto','cpu','hip')][string]$Device = 'auto',
  [string]$GpuName = '',
  [int]$Samples = 32,
  [int]$Resolution = 384,
  [int]$Frames = 24,
  [string]$OutputDirectory = (Join-Path $PSScriptRoot 'renders/game-labs'),
  [switch]$SkipBuild,
  [switch]$ComposeOnly,
  [switch]$Animate,
  [switch]$Install
)
$ErrorActionPreference = 'Stop'
# Working/idle export is always included. -Animate remains accepted for old commands.
& (Join-Path $PSScriptRoot 'render-game-labs.ps1') -BlenderPath $BlenderPath -Device $Device `
  -GpuName $GpuName -Samples $Samples -Resolution $Resolution -Frames $Frames `
  -OutputDirectory $OutputDirectory -Build:(-not $SkipBuild -and -not $ComposeOnly) `
  -PackOnly:$ComposeOnly -Install:$Install
