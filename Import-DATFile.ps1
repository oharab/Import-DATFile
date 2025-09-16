# SQL Server Data Import Script
# Imports pipe-separated .dat files into SQL Server based on Excel specification

param(
    [string]$DataFolder,
    [string]$ExcelSpecFile,
    [switch]$Verbose
)

# Import required modules
try {
    Import-Module SqlServer -ErrorAction Stop
}
catch {
    Write-Error "SqlServer module not found. Please install it using: Install-Module -Name SqlServer"
    exit 1
}

try {
    Import-Module ImportExcel -ErrorAction Stop
}
catch {
    Write-Error "ImportExcel module not found. Please install it using: Install-Module -Name ImportExcel"
    exit 1
}

# Logging functions
function Write-Log {
    param(
        [string]$Message,
        [string]$Level = "INFO",
        [switch]$VerboseOnly
    )

    $timestamp = Get-Date -Format "yyyy-MM-dd HH:mm:ss"
    $logMessage = "[$timestamp] [$Level] $Message"

    if ($VerboseOnly -and -not $Verbose) {
        return
    }

    switch ($Level.ToUpper()) {
        "ERROR" { Write-Host $logMessage -ForegroundColor Red }
        "WARNING" { Write-Host $logMessage -ForegroundColor Yellow }
        "SUCCESS" { Write-Host $logMessage -ForegroundColor Green }
        "INFO" { Write-Host $logMessage -ForegroundColor White }
        "VERBOSE" {
            if ($Verbose) {
                Write-Host $logMessage -ForegroundColor Gray
            }
        }
        default { Write-Host $logMessage -ForegroundColor White }
    }
}

function Write-LogVerbose {
    param([string]$Message)
    Write-Log -Message $Message -Level "VERBOSE" -VerboseOnly
}

function Get-DataFolderAndSpec {
    Write-Log "Starting data folder and specification file configuration" -Level "INFO"
    Write-Host "`n=== Data Folder and Specification File Configuration ===" -ForegroundColor Cyan

    # Prompt for DataFolder
    $defaultDataFolder = Get-Location
    Write-LogVerbose "Default data folder determined: $defaultDataFolder"
    Write-Host "Default data folder: '$defaultDataFolder'"
    $dataFolderInput = Read-Host "Press Enter to use default, or enter a different data folder path"

    if ([string]::IsNullOrWhiteSpace($dataFolderInput)) {
        $dataFolder = $defaultDataFolder
        Write-LogVerbose "Using default data folder"
    }
    else {
        $dataFolder = $dataFolderInput.Trim()
        Write-LogVerbose "User specified data folder: $dataFolder"
    }

    # Prompt for ExcelSpecFile
    $defaultExcelFile = "ExportSpec.xlsx"
    Write-LogVerbose "Default Excel file: $defaultExcelFile"
    Write-Host "`nDefault Excel specification file: '$defaultExcelFile'"
    $excelFileInput = Read-Host "Press Enter to use default, or enter a different Excel file name"

    if ([string]::IsNullOrWhiteSpace($excelFileInput)) {
        $excelFile = $defaultExcelFile
        Write-LogVerbose "Using default Excel specification file"
    }
    else {
        $excelFile = $excelFileInput.Trim()
        Write-LogVerbose "User specified Excel file: $excelFile"
    }

    Write-Host "`nSelected configuration:" -ForegroundColor Green
    Write-Host "  Data Folder: $dataFolder"
    Write-Host "  Excel File: $excelFile"
    Write-Log "Configuration completed - DataFolder: $dataFolder, ExcelFile: $excelFile" -Level "SUCCESS"

    return @{
        DataFolder = $dataFolder
        ExcelSpecFile = $excelFile
    }
}

