<#
.SYNOPSIS
  Regenerates the Chiptorio entity world sprites in the rosy-42 style.

.DESCRIPTION
  Every entity sprite is drawn with transparency and soft shading to match
  the hand-drawn aseprite exports. Sizes scale with the entity footprint:
  1x1 = 80px, 2x2 = 128px, 3x3 = 160px, 5x5 = 240px, 7x7 = 320px.
  Re-run this after editing the palette or adding new prototypes.
#>

$ErrorActionPreference = "Stop"
Add-Type -AssemblyName System.Drawing

$root = Split-Path -Parent $PSScriptRoot
$outDir = Join-Path $root "graphics\entity"
New-Item -ItemType Directory -Force -Path $outDir | Out-Null

function Col([string]$hex) { [System.Drawing.ColorTranslator]::FromHtml($hex) }

function New-Canvas([int]$w, [int]$h) {
  $bmp = New-Object System.Drawing.Bitmap $w, $h
  $g = [System.Drawing.Graphics]::FromImage($bmp)
  $g.Clear([System.Drawing.Color]::Transparent)
  $g.SmoothingMode = [System.Drawing.Drawing2D.SmoothingMode]::AntiAlias
  $g.InterpolationMode = [System.Drawing.Drawing2D.InterpolationMode]::HighQualityBicubic
  $g.PixelOffsetMode = [System.Drawing.Drawing2D.PixelOffsetMode]::Half
  return @($bmp, $g)
}

function Rect($g, [int]$x, [int]$y, [int]$w, [int]$h, [System.Drawing.Color]$c) {
  $br = New-Object System.Drawing.SolidBrush -ArgumentList $c
  $g.FillRectangle($br, $x, $y, $w, $h)
  $br.Dispose()
}

function Disc($g, [double]$x, [double]$y, [double]$r, [System.Drawing.Color]$c) {
  $br = New-Object System.Drawing.SolidBrush -ArgumentList $c
  $g.FillEllipse($br, [single]($x - $r), [single]($y - $r), [single](2 * $r), [single](2 * $r))
  $br.Dispose()
}

function Line($g, [int]$x1, [int]$y1, [int]$x2, [int]$y2, [System.Drawing.Color]$c, [float]$w = 1) {
  $p = New-Object System.Drawing.Pen -ArgumentList $c, $w
  $g.DrawLine($p, $x1, $y1, $x2, $y2)
  $p.Dispose()
}

function Poly($g, [int[]]$flat, [System.Drawing.Color]$c) {
  $points = @()
  for ($i = 0; $i -lt $flat.Count; $i += 2) { $points += New-Object System.Drawing.Point($flat[$i], $flat[$i + 1]) }
  $br = New-Object System.Drawing.SolidBrush -ArgumentList $c
  $g.FillPolygon($br, $points)
  $br.Dispose()
}

function RoundRect($g, [int]$x, [int]$y, [int]$w, [int]$h, [int]$r, [System.Drawing.Color]$c) {
  $gp = New-Object System.Drawing.Drawing2D.GraphicsPath
  $gp.AddArc($x, $y, $r*2, $r*2, 180, 90)
  $gp.AddArc($x+$w-$r*2, $y, $r*2, $r*2, 270, 90)
  $gp.AddArc($x+$w-$r*2, $y+$h-$r*2, $r*2, $r*2, 0, 90)
  $gp.AddArc($x, $y+$h-$r*2, $r*2, $r*2, 90, 90)
  $gp.CloseFigure()
  $br = New-Object System.Drawing.SolidBrush -ArgumentList $c
  $g.FillPath($br, $gp)
  $br.Dispose()
  $gp.Dispose()
}

