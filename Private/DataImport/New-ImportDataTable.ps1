function New-ImportDataTable {
    <#
    .SYNOPSIS
    Creates a DataTable structure for import operations.

    .DESCRIPTION
    Creates a System.Data.DataTable with ImportID as the first column,
    followed by columns from the field specification. Uses proper .NET
    types for each column based on SQL type mapping.

    .PARAMETER Fields
    Array of field specifications from Excel.

    .EXAMPLE
    $dataTable = New-ImportDataTable -Fields $tableFields
    #>
    [CmdletBinding()]
    [OutputType([System.Data.DataTable])]
    param(
        [Parameter(Mandatory=$true)]
        [array]$Fields
    )

    Write-Verbose "Creating DataTable structure with $($Fields.Count + 1) columns (including ImportID)"

    $dataTable = New-Object System.Data.DataTable

    # Add ImportID column first
    $importIdColumn = New-Object System.Data.DataColumn
    $importIdColumn.ColumnName = "ImportID"
    $importIdColumn.DataType = [System.String]
    $dataTable.Columns.Add($importIdColumn)

    # Add columns for each field from specification with proper data types
    foreach ($field in $Fields) {
        $column = New-Object System.Data.DataColumn
        $column.ColumnName = $field.'Column name'

        # Get SQL type and map to proper .NET type
        $sqlType = Get-SqlDataTypeMapping -ExcelType $field."Data type" -Precision $field.Precision
        $column.DataType = Get-DotNetDataType -SqlType $sqlType

        $dataTable.Columns.Add($column)
        Write-Verbose "Added column: $($column.ColumnName) (Type: $($column.DataType.Name))"
    }

    return $dataTable
}
