function Get-DotNetDataType {
    <#
    .SYNOPSIS
    Maps SQL Server data type to .NET Framework type.

    .DESCRIPTION
    Maps SQL Server types to appropriate .NET types for DataTable column creation.
    Returns the System.Type for the given SQL type.

    .PARAMETER SqlType
    SQL Server data type (e.g., "INT", "VARCHAR(100)", "DATETIME2").

    .EXAMPLE
    Get-DotNetDataType -SqlType "INT"
    # Returns: [System.Int32]

    .EXAMPLE
    Get-DotNetDataType -SqlType "VARCHAR(100)"
    # Returns: [System.String]
    #>
    [CmdletBinding()]
    [OutputType([Type])]
    param(
        [Parameter(Mandatory=$true)]
        [string]$SqlType
    )

    # Type mappings: SQL Server types → .NET types
    $typeMappings = @{
        'DATE'       = [System.DateTime]
        'DATETIME'   = [System.DateTime]
        'DATETIME2'  = [System.DateTime]
        'TIME'       = [System.DateTime]
        'INT'        = [System.Int32]
        'INTEGER'    = [System.Int32]
        'SMALLINT'   = [System.Int32]
        'TINYINT'    = [System.Int32]
        'BIGINT'     = [System.Int64]
        'FLOAT'      = [System.Double]
        'DOUBLE'     = [System.Double]
        'REAL'       = [System.Single]
        'DECIMAL'    = [System.Decimal]
        'NUMERIC'    = [System.Decimal]
        'MONEY'      = [System.Decimal]
        'BIT'        = [System.Boolean]
        'BOOLEAN'    = [System.Boolean]
    }

    # Remove precision/scale if present (e.g., "VARCHAR(100)" → "VARCHAR")
    $baseType = ($SqlType -replace '\(.*\)', '').ToUpper()

    # Lookup type mapping
    if ($typeMappings.ContainsKey($baseType)) {
        Write-Verbose "Mapped SQL type '$SqlType' to .NET type '$($typeMappings[$baseType].FullName)'"
        return $typeMappings[$baseType]
    }

    # Default to String for all unmapped types (VARCHAR, NVARCHAR, CHAR, TEXT, etc.)
    Write-Verbose "SQL type '$SqlType' not explicitly mapped, using default: System.String"
    return [System.String]
}
