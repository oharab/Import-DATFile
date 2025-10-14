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

        # Build normalized specs
        $specs = @()
        for ($i = 1; $i -lt $rawData.Count; $i++) {
            $row = $rawData[$i]
            $values = $row.PSObject.Properties.Value

            # Skip empty rows
            if ([string]::IsNullOrWhiteSpace($values[0])) {
                continue
            }

            # Create normalized object using standard property names
            $spec = [PSCustomObject]@{
                'Table name' = $values[0]
                'Column name' = $values[1]
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
