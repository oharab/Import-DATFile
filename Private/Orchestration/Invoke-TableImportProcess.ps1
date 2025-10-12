function Invoke-TableImportProcess {
    <#
    .SYNOPSIS
    Processes a single table import from DAT file to SQL Server.

    .DESCRIPTION
    Handles the complete import workflow for one table:
    - Extracts table name from DAT filename
    - Retrieves field specifications for the table
    - Handles existing table based on TableExistsAction (Skip, Truncate, Recreate)
    - Creates table if it doesn't exist
    - Imports data from DAT file using SqlBulkCopy
    - Adds import summary entry

    .PARAMETER DataFile
    FileInfo object representing the DAT file to import.

    .PARAMETER ConnectionString
    SQL Server connection string.

    .PARAMETER SchemaName
    Database schema name.

    .PARAMETER Prefix
    Data file prefix (for table name extraction).

    .PARAMETER TableSpecs
    Array of table specifications from Excel.

    .PARAMETER TableExistsAction
    Action to take when table exists: Skip, Truncate, or Recreate.

    .EXAMPLE
    $result = Invoke-TableImportProcess -DataFile $file -ConnectionString $conn -SchemaName "dbo" -Prefix "ABC_" -TableSpecs $specs -TableExistsAction "Truncate"

    .OUTPUTS
    Hashtable with keys: TableName, RowsImported, Skipped
    #>
    [CmdletBinding()]
    [OutputType([hashtable])]
    param(
        [Parameter(Mandatory=$true)]
        [object]$DataFile,  # Accept any object with Name and FullName properties (FileInfo or mocked object)

        [Parameter(Mandatory=$true)]
        [ValidateNotNullOrEmpty()]
        [string]$ConnectionString,

        [Parameter(Mandatory=$true)]
        [ValidatePattern('^[a-zA-Z0-9_]+$')]
        [string]$SchemaName,

        [Parameter(Mandatory=$true)]
        [ValidateNotNullOrEmpty()]
        [string]$Prefix,

        [Parameter(Mandatory=$true)]
        [array]$TableSpecs,

        [Parameter(Mandatory=$true)]
        [ValidateSet("Skip", "Truncate", "Recreate")]
        [string]$TableExistsAction
    )

    # Extract table name from filename
    $tableName = $DataFile.Name -replace "^$Prefix", "" -replace "\.dat$", ""
    Write-Host "`n=== Processing Table: $tableName ===" -ForegroundColor Cyan
    Write-Verbose "Processing table '$tableName' from file: $($DataFile.Name)"

    # Get field specifications for this table
    $tableFields = $TableSpecs | Where-Object { $_."Table name" -eq $tableName }

    if ($tableFields.Count -eq 0) {
        Write-Warning "No field specifications found for table '$tableName' in Excel specification - skipping"
        return @{
            TableName = $tableName
            RowsImported = 0
            Skipped = $true
        }
    }

    Write-Host "Found $($tableFields.Count) field specifications for table '$tableName'"
    Write-Verbose "Field specifications: $($tableFields.'Column name' -join ', ')"

    # Handle existing tables
    $tableExists = Test-TableExists -ConnectionString $ConnectionString -SchemaName $SchemaName -TableName $tableName

    if ($tableExists) {
        Write-Verbose "Table [$SchemaName].[$tableName] exists, applying action: $TableExistsAction"

        switch ($TableExistsAction) {
            "Skip" {
                Write-Host "Skipping existing table '$tableName'" -ForegroundColor Yellow
                return @{
                    TableName = $tableName
                    RowsImported = 0
                    Skipped = $true
                }
            }
            "Truncate" {
                Write-Verbose "Truncating table [$SchemaName].[$tableName]"
                Clear-DatabaseTable -ConnectionString $ConnectionString -SchemaName $SchemaName -TableName $tableName
            }
            "Recreate" {
                Write-Verbose "Dropping and recreating table [$SchemaName].[$tableName]"
                Remove-DatabaseTable -ConnectionString $ConnectionString -SchemaName $SchemaName -TableName $tableName
                New-DatabaseTable -ConnectionString $ConnectionString -SchemaName $SchemaName -TableName $tableName -Fields $tableFields
            }
        }
    }
    else {
        Write-Verbose "Table [$SchemaName].[$tableName] does not exist, creating"
        New-DatabaseTable -ConnectionString $ConnectionString -SchemaName $SchemaName -TableName $tableName -Fields $tableFields
    }

    # Import data
    Write-Verbose "Starting data import for table '$tableName'"
    $rowsImported = Import-DataFile -ConnectionString $ConnectionString `
                                     -SchemaName $SchemaName `
                                     -TableName $tableName `
                                     -FilePath $DataFile.FullName `
                                     -Fields $tableFields

    # Add to import summary
    Add-ImportSummary -TableName $tableName -RowCount $rowsImported -FileName $DataFile.Name

    Write-Verbose "Completed import for table '$tableName': $rowsImported rows"

    return @{
        TableName = $tableName
        RowsImported = $rowsImported
        Skipped = $false
    }
}
