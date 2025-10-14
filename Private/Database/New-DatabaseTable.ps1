function New-DatabaseTable {
    <#
    .SYNOPSIS
    Creates database table from field specifications.

    .DESCRIPTION
    Generates and executes CREATE TABLE statement with ImportID as first column.

    .PARAMETER ConnectionString
    SQL Server connection string.

    .PARAMETER SchemaName
    Schema name.

    .PARAMETER TableName
    Table name to create.

    .PARAMETER Fields
    Array of field specifications.

    .EXAMPLE
    New-DatabaseTable -ConnectionString $conn -SchemaName "dbo" -TableName "Employee" -Fields $fields
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
        [string]$TableName,

        [Parameter(Mandatory=$true)]
        [array]$Fields
    )

    Write-Verbose "Creating table [$SchemaName].[$TableName] with $($Fields.Count + 1) fields (including ImportID)"
    $fieldDefinitions = @()

    # Always add ImportID as first field
    $fieldDefinitions += "    [ImportID] VARCHAR(255)"

    foreach ($field in $Fields) {
        $sqlType = Get-SqlDataTypeMapping -ExcelType $field."Data type" -Precision $field.Precision -Scale $field.Scale
        $fieldDef = "    [$($field.'Column name')] $sqlType"
        $fieldDefinitions += $fieldDef
    }

    $createTableQuery = @"
CREATE TABLE [$SchemaName].[$TableName] (
$($fieldDefinitions -join ",`n")
)
"@

    if ($PSCmdlet.ShouldProcess("Table [$SchemaName].[$TableName]", "Create table")) {
        try {
            Invoke-Sqlcmd -ConnectionString $ConnectionString -Query $createTableQuery -ErrorAction Stop
            Write-Host "Table [$SchemaName].[$TableName] created successfully" -ForegroundColor Green
            Write-Verbose "Table [$SchemaName].[$TableName] created successfully"
        }
        catch {
            # Get detailed guidance with SQL statement
            $guidance = Get-DatabaseErrorGuidance -Operation "TableCreate" `
                                                  -ErrorMessage $_.Exception.Message `
                                                  -Context @{
                                                      SchemaName = $SchemaName
                                                      TableName = $TableName
                                                      SQL = $createTableQuery
                                                  }

            Write-Error $guidance
            throw "Failed to create table [$SchemaName].[$TableName]. See error above for troubleshooting guidance."
        }
    }
    else {
        Write-Host "`nWhat if: Would create table [$SchemaName].[$TableName]" -ForegroundColor Cyan
        Write-Host "CREATE TABLE statement:" -ForegroundColor Yellow
        Write-Host $createTableQuery -ForegroundColor Gray
    }
}