function Get-DatabaseConnection {
    Write-Log "Starting database connection configuration" -Level "INFO"
    Write-Host "`n=== Database Connection Configuration ===" -ForegroundColor Cyan

    $server = Read-Host "Enter SQL Server instance (e.g., localhost, server\instance)"
    Write-LogVerbose "SQL Server instance specified: $server"
    $database = Read-Host "Enter database name"
    Write-LogVerbose "Database name specified: $database"

    Write-Host "`nAuthentication Methods:"
    Write-Host "1. Windows Authentication"
    Write-Host "2. SQL Server Authentication"
    $authChoice = Read-Host "Select authentication method (1 or 2)"
    Write-LogVerbose "Authentication method selected: $authChoice"

    if ($authChoice -eq "2") {
        $username = Read-Host "Enter username"
        Write-LogVerbose "SQL Server username specified: $username"
        $password = Read-Host "Enter password" -AsSecureString
        Write-LogVerbose "SQL Server password provided (secured)"
        $credential = New-Object System.Management.Automation.PSCredential($username, $password)
        $connectionString = "Server=$server;Database=$database;User Id=$username;Password=$([Runtime.InteropServices.Marshal]::PtrToStringAuto([Runtime.InteropServices.Marshal]::SecureStringToBSTR($password)));"
    }
    else {
        Write-LogVerbose "Using Windows Authentication"
        $connectionString = "Server=$server;Database=$database;Integrated Security=True;"
    }

    # Test connection
    Write-LogVerbose "Testing database connection..."
    try {
        $connection = New-Object System.Data.SqlClient.SqlConnection($connectionString)
        $connection.Open()
        $connection.Close()
        Write-Host "Connection successful!" -ForegroundColor Green
        Write-Log "Database connection test successful" -Level "SUCCESS"
        return $connectionString
    }
    catch {
        Write-Log "Database connection failed: $($_.Exception.Message)" -Level "ERROR"
        Write-Error "Failed to connect to database: $($_.Exception.Message)"
        exit 1
    }
}

function Get-DataTypeMapping {
    param([string]$ExcelType, [string]$Precision)
    
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
            Write-Warning "Unknown data type: $ExcelType. Defaulting to NVARCHAR(255)"
            return "NVARCHAR(255)"
        }
    }
}

function Find-DataPrefix {
    param([string]$FolderPath)

    Write-Log "Starting prefix detection in folder: $FolderPath" -Level "INFO"
    Write-Host "`nLooking for Employee.dat file to determine prefix..." -ForegroundColor Yellow

    Write-LogVerbose "Searching for *Employee.dat files in: $FolderPath"
    $employeeFiles = Get-ChildItem -Path $FolderPath -Name "*Employee.dat"
    Write-LogVerbose "Found $($employeeFiles.Count) Employee.dat file(s)"

    if ($employeeFiles.Count -eq 0) {
        Write-Log "No *Employee.dat file found in $FolderPath" -Level "ERROR"
        Write-Error "No *Employee.dat file found. Cannot determine prefix. Exiting."
        exit 1
    }

    if ($employeeFiles.Count -gt 1) {
        Write-Log "Multiple Employee.dat files found, cannot determine unique prefix" -Level "ERROR"
        Write-Warning "Multiple Employee.dat files found:"
        $employeeFiles | ForEach-Object {
            Write-Host "  $_"
            Write-LogVerbose "Found file: $_"
        }
        Write-Error "Cannot uniquely determine prefix. Exiting."
        exit 1
    }

    $employeeFile = $employeeFiles[0]
    $prefix = $employeeFile -replace "Employee\.dat$", ""

    Write-Host "Found: $employeeFile" -ForegroundColor Green
    Write-Host "Detected prefix: '$prefix'" -ForegroundColor Green
    Write-Log "Prefix detection successful - File: $employeeFile, Prefix: '$prefix'" -Level "SUCCESS"

    return $prefix
}

function Get-TableSpecifications {
    param([string]$ExcelPath)

    Write-Log "Starting to read table specifications from Excel: $ExcelPath" -Level "INFO"
    Write-Host "`nReading table specifications from Excel..." -ForegroundColor Yellow

    if (-not (Test-Path $ExcelPath)) {
        Write-Log "Excel specification file not found: $ExcelPath" -Level "ERROR"
        Write-Error "Excel specification file not found: $ExcelPath"
        exit 1
    }

    Write-LogVerbose "Excel file exists, attempting to read specifications"
    try {
        $specs = Import-Excel -Path $ExcelPath
        Write-Host "Successfully read $($specs.Count) field specifications" -ForegroundColor Green
        Write-Log "Successfully read $($specs.Count) field specifications from Excel" -Level "SUCCESS"
        Write-LogVerbose "Specifications loaded for tables: $(($specs | Select-Object -Unique 'Table name').'Table name' -join ', ')"
        return $specs
    }
    catch {
        Write-Log "Failed to read Excel file: $($_.Exception.Message)" -Level "ERROR"
        Write-Error "Failed to read Excel file: $($_.Exception.Message)"
        exit 1
    }
}

