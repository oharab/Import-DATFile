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

    .EXAMPLE
    Add-DataTableRows -DataTable $dt -Records $records -Fields $fields
    #>
    [CmdletBinding()]
    param(
        [Parameter(Mandatory=$true)]
        [System.Data.DataTable]$DataTable,

        [Parameter(Mandatory=$true)]
        [array]$Records,

        [Parameter(Mandatory=$true)]
        [array]$Fields
    )

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

            # Use centralized type conversion
            $dataRow[$fieldName] = ConvertTo-TypedValue -Value $value -TargetType $columnType -FieldName $fieldName -LineNumber $record.LineNumber
        }

        $DataTable.Rows.Add($dataRow)
        $rowCount++

        if ($rowCount % $script:PROGRESS_REPORT_INTERVAL -eq 0) {
            Write-Host "  Processed $rowCount rows..." -ForegroundColor Gray
        }
    }

    Write-Verbose "Populated $rowCount rows in DataTable"
}
