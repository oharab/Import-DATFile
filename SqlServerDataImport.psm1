# SqlServerDataImport PowerShell Module (Refactored)
# Core functionality for importing pipe-separated .dat files into SQL Server
# Refactored to follow DRY and SOLID principles

#region Module Dependencies

# Import common utilities module
$moduleDir = Split-Path $PSCommandPath -Parent
$commonModulePath = Join-Path $moduleDir "Import-DATFile.Common.psm1"
if (Test-Path $commonModulePath) {
    Import-Module $commonModulePath -Force
}
else {
    throw "Common module not found at: $commonModulePath"
}

# Import constants
$constantsPath = Join-Path $moduleDir "Import-DATFile.Constants.ps1"
if (Test-Path $constantsPath) {
    . $constantsPath
}

#endregion

#region Global Variables

$script:ImportSummary = @()
$script:VerboseLogging = $false

#endregion

#region Logging Functions

function Write-ImportLog {
    <#
    .SYNOPSIS
    Writes user-facing log messages with different severity levels.

    .DESCRIPTION
    Centralized logging function for INFO and SUCCESS messages.
    For VERBOSE, DEBUG, WARNING, and ERROR messages, use PowerShell's
    built-in Write-Verbose, Write-Debug, Write-Warning, Write-Error cmdlets.

    .PARAMETER Message
    The log message to write.

    .PARAMETER Level
    Log level: INFO, SUCCESS only. Use built-in cmdlets for others.
    #>
    param(
        [Parameter(Mandatory=$true)]
        [string]$Message,

        [ValidateSet("INFO", "SUCCESS")]
        [string]$Level = "INFO"
    )

    $timestamp = Get-Date -Format "yyyy-MM-dd HH:mm:ss"
    $logMessage = "[$timestamp] [$Level] $Message"

    # Write to console with appropriate color
    switch ($Level.ToUpper()) {
        "SUCCESS" { Write-Host $logMessage -ForegroundColor Green }
        "INFO" { Write-Host $logMessage -ForegroundColor White }
        default { Write-Host $logMessage -ForegroundColor White }
    }
}

#endregion

#region File and Specification Functions

