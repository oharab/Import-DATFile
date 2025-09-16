# SqlServerDataImport PowerShell Module
# Core functionality for importing pipe-separated .dat files into SQL Server

# Global variables
$script:AlwaysSkipFirstField = $false
$script:ImportSummary = @()

#region Logging Functions

function Write-ImportLog {
    param(
        [Parameter(Mandatory=$true)]
        [string]$Message,

        [string]$Level = "INFO",

        [switch]$VerboseOnly,

        [switch]$EnableVerbose = $false
    )

    $timestamp = Get-Date -Format "yyyy-MM-dd HH:mm:ss"
    $logMessage = "[$timestamp] [$Level] $Message"

    if ($VerboseOnly -and -not $EnableVerbose) {
        return
    }

    switch ($Level.ToUpper()) {
        "ERROR" { Write-Host $logMessage -ForegroundColor Red }
        "WARNING" { Write-Host $logMessage -ForegroundColor Yellow }
        "SUCCESS" { Write-Host $logMessage -ForegroundColor Green }
        "INFO" { Write-Host $logMessage -ForegroundColor White }
        "VERBOSE" {
            if ($EnableVerbose) {
                Write-Host $logMessage -ForegroundColor Gray
            }
        }
        default { Write-Host $logMessage -ForegroundColor White }
    }
}

function Write-ImportLogVerbose {
    param(
        [Parameter(Mandatory=$true)]
        [string]$Message,

        [switch]$EnableVerbose = $false
    )
    Write-ImportLog -Message $Message -Level "VERBOSE" -VerboseOnly -EnableVerbose:$EnableVerbose
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
        [string]$FolderPath,

        [switch]$EnableVerbose = $false
    )

    Write-ImportLog "Starting prefix detection in folder: $FolderPath" -Level "INFO"
    Write-Host "`nLooking for Employee.dat file to determine prefix..." -ForegroundColor Yellow

    Write-ImportLogVerbose "Searching for *Employee.dat files in: $FolderPath" -EnableVerbose:$EnableVerbose
    $employeeFiles = Get-ChildItem -Path $FolderPath -Name "*Employee.dat"
    Write-ImportLogVerbose "Found $($employeeFiles.Count) Employee.dat file(s)" -EnableVerbose:$EnableVerbose

    if ($employeeFiles.Count -eq 0) {
        Write-ImportLog "No *Employee.dat file found in $FolderPath" -Level "ERROR"
        throw "No *Employee.dat file found. Cannot determine prefix."
    }

    if ($employeeFiles.Count -gt 1) {
        Write-ImportLog "Multiple Employee.dat files found, cannot determine unique prefix" -Level "ERROR"
        Write-Warning "Multiple Employee.dat files found:"
        $employeeFiles | ForEach-Object {
            Write-Host "  $_"
            Write-ImportLogVerbose "Found file: $_" -EnableVerbose:$EnableVerbose
        }
        throw "Cannot uniquely determine prefix. Multiple Employee.dat files found."
    }

    $employeeFile = $employeeFiles[0]
    $prefix = $employeeFile -replace "Employee\.dat$", ""

    Write-Host "Found: $employeeFile" -ForegroundColor Green
    Write-Host "Detected prefix: '$prefix'" -ForegroundColor Green
    Write-ImportLog "Prefix detection successful - File: $employeeFile, Prefix: '$prefix'" -Level "SUCCESS"

    return $prefix
}

