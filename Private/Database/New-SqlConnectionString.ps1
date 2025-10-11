function New-SqlConnectionString {
    <#
    .SYNOPSIS
    Builds a SQL Server connection string with Windows or SQL authentication.

    .DESCRIPTION
    Centralizes connection string building logic to ensure consistency.
    Supports both Windows Authentication (Integrated Security) and
    SQL Server Authentication (username/password).

    .PARAMETER Server
    SQL Server instance name (e.g., "localhost", "server\instance").

    .PARAMETER Database
    Database name.

    .PARAMETER Username
    SQL Server authentication username. If not provided, Windows Authentication is used.

    .PARAMETER Password
    SQL Server authentication password. Required when Username is provided.

    .EXAMPLE
    New-SqlConnectionString -Server "localhost" -Database "MyDB"
    # Returns: Server=localhost;Database=MyDB;Integrated Security=True;

    .EXAMPLE
    New-SqlConnectionString -Server "localhost" -Database "MyDB" -Username "sa" -Password "P@ssw0rd"
    # Returns: Server=localhost;Database=MyDB;User Id=sa;Password=P@ssw0rd;
    #>
    [CmdletBinding()]
    [OutputType([string])]
    param(
        [Parameter(Mandatory=$true)]
        [ValidateNotNullOrEmpty()]
        [string]$Server,

        [Parameter(Mandatory=$true)]
        [ValidateNotNullOrEmpty()]
        [string]$Database,

        [Parameter(Mandatory=$false)]
        [string]$Username,

        [Parameter(Mandatory=$false)]
        [string]$Password
    )

    if (-not [string]::IsNullOrWhiteSpace($Username)) {
        # SQL Server Authentication
        if ([string]::IsNullOrWhiteSpace($Password)) {
            throw "Password is required when using SQL Server Authentication"
        }

        Write-Verbose "Building connection string with SQL Server Authentication"
        return "Server=$Server;Database=$Database;User Id=$Username;Password=$Password;"
    }
    else {
        # Windows Authentication
        Write-Verbose "Building connection string with Windows Authentication"
        return "Server=$Server;Database=$Database;Integrated Security=True;"
    }
}
