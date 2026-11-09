<# The next five P0 machines, using the same one-view game sprite pipeline. #>
param(
  [string]$BlenderPath='blender',
  [ValidateSet('auto','cpu','hip')][string]$Device='auto',
  [string]$GpuName='',
  [int]$Samples=24,
  [int]$Frames=24,
  [string]$OutputDirectory=(Join-Path $PSScriptRoot 'renders/game-infrastructure'),
  [switch]$Build,
  [switch]$Install,
  [switch]$PackOnly
)
& (Join-Path $PSScriptRoot 'render-game-labs.ps1') -BlenderPath $BlenderPath -Device $Device `
  -GpuName $GpuName -Samples $Samples -Frames $Frames -Resolution 512 `
  -Assets @('metrology-lab','answer-engine','qln-storage-drive','quantum-entanglement-core','construction-core') `
  -OutputDirectory $OutputDirectory -Build:$Build -Install:$Install -PackOnly:$PackOnly
