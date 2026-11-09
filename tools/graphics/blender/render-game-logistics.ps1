<# Third five assets: actual 1x1 logistics utility nodes, one game view each. #>
param(
  [string]$BlenderPath='blender',
  [ValidateSet('auto','cpu','hip')][string]$Device='auto',
  [string]$GpuName='',
  [int]$Samples=24,
  [int]$Frames=24,
  [string]$OutputDirectory=(Join-Path $PSScriptRoot 'renders/game-logistics'),
  [switch]$Build,
  [switch]$Install,
  [switch]$PackOnly
)
& (Join-Path $PSScriptRoot 'render-game-labs.ps1') -BlenderPath $BlenderPath -Device $Device `
  -GpuName $GpuName -Samples $Samples -Frames $Frames -Resolution 384 `
  -Assets @('foup-dock','wireless-access-point','qln-import-node','qln-export-node','qln-provider-node') `
  -OutputDirectory $OutputDirectory -Build:$Build -Install:$Install -PackOnly:$PackOnly
