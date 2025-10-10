# SQL Server Data Import - Command Line Interface (Refactored)
# Uses refactored SqlServerDataImport module and common utilities

[CmdletBinding(SupportsShouldProcess=$true)]
param(
    [string]$DataFolder,
    [string]$ExcelSpecFile,
    [string]$Server,
    [string]$Database,
    [string]$Username,
    [string]$Password,
    [switch]$Force,
    [string]$PostInstallScripts
)

#region Module Loading

# Import common utilities module first
$moduleDir = Split-Path $MyInvocation.MyCommand.Path
$commonModulePath = Join-Path $moduleDir "Import-DATFile.Common.psm1"

if (-not (Test-Path $commonModulePath)) {
    Write-Host "ERROR: Import-DATFile.Common.psm1 not found at: $commonModulePath" -ForegroundColor Red
    exit 1
}

Import-Module $commonModulePath -Force

# Import core module
$coreModulePath = Join-Path $moduleDir "SqlServerDataImport.psm1"
if (-not (Test-Path $coreModulePath)) {
    Write-Host "ERROR: SqlServerDataImport.psm1 module not found at: $coreModulePath" -ForegroundColor Red
    exit 1
}

Import-Module $coreModulePath -Force

# Initialize required PowerShell modules (SqlServer, ImportExcel)
if (-not (Initialize-ImportModules)) {
    Write-Host "ERROR: Required modules not available. Please install SqlServer and ImportExcel modules." -ForegroundColor Red
    Write-Host "Run: Install-Module -Name SqlServer, ImportExcel" -ForegroundColor Yellow
    exit 1
}

#endregion

#region Helper Functions

function Get-DataFolderAndSpec {
    <#
    .SYNOPSIS
    Prompts user for data folder and Excel specification file.

    .DESCRIPTION
    Interactive prompts with defaults for data folder (current location)
    and Excel file (ExportSpec.xlsx).
    #>
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

function Get-DatabaseConnectionDetails {
    <#
    .SYNOPSIS
    Prompts user for database connection details.

    .DESCRIPTION
    Collects server, database, and optional authentication details from user.
    Uses common module's New-SqlConnectionString for building connection string.

    .PARAMETER Server
    SQL Server instance name (optional - will prompt if not provided).

    .PARAMETER Database
    Database name (optional - will prompt if not provided).

    .PARAMETER Username
    SQL Server authentication username (optional - uses Windows auth if not provided).

    .PARAMETER Password
    SQL Server authentication password (optional - will prompt if username provided).
    #>
    param(
        [string]$Server,
        [string]$Database,
        [string]$Username,
        [string]$Password
    )

    Write-Host "`n=== Database Connection Configuration ===" -ForegroundColor Cyan

    # Prompt for server if not provided
    if ([string]::IsNullOrWhiteSpace($Server)) {
        $Server = Read-Host "Enter SQL Server instance (e.g., localhost, server\instance)"
    }
    else {
        Write-Host "Server: $Server (from parameter)"
    }

    # Prompt for database if not provided
    if ([string]::IsNullOrWhiteSpace($Database)) {
        $Database = Read-Host "Enter database name"
    }
    else {
        Write-Host "Database: $Database (from parameter)"
    }

    # Determine authentication method
    $useSqlAuth = -not [string]::IsNullOrWhiteSpace($Username)

    if ($useSqlAuth) {
        # SQL Server Authentication
        Write-Host "Authentication: SQL Server Authentication (Username: $Username)" -ForegroundColor Green

        # Prompt for password if not provided
        if ([string]::IsNullOrWhiteSpace($Password)) {
            Write-Host "Password required for SQL Server Authentication" -ForegroundColor Yellow
            $securePassword = Read-Host "Enter password for user '$Username'" -AsSecureString
            $BSTR = [System.Runtime.InteropServices.Marshal]::SecureStringToBSTR($securePassword)
            $Password = [System.Runtime.InteropServices.Marshal]::PtrToStringAuto($BSTR)
            [System.Runtime.InteropServices.Marshal]::ZeroFreeBSTR($BSTR)
        }

        # Use common module to build connection string
        $connectionString = New-SqlConnectionString -Server $Server -Database $Database -Username $Username -Password $Password
    }
    else {
        # Windows Authentication
        Write-Host "Authentication: Windows Authentication (Integrated Security)" -ForegroundColor Green

        # Use common module to build connection string
        $connectionString = New-SqlConnectionString -Server $Server -Database $Database
    }

    # Test connection
    if (-not (Test-DatabaseConnection -ConnectionString $connectionString)) {
        Write-Host "Failed to connect to database. Please check your connection details." -ForegroundColor Red
        exit 1
    }

    Write-Host "Connection successful!" -ForegroundColor Green
    return $connectionString
}

function Get-SchemaName {
    <#
    .SYNOPSIS
    Prompts user for schema name with default option.

    .PARAMETER DefaultSchema
    Default schema name to suggest (typically the detected prefix).
    #>
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

#endregion

#region Main Execution

Write-Host "=== SQL Server Data Import Script (Refactored) ===" -ForegroundColor Cyan
Write-ImportLog "Starting SQL Server Data Import Script" -Level "INFO"

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
    $connectionString = Get-DatabaseConnectionDetails -Server $Server -Database $Database -Username $Username -Password $Password

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

    # Execute import using core module
    Write-Host "`n=== Starting Import Process ===" -ForegroundColor Green

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

        # Pass through Verbose parameter if specified
        if ($PSCmdlet.MyInvocation.BoundParameters['Verbose']) {
            $importParams.Verbose = $true
            Write-Host "Verbose logging enabled - detailed operational information will be displayed" -ForegroundColor Cyan
        }

        # Pass through WhatIf parameter if specified
        if ($PSCmdlet.MyInvocation.BoundParameters['WhatIf']) {
            $importParams.WhatIf = $true
            Write-Host "WhatIf mode enabled - no database changes will be made" -ForegroundColor Cyan
        }

        $summary = Invoke-SqlServerDataImport @importParams
        Write-Host "`n=== Import Process Completed Successfully ===" -ForegroundColor Green

        # Summary is displayed by the module itself via Show-ImportSummary
    }
    catch {
        Write-ImportLog "Import failed: $($_.Exception.Message)" -Level "ERROR"
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
    Write-Host "Script failed: $($_.Exception.Message)" -ForegroundColor Red
    exit 1
}

#endregion
