# Contact sheet of the exported static frames; animation viewer is preview.html.
param([string]$OutputDirectory=(Join-Path $PSScriptRoot 'renders/final'))
$ErrorActionPreference='Stop'
Add-Type -AssemblyName System.Drawing
$m=Get-Content -LiteralPath (Join-Path $OutputDirectory 'render-manifest.json') -Raw|ConvertFrom-Json
$views=@($m.directions.PSObject.Properties | Where-Object Name -ne 'hero')
$cell=384;$width=$cell*2;$height=440*[int][Math]::Ceiling($views.Count/2)
$sheet=New-Object Drawing.Bitmap $width,$height
$g=[Drawing.Graphics]::FromImage($sheet);$g.Clear([Drawing.Color]::FromArgb(46,49,46))
$font=New-Object Drawing.Font 'Consolas',13
for($i=0;$i -lt $views.Count;$i++){
 $x=($i%2)*$cell;$y=[int][Math]::Floor($i/2)*440;$name=$views[$i].Name
 foreach($suffix in @('_shadow','')){
  $file=Join-Path $OutputDirectory "server-rack_$name$suffix.png"
  if(Test-Path -LiteralPath $file){$image=[Drawing.Image]::FromFile($file);$g.DrawImage($image,$x,$y,384,384);$image.Dispose()}
 }
 $g.DrawString("$($name.ToUpper()) / 3 x 3",$font,[Drawing.Brushes]::Gainsboro,$x+16,$y+396)
}
$sheet.Save((Join-Path $OutputDirectory 'preview.png'),[Drawing.Imaging.ImageFormat]::Png)
$g.Dispose();$sheet.Dispose();$font.Dispose()
