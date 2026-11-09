<# Preview the exact installed sprite sheets, at the same camera/scale as the game. #>
param([Parameter(Mandatory)][string]$OutputDirectory,[string[]]$Assets)
$ErrorActionPreference = 'Stop'
Add-Type -AssemblyName System.Drawing
$out = [IO.Path]::GetFullPath($OutputDirectory)
$specs = @($Assets | ForEach-Object { Get-Content (Join-Path $out "$_/game-sprite.json") -Raw | ConvertFrom-Json })
$json = ConvertTo-Json -InputObject $specs -Depth 6 -Compress
@"
<!doctype html><meta charset="utf-8"><title>Chiptorio in-game lab sprites</title>
<style>body{background:#20282b;color:#e9e9da;font:16px system-ui;margin:24px}main{display:flex;flex-wrap:wrap;gap:24px}section{background:#2b3538;padding:20px}canvas{image-rendering:pixelated;display:block}button{padding:8px 16px;margin:8px}p{color:#9bb8bc}</style>
<h1>Actual in-game lab sprites</h1><p>One fixed game view. Native working/idle animations. No hero camera or turntable. Green outline = physical footprint.</p>
<button id="state">Switch to idle</button><button id="zoom">Zoom: 4x game size</button><main></main>
<script>
const assets=$json;let working=true,zoom=4;const views=[];
document.querySelector('#state').onclick=()=>{working=!working;document.querySelector('#state').textContent=working?'Switch to idle':'Switch to working'};
document.querySelector('#zoom').onclick=()=>{zoom=zoom===4?1:4;document.querySelector('#zoom').textContent='Zoom: '+zoom+'x game size';for(const v of views){v.canvas.style.width=v.spec.width*.5*zoom+'px';v.canvas.style.height=v.spec.height*.5*zoom+'px'}};
for(const spec of assets){const section=document.createElement('section');section.innerHTML='<h2>'+spec.entity+'</h2><p>'+spec.footprint.join(' x ')+' tiles / '+spec.frames+' frames / '+spec.fps+' fps</p>';const canvas=document.createElement('canvas');canvas.width=spec.width;canvas.height=spec.height;canvas.style.width=spec.width*2+'px';canvas.style.height=spec.height*2+'px';section.append(canvas);document.querySelector('main').append(section);const images={};for(const name of ['working','idle','shadow']){images[name]=new Image();images[name].src=spec.entity+'/'+name+'.png'}views.push({spec,canvas,images})}
function tick(time){for(const v of views){const s=v.spec,c=v.canvas.getContext('2d');c.clearRect(0,0,s.width,s.height);const ox=s.origin[0]-s.crop[0],oy=s.origin[1]-s.crop[1];c.strokeStyle='#56645b';c.lineWidth=1;c.strokeRect(ox-s.footprint[0]*32,oy-s.footprint[1]*32,s.footprint[0]*64,s.footprint[1]*64);if(v.images.shadow.complete)c.drawImage(v.images.shadow,0,0);if(working){const f=Math.floor(time/1000*s.fps)%s.frames;if(v.images.working.complete)c.drawImage(v.images.working,(f%s.columns)*s.width,Math.floor(f/s.columns)*s.height,s.width,s.height,0,0,s.width,s.height)}else if(v.images.idle.complete)c.drawImage(v.images.idle,0,0)}requestAnimationFrame(tick)}requestAnimationFrame(tick);
</script>
"@ | Set-Content (Join-Path $out 'preview.html') -Encoding UTF8
$background = [Drawing.Color]::FromArgb(32,40,43)
$ink = [Drawing.SolidBrush]::new([Drawing.Color]::FromArgb(233,233,218))
$muted = [Drawing.SolidBrush]::new([Drawing.Color]::FromArgb(155,184,188))
$font = [Drawing.Font]::new('Segoe UI',15,[Drawing.FontStyle]::Bold)
$small = [Drawing.Font]::new('Segoe UI',11)
$rowHeights = @($specs | ForEach-Object { [int]$_.height+60 })
$totalHeight = 100+($rowHeights | Measure-Object -Sum).Sum
try {
  $frames = ($specs | Measure-Object -Property frames -Maximum).Maximum
  for ($frame=0; $frame -lt $frames; $frame++) {
    $bitmap = [Drawing.Bitmap]::new(1200,$totalHeight)
    $g = [Drawing.Graphics]::FromImage($bitmap)
    try {
      $g.Clear($background)
      $g.DrawString('CHIPTORIO / IN-GAME SPRITES / 2x GAME SIZE',$font,$ink,20,16)
      $g.DrawString('Idle: lights off / Working: exported animation sheet / Single fixed camera',$small,$muted,20,50)
      $y = 100
      for ($index=0; $index -lt $specs.Count; $index++) {
        $s = $specs[$index]
        $g.DrawString($s.entity,$font,$ink,20,[single]($y+10))
        $g.DrawString(($s.footprint -join ' x ')+' tiles',$small,$muted,20,[single]($y+43))
        $g.DrawString('IDLE',$small,$muted,300,[single]$y)
        $g.DrawString('WORKING',$small,$muted,800,[single]$y)
        $idle = [Drawing.Bitmap]::FromFile((Join-Path $out "$($s.entity)/idle.png"))
        $work = [Drawing.Bitmap]::FromFile((Join-Path $out "$($s.entity)/working.png"))
        $shadow = [Drawing.Bitmap]::FromFile((Join-Path $out "$($s.entity)/shadow.png"))
        try {
          # Explicit pixel rectangles avoid Blender's 72-DPI PNG metadata being
          # enlarged to GDI+'s 96-DPI canvas, even by DrawImageUnscaled.
          foreach ($x in @(300,800)) {
            $g.DrawImage($shadow,[Drawing.Rectangle]::new($x,$y+30,$s.width,$s.height),0,0,$s.width,$s.height,[Drawing.GraphicsUnit]::Pixel)
          }
          $g.DrawImage($idle,[Drawing.Rectangle]::new(300,$y+30,$s.width,$s.height),0,0,$s.width,$s.height,[Drawing.GraphicsUnit]::Pixel)
          $f = $frame % $s.frames
          $src = [Drawing.Rectangle]::new(($f%$s.columns)*$s.width,[int][Math]::Floor($f/$s.columns)*$s.height,$s.width,$s.height)
          $g.DrawImage($work,[Drawing.Rectangle]::new(800,$y+30,$s.width,$s.height),$src,[Drawing.GraphicsUnit]::Pixel)
        } finally { $idle.Dispose(); $work.Dispose(); $shadow.Dispose() }
        $y += $rowHeights[$index]
      }
      if ($frame -eq 0) { $bitmap.Save((Join-Path $out 'contact-sheet.png'),[Drawing.Imaging.ImageFormat]::Png) }
      $bitmap.Save((Join-Path $out ('preview-{0:000}.png' -f $frame)),[Drawing.Imaging.ImageFormat]::Png)
    } finally { $g.Dispose(); $bitmap.Dispose() }
  }
  if (Get-Command ffmpeg -ErrorAction SilentlyContinue) {
    & ffmpeg -hide_banner -loglevel error -y -framerate $specs[0].fps -i (Join-Path $out 'preview-%03d.png') -frames:v $frames -filter_complex 'split[a][b];[a]palettegen=stats_mode=diff[p];[b][p]paletteuse=dither=sierra2_4a' -loop 0 (Join-Path $out 'working-idle.gif')
    if ($LASTEXITCODE -ne 0) { throw 'Exact-sheet preview GIF encoding failed' }
  }
} finally { $ink.Dispose(); $muted.Dispose(); $font.Dispose(); $small.Dispose() }
Write-Host "Exact game sprite viewer: $(Join-Path $out 'preview.html')"
