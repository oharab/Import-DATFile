function Add-ImportSummary {
    <#
    .SYNOPSIS
    Adds table to import summary.

    .PARAMETER TableName
    Table name.

    .PARAMETER RowCount
    Number of rows imported.

    .PARAMETER FileName
    Source file name.

    .EXAMPLE
    Add-ImportSummary -TableName "Employee" -RowCount 1000 -FileName "Employee.dat"
    #>
    [CmdletBinding()]
    param(
        [Parameter(Mandatory=$true)]
        [string]$TableName,

        [Parameter(Mandatory=$true)]
        [int]$RowCount,

        [Parameter(Mandatory=$true)]
        [string]$FileName
    )

    $script:ImportSummary += [PSCustomObject]@{
        TableName = $TableName
        RowCount = $RowCount
        FileName = $FileName
    }
}
