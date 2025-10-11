function Get-DatabaseNameFromConnectionString {
    <#
    .SYNOPSIS
    Extracts database name from a connection string.

    .DESCRIPTION
    Parses a SQL Server connection string to extract the database name.
    Supports both "Database=" and "Initial Catalog=" keywords.

    .PARAMETER ConnectionString
    SQL Server connection string.

    .EXAMPLE
    Get-DatabaseNameFromConnectionString -ConnectionString "Server=localhost;Database=MyDB;Integrated Security=True;"
    # Returns: MyDB
    #>
    [CmdletBinding()]
    [OutputType([string])]
    param(
        [Parameter(Mandatory=$true)]
        [ValidateNotNullOrEmpty()]
        [string]$ConnectionString
    )

    if ($ConnectionString -match "Database=([^;]+)") {
        return $Matches[1]
    }
    elseif ($ConnectionString -match "Initial Catalog=([^;]+)") {
        return $Matches[1]
    }
    else {
        Write-Warning "Could not extract database name from connection string"
        return $null
    }
}
