function Clear-DatabaseTable {
    <#
    .SYNOPSIS
    Truncates a database table.

    .DESCRIPTION
    Executes TRUNCATE TABLE statement. WARNING: Deletes all data.

    .PARAMETER ConnectionString
    SQL Server connection string.

    .PARAMETER SchemaName
    Schema name.

    .PARAMETER TableName
    Table name to truncate.

    .EXAMPLE
    Clear-DatabaseTable -ConnectionString $conn -SchemaName "dbo" -TableName "Employee"
    #>
    [CmdletBinding(SupportsShouldProcess=$true)]
    param(
        [Parameter(Mandatory=$true)]
        [ValidateNotNullOrEmpty()]
        [string]$ConnectionString,

        [Parameter(Mandatory=$true)]
        [ValidatePattern('^[a-zA-Z0-9_]+$')]
        [string]$SchemaName,

        [Parameter(Mandatory=$true)]
        [ValidateNotNullOrEmpty()]
        [string]$TableName
    )

    Write-Verbose "Truncating table [$SchemaName].[$TableName]"
    $truncateQuery = "TRUNCATE TABLE [$SchemaName].[$TableName]"

    if ($PSCmdlet.ShouldProcess("Table [$SchemaName].[$TableName]", "Truncate table (DELETES ALL DATA)")) {
        try {
            Invoke-Sqlcmd -ConnectionString $ConnectionString -Query $truncateQuery -ErrorAction Stop
            Write-Host "Table [$SchemaName].[$TableName] truncated successfully" -ForegroundColor Green
            Write-Verbose "Table [$SchemaName].[$TableName] truncated successfully"
        }
        catch {
            # Get detailed guidance
            $guidance = Get-DatabaseErrorGuidance -Operation "TableTruncate" `
                                                  -ErrorMessage $_.Exception.Message `
                                                  -Context @{
                                                      SchemaName = $SchemaName
                                                      TableName = $TableName
                                                  }

            Write-Error $guidance
            throw "Failed to truncate table [$SchemaName].[$TableName]. See error above for troubleshooting guidance."
        }
    }
    else {
        Write-Host "What if: Would TRUNCATE table [$SchemaName].[$TableName] (ALL DATA WOULD BE DELETED)" -ForegroundColor Yellow
    }
}