function Get-DataPrefix {
    <#
    .SYNOPSIS
    Detects data file prefix from Employee.dat file.

    .DESCRIPTION
    Scans folder for *Employee.dat file and extracts prefix.
    Requires exactly one Employee.dat file for unique prefix detection.

    .PARAMETER FolderPath
    Folder containing data files.

    .EXAMPLE
    $prefix = Get-DataPrefix -FolderPath "C:\Data"
    #>
    [CmdletBinding()]
    [OutputType([string])]
    param(
        [Parameter(Mandatory=$true)]
        [ValidateScript({ Test-Path $_ -PathType Container })]
        [string]$FolderPath
    )

    Write-Verbose "Starting prefix detection in folder: $FolderPath"
    Write-Host "`nDetecting data prefix from Employee.dat file..." -ForegroundColor Yellow

    $employeeFiles = Get-ChildItem -Path $FolderPath -Name "*Employee.dat"

    if ($employeeFiles.Count -eq 0) {
        Write-Error "No *Employee.dat file found in $FolderPath"
        throw "No *Employee.dat file found. Cannot determine prefix."
    }

    if ($employeeFiles.Count -gt 1) {
        Write-Error "Multiple Employee.dat files found, cannot determine unique prefix"
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

    Write-Host "Prefix detected: '$prefix' (from $employeeFile)" -ForegroundColor Green
    Write-Verbose "Prefix detection successful - File: $employeeFile, Prefix: '$prefix'"

    return $prefix
}

function Get-TableSpecifications {
    <#
    .SYNOPSIS
    Reads table specifications from Excel file.

    .DESCRIPTION
    Imports field specifications from Excel file that define table structure.

    .PARAMETER ExcelPath
    Path to Excel specification file.

    .EXAMPLE
    $specs = Get-TableSpecifications -ExcelPath "C:\Data\ExportSpec.xlsx"
    #>
    [CmdletBinding()]
    [OutputType([array])]
    param(
        [Parameter(Mandatory=$true)]
        [ValidateScript({ Test-Path $_ -PathType Leaf })]
        [string]$ExcelPath
    )

    Write-Verbose "Reading table specifications from Excel: $ExcelPath"
    Write-Host "`nReading table specifications from Excel..." -ForegroundColor Yellow

    try {
        $specs = Import-Excel -Path $ExcelPath
        Write-Host "Successfully read $($specs.Count) field specifications" -ForegroundColor Green
        Write-Verbose "Successfully read $($specs.Count) field specifications from Excel"
        return $specs
    }
    catch {
        Write-Error "Failed to read Excel file: $($_.Exception.Message)"
        throw "Failed to read Excel file: $($_.Exception.Message)"
    }
}

#endregion

#region Database Functions

function Test-DatabaseConnection {
    <#
    .SYNOPSIS
    Tests SQL Server database connection.

    .DESCRIPTION
    Attempts to open and close a connection to verify connectivity.

    .PARAMETER ConnectionString
    SQL Server connection string.

    .EXAMPLE
    if (Test-DatabaseConnection -ConnectionString $connStr) {
        Write-Host "Connected successfully"
    }
    #>
    [CmdletBinding()]
    [OutputType([bool])]
    param(
        [Parameter(Mandatory=$true)]
        [ValidateNotNullOrEmpty()]
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
        Write-Error "Database connection failed: $($_.Exception.Message)"
        return $false
    }
}

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
            Write-Error "Failed to create schema '$SchemaName': $($_.Exception.Message)"
            throw "Failed to create schema: $($_.Exception.Message)"
        }
    }
    else {
        Write-Host "What if: Would create or verify schema [$SchemaName]" -ForegroundColor Cyan
    }
}

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
        $sqlType = Get-SqlDataTypeMapping -ExcelType $field."Data type" -Precision $field.Precision
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
            Write-Error "Failed to create table [$SchemaName].[$TableName]: $($_.Exception.Message)"
            throw "Failed to create table [$SchemaName].[$TableName]: $($_.Exception.Message)"
        }
    }
    else {
        Write-Host "`nWhat if: Would create table [$SchemaName].[$TableName]" -ForegroundColor Cyan
        Write-Host "CREATE TABLE statement:" -ForegroundColor Yellow
        Write-Host $createTableQuery -ForegroundColor Gray
    }
}

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
            Write-Error "Failed to truncate table [$SchemaName].[$TableName]: $($_.Exception.Message)"
            throw "Failed to truncate table [$SchemaName].[$TableName]: $($_.Exception.Message)"
        }
    }
    else {
        Write-Host "What if: Would TRUNCATE table [$SchemaName].[$TableName] (ALL DATA WOULD BE DELETED)" -ForegroundColor Yellow
    }
}

#endregion

#region Data Import Functions - Refactored (SRP)