function Get-SchemaName {
    param([string]$DefaultSchema)

    Write-Log "Starting schema configuration with default: $DefaultSchema" -Level "INFO"
    Write-Host "`n=== Schema Configuration ===" -ForegroundColor Cyan
    Write-Host "Default schema name: '$DefaultSchema'"
    $response = Read-Host "Press Enter to use default, or enter a different schema name"

    if ([string]::IsNullOrWhiteSpace($response)) {
        Write-LogVerbose "Using default schema name: $DefaultSchema"
        return $DefaultSchema
    }
    else {
        $schemaName = $response.Trim()
        Write-LogVerbose "User specified schema name: $schemaName"
        Write-Log "Schema configuration completed: $schemaName" -Level "SUCCESS"
        return $schemaName
    }
}

function Test-TableExists {
    param([string]$ConnectionString, [string]$SchemaName, [string]$TableName)

    Write-LogVerbose "Checking if table [$SchemaName].[$TableName] exists"
    $query = @"
SELECT COUNT(*)
FROM INFORMATION_SCHEMA.TABLES
WHERE TABLE_SCHEMA = '$SchemaName' AND TABLE_NAME = '$TableName'
"@

    try {
        $result = Invoke-Sqlcmd -ConnectionString $ConnectionString -Query $query -ErrorAction Stop
        $exists = $result.Column1 -gt 0
        Write-LogVerbose "Table [$SchemaName].[$TableName] exists: $exists"
        return $exists
    }
    catch {
        Write-LogVerbose "Error checking table existence: $($_.Exception.Message)"
        return $false
    }
}

function Create-Schema {
    param([string]$ConnectionString, [string]$SchemaName)

    Write-Log "Creating/verifying schema: $SchemaName" -Level "INFO"
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

    Write-LogVerbose "Executing schema creation query for: $SchemaName"
    try {
        Invoke-Sqlcmd -ConnectionString $ConnectionString -Query $query -ErrorAction Stop
        Write-Host "Schema '$SchemaName' is ready" -ForegroundColor Green
        Write-Log "Schema '$SchemaName' is ready" -Level "SUCCESS"
    }
    catch {
        Write-Log "Failed to create schema '$SchemaName': $($_.Exception.Message)" -Level "ERROR"
        Write-Error "Failed to create schema: $($_.Exception.Message)"
        throw
    }
}

function Get-TableAction {
    param([string]$TableName)
    
    Write-Host "`nTable '$TableName' already exists. Choose action:" -ForegroundColor Yellow
    Write-Host "1. Cancel entire script"
    Write-Host "2. Skip this table"
    Write-Host "3. Truncate (clear existing data)"
    Write-Host "4. Recreate (drop and recreate table)"
    
    do {
        $choice = Read-Host "Enter choice (1, 2, 3, or 4)"
    } while ($choice -notin @("1", "2", "3", "4"))
    
    switch ($choice) {
        "1" { return "CancelScript" }
        "2" { return "SkipTable" }
        "3" { return "Truncate" }
        "4" { return "Recreate" }
    }
}

function Create-Table {
    param(
        [string]$ConnectionString,
        [string]$SchemaName,
        [string]$TableName,
        [array]$Fields
    )

    Write-Log "Creating table [$SchemaName].[$TableName] with $($Fields.Count) fields" -Level "INFO"
    $fieldDefinitions = @()

    foreach ($field in $Fields) {
        $sqlType = Get-DataTypeMapping -ExcelType $field."Field type" -Precision $field.Precision
        $fieldDef = "    [$($field.'Field name')] $sqlType"
        $fieldDefinitions += $fieldDef
        Write-LogVerbose "Field definition: $fieldDef"
    }

    $createTableQuery = @"
CREATE TABLE [$SchemaName].[$TableName] (
$($fieldDefinitions -join ",`n")
)
"@

    Write-LogVerbose "Executing table creation query for [$SchemaName].[$TableName]"
    try {
        Invoke-Sqlcmd -ConnectionString $ConnectionString -Query $createTableQuery -ErrorAction Stop
        Write-Host "Table [$SchemaName].[$TableName] created successfully" -ForegroundColor Green
        Write-Log "Table [$SchemaName].[$TableName] created successfully" -Level "SUCCESS"
    }
    catch {
        Write-Log "Failed to create table [$SchemaName].[$TableName]: $($_.Exception.Message)" -Level "ERROR"
        Write-Error "Failed to create table [$SchemaName].[$TableName]: $($_.Exception.Message)"
        throw
    }
}

