<#
.SYNOPSIS
  Regenerates the Chiptorio icon set in the rosy-42 style.

.DESCRIPTION
  Every icon is drawn at 64x64 native with transparency and soft shading to
  match the hand-drawn aseprite exports. Technology icons are 256x256,
  thumbnail is 144x144, and the victory image is 400x600.
  Re-run this after editing the palette or adding new prototypes.
#>

$ErrorActionPreference = "Stop"
Add-Type -AssemblyName System.Drawing

$root = Split-Path -Parent $PSScriptRoot
$outDir = Join-Path $root "graphics\icons"
New-Item -ItemType Directory -Force -Path $outDir | Out-Null

function Col([string]$hex) { [System.Drawing.ColorTranslator]::FromHtml($hex) }

function New-Canvas {
  $bmp = New-Object System.Drawing.Bitmap 64, 64
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

function Save-Icon($bmp, [string]$name) {
  $big = New-Object System.Drawing.Bitmap 64, 64
  $bg = [System.Drawing.Graphics]::FromImage($big)
  $bg.InterpolationMode = [System.Drawing.Drawing2D.InterpolationMode]::NearestNeighbor
  $bg.DrawImage($bmp, 0, 0, 64, 64)
  $big.Save((Join-Path $outDir "$name.png"), [System.Drawing.Imaging.ImageFormat]::Png)
  $bg.Dispose(); $big.Dispose(); $bmp.Dispose()
}

# --- rosy-42 palette (System.Drawing.Color objects) -----------------------
$ink      = Col "#21181b"  # deep rosy dark / outlines
$panel    = Col "#1a2430"  # chassis, dark metal
$line     = Col "#2a3a4a"  # traces, slate
$slate    = Col "#686f99"  # cooling, liquid, quantum
$slateL   = Col "#a3a7c2"  # light periwinkle highlight
$cream    = Col "#dfe0e8"  # ceramic, light plastic
$gold     = Col "#f0b541"  # contacts, pins, gold plating
$orange   = Col "#cf752b"  # heat sinks, copper
$burnt    = Col "#ab5130"  # warm accent
$red      = Col "#7d3833"  # rosy red, heat/warnings
$brown    = Col "#a3652a"  # substrate, wood
$steel    = Col "#7d8b99"  # structural metal, frames
$silver   = Col "#b9c6d4"  # aluminum, bare metal, solder
$blue     = Col "#5b8ff9"  # AI trace accent
$magenta  = Col "#c06ec8"  # AGI radiant accent
$cyan     = Col "#686f99"  # cooling accent (rosy slate, alias of $slate)
$green    = Col "#4fbf6a"  # go / online
$purple   = Col "#9a6ee0"  # magic/quantum

Write-Host "Rosy-42 palette loaded."

# =========================================================================
# 1. STORAGE MEDIA
# =========================================================================

# punched-card: cream card with rosy ink holes
$b, $g = New-Canvas
RoundRect $g 4 2 56 60 6 $cream
Rect $g 4 2 56 2 $line
for ($y = 8; $y -le 56; $y += 8) {
  for ($x = 6; $x -le 54; $x += 8) {
    if (($x + $y) % 16 -eq 0) { Rect $g $x $y 4 4 $ink }
  }
}
Save-Icon $b "punched-card"

# punched-tape: brown tape with cream edge + ink holes
$b, $g = New-Canvas
Rect $g 4 20 56 24 $brown
Rect $g 4 20 56 2 $cream
for ($x = 6; $x -le 54; $x += 6) {
  Disc $g $x 26 2 $ink; Disc $g $x 38 2 $ink
  Disc $g $x 32 2 $ink
}
Save-Icon $b "punched-tape"

# magnetic-tape: silver reel with ink hub + gold center
$b, $g = New-Canvas
ShadedDisc $g 32 32 18 $silver $cream $ink
Disc $g 32 32 8 $ink
Disc $g 32 32 4 $gold
Rect $g 14 52 36 4 $brown
Rect $g 14 52 36 2 $cream
Save-Icon $b "magnetic-tape"

# disk-pack: silver disk with ink center + gold center dot + steel arm
$b, $g = New-Canvas
ShadedDisc $g 32 32 18 $silver $cream $ink
Disc $g 32 32 6 $ink
Disc $g 32 32 2 $gold
Line $g 32 32 48 18 $steel 2
Save-Icon $b "disk-pack"

# solid-state-drive: ink body with slate window + gold edge connector
$b, $g = New-Canvas
RoundRect $g 8 10 48 44 4 $ink
RoundRect $g 12 14 40 20 2 $slate
Rect $g 16 36 8 6 $line
Rect $g 10 50 44 2 $gold
Save-Icon $b "solid-state-drive"

# mainframe-module: green/gold chip block on panel base
$b, $g = New-Canvas
RoundRect $g 8 6 48 52 6 $panel
Rect $g 8 6 48 2 $gold
Rect $g 16 16 12 12 $panel
Rect $g 36 16 12 12 $panel
Rect $g 16 32 32 12 $panel
Disc $g 18 18 2 $cream
Disc $g 26 18 2 $cream
Disc $g 40 18 2 $cream
Save-Icon $b "mainframe-module"

Write-Host "storage media icons done."

# =========================================================================
# 2. SILICON / FEEDSTOCK
# =========================================================================

# silica: tan grain pile (cream + brown specks)
$b, $g = New-Canvas
Poly $g @(6,60,10,44,16,40,24,42,30,40,38,44,42,48,46,60) $cream
Disc $g 38 50 12 $cream
Disc $g 46 50 8 $cream
Rect $g 6 54 40 2 $steel
for ($i = 0; $i -lt 14; $i++) { Disc $g (10 + ($i*3)) (56 - ($i%3)) 1 $brown }
Save-Icon $b "silica"

# glass: cyan glass block with ink cracks
$b, $g = New-Canvas
Poly $g @(10,52,14,18,28,16,34,20,30,52) $slate
Line $g 18 18 18 26 $ink 2
Line $g 24 18 24 26 $ink 2
Save-Icon $b "glass"

# metallurgical-silicon: dark chunk with silver sparkles
$b, $g = New-Canvas
Poly $g @(10,52,14,34,30,28,36,36,24,52) $steel
Poly $g @(28,52,30,34,34,28,38,34,26,52) $line
Rect $g 14 38 4 4 $silver
Rect $g 26 34 2 2 $silver
Rect $g 32 40 2 2 $silver
Save-Icon $b "metallurgical-silicon"

# polysilicon: silver rod with cream grain lines
$b, $g = New-Canvas
Poly $g @(10,52,14,30,46,28,50,52) $silver
Poly $g @(30,52,34,28,38,28,42,32,40,52) $steel
Line $g 16 36 16 46 $cream
Line $g 28 30 28 44 $cream
Line $g 36 34 36 48 $cream
Rect $g 46 30 2 2 $slate
Save-Icon $b "polysilicon"

# monocrystalline-ingot: silver cylinder, flat end with gold X lattice
$b, $g = New-Canvas
Poly $g @(10,52,16,40,34,36,50,40,44,52) $silver
Poly $g @(18,40,20,36,32,36,34,40) $steel
Line $g 22 42 26 46 $cream
Line $g 26 42 22 46 $cream
Line $g 30 42 34 46 $cream
Line $g 34 42 30 46 $cream
Save-Icon $b "monocrystalline-ingot"

# silicon-wafer: silver circle with flat notch
$b, $g = New-Canvas
ShadedDisc $g 32 32 18 $silver $cream $ink
Disc $g 32 32 2 $steel
Rect $g 30 50 4 2 $ink
Line $g 20 22 20 40 $cream
Line $g 26 18 26 44 $cream
Save-Icon $b "silicon-wafer"

# litho-mask: gold square with ink grid lines + panel mounting tab
$b, $g = New-Canvas
Rect $g 12 12 40 40 $gold
for ($i = 14; $i -le 50; $i += 4) {
  Line $g $i 12 $i 52 $ink
  Line $g 12 $i 52 $i $ink
}
Rect $g 50 24 4 16 $panel
Rect $g 50 28 2 8 $slate
Save-Icon $b "litho-mask"

# exposed-wafer: silver wafer with purple crosshair
$b, $g = New-Canvas
ShadedDisc $g 32 32 18 $silver $cream $ink
Line $g 14 32 50 32 $slate
Line $g 32 14 32 50 $slate
Disc $g 32 32 2 $steel
Save-Icon $b "exposed-wafer"

# etched-wafer: silver wafer with slate crosshair
$b, $g = New-Canvas
ShadedDisc $g 32 32 18 $silver $cream $ink
Line $g 14 32 50 32 $slate
Line $g 32 14 32 50 $slate
Disc $g 32 32 2 $steel
Save-Icon $b "etched-wafer"

# processed-wafer: silver wafer with gold crosshair
$b, $g = New-Canvas
ShadedDisc $g 32 32 18 $silver $cream $ink
Line $g 14 32 50 32 $gold
Line $g 32 14 32 50 $gold
Disc $g 32 32 2 $steel
Save-Icon $b "processed-wafer"

# bare-die: panel square with gold border + four cyan squares + center
$b, $g = New-Canvas
Rect $g 12 12 40 40 $panel
Rect $g 12 12 40 2 $gold
Rect $g 12 52 40 2 $gold
Rect $g 12 12 2 40 $gold
Rect $g 52 12 2 40 $gold
Rect $g 16 16 12 12 $slate
Rect $g 36 16 12 12 $slate
Rect $g 16 36 12 12 $slate
Rect $g 36 36 12 12 $slate
Rect $g 26 26 12 12 $ink
Save-Icon $b "bare-die"

Write-Host "silicon icons done."

# =========================================================================
# 3. DEVICES (chips, tubes, transistors)
# =========================================================================

# vacuum-tube: glass cylinder, orange filament, silver base pins
$b, $g = New-Canvas
Poly $g @(22,14,22,46,42,46,42,14) $slateL
Line $g 22 14 22 46 $ink 2
Line $g 42 14 42 46 $ink 2
Disc $g 24 20 3 $burnt
Disc $g 40 20 3 $burnt
Line $g 24 20 40 44 $orange
Line $g 40 20 24 44 $orange
Rect $g 20 46 24 6 $steel
Rect $g 22 52 2 2 $ink
Rect $g 30 52 2 2 $ink
Rect $g 38 52 2 2 $ink
Save-Icon $b "vacuum-tube"

# discrete-transistor: black body, 3 silver leads, rosy red band
$b, $g = New-Canvas
Disc $g 32 28 10 $ink
Rect $g 32 38 1 6 $steel
Rect $g 29 44 1 2 $steel
Rect $g 35 44 1 2 $steel
Disc $g 32 28 2 $red
Save-Icon $b "discrete-transistor"

# integrated-circuit: black square chip, gold pins all sides, dot at pin 1
$b, $g = New-Canvas
Rect $g 12 12 40 40 $ink
for ($y = 14; $y -le 50; $y += 6) {
  Rect $g 10 $y 2 2 $gold
  Rect $g 52 $y 2 2 $gold
}
for ($x = 14; $x -le 50; $x += 6) {
  Rect $g $x 10 2 2 $gold
  Rect $g $x 52 2 2 $gold
}
Rect $g 14 14 1 1 $slate
Save-Icon $b "integrated-circuit"

# microprocessor: larger chip, silver heat spreader center, gold pins
$b, $g = New-Canvas
Rect $g 10 10 44 44 $ink
for ($i = 12; $i -le 52; $i += 4) {
  Rect $g 10 $i 1 1 $gold
  Rect $g 53 $i 1 1 $gold
  Rect $g $i 10 1 1 $gold
  Rect $g $i 53 1 1 $gold
}
Rect $g 22 22 20 20 $red
Rect $g 26 26 12 12 $gold
Rect $g 12 12 2 2 $slate
Save-Icon $b "microprocessor"

Write-Host "device icons done."

# =========================================================================
# 4. BOARDS
# =========================================================================

# electronic-circuit: brown fiberglass, copper traces, 2 tube cylinders
$b, $g = New-Canvas
RoundRect $g 8 8 48 48 4 $panel
for ($y = 12; $y -le 52; $y += 8) { Line $g 8 $y 56 $y $line }
for ($x = 12; $x -le 52; $x += 8) { Line $g $x 8 $x 56 $line }
Rect $g 20 20 24 24 $ink
Rect $g 22 22 20 20 $gold
Rect $g 26 26 12 12 $panel
Disc $g 18 18 3 $cream
Disc $g 46 18 3 $cream
Save-Icon $b "electronic-circuit"

# advanced-circuit: dark green PCB, SMD chips
$b, $g = New-Canvas
RoundRect $g 8 8 48 48 4 $panel
for ($y = 10; $y -le 54; $y += 6) { Line $g 8 $y 56 $y $line }
for ($x = 10; $x -le 54; $x += 6) { Line $g $x 8 $x 56 $line }
Rect $g 14 14 36 36 $ink
Rect $g 16 16 32 32 $gold
Rect $g 20 20 24 24 $panel
Rect $g 22 22 20 20 $red
Save-Icon $b "advanced-circuit"

# processing-unit: dark blue PCB, microprocessor square
$b, $g = New-Canvas
RoundRect $g 8 8 48 48 4 $panel
for ($y = 8; $y -le 56; $y += 4) { Line $g 8 $y 56 $y $line }
for ($x = 8; $x -le 56; $x += 4) { Line $g $x 8 $x 56 $line }
Rect $g 16 16 32 32 $ink
Rect $g 18 18 28 28 $gold
Rect $g 22 22 20 20 $panel
Rect $g 24 24 16 16 $slate
Save-Icon $b "processing-unit"

# accelerator-board: black PCB, GPU chip, HBM stack, cyan accents
$b, $g = New-Canvas
RoundRect $g 8 8 48 48 4 $panel
Disc $g 32 32 16 $ink
Rect $g 26 26 12 12 $gold
Rect $g 28 28 8 8 $panel
Rect $g 14 14 4 20 $slate
Rect $g 46 14 4 20 $slate
Disc $g 16 32 4 $cream
Disc $g 48 32 4 $cream
Save-Icon $b "accelerator-board"

# neural-board: purple PCB, NPU chip, tensor grid, silver traces
$b, $g = New-Canvas
RoundRect $g 8 8 48 48 4 $panel
Disc $g 32 32 16 $ink
Rect $g 26 26 12 12 $gold
Rect $g 28 28 8 8 $panel
for ($y = 14; $y -le 50; $y += 12) { Line $g 14 $y 50 $y $burnt 1 }
for ($x = 14; $x -le 50; $x += 12) { Line $g $x 14 $x 50 $burnt 1 }
Save-Icon $b "neural-board"

# quantum-board: silver PCB, QPU chip, cryogenic wiring lines
$b, $g = New-Canvas
RoundRect $g 8 8 48 48 4 $panel
Disc $g 32 32 16 $ink
Rect $g 26 26 12 12 $gold
Rect $g 28 28 8 8 $panel
Disc $g 14 14 3 $slate
Disc $g 50 14 3 $slate
Disc $g 14 50 3 $slate
Disc $g 50 50 3 $slate
Line $g 32 32 14 14 $slateL 1
Line $g 32 32 50 14 $slateL 1
Line $g 32 32 14 50 $slateL 1
Line $g 32 32 50 50 $slateL 1
Save-Icon $b "quantum-board"

Write-Host "board icons done."

# =========================================================================
# 5. COMPUTERS (module cards)
# =========================================================================

# microcomputer: green PCB card, chip, 2 RAM sticks, gold edge connector
$b, $g = New-Canvas
RoundRect $g 10 10 44 44 4 $panel
Rect $g 12 12 40 40 $ink
Rect $g 14 14 36 36 $gold
Rect $g 18 18 28 28 $panel
Rect $g 22 22 20 20 $slate
Disc $g 24 24 2 $cream
Disc $g 40 24 2 $cream
Rect $g 16 46 2 4 $gold
Rect $g 46 46 2 4 $gold
Save-Icon $b "microcomputer"

# server: black PCB, chip, 4 RAM sticks, heatsink
$b, $g = New-Canvas
RoundRect $g 10 10 44 44 4 $panel
Rect $g 12 12 40 40 $ink
Rect $g 14 14 36 36 $gold
Rect $g 18 18 28 28 $panel
Rect $g 22 22 20 20 $green
Disc $g 20 20 2 $cream
Disc $g 44 20 2 $cream
Disc $g 20 44 2 $cream
Disc $g 44 44 2 $cream
Rect $g 16 46 2 4 $gold
Rect $g 46 46 2 4 $gold
Save-Icon $b "server"

# supercomputer: black PCB, GPU chip, HBM stack, heat pipes
$b, $g = New-Canvas
RoundRect $g 10 10 44 44 4 $panel
Disc $g 32 32 14 $ink
Rect $g 26 26 12 12 $gold
Rect $g 28 28 8 8 $panel
Rect $g 16 30 3 14 $slate
Rect $g 45 30 3 14 $slate
Disc $g 18 46 4 $cream
Disc $g 46 46 4 $cream
Save-Icon $b "supercomputer"

# neural-computer: purple accents, NPU chip, tensor grid, cyan traces
$b, $g = New-Canvas
RoundRect $g 10 10 44 44 4 $panel
Disc $g 32 32 14 $ink
Rect $g 26 26 12 12 $gold
Rect $g 28 28 8 8 $panel
Line $g 14 14 50 50 $burnt 1
Line $g 14 50 50 14 $burnt 1
Rect $g 16 46 2 4 $gold
Rect $g 46 46 2 4 $gold
Save-Icon $b "neural-computer"

# quantum-computer: silver card, QPU chip, qubit circle, dilution wires
$b, $g = New-Canvas
RoundRect $g 10 10 44 44 4 $panel
Disc $g 32 32 14 $ink
Rect $g 26 26 12 12 $gold
Rect $g 28 28 8 8 $panel
Disc $g 14 14 3 $slate
Disc $g 50 14 3 $slate
Disc $g 14 50 3 $slate
Disc $g 50 50 3 $slate
Line $g 32 32 14 14 $slateL 1
Line $g 32 32 50 50 $slateL 1
Rect $g 16 46 2 4 $gold
Rect $g 46 46 2 4 $gold
Save-Icon $b "quantum-computer"

Write-Host "computer icons done."

# =========================================================================
# 6. AI MODELS
# =========================================================================

# small-model: silver disk with orange AI circuit trace
$b, $g = New-Canvas
ShadedDisc $g 32 32 18 $silver $cream $ink
Disc $g 32 32 6 $ink
Rect $g 30 30 4 4 $orange
Line $g 32 16 32 24 $orange 2
Line $g 32 40 32 48 $orange 2
Line $g 16 32 24 32 $orange 2
Line $g 40 32 48 32 $orange 2
Save-Icon $b "small-model"

# specialist-model: disk with 3 domain slices, red AI trace
$b, $g = New-Canvas
ShadedDisc $g 32 32 18 $silver $cream $ink
Disc $g 32 32 6 $ink
Line $g 32 16 32 48 $red 2
Line $g 16 32 48 32 $red 2
Disc $g 16 32 3 $red
Disc $g 48 32 3 $red
Disc $g 32 16 3 $red
Disc $g 32 48 3 $red
Save-Icon $b "specialist-model"

# general-model: disk with neural nodes connected by lines
$b, $g = New-Canvas
ShadedDisc $g 32 32 18 $silver $cream $ink
Disc $g 32 32 6 $ink
Disc $g 16 16 3 $purple
Disc $g 48 16 3 $purple
Disc $g 16 48 3 $purple
Disc $g 48 48 3 $purple
Line $g 16 16 48 16 $purple 1
Line $g 16 48 48 48 $purple 1
Line $g 32 32 16 16 $purple 1
Line $g 32 32 48 48 $purple 1
Save-Icon $b "general-model"

# frontier-model: disk with cyan quantum nodes, blue AI trace
$b, $g = New-Canvas
ShadedDisc $g 32 32 18 $silver $cream $ink
Disc $g 32 32 6 $ink
Line $g 16 16 48 48 $blue 2
Line $g 16 48 48 16 $blue 2
Rect $g 14 14 4 4 $slate
Rect $g 46 14 4 4 $slate
Rect $g 14 46 4 4 $slate
Rect $g 46 46 4 4 $slate
Rect $g 30 30 4 4 $slate
Save-Icon $b "frontier-model"

# agi-model: disk with gold glowing center, magenta AI trace radiating
$b, $g = New-Canvas
ShadedDisc $g 32 32 18 $silver $cream $ink
Disc $g 32 32 6 $ink
Disc $g 32 32 4 $gold
Line $g 32 32 14 14 $magenta 2
Line $g 32 32 50 14 $magenta 2
Line $g 32 32 14 50 $magenta 2
Line $g 32 32 50 50 $magenta 2
Disc $g 14 14 2 $gold
Disc $g 50 14 2 $gold
Disc $g 14 50 2 $gold
Disc $g 50 50 2 $gold
Save-Icon $b "agi-model"

Write-Host "AI model icons done."

# =========================================================================
# 7. AI BUILDINGS
# =========================================================================

# training-cluster: mini rack with 3 bays and blinking orange LEDs
$b, $g = New-Canvas
RoundRect $g 8 6 48 52 6 $panel
Rect $g 8 6 48 2 $purple
for ($y = 12; $y -le 48; $y += 12) {
  Rect $g 16 $y 32 8 $ink
  Disc $g 20 ($y+4) 2 $cream
  Disc $g 44 ($y+4) 2 $cream
}
Rect $g 18 28 2 2 $orange
Rect $g 44 28 2 2 $orange
Save-Icon $b "training-cluster"

# inference-lab: mini workstation with purple accents + steel tray
$b, $g = New-Canvas
RoundRect $g 8 6 48 52 6 $panel
Rect $g 8 6 48 2 $purple
Rect $g 16 14 32 12 $ink
Rect $g 18 16 28 8 $slateL
Rect $g 24 32 16 6 $steel
Disc $g 28 35 2 $purple
Disc $g 36 35 2 $purple
Rect $g 18 44 28 4 $line
Save-Icon $b "inference-lab"

Write-Host "AI building icons done."

# =========================================================================
# 8. ERA 5-6 FEEDSTOCK & PACKAGES
# =========================================================================

# phase-shift-mask: gold square with purple grid + cyan diagonal
$b, $g = New-Canvas
Rect $g 12 12 40 40 $gold
for ($i = 14; $i -le 50; $i += 6) {
  Line $g $i 12 $i 52 $purple
  Line $g 12 $i 52 $i $purple
}
Line $g 12 52 52 12 $slate
Rect $g 50 24 4 16 $panel
Rect $g 50 28 2 8 $slate
Save-Icon $b "phase-shift-mask"

# cmp-slurry: silver block with cream top + ink dots
$b, $g = New-Canvas
Rect $g 16 18 32 24 $silver
Rect $g 16 18 32 2 $cream
Rect $g 16 42 32 2 $cream
Disc $g 24 28 2 $ink
Disc $g 40 36 2 $ink
Save-Icon $b "cmp-slurry"

# low-k-dielectric: silver layers with cream separators + purple core
$b, $g = New-Canvas
Rect $g 10 14 44 12 $silver
Rect $g 10 14 44 2 $cream
Rect $g 10 38 44 12 $silver
Rect $g 10 38 44 2 $cream
Rect $g 18 22 28 16 $silver
Rect $g 18 22 28 2 $cream
Rect $g 22 26 20 8 $panel
Disc $g 32 30 2 $purple
Save-Icon $b "low-k-dielectric"

# cooling-unit: panel case with cyan slab + ink core
$b, $g = New-Canvas
RoundRect $g 14 14 36 36 4 $panel
Rect $g 16 16 32 32 $slate
Rect $g 18 18 28 28 $ink
Disc $g 32 32 4 $cream
Save-Icon $b "cooling-unit"

# vlsi-wafer: silver wafer with purple grid lines
$b, $g = New-Canvas
ShadedDisc $g 32 32 18 $silver $cream $ink
Disc $g 32 32 2 $steel
for ($i = 16; $i -le 48; $i += 8) {
  Line $g $i 16 $i 48 $purple 1
  Line $g 16 $i 48 $i $purple 1
}
Save-Icon $b "vlsi-wafer"

# vlsi-die: panel square with gold border + cyan array + purple center
$b, $g = New-Canvas
Rect $g 12 12 40 40 $panel
Rect $g 12 12 40 2 $gold
Rect $g 12 52 40 2 $gold
Rect $g 12 12 2 40 $gold
Rect $g 52 12 2 40 $gold
for ($y = 16; $y -le 48; $y += 16) {
  for ($x = 16; $x -le 48; $x += 16) { Rect $g $x $y 4 4 $slate }
}
Rect $g 26 26 12 12 $purple
Save-Icon $b "vlsi-die"

# system-on-chip: ink square, gold pins, cyan/purple blocks
$b, $g = New-Canvas
Rect $g 10 10 44 44 $ink
for ($i = 12; $i -le 52; $i += 4) {
  Rect $g 10 $i 1 1 $gold
  Rect $g 53 $i 1 1 $gold
  Rect $g $i 10 1 1 $gold
  Rect $g $i 53 1 1 $gold
}
Rect $g 14 14 8 8 $slate
Rect $g 42 14 8 8 $purple
Rect $g 14 42 8 8 $panel
Rect $g 42 42 8 8 $gold
Rect $g 26 26 12 12 $gold
Save-Icon $b "system-on-chip"

# chiplet: ink blocks left/right + gold base + cyan/purple dies
$b, $g = New-Canvas
Rect $g 6 12 8 28 $ink
Rect $g 50 12 8 28 $ink
Rect $g 14 48 36 2 $gold
Rect $g 2 49 14 1 $line
Rect $g 8 10 4 10 $slate
Rect $g 18 10 4 6 $purple
Rect $g 30 10 4 10 $slate
Rect $g 40 10 4 6 $purple
Save-Icon $b "chiplet"

# hbm-stack: silver dies with cyan spacers + panel base + gold rails
$b, $g = New-Canvas
for ($i = 0; $i -lt 4; $i++) {
  $y = 10 + $i * 6
  Rect $g 4 $y 8 4 $silver
  Rect $g 52 $y 8 4 $silver
  Rect $g 12 ($y+1) 40 2 $panel
}
Rect $g 8 34 48 6 $panel
Rect $g 2 53 14 1 $gold
Rect $g 48 53 14 1 $gold
Save-Icon $b "hbm-stack"

# gpu: ink card, panel frame, red core, cyan edge pins
$b, $g = New-Canvas
RoundRect $g 10 8 44 48 4 $ink
RoundRect $g 12 10 40 44 4 $panel
Rect $g 14 12 36 36 $red
Rect $g 16 14 32 32 $gold
Rect $g 20 18 24 24 $panel
for ($i = 14; $i -le 50; $i += 6) { Rect $g $i 60 2 2 $slate }
Save-Icon $b "gpu"

# multi-core-cpu: ink chip, cyan corner blocks, gold center, gold edge pins
$b, $g = New-Canvas
Rect $g 10 10 44 44 $ink
Rect $g 14 14 8 8 $slate
Rect $g 42 14 8 8 $slate
Rect $g 14 42 8 8 $slate
Rect $g 42 42 8 8 $slate
Rect $g 26 26 12 12 $gold
for ($i = 12; $i -le 52; $i += 4) {
  Rect $g 10 $i 1 1 $gold
  Rect $g 53 $i 1 1 $gold
  Rect $g $i 10 1 1 $gold
  Rect $g $i 53 1 1 $gold
}
Save-Icon $b "multi-core-cpu"

# vlsi-fab: panel building, cyan side, green doors, gold tab
$b, $g = New-Canvas
Rect $g 10 6 44 46 $panel
Rect $g 10 6 44 2 $line
Rect $g 14 14 8 8 $cyan
Rect $g 42 14 8 8 $cyan
Rect $g 46 12 4 32 $panel
Rect $g 48 16 2 24 $cyan
Rect $g 16 24 32 12 $green
Rect $g 22 36 4 4 $line
Rect $g 38 36 4 4 $line
Rect $g 46 52 4 2 $gold
Save-Icon $b "vlsi-fab"

# cooling-tower: panel tower, silver fan discs, cyan blades
$b, $g = New-Canvas
Rect $g 14 2 36 40 $panel
Rect $g 14 2 36 2 $line
for ($i = 4; $i -le 36; $i += 6) {
  Rect $g 16 $i 32 2 $silver
  Disc $g 18 ($i+2) 1 $cyan
  Disc $g 46 ($i+2) 1 $cyan
}
Rect $g 20 38 8 4 $line
Rect $g 36 38 8 4 $line
Save-Icon $b "cooling-tower"

# datacenter: ink building, panel rows, cyan windows, gold tab
$b, $g = New-Canvas
Rect $g 4 2 56 44 $ink
Rect $g 4 2 56 2 $line
for ($x = 6; $x -le 54; $x += 8) {
  Rect $g $x 6 4 28 $panel
  for ($y = 8; $y -le 30; $y += 6) { Rect $g $x $y 2 2 $cyan }
}
Rect $g 6 34 52 2 $gold
Rect $g 6 2 2 1 $red
Save-Icon $b "datacenter"

Write-Host "era 5-6 icons done."

# =========================================================================
# 9. ERA 7 (QUANTUM)
# =========================================================================

# superconductor: gold disk, ink center, cyan core, silver leads
$b, $g = New-Canvas
ShadedDisc $g 32 32 18 $gold $cream $ink
Disc $g 32 32 8 $ink
Disc $g 32 32 4 $slate
Line $g 32 32 10 32 $silver 2
Line $g 32 32 54 32 $silver 2
Rect $g 8 30 2 4 $steel
Rect $g 54 30 2 4 $steel
Save-Icon $b "superconductor"

# qubit: cyan disk, cream center, purple cross, gold end dots
$b, $g = New-Canvas
Disc $g 32 32 10 $slate
Disc $g 32 32 2 $cream
Line $g 4 32 60 32 $purple
Line $g 32 4 32 60 $purple
Disc $g 6 32 2 $gold
Disc $g 58 32 2 $gold
Save-Icon $b "qubit"

# error-corrected-qubit: 3x3 grid of cyan dots + gold center
$b, $g = New-Canvas
for ($y = 10; $y -le 54; $y += 22) {
  for ($x = 10; $x -le 54; $x += 22) {
    Disc $g $x $y 4 $slate
    Rect $g ($x-1) ($y-1) 1 1 $cream
  }
}
Rect $g 28 28 8 8 $gold
Save-Icon $b "error-corrected-qubit"

# quantum-processor: ink chip, gold pins, purple core, cyan center, cream die
$b, $g = New-Canvas
Rect $g 10 10 44 44 $ink
for ($i = 12; $i -le 52; $i += 4) {
  Rect $g 10 $i 1 1 $gold
  Rect $g 53 $i 1 1 $gold
  Rect $g $i 10 1 1 $gold
  Rect $g $i 53 1 1 $gold
}
Disc $g 32 32 10 $purple
Disc $g 32 32 4 $slate
Rect $g 28 28 8 8 $cream
Save-Icon $b "quantum-processor"

# qubit-array: panel board, gold border, cyan dots grid + cream squares
$b, $g = New-Canvas
RoundRect $g 10 10 44 44 4 $panel
Rect $g 10 10 44 2 $gold
Rect $g 10 54 44 2 $gold
for ($y = 16; $y -le 48; $y += 16) {
  for ($x = 16; $x -le 48; $x += 16) {
    Disc $g $x $y 2 $slate
    Rect $g ($x-1) ($y-1) 1 1 $cream
  }
}
Rect $g 2 54 14 1 $gold
Save-Icon $b "qubit-array"

Write-Host "era 7 icons done."

# =========================================================================
# 10. CUSTOM SCIENCE PACKS
# =========================================================================

# optical-disc: silver disc, panel ring, ink center, cyan line + cyan rect
$b, $g = New-Canvas
ShadedDisc $g 32 32 18 $silver $cream $ink
Disc $g 32 32 10 $panel
Disc $g 32 32 2 $ink
Line $g 32 12 32 20 $slate
Rect $g 42 38 4 4 $slate
Save-Icon $b "optical-disc"

# hbm-science: panel card, cyan lines, silver/gold edges, purple top
$b, $g = New-Canvas
Rect $g 8 12 48 40 $panel
Rect $g 8 12 48 2 $purple
for ($y = 16; $y -le 48; $y += 8) { Rect $g 8 $y 48 1 $slate }
Rect $g 8 16 4 20 $silver
Rect $g 52 16 4 20 $gold
Save-Icon $b "hbm-science"

# quantum-fab: panel building, purple top, silver core, cyan dots
$b, $g = New-Canvas
Rect $g 8 6 48 46 $panel
Rect $g 8 6 48 2 $gold
Rect $g 16 10 32 10 $silver
Rect $g 16 10 32 2 $cream
Disc $g 24 22 2 $slate
Disc $g 40 34 2 $slate
Rect $g 32 34 2 8 $panel
Rect $g 4 12 2 4 $cyan
Rect $g 58 12 2 4 $cyan
Rect $g 6 50 12 1 $line
Save-Icon $b "quantum-fab"

# cryostat: silver cylinder, cream bands, cyans lines, steel top + ink dots
$b, $g = New-Canvas
Rect $g 16 8 32 44 $silver
Rect $g 16 8 32 2 $cream
Rect $g 16 16 32 2 $slate
Rect $g 16 24 32 2 $slate
Rect $g 16 32 32 2 $slate
Rect $g 18 2 28 6 $steel
Disc $g 24 14 1 $ink
Disc $g 38 22 1 $ink
Save-Icon $b "cryostat"

# cryogen: purple block, cream bands, steel top, cyan discs
$b, $g = New-Canvas
Rect $g 16 8 32 36 $purple
Rect $g 16 8 32 2 $cream
Rect $g 16 36 32 2 $cream
Rect $g 20 2 24 6 $steel
Disc $g 28 20 2 $slate
Disc $g 40 32 2 $slate
Rect $g 24 46 16 2 $line
Save-Icon $b "cryogen"

# answer-engine: ink card, gold border, panel screen, "42" in cyan, gold dots
$b, $g = New-Canvas
Rect $g 8 2 48 56 $ink
Rect $g 8 2 48 2 $gold
Rect $g 8 58 48 2 $gold
Rect $g 10 8 44 32 $panel
Rect $g 14 12 2 12 $slate
Rect $g 16 12 2 2 $slate
Rect $g 18 12 2 12 $slate
Rect $g 16 24 4 2 $slate
Rect $g 24 12 6 2 $slate
Rect $g 30 14 2 2 $slate
Rect $g 28 16 2 2 $slate
Rect $g 28 18 2 2 $slate
Rect $g 28 20 6 2 $slate
Rect $g 10 44 2 2 $gold
Rect $g 26 44 2 2 $gold
Rect $g 42 44 2 2 $gold
Rect $g 6 50 12 1 $line
Save-Icon $b "answer-engine"

Write-Host "science pack & endgame icons done."

# =========================================================================
# 11. PROCESS FLUIDS
# =========================================================================

# photoresist: orange block, cream bands, steel top
$b, $g = New-Canvas
Rect $g 16 8 32 36 $orange
Rect $g 16 8 32 2 $cream
Rect $g 16 36 32 2 $cream
Rect $g 20 2 24 6 $steel
Save-Icon $b "photoresist"

# etchant: green block, cream bands, steel top
$b, $g = New-Canvas
Rect $g 16 8 32 36 $green
Rect $g 16 8 32 2 $cream
Rect $g 16 36 32 2 $cream
Rect $g 20 2 24 6 $steel
Save-Icon $b "etchant"

# coolant: cyan block, cream bands, steel top, ink dots
$b, $g = New-Canvas
Rect $g 16 8 32 36 $slate
Rect $g 16 8 32 2 $cream
Rect $g 16 36 32 2 $cream
Rect $g 20 2 24 6 $steel
Disc $g 28 20 2 $ink
Disc $g 40 32 2 $ink
Save-Icon $b "coolant"

Write-Host "process fluid icons done."

# =========================================================================
# 12. MACHINES (item icons)
# =========================================================================

# wafer-fab: panel building, cyan rect, silver disc, steel pipe + green LEDs
$b, $g = New-Canvas
RoundRect $g 8 8 48 40 4 $panel
Rect $g 8 8 48 2 $line
Rect $g 20 16 20 20 $slate
Disc $g 30 26 4 $silver
Rect $g 44 10 4 20 $steel
Rect $g 48 12 2 2 $green
Rect $g 48 16 2 2 $green
Rect $g 8 44 48 2 $line
Save-Icon $b "wafer-fab"

# crystal-puller: panel furnace, silver cylinder, cream band, orange dot
$b, $g = New-Canvas
RoundRect $g 10 8 44 40 4 $panel
Rect $g 10 8 44 2 $line
Rect $g 22 16 20 24 $silver
Rect $g 22 16 20 2 $cream
Disc $g 32 12 2 $orange
Rect $g 8 48 48 2 $line
Save-Icon $b "crystal-puller"

# server-rack: panel case, ink rows with colored dots, line bottom
$b, $g = New-Canvas
Rect $g 8 4 48 56 $ink
Rect $g 8 4 48 2 $line
for ($y = 12; $y -le 48; $y += 12) {
  Rect $g 10 $y 8 2 $cyan
  Rect $g 20 $y 8 2 $green
  Rect $g 30 $y 8 2 $gold
  Rect $g 40 $y 8 2 $steel
}
Rect $g 8 54 48 2 $line
Save-Icon $b "server-rack"

# assembly-fab: panel case, ink blocks left/right, cyan/gold outputs, steel base
$b, $g = New-Canvas
Rect $g 8 4 48 52 $panel
Rect $g 8 4 48 2 $line
Rect $g 10 12 4 16 $ink
Rect $g 50 12 4 16 $ink
Rect $g 14 22 2 4 $slate
Rect $g 48 26 2 4 $gold
Rect $g 10 32 8 4 $line
Rect $g 46 36 8 4 $steel
for ($i = 10; $i -le 50; $i += 4) { Rect $g $i 54 1 1 $steel }
Save-Icon $b "assembly-fab"

# memory-bank: ink left strip, panel right, cyan dots, gold dot
$b, $g = New-Canvas
Rect $g 8 8 24 48 $ink
for ($y = 12; $y -le 44; $y += 8) { Rect $g 10 $y 4 1 $slate }
Rect $g 32 8 24 48 $panel
Rect $g 34 12 4 4 $slate
Rect $g 44 12 2 2 $gold
Rect $g 8 52 48 2 $line
Save-Icon $b "memory-bank"

Write-Host "machine icons done."

# =========================================================================
# 13. MEMORY MODULES
# =========================================================================

$memoryGenerations = @(
  @{ name = "sram-module";   accent = $slate;   rows = 1; pins = 5 }
  @{ name = "dram-module";   accent = $green;   rows = 2; pins = 6 }
  @{ name = "sdram-module";  accent = $slateL;  rows = 2; pins = 6 }
  @{ name = "ddr-module";    accent = $gold;    rows = 2; pins = 6 }
  @{ name = "ddr2-module";   accent = $orange;  rows = 2; pins = 7 }
  @{ name = "ddr3-module";   accent = $red;     rows = 3; pins = 7 }
  @{ name = "ddr4-module";   accent = $purple;  rows = 3; pins = 8 }
  @{ name = "ddr5-module";   accent = $burnt;   rows = 3; pins = 8 }
  @{ name = "hbm-module";    accent = $slate;   rows = 3; pins = 4 }
  @{ name = "hbm3-module";   accent = $green;   rows = 4; pins = 4 }
  @{ name = "3d-nand-module";accent = $gold;    rows = 4; pins = 3 }
)
foreach ($gen in $memoryGenerations) {
  $b, $g = New-Canvas
  Rect $g 2 4 60 52 $ink
  Rect $g 4 6 56 40 $panel
  Rect $g 4 6 56 2 $line
  Rect $g 4 44 56 2 $gen.accent
  # Memory dies: more rows for denser generations.
  for ($r = 0; $r -lt $gen.rows; $r++) {
    $y = 10 + $r * 8
    for ($c = 0; $c -lt 3; $c++) {
      $x = 6 + $c * 14
      Rect $g $x $y 6 4 $silver
      Rect $g ($x + 1) $y 1 1 $gen.accent
    }
  }
  # Contact pins along the bottom edge.
  $step = [Math]::Floor(54 / $gen.pins)
  for ($p = 0; $p -lt $gen.pins; $p++) { Rect $g (4 + $p * $step) 54 1 2 $gold }
  Save-Icon $b $gen.name
}

Write-Host "memory module icons done."

# =========================================================================
# 14. METROLOGY
# =========================================================================

# qualification-wafer: silver wafer, panel ring, crosshair, cyan center
$b, $g = New-Canvas
ShadedDisc $g 32 32 18 $silver $cream $ink
Disc $g 32 32 10 $panel
Rect $g 14 32 36 1 $line
Rect $g 32 14 1 36 $line
Rect $g 28 12 2 1 $slate
Rect $g 48 44 2 1 $gold
Disc $g 32 32 2 $slate
Save-Icon $b "qualification-wafer"

# metrology-test-structure: ink card, panel grid, cyan cross, gold corner + green dot
$b, $g = New-Canvas
Rect $g 4 4 56 56 $ink
Rect $g 4 4 56 2 $line
for ($i = 12; $i -le 52; $i += 8) { Rect $g $i 4 1 44 $line }
Rect $g 4 4 44 1 $line
Rect $g 4 52 44 1 $line
Rect $g 26 4 4 44 $slate
Rect $g 4 26 44 2 $gold
Rect $g 16 16 4 4 $green
Save-Icon $b "metrology-test-structure"

# metrology-lab: ink card, panel screen, cyan block, ink lens + gold/green tabs
$b, $g = New-Canvas
Rect $g 4 4 56 44 $ink
Rect $g 4 4 56 2 $line
Rect $g 8 8 40 24 $panel
Rect $g 26 4 1 24 $ink
Rect $g 8 28 44 2 $ink
Rect $g 8 30 44 10 $steel
Rect $g 14 34 2 4 $gold
Rect $g 48 34 2 4 $green
Save-Icon $b "metrology-lab"

Write-Host "metrology icons done."

# =========================================================================
# 15. QLN NODES & STORAGE
# =========================================================================

# qln-import-node: panel box, ink screen, cyan flow-in, gold side rail + cyan arrow
$b, $g = New-Canvas
Rect $g 4 8 56 40 $panel
Rect $g 4 8 56 2 $line
Rect $g 8 16 32 24 $ink
Rect $g 16 20 12 8 $slate
Poly $g @(8,32,16,20,26,32) $slate
Rect $g 52 8 2 40 $gold
Save-Icon $b "qln-import-node"

# qln-export-node: panel box, ink screen, cyan flow-out, gold side rail + cyan arrow
$b, $g = New-Canvas
Rect $g 4 8 56 40 $panel
Rect $g 4 8 56 2 $line
Rect $g 24 16 32 24 $ink
Rect $g 36 20 12 8 $slate
Poly $g @(8,32,16,20,26,32) $slate
Rect $g 10 8 2 40 $gold
Save-Icon $b "qln-export-node"

# qln-provider-node: panel disk, ink core, green dots + green arrow + gold rails
$b, $g = New-Canvas
ShadedDisc $g 32 32 18 $panel $silver $ink
Disc $g 32 32 10 $ink
Rect $g 26 16 2 6 $green
Rect $g 36 16 2 6 $green
Poly $g @(28,22,32,14,36,22) $green
Rect $g 4 32 2 10 $gold
Rect $g 58 32 2 10 $gold
Save-Icon $b "qln-provider-node"

# qln-requester-node: panel disk, ink core, cyan dots + cyan arrow + gold rails
$b, $g = New-Canvas
ShadedDisc $g 32 32 18 $panel $silver $ink
Disc $g 32 32 10 $ink
Rect $g 26 16 2 6 $slate
Rect $g 36 16 2 6 $slate
Poly $g @(28,26,32,36,36,26) $slate
Rect $g 4 32 2 10 $gold
Rect $g 58 32 2 10 $gold
Save-Icon $b "qln-requester-node"

# qln-terminal: ink card, panel top, cyan line + silver bars + gold tab + line bottom
$b, $g = New-Canvas
Rect $g 4 4 56 50 $ink
Rect $g 4 4 56 2 $line
Rect $g 8 8 48 1 $cyan
Rect $g 8 12 10 1 $silver
Rect $g 8 16 12 1 $silver
Rect $g 8 20 14 1 $silver
Rect $g 48 24 2 8 $gold
Rect $g 4 52 48 2 $line
Save-Icon $b "qln-terminal"

# qln-storage-drive: ink card, panel bands with cyan/green/gold dots
$b, $g = New-Canvas
Rect $g 8 4 48 8 $panel
Rect $g 8 4 48 2 $line
Rect $g 8 12 48 8 $panel
Rect $g 8 12 48 2 $line
Rect $g 8 20 48 8 $panel
Rect $g 8 20 48 2 $line
for ($x = 10; $x -le 50; $x += 10) {
  Rect $g $x 6 2 1 $slate
  Rect $g $x 14 2 1 $green
  Rect $g $x 22 2 1 $gold
}
Rect $g 4 40 14 1 $line
Save-Icon $b "qln-storage-drive"

# construction-core: panel box, ink screen, orange bars, steel corners
$b, $g = New-Canvas
Rect $g 8 8 48 48 4 $panel
Rect $g 8 8 48 2 $line
Rect $g 20 20 24 24 $ink
Rect $g 24 24 16 4 $orange
Rect $g 24 30 16 2 $orange
Rect $g 10 10 4 4 $steel
Rect $g 50 10 4 4 $steel
Rect $g 10 50 4 4 $steel
Rect $g 50 50 4 4 $steel
Save-Icon $b "construction-core"

# quantum-entanglement-core: purple + cyan discs, ink cores, gold center, silver rails
$b, $g = New-Canvas
Disc $g 22 32 10 $purple
Disc $g 42 32 10 $slate
Disc $g 22 32 4 $ink
Disc $g 42 32 4 $ink
Disc $g 32 32 2 $gold
Rect $g 4 30 2 4 $silver
Rect $g 58 30 2 4 $silver
Save-Icon $b "quantum-entanglement-core"

Write-Host "qln icons done."

# =========================================================================
# 16. FOUP & NETWORK EQUIPMENT
# =========================================================================

# foup-dock: panel base, silver carrier, cream top, ink screen, steel sides
$b, $g = New-Canvas
Rect $g 8 40 48 12 $panel
Rect $g 8 40 48 2 $line
Rect $g 20 16 24 20 $silver
Rect $g 20 16 24 2 $cream
Rect $g 22 18 20 4 $ink
Rect $g 24 22 16 2 $slate
Rect $g 6 34 2 6 $steel
Rect $g 56 34 2 6 $steel
Save-Icon $b "foup-dock"

# network-repeater: steel sides, panel center, cyan top, ink dot + gold lines
$b, $g = New-Canvas
Rect $g 4 40 8 2 $steel
Rect $g 52 40 8 2 $steel
Rect $g 12 20 40 4 $panel
Rect $g 12 20 40 2 $cyan
Rect $g 22 12 4 8 $gold
Poly $g @(24,10,28,6,28,10) $gold
Line $g 4 36 2 30 $gold
Line $g 12 36 14 30 $gold
Line $g 52 36 54 30 $gold
Line $g 60 36 58 30 $gold
Save-Icon $b "network-repeater"

# wireless-access-point: steel antenna, panel base, cyan disc + gold broadcast lines
$b, $g = New-Canvas
Rect $g 28 34 8 6 $steel
Rect $g 28 30 8 4 $panel
Disc $g 32 14 4 $slate
Disc $g 32 14 2 $ink
Line $g 4 28 2 20 $gold
Line $g 12 30 14 22 $gold
Line $g 52 30 50 22 $gold
Line $g 60 28 58 20 $gold
Save-Icon $b "wireless-access-point"

# foup: silver carrier, cream top/bottom, panel bands, ink bottom dots + cyan center
$b, $g = New-Canvas
Rect $g 22 4 20 24 $silver
Rect $g 22 4 20 2 $cream
Rect $g 22 26 20 2 $panel
Rect $g 26 28 12 2 $panel
Rect $g 26 30 12 1 $ink
Rect $g 8 38 2 1 $ink
Rect $g 54 38 2 1 $ink
Rect $g 28 10 8 4 $cyan
Save-Icon $b "foup"

# neural-processor: ink card, gold pins, cyan corner dots, gold center + lines
$b, $g = New-Canvas
Rect $g 10 10 44 44 $ink
for ($i = 12; $i -le 52; $i += 4) {
  Rect $g 10 $i 1 1 $gold
  Rect $g 53 $i 1 1 $gold
  Rect $g $i 10 1 1 $gold
  Rect $g $i 53 1 1 $gold
}
Disc $g 14 14 2 $slate
Disc $g 50 14 2 $slate
Disc $g 14 50 2 $slate
Disc $g 50 50 2 $slate
Disc $g 32 14 2 $gold
Disc $g 32 50 2 $gold
Line $g 14 14 32 32 $line
Line $g 32 32 50 50 $line
Save-Icon $b "neural-processor"

Write-Host "foup & network icons done."

# =========================================================================
# 17B. NETWORK CABLES
# =========================================================================

# network-cable: twisted pair, copper/orange pair + black jacket
$b, $g = New-Canvas
Rect $g 10 26 44 12 $orange
Rect $g 10 28 44 8 $burnt
Rect $g 8 24 4 16 $ink
Rect $g 52 24 4 16 $ink
Disc $g 12 32 3 $ink
Disc $g 52 32 3 $ink
Line $g 10 32 54 32 $orange 1
Save-Icon $b "network-cable"

# network-coaxial-cable: thick copper cable, steel shielding, gold center pin
$b, $g = New-Canvas
Rect $g 12 22 40 20 $orange
Rect $g 10 24 44 16 $burnt
Rect $g 26 26 12 12 $steel
Disc $g 32 32 4 $ink
Disc $g 32 32 2 $gold
Rect $g 8 24 2 16 $ink
Rect $g 54 24 2 16 $ink
Save-Icon $b "network-coaxial-cable"

# network-fiber-mm-cable: glass/cyan fiber, panel sheath, ink core
$b, $g = New-Canvas
Rect $g 14 24 36 16 $slate
Rect $g 12 26 40 12 $panel
Rect $g 28 28 8 8 $ink
Disc $g 32 32 2 $cream
Rect $g 8 26 2 12 $ink
Rect $g 54 26 2 12 $ink
Save-Icon $b "network-fiber-mm-cable"

# network-fiber-sm-cable: purple glass fiber, ink sheath, silver core
$b, $g = New-Canvas
Rect $g 14 24 36 16 $purple
Rect $g 12 26 40 12 $ink
Rect $g 28 28 8 8 $silver
Disc $g 32 32 2 $cream
Rect $g 8 26 2 12 $ink
Rect $g 54 26 2 12 $ink
Save-Icon $b "network-fiber-sm-cable"

Write-Host "network cable icons done."

# =========================================================================
# 17C. NETWORK CABLE WORLD SPRITES
# =========================================================================
# Cables are pipe clones, so the engine picks a sprite per connection shape.
# Each sprite below is one tile (64x64 at scale 0.5) and every arm reaches the
# canvas edge so neighbouring tiles join without a seam. The art is a neutral
# grey ribbon; scripts/network.lua tints it per tier.

$cableDir = Join-Path $root "graphics\entity\cable"
New-Item -ItemType Directory -Force -Path $cableDir | Out-Null

$cableEdge = Col "#2b2929"
$cableBody = Col "#a8a8a8"
$cableCore = Col "#e4e4e4"

function Cable-Points([string]$spec) {
  $list = @()
  foreach ($pair in $spec.Split(";")) {
    $xy = $pair.Split(",")
    $list += [System.Drawing.PointF]::new([single]$xy[0], [single]$xy[1])
  }
  return $list
}

function Cable-Band($g, [System.Drawing.PointF[]]$points) {
  $widths = @(20.0, 15.0, 5.0)
  $colours = @($cableEdge, $cableBody, $cableCore)
  for ($i = 0; $i -lt $widths.Count; $i++) {
    $pen = New-Object System.Drawing.Pen -ArgumentList $colours[$i], ([single]$widths[$i])
    $pen.LineJoin = [System.Drawing.Drawing2D.LineJoin]::Round
    $pen.StartCap = [System.Drawing.Drawing2D.LineCap]::Flat
    $pen.EndCap = [System.Drawing.Drawing2D.LineCap]::Flat
    $g.DrawLines($pen, $points)
    $pen.Dispose()
  }
}

# A splice bead where arms meet, and a socket where a run ends.
function Cable-Joint($g, [double]$r, [bool]$socket) {
  Disc $g 32 32 $r $cableEdge
  Disc $g 32 32 ($r - 3) $cableBody
  Disc $g 32 32 ($r - 6) $cableCore
  if ($socket) { Disc $g 32 32 2 $cableEdge }
}

$cableShapes = @(
  @("straight_vertical_single", "32,-4;32,68", "splice"),
  @("straight_vertical", "32,-4;32,68", ""),
  @("straight_horizontal", "-4,32;68,32", ""),
  @("corner_up_right", "32,-4;32,32;68,32", ""),
  @("corner_up_left", "32,-4;32,32;-4,32", ""),
  @("corner_down_right", "32,68;32,32;68,32", ""),
  @("corner_down_left", "32,68;32,32;-4,32", ""),
  @("t_up", "32,32;32,-4|-4,32;68,32", "splice"),
  @("t_down", "32,32;32,68|-4,32;68,32", "splice"),
  @("t_left", "32,32;-4,32|32,-4;32,68", "splice"),
  @("t_right", "32,32;68,32|32,-4;32,68", "splice"),
  @("cross", "32,-4;32,68|-4,32;68,32", "splice"),
  @("ending_up", "32,-4;32,21", "socket"),
  @("ending_down", "32,68;32,43", "socket"),
  @("ending_left", "-4,32;21,32", "socket"),
  @("ending_right", "68,32;43,32", "socket")
)

foreach ($shape in $cableShapes) {
  $bmp = New-Object System.Drawing.Bitmap 64, 64
  $g = [System.Drawing.Graphics]::FromImage($bmp)
  $g.Clear([System.Drawing.Color]::Transparent)
  $g.SmoothingMode = [System.Drawing.Drawing2D.SmoothingMode]::AntiAlias
  $g.PixelOffsetMode = [System.Drawing.Drawing2D.PixelOffsetMode]::Half
  foreach ($sub in $shape[1].Split("|")) { Cable-Band $g (Cable-Points $sub) }
  if ($shape[2] -eq "splice") { Cable-Joint $g 12 $false }
  if ($shape[2] -eq "socket") { Cable-Joint $g 12 $true }
  $bmp.Save((Join-Path $cableDir ($shape[0] + ".png")), [System.Drawing.Imaging.ImageFormat]::Png)
  $g.Dispose(); $bmp.Dispose()
}

# Shape contact sheet so the auto-tiling set can be eyeballed.
$cell = 128
$sheetCols = 4
$sheetRows = 4
$cableSheet = New-Object System.Drawing.Bitmap ($sheetCols * $cell), ($sheetRows * $cell)
$cg = [System.Drawing.Graphics]::FromImage($cableSheet)
$cg.Clear($panel)
$cg.InterpolationMode = [System.Drawing.Drawing2D.InterpolationMode]::NearestNeighbor
$cg.PixelOffsetMode = [System.Drawing.Drawing2D.PixelOffsetMode]::Half
for ($i = 0; $i -lt $cableShapes.Count; $i++) {
  $img = [System.Drawing.Image]::FromFile((Join-Path $cableDir ($cableShapes[$i][0] + ".png")))
  $x = ($i % $sheetCols) * $cell
  $y = [Math]::Floor($i / $sheetCols) * $cell
  $cg.DrawImage($img, $x, $y, $cell, $cell)
  $img.Dispose()
}
$cableSheetPath = Join-Path $env:TEMP "chiptorio-cables.png"
$cableSheet.Save($cableSheetPath, [System.Drawing.Imaging.ImageFormat]::Png)
$cg.Dispose(); $cableSheet.Dispose()

Write-Host "Wrote $($cableShapes.Count) cable sprites to $cableDir"
Write-Host "Cable shape sheet: $cableSheetPath"

# =========================================================================
# 17. CONTACT SHEET
# =========================================================================

$order = @(
  "punched-card", "punched-tape", "magnetic-tape", "disk-pack",
  "solid-state-drive", "mainframe-module", "silica", "glass",
  "metallurgical-silicon", "polysilicon", "monocrystalline-ingot", "silicon-wafer",
  "litho-mask", "exposed-wafer", "etched-wafer", "processed-wafer",
  "bare-die", "vacuum-tube", "discrete-transistor", "integrated-circuit",
  "microprocessor", "photoresist", "etchant", "wafer-fab",
  "crystal-puller", "server-rack", "assembly-fab", "memory-bank",
  "sram-module", "dram-module", "sdram-module", "ddr-module",
  "ddr2-module", "ddr3-module", "ddr4-module", "ddr5-module",
  "hbm-module", "hbm3-module", "3d-nand-module",
  "mainframe-cluster", "phase-shift-mask", "cmp-slurry", "low-k-dielectric",
  "cooling-unit", "vlsi-wafer", "vlsi-die", "system-on-chip",
  "chiplet", "hbm-stack", "gpu", "multi-core-cpu",
  "vlsi-fab", "cooling-tower", "datacenter", "datacenter-lab",
  "coolant", "superconductor", "qubit", "error-corrected-qubit",
  "quantum-processor", "qubit-array", "quantum-fab", "cryostat",
  "cryogen", "answer-engine", "network-cable", "network-coaxial-cable", "network-fiber-mm-cable", "network-fiber-sm-cable", "network-switch",
  "optical-disc", "hbm-science",
  "network-router", "network-monitor",
  "qualification-wafer", "metrology-test-structure", "metrology-lab",
  "qln-import-node", "qln-export-node", "qln-provider-node", "qln-requester-node",
  "qln-terminal", "qln-storage-drive", "construction-core", "quantum-entanglement-core",
  "foup-dock", "network-repeater", "wireless-access-point", "foup",
  "neural-processor",
  "electronic-circuit", "advanced-circuit", "processing-unit",
  "accelerator-board", "neural-board", "quantum-board", "circuit-assembler",
  "microcomputer", "server", "supercomputer", "neural-computer", "quantum-computer", "computer-assembler",
  "small-model", "specialist-model", "general-model", "frontier-model", "agi-model",
  "training-cluster", "inference-lab"
)

$cols = 8
$rows = [int][Math]::Ceiling($order.Count / $cols)
$sheet = New-Object System.Drawing.Bitmap ($cols * 64), ($rows * 64)
$sg = [System.Drawing.Graphics]::FromImage($sheet)
$sheetBg = $ink
$sg.Clear($sheetBg)
for ($i = 0; $i -lt $order.Count; $i++) {
  $img = [System.Drawing.Image]::FromFile((Join-Path $outDir ($order[$i] + ".png")))
  $x = ($i % $cols) * 64
  $y = [Math]::Floor($i / $cols) * 64
  $sg.DrawImage($img, $x, $y, 64, 64)
  $img.Dispose()
}
$sheetPath = Join-Path $env:TEMP "chiptorio-icons.png"
$sheet.Save($sheetPath, [System.Drawing.Imaging.ImageFormat]::Png)
$sg.Dispose(); $sheet.Dispose()

Write-Host "Wrote $($order.Count) icons to $outDir"
Write-Host "Contact sheet: $sheetPath"

# =========================================================================
# 18. TECHNOLOGY ICONS (256x256)
# =========================================================================

$techDir = Join-Path $root "graphics\technology"
New-Item -ItemType Directory -Force -Path $techDir | Out-Null

$techIcons = @{
  "automation-science-pack" = "punched-card"
  "electromechanics"      = "analytical-engine"
  "thermionics"           = "vacuum-tube"
  "semiconductor-physics" = "polysilicon"
  "crystal-growth"        = "monocrystalline-ingot"
  "photolithography"      = "litho-mask"
  "planar-process"        = "integrated-circuit"
  "microarchitecture"     = "microprocessor"
  "process-10um"          = "litho-mask"
  "process-3um"           = "silicon-wafer"
  "process-1um"           = "exposed-wafer"
  "process-350nm"         = "phase-shift-mask"
  "process-180nm"         = "system-on-chip"
  "process-90nm"          = "gpu"
  "process-45nm"          = "hbm-stack"
  "process-22nm"          = "multi-core-cpu"
  "process-14nm"          = "multi-core-cpu"
  "process-7nm"           = "chiplet"
  "process-3nm"           = "quantum-processor"
  "process-1-4nm"         = "qubit-array"
  "internet"              = "network-monitor"
  "vlsi-process"          = "vlsi-die"
  "datacenter"            = "datacenter"
  "advanced-packaging"    = "chiplet"
  "heterogeneous-compute" = "gpu"
  "machine-learning"      = "training-cluster"
  "ai-specialist"         = "specialist-model"
  "ai-general"            = "general-model"
  "ai-frontier"           = "frontier-model"
  "artificial-general-intelligence" = "agi-model"
  "chip-performance"      = "multi-core-cpu"
  "chip-efficiency"       = "cooling-unit"
  "memory-density"        = "3d-nand-module"
  "memory-bandwidth"      = "hbm-stack"
  "network-bandwidth"     = "network-router"
  "cooling-efficiency"    = "cooling-tower"
  "quantum-correction"    = "error-corrected-qubit"
  "quantum-computing"          = "qubit"
  "quantum-error-correction"   = "error-corrected-qubit"
  "quantum-advantage"          = "quantum-processor"
  "the-question"               = "answer-engine"
  "qln"                        = "qln-terminal"
  "qln-quantum"                = "quantum-entanglement-core"
  "refine-6um"                 = "qualification-wafer"
  "refine-1-5um"               = "qualification-wafer"
  "refine-800nm"               = "qualification-wafer"
  "refine-250nm"               = "qualification-wafer"
  "refine-130nm"               = "qualification-wafer"
  "refine-65nm"                = "qualification-wafer"
  "refine-32nm"                = "qualification-wafer"
  "refine-10nm"                = "qualification-wafer"
  "refine-5nm"                 = "qualification-wafer"
  "refine-2nm"                 = "qualification-wafer"
}

foreach ($tech in $techIcons.Keys) {
  $src = [System.Drawing.Image]::FromFile((Join-Path $outDir ($techIcons[$tech] + ".png")))
  $bmp = New-Object System.Drawing.Bitmap 256, 256
  $g = [System.Drawing.Graphics]::FromImage($bmp)
  $g.Clear([System.Drawing.Color]::Transparent)
  $g.InterpolationMode = [System.Drawing.Drawing2D.InterpolationMode]::NearestNeighbor
  $g.PixelOffsetMode = [System.Drawing.Drawing2D.PixelOffsetMode]::Half
  $g.DrawImage($src, 0, 0, 256, 256)
  $bmp.Save((Join-Path $techDir ($tech + ".png")), [System.Drawing.Imaging.ImageFormat]::Png)
  $g.Dispose(); $bmp.Dispose(); $src.Dispose()
}

Write-Host "Wrote technology icons to $techDir"

# =========================================================================
# 19. MOD THUMBNAIL (144x144)
# =========================================================================

$thumb = New-Object System.Drawing.Bitmap 144, 144
$tg = [System.Drawing.Graphics]::FromImage($thumb)
$thumbBg = $ink
$tg.Clear($thumbBg)
$tg.InterpolationMode = [System.Drawing.Drawing2D.InterpolationMode]::NearestNeighbor
$thumbIcons = @("answer-engine", "quantum-processor", "cryostat", "qubit-array")
for ($i = 0; $i -lt 4; $i++) {
  $img = [System.Drawing.Image]::FromFile((Join-Path $outDir ($thumbIcons[$i] + ".png")))
  $x = 4 + ($i % 2) * 72
  $y = 4 + [Math]::Floor($i / 2) * 72
  $tg.DrawImage($img, $x, $y, 64, 64)
  $img.Dispose()
}
$thumb.Save((Join-Path $root "thumbnail.png"), [System.Drawing.Imaging.ImageFormat]::Png)
$tg.Dispose(); $thumb.Dispose()

Write-Host "Wrote thumbnail to $(Join-Path $root 'thumbnail.png')"

# =========================================================================
# 20. VICTORY IMAGE (400x600 portrait)
# =========================================================================

$ending = New-Object System.Drawing.Bitmap 400, 600
$eg = [System.Drawing.Graphics]::FromImage($ending)
$endingBgHex = "#080c12"
$endingBg = Col $endingBgHex
$eg.Clear($endingBg)
$eg.SmoothingMode = [System.Drawing.Drawing2D.SmoothingMode]::AntiAlias

$cGold = Col "#e0b040"
$cTrace = Col "#1d3a46"
$cGlow = Col "#12222b"
$cTitle = Col "#e8dcc0"
$cSmall = Col "#7d8b99"

$goldPen = New-Object System.Drawing.Pen -ArgumentList $cGold, 4
$eg.DrawRectangle($goldPen, 8, 8, 384, 584)
$goldPen.Dispose()

$tracePen = New-Object System.Drawing.Pen -ArgumentList $cTrace, 2
for ($y = 36; $y -le 564; $y += 48) {
  $eg.DrawLine($tracePen, 20, $y, 120, $y)
  $eg.DrawLine($tracePen, 280, $y, 380, $y)
}
$tracePen.Dispose()

$glow = New-Object System.Drawing.SolidBrush -ArgumentList $cGlow
$eg.FillRectangle($glow, 42, 150, 316, 280)
$glow.Dispose()

$center = New-Object System.Drawing.StringFormat
$center.Alignment = [System.Drawing.StringAlignment]::Center
$center.LineAlignment = [System.Drawing.StringAlignment]::Center

$bigFont = New-Object System.Drawing.Font -ArgumentList @("Consolas", [single]200, [System.Drawing.FontStyle]::Bold, [System.Drawing.GraphicsUnit]::Pixel)
$bigBrush = New-Object System.Drawing.SolidBrush -ArgumentList $cGold
$eg.DrawString("42", $bigFont, $bigBrush, (New-Object System.Drawing.RectangleF(0, 150, 400, 280)), $center)
$bigBrush.Dispose(); $bigFont.Dispose()

$titleFont = New-Object System.Drawing.Font -ArgumentList @("Consolas", [single]34, [System.Drawing.FontStyle]::Bold, [System.Drawing.GraphicsUnit]::Pixel)
$titleBrush = New-Object System.Drawing.SolidBrush -ArgumentList $cTitle
$eg.DrawString("THE ANSWER", $titleFont, $titleBrush, (New-Object System.Drawing.RectangleF(0, 440, 400, 50)), $center)
$titleBrush.Dispose(); $titleFont.Dispose()

$smallFont = New-Object System.Drawing.Font -ArgumentList @("Consolas", [single]17, [System.Drawing.FontStyle]::Regular, [System.Drawing.GraphicsUnit]::Pixel)
$smallBrush = New-Object System.Drawing.SolidBrush -ArgumentList $cSmall
$eg.DrawString("42 minutes. Nine workloads. One question.", $smallFont, $smallBrush, (New-Object System.Drawing.RectangleF(0, 500, 400, 30)), $center)
$eg.DrawString("DON'T PANIC", $smallFont, $smallBrush, (New-Object System.Drawing.RectangleF(0, 540, 400, 30)), $center)
$smallBrush.Dispose(); $smallFont.Dispose()
$center.Dispose()

$ending.Save((Join-Path $root "graphics\answer-ending.png"), [System.Drawing.Imaging.ImageFormat]::Png)
$eg.Dispose(); $ending.Dispose()

Write-Host "Wrote victory image to $(Join-Path $root 'graphics/answer-ending.png')"
Write-Host "All graphics generated."

