<#
.SYNOPSIS
  Generates the placeholder pixel-art icon set for Chiptorio.

.DESCRIPTION
  Every icon is drawn at 16x16 and upscaled 4x with nearest-neighbour, which
  gives a consistent chunky look and keeps the source code readable.
  Re-run this after editing the palette or adding new prototypes.
#>

$ErrorActionPreference = "Stop"
Add-Type -AssemblyName System.Drawing

$root = Split-Path -Parent $PSScriptRoot
$outDir = Join-Path $root "graphics\icons"
New-Item -ItemType Directory -Force -Path $outDir | Out-Null

function Col([string]$hex) { [System.Drawing.ColorTranslator]::FromHtml($hex) }

function New-Canvas {
  $bmp = New-Object System.Drawing.Bitmap 16, 16
  $g = [System.Drawing.Graphics]::FromImage($bmp)
  $g.Clear([System.Drawing.Color]::Transparent)
  $g.SmoothingMode = [System.Drawing.Drawing2D.SmoothingMode]::None
  return @($bmp, $g)
}

function Rect($g, [int]$x, [int]$y, [int]$w, [int]$h, [string]$c) {
  $br = New-Object System.Drawing.SolidBrush -ArgumentList (Col $c)
  $g.FillRectangle($br, $x, $y, $w, $h)
  $br.Dispose()
}

function Disc($g, [double]$x, [double]$y, [double]$r, [string]$c) {
  $br = New-Object System.Drawing.SolidBrush -ArgumentList (Col $c)
  $g.FillEllipse($br, [single]($x - $r), [single]($y - $r), [single](2 * $r), [single](2 * $r))
  $br.Dispose()
}

function Line($g, [int]$x1, [int]$y1, [int]$x2, [int]$y2, [string]$c) {
  $p = New-Object System.Drawing.Pen -ArgumentList (Col $c), 1
  $g.DrawLine($p, $x1, $y1, $x2, $y2)
  $p.Dispose()
}

function Poly($g, [int[]]$flat, [string]$c) {
  $points = @()
  for ($i = 0; $i -lt $flat.Count; $i += 2) { $points += New-Object System.Drawing.Point($flat[$i], $flat[$i + 1]) }
  $br = New-Object System.Drawing.SolidBrush -ArgumentList (Col $c)
  $g.FillPolygon($br, $points)
  $br.Dispose()
}

function Save-Icon($bmp, [string]$name) {
  $big = New-Object System.Drawing.Bitmap 64, 64
  $bg = [System.Drawing.Graphics]::FromImage($big)
  $bg.InterpolationMode = [System.Drawing.Drawing2D.InterpolationMode]::NearestNeighbor
  $bg.PixelOffsetMode = [System.Drawing.Drawing2D.PixelOffsetMode]::Half
  $bg.DrawImage($bmp, 0, 0, 64, 64)
  $big.Save((Join-Path $outDir "$name.png"), [System.Drawing.Imaging.ImageFormat]::Png)
  $bg.Dispose(); $big.Dispose(); $bmp.Dispose()
}

# palette
$ink    = "#0c1116"
$panel  = "#1a2430"
$line   = "#33475a"
$cyan   = "#45e0c0"
$gold   = "#e0b040"
$red    = "#e05555"
$green  = "#4fbf6a"
$silver = "#b9c6d4"
$steel  = "#7d8b99"
$cream  = "#e8dcc0"
$brown  = "#8a5a3a"
$purple = "#9a6ee0"
$orange = "#e08a3a"

# --- storage media -----------------------------------------------------

$b, $g = New-Canvas
Rect $g 2 3 12 10 $cream
Rect $g 2 3 12 1 $steel
for ($y = 5; $y -le 11; $y += 2) {
  for ($x = 4; $x -le 12; $x += 2) {
    if (($x + $y) % 4 -eq 0) { Rect $g $x $y 1 1 $ink }
  }
}
Save-Icon $b "punched-card"

$b, $g = New-Canvas
Rect $g 1 5 14 6 $brown
Rect $g 1 5 14 1 $cream
for ($x = 2; $x -le 14; $x += 2) { Rect $g $x 6 1 1 $ink; Rect $g $x 9 1 1 $ink }
Save-Icon $b "punched-tape"

