# Test-ModuleLoading.ps1
# Diagnostic script to verify all Private and Public functions load correctly

param(
    [switch]$Verbose
)

$VerbosePreference = if ($Verbose) { "Continue" } else { "SilentlyContinue" }

Write-Host "`n=== Module Loading Diagnostic ===" -ForegroundColor Cyan

# Get module path
$moduleRoot = Split-Path $MyInvocation.MyCommand.Path
$modulePath = Join-Path $moduleRoot "SqlServerDataImport.psm1"

Write-Host "`nModule Path: $modulePath" -ForegroundColor White

# Remove module if already loaded
if (Get-Module SqlServerDataImport) {
    Write-Host "Removing previously loaded module..." -ForegroundColor Yellow
    Remove-Module SqlServerDataImport -Force
}

# Import module
Write-Host "`nImporting module..." -ForegroundColor Yellow
try {
    Import-Module $modulePath -Force -ErrorAction Stop -Verbose:$Verbose
    Write-Host "[OK] Module imported successfully" -ForegroundColor Green
}
catch {
    Write-Host "[FAILED] Module import failed: $($_.Exception.Message)" -ForegroundColor Red
    exit 1
}

# Check exported functions
Write-Host "`n--- Exported Functions ---" -ForegroundColor Cyan
$exportedFunctions = Get-Command -Module SqlServerDataImport
Write-Host "Count: $($exportedFunctions.Count)" -ForegroundColor White
$exportedFunctions | ForEach-Object { Write-Host "  - $($_.Name)" -ForegroundColor Green }

# Check if specific functions are available
Write-Host "`n--- Checking Specific Functions ---" -ForegroundColor Cyan

$functionsToCheck = @(
    'Write-ImportLog',
    'Get-DataPrefix',
    'Get-TableSpecifications',
    'Initialize-ImportContext',
    'Test-DatabaseConnection',
    'New-SqlConnectionString',
    'Invoke-TableImportProcess'
)

foreach ($funcName in $functionsToCheck) {
    $func = Get-Command $funcName -ErrorAction SilentlyContinue
    if ($func) {
        Write-Host "  [OK] $funcName" -ForegroundColor Green
    }
    else {
        Write-Host "  [MISSING] $funcName" -ForegroundColor Red
    }
}

# Count all Private functions
Write-Host "`n--- Private Function Files ---" -ForegroundColor Cyan
$privateFunctions = Get-ChildItem -Path "$moduleRoot\Private\*.ps1" -Recurse
Write-Host "Total files: $($privateFunctions.Count)" -ForegroundColor White

# Check for syntax errors in each file
Write-Host "`n--- Syntax Validation ---" -ForegroundColor Cyan
$syntaxErrors = @()

foreach ($file in $privateFunctions) {
    $errors = $null
    $null = [System.Management.Automation.PSParser]::Tokenize((Get-Content $file.FullName -Raw), [ref]$errors)

    if ($errors.Count -gt 0) {
        Write-Host "  [ERROR] $($file.Name)" -ForegroundColor Red
        $syntaxErrors += [PSCustomObject]@{
            File = $file.Name
            Errors = $errors
        }
    }
    else {
        Write-Host "  [OK] $($file.Name)" -ForegroundColor Green
    }
}

if ($syntaxErrors.Count -gt 0) {
    Write-Host "`n--- Syntax Error Details ---" -ForegroundColor Red
    foreach ($err in $syntaxErrors) {
        Write-Host "`nFile: $($err.File)" -ForegroundColor Yellow
        foreach ($e in $err.Errors) {
            Write-Host "  Line $($e.StartLine), Col $($e.StartColumn): $($e.Message)" -ForegroundColor Red
        }
    }
}

Write-Host "`n=== Diagnostic Complete ===" -ForegroundColor Cyan