function ShadedRect($g, [int]$x, [int]$y, [int]$w, [int]$h, [System.Drawing.Color]$base, [System.Drawing.Color]$light, [System.Drawing.Color]$dark) {
  $gp = New-Object System.Drawing.Drawing2D.GraphicsPath
  $gp.AddRectangle([System.Drawing.Rectangle]::new($x, $y, $w, $h))
  $pth = New-Object System.Drawing.Drawing2D.PathGradientBrush $gp
  $pth.CenterColor = $base
  $pth.SurroundColors = @($light, $dark)
  $g.FillRectangle($pth, $x, $y, $w, $h)
  $pth.Dispose(); $gp.Dispose()
}

function ShadedDisc($g, [double]$cx, [double]$cy, [double]$r, [System.Drawing.Color]$base, [System.Drawing.Color]$light, [System.Drawing.Color]$dark) {
  $pth = New-Object System.Drawing.Drawing2D.GraphicsPath
  $pth.AddEllipse([single]($cx - $r), [single]($cy - $r), [single](2*$r), [single](2*$r))
  $gb = New-Object System.Drawing.Drawing2D.PathGradientBrush $pth
  $gb.CenterColor = $base
  $gb.SurroundColors = @($light, $dark)
  $g.FillEllipse($gb, [single]($cx - $r), [single]($cy - $r), [single](2*$r), [single](2*$r))
  $gb.Dispose(); $pth.Dispose()
}

function Save-Entity($bmp, [string]$name) {
  $big = New-Object System.Drawing.Bitmap $bmp.Width, $bmp.Height
  $bg = [System.Drawing.Graphics]::FromImage($big)
  $bg.InterpolationMode = [System.Drawing.Drawing2D.InterpolationMode]::NearestNeighbor
  $bg.DrawImage($bmp, 0, 0, $bmp.Width, $bmp.Height)
  $big.Save((Join-Path $outDir "$name.png"), [System.Drawing.Imaging.ImageFormat]::Png)
  $bg.Dispose(); $big.Dispose(); $bmp.Dispose()
}

# --- rosy-42 palette (System.Drawing.Color objects) -----------------------
$ink      = Col "#21181b"
$panel    = Col "#1a2430"
$line     = Col "#2a3a4a"
$slate    = Col "#686f99"
$slateL   = Col "#a3a7c2"
$cream    = Col "#dfe0e8"
$gold     = Col "#f0b541"
$orange   = Col "#cf752b"
$burnt    = Col "#ab5130"
$red      = Col "#7d3833"
$brown    = Col "#a3652a"
$steel    = Col "#7d8b99"
$silver   = Col "#b9c6d4"
$blue     = Col "#5b8ff9"
$magenta  = Col "#c06ec8"
$cyan     = Col "#686f99"
$green    = Col "#4fbf6a"
$purple   = Col "#9a6ee0"

Write-Host "Rosy-42 palette loaded."

# =========================================================================
# NETWORK ENTITIES
# =========================================================================

# --- network-cable (1x1): floor decal, thin vertical line + connector caps ---
$b, $g = New-Canvas 80 80
$cx = 40
Line $g $cx 8 $cx 72 $slate 3
Line $g $cx 8 $cx 12 $slate 5
Line $g $cx 68 $cx 72 $slate 5
Rect $g 37 4 6 4 $silver
Rect $g 37 72 6 4 $silver
Disc $g 40 6 2 $ink
Disc $g 40 74 2 $ink
Save-Entity $b "network-cable"

# --- network-switch (2x2): box chassis, 4-sided ports, green LEDs ---
$b, $g = New-Canvas 128 128
RoundRect $g 16 16 96 96 10 $panel
Rect $g 16 16 96 2 $line
# side ports
for ($sy = 30; $sy -le 98; $sy += 34) {
  Disc $g 22 $sy 5 $ink; Disc $g 26 $sy 2 $green
  Disc $g 106 $sy 5 $ink; Disc $g 102 $sy 2 $green
}
for ($sx = 30; $sx -le 98; $sx += 34) {
  Disc $g $sx 22 5 $ink; Disc $g $sx 26 2 $green
  Disc $g $sx 106 5 $ink; Disc $g $sx 102 2 $green
}
# top status display
Rect $g 48 34 32 14 $slate
Rect $g 54 36 4 4 $cream
Rect $g 70 36 4 4 $cream
Save-Entity $b "network-switch"

