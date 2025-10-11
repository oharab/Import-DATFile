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

    .EXAMPLE
    Invoke-SqlServerDataImport -DataFolder "C:\Data" -ExcelSpecFile "ExportSpec.xlsx" -Server "localhost" -Database "MyDB" -SchemaName "dbo"

    .EXAMPLE
    Invoke-SqlServerDataImport -DataFolder "C:\Data" -ExcelSpecFile "ExportSpec.xlsx" -Server "localhost" -Database "MyDB" -Username "sa" -Password "P@ssw0rd"
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

        [string]$PostInstallScripts
    )

    # Set verbose logging flag
    $script:VerboseLogging = ($PSCmdlet.MyInvocation.BoundParameters['Verbose'] -eq $true) -or ($VerbosePreference -eq 'Continue')

    # Clear previous summary
    Clear-ImportSummary

    # Build connection string
    $connectionString = New-SqlConnectionString -Server $Server -Database $Database -Username $Username -Password $Password
    Write-Verbose "Connection string built for Server: $Server, Database: $Database"

    try {
        Write-ImportLog "Starting SQL Server data import process" -Level "INFO"

        # Validate Excel specification file
        $excelPath = Join-Path $DataFolder $ExcelSpecFile
        Test-ImportPath -Path $excelPath -PathType File -ThrowOnError

        # Find prefix and validate connection
        $prefix = Get-DataPrefix -FolderPath $DataFolder

        if (-not (Test-DatabaseConnection -ConnectionString $connectionString)) {
            throw "Database connection test failed"
        }

        # Determine schema name
        if (-not $SchemaName) {
            $SchemaName = $prefix
        }

        # Validate schema name
        Test-SchemaName -SchemaName $SchemaName -ThrowOnError

        # Create schema
        New-DatabaseSchema -ConnectionString $connectionString -SchemaName $SchemaName

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
            $tableExists = Test-TableExists -ConnectionString $connectionString -SchemaName $SchemaName -TableName $tableName

            if ($tableExists) {
                switch ($TableExistsAction) {
                    "Skip" {
                        Write-Host "Skipping existing table '$tableName'" -ForegroundColor Yellow
                        continue
                    }
                    "Truncate" {
                        Clear-DatabaseTable -ConnectionString $connectionString -SchemaName $SchemaName -TableName $tableName
                    }
                    "Recreate" {
                        Remove-DatabaseTable -ConnectionString $connectionString -SchemaName $SchemaName -TableName $tableName
                        New-DatabaseTable -ConnectionString $connectionString -SchemaName $SchemaName -TableName $tableName -Fields $tableFields
                    }
                }
            }
            else {
                New-DatabaseTable -ConnectionString $connectionString -SchemaName $SchemaName -TableName $tableName -Fields $tableFields
            }

            # Import data
            $rowsImported = Import-DataFile -ConnectionString $connectionString -SchemaName $SchemaName -TableName $tableName -FilePath $datFile.FullName -Fields $tableFields

            Add-ImportSummary -TableName $tableName -RowCount $rowsImported -FileName $datFile.Name
        }

        # Display summary
        Show-ImportSummary -SchemaName $SchemaName

        Write-ImportLog "Import process completed successfully" -Level "SUCCESS"

        # Execute post-install scripts if specified
        if (-not [string]::IsNullOrWhiteSpace($PostInstallScripts)) {
            Write-Host "`n=== Post-Install Scripts ===" -ForegroundColor Cyan
            Write-Verbose "Post-install scripts path: $PostInstallScripts"

            try {
                Invoke-PostInstallScripts -ScriptPath $PostInstallScripts -ConnectionString $connectionString -DatabaseName $Database -SchemaName $SchemaName
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
