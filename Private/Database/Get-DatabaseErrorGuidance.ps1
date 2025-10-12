function Get-DatabaseErrorGuidance {
    <#
    .SYNOPSIS
    Provides user-friendly guidance for database operation failures.

    .DESCRIPTION
    Analyzes database exceptions and provides actionable troubleshooting guidance
    based on the operation type and error message.

    .PARAMETER Operation
    The database operation that failed (Connection, Schema, TableCreate, TableTruncate, TableDrop).

    .PARAMETER ErrorMessage
    The original error message from the exception.

    .PARAMETER Context
    Hashtable with operation-specific context (server, database, schema, table, etc.).

    .EXAMPLE
    $guidance = Get-DatabaseErrorGuidance -Operation "Connection" -ErrorMessage $_.Exception.Message -Context @{Server="localhost"; Database="TestDB"}

    .OUTPUTS
    String containing detailed guidance for troubleshooting the database error.
    #>
    [CmdletBinding()]
    [OutputType([string])]
    param(
        [Parameter(Mandatory=$true)]
        [ValidateSet("Connection", "Schema", "TableCreate", "TableTruncate", "TableDrop")]
        [string]$Operation,

        [Parameter(Mandatory=$true)]
        [string]$ErrorMessage,

        [Parameter(Mandatory=$false)]
        [hashtable]$Context = @{}
    )

    $guidance = @()

    # Add operation-specific context
    switch ($Operation) {
        "Connection" {
            $server = if ($Context.Server) { $Context.Server } else { "unknown" }
            $database = if ($Context.Database) { $Context.Database } else { "unknown" }
            $authType = if ($Context.Username) { "SQL Authentication" } else { "Windows Authentication" }

            $guidance += "Failed to connect to SQL Server"
            $guidance += "  Server: $server"
            $guidance += "  Database: $database"
            $guidance += "  Authentication: $authType"
            $guidance += ""
            $guidance += "Common issues to check:"
            $guidance += "  1. Server name/instance - Verify server is reachable (try: ping $server)"
            $guidance += "  2. SQL Server service - Ensure SQL Server is running"
            $guidance += "  3. Firewall - Check port 1433 is open (default SQL Server port)"
            $guidance += "  4. Authentication:"

            if ($Context.Username) {
                $guidance += "     • SQL Auth must be enabled on server"
                $guidance += "     • Username/password must be correct"
                $guidance += "     • User must have access to database"
            }
            else {
                $guidance += "     • Windows account must have SQL Server access"
                $guidance += "     • Run PowerShell as correct Windows user"
            }

            $guidance += "  5. Database existence - Verify database '$database' exists"
            $guidance += ""
            $guidance += "Error details: $ErrorMessage"
        }

        "Schema" {
            $schemaName = if ($Context.SchemaName) { $Context.SchemaName } else { "unknown" }
            $database = if ($Context.Database) { $Context.Database } else { "unknown" }

            $guidance += "Failed to create schema [$schemaName] in database '$database'"
            $guidance += ""
            $guidance += "Common issues to check:"
            $guidance += "  1. Permissions - User needs CREATE SCHEMA permission"
            $guidance += "     • Grant with: GRANT CREATE SCHEMA TO [username]"
            $guidance += "  2. Schema name - Verify name is valid (alphanumeric and underscore only)"
            $guidance += "  3. Database role - User may need db_ddladmin role"
            $guidance += "     • Grant with: ALTER ROLE db_ddladmin ADD MEMBER [username]"
            $guidance += ""
            $guidance += "Error details: $ErrorMessage"
        }

        "TableCreate" {
            $schemaName = if ($Context.SchemaName) { $Context.SchemaName } else { "unknown" }
            $tableName = if ($Context.TableName) { $Context.TableName } else { "unknown" }
            $sql = $Context.SQL

            $guidance += "Failed to create table [$schemaName].[$tableName]"
            $guidance += ""
            $guidance += "Common issues to check:"
            $guidance += "  1. Permissions - User needs CREATE TABLE permission in schema"
            $guidance += "     • Grant with: GRANT CREATE TABLE TO [username]"
            $guidance += "  2. Schema existence - Verify schema [$schemaName] exists"
            $guidance += "  3. Table name - Verify name doesn't conflict with existing object"
            $guidance += "  4. Data types - Check all column data types are valid"
            $guidance += "  5. Reserved words - Table/column names may conflict with SQL keywords"
            $guidance += ""

            if ($sql) {
                $guidance += "CREATE TABLE statement that failed:"
                $guidance += $sql
                $guidance += ""
            }

            $guidance += "Error details: $ErrorMessage"
        }

        "TableTruncate" {
            $schemaName = if ($Context.SchemaName) { $Context.SchemaName } else { "unknown" }
            $tableName = if ($Context.TableName) { $Context.TableName } else { "unknown" }

            $guidance += "Failed to truncate table [$schemaName].[$tableName]"
            $guidance += ""
            $guidance += "Common issues to check:"
            $guidance += "  1. Foreign key constraints - TRUNCATE fails if table is referenced"
            $guidance += "     • Option A: Drop foreign keys temporarily"
            $guidance += "     • Option B: Use DELETE instead of TRUNCATE"
            $guidance += "  2. Permissions - User needs ALTER permission on table"
            $guidance += "     • Grant with: GRANT ALTER ON [$schemaName].[$tableName] TO [username]"
            $guidance += "  3. Table existence - Verify table exists"
            $guidance += "  4. Active transactions - Ensure no locks on table"
            $guidance += ""
            $guidance += "Alternative: Use TableExistsAction='Recreate' to drop and recreate instead"
            $guidance += ""
            $guidance += "Error details: $ErrorMessage"
        }

        "TableDrop" {
            $schemaName = if ($Context.SchemaName) { $Context.SchemaName } else { "unknown" }
            $tableName = if ($Context.TableName) { $Context.TableName } else { "unknown" }

            $guidance += "Failed to drop table [$schemaName].[$tableName]"
            $guidance += ""
            $guidance += "Common issues to check:"
            $guidance += "  1. Foreign key constraints - Drop referencing tables/constraints first"
            $guidance += "  2. Permissions - User needs ALTER permission on schema"
            $guidance += "     • Grant with: GRANT ALTER ON SCHEMA::[$schemaName] TO [username]"
            $guidance += "  3. Dependent objects - Views, stored procedures may reference table"
            $guidance += "  4. Active transactions - Ensure no locks on table"
            $guidance += ""
            $guidance += "Error details: $ErrorMessage"
        }
    }

    return ($guidance -join "`n")
}
