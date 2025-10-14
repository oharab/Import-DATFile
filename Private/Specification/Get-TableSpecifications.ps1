function Get-TableSpecifications {
    <#
    .SYNOPSIS
    Reads table specifications from Excel file using column indices.

    .DESCRIPTION
    Imports field specifications from Excel file that define table structure.
    Uses column positions (indices) rather than header names to avoid issues
    with typos or variations in Excel column headers.

    Expected Excel column order:
    1. Table name (required)
    2. Column name (required)
    3. Data type (required)
    4. Precision (optional)
    5. Scale (optional)

    The actual header names in the Excel file don't matter - only the column
    order is important. This makes the importer resilient to header typos
    like "Precison" vs "Precision".

    Duplicate column names within the same table are automatically renamed by
    appending ".N" where N is a sequential counter (e.g., MemberName, MemberName.1, MemberName.2).

    .PARAMETER ExcelPath
    Path to Excel specification file.

    .EXAMPLE
    $specs = Get-TableSpecifications -ExcelPath "C:\Data\ExportSpec.xlsx"

    .NOTES
    Returns normalized objects with standard property names:
    'Table name', 'Column name', 'Data type', 'Precision', 'Scale'
    #>
    [CmdletBinding()]
    [OutputType([array])]
    param(
        [Parameter(Mandatory=$true)]
        [ValidateScript({ Test-Path $_ -PathType Leaf })]
        [string]$ExcelPath
    )

    Write-Verbose "Reading table specifications from Excel: $ExcelPath"
    Write-Host "`nReading table specifications from Excel..." -ForegroundColor Yellow

    try {
        # Import Excel file without headers to get raw data
        $rawData = Import-Excel -Path $ExcelPath -NoHeader

        if ($rawData.Count -eq 0) {
            throw "Excel file is empty"
        }

        # First row contains headers (use indices to avoid typo issues)
        $headers = $rawData[0].PSObject.Properties.Value

        # Validate we have at least 3 columns (Table name, Column name, Data type)
        if ($headers.Count -lt 3) {
            throw "Excel file must have at least 3 columns: Table name, Column name, Data type"
        }

        # Normalize headers to standard names using column positions
        # Expected order: TableName, ColumnName, DataType, Precision, Scale
        $standardHeaders = @('Table name', 'Column name', 'Data type', 'Precision', 'Scale')

        # Build normalized specs with duplicate column name handling
        $specs = @()
        $columnNameCounters = @{}  # Track column name usage per table: "TableName|ColumnName" -> count

        for ($i = 1; $i -lt $rawData.Count; $i++) {
            $row = $rawData[$i]
            $values = $row.PSObject.Properties.Value

            # Skip empty rows
            if ([string]::IsNullOrWhiteSpace($values[0])) {
                continue
            }

            $tableName = $values[0]
            $columnName = $values[1]

            # Handle duplicate column names by appending .N
            $fieldKey = "$tableName|$columnName"
            if ($columnNameCounters.ContainsKey($fieldKey)) {
                # Duplicate found - append counter
                $counter = $columnNameCounters[$fieldKey]
                $originalColumnName = $columnName
                $columnName = "$columnName.$counter"
                $columnNameCounters[$fieldKey] = $counter + 1

                Write-Warning "Row $($i + 1) - Duplicate column name '$originalColumnName' in table '$tableName'. Renamed to '$columnName'"
            }
            else {
                # First occurrence
                $columnNameCounters[$fieldKey] = 1
            }

            # Create normalized object using standard property names
            $spec = [PSCustomObject]@{
                'Table name' = $tableName
                'Column name' = $columnName  # May have .N suffix for duplicates
                'Data type' = $values[2]
                'Precision' = if ($values.Count -gt 3) { $values[3] } else { $null }
                'Scale' = if ($values.Count -gt 4) { $values[4] } else { $null }
            }

            $specs += $spec
        }

        Write-Host "Successfully read $($specs.Count) field specifications" -ForegroundColor Green
        Write-Verbose "Successfully read $($specs.Count) field specifications from Excel"
        return $specs
    }
    catch {
        Write-Error "Failed to read Excel file: $($_.Exception.Message)"
        throw "Failed to read Excel file: $($_.Exception.Message)"
    }
}
