<#
.SYNOPSIS
  Shared helpers for Chiptorio's PowerShell tooling.

.DESCRIPTION
  Resolves the Factorio executable without hard-coding a machine-specific path.
  Resolution order:
    1. The -Factorio parameter.
    2. The FACTORIO_EXE environment variable.
    3. FACTORIO_EXE in the repository-root .env file.
    4. Common Steam library locations and install paths.
#>

$script:RepoRoot = Split-Path -Parent $PSScriptRoot

function Read-ChiptorioDotEnv {
  param(
    [string]$Path = (Join-Path $script:RepoRoot ".env")
  )

  $values = @{}
  if (-not (Test-Path -LiteralPath $Path)) {
    return $values
  }

  foreach ($line in Get-Content -LiteralPath $Path) {
    $trimmed = $line.Trim()
    if (-not $trimmed -or $trimmed.StartsWith("#")) {
      continue
    }

    $equals = $trimmed.IndexOf("=")
    if ($equals -lt 1) {
      continue
    }

    $name = $trimmed.Substring(0, $equals).Trim()
    $value = $trimmed.Substring($equals + 1).Trim()

    if ($value.Length -ge 2) {
      $first = $value.Substring(0, 1)
      $last = $value.Substring($value.Length - 1, 1)
      if (($first -eq '"' -and $last -eq '"') -or ($first -eq "'" -and $last -eq "'")) {
        $value = $value.Substring(1, $value.Length - 2)
      }
    }

    $values[$name] = [Environment]::ExpandEnvironmentVariables($value)
  }

  return $values
}

function Get-FactorioExecutableCandidate {
  param([string]$Path)

  if (-not $Path) {
    return $null
  }

  $expanded = [Environment]::ExpandEnvironmentVariables($Path.Trim().Trim('"'))
  if (-not $expanded) {
    return $null
  }

  if (Test-Path -LiteralPath $expanded -PathType Container) {
    $insideInstall = Join-Path $expanded "bin\x64\factorio.exe"
    if (Test-Path -LiteralPath $insideInstall -PathType Leaf) {
      return (Resolve-Path -LiteralPath $insideInstall).Path
    }
  }

  if (Test-Path -LiteralPath $expanded -PathType Leaf) {
    return (Resolve-Path -LiteralPath $expanded).Path
  }

  return $null
}

function Get-SteamInstallRoots {
  $roots = New-Object System.Collections.Generic.List[string]

  foreach ($key in @(
    "HKCU:\Software\Valve\Steam",
    "HKLM:\SOFTWARE\Valve\Steam",
    "HKLM:\SOFTWARE\WOW6432Node\Valve\Steam"
  )) {
    if (-not (Test-Path $key)) {
      continue
    }

    $properties = Get-ItemProperty -Path $key -ErrorAction SilentlyContinue
    if (-not $properties) {
      continue
    }

    foreach ($propertyName in @("SteamPath", "InstallPath")) {
      $value = $properties.$propertyName
      if ($value) {
        $roots.Add($value)
      }
    }
  }

  foreach ($base in @($env:ProgramFiles, ${env:ProgramFiles(x86)})) {
    if ($base) {
      $roots.Add((Join-Path $base "Steam"))
    }
  }

  $roots.Add("C:\Steam")

  return $roots | Where-Object { $_ -and (Test-Path -LiteralPath $_) } | Select-Object -Unique
}

function Get-SteamLibraryRoots {
  $roots = New-Object System.Collections.Generic.List[string]

  foreach ($steamRoot in Get-SteamInstallRoots) {
    $roots.Add($steamRoot)

    $vdf = Join-Path $steamRoot "steamapps\libraryfolders.vdf"
    if (-not (Test-Path -LiteralPath $vdf)) {
      continue
    }

    $text = Get-Content -LiteralPath $vdf -Raw
    foreach ($match in [regex]::Matches($text, '"path"\s+"([^"]+)"')) {
      $library = $match.Groups[1].Value.Replace('\\', '\')
      if ($library) {
        $roots.Add($library)
      }
    }
  }

  return $roots | Where-Object { $_ -and (Test-Path -LiteralPath $_) } | Select-Object -Unique
}

function Get-FactorioCandidates {
  $candidates = New-Object System.Collections.Generic.List[string]

  $onPath = Get-Command "factorio.exe" -ErrorAction SilentlyContinue
  if ($onPath) {
    $candidates.Add($onPath.Source)
  }

  foreach ($library in Get-SteamLibraryRoots) {
    $candidates.Add((Join-Path $library "steamapps\common\Factorio\bin\x64\factorio.exe"))
  }

  foreach ($base in @($env:ProgramFiles, ${env:ProgramFiles(x86)}, "C:\Games", "D:\Games")) {
    if ($base) {
      $candidates.Add((Join-Path $base "Factorio\bin\x64\factorio.exe"))
    }
  }

  return $candidates | Select-Object -Unique
}

function Resolve-FactorioExecutable {
  param([string]$Factorio)

  if ($Factorio) {
    $resolved = Get-FactorioExecutableCandidate $Factorio
    if (-not $resolved) {
      throw "Factorio executable not found at '$Factorio'."
    }
    return $resolved
  }

  if ($env:FACTORIO_EXE) {
    $resolved = Get-FactorioExecutableCandidate $env:FACTORIO_EXE
    if (-not $resolved) {
      throw "FACTORIO_EXE points to '$($env:FACTORIO_EXE)', but factorio.exe was not found there."
    }
    return $resolved
  }

  $dotenv = Read-ChiptorioDotEnv
  if ($dotenv.ContainsKey("FACTORIO_EXE") -and $dotenv["FACTORIO_EXE"]) {
    $configured = $dotenv["FACTORIO_EXE"]
    $resolved = Get-FactorioExecutableCandidate $configured
    if (-not $resolved) {
      throw ".env has FACTORIO_EXE='$configured', but factorio.exe was not found there."
    }
    return $resolved
  }

  foreach ($candidate in Get-FactorioCandidates) {
    $resolved = Get-FactorioExecutableCandidate $candidate
    if ($resolved) {
      return $resolved
    }
  }

  throw (@(
    "Factorio executable not found.",
    "",
    "Fix it in one of these ways:",
    '  1. Pass -Factorio "C:\path\to\factorio.exe" to the script.',
    "  2. Set the FACTORIO_EXE environment variable.",
    "  3. Copy .env.example to .env and set FACTORIO_EXE.",
    "",
    "Steam installations are detected automatically."
  ) -join [Environment]::NewLine)
}