function Read-DatFileLines {
    <#
    .SYNOPSIS
    Reads DAT file lines with multi-line field support.

    .DESCRIPTION
    Reads file content and parses lines, handling embedded newlines in fields.
    Returns structured records ready for DataTable population.

    .PARAMETER FilePath
    Path to DAT file.

    .PARAMETER ExpectedFieldCount
    Expected number of fields per record (ImportID + specification fields).

    .EXAMPLE
    $records = Read-DatFileLines -FilePath "C:\Data\Employee.dat" -ExpectedFieldCount 10
    #>
    [CmdletBinding()]
    [OutputType([array])]
    param(
        [Parameter(Mandatory=$true)]
        [ValidateScript({ Test-Path $_ -PathType Leaf })]
        [string]$FilePath,

        [Parameter(Mandatory=$true)]
        [int]$ExpectedFieldCount
    )

    Write-Verbose "Reading DAT file: $FilePath (Expected fields: $ExpectedFieldCount)"

    $lines = Get-Content -Path $FilePath
    if ($lines.Count -eq 0) {
        Write-Warning "Data file is empty: $FilePath"
        return @()
    }

    $records = @()
    $totalLines = $lines.Count
    $currentLineIndex = 0

    while ($currentLineIndex -lt $totalLines) {
        $startLineNumber = $currentLineIndex + 1
        $currentLine = $lines[$currentLineIndex]

        # Skip empty lines
        if ([string]::IsNullOrWhiteSpace($currentLine)) {
            $currentLineIndex++
            continue
        }

        # Start building record
        $accumulatedLine = $currentLine
        $values = $accumulatedLine -split '\|', -1  # -1 to keep empty trailing fields
        $linesConsumed = 1

        # Accumulate lines until we have enough fields
        while ($values.Length -lt $ExpectedFieldCount -and ($currentLineIndex + 1) -lt $totalLines) {
            $currentLineIndex++
            $nextLine = $lines[$currentLineIndex]
            $accumulatedLine += "`n" + $nextLine
            $values = $accumulatedLine -split '\|', -1
            $linesConsumed++
        }

        # Validate final field count
        if ($values.Length -ne $ExpectedFieldCount) {
            $endLineNumber = $startLineNumber + $linesConsumed - 1
            Write-Error "Field count mismatch at lines $startLineNumber-$endLineNumber. Expected $ExpectedFieldCount, got $($values.Length)"
            $preview = $accumulatedLine.Substring(0, [Math]::Min($script:PREVIEW_TEXT_LENGTH, $accumulatedLine.Length))
            Write-Host "FAILED at line $startLineNumber (consumed $linesConsumed lines)" -ForegroundColor Red
            Write-Host "Content preview: $preview..." -ForegroundColor Red
            throw "Field count mismatch at lines $startLineNumber-$endLineNumber. Expected $ExpectedFieldCount fields, got $($values.Length)."
        }

        if ($linesConsumed -gt 1) {
            Write-Host "  Multi-line record at line $startLineNumber (spans $linesConsumed lines)" -ForegroundColor Cyan
        }

        $records += [PSCustomObject]@{
            LineNumber = $startLineNumber
            Values = $values
        }

        $currentLineIndex++
    }

    Write-Verbose "Read $($records.Count) records from file"
    return $records
}

function Add-DataTableRows {
    <#
    .SYNOPSIS
    Populates DataTable with records from DAT file.

    .DESCRIPTION
    Adds rows to DataTable with type conversion for each field.
    First field is ImportID, remaining fields match specification order.

    .PARAMETER DataTable
    DataTable to populate.

    .PARAMETER Records
    Array of records from Read-DatFileLines.

    .PARAMETER Fields
    Field specifications.

    .EXAMPLE
    Add-DataTableRows -DataTable $dt -Records $records -Fields $fields
    #>
    [CmdletBinding()]
    param(
        [Parameter(Mandatory=$true)]
        [System.Data.DataTable]$DataTable,

        [Parameter(Mandatory=$true)]
        [array]$Records,

        [Parameter(Mandatory=$true)]
        [array]$Fields
    )

    Write-Verbose "Populating DataTable with $($Records.Count) records"

    $rowCount = 0
    foreach ($record in $Records) {
        $dataRow = $DataTable.NewRow()
        $values = $record.Values

        # First field is always ImportID
        $dataRow["ImportID"] = $values[0].Trim()

        # Remaining fields map to specification fields
        for ($i = 0; $i -lt $Fields.Count; $i++) {
            $value = $values[$i + 1].Trim()
            $fieldName = $Fields[$i].'Column name'
            $columnType = $DataTable.Columns[$fieldName].DataType

            # Use centralized type conversion
            $dataRow[$fieldName] = ConvertTo-TypedValue -Value $value -TargetType $columnType -FieldName $fieldName -LineNumber $record.LineNumber
        }

        $DataTable.Rows.Add($dataRow)
        $rowCount++

        if ($rowCount % $script:PROGRESS_REPORT_INTERVAL -eq 0) {
            Write-Host "  Processed $rowCount rows..." -ForegroundColor Gray
        }
    }

    Write-Verbose "Populated $rowCount rows in DataTable"
}

