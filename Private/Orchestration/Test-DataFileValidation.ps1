function Test-DataFileValidation {
    <#
    .SYNOPSIS
    Validates a DAT file can be successfully imported without writing to database.

    .DESCRIPTION
    Performs dry-run validation of a data file:
    - Reads and parses DAT file
    - Validates field count matches specification
    - Tests type conversions for all fields
    - Reports validation errors without database operations

    .PARAMETER FilePath
    Path to DAT file to validate.

    .PARAMETER Fields
    Field specifications from Excel.

    .PARAMETER TableName
    Table name (for error context).

    .EXAMPLE
    $result = Test-DataFileValidation -FilePath "C:\Data\Employee.dat" -Fields $fields -TableName "Employee"

    .OUTPUTS
    Hashtable with keys: TableName, IsValid, RowCount, Errors, Warnings
    #>
    [CmdletBinding()]
    [OutputType([hashtable])]
    param(
        [Parameter(Mandatory=$true)]
        [ValidateScript({ Test-Path $_ -PathType Leaf })]
        [string]$FilePath,

        [Parameter(Mandatory=$true)]
        [array]$Fields,

        [Parameter(Mandatory=$true)]
        [ValidateNotNullOrEmpty()]
        [string]$TableName
    )

    $fileName = [System.IO.Path]::GetFileName($FilePath)
    Write-Host "Validating $fileName..." -ForegroundColor Yellow

    $validationErrors = @()
    $validationWarnings = @()
    $rowCount = 0

    try {
        # Expected field count = ImportID + spec fields
        $expectedFieldCount = $Fields.Count + 1

        # Step 1: Read file with multi-line support
        Write-Verbose "Reading and parsing DAT file: $fileName"
        $records = Read-DatFileLines -FilePath $FilePath -ExpectedFieldCount $expectedFieldCount

        if ($records.Count -eq 0) {
            $validationWarnings += "No records found in file"
            return @{
                TableName = $TableName
                IsValid = $true
                RowCount = 0
                Errors = $validationErrors
                Warnings = $validationWarnings
            }
        }

        $rowCount = $records.Count
        Write-Verbose "Successfully parsed $rowCount records from $fileName"

        # Step 2: Create DataTable structure to validate field mappings
        Write-Verbose "Creating DataTable structure for validation"
        $dataTable = New-ImportDataTable -Fields $Fields

        # Step 3: Validate type conversions without inserting data
        Write-Verbose "Validating type conversions for $rowCount records"
        try {
            Add-DataTableRows -DataTable $dataTable -Records $records -Fields $Fields -TableName $TableName
            Write-Host "  ✓ Successfully validated $rowCount rows" -ForegroundColor Green
        }
        catch {
            # Capture type conversion errors
            $validationErrors += $_.Exception.Message
            Write-Host "  ✗ Validation failed: $($_.Exception.Message)" -ForegroundColor Red
        }

        # Return validation result
        return @{
            TableName = $TableName
            IsValid = ($validationErrors.Count -eq 0)
            RowCount = $rowCount
            Errors = $validationErrors
            Warnings = $validationWarnings
        }
    }
    catch {
        # Capture parsing errors
        $validationErrors += "Failed to parse file: $($_.Exception.Message)"
        Write-Host "  ✗ Parse error: $($_.Exception.Message)" -ForegroundColor Red

        return @{
            TableName = $TableName
            IsValid = $false
            RowCount = $rowCount
            Errors = $validationErrors
            Warnings = $validationWarnings
        }
    }
}
