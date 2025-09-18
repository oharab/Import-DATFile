# SqlServerDataImport PowerShell Module
# Core functionality for importing pipe-separated .dat files into SQL Server

# Global variables
$script:ImportSummary = @()

#region Logging Functions

function Write-ImportLog {
    param(
        [Parameter(Mandatory=$true)]
        [string]$Message,

        [string]$Level = "INFO"
    )

    $timestamp = Get-Date -Format "yyyy-MM-dd HH:mm:ss"
    $logMessage = "[$timestamp] [$Level] $Message"

    # Write to console only
    switch ($Level.ToUpper()) {
        "ERROR" { Write-Host $logMessage -ForegroundColor Red }
        "WARNING" { Write-Host $logMessage -ForegroundColor Yellow }
        "SUCCESS" { Write-Host $logMessage -ForegroundColor Green }
        "INFO" { Write-Host $logMessage -ForegroundColor White }
        default { Write-Host $logMessage -ForegroundColor White }
    }
}

#endregion

#region Data Type Functions

function Get-SqlDataTypeMapping {
    param(
        [Parameter(Mandatory=$true)]
        [string]$ExcelType,

        [string]$Precision
    )

    $type = $ExcelType.ToUpper()

    switch -Regex ($type) {
        "^MONEY$" { return "MONEY" }
        "^VARCHAR.*" {
            if ($Precision -and $Precision -ne "") {
                return "VARCHAR($Precision)"
            }
            return "VARCHAR(255)"
        }
        "^CHAR.*" {
            if ($Precision -and $Precision -ne "") {
                return "CHAR($Precision)"
            }
            return "CHAR(10)"
        }
        "^INT.*|^INTEGER$" { return "INT" }
        "^BIGINT$" { return "BIGINT" }
        "^SMALLINT$" { return "SMALLINT" }
        "^TINYINT$" { return "TINYINT" }
        "^DECIMAL.*|^NUMERIC.*" {
            if ($Precision -and $Precision -ne "") {
                return "DECIMAL($Precision)"
            }
            return "DECIMAL(18,2)"
        }
        "^FLOAT$" { return "FLOAT" }
        "^REAL$" { return "REAL" }
        "^DATE$" { return "DATE" }
        "^DATETIME.*" { return "DATETIME2" }
        "^TIME$" { return "TIME" }
        "^BIT$|^BOOLEAN$" { return "BIT" }
        "^TEXT$" { return "NVARCHAR(MAX)" }
        default {
            Write-ImportLog "Unknown data type: $ExcelType. Defaulting to NVARCHAR(255)" -Level "WARNING"
            return "NVARCHAR(255)"
        }
    }
}

#endregion

#region File and Specification Functions

function Get-DataPrefix {
    param(
        [Parameter(Mandatory=$true)]
        [string]$FolderPath
    )

    Write-ImportLog "Starting prefix detection in folder: $FolderPath" -Level "INFO"
    Write-Host "`nLooking for Employee.dat file to determine prefix..." -ForegroundColor Yellow

    $employeeFiles = Get-ChildItem -Path $FolderPath -Name "*Employee.dat"

    if ($employeeFiles.Count -eq 0) {
        Write-ImportLog "No *Employee.dat file found in $FolderPath" -Level "ERROR"
        throw "No *Employee.dat file found. Cannot determine prefix."
    }

    if ($employeeFiles.Count -gt 1) {
        Write-ImportLog "Multiple Employee.dat files found, cannot determine unique prefix" -Level "ERROR"
        Write-Warning "Multiple Employee.dat files found:"
        $employeeFiles | ForEach-Object {
            Write-Host "  $_"
        }
        throw "Cannot uniquely determine prefix. Multiple Employee.dat files found."
    }

    # Get the first (and only) employee file
    if ($employeeFiles -is [array]) {
        $employeeFile = $employeeFiles[0]
    } else {
        $employeeFile = $employeeFiles
    }
    # Extract prefix by removing "Employee.dat" from the end (case-insensitive)
    $prefix = $employeeFile -replace "(?i)Employee\.dat$", ""

    Write-Host "Found: $employeeFile" -ForegroundColor Green
    Write-Host "Detected prefix: '$prefix'" -ForegroundColor Green
    Write-ImportLog "Prefix detection successful - File: $employeeFile, Prefix: '$prefix'" -Level "SUCCESS"

    return $prefix
}