function Get-TableSpecifications {
    param(
        [Parameter(Mandatory=$true)]
        [string]$ExcelPath,

        [switch]$EnableVerbose = $false
    )

    Write-ImportLog "Starting to read table specifications from Excel: $ExcelPath" -Level "INFO"
    Write-Host "`nReading table specifications from Excel..." -ForegroundColor Yellow

    if (-not (Test-Path $ExcelPath)) {
        Write-ImportLog "Excel specification file not found: $ExcelPath" -Level "ERROR"
        throw "Excel specification file not found: $ExcelPath"
    }

    Write-ImportLogVerbose "Excel file exists, attempting to read specifications" -EnableVerbose:$EnableVerbose
    try {
        $specs = Import-Excel -Path $ExcelPath
        Write-Host "Successfully read $($specs.Count) field specifications" -ForegroundColor Green
        Write-ImportLog "Successfully read $($specs.Count) field specifications from Excel" -Level "SUCCESS"
        Write-ImportLogVerbose "Specifications loaded for tables: $(($specs | Select-Object -Unique 'Table name').'Table name' -join ', ')" -EnableVerbose:$EnableVerbose
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
        [string]$ConnectionString,

        [switch]$EnableVerbose = $false
    )

    Write-ImportLogVerbose "Testing database connection..." -EnableVerbose:$EnableVerbose
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
        [string]$TableName,

        [switch]$EnableVerbose = $false
    )

    Write-ImportLogVerbose "Checking if table [$SchemaName].[$TableName] exists" -EnableVerbose:$EnableVerbose
    $query = @"
SELECT COUNT(*)
FROM INFORMATION_SCHEMA.TABLES
WHERE TABLE_SCHEMA = '$SchemaName' AND TABLE_NAME = '$TableName'
"@

    try {
        $result = Invoke-Sqlcmd -ConnectionString $ConnectionString -Query $query -ErrorAction Stop
        $exists = $result.Column1 -gt 0
        Write-ImportLogVerbose "Table [$SchemaName].[$TableName] exists: $exists" -EnableVerbose:$EnableVerbose
        return $exists
    }
    catch {
        Write-ImportLogVerbose "Error checking table existence: $($_.Exception.Message)" -EnableVerbose:$EnableVerbose
        return $false
    }
}

function New-DatabaseSchema {
    param(
        [Parameter(Mandatory=$true)]
        [string]$ConnectionString,

        [Parameter(Mandatory=$true)]
        [string]$SchemaName,

        [switch]$EnableVerbose = $false
    )

    Write-ImportLog "Creating/verifying schema: $SchemaName" -Level "INFO"
    $query = @"
IF NOT EXISTS (SELECT * FROM sys.schemas WHERE name = '$SchemaName')
BEGIN
    EXEC('CREATE SCHEMA [$SchemaName]')
    PRINT 'Schema [$SchemaName] created successfully'
END
ELSE
BEGIN
    PRINT 'Schema [$SchemaName] already exists'
END
"@

    Write-ImportLogVerbose "Executing schema creation query for: $SchemaName" -EnableVerbose:$EnableVerbose
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
        [array]$Fields,

        [switch]$EnableVerbose = $false
    )

    Write-ImportLog "Creating table [$SchemaName].[$TableName] with $($Fields.Count) fields" -Level "INFO"
    $fieldDefinitions = @()

    foreach ($field in $Fields) {
        $sqlType = Get-SqlDataTypeMapping -ExcelType $field."Field type" -Precision $field.Precision
        $fieldDef = "    [$($field.'Field name')] $sqlType"
        $fieldDefinitions += $fieldDef
        Write-ImportLogVerbose "Field definition: $fieldDef" -EnableVerbose:$EnableVerbose
    }

    $createTableQuery = @"
CREATE TABLE [$SchemaName].[$TableName] (
$($fieldDefinitions -join ",`n")
)
"@

    Write-ImportLogVerbose "Executing table creation query for [$SchemaName].[$TableName]" -EnableVerbose:$EnableVerbose
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
        [string]$TableName,

        [switch]$EnableVerbose = $false
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
        [string]$TableName,

        [switch]$EnableVerbose = $false
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

