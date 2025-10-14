function Test-ExcelSpecification {
    <#
    .SYNOPSIS
    Validates Excel specification file for correctness and completeness.

    .DESCRIPTION
    Performs comprehensive validation of Excel specification:
    - Checks required columns exist
    - Validates data types are supported
    - Validates field/table names are SQL-safe
    - Checks for duplicate field definitions
    - Validates precision/scale values
    - Provides detailed error messages with line numbers

    .PARAMETER Specifications
    Array of specification objects from Excel file.

    .PARAMETER ThrowOnError
    If specified, throws an exception on first validation error.
    Otherwise, returns validation results object.

    .EXAMPLE
    $specs = Import-Excel "ExportSpec.xlsx"
    $result = Test-ExcelSpecification -Specifications $specs
    if (-not $result.IsValid) {
        $result.Errors | ForEach-Object { Write-Warning $_ }
    }

    .EXAMPLE
    Test-ExcelSpecification -Specifications $specs -ThrowOnError

    .OUTPUTS
    Hashtable with keys:
    - IsValid: Boolean indicating if specification is valid
    - Errors: Array of error messages
    - Warnings: Array of warning messages
    #>
    [CmdletBinding()]
    [OutputType([hashtable])]
    param(
        [Parameter(Mandatory=$true)]
        [AllowEmptyCollection()]
        [array]$Specifications,

        [Parameter(Mandatory=$false)]
        [switch]$ThrowOnError
    )

    $errors = @()
    $warnings = @()

    # Check if specifications array is empty
    if ($Specifications.Count -eq 0) {
        $errors += "Excel specification file is empty or contains no data rows"
        if ($ThrowOnError) {
            throw ($errors -join "`n")
        }
        return @{
            IsValid = $false
            Errors = $errors
            Warnings = $warnings
        }
    }

    # Required columns
    $requiredColumns = @('Table name', 'Column name', 'Data type')

    # Check that first specification has all required columns
    $firstSpec = $Specifications[0]
    $missingColumns = $requiredColumns | Where-Object { -not ($firstSpec.PSObject.Properties.Name -contains $_) }

    if ($missingColumns.Count -gt 0) {
        $errors += "Excel specification file is missing required columns: $($missingColumns -join ', ')"
        $errors += "Required columns: $($requiredColumns -join ', ')"
        if ($ThrowOnError) {
            throw ($errors -join "`n")
        }
        return @{
            IsValid = $false
            Errors = $errors
            Warnings = $warnings
        }
    }

    # Valid SQL Server data types (simplified list - commonly used types)
    $validDataTypes = @(
        'VARCHAR', 'NVARCHAR', 'CHAR', 'NCHAR', 'TEXT', 'NTEXT',
        'INT', 'BIGINT', 'SMALLINT', 'TINYINT',
        'DECIMAL', 'NUMERIC', 'MONEY', 'SMALLMONEY', 'FLOAT', 'REAL',
        'BIT',
        'DATE', 'DATETIME', 'DATETIME2', 'SMALLDATETIME', 'TIME', 'DATETIMEOFFSET',
        'UNIQUEIDENTIFIER',
        'BINARY', 'VARBINARY', 'IMAGE'
    )

    # Track seen fields to detect duplicates
    $seenFields = @{}

    # Validate each specification
    for ($i = 0; $i -lt $Specifications.Count; $i++) {
        $spec = $Specifications[$i]
        $rowNum = $i + 2  # Excel row number (1-indexed + header row)

        $tableName = $spec.'Table name'
        $columnName = $spec.'Column name'
        $dataType = $spec.'Data type'
        $precision = $spec.Precision
        $scale = $spec.Scale

        # Validate Table name is not empty
        if ([string]::IsNullOrWhiteSpace($tableName)) {
            $errors += "Row $rowNum - 'Table name' is empty or missing"
        }
        else {
            # Validate Table name is SQL-safe
            if ($tableName -notmatch '^[a-zA-Z0-9_]+$') {
                $errors += "Row $rowNum - Invalid table name '$tableName'. Table names must contain only letters, numbers, and underscores."
            }
        }

        # Validate Column name is not empty
        if ([string]::IsNullOrWhiteSpace($columnName)) {
            $errors += "Row $rowNum - 'Column name' is empty or missing"
        }
        else {
            # Validate Column name is SQL-safe
            if ($columnName -notmatch '^[a-zA-Z0-9_]+$') {
                $errors += "Row $rowNum - Invalid column name '$columnName'. Column names must contain only letters, numbers, and underscores."
            }

            # Check for reserved SQL keywords (common ones)
            $reservedKeywords = @('SELECT', 'INSERT', 'UPDATE', 'DELETE', 'FROM', 'WHERE', 'ORDER', 'GROUP', 'TABLE', 'INDEX', 'KEY', 'PRIMARY', 'FOREIGN', 'UNIQUE', 'DEFAULT', 'CHECK', 'NULL', 'NOT', 'AND', 'OR', 'IN', 'BETWEEN', 'LIKE', 'IS', 'EXISTS', 'ALL', 'ANY', 'SOME', 'UNION', 'INTERSECT', 'EXCEPT')
            if ($reservedKeywords -contains $columnName.ToUpper()) {
                $warnings += "Row $rowNum - Column name '$columnName' is a SQL reserved keyword. Consider using a different name or expect it to be quoted in queries."
            }

            # Check for duplicates within same table
            $fieldKey = "$tableName|$columnName"
            if ($seenFields.ContainsKey($fieldKey)) {
                $errors += "Row $rowNum - Duplicate field definition for table '$tableName', column '$columnName'. First defined at row $($seenFields[$fieldKey])."
            }
            else {
                $seenFields[$fieldKey] = $rowNum
            }
        }

        # Validate Data type
        if ([string]::IsNullOrWhiteSpace($dataType)) {
            $errors += "Row $rowNum - 'Data type' is empty or missing"
        }
        else {
            $dataTypeUpper = $dataType.ToUpper().Trim()
            if ($validDataTypes -notcontains $dataTypeUpper) {
                $errors += "Row $rowNum - Invalid data type '$dataType'. Supported types - $($validDataTypes -join ', ')"
            }

            # Validate Precision is provided for types that strictly require it
            # Note: VARCHAR, CHAR can use defaults (VARCHAR(MAX), CHAR(10))
            # DECIMAL/NUMERIC should have precision specified for data integrity
            $typesStrictlyRequiringPrecision = @('DECIMAL', 'NUMERIC')
            if ($typesStrictlyRequiringPrecision -contains $dataTypeUpper) {
                if ($null -eq $precision -or $precision -eq '' -or $precision -eq 0) {
                    $errors += "Row $rowNum - Data type '$dataType' requires a valid 'Precision' value (e.g., 18 for DECIMAL(18,2) with Scale=2)"
                }
            }

            # Validate Precision if provided (for any type that supports it)
            $typesAcceptingPrecision = @('VARCHAR', 'NVARCHAR', 'CHAR', 'NCHAR', 'BINARY', 'VARBINARY', 'DECIMAL', 'NUMERIC')
            if ($typesAcceptingPrecision -contains $dataTypeUpper) {
                if ($null -ne $precision -and $precision -ne '' -and $precision -ne 0) {
                    # Validate precision as integer
                    $precisionNum = 0
                    if (-not [int]::TryParse($precision.ToString().Trim(), [ref]$precisionNum)) {
                        $errors += "Row $rowNum - 'Precision' value '$precision' is not a valid integer"
                    }
                    else {
                        # Validate precision bounds based on type
                        if ($dataTypeUpper -in @('VARCHAR', 'NVARCHAR') -and $precisionNum -gt 8000) {
                            $warnings += "Row $rowNum - 'Precision' value $precisionNum for $dataType exceeds max (8000). Will use VARCHAR(MAX) instead."
                        }
                        elseif ($dataTypeUpper -in @('CHAR', 'NCHAR') -and $precisionNum -gt 8000) {
                            $errors += "Row $rowNum - 'Precision' value $precisionNum for $dataType exceeds max (8000)"
                        }
                        elseif ($dataTypeUpper -in @('DECIMAL', 'NUMERIC') -and $precisionNum -gt 38) {
                            $errors += "Row $rowNum - 'Precision' value $precisionNum for $dataType exceeds max (38)"
                        }
                    }
                }
            }

            # Validate Scale for DECIMAL/NUMERIC types (separate column)
            if ($dataTypeUpper -in @('DECIMAL', 'NUMERIC')) {
                if ($null -ne $scale -and $scale -ne '' -and $scale -ne 0) {
                    $scaleNum = 0
                    if (-not [int]::TryParse($scale.ToString().Trim(), [ref]$scaleNum)) {
                        $errors += "Row $rowNum - 'Scale' value '$scale' is not a valid integer"
                    }
                    elseif ($scaleNum -lt 0) {
                        $errors += "Row $rowNum - 'Scale' value must be >= 0"
                    }
                    elseif ($null -ne $precision -and $precision -ne '' -and $scaleNum -gt $precision) {
                        $errors += "Row $rowNum - 'Scale' ($scale) cannot exceed 'Precision' ($precision) for DECIMAL/NUMERIC"
                    }
                }
            }

            # Warn if precision is empty for string types (defaults will be used)
            if ($dataTypeUpper -in @('VARCHAR', 'NVARCHAR', 'CHAR', 'NCHAR')) {
                if ($null -eq $precision -or $precision -eq '' -or $precision -eq 0) {
                    $warnings += "Row $rowNum - No precision specified for $dataType. Will use default: VARCHAR/NVARCHAR=MAX, CHAR/NCHAR=10"
                }
            }
        }
    }

    # Build result
    $result = @{
        IsValid = ($errors.Count -eq 0)
        Errors = $errors
        Warnings = $warnings
    }

    # Throw if requested and invalid
    if ($ThrowOnError -and -not $result.IsValid) {
        $errorMessage = "Excel specification validation failed with $($errors.Count) error(s):`n" + ($errors -join "`n")
        throw $errorMessage
    }

    return $result
}
