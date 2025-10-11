function Invoke-PostInstallScripts {
    <#
    .SYNOPSIS
    Executes SQL template files after data import with placeholder replacement.

    .DESCRIPTION
    Reads SQL template files from a specified folder or single file, replaces placeholders
    with actual values (database name, schema name), and executes them using the
    current database connection. Useful for creating views, stored procedures,
    functions, or other database objects that depend on the imported data.

    .PARAMETER ScriptPath
    Path to folder containing SQL template files, or path to a single SQL file.

    .PARAMETER ConnectionString
    SQL Server connection string.

    .PARAMETER DatabaseName
    Database name to replace {{DATABASE}} placeholder.

    .PARAMETER SchemaName
    Schema name to replace {{SCHEMA}} placeholder.

    .EXAMPLE
    Invoke-PostInstallScripts -ScriptPath "C:\Scripts\PostInstall" -ConnectionString $conn -DatabaseName "MyDB" -SchemaName "dbo"
    #>
    [CmdletBinding()]
    param(
        [Parameter(Mandatory=$true)]
        [ValidateScript({ Test-Path $_ })]
        [string]$ScriptPath,

        [Parameter(Mandatory=$true)]
        [ValidateNotNullOrEmpty()]
        [string]$ConnectionString,

        [Parameter(Mandatory=$true)]
        [ValidateNotNullOrEmpty()]
        [string]$DatabaseName,

        [Parameter(Mandatory=$true)]
        [ValidateNotNullOrEmpty()]
        [string]$SchemaName
    )

    Write-Verbose "Starting post-install script execution"

    # Determine if ScriptPath is a file or folder
    $sqlFiles = @()

    if (Test-Path -Path $ScriptPath -PathType Leaf) {
        $sqlFiles += Get-Item -Path $ScriptPath
        Write-Debug "Post-install: Single SQL file specified: $ScriptPath"
    }
    elseif (Test-Path -Path $ScriptPath -PathType Container) {
        $sqlFiles = Get-ChildItem -Path $ScriptPath -Filter "*.sql" | Sort-Object Name
        Write-Debug "Post-install: Found $($sqlFiles.Count) SQL files in folder: $ScriptPath"
    }

    if ($sqlFiles.Count -eq 0) {
        Write-Warning "No SQL files found for post-install execution"
        return
    }

    $successCount = 0
    $errorCount = 0

    foreach ($sqlFile in $sqlFiles) {
        Write-Host "`nExecuting post-install script: $($sqlFile.Name)" -ForegroundColor Cyan
        Write-Debug "Post-install: Executing $($sqlFile.Name)"

        try {
            # Read the SQL template file
            $sqlTemplate = Get-Content -Path $sqlFile.FullName -Raw

            # Replace placeholders
            $sql = $sqlTemplate
            $sql = $sql -replace '\{\{DATABASE\}\}', $DatabaseName
            $sql = $sql -replace '\{\{SCHEMA\}\}', $SchemaName

            # Script execution configuration
            $previewLength = 200         # Characters to show in preview
            $queryTimeoutSeconds = 300   # 5 minutes

            # Show preview
            $preview = $sql.Substring(0, [Math]::Min($previewLength, $sql.Length))
            Write-Host "  Preview: $preview..." -ForegroundColor Gray

            # Execute the SQL script
            Invoke-Sqlcmd -ConnectionString $ConnectionString -Query $sql -QueryTimeout $queryTimeoutSeconds

            Write-Host "  ✓ Successfully executed $($sqlFile.Name)" -ForegroundColor Green
            Write-Debug "Post-install: Successfully executed $($sqlFile.Name)"
            $successCount++
        }
        catch {
            Write-Host "  ✗ Failed to execute $($sqlFile.Name): $($_.Exception.Message)" -ForegroundColor Red
            Write-Error "Post-install: Failed to execute $($sqlFile.Name): $($_.Exception.Message)"
            $errorCount++
        }
    }

    # Summary
    Write-Host "`n=== Post-Install Script Summary ===" -ForegroundColor Cyan
    Write-Host "Total scripts: $($sqlFiles.Count)" -ForegroundColor White
    Write-Host "Successful: $successCount" -ForegroundColor Green
    if ($errorCount -gt 0) {
        Write-Host "Failed: $errorCount" -ForegroundColor Red
    }

    Write-Verbose "Post-install script execution completed: $successCount successful, $errorCount failed"

    if ($errorCount -gt 0) {
        throw "Post-install script execution completed with $errorCount errors"
    }
}