$b, $g = New-Canvas
Disc $g 8 7 6 $panel
Disc $g 8 7 2 $ink
Disc $g 8 7 1 $gold
Rect $g 3 13 10 2 $brown
Rect $g 3 13 10 1 $cream
Save-Icon $b "magnetic-tape"

$b, $g = New-Canvas
Disc $g 8 8 6 $silver
Disc $g 8 8 2 $ink
Disc $g 8 8 1 $gold
Line $g 8 8 13 4 $steel
Save-Icon $b "disk-pack"

$b, $g = New-Canvas
Rect $g 2 4 12 8 $ink
Rect $g 3 5 10 3 $cyan
Rect $g 3 9 10 1 $line
Rect $g 3 11 10 1 $gold
Save-Icon $b "solid-state-drive"

$b, $g = New-Canvas
Rect $g 2 2 12 12 $green
Rect $g 2 2 12 1 $gold
Rect $g 4 4 3 3 $panel
Rect $g 8 4 3 3 $panel
Rect $g 4 9 7 3 $panel
Rect $g 4 4 1 1 $cyan
Save-Icon $b "mainframe-module"

# --- silicon -----------------------------------------------------------

$b, $g = New-Canvas
Poly $g @(1,14,3,10,6,9,7,14) $cream
Disc $g 9 12 3 $cream
Disc $g 13 12 2 $cream
Rect $g 3 13 10 1 $steel
Save-Icon $b "silica"

$b, $g = New-Canvas
Poly $g @(3,13,5,3,13,4,11,13) $cyan
Line $g 6 5 6 9 $ink
Line $g 8 5 8 10 $ink
Save-Icon $b "glass"

$b, $g = New-Canvas
Poly $g @(2,13,4,6,8,5,9,9,6,13) $steel
Poly $g @(8,13,10,7,13,8,12,13) $line
Rect $g 4 8 2 1 $silver
Save-Icon $b "metallurgical-silicon"

$b, $g = New-Canvas
Poly $g @(2,12,4,4,11,3,13,8,10,12) $silver
Line $g 5 6 5 10 $cream
Line $g 7 4 7 9 $cream
Rect $g 11 5 1 1 $cyan
Save-Icon $b "polysilicon"

$b, $g = New-Canvas
Poly $g @(2,11,5,5,13,4,14,8,11,12,4,12) $silver
Poly $g @(5,10,7,6,11,5,12,8) $steel
Line $g 6 8 10 7 $cream
Save-Icon $b "monocrystalline-ingot"

$b, $g = New-Canvas
Disc $g 8 8 6 $silver
Disc $g 8 8 1 $steel
Rect $g 7 13 2 1 $ink
Line $g 4 6 4 9 $cream
Line $g 5 4 5 6 $cream
Save-Icon $b "silicon-wafer"

$b, $g = New-Canvas
Rect $g 3 3 10 10 $gold
for ($i = 5; $i -le 11; $i += 2) {
  Line $g $i 4 $i 12 $ink
  Line $g 4 $i 12 $i $ink
}
Rect $g 12 6 2 4 $panel
Rect $g 12 7 1 1 $cyan
Save-Icon $b "litho-mask"

$b, $g = New-Canvas
Disc $g 8 8 6 $silver
Line $g 4 8 12 8 $purple
Line $g 8 4 8 12 $purple
Disc $g 8 8 1 $steel
Save-Icon $b "exposed-wafer"

$b, $g = New-Canvas
Disc $g 8 8 6 $silver
Line $g 4 8 12 8 $cyan
Line $g 8 4 8 12 $cyan
Disc $g 8 8 1 $steel
Save-Icon $b "etched-wafer"

$b, $g = New-Canvas
Disc $g 8 8 6 $silver
Line $g 4 8 12 8 $gold
Line $g 8 4 8 12 $gold
Disc $g 8 8 1 $steel
Save-Icon $b "processed-wafer"

$b, $g = New-Canvas
Rect $g 3 3 10 10 $panel
Rect $g 3 3 10 1 $gold
Rect $g 3 12 10 1 $gold
Rect $g 4 4 3 3 $cyan
Rect $g 9 4 3 3 $cyan
Rect $g 4 9 3 3 $cyan
Rect $g 9 9 3 3 $cyan
Save-Icon $b "bare-die"

