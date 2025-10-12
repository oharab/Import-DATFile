# DatabaseHelpers.ps1
# Test helper functions for database operations in integration tests

function Initialize-TestDatabase {
    <#
    .SYNOPSIS
    Creates a temporary test database using SQL LocalDB.

    .DESCRIPTION
    Creates and starts a LocalDB instance for integration testing.
    Returns connection string and database name for cleanup.

    .EXAMPLE
    $testDb = Initialize-TestDatabase
    # Use $testDb.ConnectionString for tests
    Remove-TestDatabase -DatabaseName $testDb.DatabaseName
    #>
    [CmdletBinding()]
    [OutputType([hashtable])]
    param()

    $testDbName = "ImportDATFile_Test_$(Get-Random -Minimum 10000 -Maximum 99999)"

    try {
        Write-Verbose "Creating LocalDB instance: $testDbName"
        sqllocaldb create $testDbName -ErrorAction Stop | Out-Null
        sqllocaldb start $testDbName -ErrorAction Stop | Out-Null

        $connString = "Server=(localdb)\$testDbName;Integrated Security=True;Database=master;"

        # Create test database
        $createDbQuery = "CREATE DATABASE [$testDbName]"
        Invoke-Sqlcmd -ConnectionString $connString -Query $createDbQuery -ErrorAction Stop

        $testConnString = "Server=(localdb)\$testDbName;Integrated Security=True;Database=$testDbName;"

        return @{
            ConnectionString = $testConnString
            DatabaseName = $testDbName
            InstanceName = $testDbName
        }
    }
    catch {
        Write-Warning "Failed to create test database: $($_.Exception.Message)"
        Write-Warning "Integration tests require SQL Server LocalDB. Install with: sqllocaldb create MSSQLLocalDB"
        throw
    }
}

function Remove-TestDatabase {
    <#
    .SYNOPSIS
    Removes a test database created by Initialize-TestDatabase.

    .PARAMETER DatabaseName
    Name of the test database to remove.

    .EXAMPLE
    Remove-TestDatabase -DatabaseName $testDb.DatabaseName
    #>
    [CmdletBinding()]
    param(
        [Parameter(Mandatory=$true)]
        [string]$DatabaseName
    )

    try {
        Write-Verbose "Stopping LocalDB instance: $DatabaseName"
        sqllocaldb stop $DatabaseName -ErrorAction SilentlyContinue | Out-Null

        Start-Sleep -Milliseconds 500

        Write-Verbose "Deleting LocalDB instance: $DatabaseName"
        sqllocaldb delete $DatabaseName -ErrorAction SilentlyContinue | Out-Null
    }
    catch {
        Write-Warning "Failed to remove test database: $($_.Exception.Message)"
    }
}

function Test-LocalDbAvailable {
    <#
    .SYNOPSIS
    Checks if SQL Server LocalDB is available.

    .DESCRIPTION
    Tests whether sqllocaldb command is available for integration tests.

    .EXAMPLE
    if (Test-LocalDbAvailable) {
        # Run integration tests
    }
    #>
    [CmdletBinding()]
    [OutputType([bool])]
    param()

    try {
        $null = sqllocaldb info 2>$null
        return $true
    }
    catch {
        return $false
    }
}

function Test-SqlServerAvailable {
    <#
    .SYNOPSIS
    Checks if a SQL Server instance is available and accepting connections.

    .DESCRIPTION
    Tests whether a SQL Server connection can be established.
    Used to conditionally run real SQL Server integration tests.

    .PARAMETER ServerName
    SQL Server instance name. Defaults to "localhost".

    .PARAMETER Database
    Database name to connect to. Defaults to "master".

    .PARAMETER TimeoutSeconds
    Connection timeout in seconds. Defaults to 2.

    .EXAMPLE
    if (Test-SqlServerAvailable -ServerName "localhost") {
        # Run real SQL Server tests
    }

    .EXAMPLE
    $hasLocalDb = Test-SqlServerAvailable -ServerName "(localdb)\MSSQLLocalDB"
    #>
    [CmdletBinding()]
    [OutputType([bool])]
    param(
        [Parameter(Mandatory=$false)]
        [string]$ServerName = "localhost",

        [Parameter(Mandatory=$false)]
        [string]$Database = "master",

        [Parameter(Mandatory=$false)]
        [int]$TimeoutSeconds = 2
    )

    try {
        $connectionString = "Server=$ServerName;Database=$Database;Integrated Security=True;Connection Timeout=$TimeoutSeconds"
        $connection = New-Object System.Data.SqlClient.SqlConnection($connectionString)
        $connection.Open()
        $connection.Close()
        $connection.Dispose()
        Write-Verbose "SQL Server available at: $ServerName"
        return $true
    }
    catch {
        Write-Verbose "SQL Server not available at $ServerName : $($_.Exception.Message)"
        return $false
    }
}

Export-ModuleMember -Function @(
    'Initialize-TestDatabase',
    'Remove-TestDatabase',
    'Test-LocalDbAvailable',
    'Test-SqlServerAvailable'
)
