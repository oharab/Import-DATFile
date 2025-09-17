# SQL Server Data Import - Command Line Interface
# Interactive CLI that uses the SqlServerDataImport module

param(
    [string]$DataFolder,
    [string]$ExcelSpecFile,
    [switch]$Verbose
)

# Import the SqlServerDataImport module
$moduleDir = Split-Path $MyInvocation.MyCommand.Path
$modulePath = Join-Path $moduleDir "SqlServerDataImport.psm1"

if (-not (Test-Path $modulePath)) {
    Write-Host "ERROR: SqlServerDataImport.psm1 module not found at: $modulePath" -ForegroundColor Red
    exit 1
}

Import-Module $modulePath -Force

# Check for required PowerShell modules
try {
    Import-Module SqlServer -ErrorAction Stop
}
catch {
    Write-Host "ERROR: SqlServer module not found. Please install it using: Install-Module -Name SqlServer" -ForegroundColor Red
    exit 1
}

try {
    Import-Module ImportExcel -ErrorAction Stop
}
catch {
    Write-Host "ERROR: ImportExcel module not found. Please install it using: Install-Module -Name ImportExcel" -ForegroundColor Red
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
        Write-ImportLogVerbose "Using default data folder" -EnableVerbose:$Verbose
    }
    else {
        $dataFolder = $dataFolderInput.Trim()
        Write-ImportLogVerbose "User specified data folder: $dataFolder" -EnableVerbose:$Verbose
    }

    # Prompt for ExcelSpecFile
    $defaultExcelFile = "ExportSpec.xlsx"
    Write-Host "`nDefault Excel specification file: '$defaultExcelFile'"
    $excelFileInput = Read-Host "Press Enter to use default, or enter a different Excel file name"

    if ([string]::IsNullOrWhiteSpace($excelFileInput)) {
        $excelFile = $defaultExcelFile
        Write-ImportLogVerbose "Using default Excel specification file" -EnableVerbose:$Verbose
    }
    else {
        $excelFile = $excelFileInput.Trim()
        Write-ImportLogVerbose "User specified Excel file: $excelFile" -EnableVerbose:$Verbose
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
    Write-ImportLogVerbose "SQL Server instance specified: $server" -EnableVerbose:$Verbose
    $database = Read-Host "Enter database name"
    Write-ImportLogVerbose "Database name specified: $database" -EnableVerbose:$Verbose

    Write-Host "`nAuthentication Methods:"
    Write-Host "1. Windows Authentication"
    Write-Host "2. SQL Server Authentication"
    $authChoice = Read-Host "Select authentication method (1 or 2)"
    Write-ImportLogVerbose "Authentication method selected: $authChoice" -EnableVerbose:$Verbose

    if ($authChoice -eq "2") {
        $username = Read-Host "Enter username"
        Write-ImportLogVerbose "SQL Server username specified: $username" -EnableVerbose:$Verbose
        $securePassword = Read-Host "Enter password" -AsSecureString
        Write-ImportLogVerbose "SQL Server password provided (secured)" -EnableVerbose:$Verbose
        # Convert SecureString to plaintext for connection string (required by SQL Server)
        $BSTR = [System.Runtime.InteropServices.Marshal]::SecureStringToBSTR($securePassword)
        $password = [System.Runtime.InteropServices.Marshal]::PtrToStringAuto($BSTR)
        $connectionString = "Server=$server;Database=$database;User Id=$username;Password=$password;"
        # Clear password from memory immediately after use
        [System.Runtime.InteropServices.Marshal]::ZeroFreeBSTR($BSTR)
    }
    else {
        Write-ImportLogVerbose "Using Windows Authentication" -EnableVerbose:$Verbose
        $connectionString = "Server=$server;Database=$database;Integrated Security=True;"
    }

    # Test connection using module function
    Write-ImportLogVerbose "Testing database connection..." -EnableVerbose:$Verbose
    if (-not (Test-DatabaseConnection -ConnectionString $connectionString -EnableVerbose:$Verbose)) {
        Write-Host "Failed to connect to database. Please check your connection details." -ForegroundColor Red
        exit 1
    }

    Write-Host "Connection successful!" -ForegroundColor Green
    return $connectionString
}