# --- devices -----------------------------------------------------------

$b, $g = New-Canvas
Poly $g @(5,11,5,5,6,2,10,2,11,5,11,11) $cyan
Line $g 7 4 8 8 $orange
Line $g 8 8 9 4 $orange
Rect $g 5 11 6 3 $steel
Rect $g 5 14 1 1 $ink
Rect $g 8 14 1 1 $ink
Rect $g 10 14 1 1 $ink
Save-Icon $b "vacuum-tube"

$b, $g = New-Canvas
Disc $g 8 7 5 $ink
Rect $g 8 11 1 4 $steel
Rect $g 5 13 1 2 $steel
Rect $g 10 13 1 2 $steel
Rect $g 6 5 1 1 $green
Save-Icon $b "discrete-transistor"

$b, $g = New-Canvas
Rect $g 3 3 10 10 $ink
for ($y = 4; $y -le 11; $y += 2) {
  Rect $g 1 $y 2 1 $gold
  Rect $g 13 $y 2 1 $gold
}
Rect $g 4 4 1 1 $cyan
Rect $g 7 7 2 2 $panel
Save-Icon $b "integrated-circuit"

$b, $g = New-Canvas
Rect $g 2 2 12 12 $ink
for ($i = 4; $i -le 11; $i += 2) {
  Rect $g 1 $i 1 1 $gold
  Rect $g 14 $i 1 1 $gold
  Rect $g $i 1 1 1 $gold
  Rect $g $i 14 1 1 $gold
}
Rect $g 6 6 4 4 $red
Rect $g 7 7 2 2 $gold
Rect $g 3 3 1 1 $cyan
Save-Icon $b "microprocessor"

# --- era 5-6 -----------------------------------------------------------

$b, $g = New-Canvas
Rect $g 3 3 10 10 $gold
for ($i = 5; $i -le 11; $i += 3) {
  Line $g $i 4 $i 12 $purple
  Line $g 4 $i 12 $i $purple
}
Line $g 3 12 12 3 $cyan
Rect $g 12 6 2 4 $panel
Rect $g 12 7 1 1 $cyan
Save-Icon $b "phase-shift-mask"

$b, $g = New-Canvas
Rect $g 4 4 8 9 $silver
Rect $g 4 5 8 1 $cream
Rect $g 4 9 8 1 $cream
Rect $g 5 2 6 2 $steel
Rect $g 5 7 6 3 $steel
Disc $g 6 8 1 $ink
Disc $g 10 10 1 $ink
Save-Icon $b "cmp-slurry"

$b, $g = New-Canvas
Rect $g 2 4 12 2 $silver
Rect $g 2 7 12 2 $cyan
Rect $g 2 10 12 2 $silver
Rect $g 2 4 12 1 $cream
Rect $g 5 7 2 2 $purple
Rect $g 9 10 3 2 $panel
Save-Icon $b "low-k-dielectric"

$b, $g = New-Canvas
Rect $g 3 3 10 10 $panel
for ($y = 4; $y -le 11; $y += 2) { Rect $g 4 $y 8 1 $silver }
Rect $g 2 5 1 6 $cyan
Rect $g 13 5 1 6 $cyan
Disc $g 8 8 2 $cyan
Rect $g 7 7 2 2 $ink
Save-Icon $b "cooling-unit"

$b, $g = New-Canvas
Disc $g 8 8 6 $silver
for ($i = 5; $i -le 11; $i += 2) {
  Line $g $i 3 $i 13 $purple
  Line $g 3 $i 13 $i $purple
}
Disc $g 8 8 1 $steel
Save-Icon $b "vlsi-wafer"

$b, $g = New-Canvas
Rect $g 2 2 12 12 $panel
Rect $g 2 2 12 1 $gold
Rect $g 2 13 12 1 $gold
for ($y = 4; $y -le 10; $y += 2) {
  for ($x = 4; $x -le 10; $x += 2) { Rect $g $x $y 1 1 $cyan }
}
Rect $g 4 4 2 2 $purple
Save-Icon $b "vlsi-die"

$b, $g = New-Canvas
Rect $g 2 2 12 12 $ink
for ($i = 3; $i -le 12; $i += 2) {
  Rect $g 1 $i 1 1 $gold
  Rect $g 14 $i 1 1 $gold
}
Rect $g 4 4 3 3 $cyan
Rect $g 9 4 3 3 $purple
Rect $g 4 9 8 2 $panel
Rect $g 7 7 2 2 $gold
Save-Icon $b "system-on-chip"

