<# Export one fixed game view, native working/idle sprites and an exact-sheet viewer. #>
param(
  [string]$BlenderPath = 'blender',
  [ValidateSet('auto','cpu','hip')][string]$Device = 'auto',
  [string]$GpuName = '',
  [string[]]$Assets = @('analytical-engine','tube-mainframe','mainframe-cluster','datacenter-lab','cryostat'),
  [ValidateRange(2,64)][int]$Frames = 24,
  [ValidateRange(1,4096)][int]$Samples = 32,
  [ValidateRange(384,1024)][int]$Resolution = 384,
  [string]$OutputDirectory = (Join-Path $PSScriptRoot 'renders/game-labs'),
  [switch]$Build,
  [switch]$Install,
  [switch]$PackOnly
)
$ErrorActionPreference = 'Stop'
$allowed = @('analytical-engine','tube-mainframe','mainframe-cluster','datacenter-lab','cryostat',
  'metrology-lab','answer-engine','qln-storage-drive','quantum-entanglement-core','construction-core',
  'foup-dock','wireless-access-point','qln-import-node','qln-export-node','qln-provider-node',
  'qln-requester-node')
foreach ($asset in $Assets) { if ($asset -notin $allowed) { throw "Unknown game asset: $asset" } }
$out = [IO.Path]::GetFullPath($OutputDirectory)
if (-not $PackOnly) { $exe = (Get-Command $BlenderPath -ErrorAction Stop).Source }
foreach ($asset in $Assets) {
  $directory = Join-Path $PSScriptRoot $asset
  $blend = Join-Path $directory "$asset.blend"
  $assetOut = Join-Path $out $asset
  $assetRes = $Resolution
  if ($asset -in @('metrology-lab', 'answer-engine')) { $assetRes = 512 }
  if (-not $PackOnly) {
    if ($Build) {
      & $exe -b --python-exit-code 1 -P (Join-Path $directory 'build.py')
      if ($LASTEXITCODE -ne 0) { throw "Build failed: $asset" }
    }
    & $exe -b $blend --python-exit-code 1 -P (Join-Path $PSScriptRoot 'verify-lab-motion.py')
    if ($LASTEXITCODE -ne 0) { throw "Working/idle validation failed: $asset" }
    foreach ($state in @('working','idle')) {
      $arguments = @('-b',$blend,'--python-exit-code','1','-P',(Join-Path $PSScriptRoot 'render.py'),
        '--','--game-view','--samples',$Samples,'--resolution',$assetRes,'--device',$Device,
        '--output-dir',(Join-Path $assetOut $state))
      if ($GpuName) { $arguments += @('--gpu-name',$GpuName) }
      if ($state -eq 'working') { $arguments += @('--animate','--frames',$Frames,'--no-shadows') }
      else { $arguments += '--idle' }
      & $exe @arguments
      if ($LASTEXITCODE -ne 0) { throw "Game render failed: $asset / $state" }
    }
  }
  & (Join-Path $PSScriptRoot 'pack-game-lab.ps1') -OutputDirectory $assetOut -Install:$Install
}
& (Join-Path $PSScriptRoot 'preview-game-labs.ps1') -OutputDirectory $out -Assets $Assets
