function Write-ImportLog {
    <#
    .SYNOPSIS
    Writes user-facing log messages with different severity levels.

    .DESCRIPTION
    Centralized logging function for INFO and SUCCESS messages.
    For VERBOSE, DEBUG, WARNING, and ERROR messages, use PowerShell's
    built-in Write-Verbose, Write-Debug, Write-Warning, Write-Error cmdlets.

    .PARAMETER Message
    The log message to write.

    .PARAMETER Level
    Log level: INFO, SUCCESS only. Use built-in cmdlets for others.
    #>
    param(
        [Parameter(Mandatory=$true)]
        [string]$Message,

        [ValidateSet("INFO", "SUCCESS")]
        [string]$Level = "INFO"
    )

    $timestamp = Get-Date -Format "yyyy-MM-dd HH:mm:ss"
    $logMessage = "[$timestamp] [$Level] $Message"

    # Write to console with appropriate color
    switch ($Level.ToUpper()) {
        "SUCCESS" { Write-Host $logMessage -ForegroundColor Green }
        "INFO" { Write-Host $logMessage -ForegroundColor White }
        default { Write-Host $logMessage -ForegroundColor White }
    }
}