$b, $g = New-Canvas
Rect $g 2 4 5 8 $ink
Rect $g 9 4 5 8 $ink
Rect $g 3 5 3 2 $cyan
Rect $g 10 5 3 2 $purple
Rect $g 2 12 12 1 $gold
Rect $g 1 13 14 1 $line
Save-Icon $b "chiplet"

$b, $g = New-Canvas
for ($i = 3; $i -le 9; $i += 2) { Rect $g 4 $i 8 1 $silver }
Rect $g 3 10 10 3 $panel
Rect $g 4 11 8 1 $cyan
Line $g 2 3 2 12 $gold
Line $g 13 3 13 12 $gold
Save-Icon $b "hbm-stack"

$b, $g = New-Canvas
Rect $g 2 2 12 12 $ink
Rect $g 3 3 10 10 $panel
Rect $g 5 5 6 6 $red
Rect $g 6 6 4 4 $gold
for ($i = 4; $i -le 11; $i += 2) {
  Rect $g 1 $i 1 1 $cyan
  Rect $g 14 $i 1 1 $cyan
}
Rect $g 4 12 8 1 $silver
Save-Icon $b "gpu"

$b, $g = New-Canvas
Rect $g 2 2 12 12 $ink
Rect $g 4 4 3 3 $cyan
Rect $g 9 4 3 3 $cyan
Rect $g 4 9 3 3 $cyan
Rect $g 9 9 3 3 $cyan
Rect $g 7 7 2 2 $gold
for ($i = 3; $i -le 12; $i += 2) {
  Rect $g 1 $i 1 1 $gold
  Rect $g 14 $i 1 1 $gold
}
Save-Icon $b "multi-core-cpu"

$b, $g = New-Canvas
Rect $g 2 3 12 10 $panel
Rect $g 2 3 12 1 $purple
Rect $g 4 5 4 4 $cyan
Disc $g 6 7 2 $silver
Rect $g 9 4 3 8 $panel
Rect $g 9 5 1 1 $red
Rect $g 11 5 1 1 $cyan
Rect $g 9 8 1 1 $green
Rect $g 11 8 1 1 $gold
Rect $g 3 12 10 1 $line
Save-Icon $b "vlsi-fab"

$b, $g = New-Canvas
Rect $g 3 2 10 12 $panel
Rect $g 3 2 10 1 $line
for ($i = 4; $i -le 10; $i += 3) {
  Rect $g 4 $i 8 1 $silver
  Disc $g 6 $i 1 $cyan
  Disc $g 10 $i 1 $cyan
}
Rect $g 5 12 6 2 $line
Rect $g 7 3 2 1 $cyan
Save-Icon $b "cooling-tower"

$b, $g = New-Canvas
Rect $g 1 2 14 12 $ink
Rect $g 1 2 14 1 $line
for ($x = 2; $x -le 11; $x += 3) {
  Rect $g $x 4 2 8 $panel
  for ($y = 5; $y -le 10; $y += 2) { Rect $g $x $y 1 1 $cyan }
}
Rect $g 3 12 10 1 $gold
Rect $g 3 1 2 1 $red
Save-Icon $b "datacenter"

# --- era 7 -------------------------------------------------------------

$b, $g = New-Canvas
Disc $g 8 8 6 $gold
Disc $g 8 8 3 $ink
Disc $g 8 8 2 $cyan
Line $g 3 8 1 8 $silver
Line $g 13 8 15 8 $silver
Rect $g 1 7 1 2 $steel
Rect $g 14 7 1 2 $steel
Save-Icon $b "superconductor"

$b, $g = New-Canvas
Disc $g 8 8 3 $cyan
Disc $g 8 8 1 $cream
Line $g 2 8 14 8 $purple
Line $g 8 2 8 14 $purple
Disc $g 3 8 1 $gold
Disc $g 13 8 1 $gold
Save-Icon $b "qubit"