# --- network-router (2x2): box + two antennas + signal arcs ---
$b, $g = New-Canvas 128 128
RoundRect $g 16 16 96 80 10 $panel
Rect $g 16 16 96 2 $line
# side ports
for ($sy = 36; $sy -le 90; $sy += 27) {
  Disc $g 22 $sy 4 $ink; Disc $g 24 $sy 2 $green
  Disc $g 106 $sy 4 $ink; Disc $g 104 $sy 2 $green
}
# antennas
Rect $g 44 8 4 20 $steel
Rect $g 80 8 4 20 $steel
Disc $g 46 6 4 $slate
Disc $g 82 6 4 $slate
# signal arcs
Line $g 44 16 30 24 $slate 1
Line $g 44 16 58 24 $slate 1
Line $g 84 16 70 24 $slate 1
Line $g 84 16 98 24 $slate 1
Save-Entity $b "network-router"

# --- network-monitor (2x2): kiosk with tilted screen + status LEDs ---
$b, $g = New-Canvas 128 128
RoundRect $g 16 20 96 92 10 $panel
Rect $g 16 20 96 2 $line
# stand
Rect $g 58 100 12 14 $steel
# screen face (tilted)
Poly $g @(30,56,98,56,106,42,22,42) $ink
Rect $g 34 60 60 22 $slate
# status LEDs
Rect $g 38 86 6 6 $red
Rect $g 84 86 6 6 $green
Save-Entity $b "network-monitor"

# --- network-repeater (1x1): inline box, cable left/right, green light ---
$b, $g = New-Canvas 80 80
RoundRect $g 12 30 56 20 6 $panel
Rect $g 12 30 56 2 $line
Disc $g 40 40 6 $green
# cable entry points
Rect $g 4 36 8 8 $ink
Rect $g 68 36 8 8 $ink
Line $g 8 40 12 40 $slate 2
Line $g 68 40 64 40 $slate 2
# signal arc
Line $g 40 24 40 16 $slate 2
Line $g 34 22 40 28 $slate 1
Line $g 46 22 40 28 $slate 1
Save-Entity $b "network-repeater"

# --- wireless-access-point (2x2): flat panel + center antenna + broadcast arcs ---
$b, $g = New-Canvas 128 128
Rect $g 24 40 80 48 $panel
Rect $g 24 40 80 2 $line
Rect $g 58 12 12 32 $steel
Disc $g 64 10 5 $slate
# broadcast arcs
Line $g 64 12 40 30 $slate 1
Line $g 64 12 88 30 $slate 1
Line $g 64 16 48 34 $slate 1
Line $g 64 16 80 34 $slate 1
# front panel detail
Rect $g 36 60 56 2 $cream
Save-Entity $b "wireless-access-point"

# --- foup-dock (2x2): container body + top carrier + mode indicator ---
$b, $g = New-Canvas 128 128
RoundRect $g 20 40 88 72 8 $panel
Rect $g 20 40 88 2 $line
# access door
Rect $g 40 56 48 36 $ink
Rect $g 44 60 40 4 $line
# carrier on top
Rect $g 50 20 28 24 $silver
Rect $g 50 20 28 2 $cream
Rect $g 48 18 4 4 $gold
Rect $g 76 18 4 4 $gold
# mode indicator (red seal / green unseal)
Rect $g 30 104 8 8 $red
Rect $g 90 104 8 8 $green
Save-Entity $b "foup-dock"

Write-Host "network entity sprites done."

# =========================================================================
# MACHINE ENTITIES (fabs / assemblers)
# =========================================================================

