# SQL Server Data Import - Optimized Command Line Interface
# Simplified CLI that uses the optimized SqlServerDataImport module

param(
    [string]$DataFolder,
    [string]$ExcelSpecFile,
    [string]$Server,
    [string]$Database,
    [string]$Username,
    [string]$Password,
    [switch]$Force,
    [string]$PostInstallScripts,
    [switch]$VerboseLogging
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
    param(
        [string]$Server,
        [string]$Database,
        [string]$Username,
        [string]$Password
    )

    Write-Host "`n=== Database Connection Configuration ===" -ForegroundColor Cyan

    # Use provided parameters or prompt for missing ones
    if ([string]::IsNullOrWhiteSpace($Server)) {
        $Server = Read-Host "Enter SQL Server instance (e.g., localhost, server\instance)"
    }
    else {
        Write-Host "Server: $Server (from parameter)"
    }

    if ([string]::IsNullOrWhiteSpace($Database)) {
        $Database = Read-Host "Enter database name"
    }
    else {
        Write-Host "Database: $Database (from parameter)"
    }

    # Determine authentication method
    # If Username is provided, use SQL Authentication
    # If Username is NOT provided, use Windows Authentication (no prompt)
    $useSqlAuth = -not [string]::IsNullOrWhiteSpace($Username)

    if ($useSqlAuth) {
        # SQL Server Authentication
        Write-Host "Authentication: SQL Server Authentication (Username: $Username)" -ForegroundColor Green

        # If password not provided, prompt for it
        if ([string]::IsNullOrWhiteSpace($Password)) {
            Write-Host "Password required for SQL Server Authentication" -ForegroundColor Yellow
            $securePassword = Read-Host "Enter password for user '$Username'" -AsSecureString
            $BSTR = [System.Runtime.InteropServices.Marshal]::SecureStringToBSTR($securePassword)
            $Password = [System.Runtime.InteropServices.Marshal]::PtrToStringAuto($BSTR)
            [System.Runtime.InteropServices.Marshal]::ZeroFreeBSTR($BSTR)
        }

        $connectionString = "Server=$Server;Database=$Database;User Id=$Username;Password=$Password;"
    }
    else {
        # Windows Authentication (default when no username provided)
        Write-Host "Authentication: Windows Authentication (Integrated Security)" -ForegroundColor Green
        $connectionString = "Server=$Server;Database=$Database;Integrated Security=True;"
    }

    # Test connection using module function
    if (-not (Test-DatabaseConnection -ConnectionString $connectionString)) {
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
        return $DefaultSchema
    }
    else {
        return $response.Trim()
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

# Main script execution
Write-Host "=== SQL Server Data Import Script (Optimized) ===" -ForegroundColor Cyan
Write-ImportLog "Starting optimized SQL Server Data Import Script" -Level "INFO"

try {
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

    # Get database connection
    $connectionString = Get-DatabaseConnection -Server $Server -Database $Database -Username $Username -Password $Password

    # Get prefix from data folder
    $prefix = Get-DataPrefix -FolderPath $DataFolder

    # Get schema name
    $schemaName = Get-SchemaName -DefaultSchema $prefix

    # Determine table action based on Force parameter
    if ($Force) {
        $tableAction = "Recreate"
        Write-Host "`n=== FORCE MODE ENABLED ===" -ForegroundColor Red
        Write-Host "• All existing tables will be DROPPED and RECREATED" -ForegroundColor Red
        Write-Host "• This will DELETE all existing data in the tables" -ForegroundColor Red
    }
    else {
        $tableAction = "Ask"
    }

    Write-Host "`n=== IMPORTANT: Optimized Import Assumptions ===" -ForegroundColor Yellow
    Write-Host "• Every data file MUST have an ImportID as the first field"
    Write-Host "• Field count MUST match: ImportID + specification fields"
    Write-Host "• Import will FAIL immediately if field counts don't match"
    Write-Host "• Only SqlBulkCopy is used - no fallback to INSERT statements"
    Write-Host "• No file logging for maximum speed"
    if ($Force) {
        Write-Host "• FORCE MODE: All tables will be dropped and recreated (existing data will be lost)" -ForegroundColor Red
    }
    $confirm = Read-Host "`nDo you want to continue with these assumptions? (Y/N)"

    if ($confirm -notmatch '^[Yy]') {
        Write-Host "Import cancelled by user." -ForegroundColor Yellow
        exit 0
    }

    # Process tables with simplified logic
    Write-Host "`n=== Starting Optimized Import Process ===" -ForegroundColor Green

    # Use the optimized import function
    try {
        $importParams = @{
            DataFolder = $DataFolder
            ExcelSpecFile = $ExcelSpecFile
            ConnectionString = $connectionString
            SchemaName = $schemaName
            TableExistsAction = $tableAction
        }

        # Add PostInstallScripts if provided
        if (-not [string]::IsNullOrWhiteSpace($PostInstallScripts)) {
            $importParams.PostInstallScripts = $PostInstallScripts
            Write-Host "Post-install scripts will be executed from: $PostInstallScripts" -ForegroundColor Cyan
        }

        # Add Verbose flag if specified
        if ($VerboseLogging) {
            $importParams.Verbose = $true
            Write-Host "Verbose logging enabled - detailed operational information will be displayed" -ForegroundColor Cyan
        }

        $summary = Invoke-SqlServerDataImport @importParams
        Write-Host "`n=== Import Process Completed Successfully ===" -ForegroundColor Green

        # Display import summary
        if ($summary) {
            Write-Host "`n=== Import Summary ===" -ForegroundColor Cyan
            Write-Host $summary
        }
    }
    catch {
        Write-ImportLog "Optimized import failed: $($_.Exception.Message)" -Level "ERROR"
        Write-Host "Import failed: $($_.Exception.Message)" -ForegroundColor Red
        Write-Host "`nThis could be due to:" -ForegroundColor Yellow
        Write-Host "• Field count mismatch (check that first field is ImportID)" -ForegroundColor Yellow
        Write-Host "• Data type conversion issues" -ForegroundColor Yellow
        Write-Host "• SqlBulkCopy specific errors" -ForegroundColor Yellow
        Write-Host "• Missing or invalid data files" -ForegroundColor Yellow
        exit 1
    }
}
catch {
    Write-ImportLog "Script execution failed: $($_.Exception.Message)" -Level "ERROR"
    Write-Host "Script failed: $($_.Exception.Message)" -ForegroundColor Red
    exit 1
}