function Add-DataTableRows {
    <#
    .SYNOPSIS
    Populates DataTable with records from DAT file.

    .DESCRIPTION
    Adds rows to DataTable with type conversion for each field.
    First field is ImportID, remaining fields match specification order.

    .PARAMETER DataTable
    DataTable to populate.

    .PARAMETER Records
    Array of records from Read-DatFileLines.

    .PARAMETER Fields
    Field specifications.

    .PARAMETER TableName
    Table name (for error reporting context).

    .EXAMPLE
    Add-DataTableRows -DataTable $dt -Records $records -Fields $fields -TableName "Employee"
    #>
    [CmdletBinding()]
    param(
        [Parameter(Mandatory=$true)]
        [System.Data.DataTable]$DataTable,

        [Parameter(Mandatory=$true)]
        [array]$Records,

        [Parameter(Mandatory=$true)]
        [array]$Fields,

        [Parameter(Mandatory=$false)]
        [string]$TableName
    )

    # Progress reporting configuration
    $progressInterval = 10000  # Report progress every N rows

    Write-Verbose "Populating DataTable with $($Records.Count) records"

    $rowCount = 0
    foreach ($record in $Records) {
        $dataRow = $DataTable.NewRow()
        $values = $record.Values

        # First field is always ImportID
        $dataRow["ImportID"] = $values[0].Trim()

        # Remaining fields map to specification fields
        for ($i = 0; $i -lt $Fields.Count; $i++) {
            $value = $values[$i + 1].Trim()
            $fieldName = $Fields[$i].'Column name'
            $columnType = $DataTable.Columns[$fieldName].DataType

            # Use centralized type conversion with error handling
            try {
                $convertParams = @{
                    Value = $value
                    TargetType = $columnType
                    FieldName = $fieldName
                    LineNumber = $record.LineNumber
                }
                if ($TableName) {
                    $convertParams.TableName = $TableName
                }
                $dataRow[$fieldName] = ConvertTo-TypedValue @convertParams
            }
            catch {
                Write-Error $_.Exception.Message
                throw  # Re-throw to halt import on data quality issues
            }
        }

        $DataTable.Rows.Add($dataRow)
        $rowCount++

        if ($rowCount % $progressInterval -eq 0) {
            Write-Host "  Processed $rowCount rows..." -ForegroundColor Gray
        }
    }

    Write-Verbose "Populated $rowCount rows in DataTable"
}