function Import-DataFileBulk {
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
        [array]$Fields,

        [bool]$SkipFirstField = $false,

        [switch]$EnableVerbose = $false
    )

    $fileName = [System.IO.Path]::GetFileName($FilePath)
    Write-ImportLog "Starting bulk data import for table [$SchemaName].[$TableName] from file: $fileName" -Level "INFO"
    Write-Host "Importing data from $fileName using SqlBulkCopy..." -ForegroundColor Yellow

    # Read the file and parse pipe-separated data
    Write-ImportLogVerbose "Reading data file: $FilePath" -EnableVerbose:$EnableVerbose
    $lines = Get-Content -Path $FilePath
    Write-ImportLogVerbose "Read $($lines.Count) lines from data file" -EnableVerbose:$EnableVerbose

    if ($lines.Count -eq 0) {
        Write-ImportLog "Data file is empty: $FilePath" -Level "WARNING"
        Write-Warning "File is empty: $FilePath"
        return 0
    }

    # Create DataTable structure
    $dataTable = New-Object System.Data.DataTable
    Write-ImportLogVerbose "Creating DataTable structure with $($Fields.Count) columns" -EnableVerbose:$EnableVerbose

    foreach ($field in $Fields) {
        $column = New-Object System.Data.DataColumn
        $column.ColumnName = $field.'Field name'

        # Map SQL types to .NET types for DataTable
        $sqlType = Get-SqlDataTypeMapping -ExcelType $field."Field type" -Precision $field.Precision
        switch -Regex ($sqlType.ToUpper()) {
            "^INT" { $column.DataType = [System.Int32] }
            "^BIGINT" { $column.DataType = [System.Int64] }
            "^SMALLINT" { $column.DataType = [System.Int16] }
            "^TINYINT" { $column.DataType = [System.Byte] }
            "^BIT" { $column.DataType = [System.Boolean] }
            "^FLOAT" { $column.DataType = [System.Double] }
            "^REAL" { $column.DataType = [System.Single] }
            "^DECIMAL|^MONEY|^NUMERIC" { $column.DataType = [System.Decimal] }
            "^DATE|^DATETIME" { $column.DataType = [System.DateTime] }
            default { $column.DataType = [System.String] }
        }

        $dataTable.Columns.Add($column)
        Write-ImportLogVerbose "Added column: $($field.'Field name') as $($column.DataType)" -EnableVerbose:$EnableVerbose
    }

    # Populate DataTable with data
    $rowCount = 0
    Write-ImportLogVerbose "Populating DataTable with data" -EnableVerbose:$EnableVerbose

    foreach ($line in $lines) {
        if ([string]::IsNullOrWhiteSpace($line)) { continue }

        $values = $line -split '\|'
        Write-ImportLogVerbose "Processing line with $($values.Length) fields" -EnableVerbose:$EnableVerbose

        # Skip first field if determined necessary
        if ($SkipFirstField -and $values.Length -gt 0) {
            $originalCount = $values.Length
            $values = $values[1..($values.Length - 1)]
            Write-ImportLogVerbose "Skipped first field - Original: $originalCount, After skip: $($values.Length)" -EnableVerbose:$EnableVerbose
        }

        # Create DataRow and populate with values
        $dataRow = $dataTable.NewRow()

        for ($i = 0; $i -lt [Math]::Min($values.Length, $Fields.Count); $i++) {
            $value = $values[$i].Trim()
            $fieldName = $Fields[$i].'Field name'

            if ([string]::IsNullOrEmpty($value) -or $value -eq "NULL") {
                $dataRow[$fieldName] = [DBNull]::Value
            }
            else {
                try {
                    # Convert value to appropriate type
                    $column = $dataTable.Columns[$fieldName]
                    if ($column.DataType -eq [System.Boolean]) {
                        $dataRow[$fieldName] = [System.Convert]::ToBoolean($value)
                    }
                    elseif ($column.DataType -eq [System.DateTime]) {
                        $dataRow[$fieldName] = [System.DateTime]::Parse($value)
                    }
                    elseif ($column.DataType -eq [System.Decimal]) {
                        $dataRow[$fieldName] = [System.Decimal]::Parse($value)
                    }
                    elseif ($column.DataType -eq [System.Double]) {
                        $dataRow[$fieldName] = [System.Double]::Parse($value)
                    }
                    elseif ($column.DataType -eq [System.Single]) {
                        $dataRow[$fieldName] = [System.Single]::Parse($value)
                    }
                    elseif ($column.DataType -eq [System.Int64]) {
                        $dataRow[$fieldName] = [System.Int64]::Parse($value)
                    }
                    elseif ($column.DataType -eq [System.Int32]) {
                        $dataRow[$fieldName] = [System.Int32]::Parse($value)
                    }
                    elseif ($column.DataType -eq [System.Int16]) {
                        $dataRow[$fieldName] = [System.Int16]::Parse($value)
                    }
                    elseif ($column.DataType -eq [System.Byte]) {
                        $dataRow[$fieldName] = [System.Byte]::Parse($value)
                    }
                    else {
                        $dataRow[$fieldName] = $value
                    }
                }
                catch {
                    # If conversion fails, store as string
                    Write-ImportLogVerbose "Type conversion failed for $fieldName, using string value: $($_.Exception.Message)" -EnableVerbose:$EnableVerbose
                    $dataRow[$fieldName] = $value
                }
            }
        }

        $dataTable.Rows.Add($dataRow)
        $rowCount++

        if ($rowCount % 10000 -eq 0) {
            Write-ImportLogVerbose "Processed $rowCount rows into DataTable" -EnableVerbose:$EnableVerbose
        }
    }

    Write-ImportLogVerbose "DataTable populated with $rowCount rows" -EnableVerbose:$EnableVerbose

    # Perform bulk copy
    try {
        $connection = New-Object System.Data.SqlClient.SqlConnection($ConnectionString)
        $connection.Open()
        Write-ImportLogVerbose "Database connection opened for bulk copy" -EnableVerbose:$EnableVerbose

        $bulkCopy = New-Object System.Data.SqlClient.SqlBulkCopy($connection)
        $bulkCopy.DestinationTableName = "[$SchemaName].[$TableName]"
        $bulkCopy.BatchSize = 10000
        $bulkCopy.BulkCopyTimeout = 300  # 5 minutes

        # Map columns
        foreach ($field in $Fields) {
            $bulkCopy.ColumnMappings.Add($field.'Field name', $field.'Field name') | Out-Null
        }

        Write-ImportLogVerbose "Starting SqlBulkCopy operation with batch size: $($bulkCopy.BatchSize)" -EnableVerbose:$EnableVerbose
        $bulkCopy.WriteToServer($dataTable)

        $bulkCopy.Close()
        $connection.Close()

        Write-Host "Successfully imported $rowCount rows into [$SchemaName].[$TableName]" -ForegroundColor Green
        Write-ImportLog "Bulk data import completed successfully - $rowCount rows imported into [$SchemaName].[$TableName]" -Level "SUCCESS"

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

function Import-DataFileStandard {
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
        [array]$Fields,

        [bool]$SkipFirstField = $false,

        [switch]$EnableVerbose = $false
    )

    $fileName = [System.IO.Path]::GetFileName($FilePath)
    Write-ImportLog "Starting standard data import for table [$SchemaName].[$TableName] from file: $fileName" -Level "INFO"
    Write-Host "Importing data from $fileName using INSERT statements..." -ForegroundColor Yellow

    # Read the file and parse pipe-separated data
    Write-ImportLogVerbose "Reading data file: $FilePath" -EnableVerbose:$EnableVerbose
    $lines = Get-Content -Path $FilePath
    Write-ImportLogVerbose "Read $($lines.Count) lines from data file" -EnableVerbose:$EnableVerbose

    if ($lines.Count -eq 0) {
        Write-ImportLog "Data file is empty: $FilePath" -Level "WARNING"
        Write-Warning "File is empty: $FilePath"
        return 0
    }

    $fieldNames = $Fields.'Field name' -join "], ["
    $insertQuery = "INSERT INTO [$SchemaName].[$TableName] ([$fieldNames]) VALUES "

    $batchSize = 1000
    $valueRows = @()
    $rowCount = 0
    Write-ImportLogVerbose "Starting data processing with batch size: $batchSize" -EnableVerbose:$EnableVerbose

    foreach ($line in $lines) {
        if ([string]::IsNullOrWhiteSpace($line)) { continue }

        $values = $line -split '\|'
        Write-ImportLogVerbose "Processing line with $($values.Length) fields" -EnableVerbose:$EnableVerbose

        # Skip first field if determined necessary
        if ($SkipFirstField -and $values.Length -gt 0) {
            $originalCount = $values.Length
            $values = $values[1..($values.Length - 1)]
            Write-ImportLogVerbose "Skipped first field - Original: $originalCount, After skip: $($values.Length)" -EnableVerbose:$EnableVerbose
        }

        # Escape single quotes and handle nulls
        $escapedValues = @()
        for ($i = 0; $i -lt $values.Length; $i++) {
            $value = $values[$i].Trim()
            if ([string]::IsNullOrEmpty($value) -or $value -eq "NULL") {
                $escapedValues += "NULL"
            }
            else {
                $escapedValues += "'$($value -replace "'", "''")'"
            }
        }

        $valueRows += "($($escapedValues -join ', '))"
        $rowCount++

        # Execute batch when we reach batch size
        if ($valueRows.Count -ge $batchSize) {
            $batchQuery = $insertQuery + ($valueRows -join ', ')
            Write-ImportLogVerbose "Executing batch insert with $($valueRows.Count) rows" -EnableVerbose:$EnableVerbose
            try {
                Invoke-Sqlcmd -ConnectionString $ConnectionString -Query $batchQuery -ErrorAction Stop
                Write-Host "  Inserted $($valueRows.Count) rows (Total: $rowCount)" -ForegroundColor Gray
                Write-ImportLogVerbose "Batch insert successful - $($valueRows.Count) rows inserted" -EnableVerbose:$EnableVerbose
            }
            catch {
                Write-ImportLog "Failed to insert batch: $($_.Exception.Message)" -Level "ERROR"
                throw "Failed to insert batch: $($_.Exception.Message)"
            }
            $valueRows = @()
        }
    }

    # Insert remaining rows
    if ($valueRows.Count -gt 0) {
        $batchQuery = $insertQuery + ($valueRows -join ', ')
        Write-ImportLogVerbose "Executing final batch insert with $($valueRows.Count) rows" -EnableVerbose:$EnableVerbose
        try {
            Invoke-Sqlcmd -ConnectionString $ConnectionString -Query $batchQuery -ErrorAction Stop
            Write-Host "  Inserted final $($valueRows.Count) rows (Total: $rowCount)" -ForegroundColor Gray
            Write-ImportLogVerbose "Final batch insert successful - $($valueRows.Count) rows inserted" -EnableVerbose:$EnableVerbose
        }
        catch {
            Write-ImportLog "Failed to insert final batch: $($_.Exception.Message)" -Level "ERROR"
            throw "Failed to insert final batch: $($_.Exception.Message)"
        }
    }

    Write-Host "Successfully imported $rowCount rows into [$SchemaName].[$TableName]" -ForegroundColor Green
    Write-ImportLog "Data import completed successfully - $rowCount rows imported into [$SchemaName].[$TableName]" -Level "SUCCESS"

    return $rowCount
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
        [string]$SchemaName,

        [switch]$EnableVerbose = $false
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
        Write-ImportLogVerbose "Summary entry: $tableDisplay - $rowDisplay rows" -EnableVerbose:$EnableVerbose
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
        [string]$TableExistsAction = "Ask",

        [ValidateSet("Ask", "Skip", "Exit")]
        [string]$FieldMismatchAction = "Ask",

        [switch]$EnableVerbose = $false
    )

    # Clear previous summary
    Clear-ImportSummary

    try {
        Write-ImportLog "Starting SQL Server data import" -Level "INFO" -EnableVerbose:$EnableVerbose

        # Validate paths
        if (-not (Test-Path $DataFolder)) {
            throw "Data folder not found: $DataFolder"
        }

        $excelPath = Join-Path $DataFolder $ExcelSpecFile
        if (-not (Test-Path $excelPath)) {
            throw "Excel specification file not found: $excelPath"
        }

        # Find prefix and validate connection
        $prefix = Get-DataPrefix -FolderPath $DataFolder -EnableVerbose:$EnableVerbose

        if (-not (Test-DatabaseConnection -ConnectionString $ConnectionString -EnableVerbose:$EnableVerbose)) {
            throw "Database connection test failed"
        }

        # Determine schema name
        if (-not $SchemaName) {
            $SchemaName = $prefix
        }

        # Create schema
        New-DatabaseSchema -ConnectionString $ConnectionString -SchemaName $SchemaName -EnableVerbose:$EnableVerbose

        # Read table specifications
        $tableSpecs = Get-TableSpecifications -ExcelPath $excelPath -EnableVerbose:$EnableVerbose

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
            $tableExists = Test-TableExists -ConnectionString $ConnectionString -SchemaName $SchemaName -TableName $tableName -EnableVerbose:$EnableVerbose

            if ($tableExists) {
                switch ($TableExistsAction) {
                    "Skip" {
                        Write-Host "Skipping existing table '$tableName'" -ForegroundColor Yellow
                        continue
                    }
                    "Truncate" {
                        Clear-DatabaseTable -ConnectionString $ConnectionString -SchemaName $SchemaName -TableName $tableName -EnableVerbose:$EnableVerbose
                    }
                    "Recreate" {
                        Remove-DatabaseTable -ConnectionString $ConnectionString -SchemaName $SchemaName -TableName $tableName -EnableVerbose:$EnableVerbose
                        New-DatabaseTable -ConnectionString $ConnectionString -SchemaName $SchemaName -TableName $tableName -Fields $tableFields -EnableVerbose:$EnableVerbose
                    }
                }
            }
            else {
                New-DatabaseTable -ConnectionString $ConnectionString -SchemaName $SchemaName -TableName $tableName -Fields $tableFields -EnableVerbose:$EnableVerbose
            }

            # Determine if we need to skip first field
            $skipFirstField = $false
            if ($FieldMismatchAction -eq "Skip") {
                $skipFirstField = $true
            }
            elseif ($FieldMismatchAction -eq "Ask") {
                # Check field count
                $testLines = Get-Content -Path $datFile.FullName -TotalCount 1
                if ($testLines.Count -gt 0) {
                    $firstLineFields = ($testLines[0] -split '\|').Count
                    $specFieldCount = $tableFields.Count
                    if ($firstLineFields -eq ($specFieldCount + 1)) {
                        $skipFirstField = $true
                        Write-Host "Auto-detected field mismatch - skipping first field" -ForegroundColor Green
                    }
                }
            }

            # Import data with fallback
            try {
                $rowsImported = Import-DataFileBulk -ConnectionString $ConnectionString -SchemaName $SchemaName -TableName $tableName -FilePath $datFile.FullName -Fields $tableFields -SkipFirstField $skipFirstField -EnableVerbose:$EnableVerbose
                Write-ImportLog "Used efficient SqlBulkCopy for import" -Level "SUCCESS"
            }
            catch {
                Write-ImportLog "Bulk copy failed, falling back to standard import: $($_.Exception.Message)" -Level "WARNING"
                $rowsImported = Import-DataFileStandard -ConnectionString $ConnectionString -SchemaName $SchemaName -TableName $tableName -FilePath $datFile.FullName -Fields $tableFields -SkipFirstField $skipFirstField -EnableVerbose:$EnableVerbose
            }

            Add-ImportSummary -TableName $tableName -RowCount $rowsImported -FileName $datFile.Name
        }

        # Display summary
        Show-ImportSummary -SchemaName $SchemaName -EnableVerbose:$EnableVerbose

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
    'Test-DatabaseConnection',
    'New-DatabaseSchema',
    'New-DatabaseTable',
    'Import-DataFileBulk',
    'Import-DataFileStandard',
    'Show-ImportSummary',
    'Clear-ImportSummary',
    'Write-ImportLog',
    'Write-ImportLogVerbose'
)