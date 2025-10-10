function Test-TableExists {
    <#
    .SYNOPSIS
    Checks if a table exists in the database.

    .PARAMETER ConnectionString
    SQL Server connection string.

    .PARAMETER SchemaName
    Schema name.

    .PARAMETER TableName
    Table name to check.

    .EXAMPLE
    if (Test-TableExists -ConnectionString $conn -SchemaName "dbo" -TableName "Employee") {
        Write-Host "Table exists"
    }
    #>
    [CmdletBinding()]
    [OutputType([bool])]
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

    $query = @"
DECLARE @SchemaName VARCHAR(255)='$SchemaName';
DECLARE @TableName VARCHAR(255)='$TableName';

SELECT COUNT(*)
FROM INFORMATION_SCHEMA.TABLES
WHERE TABLE_SCHEMA = @SchemaName AND TABLE_NAME = @TableName
"@

    try {
        $result = Invoke-Sqlcmd -ConnectionString $ConnectionString -Query $query -ErrorAction Stop
        $exists = $result.Column1 -gt 0
        return $exists
    }
    catch {
        return $false
    }
}
