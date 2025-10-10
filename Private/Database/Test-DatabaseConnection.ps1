function Test-DatabaseConnection {
    <#
    .SYNOPSIS
    Tests SQL Server database connection.

    .DESCRIPTION
    Attempts to open and close a connection to verify connectivity.

    .PARAMETER ConnectionString
    SQL Server connection string.

    .EXAMPLE
    if (Test-DatabaseConnection -ConnectionString $connStr) {
        Write-Host "Connected successfully"
    }
    #>
    [CmdletBinding()]
    [OutputType([bool])]
    param(
        [Parameter(Mandatory=$true)]
        [ValidateNotNullOrEmpty()]
        [string]$ConnectionString
    )

    try {
        $connection = New-Object System.Data.SqlClient.SqlConnection($ConnectionString)
        $connection.Open()
        $connection.Close()
        Write-ImportLog "Database connection test successful" -Level "SUCCESS"
        return $true
    }
    catch {
        Write-Error "Database connection failed: $($_.Exception.Message)"
        return $false
    }
}