function Get-TableSpecifications {
    param(
        [Parameter(Mandatory=$true)]
        [string]$ExcelPath
    )

    Write-ImportLog "Starting to read table specifications from Excel: $ExcelPath" -Level "INFO"
    Write-Host "`nReading table specifications from Excel..." -ForegroundColor Yellow

    if (-not (Test-Path $ExcelPath)) {
        Write-ImportLog "Excel specification file not found: $ExcelPath" -Level "ERROR"
        throw "Excel specification file not found: $ExcelPath"
    }

    try {
        $specs = Import-Excel -Path $ExcelPath
        Write-Host "Successfully read $($specs.Count) field specifications" -ForegroundColor Green
        Write-ImportLog "Successfully read $($specs.Count) field specifications from Excel" -Level "SUCCESS"
        return $specs
    }
    catch {
        Write-ImportLog "Failed to read Excel file: $($_.Exception.Message)" -Level "ERROR"
        throw "Failed to read Excel file: $($_.Exception.Message)"
    }
}

#endregion

#region Database Functions

function Test-DatabaseConnection {
    param(
        [Parameter(Mandatory=$true)]
        [string]$ConnectionString
    )

    try {
        $connection = New-Object System.Data.SqlClient.SqlConnection($ConnectionString)
        $connection.Open()
        $connection.Close()
        Write-ImportLog "Database connection test successful" -Level "SUCCESS"
        return $true
    }
    catch {
        Write-ImportLog "Database connection failed: $($_.Exception.Message)" -Level "ERROR"
        return $false
    }
}

