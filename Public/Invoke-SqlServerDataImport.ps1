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

    .PARAMETER Server
    SQL Server instance name (e.g., "localhost", "server\instance").

    .PARAMETER Database
    Database name.

    .PARAMETER Username
    SQL Server authentication username (optional - uses Windows Authentication if not provided).

    .PARAMETER Password
    SQL Server authentication password (required when Username is provided).

    .PARAMETER SchemaName
    Schema name (optional - defaults to detected prefix).

    .PARAMETER TableExistsAction
    Action when table exists: Ask, Skip, Truncate, Recreate.

    .PARAMETER PostInstallScripts
    Optional path to post-install SQL scripts.

    .PARAMETER ValidateOnly
    When specified, validates Excel specification and data files without importing to database.
    Use this to verify your data and configuration before performing the actual import.

    .EXAMPLE
    Invoke-SqlServerDataImport -DataFolder "C:\Data" -ExcelSpecFile "ExportSpec.xlsx" -Server "localhost" -Database "MyDB" -SchemaName "dbo"

    .EXAMPLE
    Invoke-SqlServerDataImport -DataFolder "C:\Data" -ExcelSpecFile "ExportSpec.xlsx" -Server "localhost" -Database "MyDB" -Username "sa" -Password "P@ssw0rd"

    .EXAMPLE
    Invoke-SqlServerDataImport -DataFolder "C:\Data" -ExcelSpecFile "ExportSpec.xlsx" -Server "localhost" -Database "MyDB" -ValidateOnly
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
        [string]$Server,

        [Parameter(Mandatory=$true)]
        [ValidateNotNullOrEmpty()]
        [string]$Database,

        [Parameter(Mandatory=$false)]
        [string]$Username,

        [Parameter(Mandatory=$false)]
        [string]$Password,

        [string]$SchemaName,

        [ValidateSet("Ask", "Skip", "Truncate", "Recreate")]
        [string]$TableExistsAction = "Ask",

        [string]$PostInstallScripts,

        [switch]$ValidateOnly
    )

    # Set verbose logging flag
    $script:VerboseLogging = ($PSCmdlet.MyInvocation.BoundParameters['Verbose'] -eq $true) -or ($VerbosePreference -eq 'Continue')

    # Clear previous summary
    Clear-ImportSummary

    # Build connection string
    $connectionString = New-SqlConnectionString -Server $Server -Database $Database -Username $Username -Password $Password
    Write-Verbose "Connection string built for Server: $Server, Database: $Database"

    try {
        if ($ValidateOnly) {
            Write-ImportLog "Starting validation mode (no database changes will be made)" -Level "INFO"
            Write-Host "`n=== VALIDATION MODE ===" -ForegroundColor Magenta
            Write-Host "No data will be imported to the database.`n" -ForegroundColor Magenta
        }
        else {
            Write-ImportLog "Starting SQL Server data import process" -Level "INFO"
        }

        # Initialize import context (validation, connection, schema setup, spec reading)
        $context = Initialize-ImportContext -DataFolder $DataFolder `
                                            -ExcelSpecFile $ExcelSpecFile `
                                            -ConnectionString $connectionString `
                                            -SchemaName $SchemaName `
                                            -ValidateOnly:$ValidateOnly

        Write-Verbose "Import context initialized successfully"

        if ($ValidateOnly) {
            # Validation mode: validate all data files without importing
            $validationResults = @()

            foreach ($datFile in $context.DataFiles) {
                # Extract table name from filename
                $tableName = $datFile.Name -replace "^$($context.Prefix)", "" -replace "\.dat$", ""
                Write-Host "`n=== Validating Table: $tableName ===" -ForegroundColor Cyan

                # Get field specifications for this table
                $tableFields = $context.TableSpecs | Where-Object { $_."Table name" -eq $tableName }

                if ($tableFields.Count -eq 0) {
                    Write-Warning "No field specifications found for table '$tableName' in Excel specification - skipping"
                    $validationResults += @{
                        TableName = $tableName
                        IsValid = $false
                        RowCount = 0
                        Errors = @("No field specifications found in Excel")
                        Warnings = @()
                    }
                    continue
                }

                # Validate data file
                $result = Test-DataFileValidation -FilePath $datFile.FullName `
                                                  -Fields $tableFields `
                                                  -TableName $tableName

                $validationResults += $result
            }

            # Display validation summary
            Show-ValidationSummary -ValidationResults $validationResults -SchemaName $context.SchemaName

            # Return validation results
            Write-Output -NoEnumerate $validationResults
        }
        else {
            # Normal import mode: process each data file
            foreach ($datFile in $context.DataFiles) {
                $result = Invoke-TableImportProcess -DataFile $datFile `
                                                    -ConnectionString $context.ConnectionString `
                                                    -SchemaName $context.SchemaName `
                                                    -Prefix $context.Prefix `
                                                    -TableSpecs $context.TableSpecs `
                                                    -TableExistsAction $TableExistsAction

                Write-Verbose "Table import completed: $($result.TableName) ($($result.RowsImported) rows, Skipped: $($result.Skipped))"
            }

            # Finalize import (summary display, post-install scripts)
            Complete-ImportProcess -SchemaName $context.SchemaName `
                                   -ConnectionString $context.ConnectionString `
                                   -DatabaseName $Database `
                                   -PostInstallScripts $PostInstallScripts

            # Return import summary explicitly with Write-Output to ensure proper pipeline behavior
            Write-Output -NoEnumerate $script:ImportSummary
        }
    }
    catch {
        Write-Error "Import process failed: $($_.Exception.Message)"
        throw
    }
}
