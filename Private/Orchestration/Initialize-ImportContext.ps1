function Initialize-ImportContext {
    <#
    .SYNOPSIS
    Initializes and validates the import context before processing begins.

    .DESCRIPTION
    Performs all pre-import validation and setup:
    - Validates Excel specification file exists
    - Detects data file prefix
    - Tests database connection
    - Determines and validates schema name
    - Creates database schema if needed
    - Reads table specifications from Excel
    - Discovers matching DAT files

    Returns a context object with all necessary information for import processing.

    .PARAMETER DataFolder
    Folder containing DAT files and Excel specification.

    .PARAMETER ExcelSpecFile
    Excel specification file name.

    .PARAMETER ConnectionString
    SQL Server connection string.

    .PARAMETER SchemaName
    Schema name (optional - defaults to detected prefix).

    .PARAMETER ValidateOnly
    When specified, skips database connection and schema creation. Used for validation-only mode.

    .EXAMPLE
    $context = Initialize-ImportContext -DataFolder "C:\Data" -ExcelSpecFile "ExportSpec.xlsx" -ConnectionString $connString

    .EXAMPLE
    $context = Initialize-ImportContext -DataFolder "C:\Data" -ExcelSpecFile "ExportSpec.xlsx" -ConnectionString $connString -ValidateOnly

    .OUTPUTS
    Hashtable with keys: ConnectionString, SchemaName, Prefix, TableSpecs, DataFiles
    #>
    [CmdletBinding()]
    [OutputType([hashtable])]
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

        [Parameter(Mandatory=$false)]
        [string]$SchemaName,

        [Parameter(Mandatory=$false)]
        [switch]$ValidateOnly
    )

    Write-ImportLog "Initializing import context" -Level "INFO"

    # Validate Excel specification file
    $excelPath = Join-Path $DataFolder $ExcelSpecFile
    Test-ImportPath -Path $excelPath -PathType File -ThrowOnError
    Write-Verbose "Excel specification file validated: $excelPath"

    # Find prefix
    $prefix = Get-DataPrefix -FolderPath $DataFolder
    Write-Verbose "Detected data file prefix: $prefix"

    # Test database connection (skip in validate-only mode)
    if (-not $ValidateOnly) {
        if (-not (Test-DatabaseConnection -ConnectionString $ConnectionString)) {
            throw "Database connection test failed"
        }
        Write-Verbose "Database connection validated"
    }
    else {
        Write-Verbose "Skipping database connection test (validate-only mode)"
    }

    # Determine schema name (use prefix if not specified)
    if (-not $SchemaName) {
        $SchemaName = $prefix
        Write-Verbose "Schema name not specified, using detected prefix: $SchemaName"
    }

    # Validate schema name
    Test-SchemaName -SchemaName $SchemaName -ThrowOnError
    Write-Verbose "Schema name validated: $SchemaName"

    # Create schema (skip in validate-only mode)
    if (-not $ValidateOnly) {
        New-DatabaseSchema -ConnectionString $ConnectionString -SchemaName $SchemaName
        Write-Verbose "Database schema ensured: $SchemaName"
    }
    else {
        Write-Verbose "Skipping database schema creation (validate-only mode)"
    }

    # Read table specifications
    $tableSpecs = Get-TableSpecifications -ExcelPath $excelPath
    Write-Verbose "Read $(@($tableSpecs).Count) table specification entries from Excel"

    # Validate table specifications
    Write-Verbose "Validating Excel specification..."
    $validationResult = Test-ExcelSpecification -Specifications $tableSpecs

    if (-not $validationResult.IsValid) {
        Write-Host "`nExcel Specification Validation Failed!" -ForegroundColor Red
        Write-Host "Found $($validationResult.Errors.Count) error(s):`n" -ForegroundColor Red
        $validationResult.Errors | ForEach-Object { Write-Host "  - $_" -ForegroundColor Red }

        if ($validationResult.Warnings.Count -gt 0) {
            Write-Host "`nWarnings ($($validationResult.Warnings.Count)):" -ForegroundColor Yellow
            $validationResult.Warnings | ForEach-Object { Write-Host "  - $_" -ForegroundColor Yellow }
        }

        throw "Excel specification validation failed. Please correct the errors in your Excel file and try again."
    }

    if ($validationResult.Warnings.Count -gt 0) {
        Write-Host "`nExcel Specification Warnings ($($validationResult.Warnings.Count)):" -ForegroundColor Yellow
        $validationResult.Warnings | ForEach-Object { Write-Host "  - $_" -ForegroundColor Yellow }
    }

    Write-Verbose "Excel specification validation passed"

    # Get data files
    $datFiles = Get-ChildItem -Path $DataFolder -Filter "*.dat" | Where-Object { $_.Name -like "$prefix*" }

    if ($datFiles.Count -eq 0) {
        throw "No .dat files found with prefix '$prefix' in folder: $DataFolder"
    }

    Write-Host "`nFound $($datFiles.Count) data files to process:" -ForegroundColor Green
    $datFiles | ForEach-Object { Write-Host "  $($_.Name)" }

    # Return context object
    return @{
        ConnectionString = $ConnectionString
        SchemaName = $SchemaName
        Prefix = $prefix
        TableSpecs = $tableSpecs
        DataFiles = $datFiles
    }
}