function Get-SchemaName {
    param([string]$DefaultSchema)

    Write-Host "`n=== Schema Configuration ===" -ForegroundColor Cyan
    Write-Host "Default schema name: '$DefaultSchema'"
    $response = Read-Host "Press Enter to use default, or enter a different schema name"

    if ([string]::IsNullOrWhiteSpace($response)) {
        Write-ImportLogVerbose "Using default schema name: $DefaultSchema" -EnableVerbose:$Verbose
        return $DefaultSchema
    }
    else {
        $schemaName = $response.Trim()
        Write-ImportLogVerbose "User specified schema name: $schemaName" -EnableVerbose:$Verbose
        return $schemaName
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
        "1" { return "Cancel" }
        "2" { return "Skip" }
        "3" { return "Truncate" }
        "4" { return "Recreate" }
    }
}

function Get-FieldMismatchAction {
    param([string]$TableName, [int]$FileFieldCount, [int]$SpecFieldCount)

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
        "3" { return "Always" }
    }
}

# Main script execution
Write-Host "=== SQL Server Data Import Script ===" -ForegroundColor Cyan
Write-ImportLog "Starting SQL Server Data Import Script" -Level "INFO"
Write-ImportLog "Verbose logging enabled: $Verbose" -Level "INFO"


try {
    # Get DataFolder and ExcelSpecFile if not provided as parameters
    if ([string]::IsNullOrWhiteSpace($DataFolder) -or [string]::IsNullOrWhiteSpace($ExcelSpecFile)) {
        Write-ImportLogVerbose "Parameters not fully specified, prompting for configuration" -EnableVerbose:$Verbose
        $config = Get-DataFolderAndSpec
        if ([string]::IsNullOrWhiteSpace($DataFolder)) {
            $DataFolder = $config.DataFolder
        }
        if ([string]::IsNullOrWhiteSpace($ExcelSpecFile)) {
            $ExcelSpecFile = $config.ExcelSpecFile
        }
    }
    else {
        Write-ImportLogVerbose "Using provided parameters - DataFolder: $DataFolder, ExcelSpecFile: $ExcelSpecFile" -EnableVerbose:$Verbose
    }

    Write-Host "`nUsing configuration:" -ForegroundColor Green
    Write-Host "Data Folder: $DataFolder"
    Write-Host "Excel Spec File: $ExcelSpecFile"

    # Initialize log file now that we have the data folder
    if ($Verbose) {
        Initialize-ImportLog -DataFolder $DataFolder -EnableVerbose:$Verbose
    }

    # Get database connection
    $connectionString = Get-DatabaseConnection

    # Get prefix from data folder
    $prefix = Get-DataPrefix -FolderPath $DataFolder -EnableVerbose:$Verbose

    # Get schema name
    $schemaName = Get-SchemaName -DefaultSchema $prefix

    # Get data files
    $datFiles = Get-ChildItem -Path $DataFolder -Filter "*.dat" | Where-Object { $_.Name -like "$prefix*" }

    if ($datFiles.Count -eq 0) {
        throw "No .dat files found with prefix '$prefix'"
    }

    Write-Host "`nFound $($datFiles.Count) data files to process:" -ForegroundColor Green
    $datFiles | ForEach-Object { Write-Host "  $($_.Name)" }

    # Read table specifications
    $excelPath = Join-Path $DataFolder $ExcelSpecFile
    $tableSpecs = Get-TableSpecifications -ExcelPath $excelPath -EnableVerbose:$Verbose

    # Create schema
    New-DatabaseSchema -ConnectionString $connectionString -SchemaName $schemaName -EnableVerbose:$Verbose

    # Process each table with interactive decisions
    $alwaysSkipFirst = $false
    $tableAction = "Ask"

    foreach ($datFile in $datFiles) {
        $tableName = $datFile.Name -replace "^$prefix", "" -replace "\.dat$", ""
        Write-Host "`n=== Processing Table: $tableName ===" -ForegroundColor Cyan

        # Get field specifications for this table
        $tableFields = $tableSpecs | Where-Object { $_."Table name" -eq $tableName }

        if ($tableFields.Count -eq 0) {
            Write-Host "No field specifications found for table '$tableName'. Skipping." -ForegroundColor Yellow
            continue
        }

        Write-Host "Found $($tableFields.Count) field specifications for table '$tableName'"

        # Check if table exists
        $tableExists = Test-TableExists -ConnectionString $connectionString -SchemaName $schemaName -TableName $tableName -EnableVerbose:$Verbose

        if ($tableExists) {
            if ($tableAction -eq "Ask") {
                $action = Get-TableAction -TableName $tableName
                if ($action -eq "Cancel") {
                    Write-Host "Script cancelled by user." -ForegroundColor Red
                    exit 0
                }
                $tableAction = $action
            }

            switch ($tableAction) {
                "Skip" {
                    Write-Host "Skipping table '$tableName'" -ForegroundColor Yellow
                    continue
                }
                "Truncate" {
                    Clear-DatabaseTable -ConnectionString $connectionString -SchemaName $schemaName -TableName $tableName -EnableVerbose:$Verbose
                }
                "Recreate" {
                    Remove-DatabaseTable -ConnectionString $connectionString -SchemaName $schemaName -TableName $tableName -EnableVerbose:$Verbose
                    New-DatabaseTable -ConnectionString $connectionString -SchemaName $schemaName -TableName $tableName -Fields $tableFields -EnableVerbose:$Verbose
                }
            }
        }
        else {
            New-DatabaseTable -ConnectionString $connectionString -SchemaName $schemaName -TableName $tableName -Fields $tableFields -EnableVerbose:$Verbose
        }

        # Check field count and handle mismatch
        $skipFirstField = $alwaysSkipFirst
        if (-not $alwaysSkipFirst) {
            $testLines = Get-Content -Path $datFile.FullName -TotalCount 1
            if ($testLines.Count -gt 0) {
                $firstLineFields = ($testLines[0] -split '\|').Count
                $specFieldCount = $tableFields.Count

                if ($firstLineFields -eq ($specFieldCount + 1)) {
                    $action = Get-FieldMismatchAction -TableName $tableName -FileFieldCount $firstLineFields -SpecFieldCount $specFieldCount
                    if ($action -eq "Exit") {
                        Write-Host "Import cancelled by user." -ForegroundColor Red
                        exit 0
                    }
                    elseif ($action -eq "Skip") {
                        $skipFirstField = $true
                        Write-Host "Will skip first field for this table" -ForegroundColor Green
                    }
                    elseif ($action -eq "Always") {
                        $alwaysSkipFirst = $true
                        $skipFirstField = $true
                        Write-Host "Will skip first field for all remaining tables" -ForegroundColor Green
                    }
                }
            }
        }

        # Import data with fallback
        try {
            $rowsImported = Import-DataFileBulk -ConnectionString $connectionString -SchemaName $schemaName -TableName $tableName -FilePath $datFile.FullName -Fields $tableFields -SkipFirstField $skipFirstField -EnableVerbose:$Verbose
            Write-ImportLog "Used efficient SqlBulkCopy for import" -Level "SUCCESS"
        }
        catch {
            Write-ImportLog "Bulk copy failed, falling back to standard import: $($_.Exception.Message)" -Level "WARNING"
            Write-Host "Bulk copy failed, using standard import method..." -ForegroundColor Yellow
            $rowsImported = Import-DataFileStandard -ConnectionString $connectionString -SchemaName $schemaName -TableName $tableName -FilePath $datFile.FullName -Fields $tableFields -SkipFirstField $skipFirstField -EnableVerbose:$Verbose
        }

        Add-ImportSummary -TableName $tableName -RowCount $rowsImported -FileName $datFile.Name
    }

    # Display summary
    Show-ImportSummary -SchemaName $schemaName -EnableVerbose:$Verbose

    Write-ImportLog "Import process completed successfully" -Level "SUCCESS"
    Write-Host "`n=== Import Process Completed ===" -ForegroundColor Green
}
catch {
    Write-ImportLog "Import process failed: $($_.Exception.Message)" -Level "ERROR"
    Write-Host "Import failed: $($_.Exception.Message)" -ForegroundColor Red
    exit 1
}