# --- wafer-fab (7x7): cleanroom, fluid pipes, load port, status screen ---
$b, $g = New-Canvas 320 320
RoundRect $g 20 20 280 200 16 $panel
Rect $g 20 20 280 2 $line
# fluid pipes left
Rect $g 8 80 16 120 $slate
Rect $g 8 80 16 2 $cream
# front load port
Rect $g 120 140 80 40 $ink
Rect $g 124 144 72 8 $slate
# status screen
Rect $g 180 40 100 44 $panel
Rect $g 184 44 92 8 $ink
Rect $g 200 54 4 4 $cyan
Rect $g 220 54 4 4 $cyan
# side wafer cassette
Rect $g 220 140 60 14 $silver
for ($i = 0; $i -lt 5; $i++) { Rect $g 222 (144 + $i * 4) 56 2 $line }
# top vents
for ($x = 40; $x -le 260; $x += 40) { Rect $g $x 24 8 4 $steel }
Save-Entity $b "wafer-fab"

# --- crystal-puller (5x5): furnace, crystal cylinder, heat glow ---
$b, $g = New-Canvas 240 240
RoundRect $g 20 40 200 140 12 $panel
Rect $g 20 40 200 2 $line
# crystal cylinder
Rect $g 100 40 40 100 $silver
Rect $g 100 40 40 2 $cream
Disc $g 120 30 12 $orange
# melt pool
Rect $g 80 140 80 6 $ink
Line $g 80 142 160 142 $orange 2
# top heater ring
Rect $g 70 16 100 10 $steel
Rect $g 74 20 92 2 $red
# side details
Rect $g 20 100 16 40 $line
Rect $g 204 100 16 40 $line
Save-Entity $b "crystal-puller"

# --- assembly-fab (5x5): packaging line, chip pattern, spool ---
$b, $g = New-Canvas 240 240
RoundRect $g 20 30 200 160 12 $panel
Rect $g 20 30 200 2 $line
# side chip pattern
Rect $g 30 50 8 6 $gold
Rect $g 30 60 8 6 $gold
Rect $g 30 70 8 6 $gold
Rect $g 30 80 8 6 $gold
Rect $g 30 90 8 6 $gold
# front I/O ports
Rect $g 90 130 20 20 $ink
Rect $g 94 134 12 4 $slate
Rect $g 130 130 20 20 $ink
Rect $g 134 134 12 4 $gold
# top spool
Disc $g 60 50 10 $silver
Disc $g 60 50 4 $ink
Rect $g 56 44 8 12 $steel
# base
Rect $g 20 180 200 10 $line
Save-Entity $b "assembly-fab"

# --- circuit-assembler (3x3): bench with screen + component tray ---
$b, $g = New-Canvas 160 160
RoundRect $g 12 24 136 110 8 $panel
Rect $g 12 24 136 2 $line
# screen
Rect $g 30 36 40 28 $ink
Rect $g 34 40 32 4 $slate
# component tray
Rect $g 20 70 120 16 $line
Rect $g 30 74 12 12 $gold
Rect $g 50 74 12 12 $gold
Rect $g 70 74 12 12 $gold
Rect $g 90 74 12 12 $gold
# base
Rect $g 12 130 136 4 $line
Save-Entity $b "circuit-assembler"

# --- computer-assembler (3x3): bench with blue screen + circuit lid ---
$b, $g = New-Canvas 160 160
RoundRect $g 12 24 136 110 8 $panel
Rect $g 12 24 136 2 $line
# blue screen
Rect $g 30 36 40 28 $ink
Rect $g 34 40 32 4 $blue
# circuit lid
Rect $g 20 70 120 6 $panel
Rect $g 20 70 120 2 $line
Rect $g 30 74 12 12 $gold
Rect $g 50 74 12 12 $gold
Rect $g 70 74 12 12 $gold
Rect $g 90 74 12 12 $gold
# base
Rect $g 12 130 136 4 $line
Save-Entity $b "computer-assembler"

