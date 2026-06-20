# Validation module for frame sequence processing

function Test-FrameSequence {
    <#
    .SYNOPSIS
    Validates a frame sequence directory for completeness and correctness.
    .DESCRIPTION
    Scans a directory for frame files (frame_XXXX.ext) and validates the sequence.
    Checks for missing frames, duplicate frames, unsupported extensions, and extension consistency.
    .PARAMETER Directory
    Path to the directory containing frame files.
    .OUTPUTS
    PSCustomObject with properties: Valid, TotalFrames, MissingFrames, DuplicateFrames, Extension, Error.
    #>
    [CmdletBinding()]
    param(
        [Parameter(Mandatory=$true)]
        [string]$Directory
    )

    # Initialize result object
    $result = [PSCustomObject]@{
        Valid            = $true
        TotalFrames      = 0
        MissingFrames    = @()
        DuplicateFrames  = @()
        Extension        = ""
        Error            = $null
    }

    # Check if directory exists
    if (-not (Test-Path -Path $Directory -PathType Container)) {
        $result.Valid = $false
        $result.Error = "Directory not found: $Directory"
        return $result
    }

    # Get all frame_*.* files
    try {
        $allFiles = Get-ChildItem -Path $Directory -Filter "frame_*.*" -ErrorAction Stop
    } catch {
        $result.Valid = $false
        $result.Error = "Failed to access directory: $($_.Exception.Message)"
        return $result
    }

    if ($allFiles.Count -eq 0) {
        $result.Valid = $false
        $result.Error = "No frame files found in directory"
        return $result
    }

    # Arrays to store valid frame data and unsupported files
    $validFrames = @()
    $unsupportedFiles = @()

    # Process each file
    foreach ($file in $allFiles) {
        $filename = $file.Name

        # Check if filename matches frame_XXXX.ext pattern
        if ($filename -notmatch '^frame_(\d+)\.(.+)$') {
            $unsupportedFiles += $file
            continue
        }

        $frameNum = [int]$matches[1]
        $extension = $matches[2].ToLower()

        # Check if extension is supported
        if ($extension -notin @('jpg', 'jpeg', 'png')) {
            $unsupportedFiles += $file
            continue
        }

        # Add to valid frames
        $validFrames += [PSCustomObject]@{
            FrameNumber = $frameNum
            Extension   = $extension
            FileName    = $filename
        }
    }

    # Handle unsupported files
    if ($unsupportedFiles.Count -gt 0) {
        $result.Valid = $false
        $result.Error = "Unsupported file extension found in: $($unsupportedFiles.Name -join ', ')"
        return $result
    }

    if ($validFrames.Count -eq 0) {
        $result.Valid = $false
        $result.Error = "No valid frame files found (all files have unsupported extensions)"
        return $result
    }

    # Extract frame numbers and extensions
    $frameNumbers = $validFrames.FrameNumber
    $extensions = @($validFrames.Extension | Select-Object -Unique)

    # Calculate TotalFrames (highest frame number found)
    $maxFrame = ($frameNumbers | Measure-Object -Maximum).Maximum
    $result.TotalFrames = $maxFrame

    # Find missing frames (1 to maxFrame)
    $allExpected = 1..$maxFrame
    $missing = $allExpected | Where-Object { $_ -notin $frameNumbers }
    $result.MissingFrames = $missing

    # Find duplicate frames
    $duplicates = $frameNumbers | Group-Object | Where-Object {$_.Count -gt 1} | Select-Object -ExpandProperty Name
    $result.DuplicateFrames = [int[]]$duplicates

    # Determine Extension (common extension if all files have same extension)
    if ($extensions.Count -eq 1) {
        $result.Extension = $extensions[0]
        
    } else {
        $result.Extension = ""  # No common extension when multiple extensions present
    }

    # Set Valid based on missing/duplicate frames
    if ($result.MissingFrames.Count -gt 0 -or $result.DuplicateFrames.Count -gt 0) {
        $result.Valid = $false
        $errors = @()
        if ($result.MissingFrames.Count -gt 0) {
            $errors += "Missing frames: $($result.MissingFrames -join ', ')"
        }
        if ($result.DuplicateFrames.Count -gt 0) {
            $errors += "Duplicate frames: $($result.DuplicateFrames -join ', ')"
        }
        $result.Error = $errors -join '; '
    }

    return $result
}

