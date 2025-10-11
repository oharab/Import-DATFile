function Test-SchemaName {
    <#
    .SYNOPSIS
    Validates a SQL Server schema name.

    .DESCRIPTION
    Ensures schema name contains only valid characters (alphanumeric and underscore)
    to prevent SQL injection and ensure compatibility.

    .PARAMETER SchemaName
    Schema name to validate.

    .PARAMETER ThrowOnError
    If specified, throws an exception on validation failure.

    .EXAMPLE
    Test-SchemaName -SchemaName "dbo" -ThrowOnError
    #>
    [CmdletBinding()]
    [OutputType([bool])]
    param(
        [Parameter(Mandatory=$true)]
        [string]$SchemaName,

        [switch]$ThrowOnError
    )

    # Schema name validation pattern (alphanumeric and underscore only)
    $validationPattern = '^[a-zA-Z0-9_]+$'

    if ($SchemaName -notmatch $validationPattern) {
        $message = "Invalid schema name: $SchemaName. Schema names must contain only letters, numbers, and underscores."

        if ($ThrowOnError) {
            throw $message
        }
        else {
            Write-Error $message
            return $false
        }
    }

    Write-Verbose "Schema name validated: $SchemaName"
    return $true
}
