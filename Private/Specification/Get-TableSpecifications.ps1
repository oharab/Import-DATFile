function Get-TableSpecifications {
    <#
    .SYNOPSIS
    Reads table specifications from Excel file.

    .DESCRIPTION
    Imports field specifications from Excel file that define table structure.

    .PARAMETER ExcelPath
    Path to Excel specification file.

    .EXAMPLE
    $specs = Get-TableSpecifications -ExcelPath "C:\Data\ExportSpec.xlsx"
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
        $specs = Import-Excel -Path $ExcelPath
        Write-Host "Successfully read $($specs.Count) field specifications" -ForegroundColor Green
        Write-Verbose "Successfully read $($specs.Count) field specifications from Excel"
        return $specs
    }
    catch {
        Write-Error "Failed to read Excel file: $($_.Exception.Message)"
        throw "Failed to read Excel file: $($_.Exception.Message)"
    }
}