function Get-FrameStatistics {
    <#
    .SYNOPSIS
    Calculates statistics for a frame sequence directory.
    .DESCRIPTION
    Scans a directory for frame files (frame_XXXX.ext) and calculates sequence statistics.
    Does not validate - reports on what is found including unsupported files (which are ignored).
    .PARAMETER Directory
    Path to the directory containing frame files.
    .OUTPUTS
    PSCustomObject with properties: TotalFrames, FirstFrame, LastFrame, Extension, MissingFrames, DuplicateFrames, MixedExtensions.
    #>
    [CmdletBinding()]
    param(
        [Parameter(Mandatory=$true)]
        [string]$Directory
    )

    # Initialize result object
    $result = [PSCustomObject]@{
        TotalFrames      = 0
        FirstFrame       = $null
        LastFrame        = $null
        Extension        = ""
        MissingFrames    = @()
        DuplicateFrames  = @()
        MixedExtensions  = $false
    }

    # Check if directory exists
    if (-not (Test-Path -Path $Directory -PathType Container)) {
        return $result
    }

    # Get all frame_*.* files
    try {
        $allFiles = Get-ChildItem -Path $Directory -Filter "frame_*.*" -ErrorAction Stop
    } catch {
        return $result
    }

    if ($allFiles.Count -eq 0) {
        return $result
    }

    # Arrays to store valid frame data (ignoring unsupported files)
    $validFrames = @()

    # Process each file
    foreach ($file in $allFiles) {
        $filename = $file.Name

        # Check if filename matches frame_XXXX.ext pattern
        if ($filename -notmatch '^frame_(\d+)\.(.+)$') {
            # Skip unsupported format
            continue
        }

        $frameNum = [int]$matches[1]
        $extension = $matches[2].ToLower()

        # Check if extension is supported
        if ($extension -notin @('jpg', 'jpeg', 'png')) {
            # Skip unsupported extension
            continue
        }

        # Add to valid frames
        $validFrames += [PSCustomObject]@{
            FrameNumber = $frameNum
            Extension   = $extension
            FileName    = $filename
        }
    }

    if ($validFrames.Count -eq 0) {
        return $result
    }

    # Extract frame numbers and extensions
    $frameNumbers = $validFrames.FrameNumber
    $extensions = @($validFrames.Extension | Select-Object -Unique)

    # Calculate TotalFrames (count of valid files)
    $result.TotalFrames = $validFrames.Count

    # Determine MixedExtensions and Extension
    if ($extensions.Count -gt 1) {
        $result.MixedExtensions = $true
        $result.Extension = ""  # No common extension when multiple extensions present
    } elseif ($extensions.Count -eq 1) {
        $result.MixedExtensions = $false
        $result.Extension = $extensions[0]
    } else {
        # No valid extensions (shouldn't happen if we have valid frames)
        $result.MixedExtensions = $false
        $result.Extension = ""
    }

    # Find frame range (min and max)
    $minFrame = ($frameNumbers | Measure-Object -Minimum).Minimum
    $maxFrame = ($frameNumbers | Measure-Object -Maximum).Maximum

    # Build FirstFrame and LastFrame filenames
    # For the lowest frame number, take the first file we encountered (no extension selection)
    $firstFrameInfo = $validFrames | Where-Object {$_.FrameNumber -eq $minFrame} | Select-Object -First 1
    $lastFrameInfo  = $validFrames | Where-Object {$_.FrameNumber -eq $maxFrame} | Select-Object -First 1

    if ($firstFrameInfo) {
        $result.FirstFrame = $firstFrameInfo.FileName
    }
    if ($lastFrameInfo) {
        $result.LastFrame = $lastFrameInfo.FileName
    }

    # Find missing frames (1 to maxFrame)
    $allExpected = 1..$maxFrame
    $missing = $allExpected | Where-Object { $_ -notin $frameNumbers }
    $result.MissingFrames = $missing

    # Find duplicate frames
    $duplicates = $frameNumbers | Group-Object | Where-Object {$_.Count -gt 1} | Select-Object -ExpandProperty Name
    $result.DuplicateFrames = [int[]]$duplicates

    return $result
}