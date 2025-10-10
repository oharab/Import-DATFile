function Get-DataPrefix {
    <#
    .SYNOPSIS
    Detects data file prefix from Employee.dat file.

    .DESCRIPTION
    Scans folder for *Employee.dat file and extracts prefix.
    Requires exactly one Employee.dat file for unique prefix detection.

    .PARAMETER FolderPath
    Folder containing data files.

    .EXAMPLE
    $prefix = Get-DataPrefix -FolderPath "C:\Data"
    #>
    [CmdletBinding()]
    [OutputType([string])]
    param(
        [Parameter(Mandatory=$true)]
        [ValidateScript({ Test-Path $_ -PathType Container })]
        [string]$FolderPath
    )

    Write-Verbose "Starting prefix detection in folder: $FolderPath"
    Write-Host "`nDetecting data prefix from Employee.dat file..." -ForegroundColor Yellow

    $employeeFiles = Get-ChildItem -Path $FolderPath -Name "*Employee.dat"

    if ($employeeFiles.Count -eq 0) {
        Write-Error "No *Employee.dat file found in $FolderPath"
        throw "No *Employee.dat file found. Cannot determine prefix."
    }

    if ($employeeFiles.Count -gt 1) {
        Write-Error "Multiple Employee.dat files found, cannot determine unique prefix"
        Write-Warning "Multiple Employee.dat files found:"
        $employeeFiles | ForEach-Object {
            Write-Host "  $_"
        }
        throw "Cannot uniquely determine prefix. Multiple Employee.dat files found."
    }

    # Get the first (and only) employee file
    if ($employeeFiles -is [array]) {
        $employeeFile = $employeeFiles[0]
    } else {
        $employeeFile = $employeeFiles
    }

    # Extract prefix by removing "Employee.dat" from the end (case-insensitive)
    $prefix = $employeeFile -replace "(?i)Employee\.dat$", ""

    Write-Host "Prefix detected: '$prefix' (from $employeeFile)" -ForegroundColor Green
    Write-Verbose "Prefix detection successful - File: $employeeFile, Prefix: '$prefix'"

    return $prefix
}
