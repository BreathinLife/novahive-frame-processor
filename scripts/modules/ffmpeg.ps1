. "$PSScriptRoot\validation.ps1"

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

function Render-FrameSequence {
    <#
    .SYNOPSIS
        Renders a frame sequence into a video file using FFmpeg.
    .DESCRIPTION
        Takes a validated frame sequence and renders it to a video file using FFmpeg with standardized encoding settings.
        Relies on Test-FrameSequence for input validation and Test-FFmpeg for FFmpeg availability verification.
    .PARAMETER FrameDirectory
        Path to directory containing frame files.
    .PARAMETER FPS
        Frames per second for input sequence.
    .PARAMETER OutputVideoPath
        Full path for output video file.
    .OUTPUTS
        PSCustomObject with properties:
            Success (bool): True if rendering completed successfully
            VideoPath (string): OutputVideoPath on success, $null on failure
            ErrorMessage (string): Error details on failure, $null on success
            Duration (double): (frame count) / FPS on success, 0 on failure
    .EXAMPLE
        $result = Render-FrameSequence -FrameDirectory ".\frames" -FPS 30 -OutputVideoPath ".\output.mp4"
        if ($result.Success) {
            Write-Host "Rendered video to $($result.VideoPath) with duration $($result.Duration)s"
        } else {
            Write-Warning "Render failed: $($result.ErrorMessage)"
        }
    #>

    [CmdletBinding()]
    param(
        [Parameter(Mandatory=$true)]
        [string]$FrameDirectory,

        [Parameter(Mandatory=$true)]
        [int]$FPS,

        [Parameter(Mandatory=$true)]
        [string]$OutputVideoPath
    )

    # Validate FPS
    if ($FPS -le 0) {
        return [PSCustomObject]@{
            Success      = $false
            VideoPath    = $null
            ErrorMessage = "FPS must be greater than zero"
            Duration     = 0
        }
    }

    # Validate output path directory exists
    $outputDir = Split-Path -Path $OutputVideoPath -Parent
    if (-not (Test-Path -Path $outputDir -PathType Container)) {
        return [PSCustomObject]@{
            Success      = $false
            VideoPath    = $null
            ErrorMessage = "Output directory does not exist: $outputDir"
            Duration     = 0
        }
    }

    # Validate frame sequence using Test-FrameSequence
    $validationResult = Test-FrameSequence -Directory $FrameDirectory
    if (-not $validationResult.Valid) {
        return [PSCustomObject]@{
            Success      = $false
            VideoPath    = $null
            ErrorMessage = $validationResult.Error
            Duration     = 0
        }
    }

    # Verify FFmpeg availability
    $ffmpegResult = Test-FFmpeg
    if (-not $ffmpegResult.Installed) {
        return [PSCustomObject]@{
            Success      = $false
            VideoPath    = $null
            ErrorMessage = $ffmpegResult.Error
            Duration     = 0
        }
    }

    # Extract information from validated sequence
    $extension = $validationResult.Extension
    $frameCount = [double]$validationResult.TotalFrames  # When Valid=$true, TotalFrames = frame count

    # Calculate duration
    $duration = $frameCount / $FPS

    # Construct FFmpeg command with hardcoded project-standard settings
    $inputPattern = Join-Path -Path $FrameDirectory -ChildPath "frame_%04d.$extension"

    # Fixed video filter (scale to 1080x1920 maintaining aspect ratio with padding)
    $videoFilter = "scale=1080:1920:force_original_aspect_ratio=decrease,pad=1080:1920:(ow-iw)/2:(oh-ih)/2"

    # Fixed encoding settings (approved)
    $videoCodec = "libx264"
    $crfValue = "18"
    $presetValue = "medium"
    $pixelFormat = "yuv420p"

    # Build FFmpeg argument array (raw values, no extra quotes)
    $ffmpegArguments = @(
        "-framerate", $FPS,
        "-start_number", "1",
        "-i", $inputPattern,
        "-vf", $videoFilter,
        "-c:v", $videoCodec,
        "-crf", $crfValue,
        "-preset", $presetValue,
        "-pix_fmt", $pixelFormat,
        "-t", $duration,
        $OutputVideoPath
    )

    # Execute FFmpeg
    try {
        & ffmpeg @ffmpegArguments 2>&1
        $exitCode = $LASTEXITCODE

        if ($exitCode -eq 0) {
            return [PSCustomObject]@{
                Success      = $true
                VideoPath    = $OutputVideoPath
                ErrorMessage = $null
                Duration     = $duration
            }
        } else {
            return [PSCustomObject]@{
                Success      = $false
                VideoPath    = $null
                ErrorMessage = "FFmpeg execution failed with exit code $exitCode"
                Duration     = 0
            }
        }
    } catch {
        return [PSCustomObject]@{
            Success      = $false
            VideoPath    = $null
            ErrorMessage = "Failed to execute FFmpeg: $($_.Exception.Message)"
            Duration     = 0
        }
    }
}