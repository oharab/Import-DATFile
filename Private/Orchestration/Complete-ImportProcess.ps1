function Complete-ImportProcess {
    <#
    .SYNOPSIS
    Finalizes the import process with summary display and post-install scripts.

    .DESCRIPTION
    Completes the import workflow:
    - Displays import summary with table and row counts
    - Executes optional post-install SQL scripts
    - Logs completion status
    - Handles post-install script failures gracefully (import success preserved)

    .PARAMETER SchemaName
    Database schema name (for display).

    .PARAMETER ConnectionString
    SQL Server connection string (for post-install scripts).

    .PARAMETER DatabaseName
    Database name (for post-install script placeholder replacement).

    .PARAMETER PostInstallScripts
    Optional path to post-install SQL scripts (file or folder).

    .EXAMPLE
    Complete-ImportProcess -SchemaName "dbo" -ConnectionString $conn -DatabaseName "MyDB" -PostInstallScripts "C:\Scripts\PostInstall.sql"

    .OUTPUTS
    None. Displays output to console and executes scripts.
    #>
    [CmdletBinding()]
    param(
        [Parameter(Mandatory=$true)]
        [ValidatePattern('^[a-zA-Z0-9_]+$')]
        [string]$SchemaName,

        [Parameter(Mandatory=$true)]
        [ValidateNotNullOrEmpty()]
        [string]$ConnectionString,

        [Parameter(Mandatory=$true)]
        [ValidateNotNullOrEmpty()]
        [string]$DatabaseName,

        [Parameter(Mandatory=$false)]
        [string]$PostInstallScripts
    )

    Write-Verbose "Completing import process"

    # Display summary
    Show-ImportSummary -SchemaName $SchemaName
    Write-ImportLog "Import process completed successfully" -Level "SUCCESS"

    # Execute post-install scripts if specified
    if (-not [string]::IsNullOrWhiteSpace($PostInstallScripts)) {
        Write-Host "`n=== Post-Install Scripts ===" -ForegroundColor Cyan
        Write-Verbose "Post-install scripts path: $PostInstallScripts"

        try {
            Invoke-PostInstallScripts -ScriptPath $PostInstallScripts `
                                       -ConnectionString $ConnectionString `
                                       -DatabaseName $DatabaseName `
                                       -SchemaName $SchemaName

            Write-ImportLog "Post-install scripts completed successfully" -Level "SUCCESS"
        }
        catch {
            Write-Error "Post-install scripts failed: $($_.Exception.Message)"
            Write-Host "`nWARNING: Post-install scripts failed but data import was successful" -ForegroundColor Yellow
            Write-Host "Error: $($_.Exception.Message)" -ForegroundColor Red
            Write-Verbose "Post-install script error details: $($_.Exception | Format-List * | Out-String)"

            # Don't throw - import was successful even if post-install failed
            # This allows the main function to return the import summary
        }
    }
    else {
        Write-Verbose "No post-install scripts specified, skipping"
    }

    Write-Verbose "Import finalization completed"
}