# --- vlsi-fab (7x7): massive plant, coolant pipes, mask-loader port ---
$b, $g = New-Canvas 320 320
RoundRect $g 20 20 280 200 16 $panel
Rect $g 20 20 280 2 $line
# coolant pipes
Rect $g 8 80 16 120 $slate
Rect $g 8 80 16 2 $cream
Rect $g 296 80 16 120 $slate
Rect $g 296 80 16 2 $cream
# mask-loader port
Rect $g 120 130 80 50 $ink
Rect $g 124 134 72 8 $gold
# status screen
Rect $g 180 40 100 44 $panel
Rect $g 184 44 92 8 $ink
Rect $g 200 54 4 4 $cyan
Rect $g 220 54 4 4 $cyan
# side panel lines
for ($y = 60; $y -le 160; $y += 20) { Rect $g 40 $y 4 8 $steel }
Save-Entity $b "vlsi-fab"

# --- cooling-tower (5x5): tower body, top fan, vapor plumes ---
$b, $g = New-Canvas 240 240
RoundRect $g 30 30 180 140 10 $panel
Rect $g 30 30 180 2 $line
# top fan
Rect $g 70 14 100 16 $steel
Disc $g 120 22 14 $steel
Line $g 120 8 120 36 $slate 2
Line $g 106 22 134 22 $slate 2
Line $g 106 16 134 28 $slate 1
Line $g 134 16 106 28 $slate 1
# vapor plumes
Rect $g 100 8 10 14 $slateL
Rect $g 130 8 10 14 $slateL
Rect $g 110 4 20 10 $slateL
# pipe inlets bottom
Rect $g 40 164 20 4 $slate
Rect $g 180 164 20 4 $slate
Save-Entity $b "cooling-tower"

# --- quantum-fab (7x7): cryogenic, frost patterns, dilution cylinder ---
$b, $g = New-Canvas 320 320
RoundRect $g 20 20 280 200 16 $panel
Rect $g 20 20 280 2 $line
# frost patterns (pale cyan)
for ($i = 0; $i -lt 8; $i++) {
  $x = 40 + ($i * 30)
  $y = 60 + ($i % 3) * 10
  Line $g $x $y ($x + 8) ($y + 6) $slateL 1
  Line $g ($x + 4) $y ($x + 12) ($y + 6) $slateL 1
}
# dilution refrigerator cylinder stack
Rect $g 120 40 80 100 $silver
Rect $g 120 40 80 2 $cream
Rect $g 128 48 8 8 $cyan
Rect $g 184 48 8 8 $cyan
# top quantum wiring
for ($x = 110; $x -le 210; $x += 10) { Line $g $x 40 $x 34 $gold 1 }
# front cylinder stack
Rect $g 136 150 48 20 $silver
Rect $g 144 154 4 4 $cyan
Rect $g 172 154 4 4 $cyan
Save-Entity $b "quantum-fab"

Write-Host "machine entity sprites done."

# =========================================================================
# COMPUTE PROVIDERS & LABS (lab clones)
# =========================================================================

# --- server-rack (2x2): rack with 4 bays, blinking LEDs ---
$b, $g = New-Canvas 128 128
RoundRect $g 14 14 100 100 8 $panel
Rect $g 14 14 100 2 $line
for ($y = 30; $y -le 94; $y += 22) {
  Rect $g 24 $y 24 12 $ink
  Rect $g 28 ($y + 2) 4 4 $red
  Rect $g 40 ($y + 2) 4 4 $green
  Rect $g 80 $y 24 12 $ink
  Rect $g 84 ($y + 2) 4 4 $red
  Rect $g 96 ($y + 2) 4 4 $green
}
# cable entry bottom
Rect $g 54 108 20 4 $steel
Save-Entity $b "server-rack"

