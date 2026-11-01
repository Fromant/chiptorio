<# Render the canonical enclosure. Direction selection and animation are independent. #>
param(
 [string]$Angles='north,east,south,west',
 [switch]$Animate,
 [ValidateRange(2,64)][int]$Frames=16,
 [int]$Resolution=384,
 [int]$Samples=128,
 [ValidateSet('auto','cpu','hip')][string]$Device='auto',
 [string]$GpuName='',
 [string]$BlenderPath='blender',
 [string]$OutputDirectory=(Join-Path $PSScriptRoot 'renders/final'),
 [switch]$Build,
 [switch]$Install,
 [switch]$NoShadows,
 [switch]$KeepFrames
)
$ErrorActionPreference='Stop'
$exe=Get-Command $BlenderPath -ErrorAction Stop
$blend=Join-Path $PSScriptRoot 'server-rack.blend'
if($Build){
 & $exe.Source -b --python-exit-code 1 -P (Join-Path $PSScriptRoot 'build.py')
 if($LASTEXITCODE -ne 0){throw 'Model build failed'}
}
if(-not (Test-Path -LiteralPath $blend)){throw 'Model missing. Run with -Build.'}
$argsList=@('-b',$blend,'--python-exit-code','1','-P',(Join-Path $PSScriptRoot 'render.py'),'--','--angles',$Angles,'--samples',$Samples,'--resolution',$Resolution,'--device',$Device,'--output-dir',$OutputDirectory)
if($Animate){$argsList+=@('--animate','--frames',$Frames)}
if($GpuName){$argsList+=@('--gpu-name',$GpuName)}
if($NoShadows){$argsList+='--no-shadows'}
& $exe.Source @argsList
if($LASTEXITCODE -ne 0){throw 'Render failed'}
& (Join-Path $PSScriptRoot 'pack.ps1') -OutputDirectory $OutputDirectory -Install:$Install -KeepFrames:$KeepFrames
Write-Host "Complete: $OutputDirectory"