$b, $g = New-Canvas
for ($y = 3; $y -le 13; $y += 5) {
  for ($x = 3; $x -le 13; $x += 5) {
    Disc $g $x $y 2 $cyan
    Rect $g ($x - 1) ($y - 1) 1 1 $cream
  }
}
Rect $g 7 7 2 2 $gold
Save-Icon $b "error-corrected-qubit"

$b, $g = New-Canvas
Rect $g 2 2 12 12 $ink
for ($i = 4; $i -le 11; $i += 2) {
  Rect $g 1 $i 1 1 $gold
  Rect $g 14 $i 1 1 $gold
  Rect $g $i 1 1 1 $gold
  Rect $g $i 14 1 1 $gold
}
Disc $g 8 8 4 $purple
Disc $g 8 8 2 $cyan
Rect $g 7 7 2 2 $cream
Save-Icon $b "quantum-processor"

$b, $g = New-Canvas
Rect $g 2 2 12 12 $panel
Rect $g 2 2 12 1 $gold
for ($y = 4; $y -le 10; $y += 3) {
  for ($x = 4; $x -le 10; $x += 3) {
    Disc $g $x $y 1 $cyan
    Rect $g ($x - 1) ($y - 1) 1 1 $cream
  }
}
Rect $g 2 13 12 1 $gold
Save-Icon $b "qubit-array"

$b, $g = New-Canvas
Rect $g 2 3 12 10 $panel
Rect $g 2 3 12 1 $purple
Rect $g 4 5 4 6 $silver
Rect $g 4 5 4 1 $cream
Rect $g 4 9 4 1 $cream
Disc $g 6 7 1 $cyan
Rect $g 9 4 3 8 $panel
Rect $g 9 5 1 1 $cyan
Rect $g 11 5 1 1 $purple
Rect $g 9 8 1 1 $red
Rect $g 11 8 1 1 $gold
Rect $g 3 12 10 1 $line
Save-Icon $b "quantum-fab"

$b, $g = New-Canvas
Rect $g 4 2 8 12 $silver
Rect $g 4 2 8 1 $cream
Rect $g 4 5 8 1 $cyan
Rect $g 4 8 8 1 $cyan
Rect $g 4 11 8 1 $cyan
Rect $g 5 1 6 1 $steel
Disc $g 8 13 2 $panel
Rect $g 5 6 1 1 $ink
Rect $g 10 7 1 1 $ink
Save-Icon $b "cryostat"

$b, $g = New-Canvas
Rect $g 4 4 8 9 $purple
Rect $g 4 5 8 1 $cream
Rect $g 4 9 8 1 $cream
Rect $g 5 2 6 2 $steel
Disc $g 7 7 1 $cyan
Disc $g 10 9 1 $cyan
Rect $g 6 12 4 1 $line
Save-Icon $b "cryogen"

# --- endgame -----------------------------------------------------------

$b, $g = New-Canvas
Rect $g 2 1 12 14 $ink
Rect $g 2 1 12 1 $gold
Rect $g 2 14 12 1 $gold
Rect $g 3 3 10 8 $panel
# "42" on the display
Rect $g 4 4 1 4 $cyan
Rect $g 5 4 1 1 $cyan
Rect $g 6 4 1 4 $cyan
Rect $g 5 8 2 1 $cyan
Rect $g 8 4 3 1 $cyan
Rect $g 10 5 1 1 $cyan
Rect $g 9 6 1 1 $cyan
Rect $g 8 7 1 1 $cyan
Rect $g 8 8 3 1 $cyan
Rect $g 4 11 1 1 $gold
Rect $g 7 11 1 1 $gold
Rect $g 10 11 1 1 $gold
Rect $g 3 12 10 1 $line
Save-Icon $b "answer-engine"

# --- process fluids ----------------------------------------------------

$b, $g = New-Canvas
Rect $g 4 4 8 9 $orange
Rect $g 4 5 8 1 $cream
Rect $g 4 9 8 1 $cream
Rect $g 5 2 6 2 $steel
Save-Icon $b "photoresist"

$b, $g = New-Canvas
Rect $g 4 4 8 9 $green
Rect $g 4 5 8 1 $cream
Rect $g 4 9 8 1 $cream
Rect $g 5 2 6 2 $steel
Save-Icon $b "etchant"

