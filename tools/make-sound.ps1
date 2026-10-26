<#
.SYNOPSIS
  Generates the short chiptune fanfare played when The Answer Engine finishes.

.DESCRIPTION
  Synthesises a square-wave arpeggio into a temporary WAV, then asks ffmpeg to
  encode it as OGG Vorbis. No external sample is required, so the sound can be
  rebuilt from source like the icons.
#>

$ErrorActionPreference = "Stop"

$root = Split-Path -Parent $PSScriptRoot
$soundDir = Join-Path $root "sound"
New-Item -ItemType Directory -Force -Path $soundDir | Out-Null

$ffmpeg = (Get-Command ffmpeg -ErrorAction SilentlyContinue).Source
if (-not $ffmpeg) {
  throw "ffmpeg not found on PATH; install it or copy an OGG into sound/answer-fanfare.ogg"
}

$sampleRate = 44100
$samples = New-Object System.Collections.Generic.List[double]

function Add-Tone([double]$frequency, [double]$seconds, [double]$amplitude) {
  $count = [int]($seconds * $sampleRate)
  $attack = [Math]::Min(220, [int]($count * 0.08))
  $release = [Math]::Min(1300, [int]($count * 0.20))
  for ($i = 0; $i -lt $count; $i++) {
    $phase = 2.0 * [Math]::PI * $frequency * ($i / $sampleRate)
    $square = if ([Math]::Sin($phase) -ge 0) { 1.0 } else { -1.0 }
    $sine = [Math]::Sin($phase)
    $envelope = 1.0
    if ($i -lt $attack) { $envelope = $i / [double]$attack }
    elseif ($i -gt ($count - $release)) { $envelope = ($count - $i) / [double]$release }
    $samples.Add(($square * 0.55 + $sine * 0.45) * $amplitude * $envelope)
  }
}

# Rising arpeggio, a short answer-like pause, then a held major chord.
Add-Tone 523.25 0.14 0.34
Add-Tone 659.25 0.14 0.34
Add-Tone 783.99 0.14 0.34
Add-Tone 1046.50 0.26 0.34
Add-Tone 783.99 0.12 0.30
Add-Tone 1046.50 0.12 0.30
Add-Tone 1318.51 0.16 0.32

$chordStart = $samples.Count
Add-Tone 1046.50 1.10 0.22
$chordEnd = $samples.Count
$second = New-Object System.Collections.Generic.List[double]
for ($i = 0; $i -lt ($chordEnd - $chordStart); $i++) {
  $phase = 2.0 * [Math]::PI * 659.25 * ($i / $sampleRate)
  $second.Add([Math]::Sin($phase) * 0.13)
}
for ($i = 0; $i -lt $second.Count; $i++) {
  $samples[$chordStart + $i] = $samples[$chordStart + $i] + $second[$i]
}
$third = New-Object System.Collections.Generic.List[double]
for ($i = 0; $i -lt ($chordEnd - $chordStart); $i++) {
  $phase = 2.0 * [Math]::PI * 783.99 * ($i / $sampleRate)
  $third.Add([Math]::Sin($phase) * 0.11)
}
for ($i = 0; $i -lt $third.Count; $i++) {
  $samples[$chordStart + $i] = $samples[$chordStart + $i] + $third[$i]
}

$tempWav = Join-Path $env:TEMP "chiptorio-answer-fanfare.wav"
$stream = [System.IO.File]::Open($tempWav, [System.IO.FileMode]::Create)
$writer = New-Object System.IO.BinaryWriter($stream)
$dataSize = $samples.Count * 2
$writer.Write([System.Text.Encoding]::ASCII.GetBytes("RIFF"))
$writer.Write([int](36 + $dataSize))
$writer.Write([System.Text.Encoding]::ASCII.GetBytes("WAVE"))
$writer.Write([System.Text.Encoding]::ASCII.GetBytes("fmt "))
$writer.Write([int]16)
$writer.Write([int16]1)
$writer.Write([int16]1)
$writer.Write([int]$sampleRate)
$writer.Write([int]($sampleRate * 2))
$writer.Write([int16]2)
$writer.Write([int16]16)
$writer.Write([System.Text.Encoding]::ASCII.GetBytes("data"))
$writer.Write([int]$dataSize)
foreach ($sample in $samples) {
  $clamped = [Math]::Max(-1.0, [Math]::Min(1.0, $sample))
  $writer.Write([int16]($clamped * 32767))
}
$writer.Dispose()
$stream.Dispose()

$out = Join-Path $soundDir "answer-fanfare.ogg"
& $ffmpeg -y -loglevel error -i $tempWav -c:a libvorbis -q:a 4 $out
if ($LASTEXITCODE -ne 0) {
  throw "ffmpeg failed to encode $out"
}
Remove-Item $tempWav -Force

Write-Host "Wrote $out"
