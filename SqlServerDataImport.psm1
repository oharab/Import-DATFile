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

function Get-DotNetDataType {
    param(
        [Parameter(Mandatory=$true)]
        [string]$SqlType
    )

    $type = $SqlType.ToUpper()

    switch -Regex ($type) {
        "^DATE$|^DATETIME.*|^TIME$" { return [System.DateTime] }
        "^INT$|^INTEGER$|^SMALLINT$|^TINYINT$" { return [System.Int32] }
        "^BIGINT$" { return [System.Int64] }
        "^FLOAT$|^DOUBLE.*" { return [System.Double] }
        "^REAL$" { return [System.Single] }
        "^DECIMAL.*|^NUMERIC.*|^MONEY$" { return [System.Decimal] }
        "^BIT$|^BOOLEAN$" { return [System.Boolean] }
        default { return [System.String] }
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

    # Add columns for each field from specification with proper data types
    foreach ($field in $Fields) {
        $column = New-Object System.Data.DataColumn
        $column.ColumnName = $field.'Column name'

        # Get SQL type and map to proper .NET type for better SqlBulkCopy handling
        $sqlType = Get-SqlDataTypeMapping -ExcelType $field."Data type" -Precision $field.Precision
        $column.DataType = Get-DotNetDataType -SqlType $sqlType

        $dataTable.Columns.Add($column)
    }

    # Expected field count = ImportID (from file) + spec fields
    $expectedFieldCount = $Fields.Count + 1

    # Populate DataTable with data using multi-line field support
    $rowCount = 0
    $totalLines = $lines.Count
    $currentLineIndex = 0

    while ($currentLineIndex -lt $totalLines) {
        $startLineNumber = $currentLineIndex + 1
        $currentLine = $lines[$currentLineIndex]

        # Skip empty lines at the start of a record
        if ([string]::IsNullOrWhiteSpace($currentLine)) {
            $currentLineIndex++
            continue
        }

        # Start building the record from current line
        $accumulatedLine = $currentLine
        $values = $accumulatedLine -split '\|', -1  # -1 to keep empty trailing fields
        $linesConsumed = 1

        # Keep reading and accumulating lines until we have enough fields
        while ($values.Length -lt $expectedFieldCount -and ($currentLineIndex + 1) -lt $totalLines) {
            $currentLineIndex++
            $nextLine = $lines[$currentLineIndex]
            # Preserve the newline when accumulating (this is the embedded newline in the field)
            $accumulatedLine += "`n" + $nextLine
            $values = $accumulatedLine -split '\|', -1
            $linesConsumed++
        }

        # Validate final field count
        if ($values.Length -ne $expectedFieldCount) {
            $endLineNumber = $startLineNumber + $linesConsumed - 1
            Write-ImportLog "Field count mismatch at lines $startLineNumber-$endLineNumber. Expected $expectedFieldCount, got $($values.Length)" -Level "ERROR"
            Write-Host "FAILED at line $startLineNumber (consumed $linesConsumed lines)" -ForegroundColor Red
            Write-Host "Accumulated content: $($accumulatedLine.Substring(0, [Math]::Min(200, $accumulatedLine.Length)))..." -ForegroundColor Red
            throw "Field count mismatch at lines $startLineNumber-$endLineNumber. Expected $expectedFieldCount fields, got $($values.Length)."
        }

        if ($linesConsumed -gt 1) {
            Write-Host "  Multi-line record at line $startLineNumber (spans $linesConsumed lines)" -ForegroundColor Cyan
        }

        # Create DataRow and populate with values
        $dataRow = $dataTable.NewRow()

        # First field is always ImportID
        $dataRow["ImportID"] = $values[0].Trim()

        # Remaining fields map to specification fields
        for ($i = 0; $i -lt $Fields.Count; $i++) {
            $value = $values[$i + 1].Trim()
            $fieldName = $Fields[$i].'Column name'
            $columnType = $dataTable.Columns[$fieldName].DataType

            # Check for NULL values - case insensitive and whitespace aware
            if ([string]::IsNullOrWhiteSpace($value) -or $value -match '^(NULL|NA|N/A)$') {
                $dataRow[$fieldName] = [DBNull]::Value
            }
            else {
                # Convert value to proper type based on column definition
                try {
                    if ($columnType -eq [System.DateTime]) {
                        # Parse datetime using InvariantCulture for consistent behavior
                        # Try multiple common formats
                        $formats = @(
                            "yyyy-MM-dd HH:mm:ss.fff",
                            "yyyy-MM-dd HH:mm:ss.ff",
                            "yyyy-MM-dd HH:mm:ss.f",
                            "yyyy-MM-dd HH:mm:ss",
                            "yyyy-MM-dd"
                        )
                        $parsed = $false
                        foreach ($format in $formats) {
                            try {
                                $dataRow[$fieldName] = [DateTime]::ParseExact($value, $format, [System.Globalization.CultureInfo]::InvariantCulture)
                                $parsed = $true
                                break
                            }
                            catch { }
                        }
                        if (-not $parsed) {
                            # Fallback to culture-aware parsing
                            $dataRow[$fieldName] = [DateTime]::Parse($value, [System.Globalization.CultureInfo]::InvariantCulture)
                        }
                    }
                    elseif ($columnType -eq [System.Int32]) {
                        # Handle integers that may have decimal notation (e.g., "123.0")
                        $decimalValue = [Decimal]::Parse($value, [System.Globalization.CultureInfo]::InvariantCulture)
                        $dataRow[$fieldName] = [Int32]$decimalValue
                    }
                    elseif ($columnType -eq [System.Int64]) {
                        # Handle big integers that may have decimal notation
                        $decimalValue = [Decimal]::Parse($value, [System.Globalization.CultureInfo]::InvariantCulture)
                        $dataRow[$fieldName] = [Int64]$decimalValue
                    }
                    elseif ($columnType -eq [System.Double]) {
                        # FLOAT - use InvariantCulture for consistent decimal separator
                        $dataRow[$fieldName] = [Double]::Parse($value, [System.Globalization.CultureInfo]::InvariantCulture)
                    }
                    elseif ($columnType -eq [System.Single]) {
                        # REAL - use InvariantCulture for consistent decimal separator
                        $dataRow[$fieldName] = [Single]::Parse($value, [System.Globalization.CultureInfo]::InvariantCulture)
                    }
                    elseif ($columnType -eq [System.Decimal]) {
                        # DECIMAL/NUMERIC/MONEY - use InvariantCulture for consistent decimal separator
                        $dataRow[$fieldName] = [Decimal]::Parse($value, [System.Globalization.CultureInfo]::InvariantCulture)
                    }
                    elseif ($columnType -eq [System.Boolean]) {
                        # Handle common boolean representations
                        switch -Regex ($value.ToUpper()) {
                            '^(1|TRUE|YES|Y|T)$' { $dataRow[$fieldName] = $true }
                            '^(0|FALSE|NO|N|F)$' { $dataRow[$fieldName] = $false }
                            default {
                                Write-ImportLog "Invalid boolean value '$value' for field '$fieldName' at line $startLineNumber. Using False." -Level "WARNING"
                                $dataRow[$fieldName] = $false
                            }
                        }
                    }
                    else {
                        # String types - assign directly
                        $dataRow[$fieldName] = $value
                    }
                }
                catch {
                    Write-ImportLog "Error converting value '$value' for field '$fieldName' at line $startLineNumber. Expected type: $($columnType.Name). Error: $($_.Exception.Message)" -Level "WARNING"
                    # Assign as string and let SqlBulkCopy try to handle it
                    $dataRow[$fieldName] = $value
                }
            }
        }

        $dataTable.Rows.Add($dataRow)
        $rowCount++

        if ($rowCount % 10000 -eq 0) {
            Write-Host "  Processed $rowCount rows..." -ForegroundColor Gray
        }

        # Move to next record (may have already advanced during multi-line accumulation)
        $currentLineIndex++
    }

    # Perform bulk copy
    try {
        $connection = New-Object System.Data.SqlClient.SqlConnection($ConnectionString)
        $connection.Open()

        # Verify SQL table columns exist
        Write-Host "Verifying SQL table columns..." -ForegroundColor Yellow
        $sqlTableColumnsQuery = @"
SELECT COLUMN_NAME
FROM INFORMATION_SCHEMA.COLUMNS
WHERE TABLE_SCHEMA = '$SchemaName' AND TABLE_NAME = '$TableName'
ORDER BY ORDINAL_POSITION
"@
        $sqlTableColumns = Invoke-Sqlcmd -ConnectionString $ConnectionString -Query $sqlTableColumnsQuery
        $sqlColumnNames = $sqlTableColumns.COLUMN_NAME

        Write-Host "SQL Table Columns: $($sqlColumnNames -join ', ')" -ForegroundColor Gray
        Write-Host "DataTable Columns: $($dataTable.Columns.ColumnName -join ', ')" -ForegroundColor Gray

        # Check for mismatches
        foreach ($dtColumn in $dataTable.Columns) {
            if ($dtColumn.ColumnName -notin $sqlColumnNames) {
                Write-Host "WARNING: DataTable column '$($dtColumn.ColumnName)' not found in SQL table!" -ForegroundColor Red
            }
        }

        $bulkCopy = New-Object System.Data.SqlClient.SqlBulkCopy($connection)
        $bulkCopy.DestinationTableName = "[$SchemaName].[$TableName]"
        $bulkCopy.BatchSize = 10000
        $bulkCopy.BulkCopyTimeout = 300  # 5 minutes

        Write-ImportLog "Setting up column mappings for $($dataTable.Columns.Count) columns" -Level "INFO"

        # Map each column from DataTable to SQL table
        foreach ($column in $dataTable.Columns) {
            $columnName = $column.ColumnName
            Write-Host "  Mapping column: $columnName (Type: $($column.DataType.Name))" -ForegroundColor Gray
            $bulkCopy.ColumnMappings.Add($columnName, $columnName) | Out-Null
        }

        Write-Host "Starting bulk copy operation..." -ForegroundColor Yellow
        $bulkCopy.WriteToServer($dataTable)

        $bulkCopy.Close()
        $connection.Close()

        Write-Host "Successfully imported $rowCount rows into [$SchemaName].[$TableName]" -ForegroundColor Green
        Write-ImportLog "Data import completed successfully - $rowCount rows imported into [$SchemaName].[$TableName]" -Level "SUCCESS"

        return $rowCount
    }
    catch {
        Write-ImportLog "Bulk copy failed: $($_.Exception.Message)" -Level "ERROR"
        Write-Host "`nBulk Copy Error Details:" -ForegroundColor Red
        Write-Host "Table: [$SchemaName].[$TableName]" -ForegroundColor Red
        Write-Host "DataTable Columns: $($dataTable.Columns.Count)" -ForegroundColor Red
        Write-Host "Column Names: $($dataTable.Columns.ColumnName -join ', ')" -ForegroundColor Red
        Write-Host "Error: $($_.Exception.Message)" -ForegroundColor Red

        if ($_.Exception.InnerException) {
            Write-Host "Inner Exception: $($_.Exception.InnerException.Message)" -ForegroundColor Red
        }

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

#region Post-Install Script Functions

function Invoke-PostInstallScripts {
    <#
    .SYNOPSIS
    Executes SQL template files after data import with placeholder replacement.

    .DESCRIPTION
    Reads SQL template files from a specified folder, replaces placeholders with
    actual values (database name, schema name), and executes them using the
    current database connection. This is useful for creating views, stored procedures,
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
    param(
        [Parameter(Mandatory=$true)]
        [string]$ScriptPath,

        [Parameter(Mandatory=$true)]
        [string]$ConnectionString,

        [Parameter(Mandatory=$true)]
        [string]$DatabaseName,

        [Parameter(Mandatory=$true)]
        [string]$SchemaName
    )

    Write-ImportLog "Starting post-install script execution" -Level "INFO"

    # Determine if ScriptPath is a file or folder
    $sqlFiles = @()

    if (Test-Path -Path $ScriptPath -PathType Leaf) {
        # Single file
        $sqlFiles += Get-Item -Path $ScriptPath
        Write-ImportLog "Post-install: Single SQL file specified: $ScriptPath" -Level "INFO"
    }
    elseif (Test-Path -Path $ScriptPath -PathType Container) {
        # Folder - get all .sql files
        $sqlFiles = Get-ChildItem -Path $ScriptPath -Filter "*.sql" | Sort-Object Name
        Write-ImportLog "Post-install: Found $($sqlFiles.Count) SQL files in folder: $ScriptPath" -Level "INFO"
    }
    else {
        Write-ImportLog "Post-install script path not found: $ScriptPath" -Level "ERROR"
        throw "Post-install script path not found: $ScriptPath"
    }

    if ($sqlFiles.Count -eq 0) {
        Write-ImportLog "No SQL files found for post-install execution" -Level "WARNING"
        return
    }

    $successCount = 0
    $errorCount = 0

    foreach ($sqlFile in $sqlFiles) {
        Write-Host "`nExecuting post-install script: $($sqlFile.Name)" -ForegroundColor Cyan
        Write-ImportLog "Post-install: Executing $($sqlFile.Name)" -Level "INFO"

        try {
            # Read the SQL template file
            $sqlTemplate = Get-Content -Path $sqlFile.FullName -Raw

            # Replace placeholders
            $sql = $sqlTemplate
            $sql = $sql -replace '\{\{DATABASE\}\}', $DatabaseName
            $sql = $sql -replace '\{\{SCHEMA\}\}', $SchemaName

            # Show what we're about to execute (first 200 chars)
            $preview = $sql.Substring(0, [Math]::Min(200, $sql.Length))
            Write-Host "  Preview: $preview..." -ForegroundColor Gray

            # Execute the SQL script
            Invoke-Sqlcmd -ConnectionString $ConnectionString -Query $sql -QueryTimeout 300

            Write-Host "  ✓ Successfully executed $($sqlFile.Name)" -ForegroundColor Green
            Write-ImportLog "Post-install: Successfully executed $($sqlFile.Name)" -Level "SUCCESS"
            $successCount++
        }
        catch {
            Write-Host "  ✗ Failed to execute $($sqlFile.Name): $($_.Exception.Message)" -ForegroundColor Red
            Write-ImportLog "Post-install: Failed to execute $($sqlFile.Name): $($_.Exception.Message)" -Level "ERROR"
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

    Write-ImportLog "Post-install script execution completed: $successCount successful, $errorCount failed" -Level "INFO"

    if ($errorCount -gt 0) {
        throw "Post-install script execution completed with $errorCount errors"
    }
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

        [string]$PostInstallScripts
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

        # Execute post-install scripts if specified
        if (-not [string]::IsNullOrWhiteSpace($PostInstallScripts)) {
            Write-Host "`n=== Post-Install Scripts ===" -ForegroundColor Cyan
            Write-ImportLog "Post-install scripts specified: $PostInstallScripts" -Level "INFO"

            # Extract database name from connection string
            $databaseName = ""
            if ($ConnectionString -match "Database=([^;]+)") {
                $databaseName = $Matches[1]
            }
            elseif ($ConnectionString -match "Initial Catalog=([^;]+)") {
                $databaseName = $Matches[1]
            }

            if ([string]::IsNullOrWhiteSpace($databaseName)) {
                Write-ImportLog "Could not extract database name from connection string for placeholder replacement" -Level "WARNING"
                Write-Host "Warning: Could not extract database name from connection string" -ForegroundColor Yellow
            }

            try {
                Invoke-PostInstallScripts -ScriptPath $PostInstallScripts -ConnectionString $ConnectionString -DatabaseName $databaseName -SchemaName $SchemaName
                Write-ImportLog "Post-install scripts completed successfully" -Level "SUCCESS"
            }
            catch {
                Write-ImportLog "Post-install scripts failed: $($_.Exception.Message)" -Level "ERROR"
                Write-Host "`nWARNING: Post-install scripts failed but data import was successful" -ForegroundColor Yellow
                Write-Host "Error: $($_.Exception.Message)" -ForegroundColor Red
                # Don't throw - import was successful even if post-install failed
            }
        }

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
    'Invoke-PostInstallScripts',
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