$b, $g = New-Canvas
Rect $g 4 4 8 9 $cyan
Rect $g 4 5 8 1 $cream
Rect $g 4 9 8 1 $cream
Rect $g 5 2 6 2 $steel
Disc $g 7 7 1 $ink
Disc $g 10 9 1 $ink
Save-Icon $b "coolant"

# --- machines ----------------------------------------------------------

$b, $g = New-Canvas
Rect $g 2 3 12 10 $panel
Rect $g 2 3 12 1 $line
Rect $g 4 5 5 5 $cyan
Disc $g 6 7 2 $silver
Rect $g 10 4 1 8 $steel
Rect $g 11 4 1 1 $green
Rect $g 11 6 1 1 $green
Rect $g 3 11 10 1 $line
Save-Icon $b "wafer-fab"

$b, $g = New-Canvas
Rect $g 3 2 10 12 $panel
Rect $g 3 2 10 1 $line
Rect $g 5 8 6 5 $silver
Rect $g 5 8 6 1 $cream
Rect $g 7 2 2 7 $silver
Disc $g 8 4 1 $orange
Rect $g 3 13 10 1 $line
Save-Icon $b "crystal-puller"

$b, $g = New-Canvas
Rect $g 3 1 10 14 $panel
Rect $g 3 1 10 1 $line
for ($y = 3; $y -le 11; $y += 3) {
  Rect $g 4 $y 8 2 $ink
  Rect $g 5 $y 1 1 $cyan
  Rect $g 7 $y 1 1 $green
  Rect $g 9 $y 1 1 $gold
}
Rect $g 9 12 3 2 $line
Save-Icon $b "server-rack"

# --- computers ---------------------------------------------------------

$b, $g = New-Canvas
Disc $g 6 6 4 $gold
Disc $g 6 6 1 $ink
Disc $g 11 11 3 $steel
Disc $g 11 11 1 $ink
Rect $g 1 14 14 1 $line
Rect $g 2 2 1 1 $cream
Save-Icon $b "analytical-engine"

$b, $g = New-Canvas
Rect $g 2 2 12 12 $panel
Rect $g 3 4 3 6 $orange
Rect $g 8 4 3 6 $orange
Rect $g 3 3 3 1 $cream
Rect $g 8 3 3 1 $cream
Rect $g 3 11 8 2 $ink
Rect $g 4 12 2 1 $cyan
Save-Icon $b "tube-mainframe"

$b, $g = New-Canvas
Rect $g 2 2 12 12 $ink
Rect $g 2 2 12 1 $line
for ($y = 4; $y -le 9; $y += 2) {
  Rect $g 3 $y 10 1 $panel
  Rect $g 4 $y 1 1 $cyan
  Rect $g 6 $y 1 1 $green
}
Rect $g 3 12 4 1 $gold
Rect $g 8 12 4 1 $line
Save-Icon $b "mainframe-cluster"

# --- contact sheet -----------------------------------------------------

$order = @(
  "punched-card", "punched-tape", "magnetic-tape", "disk-pack",
  "solid-state-drive", "mainframe-module", "silica", "glass",
  "metallurgical-silicon", "polysilicon", "monocrystalline-ingot", "silicon-wafer",
  "litho-mask", "exposed-wafer", "etched-wafer", "processed-wafer",
  "bare-die", "vacuum-tube", "discrete-transistor", "integrated-circuit",
  "microprocessor", "photoresist", "etchant", "wafer-fab",
  "crystal-puller", "server-rack", "analytical-engine", "tube-mainframe",
  "mainframe-cluster", "phase-shift-mask", "cmp-slurry", "low-k-dielectric",
  "cooling-unit", "vlsi-wafer", "vlsi-die", "system-on-chip",
  "chiplet", "hbm-stack", "gpu", "multi-core-cpu",
  "vlsi-fab", "cooling-tower", "datacenter", "coolant",
  "superconductor", "qubit", "error-corrected-qubit", "quantum-processor",
  "qubit-array", "quantum-fab", "cryostat", "cryogen",
  "answer-engine"
)

$cols = 8
$rows = [int][Math]::Ceiling($order.Count / $cols)
$sheet = New-Object System.Drawing.Bitmap ($cols * 64), ($rows * 64)
$sg = [System.Drawing.Graphics]::FromImage($sheet)
$sg.Clear([System.Drawing.ColorTranslator]::FromHtml("#0c1116"))
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

