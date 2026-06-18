# Logger Module - Novahive Frame Processor

function Initialize-Logger {
    <#
    .SYNOPSIS
        Initializes the logger by creating a timestamped log file in the output/logs directory.
    .DESCRIPTION
        Creates the output/logs directory if it doesn't exist, generates a timestamped log file,
        and returns the full path to the log file.
    .OUTPUTS
        System.String. Returns the full path to the created log file.
    .EXAMPLE
        $logFile = Initialize-Logger
        Write-Log -Message "Process started" -LogFile $logFile
    #>

    # Resolve project root explicitly
    $rootDir = Resolve-Path (Join-Path $PSScriptRoot "..\..")
    $logsDir = Join-Path $rootDir "output\logs"

    # Create logs directory if it doesn't exist
    if (-not (Test-Path $logsDir)) {
        New-Item -ItemType Directory -Path $logsDir -Force | Out-Null
    }

    # Generate timestamp for log file name
    $timestamp = Get-Date -Format 'yyyyMMdd_HHmmss'
    $logFile = Join-Path -Path $logsDir -ChildPath "log_$timestamp.txt"

    # Create an empty log file
    New-Item -ItemType File -Path $logFile -Force | Out-Null

    return $logFile
}

function Write-Log {
    <#
    .SYNOPSIS
        Writes a log entry to the console and to a specified log file.
    .DESCRIPTION
        Formats a log entry with timestamp, level, and message, writes it to the console,
        and appends it to the specified log file using UTF8 encoding.
    .PARAMETER Message
        The log message to write.
    .PARAMETER Level
        The log level. Valid values are INFO, WARN, ERROR, DEBUG. Defaults to INFO.
    .PARAMETER LogFile
        The full path to the log file where the entry will be appended.
    .EXAMPLE
        Write-Log -Message "Frame processing complete" -Level "INFO" -LogFile $logFile
    .EXAMPLE
        Write-Log -Message "Processing frame 0001" -LogFile $logFile  # Uses default Level=INFO
    #>
    [CmdletBinding()]
    param (
        [Parameter(Mandatory=$true)]
        [string] $Message,

        [Parameter(Mandatory=$false)]
        [ValidateSet('INFO','WARN','ERROR','DEBUG')]
        [string] $Level = 'INFO',

        [Parameter(Mandatory=$true)]
        [string] $LogFile
    )

    # Validate LogFile
    if ([string]::IsNullOrWhiteSpace($LogFile)) {
        throw "LogFile parameter cannot be null, empty, or whitespace."
    }

    # Format timestamp as YYYY-MM-DD HH:MM:SS
    $timeStamp = Get-Date -Format 'yyyy-MM-dd HH:mm:ss'
    # Format the log entry
    $logEntry = "[$timeStamp] [$Level] $Message"

    # Determine console color based on level
    $color = switch ($Level) {
        'INFO'  { 'Green' }
        'WARN'  { 'Yellow' }
        'ERROR' { 'Red' }
        'DEBUG' { 'Cyan' }
        default { 'White' } # should not happen due to ValidateSet
    }

    # Write to console with color
    Write-Host $logEntry -ForegroundColor $color

    # Append to log file with UTF8 encoding
    Add-Content -Path $LogFile -Value $logEntry -Encoding UTF8
}