# --- memory-bank (2x2): rack with 4 vertical memory slots ---
$b, $g = New-Canvas 128 128
RoundRect $g 14 14 100 100 8 $panel
Rect $g 14 14 100 2 $line
for ($x = 26; $x -le 94; $x += 24) {
  Rect $g $x 30 16 60 $ink
  Rect $g ($x + 2) 32 2 56 $slate
  Disc $g ($x + 8) 94 2 $green
}
# side slots
Rect $g 10 60 4 8 $steel
Rect $g 114 60 4 8 $steel
Save-Entity $b "memory-bank"

# --- datacenter (3x3): large rack, 8 bays, fan grilles, coolant inlet ---
$b, $g = New-Canvas 160 160
RoundRect $g 10 10 140 120 10 $panel
Rect $g 10 10 140 2 $line
for ($y = 24; $y -le 100; $y += 19) {
  Rect $g 20 $y 24 11 $ink
  Disc $g 24 ($y + 3) 2 $red
  Rect $g 116 $y 24 11 $ink
  Disc $g 120 ($y + 3) 2 $green
}
# top fan grilles
Disc $g 50 24 8 $steel
Disc $g 110 24 8 $steel
# coolant inlet right
Rect $g 142 60 4 24 $slate
Rect $g 144 64 2 16 $cream
Save-Entity $b "datacenter"

# --- analytical-engine (2x2): Victorian brass computer, gears, crank ---
$b, $g = New-Canvas 128 128
RoundRect $g 14 14 100 100 8 $panel
Rect $g 14 14 100 2 $line
# brass body
Rect $g 24 30 80 50 $orange
# gears
Disc $g 38 56 10 $burnt
Disc $g 90 56 10 $burnt
Line $g 38 56 38 46 $ink 1
Line $g 90 56 90 46 $ink 1
# card reader slot
Rect $g 42 18 44 6 $ink
# output tray
Rect $g 40 90 48 8 $panel
# side crank
Rect $g 8 48 6 16 $steel
Disc $g 2 56 4 $steel
Save-Entity $b "analytical-engine"

# --- tube-mainframe (2x2): rack of vacuum tubes, orange filaments ---
$b, $g = New-Canvas 128 128
RoundRect $g 14 14 100 100 8 $panel
Rect $g 14 14 100 2 $line
for ($x = 26; $x -le 94; $x += 22) {
  Disc $g ($x + 4) 34 6 $cream
  Line $g ($x + 4) 28 ($x + 4) 40 $orange 2
  Disc $g ($x + 4) 34 2 $red
}
# heat haze top
Rect $g 20 8 88 10 $slateL
Save-Entity $b "tube-mainframe"

# --- mainframe-cluster (2x2): rack with module cards, green PCBs ---
$b, $g = New-Canvas 128 128
RoundRect $g 14 14 100 100 8 $panel
Rect $g 14 14 100 2 $line
for ($y = 30; $y -le 94; $y += 22) {
  Rect $g 24 $y 80 12 $ink
  Rect $g 28 ($y + 2) 4 4 $green
  Rect $g 36 ($y + 2) 4 4 $gold
  Rect $g 72 ($y + 2) 4 4 $cyan
  Rect $g 80 ($y + 2) 4 4 $green
}
# status lights row
for ($x = 30; $x -le 90; $x += 15) { Disc $g $x 110 2 $gold }
Save-Entity $b "mainframe-cluster"

# --- datacenter-lab (2x2): white/silver chassis, cooling pipes, screens ---
$b, $g = New-Canvas 128 128
RoundRect $g 14 14 100 100 6 $panel
Rect $g 14 14 100 2 $line
# cooling pipes
Rect $g 20 30 4 60 $slate
Rect $g 104 30 4 60 $slate
# front screens
Rect $g 30 40 28 20 $ink
Rect $g 70 40 28 20 $ink
Rect $g 34 44 4 4 $slate
Rect $g 74 44 4 4 $slate
# base line
Rect $g 14 108 100 4 $line
Save-Entity $b "datacenter-lab"

