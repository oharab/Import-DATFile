function Remove-DatabaseTable {
    <#
    .SYNOPSIS
    Drops a database table.

    .DESCRIPTION
    Executes DROP TABLE statement. WARNING: Deletes all data.

    .PARAMETER ConnectionString
    SQL Server connection string.

    .PARAMETER SchemaName
    Schema name.

    .PARAMETER TableName
    Table name to drop.

    .EXAMPLE
    Remove-DatabaseTable -ConnectionString $conn -SchemaName "dbo" -TableName "Employee"
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

    Write-Verbose "Dropping table [$SchemaName].[$TableName]"
    $dropQuery = "DROP TABLE [$SchemaName].[$TableName]"

    if ($PSCmdlet.ShouldProcess("Table [$SchemaName].[$TableName]", "Drop table (DELETES ALL DATA)")) {
        try {
            Invoke-Sqlcmd -ConnectionString $ConnectionString -Query $dropQuery -ErrorAction Stop
            Write-Host "Table [$SchemaName].[$TableName] dropped successfully" -ForegroundColor Green
            Write-Verbose "Table [$SchemaName].[$TableName] dropped successfully"
        }
        catch {
            Write-Error "Failed to drop table [$SchemaName].[$TableName]: $($_.Exception.Message)"
            throw "Failed to drop table [$SchemaName].[$TableName]: $($_.Exception.Message)"
        }
    }
    else {
        Write-Host "What if: Would DROP table [$SchemaName].[$TableName] (ALL DATA WOULD BE LOST)" -ForegroundColor Yellow
    }
}