function Get-FieldMismatchAction {
    param([string]$TableName, [int]$FileFieldCount, [int]$SpecFieldCount)

    Write-Log "Field count mismatch detected for table '$TableName' - File: $FileFieldCount, Spec: $SpecFieldCount" -Level "WARNING"

    if ($global:AlwaysSkipFirstField) {
        Write-Host "Automatically skipping first field (Always mode)" -ForegroundColor Yellow
        Write-LogVerbose "Using Always mode - automatically skipping first field"
        return "Skip"
    }

    Write-Host "`nField count mismatch detected for table '$TableName':" -ForegroundColor Yellow
    Write-Host "  Data file has $FileFieldCount fields"
    Write-Host "  Specification has $SpecFieldCount fields"
    Write-Host "  This usually means the data file has an extra first field with the import name."
    Write-Host "`nChoose action:"
    Write-Host "1. Yes - Skip first field for this table only"
    Write-Host "2. No - Exit the import"
    Write-Host "3. Always - Skip first field for all remaining tables"

    do {
        $choice = Read-Host "Enter choice (1, 2, or 3)"
        Write-LogVerbose "User choice for field mismatch: $choice"
    } while ($choice -notin @("1", "2", "3"))

    switch ($choice) {
        "1" {
            Write-Log "User chose to skip first field for table '$TableName' only" -Level "INFO"
            return "Skip"
        }
        "2" {
            Write-Log "User chose to exit the import" -Level "INFO"
            return "Exit"
        }
        "3" {
            $global:AlwaysSkipFirstField = $true
            Write-Log "User chose to always skip first field for all remaining tables" -Level "INFO"
            return "Skip"
        }
    }
}

function Import-DataFile {
    param(
        [string]$ConnectionString,
        [string]$SchemaName,
        [string]$TableName,
        [string]$FilePath,
        [array]$Fields
    )

    $fileName = [System.IO.Path]::GetFileName($FilePath)
    Write-Log "Starting data import for table [$SchemaName].[$TableName] from file: $fileName" -Level "INFO"
    Write-Host "Importing data from $fileName..." -ForegroundColor Yellow
    
    # Read the file and parse pipe-separated data
    Write-LogVerbose "Reading data file: $FilePath"
    $lines = Get-Content -Path $FilePath
    Write-LogVerbose "Read $($lines.Count) lines from data file"

    if ($lines.Count -eq 0) {
        Write-Log "Data file is empty: $FilePath" -Level "WARNING"
        Write-Warning "File is empty: $FilePath"
        return
    }

    # Check field count mismatch and determine if we should skip first field
    $skipFirstField = $false
    if ($lines.Count -gt 0) {
        $firstLineFields = ($lines[0] -split '\|').Count
        $specFieldCount = $Fields.Count
        Write-LogVerbose "Field count analysis - Data file: $firstLineFields, Specification: $specFieldCount"

        if ($firstLineFields -eq ($specFieldCount + 1)) {
            Write-LogVerbose "Detected standard field mismatch pattern (data has one extra field)"
            $action = Get-FieldMismatchAction -TableName $TableName -FileFieldCount $firstLineFields -SpecFieldCount $specFieldCount
            if ($action -eq "Exit") {
                Write-Log "Import cancelled by user due to field mismatch" -Level "INFO"
                Write-Host "Import cancelled by user." -ForegroundColor Red
                exit 0
            }
            elseif ($action -eq "Skip") {
                $skipFirstField = $true
                Write-Host "Will skip first field in data file" -ForegroundColor Green
                Write-Log "Will skip first field during data import" -Level "INFO"
            }
        }
        elseif ($firstLineFields -ne $specFieldCount) {
            Write-Log "Unexpected field count mismatch - Data: $firstLineFields, Spec: $specFieldCount" -Level "WARNING"
            Write-Warning "Field count mismatch: Data file has $firstLineFields fields, specification has $specFieldCount fields. Proceeding without field adjustment."
        }
        else {
            Write-LogVerbose "Field counts match perfectly"
        }
    }

    $fieldNames = $Fields.'Field name' -join "], ["
    $insertQuery = "INSERT INTO [$SchemaName].[$TableName] ([$fieldNames]) VALUES "

    $batchSize = 1000
    $valueRows = @()
    $rowCount = 0
    Write-LogVerbose "Starting data processing with batch size: $batchSize"

    foreach ($line in $lines) {
        if ([string]::IsNullOrWhiteSpace($line)) { continue }

        $values = $line -split '\|'
        Write-LogVerbose "Processing line with $($values.Length) fields"

        # Skip first field if determined necessary
        if ($skipFirstField -and $values.Length -gt 0) {
            $originalCount = $values.Length
            $values = $values[1..($values.Length - 1)]
            Write-LogVerbose "Skipped first field - Original: $originalCount, After skip: $($values.Length)"
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
            Write-LogVerbose "Executing batch insert with $($valueRows.Count) rows"
            try {
                Invoke-Sqlcmd -ConnectionString $ConnectionString -Query $batchQuery -ErrorAction Stop
                Write-Host "  Inserted $($valueRows.Count) rows (Total: $rowCount)" -ForegroundColor Gray
                Write-LogVerbose "Batch insert successful - $($valueRows.Count) rows inserted"
            }
            catch {
                Write-Log "Failed to insert batch: $($_.Exception.Message)" -Level "ERROR"
                Write-Error "Failed to insert batch: $($_.Exception.Message)"
                throw
            }
            $valueRows = @()
        }
    }
    
    # Insert remaining rows
    if ($valueRows.Count -gt 0) {
        $batchQuery = $insertQuery + ($valueRows -join ', ')
        Write-LogVerbose "Executing final batch insert with $($valueRows.Count) rows"
        try {
            Invoke-Sqlcmd -ConnectionString $ConnectionString -Query $batchQuery -ErrorAction Stop
            Write-Host "  Inserted final $($valueRows.Count) rows (Total: $rowCount)" -ForegroundColor Gray
            Write-LogVerbose "Final batch insert successful - $($valueRows.Count) rows inserted"
        }
        catch {
            Write-Log "Failed to insert final batch: $($_.Exception.Message)" -Level "ERROR"
            Write-Error "Failed to insert final batch: $($_.Exception.Message)"
            throw
        }
    }

    Write-Host "Successfully imported $rowCount rows into [$SchemaName].[$TableName]" -ForegroundColor Green
    Write-Log "Data import completed successfully - $rowCount rows imported into [$SchemaName].[$TableName]" -Level "SUCCESS"
}

