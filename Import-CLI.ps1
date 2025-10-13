# SQL Server Data Import - Command Line Interface (Refactored)
# Non-interactive CLI for scripting and automation
# For interactive experience, use Import-GUI.ps1 or Launch-Import-GUI.bat

[CmdletBinding(SupportsShouldProcess=$true)]
param(
    [Parameter(Mandatory=$true)]
    [ValidateScript({ Test-Path $_ -PathType Container })]
    [string]$DataFolder,

    [Parameter(Mandatory=$true)]
    [ValidateNotNullOrEmpty()]
    [string]$ExcelSpecFile,

    [Parameter(Mandatory=$false)]
    [string]$Server,

    [Parameter(Mandatory=$false)]
    [string]$Database,

    [string]$Username,
    [string]$Password,
    [string]$SchemaName,
    [switch]$Force,
    [switch]$ValidateOnly,
    [string]$PostInstallScripts
)

#region Module Loading

# Import core module (which will initialize dependencies automatically)
$moduleDir = Split-Path $MyInvocation.MyCommand.Path
$coreModulePath = Join-Path $moduleDir "SqlServerDataImport.psm1"

if (-not (Test-Path $coreModulePath)) {
    Write-Host "ERROR: SqlServerDataImport.psm1 module not found at: $coreModulePath" -ForegroundColor Red
    exit 1
}

try {
    Import-Module $coreModulePath -Force -ErrorAction Stop
}
catch {
    Write-Host "ERROR: Failed to load SqlServerDataImport module." -ForegroundColor Red
    Write-Host "This could be due to missing dependencies (SqlServer, ImportExcel modules)." -ForegroundColor Yellow
    Write-Host "Error: $($_.Exception.Message)" -ForegroundColor Red
    Write-Host "`nTo install required modules, run: Install-Module -Name SqlServer, ImportExcel" -ForegroundColor Yellow
    exit 1
}

#endregion

#region Main Execution

Write-Host "=== SQL Server Data Import Script (Refactored) ===" -ForegroundColor Cyan
Write-ImportLog "Starting SQL Server Data Import Script" -Level "INFO"

try {
    # Validate Server/Database are provided unless ValidateOnly mode
    if (-not $ValidateOnly) {
        if ([string]::IsNullOrWhiteSpace($Server) -or [string]::IsNullOrWhiteSpace($Database)) {
            Write-Host "ERROR: Server and Database parameters are required unless -ValidateOnly is specified" -ForegroundColor Red
            Write-Host "`nUsage examples:" -ForegroundColor Yellow
            Write-Host "  .\Import-CLI.ps1 -DataFolder 'C:\Data' -ExcelSpecFile 'spec.xlsx' -Server 'localhost' -Database 'MyDB'" -ForegroundColor Gray
            Write-Host "  .\Import-CLI.ps1 -DataFolder 'C:\Data' -ExcelSpecFile 'spec.xlsx' -ValidateOnly" -ForegroundColor Gray
            exit 1
        }
    }

    Write-Host "`nUsing configuration:" -ForegroundColor Green
    Write-Host "Data Folder: $DataFolder"
    Write-Host "Excel Spec File: $ExcelSpecFile"

    # Display mode
    if ($ValidateOnly) {
        Write-Host "Mode: VALIDATION ONLY (no database import)" -ForegroundColor Magenta
    } else {
        Write-Host "Server: $Server"
        Write-Host "Database: $Database"
        if ($Username) {
            Write-Host "Authentication: SQL Server (User: $Username)"
        } else {
            Write-Host "Authentication: Windows Authentication"
        }
    }

    # Get prefix from data folder
    $prefix = Get-DataPrefix -FolderPath $DataFolder

    # Determine schema name (use parameter or default to prefix)
    if (-not [string]::IsNullOrWhiteSpace($SchemaName)) {
        $schemaName = $SchemaName
        Write-Host "Schema: $schemaName (from parameter)" -ForegroundColor Green
    } else {
        $schemaName = $prefix
        Write-Host "Schema: $schemaName (using detected prefix)" -ForegroundColor Green
    }

    # Determine table action based on Force parameter
    if ($Force) {
        $tableAction = "Recreate"
        Write-Host "`n=== FORCE MODE ENABLED ===" -ForegroundColor Red
        Write-Host "• All existing tables will be DROPPED and RECREATED" -ForegroundColor Red
        Write-Host "• This will DELETE all existing data in the tables" -ForegroundColor Red
    } else {
        $tableAction = "Ask"
    }

    # Show assumptions only in import mode (not validation)
    if (-not $ValidateOnly) {
        Write-Host "`n=== IMPORTANT: Optimized Import Assumptions ===" -ForegroundColor Yellow
        Write-Host "• Every data file MUST have an ImportID as the first field"
        Write-Host "• Field count MUST match: ImportID + specification fields"
        Write-Host "• Import will FAIL immediately if field counts don't match"
        Write-Host "• Only SqlBulkCopy is used - no fallback to INSERT statements"
        Write-Host "• No file logging for maximum speed"
        if ($Force) {
            Write-Host "• FORCE MODE: All tables will be dropped and recreated (existing data will be lost)" -ForegroundColor Red
        }
    }

    # Execute import using core module
    Write-Host "`n=== Starting $( if ($ValidateOnly) { 'Validation' } else { 'Import' } ) Process ===" -ForegroundColor Green

    try {
        $importParams = @{
            DataFolder = $DataFolder
            ExcelSpecFile = $ExcelSpecFile
            SchemaName = $schemaName
        }

        # Add database parameters (use dummy values in ValidateOnly mode)
        if ($ValidateOnly) {
            $importParams.Server = if ($Server) { $Server } else { "localhost" }
            $importParams.Database = if ($Database) { $Database } else { "tempdb" }
        } else {
            $importParams.Server = $Server
            $importParams.Database = $Database
            $importParams.TableExistsAction = $tableAction
        }

        # Add Username/Password if SQL Server authentication is being used
        if (-not [string]::IsNullOrWhiteSpace($Username)) {
            $importParams.Username = $Username
            $importParams.Password = $Password
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

        # Pass through ValidateOnly parameter if specified
        if ($ValidateOnly) {
            $importParams.ValidateOnly = $true
            Write-Host "ValidateOnly mode enabled - data will be validated without database import" -ForegroundColor Cyan
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
