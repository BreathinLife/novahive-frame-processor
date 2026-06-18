function Test-FFmpeg {
    <#
    .SYNOPSIS
        Tests for FFmpeg installation and returns an object with installation details.
    .DESCRIPTION
        Checks if FFmpeg is available in the system PATH, validates the executable path,
        retrieves the version, and returns a PSCustomObject with Installed, Version, Path, and Error properties.
    .OUTPUTS
        PSCustomObject with properties:
            Installed (bool): True if FFmpeg is installed and usable.
            Version (string): Version string if available, otherwise $null.
            Path (string): Full path to FFmpeg executable if found, otherwise $null.
            Error (string): Error message if any, otherwise $null.
    .EXAMPLE
        $result = Test-FFmpeg
        if ($result.Installed) {
            Write-Host "FFmpeg version $($result.Version) found at $($result.Path)"
        } else {
            Write-Warning "FFmpeg check failed: $($result.Error)"
        }
    #>

    # Attempt to find ffmpeg in PATH
    $cmd = Get-Command ffmpeg -ErrorAction SilentlyContinue
    if (-not $cmd) {
        return [PSCustomObject]@{
            Installed = $false
            Version   = $null
            Path      = $null
            Error     = 'FFmpeg not found in PATH.'
        }
    }

    $exePath = $cmd.Source
    # Validate the executable path exists
    if (-not (Test-Path -Path $exePath -PathType Leaf)) {
        return [PSCustomObject]@{
            Installed = $false
            Version   = $null
            Path      = $exePath
            Error     = "FFmpeg executable not found at path: $exePath"
        }
    }

    # Get the version
    $version = Get-FFmpegVersion
    if (-not $version) {
        return [PSCustomObject]@{
            Installed = $false
            Version   = $null
            Path      = $exePath
            Error     = 'Unable to determine FFmpeg version.'
        }
    }

    return [PSCustomObject]@{
        Installed = $true
        Version   = $version
        Path      = $exePath
        Error     = $null
    }
}

function Get-FFmpegVersion {
    <#
    .SYNOPSIS
        Retrieves the FFmpeg version string.
    .DESCRIPTION
        Executes 'ffmpeg -version' and parses the output to extract the version number.
        Returns the version string (e.g., '7.1') or $null if unable to determine.
    .OUTPUTS
        string. Version number or $null.
    .EXAMPLE
        $version = Get-FFmpegVersion
        if ($version) {
            Write-Host "FFmpeg version: $version"
        }
    #>

    try {
        # Run ffmpeg -version and capture output
        $output = & ffmpeg -version 2>&1
        # Extract the first line
        $firstLine = $output -split "`n" | Select-Object -First 1
        # Attempt to match a version pattern (e.g., "ffmpeg version 7.1", "ffmpeg version 7.1.1", etc.)
        if ($firstLine -match 'ffmpeg version\s+([0-9]+(?:\.[0-9]+)+)') {
            return $matches[1]
        }
        # Fallback: match any version-like number in the first line
        if ($firstLine -match '([0-9]+(?:\.[0-9]+)+)') {
            return $matches[1]
        }
        return $null
    } catch {
        # In case of any exception (e.g., ffmpeg not found, access denied), return null
        return $null
    }
}