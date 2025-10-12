function Show-ImportSummary {
    <#
    .SYNOPSIS
    Displays import summary.

    .PARAMETER SchemaName
    Schema name for display.

    .EXAMPLE
    Show-ImportSummary -SchemaName "dbo"
    #>
    [CmdletBinding()]
    param(
        [Parameter(Mandatory=$true)]
        [string]$SchemaName
    )

    Write-Debug "Generating import summary"
    Write-Host "`n=== Import Summary ===" -ForegroundColor Cyan

    if ($script:ImportSummary.Count -eq 0) {
        Write-Host "No tables were imported." -ForegroundColor Yellow
        Write-Warning "No tables were imported"
        return
    }

    Write-Host "`nImported Tables:" -ForegroundColor Green
    Write-Host "Schema: $SchemaName" -ForegroundColor White
    Write-Host "=" * 50 -ForegroundColor Gray

    $totalRows = 0
    $summaryData = @()

    foreach ($item in $script:ImportSummary) {
        $tableDisplay = "[$SchemaName].[$($item.TableName)]"
        $rowDisplay = "{0:N0}" -f $item.RowCount
        $summaryData += [PSCustomObject]@{
            Table = $tableDisplay
            Rows = $rowDisplay
        }
        $totalRows += $item.RowCount
    }

    # Display in formatted table (pipe to Out-Host to prevent output stream pollution)
    $summaryData | Format-Table -Property @{
        Label = "Table Name"
        Expression = { $_.Table }
        Width = 35
    }, @{
        Label = "Rows Imported"
        Expression = { $_.Rows }
        Width = 15
        Alignment = "Right"
    } -AutoSize | Out-Host

    Write-Host "=" * 50 -ForegroundColor Gray
    Write-Host "Total Tables Imported: $($script:ImportSummary.Count)" -ForegroundColor Green
    Write-Host "Total Rows Imported: $("{0:N0}" -f $totalRows)" -ForegroundColor Green
    Write-Debug "Import summary completed - $($script:ImportSummary.Count) tables, $totalRows total rows"
}