# --- cryostat (2x2): cryogenic lab, dewar flask, quantum core ---
$b, $g = New-Canvas 128 128
RoundRect $g 14 14 100 100 8 $panel
Rect $g 14 14 100 2 $line
# dewar flask
Disc $g 64 58 16 $silver
Disc $g 64 58 4 $ink
Rect $g 56 72 16 4 $steel
# quantum core glow
Disc $g 64 58 6 $slate
# frost patterns
Line $g 20 40 28 46 $slateL 1
Line $g 100 40 92 46 $slateL 1
Line $g 20 90 28 84 $slateL 1
Line $g 100 90 92 84 $slateL 1
Save-Entity $b "cryostat"

# --- metrology-lab (3x3): bench, microscope, wafer stage, status bar ---
$b, $g = New-Canvas 160 160
RoundRect $g 10 30 140 110 8 $panel
Rect $g 10 30 140 2 $line
# bench top
Rect $g 20 40 120 4 $cream
# microscope left
Rect $g 30 44 14 46 $steel
Disc $g 36 44 8 $ink
# wafer stage center
Rect $g 70 70 20 4 $silver
Disc $g 80 72 6 $ink
# status bar right
Rect $g 110 50 14 6 $green
Rect $g 110 58 14 4 $red
# side details
Rect $g 20 80 16 4 $steel
Rect $g 124 80 16 4 $steel
Save-Entity $b "metrology-lab"

Write-Host "provider & lab entity sprites done."

# =========================================================================
# QLN & CONSTRUCTION ENTITIES
# =========================================================================

# --- qln-import-node (2x2): box, IN arrow, cyan flow ---
$b, $g = New-Canvas 128 128
RoundRect $g 16 16 96 96 8 $panel
Rect $g 16 16 96 2 $line
Rect $g 24 30 40 40 $ink
# IN arrow from left
Rect $g 12 50 14 4 $green
Rect $g 20 46 8 12 $green
# cyan flow inside
Rect $g 32 40 24 20 $slate
# chest front
Rect $g 34 82 36 4 $line
Save-Entity $b "qln-import-node"

# --- qln-export-node (2x2): box, OUT arrow, cyan flow ---
$b, $g = New-Canvas 128 128
RoundRect $g 16 16 96 96 8 $panel
Rect $g 16 16 96 2 $line
Rect $g 64 30 40 40 $ink
# OUT arrow to right
Rect $g 102 50 14 4 $red
Rect $g 100 46 8 12 $red
# cyan flow inside
Rect $g 32 40 24 20 $slate
# chest front
Rect $g 34 82 36 4 $line
Save-Entity $b "qln-export-node"

# --- qln-provider-node (2x2): disk, supply icon, outgoing arcs ---
$b, $g = New-Canvas 128 128
ShadedDisc $g 64 64 40 $panel $silver $ink
Disc $g 64 64 20 $ink
# supply icon: gold box with plus
Rect $g 50 50 12 12 $gold
Rect $g 54 54 4 4 $ink
Line $g 56 50 56 62 $gold 2
Line $g 54 56 58 56 $gold 2
# outgoing arcs right
Line $g 90 40 112 50 $slate 2
Line $g 90 50 112 50 $slate 2
Line $g 90 60 112 50 $slate 2
Save-Entity $b "qln-provider-node"

# --- qln-requester-node (2x2): disk, request icon, incoming arcs ---
$b, $g = New-Canvas 128 128
ShadedDisc $g 64 64 40 $panel $silver $ink
Disc $g 64 64 20 $ink
# request icon: ink box with minus
Rect $g 50 50 12 12 $ink
Rect $g 54 54 4 4 $panel
Line $g 54 58 60 58 $ink 2
# incoming arcs left
Line $g 38 40 16 50 $slate 2
Line $g 38 50 16 50 $slate 2
Line $g 38 60 16 50 $slate 2
Save-Entity $b "qln-requester-node"