# --- technology icons (256x256, nearest-neighbour upscale) --------------

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
  "vlsi-process"          = "vlsi-die"
  "datacenter"            = "datacenter"
  "advanced-packaging"    = "chiplet"
  "heterogeneous-compute" = "gpu"
  "quantum-computing"          = "qubit"
  "quantum-error-correction"   = "error-corrected-qubit"
  "quantum-advantage"          = "quantum-processor"
  "the-question"               = "answer-engine"
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

# --- mod thumbnail (144x144) -------------------------------------------

$thumb = New-Object System.Drawing.Bitmap 144, 144
$tg = [System.Drawing.Graphics]::FromImage($thumb)
$tg.Clear([System.Drawing.ColorTranslator]::FromHtml("#0c1116"))
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

# --- victory image (400x600 portrait) ----------------------------------

$ending = New-Object System.Drawing.Bitmap 400, 600
$eg = [System.Drawing.Graphics]::FromImage($ending)
$eg.Clear((Col "#080c12"))
$eg.SmoothingMode = [System.Drawing.Drawing2D.SmoothingMode]::AntiAlias

$goldPen = New-Object System.Drawing.Pen -ArgumentList (Col "#e0b040"), 4
$eg.DrawRectangle($goldPen, 8, 8, 384, 584)
$goldPen.Dispose()

$tracePen = New-Object System.Drawing.Pen -ArgumentList (Col "#1d3a46"), 2
for ($y = 36; $y -le 564; $y += 48) {
  $eg.DrawLine($tracePen, 20, $y, 120, $y)
  $eg.DrawLine($tracePen, 280, $y, 380, $y)
}
$tracePen.Dispose()

$glow = New-Object System.Drawing.SolidBrush -ArgumentList (Col "#12222b")
$eg.FillRectangle($glow, 42, 150, 316, 280)
$glow.Dispose()

$center = New-Object System.Drawing.StringFormat
$center.Alignment = [System.Drawing.StringAlignment]::Center
$center.LineAlignment = [System.Drawing.StringAlignment]::Center

$bigFont = New-Object System.Drawing.Font -ArgumentList @("Consolas", [single]200, [System.Drawing.FontStyle]::Bold, [System.Drawing.GraphicsUnit]::Pixel)
$bigBrush = New-Object System.Drawing.SolidBrush -ArgumentList (Col "#e0b040")
$eg.DrawString("42", $bigFont, $bigBrush, (New-Object System.Drawing.RectangleF(0, 150, 400, 280)), $center)
$bigBrush.Dispose(); $bigFont.Dispose()

$titleFont = New-Object System.Drawing.Font -ArgumentList @("Consolas", [single]34, [System.Drawing.FontStyle]::Bold, [System.Drawing.GraphicsUnit]::Pixel)
$titleBrush = New-Object System.Drawing.SolidBrush -ArgumentList (Col "#e8dcc0")
$eg.DrawString("THE ANSWER", $titleFont, $titleBrush, (New-Object System.Drawing.RectangleF(0, 440, 400, 50)), $center)
$titleBrush.Dispose(); $titleFont.Dispose()

$smallFont = New-Object System.Drawing.Font -ArgumentList @("Consolas", [single]17, [System.Drawing.FontStyle]::Regular, [System.Drawing.GraphicsUnit]::Pixel)
$smallBrush = New-Object System.Drawing.SolidBrush -ArgumentList (Col "#7d8b99")
$eg.DrawString("42 minutes. Seven workloads. One question.", $smallFont, $smallBrush, (New-Object System.Drawing.RectangleF(0, 500, 400, 30)), $center)
$eg.DrawString("DON'T PANIC", $smallFont, $smallBrush, (New-Object System.Drawing.RectangleF(0, 540, 400, 30)), $center)
$smallBrush.Dispose(); $smallFont.Dispose()
$center.Dispose()

$ending.Save((Join-Path $root "graphics\answer-ending.png"), [System.Drawing.Imaging.ImageFormat]::Png)
$eg.Dispose(); $ending.Dispose()

Write-Host "Wrote technology icons to $techDir"
Write-Host "Wrote thumbnail to $(Join-Path $root 'thumbnail.png')"
Write-Host "Wrote victory image to $(Join-Path $root 'graphics/answer-ending.png')"
