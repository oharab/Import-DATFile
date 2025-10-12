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
        # Extract server and database from connection string for context
        $connBuilder = New-Object System.Data.SqlClient.SqlConnectionStringBuilder($ConnectionString)
        $server = $connBuilder.DataSource
        $database = $connBuilder.InitialCatalog
        $username = $connBuilder.UserID

        # Build context for guidance
        $context = @{
            Server = $server
            Database = $database
        }
        if ($username) {
            $context.Username = $username
        }

        # Get detailed guidance
        $guidance = Get-DatabaseErrorGuidance -Operation "Connection" -ErrorMessage $_.Exception.Message -Context $context

        Write-Error $guidance
        return $false
    }
}