function Invoke-SqlBulkCopy {
    <#
    .SYNOPSIS
    Performs SqlBulkCopy operation.

    .DESCRIPTION
    Executes high-performance bulk copy from DataTable to SQL Server table.

    .PARAMETER DataTable
    DataTable containing data to import.

    .PARAMETER ConnectionString
    SQL Server connection string.

    .PARAMETER SchemaName
    Schema name.

    .PARAMETER TableName
    Destination table name.

    .EXAMPLE
    $rowCount = Invoke-SqlBulkCopy -DataTable $dt -ConnectionString $conn -SchemaName "dbo" -TableName "Employee"
    #>
    [CmdletBinding()]
    [OutputType([int])]
    param(
        [Parameter(Mandatory=$true)]
        [System.Data.DataTable]$DataTable,

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

    Write-Verbose "Starting SqlBulkCopy operation to [$SchemaName].[$TableName]"

    try {
        $connection = New-Object System.Data.SqlClient.SqlConnection($ConnectionString)
        $connection.Open()

        $bulkCopy = New-Object System.Data.SqlClient.SqlBulkCopy($connection)
        $bulkCopy.DestinationTableName = "[$SchemaName].[$TableName]"
        $bulkCopy.BatchSize = $script:BULK_COPY_BATCH_SIZE
        $bulkCopy.BulkCopyTimeout = $script:BULK_COPY_TIMEOUT_SECONDS

        Write-Debug "Setting up column mappings for $($DataTable.Columns.Count) columns"

        # Map each column from DataTable to SQL table
        foreach ($column in $DataTable.Columns) {
            $columnName = $column.ColumnName
            Write-Debug "Mapping column: $columnName (Type: $($column.DataType.Name))"
            $bulkCopy.ColumnMappings.Add($columnName, $columnName) | Out-Null
        }

        Write-Host "Starting bulk copy operation..." -ForegroundColor Yellow
        $bulkCopy.WriteToServer($DataTable)

        $bulkCopy.Close()
        $connection.Close()

        $rowCount = $DataTable.Rows.Count
        Write-Host "Successfully imported $rowCount rows into [$SchemaName].[$TableName]" -ForegroundColor Green
        Write-Verbose "Successfully imported $rowCount rows into [$SchemaName].[$TableName]"

        return $rowCount
    }
    catch {
        Write-Error "Bulk copy failed: $($_.Exception.Message)"
        Write-Host "`nBulk Copy Error Details:" -ForegroundColor Red
        Write-Host "Table: [$SchemaName].[$TableName]" -ForegroundColor Red
        Write-Host "DataTable Columns: $($DataTable.Columns.Count)" -ForegroundColor Red
        Write-Host "Column Names: $($DataTable.Columns.ColumnName -join ', ')" -ForegroundColor Red
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
        if ($DataTable) {
            $DataTable.Dispose()
        }
    }
}

function Import-DataFile {
    <#
    .SYNOPSIS
    Imports data from DAT file into SQL Server table.

    .DESCRIPTION
    Orchestrates the import process: reads file, creates DataTable,
    populates rows with type conversion, and performs bulk copy.
    This function follows Single Responsibility Principle by delegating
    to specialized functions.

    .PARAMETER ConnectionString
    SQL Server connection string.

    .PARAMETER SchemaName
    Schema name.

    .PARAMETER TableName
    Table name.

    .PARAMETER FilePath
    Path to DAT file.

    .PARAMETER Fields
    Field specifications from Excel.

    .EXAMPLE
    $count = Import-DataFile -ConnectionString $conn -SchemaName "dbo" -TableName "Employee" -FilePath "C:\Data\Employee.dat" -Fields $fields
    #>
    [CmdletBinding(SupportsShouldProcess=$true)]
    [OutputType([int])]
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
        [ValidateScript({ Test-Path $_ -PathType Leaf })]
        [string]$FilePath,

        [Parameter(Mandatory=$true)]
        [array]$Fields
    )

    $fileName = [System.IO.Path]::GetFileName($FilePath)
    Write-Verbose "Starting data import for table [$SchemaName].[$TableName] from file: $fileName"
    Write-Host "Importing $fileName..." -ForegroundColor Yellow

    # Expected field count = ImportID + spec fields
    $expectedFieldCount = $Fields.Count + 1

    # Step 1: Read file with multi-line support
    $records = Read-DatFileLines -FilePath $FilePath -ExpectedFieldCount $expectedFieldCount

    if ($records.Count -eq 0) {
        Write-Warning "No records to import from $fileName"
        return 0
    }

    # Step 2: Create DataTable structure
    $dataTable = New-ImportDataTable -Fields $Fields

    # Step 3: Populate DataTable with type conversion
    Add-DataTableRows -DataTable $dataTable -Records $records -Fields $Fields

    # Step 4: Perform bulk copy (or skip if WhatIf)
    if ($PSCmdlet.ShouldProcess("[$SchemaName].[$TableName]", "Import $($records.Count) rows from $fileName")) {
        $rowCount = Invoke-SqlBulkCopy -DataTable $dataTable -ConnectionString $ConnectionString -SchemaName $SchemaName -TableName $TableName
        return $rowCount
    }
    else {
        # WhatIf mode
        Write-Host "What if: Would import $($records.Count) rows from $fileName into [$SchemaName].[$TableName]" -ForegroundColor Cyan
        Write-Host "  File parsed successfully: $($records.Count) rows would be imported" -ForegroundColor Gray
        return $records.Count
    }
}