function Test-TableExists {
    param(
        [Parameter(Mandatory=$true)]
        [string]$ConnectionString,

        [Parameter(Mandatory=$true)]
        [string]$SchemaName,

        [Parameter(Mandatory=$true)]
        [string]$TableName
    )

    # Use parameterized query to prevent SQL injection
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

function New-DatabaseSchema {
    param(
        [Parameter(Mandatory=$true)]
        [string]$ConnectionString,

        [Parameter(Mandatory=$true)]
        [string]$SchemaName
    )

    Write-ImportLog "Creating/verifying schema: $SchemaName" -Level "INFO"

    # Validate schema name to prevent injection - only allow alphanumeric and underscore
    if ($SchemaName -notmatch '^[a-zA-Z0-9_]+$') {
        throw "Invalid schema name. Schema names must contain only letters, numbers, and underscores."
    }

    # Use quoted identifier to safely include schema name
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

    try {
        Invoke-Sqlcmd -ConnectionString $ConnectionString -Query $query -ErrorAction Stop
        Write-Host "Schema '$SchemaName' is ready" -ForegroundColor Green
        Write-ImportLog "Schema '$SchemaName' is ready" -Level "SUCCESS"
    }
    catch {
        Write-ImportLog "Failed to create schema '$SchemaName': $($_.Exception.Message)" -Level "ERROR"
        throw "Failed to create schema: $($_.Exception.Message)"
    }
}

function New-DatabaseTable {
    param(
        [Parameter(Mandatory=$true)]
        [string]$ConnectionString,

        [Parameter(Mandatory=$true)]
        [string]$SchemaName,

        [Parameter(Mandatory=$true)]
        [string]$TableName,

        [Parameter(Mandatory=$true)]
        [array]$Fields
    )

    Write-ImportLog "Creating table [$SchemaName].[$TableName] with $($Fields.Count + 1) fields (including ImportID)" -Level "INFO"
    $fieldDefinitions = @()

    # Always add ImportID as first field
    $fieldDefinitions += "    [ImportID] VARCHAR(255)"

    foreach ($field in $Fields) {
        $sqlType = Get-SqlDataTypeMapping -ExcelType $field."Data type" -Precision $field.Precision
        $fieldDef = "    [$($field.'Column name')] $sqlType"
        $fieldDefinitions += $fieldDef
    }

    $createTableQuery = @"
CREATE TABLE [$SchemaName].[$TableName] (
$($fieldDefinitions -join ",`n")
)
"@

    try {
        Invoke-Sqlcmd -ConnectionString $ConnectionString -Query $createTableQuery -ErrorAction Stop
        Write-Host "Table [$SchemaName].[$TableName] created successfully" -ForegroundColor Green
        Write-ImportLog "Table [$SchemaName].[$TableName] created successfully" -Level "SUCCESS"
    }
    catch {
        Write-ImportLog "Failed to create table [$SchemaName].[$TableName]: $($_.Exception.Message)" -Level "ERROR"
        throw "Failed to create table [$SchemaName].[$TableName]: $($_.Exception.Message)"
    }
}

function Remove-DatabaseTable {
    param(
        [Parameter(Mandatory=$true)]
        [string]$ConnectionString,

        [Parameter(Mandatory=$true)]
        [string]$SchemaName,

        [Parameter(Mandatory=$true)]
        [string]$TableName
    )

    Write-ImportLog "Dropping table [$SchemaName].[$TableName]" -Level "INFO"
    $dropQuery = "DROP TABLE [$SchemaName].[$TableName]"

    try {
        Invoke-Sqlcmd -ConnectionString $ConnectionString -Query $dropQuery -ErrorAction Stop
        Write-Host "Table [$SchemaName].[$TableName] dropped successfully" -ForegroundColor Green
        Write-ImportLog "Table [$SchemaName].[$TableName] dropped successfully" -Level "SUCCESS"
    }
    catch {
        Write-ImportLog "Failed to drop table [$SchemaName].[$TableName]: $($_.Exception.Message)" -Level "ERROR"
        throw "Failed to drop table [$SchemaName].[$TableName]: $($_.Exception.Message)"
    }
}

function Clear-DatabaseTable {
    param(
        [Parameter(Mandatory=$true)]
        [string]$ConnectionString,

        [Parameter(Mandatory=$true)]
        [string]$SchemaName,

        [Parameter(Mandatory=$true)]
        [string]$TableName
    )

    Write-ImportLog "Truncating table [$SchemaName].[$TableName]" -Level "INFO"
    $truncateQuery = "TRUNCATE TABLE [$SchemaName].[$TableName]"

    try {
        Invoke-Sqlcmd -ConnectionString $ConnectionString -Query $truncateQuery -ErrorAction Stop
        Write-Host "Table [$SchemaName].[$TableName] truncated successfully" -ForegroundColor Green
        Write-ImportLog "Table [$SchemaName].[$TableName] truncated successfully" -Level "SUCCESS"
    }
    catch {
        Write-ImportLog "Failed to truncate table [$SchemaName].[$TableName]: $($_.Exception.Message)" -Level "ERROR"
        throw "Failed to truncate table [$SchemaName].[$TableName]: $($_.Exception.Message)"
    }
}

#endregion

#region Data Import Functions

function Import-DataFile {
    param(
        [Parameter(Mandatory=$true)]
        [string]$ConnectionString,

        [Parameter(Mandatory=$true)]
        [string]$SchemaName,

        [Parameter(Mandatory=$true)]
        [string]$TableName,

        [Parameter(Mandatory=$true)]
        [string]$FilePath,

        [Parameter(Mandatory=$true)]
        [array]$Fields
    )

    $fileName = [System.IO.Path]::GetFileName($FilePath)
    Write-ImportLog "Starting data import for table [$SchemaName].[$TableName] from file: $fileName" -Level "INFO"
    Write-Host "Importing data from $fileName using SqlBulkCopy..." -ForegroundColor Yellow

    # Read the file and parse pipe-separated data
    $lines = Get-Content -Path $FilePath

    if ($lines.Count -eq 0) {
        Write-ImportLog "Data file is empty: $FilePath" -Level "WARNING"
        Write-Warning "File is empty: $FilePath"
        return 0
    }

    # Create DataTable structure with ImportID first
    $dataTable = New-Object System.Data.DataTable

    # Add ImportID column first
    $importIdColumn = New-Object System.Data.DataColumn
    $importIdColumn.ColumnName = "ImportID"
    $importIdColumn.DataType = [System.String]
    $dataTable.Columns.Add($importIdColumn)

    # Add columns for each field from specification
    # Since data comes from database export, treat all as strings and let SqlBulkCopy handle conversions
    foreach ($field in $Fields) {
        $column = New-Object System.Data.DataColumn
        $column.ColumnName = $field.'Column name'
        $column.DataType = [System.String]  # Simplified - all as strings for database exports
        $dataTable.Columns.Add($column)
    }

    # Expected field count = ImportID (from file) + spec fields
    $expectedFieldCount = $Fields.Count + 1

    # Populate DataTable with data
    $rowCount = 0
    $lineNumber = 0

    foreach ($line in $lines) {
        $lineNumber++
        if ([string]::IsNullOrWhiteSpace($line)) { continue }

        $values = $line -split '\|'

        # Strict field count validation
        if ($values.Length -ne $expectedFieldCount) {
            Write-ImportLog "Field count mismatch at line $lineNumber. Expected $expectedFieldCount, got $($values.Length)" -Level "ERROR"
            Write-Host "FAILED LINE $lineNumber`: $line" -ForegroundColor Red
            throw "Field count mismatch at line $lineNumber. Expected $expectedFieldCount fields, got $($values.Length). Line: $line"
        }

        # Create DataRow and populate with values
        $dataRow = $dataTable.NewRow()

        # First field is always ImportID
        $dataRow["ImportID"] = $values[0].Trim()

        # Remaining fields map to specification fields
        for ($i = 0; $i -lt $Fields.Count; $i++) {
            $value = $values[$i + 1].Trim()
            $fieldName = $Fields[$i].'Column name'

            if ([string]::IsNullOrEmpty($value) -or $value -eq "NULL") {
                $dataRow[$fieldName] = [DBNull]::Value
            }
            else {
                # Since data comes from database export, values should already be in correct format
                # Just assign directly - SqlBulkCopy will handle any necessary conversions
                $dataRow[$fieldName] = $value
            }
        }

        $dataTable.Rows.Add($dataRow)
        $rowCount++

        if ($rowCount % 10000 -eq 0) {
            Write-Host "  Processed $rowCount rows..." -ForegroundColor Gray
        }
    }

    # Perform bulk copy
    try {
        $connection = New-Object System.Data.SqlClient.SqlConnection($ConnectionString)
        $connection.Open()

        $bulkCopy = New-Object System.Data.SqlClient.SqlBulkCopy($connection)
        $bulkCopy.DestinationTableName = "[$SchemaName].[$TableName]"
        $bulkCopy.BatchSize = 10000
        $bulkCopy.BulkCopyTimeout = 300  # 5 minutes

        # Map ImportID column
        $bulkCopy.ColumnMappings.Add("ImportID", "ImportID") | Out-Null

        # Map columns from specification
        foreach ($field in $Fields) {
            $bulkCopy.ColumnMappings.Add($field.'Column name', $field.'Column name') | Out-Null
        }

        $bulkCopy.WriteToServer($dataTable)

        $bulkCopy.Close()
        $connection.Close()

        Write-Host "Successfully imported $rowCount rows into [$SchemaName].[$TableName]" -ForegroundColor Green
        Write-ImportLog "Data import completed successfully - $rowCount rows imported into [$SchemaName].[$TableName]" -Level "SUCCESS"

        return $rowCount
    }
    catch {
        Write-ImportLog "Bulk copy failed: $($_.Exception.Message)" -Level "ERROR"
        if ($connection.State -eq 'Open') {
            $connection.Close()
        }
        throw
    }
    finally {
        if ($dataTable) {
            $dataTable.Dispose()
        }
    }
}


#endregion

#region Summary Functions

function Add-ImportSummary {
    param(
        [Parameter(Mandatory=$true)]
        [string]$TableName,

        [Parameter(Mandatory=$true)]
        [int]$RowCount,

        [Parameter(Mandatory=$true)]
        [string]$FileName
    )

    $script:ImportSummary += [PSCustomObject]@{
        TableName = $TableName
        RowCount = $RowCount
        FileName = $FileName
    }
}

function Show-ImportSummary {
    param(
        [Parameter(Mandatory=$true)]
        [string]$SchemaName
    )

    Write-ImportLog "Generating import summary" -Level "INFO"
    Write-Host "`n=== Import Summary ===" -ForegroundColor Cyan

    if ($script:ImportSummary.Count -eq 0) {
        Write-Host "No tables were imported." -ForegroundColor Yellow
        Write-ImportLog "No tables were imported" -Level "WARNING"
        return
    }

    Write-Host "`nImported Tables:" -ForegroundColor Green
    Write-Host "Schema: $SchemaName" -ForegroundColor White
    Write-Host "=" * 50 -ForegroundColor Gray

    $totalRows = 0
    $summaryData = @()

    foreach ($item in $script:ImportSummary) {
        $tableDisplay = "[$SchemaName].[$($item.TableName)]"
        $rowDisplay = "{0:N0}" -f $item.RowCount
        $summaryData += [PSCustomObject]@{
            Table = $tableDisplay
            Rows = $rowDisplay
        }
        $totalRows += $item.RowCount
    }

    # Display in formatted table
    $summaryData | Format-Table -Property @{
        Label = "Table Name"
        Expression = { $_.Table }
        Width = 35
    }, @{
        Label = "Rows Imported"
        Expression = { $_.Rows }
        Width = 15
        Alignment = "Right"
    } -AutoSize

    Write-Host "=" * 50 -ForegroundColor Gray
    Write-Host "Total Tables Imported: $($script:ImportSummary.Count)" -ForegroundColor Green
    Write-Host "Total Rows Imported: $("{0:N0}" -f $totalRows)" -ForegroundColor Green
    Write-ImportLog "Import summary completed - $($script:ImportSummary.Count) tables, $totalRows total rows" -Level "SUCCESS"
}

function Clear-ImportSummary {
    $script:ImportSummary = @()
}

#endregion

#region Main Import Function

function Invoke-SqlServerDataImport {
    param(
        [Parameter(Mandatory=$true)]
        [string]$DataFolder,

        [Parameter(Mandatory=$true)]
        [string]$ExcelSpecFile,

        [Parameter(Mandatory=$true)]
        [string]$ConnectionString,

        [string]$SchemaName,

        [ValidateSet("Ask", "Skip", "Truncate", "Recreate")]
        [string]$TableExistsAction = "Ask"
    )

    # Clear previous summary
    Clear-ImportSummary

    try {
        Write-ImportLog "Starting SQL Server data import" -Level "INFO"

        # Validate paths
        if (-not (Test-Path $DataFolder)) {
            throw "Data folder not found: $DataFolder"
        }

        $excelPath = Join-Path $DataFolder $ExcelSpecFile
        if (-not (Test-Path $excelPath)) {
            throw "Excel specification file not found: $excelPath"
        }

        # Find prefix and validate connection
        $prefix = Get-DataPrefix -FolderPath $DataFolder

        if (-not (Test-DatabaseConnection -ConnectionString $ConnectionString)) {
            throw "Database connection test failed"
        }

        # Determine schema name
        if (-not $SchemaName) {
            $SchemaName = $prefix
        }

        # Create schema
        New-DatabaseSchema -ConnectionString $ConnectionString -SchemaName $SchemaName

        # Read table specifications
        $tableSpecs = Get-TableSpecifications -ExcelPath $excelPath

        # Get data files
        $datFiles = Get-ChildItem -Path $DataFolder -Filter "*.dat" | Where-Object { $_.Name -like "$prefix*" }

        if ($datFiles.Count -eq 0) {
            throw "No .dat files found with prefix '$prefix'"
        }

        Write-Host "`nFound $($datFiles.Count) data files to process:" -ForegroundColor Green
        $datFiles | ForEach-Object { Write-Host "  $($_.Name)" }

        # Process each data file
        foreach ($datFile in $datFiles) {
            $tableName = $datFile.Name -replace "^$prefix", "" -replace "\.dat$", ""
            Write-Host "`n=== Processing Table: $tableName ===" -ForegroundColor Cyan

            # Get field specifications for this table
            $tableFields = $tableSpecs | Where-Object { $_."Table name" -eq $tableName }

            if ($tableFields.Count -eq 0) {
                Write-ImportLog "No field specifications found for table '$tableName' - skipping" -Level "WARNING"
                continue
            }

            Write-Host "Found $($tableFields.Count) field specifications for table '$tableName'"

            # Handle existing tables
            $tableExists = Test-TableExists -ConnectionString $ConnectionString -SchemaName $SchemaName -TableName $tableName

            if ($tableExists) {
                switch ($TableExistsAction) {
                    "Skip" {
                        Write-Host "Skipping existing table '$tableName'" -ForegroundColor Yellow
                        continue
                    }
                    "Truncate" {
                        Clear-DatabaseTable -ConnectionString $ConnectionString -SchemaName $SchemaName -TableName $tableName
                    }
                    "Recreate" {
                        Remove-DatabaseTable -ConnectionString $ConnectionString -SchemaName $SchemaName -TableName $tableName
                        New-DatabaseTable -ConnectionString $ConnectionString -SchemaName $SchemaName -TableName $tableName -Fields $tableFields
                    }
                }
            }
            else {
                New-DatabaseTable -ConnectionString $ConnectionString -SchemaName $SchemaName -TableName $tableName -Fields $tableFields
            }

            # Import data - assumes first field is ImportID, remaining fields match specification
            $rowsImported = Import-DataFile -ConnectionString $ConnectionString -SchemaName $SchemaName -TableName $tableName -FilePath $datFile.FullName -Fields $tableFields

            Add-ImportSummary -TableName $tableName -RowCount $rowsImported -FileName $datFile.Name
        }

        # Display summary
        Show-ImportSummary -SchemaName $SchemaName

        Write-ImportLog "Import process completed successfully" -Level "SUCCESS"

        return $script:ImportSummary
    }
    catch {
        Write-ImportLog "Import process failed: $($_.Exception.Message)" -Level "ERROR"
        throw
    }
}

#endregion

# Export module functions
Export-ModuleMember -Function @(
    'Invoke-SqlServerDataImport',
    'Get-DataPrefix',
    'Get-TableSpecifications',
    'Get-SqlDataTypeMapping',
    'Test-DatabaseConnection',
    'Test-TableExists',
    'New-DatabaseSchema',
    'New-DatabaseTable',
    'Remove-DatabaseTable',
    'Clear-DatabaseTable',
    'Import-DataFile',
    'Add-ImportSummary',
    'Show-ImportSummary',
    'Clear-ImportSummary',
    'Write-ImportLog'
)