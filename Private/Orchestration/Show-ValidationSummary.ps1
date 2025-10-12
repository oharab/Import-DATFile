function Show-ValidationSummary {
    <#
    .SYNOPSIS
    Displays comprehensive validation summary.

    .DESCRIPTION
    Shows validation results for all data files:
    - Tables validated successfully
    - Tables with validation errors
    - Total row counts
    - Detailed error messages

    .PARAMETER ValidationResults
    Array of validation result hashtables from Test-DataFileValidation.

    .PARAMETER SchemaName
    Schema name (for display).

    .EXAMPLE
    Show-ValidationSummary -ValidationResults $results -SchemaName "dbo"

    .OUTPUTS
    None. Displays formatted output to console.
    #>
    [CmdletBinding()]
    param(
        [Parameter(Mandatory=$true)]
        [array]$ValidationResults,

        [Parameter(Mandatory=$true)]
        [ValidatePattern('^[a-zA-Z0-9_]+$')]
        [string]$SchemaName
    )

    Write-Host "`n========================================" -ForegroundColor Cyan
    Write-Host "  VALIDATION SUMMARY" -ForegroundColor Cyan
    Write-Host "========================================" -ForegroundColor Cyan
    Write-Host "Schema: $SchemaName" -ForegroundColor Cyan

    # Separate valid and invalid results
    $validTables = @($ValidationResults | Where-Object { $_.IsValid })
    $invalidTables = @($ValidationResults | Where-Object { -not $_.IsValid })
    $totalRows = ($ValidationResults | Measure-Object -Property RowCount -Sum).Sum

    # Display valid tables
    if ($validTables.Count -gt 0) {
        Write-Host "`n✓ VALID TABLES ($($validTables.Count)):" -ForegroundColor Green
        foreach ($result in $validTables) {
            Write-Host "  • $($result.TableName): $($result.RowCount) rows" -ForegroundColor Green

            # Show warnings if any
            if ($result.Warnings.Count -gt 0) {
                foreach ($warning in $result.Warnings) {
                    Write-Host "    ⚠ $warning" -ForegroundColor Yellow
                }
            }
        }
    }

    # Display invalid tables
    if ($invalidTables.Count -gt 0) {
        Write-Host "`n✗ INVALID TABLES ($($invalidTables.Count)):" -ForegroundColor Red
        foreach ($result in $invalidTables) {
            Write-Host "  • $($result.TableName): VALIDATION FAILED" -ForegroundColor Red

            # Show all errors
            foreach ($error in $result.Errors) {
                Write-Host "    ✗ $error" -ForegroundColor Red
            }
        }
    }

    # Display summary statistics
    Write-Host "`n========================================" -ForegroundColor Cyan
    Write-Host "Total Tables Validated: $($ValidationResults.Count)" -ForegroundColor White
    Write-Host "Valid Tables: $($validTables.Count)" -ForegroundColor Green
    Write-Host "Invalid Tables: $($invalidTables.Count)" -ForegroundColor Red
    Write-Host "Total Rows: $totalRows" -ForegroundColor White
    Write-Host "========================================" -ForegroundColor Cyan

    # Overall result
    if ($invalidTables.Count -eq 0) {
        Write-Host "`n✓ ALL VALIDATIONS PASSED" -ForegroundColor Green
        Write-Host "Your data is ready to import!" -ForegroundColor Green
    }
    else {
        Write-Host "`n✗ VALIDATION FAILED" -ForegroundColor Red
        Write-Host "Please fix the errors above before importing." -ForegroundColor Red
    }
}