# Global variable to track field skipping behavior
$global:AlwaysSkipFirstField = $false

# Main script execution
Write-Host "=== SQL Server Data Import Script ===" -ForegroundColor Cyan

# Get DataFolder and ExcelSpecFile if not provided as parameters
if ([string]::IsNullOrWhiteSpace($DataFolder) -or [string]::IsNullOrWhiteSpace($ExcelSpecFile)) {
    $config = Get-DataFolderAndSpec
    if ([string]::IsNullOrWhiteSpace($DataFolder)) {
        $DataFolder = $config.DataFolder
    }
    if ([string]::IsNullOrWhiteSpace($ExcelSpecFile)) {
        $ExcelSpecFile = $config.ExcelSpecFile
    }
}

Write-Host "`nUsing configuration:" -ForegroundColor Green
Write-Host "Data Folder: $DataFolder"
Write-Host "Excel Spec File: $ExcelSpecFile"

# Validate paths
if (-not (Test-Path $DataFolder)) {
    Write-Error "Data folder not found: $DataFolder"
    exit 1
}

$excelPath = Join-Path $DataFolder $ExcelSpecFile
if (-not (Test-Path $excelPath)) {
    Write-Error "Excel specification file not found: $excelPath"
    exit 1
}

# Find prefix and get database connection
$prefix = Find-DataPrefix -FolderPath $DataFolder
$connectionString = Get-DatabaseConnection

# Get schema name
$schemaName = Get-SchemaName -DefaultSchema $prefix

# Create schema if needed
Create-Schema -ConnectionString $connectionString -SchemaName $schemaName

# Read table specifications
$tableSpecs = Get-TableSpecifications -ExcelPath $excelPath

# Get all .dat files
Write-Log "Searching for .dat files with prefix '$prefix'" -Level "INFO"
$datFiles = Get-ChildItem -Path $DataFolder -Filter "*.dat" | Where-Object { $_.Name -like "$prefix*" }
Write-LogVerbose "Found $($datFiles.Count) .dat files matching prefix '$prefix'"

if ($datFiles.Count -eq 0) {
    Write-Log "No .dat files found with prefix '$prefix'" -Level "ERROR"
    Write-Error "No .dat files found with prefix '$prefix'"
    exit 1
}