# --- qln-terminal (2x2): kiosk, screen with item list, keyboard tray ---
$b, $g = New-Canvas 128 128
RoundRect $g 16 30 96 80 8 $panel
Rect $g 16 30 96 2 $line
# tilted screen
Poly $g @(28,50,100,50,104,38,24,38) $ink
Rect $g 32 54 40 18 $slate
# text lines
Rect $g 36 60 6 1 $silver
Rect $g 36 64 10 1 $silver
Rect $g 36 68 8 1 $silver
# keyboard tray
Rect $g 32 100 64 4 $steel
# card reader
Rect $g 108 60 4 12 $gold
Save-Entity $b "qln-terminal"

# --- qln-storage-drive (2x2): rack-mount drive, 4 slots, capacity bar ---
$b, $g = New-Canvas 128 128
RoundRect $g 14 14 100 100 8 $panel
Rect $g 14 14 100 2 $line
for ($y = 26; $y -le 86; $y += 20) {
  Rect $g 24 $y 20 14 $ink
  Rect $g 26 ($y + 2) 4 10 $slate
  Rect $g 32 ($y + 2) 4 10 $gold
}
# capacity bar bottom
Rect $g 24 104 40 6 $slate
Rect $g 24 104 32 6 $slate
# side rails
Rect $g 8 40 4 8 $steel
Rect $g 116 40 4 8 $steel
Save-Entity $b "qln-storage-drive"

# --- construction-core (3x3): accumulator shell, arm icon, charge bars ---
$b, $g = New-Canvas 160 160
RoundRect $g 20 40 120 80 10 $panel
Rect $g 20 40 120 2 $line
# arm icon front
Rect $g 56 60 12 4 $gold
Rect $g 68 58 12 4 $gold
Rect $g 74 60 12 4 $gold
# charge bars right
Rect $g 114 44 12 32 $slate
Rect $g 116 46 8 28 $green
# base
Rect $g 20 112 120 4 $line
Save-Entity $b "construction-core"

# --- quantum-entanglement-core (2x2): two cores linked by arc ---
$b, $g = New-Canvas 128 128
# core A
Disc $g 36 64 14 $purple
Disc $g 36 64 4 $ink
# core B
Disc $g 92 64 14 $slate
Disc $g 92 64 4 $ink
# linking arc
Line $g 50 64 78 64 $magenta 2
Disc $g 36 64 2 $gold
Disc $g 92 64 2 $gold
# side rails
Rect $g 8 46 4 6 $silver
Rect $g 116 46 4 6 $silver
Save-Entity $b "quantum-entanglement-core"

# --- answer-engine (5x5): large block, quantum accents, "42" screen, corner towers ---
$b, $g = New-Canvas 240 240
RoundRect $g 16 32 208 140 14 $panel
Rect $g 16 32 208 2 $line
# central screen with "42"
Rect $g 92 56 56 36 $ink
Rect $g 100 64 4 12 $gold
Rect $g 106 64 4 4 $gold
Rect $g 112 64 4 12 $gold
Rect $g 116 76 4 4 $gold
Rect $g 128 64 8 4 $gold
Rect $g 138 68 4 4 $gold
Rect $g 134 72 4 4 $gold
Rect $g 134 76 8 4 $gold
# corner towers
Rect $g 28 32 24 24 $steel
Rect $g 188 32 24 24 $steel
Rect $g 28 148 24 24 $steel
Rect $g 188 148 24 24 $steel
# top quantum core glow
Disc $g 120 22 18 $slate
Disc $g 120 22 6 $gold
# quantum accents
Rect $g 104 34 32 4 $purple
Save-Entity $b "answer-engine"

Write-Host "qln & answer engine entity sprites done."
Write-Host "All entity sprites generated."





# --- size map by footprint -------------------------------------------------
function Size-For([int]$tiles) {
  switch ($tiles) {
    1 { return 80 }
    2 { return 128 }
    3 { return 160 }
    5 { return 240 }
    7 { return 320 }
    default { return 128 }
  }
}
