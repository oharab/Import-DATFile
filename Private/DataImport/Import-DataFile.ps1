function Import-DataFile {
    <#
    .SYNOPSIS
    Imports data from DAT file into SQL Server table.

    .DESCRIPTION
    Orchestrates the import process: reads file, creates DataTable,
    populates rows with type conversion, and performs bulk copy.
    This function follows Single Responsibility Principle by delegating
    to specialized functions.

    .PARAMETER ConnectionString
    SQL Server connection string.

    .PARAMETER SchemaName
    Schema name.

    .PARAMETER TableName
    Table name.

    .PARAMETER FilePath
    Path to DAT file.

    .PARAMETER Fields
    Field specifications from Excel.

    .EXAMPLE
    $count = Import-DataFile -ConnectionString $conn -SchemaName "dbo" -TableName "Employee" -FilePath "C:\Data\Employee.dat" -Fields $fields
    #>
    [CmdletBinding(SupportsShouldProcess=$true)]
    [OutputType([int])]
    param(
        [Parameter(Mandatory=$true)]
        [ValidateNotNullOrEmpty()]
        [string]$ConnectionString,

        [Parameter(Mandatory=$true)]
        [ValidatePattern('^[a-zA-Z0-9_]+$')]
        [string]$SchemaName,

        [Parameter(Mandatory=$true)]
        [ValidateNotNullOrEmpty()]
        [string]$TableName,

        [Parameter(Mandatory=$true)]
        [ValidateScript({ Test-Path $_ -PathType Leaf })]
        [string]$FilePath,

        [Parameter(Mandatory=$true)]
        [array]$Fields
    )

    $fileName = [System.IO.Path]::GetFileName($FilePath)
    Write-Verbose "Starting data import for table [$SchemaName].[$TableName] from file: $fileName"
    Write-Host "Importing $fileName..." -ForegroundColor Yellow

    # Expected field count = ImportID + spec fields
    $expectedFieldCount = $Fields.Count + 1

    # Step 1: Read file with multi-line support
    $records = Read-DatFileLines -FilePath $FilePath -ExpectedFieldCount $expectedFieldCount

    if ($records.Count -eq 0) {
        Write-Warning "No records to import from $fileName"
        return 0
    }

    # Step 2: Create DataTable structure
    $dataTable = New-ImportDataTable -Fields $Fields

    # Step 3: Populate DataTable with type conversion (pass TableName for error context)
    Add-DataTableRows -DataTable $dataTable -Records $records -Fields $Fields -TableName $TableName

    # Step 4: Perform bulk copy (or skip if WhatIf)
    if ($PSCmdlet.ShouldProcess("[$SchemaName].[$TableName]", "Import $($records.Count) rows from $fileName")) {
        $rowCount = Invoke-SqlBulkCopy -DataTable $dataTable -ConnectionString $ConnectionString -SchemaName $SchemaName -TableName $TableName
        return $rowCount
    }
    else {
        # WhatIf mode
        Write-Host "What if: Would import $($records.Count) rows from $fileName into [$SchemaName].[$TableName]" -ForegroundColor Cyan
        Write-Host "  File parsed successfully: $($records.Count) rows would be imported" -ForegroundColor Gray
        return $records.Count
    }
}