#endregion

#region Summary Functions

function Add-ImportSummary {
    <#
    .SYNOPSIS
    Adds table to import summary.

    .PARAMETER TableName
    Table name.

    .PARAMETER RowCount
    Number of rows imported.

    .PARAMETER FileName
    Source file name.

    .EXAMPLE
    Add-ImportSummary -TableName "Employee" -RowCount 1000 -FileName "Employee.dat"
    #>
    [CmdletBinding()]
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
    <#
    .SYNOPSIS
    Displays import summary.

    .PARAMETER SchemaName
    Schema name for display.

    .EXAMPLE
    Show-ImportSummary -SchemaName "dbo"
    #>
    [CmdletBinding()]
    param(
        [Parameter(Mandatory=$true)]
        [string]$SchemaName
    )

    Write-Debug "Generating import summary"
    Write-Host "`n=== Import Summary ===" -ForegroundColor Cyan

    if ($script:ImportSummary.Count -eq 0) {
        Write-Host "No tables were imported." -ForegroundColor Yellow
        Write-Warning "No tables were imported"
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
    Write-Debug "Import summary completed - $($script:ImportSummary.Count) tables, $totalRows total rows"
}

function Clear-ImportSummary {
    <#
    .SYNOPSIS
    Clears import summary.

    .EXAMPLE
    Clear-ImportSummary
    #>
    [CmdletBinding()]
    param()

    $script:ImportSummary = @()
}

#endregion

#region Post-Install Script Functions

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

            # Show preview
            $preview = $sql.Substring(0, [Math]::Min($script:PREVIEW_TEXT_LENGTH, $sql.Length))
            Write-Host "  Preview: $preview..." -ForegroundColor Gray

            # Execute the SQL script
            Invoke-Sqlcmd -ConnectionString $ConnectionString -Query $sql -QueryTimeout $script:SQL_COMMAND_TIMEOUT_SECONDS

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

#endregion

#region Main Import Function

function Invoke-SqlServerDataImport {
    <#
    .SYNOPSIS
    Main orchestrator for SQL Server data import process.

    .DESCRIPTION
    Coordinates the entire import workflow: validation, prefix detection,
    database connection, schema creation, table processing, and optional
    post-install script execution.

    .PARAMETER DataFolder
    Folder containing DAT files and Excel specification.

    .PARAMETER ExcelSpecFile
    Excel specification file name.

    .PARAMETER ConnectionString
    SQL Server connection string.

    .PARAMETER SchemaName
    Schema name (optional - defaults to detected prefix).

    .PARAMETER TableExistsAction
    Action when table exists: Ask, Skip, Truncate, Recreate.

    .PARAMETER PostInstallScripts
    Optional path to post-install SQL scripts.

    .EXAMPLE
    Invoke-SqlServerDataImport -DataFolder "C:\Data" -ExcelSpecFile "ExportSpec.xlsx" -ConnectionString $conn -SchemaName "dbo"
    #>
    [CmdletBinding(SupportsShouldProcess=$true)]
    [OutputType([array])]
    param(
        [Parameter(Mandatory=$true)]
        [ValidateScript({ Test-Path $_ -PathType Container })]
        [string]$DataFolder,

        [Parameter(Mandatory=$true)]
        [ValidateNotNullOrEmpty()]
        [string]$ExcelSpecFile,

        [Parameter(Mandatory=$true)]
        [ValidateNotNullOrEmpty()]
        [string]$ConnectionString,

        [string]$SchemaName,

        [ValidateSet("Ask", "Skip", "Truncate", "Recreate")]
        [string]$TableExistsAction = "Ask",

        [string]$PostInstallScripts
    )

    # Set verbose logging flag
    $script:VerboseLogging = ($PSCmdlet.MyInvocation.BoundParameters['Verbose'] -eq $true) -or ($VerbosePreference -eq 'Continue')

    # Clear previous summary
    Clear-ImportSummary

    try {
        Write-ImportLog "Starting SQL Server data import process" -Level "INFO"

        # Validate Excel specification file
        $excelPath = Join-Path $DataFolder $ExcelSpecFile
        Test-ImportPath -Path $excelPath -PathType File -ThrowOnError

        # Find prefix and validate connection
        $prefix = Get-DataPrefix -FolderPath $DataFolder

        if (-not (Test-DatabaseConnection -ConnectionString $ConnectionString)) {
            throw "Database connection test failed"
        }

        # Determine schema name
        if (-not $SchemaName) {
            $SchemaName = $prefix
        }

        # Validate schema name
        Test-SchemaName -SchemaName $SchemaName -ThrowOnError

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
                Write-Warning "No field specifications found for table '$tableName' - skipping"
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

            # Import data
            $rowsImported = Import-DataFile -ConnectionString $ConnectionString -SchemaName $SchemaName -TableName $tableName -FilePath $datFile.FullName -Fields $tableFields

            Add-ImportSummary -TableName $tableName -RowCount $rowsImported -FileName $datFile.Name
        }

        # Display summary
        Show-ImportSummary -SchemaName $SchemaName

        Write-ImportLog "Import process completed successfully" -Level "SUCCESS"

        # Execute post-install scripts if specified
        if (-not [string]::IsNullOrWhiteSpace($PostInstallScripts)) {
            Write-Host "`n=== Post-Install Scripts ===" -ForegroundColor Cyan
            Write-Verbose "Post-install scripts path: $PostInstallScripts"

            # Extract database name from connection string
            $databaseName = Get-DatabaseNameFromConnectionString -ConnectionString $ConnectionString

            if ([string]::IsNullOrWhiteSpace($databaseName)) {
                Write-Warning "Could not extract database name from connection string for placeholder replacement"
            }

            try {
                Invoke-PostInstallScripts -ScriptPath $PostInstallScripts -ConnectionString $ConnectionString -DatabaseName $databaseName -SchemaName $SchemaName
                Write-ImportLog "Post-install scripts completed successfully" -Level "SUCCESS"
            }
            catch {
                Write-Error "Post-install scripts failed: $($_.Exception.Message)"
                Write-Host "`nWARNING: Post-install scripts failed but data import was successful" -ForegroundColor Yellow
                Write-Host "Error: $($_.Exception.Message)" -ForegroundColor Red
                # Don't throw - import was successful even if post-install failed
            }
        }

        return $script:ImportSummary
    }
    catch {
        Write-Error "Import process failed: $($_.Exception.Message)"
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
