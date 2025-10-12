function New-DatabaseSchema {
    <#
    .SYNOPSIS
    Creates or verifies database schema.

    .DESCRIPTION
    Creates schema if it doesn't exist, otherwise verifies existence.

    .PARAMETER ConnectionString
    SQL Server connection string.

    .PARAMETER SchemaName
    Schema name to create.

    .EXAMPLE
    New-DatabaseSchema -ConnectionString $conn -SchemaName "MySchema"
    #>
    [CmdletBinding(SupportsShouldProcess=$true)]
    param(
        [Parameter(Mandatory=$true)]
        [ValidateNotNullOrEmpty()]
        [string]$ConnectionString,

        [Parameter(Mandatory=$true)]
        [ValidatePattern('^[a-zA-Z0-9_]+$')]
        [string]$SchemaName
    )

    Write-Verbose "Creating/verifying schema: $SchemaName"

    $query = @"
DECLARE @SchemaName VARCHAR(255)='$SchemaName';

IF NOT EXISTS (SELECT * FROM sys.schemas WHERE name = @SchemaName)
BEGIN
    DECLARE @sql NVARCHAR(MAX) = 'CREATE SCHEMA [' + @SchemaName + ']'
    EXEC sp_executesql @sql
    PRINT 'Schema [' + @SchemaName + '] created successfully'
END
ELSE
BEGIN
    PRINT 'Schema [' + @SchemaName + '] already exists'
END
"@

    if ($PSCmdlet.ShouldProcess("Schema [$SchemaName]", "Create or verify schema")) {
        try {
            Invoke-Sqlcmd -ConnectionString $ConnectionString -Query $query -ErrorAction Stop
            Write-Host "Schema '$SchemaName' is ready" -ForegroundColor Green
            Write-Verbose "Schema '$SchemaName' is ready"
        }
        catch {
            # Extract database from connection string for context
            $connBuilder = New-Object System.Data.SqlClient.SqlConnectionStringBuilder($ConnectionString)
            $database = $connBuilder.InitialCatalog

            # Get detailed guidance
            $guidance = Get-DatabaseErrorGuidance -Operation "Schema" `
                                                  -ErrorMessage $_.Exception.Message `
                                                  -Context @{
                                                      SchemaName = $SchemaName
                                                      Database = $database
                                                  }

            Write-Error $guidance
            throw "Failed to create schema '$SchemaName'. See error above for troubleshooting guidance."
        }
    }
    else {
        Write-Host "What if: Would create or verify schema [$SchemaName]" -ForegroundColor Cyan
    }
}
