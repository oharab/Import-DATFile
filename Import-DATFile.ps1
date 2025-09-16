# SQL Server Data Import Script
# Imports pipe-separated .dat files into SQL Server based on Excel specification

param(
    [string]$DataFolder,
    [string]$ExcelSpecFile
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

function Get-DataFolderAndSpec {
    Write-Host "`n=== Data Folder and Specification File Configuration ===" -ForegroundColor Cyan

    # Prompt for DataFolder
    $defaultDataFolder = Get-Location
    Write-Host "Default data folder: '$defaultDataFolder'"
    $dataFolderInput = Read-Host "Press Enter to use default, or enter a different data folder path"

    if ([string]::IsNullOrWhiteSpace($dataFolderInput)) {
        $dataFolder = $defaultDataFolder
    }
    else {
        $dataFolder = $dataFolderInput.Trim()
    }

    # Prompt for ExcelSpecFile
    $defaultExcelFile = "ExportSpec.xlsx"
    Write-Host "`nDefault Excel specification file: '$defaultExcelFile'"
    $excelFileInput = Read-Host "Press Enter to use default, or enter a different Excel file name"

    if ([string]::IsNullOrWhiteSpace($excelFileInput)) {
        $excelFile = $defaultExcelFile
    }
    else {
        $excelFile = $excelFileInput.Trim()
    }

    Write-Host "`nSelected configuration:" -ForegroundColor Green
    Write-Host "  Data Folder: $dataFolder"
    Write-Host "  Excel File: $excelFile"

    return @{
        DataFolder = $dataFolder
        ExcelSpecFile = $excelFile
    }
}

function Get-DatabaseConnection {
    Write-Host "`n=== Database Connection Configuration ===" -ForegroundColor Cyan
    
    $server = Read-Host "Enter SQL Server instance (e.g., localhost, server\instance)"
    $database = Read-Host "Enter database name"
    
    Write-Host "`nAuthentication Methods:"
    Write-Host "1. Windows Authentication"
    Write-Host "2. SQL Server Authentication"
    $authChoice = Read-Host "Select authentication method (1 or 2)"
    
    if ($authChoice -eq "2") {
        $username = Read-Host "Enter username"
        $password = Read-Host "Enter password" -AsSecureString
        $credential = New-Object System.Management.Automation.PSCredential($username, $password)
        $connectionString = "Server=$server;Database=$database;User Id=$username;Password=$([Runtime.InteropServices.Marshal]::PtrToStringAuto([Runtime.InteropServices.Marshal]::SecureStringToBSTR($password)));"
    }
    else {
        $connectionString = "Server=$server;Database=$database;Integrated Security=True;"
    }
    
    # Test connection
    try {
        $connection = New-Object System.Data.SqlClient.SqlConnection($connectionString)
        $connection.Open()
        $connection.Close()
        Write-Host "Connection successful!" -ForegroundColor Green
        return $connectionString
    }
    catch {
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
    
    Write-Host "`nLooking for Employee.dat file to determine prefix..." -ForegroundColor Yellow
    
    $employeeFiles = Get-ChildItem -Path $FolderPath -Name "*Employee.dat"
    
    if ($employeeFiles.Count -eq 0) {
        Write-Error "No *Employee.dat file found. Cannot determine prefix. Exiting."
        exit 1
    }
    
    if ($employeeFiles.Count -gt 1) {
        Write-Warning "Multiple Employee.dat files found:"
        $employeeFiles | ForEach-Object { Write-Host "  $_" }
        Write-Error "Cannot uniquely determine prefix. Exiting."
        exit 1
    }
    
    $employeeFile = $employeeFiles[0]
    $prefix = $employeeFile -replace "Employee\.dat$", ""
    
    Write-Host "Found: $employeeFile" -ForegroundColor Green
    Write-Host "Detected prefix: '$prefix'" -ForegroundColor Green
    
    return $prefix
}

function Get-TableSpecifications {
    param([string]$ExcelPath)
    
    Write-Host "`nReading table specifications from Excel..." -ForegroundColor Yellow
    
    if (-not (Test-Path $ExcelPath)) {
        Write-Error "Excel specification file not found: $ExcelPath"
        exit 1
    }
    
    try {
        $specs = Import-Excel -Path $ExcelPath
        Write-Host "Successfully read $($specs.Count) field specifications" -ForegroundColor Green
        return $specs
    }
    catch {
        Write-Error "Failed to read Excel file: $($_.Exception.Message)"
        exit 1
    }
}

function Get-SchemaName {
    param([string]$DefaultSchema)
    
    Write-Host "`n=== Schema Configuration ===" -ForegroundColor Cyan
    Write-Host "Default schema name: '$DefaultSchema'"
    $response = Read-Host "Press Enter to use default, or enter a different schema name"
    
    if ([string]::IsNullOrWhiteSpace($response)) {
        return $DefaultSchema
    }
    else {
        return $response.Trim()
    }
}

function Test-TableExists {
    param([string]$ConnectionString, [string]$SchemaName, [string]$TableName)
    
    $query = @"
SELECT COUNT(*) 
FROM INFORMATION_SCHEMA.TABLES 
WHERE TABLE_SCHEMA = '$SchemaName' AND TABLE_NAME = '$TableName'
"@
    
    try {
        $result = Invoke-Sqlcmd -ConnectionString $ConnectionString -Query $query -ErrorAction Stop
        return $result.Column1 -gt 0
    }
    catch {
        return $false
    }
}

function Create-Schema {
    param([string]$ConnectionString, [string]$SchemaName)
    
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
    
    try {
        Invoke-Sqlcmd -ConnectionString $ConnectionString -Query $query -ErrorAction Stop
        Write-Host "Schema '$SchemaName' is ready" -ForegroundColor Green
    }
    catch {
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
    
    $fieldDefinitions = @()
    
    foreach ($field in $Fields) {
        $sqlType = Get-DataTypeMapping -ExcelType $field."Field type" -Precision $field.Precision
        $fieldDefinitions += "    [$($field.'Field name')] $sqlType"
    }
    
    $createTableQuery = @"
CREATE TABLE [$SchemaName].[$TableName] (
$($fieldDefinitions -join ",`n")
)
"@
    
    try {
        Invoke-Sqlcmd -ConnectionString $ConnectionString -Query $createTableQuery -ErrorAction Stop
        Write-Host "Table [$SchemaName].[$TableName] created successfully" -ForegroundColor Green
    }
    catch {
        Write-Error "Failed to create table [$SchemaName].[$TableName]: $($_.Exception.Message)"
        throw
    }
}

function Get-FieldMismatchAction {
    param([string]$TableName, [int]$FileFieldCount, [int]$SpecFieldCount)

    if ($global:AlwaysSkipFirstField) {
        Write-Host "Automatically skipping first field (Always mode)" -ForegroundColor Yellow
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
    } while ($choice -notin @("1", "2", "3"))

    switch ($choice) {
        "1" { return "Skip" }
        "2" { return "Exit" }
        "3" {
            $global:AlwaysSkipFirstField = $true
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
    
    Write-Host "Importing data from $([System.IO.Path]::GetFileName($FilePath))..." -ForegroundColor Yellow
    
    # Read the file and parse pipe-separated data
    $lines = Get-Content -Path $FilePath

    if ($lines.Count -eq 0) {
        Write-Warning "File is empty: $FilePath"
        return
    }

    # Check field count mismatch and determine if we should skip first field
    $skipFirstField = $false
    if ($lines.Count -gt 0) {
        $firstLineFields = ($lines[0] -split '\|').Count
        $specFieldCount = $Fields.Count

        if ($firstLineFields -eq ($specFieldCount + 1)) {
            $action = Get-FieldMismatchAction -TableName $TableName -FileFieldCount $firstLineFields -SpecFieldCount $specFieldCount
            if ($action -eq "Exit") {
                Write-Host "Import cancelled by user." -ForegroundColor Red
                exit 0
            }
            elseif ($action -eq "Skip") {
                $skipFirstField = $true
                Write-Host "Will skip first field in data file" -ForegroundColor Green
            }
        }
        elseif ($firstLineFields -ne $specFieldCount) {
            Write-Warning "Field count mismatch: Data file has $firstLineFields fields, specification has $specFieldCount fields. Proceeding without field adjustment."
        }
    }

    $fieldNames = $Fields.'Field name' -join "], ["
    $insertQuery = "INSERT INTO [$SchemaName].[$TableName] ([$fieldNames]) VALUES "

    $batchSize = 1000
    $valueRows = @()
    $rowCount = 0

    foreach ($line in $lines) {
        if ([string]::IsNullOrWhiteSpace($line)) { continue }

        $values = $line -split '\|'

        # Skip first field if determined necessary
        if ($skipFirstField -and $values.Length -gt 0) {
            $values = $values[1..($values.Length - 1)]
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
            try {
                Invoke-Sqlcmd -ConnectionString $ConnectionString -Query $batchQuery -ErrorAction Stop
                Write-Host "  Inserted $($valueRows.Count) rows (Total: $rowCount)" -ForegroundColor Gray
            }
            catch {
                Write-Error "Failed to insert batch: $($_.Exception.Message)"
                throw
            }
            $valueRows = @()
        }
    }
    
    # Insert remaining rows
    if ($valueRows.Count -gt 0) {
        $batchQuery = $insertQuery + ($valueRows -join ', ')
        try {
            Invoke-Sqlcmd -ConnectionString $ConnectionString -Query $batchQuery -ErrorAction Stop
            Write-Host "  Inserted final $($valueRows.Count) rows (Total: $rowCount)" -ForegroundColor Gray
        }
        catch {
            Write-Error "Failed to insert final batch: $($_.Exception.Message)"
            throw
        }
    }
    
    Write-Host "Successfully imported $rowCount rows into [$SchemaName].[$TableName]" -ForegroundColor Green
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
$datFiles = Get-ChildItem -Path $DataFolder -Filter "*.dat" | Where-Object { $_.Name -like "$prefix*" }

if ($datFiles.Count -eq 0) {
    Write-Error "No .dat files found with prefix '$prefix'"
    exit 1
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
        Write-Warning "No field specifications found for table '$tableName'. Skipping."
        continue
    }
    
    Write-Host "Found $($tableFields.Count) field specifications for table '$tableName'"
    
    # Check if table exists
    $tableExists = Test-TableExists -ConnectionString $connectionString -SchemaName $schemaName -TableName $tableName
    
    if ($tableExists) {
        $action = Get-TableAction -TableName $tableName
        
        switch ($action) {
            "CancelScript" {
                Write-Host "Script cancelled by user." -ForegroundColor Red
                exit 0
            }
            "SkipTable" {
                Write-Host "Skipping table '$tableName'" -ForegroundColor Yellow
                continue
            }
            "Truncate" {
                $truncateQuery = "TRUNCATE TABLE [$schemaName].[$tableName]"
                try {
                    Invoke-Sqlcmd -ConnectionString $connectionString -Query $truncateQuery -ErrorAction Stop
                    Write-Host "Table truncated successfully" -ForegroundColor Green
                }
                catch {
                    Write-Error "Failed to truncate table: $($_.Exception.Message)"
                    continue
                }
            }
            "Recreate" {
                $dropQuery = "DROP TABLE [$schemaName].[$tableName]"
                try {
                    Invoke-Sqlcmd -ConnectionString $connectionString -Query $dropQuery -ErrorAction Stop
                    Write-Host "Table dropped successfully" -ForegroundColor Green
                    Create-Table -ConnectionString $connectionString -SchemaName $schemaName -TableName $tableName -Fields $tableFields
                }
                catch {
                    Write-Error "Failed to recreate table: $($_.Exception.Message)"
                    continue
                }
            }
        }
    }
    else {
        # Create new table
        Create-Table -ConnectionString $connectionString -SchemaName $schemaName -TableName $tableName -Fields $tableFields
    }
    
    # Import data
    try {
        Import-DataFile -ConnectionString $connectionString -SchemaName $schemaName -TableName $tableName -FilePath $datFile.FullName -Fields $tableFields
    }
    catch {
        Write-Error "Failed to import data for table '$tableName': $($_.Exception.Message)"
        continue
    }
}

Write-Host "`n=== Import Process Completed ===" -ForegroundColor Green