Write-Host "`nFound $($datFiles.Count) data files to process:" -ForegroundColor Green
$datFiles | ForEach-Object {
    Write-Host "  $($_.Name)"
    Write-LogVerbose "Will process file: $($_.Name) (Size: $($_.Length) bytes)"
}
Write-Log "Data file discovery completed - $($datFiles.Count) files found" -Level "SUCCESS"

# Process each data file
Write-Log "Starting processing of $($datFiles.Count) data files" -Level "INFO"
foreach ($datFile in $datFiles) {
    $tableName = $datFile.Name -replace "^$prefix", "" -replace "\.dat$", ""
    Write-Log "Processing table: $tableName (from file: $($datFile.Name))" -Level "INFO"
    Write-Host "`n=== Processing Table: $tableName ===" -ForegroundColor Cyan

    # Get field specifications for this table
    Write-LogVerbose "Looking for field specifications for table: $tableName"
    $tableFields = $tableSpecs | Where-Object { $_."Table name" -eq $tableName }
    Write-LogVerbose "Found $($tableFields.Count) field specifications for table '$tableName'"

    if ($tableFields.Count -eq 0) {
        Write-Log "No field specifications found for table '$tableName' - skipping" -Level "WARNING"
        Write-Warning "No field specifications found for table '$tableName'. Skipping."
        continue
    }

    Write-Host "Found $($tableFields.Count) field specifications for table '$tableName'"
    
    # Check if table exists
    $tableExists = Test-TableExists -ConnectionString $connectionString -SchemaName $schemaName -TableName $tableName

    if ($tableExists) {
        Write-Log "Table [$schemaName].[$tableName] already exists - prompting for action" -Level "INFO"
        $action = Get-TableAction -TableName $tableName

        switch ($action) {
            "CancelScript" {
                Write-Log "Script cancelled by user during table conflict resolution" -Level "INFO"
                Write-Host "Script cancelled by user." -ForegroundColor Red
                exit 0
            }
            "SkipTable" {
                Write-Log "Skipping table '$tableName' as requested by user" -Level "INFO"
                Write-Host "Skipping table '$tableName'" -ForegroundColor Yellow
                continue
            }
            "Truncate" {
                Write-Log "Truncating existing table [$schemaName].[$tableName]" -Level "INFO"
                $truncateQuery = "TRUNCATE TABLE [$schemaName].[$tableName]"
                try {
                    Invoke-Sqlcmd -ConnectionString $connectionString -Query $truncateQuery -ErrorAction Stop
                    Write-Host "Table truncated successfully" -ForegroundColor Green
                    Write-Log "Table [$schemaName].[$tableName] truncated successfully" -Level "SUCCESS"
                }
                catch {
                    Write-Log "Failed to truncate table [$schemaName].[$tableName]: $($_.Exception.Message)" -Level "ERROR"
                    Write-Error "Failed to truncate table: $($_.Exception.Message)"
                    continue
                }
            }
            "Recreate" {
                Write-Log "Recreating table [$schemaName].[$tableName]" -Level "INFO"
                $dropQuery = "DROP TABLE [$schemaName].[$tableName]"
                try {
                    Invoke-Sqlcmd -ConnectionString $connectionString -Query $dropQuery -ErrorAction Stop
                    Write-Host "Table dropped successfully" -ForegroundColor Green
                    Write-LogVerbose "Table [$schemaName].[$tableName] dropped successfully"
                    Create-Table -ConnectionString $connectionString -SchemaName $schemaName -TableName $tableName -Fields $tableFields
                }
                catch {
                    Write-Log "Failed to recreate table [$schemaName].[$tableName]: $($_.Exception.Message)" -Level "ERROR"
                    Write-Error "Failed to recreate table: $($_.Exception.Message)"
                    continue
                }
            }
        }
    }
    else {
        # Create new table
        Write-LogVerbose "Table [$schemaName].[$tableName] does not exist - creating new table"
        Create-Table -ConnectionString $connectionString -SchemaName $schemaName -TableName $tableName -Fields $tableFields
    }
    
    # Import data
    try {
        Import-DataFile -ConnectionString $connectionString -SchemaName $schemaName -TableName $tableName -FilePath $datFile.FullName -Fields $tableFields
    }
    catch {
        Write-Log "Failed to import data for table '$tableName': $($_.Exception.Message)" -Level "ERROR"
        Write-Error "Failed to import data for table '$tableName': $($_.Exception.Message)"
        continue
    }
}

Write-Log "Import process completed successfully" -Level "SUCCESS"
Write-Host "`n=== Import Process Completed ===" -ForegroundColor Green