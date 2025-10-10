function Invoke-SqlBulkCopy {
    <#
    .SYNOPSIS
    Performs SqlBulkCopy operation.

    .DESCRIPTION
    Executes high-performance bulk copy from DataTable to SQL Server table.

    .PARAMETER DataTable
    DataTable containing data to import.

    .PARAMETER ConnectionString
    SQL Server connection string.

    .PARAMETER SchemaName
    Schema name.

    .PARAMETER TableName
    Destination table name.

    .EXAMPLE
    $rowCount = Invoke-SqlBulkCopy -DataTable $dt -ConnectionString $conn -SchemaName "dbo" -TableName "Employee"
    #>
    [CmdletBinding()]
    [OutputType([int])]
    param(
        [Parameter(Mandatory=$true)]
        [System.Data.DataTable]$DataTable,

        [Parameter(Mandatory=$true)]
        [ValidateNotNullOrEmpty()]
        [string]$ConnectionString,

        [Parameter(Mandatory=$true)]
        [ValidatePattern('^[a-zA-Z0-9_]+$')]
        [string]$SchemaName,

        [Parameter(Mandatory=$true)]
        [ValidateNotNullOrEmpty()]
        [string]$TableName
    )

    Write-Verbose "Starting SqlBulkCopy operation to [$SchemaName].[$TableName]"

    try {
        $connection = New-Object System.Data.SqlClient.SqlConnection($ConnectionString)
        $connection.Open()

        $bulkCopy = New-Object System.Data.SqlClient.SqlBulkCopy($connection)
        $bulkCopy.DestinationTableName = "[$SchemaName].[$TableName]"
        $bulkCopy.BatchSize = $script:BULK_COPY_BATCH_SIZE
        $bulkCopy.BulkCopyTimeout = $script:BULK_COPY_TIMEOUT_SECONDS

        Write-Debug "Setting up column mappings for $($DataTable.Columns.Count) columns"

        # Map each column from DataTable to SQL table
        foreach ($column in $DataTable.Columns) {
            $columnName = $column.ColumnName
            Write-Debug "Mapping column: $columnName (Type: $($column.DataType.Name))"
            $bulkCopy.ColumnMappings.Add($columnName, $columnName) | Out-Null
        }

        Write-Host "Starting bulk copy operation..." -ForegroundColor Yellow
        $bulkCopy.WriteToServer($DataTable)

        $bulkCopy.Close()
        $connection.Close()

        $rowCount = $DataTable.Rows.Count
        Write-Host "Successfully imported $rowCount rows into [$SchemaName].[$TableName]" -ForegroundColor Green
        Write-Verbose "Successfully imported $rowCount rows into [$SchemaName].[$TableName]"

        return $rowCount
    }
    catch {
        Write-Error "Bulk copy failed: $($_.Exception.Message)"
        Write-Host "`nBulk Copy Error Details:" -ForegroundColor Red
        Write-Host "Table: [$SchemaName].[$TableName]" -ForegroundColor Red
        Write-Host "DataTable Columns: $($DataTable.Columns.Count)" -ForegroundColor Red
        Write-Host "Column Names: $($DataTable.Columns.ColumnName -join ', ')" -ForegroundColor Red
        Write-Host "Error: $($_.Exception.Message)" -ForegroundColor Red

        if ($_.Exception.InnerException) {
            Write-Host "Inner Exception: $($_.Exception.InnerException.Message)" -ForegroundColor Red
        }

        if ($connection.State -eq 'Open') {
            $connection.Close()
        }
        throw
    }
    finally {
        if ($DataTable) {
            $DataTable.Dispose()
        }
    }
}
