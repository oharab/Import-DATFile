function Get-SqlDataTypeMapping {
    <#
    .SYNOPSIS
    Maps Excel/specification data type to SQL Server data type.

    .DESCRIPTION
    Maps data types from Excel specifications to appropriate SQL Server types.
    Supports precision/scale for variable-length types.

    .PARAMETER ExcelType
    Data type from Excel specification (e.g., "VARCHAR", "INT", "DECIMAL").

    .PARAMETER Precision
    Optional precision/length for the data type (e.g., "100" for VARCHAR(100), "18,2" for DECIMAL(18,2)).

    .EXAMPLE
    Get-SqlDataTypeMapping -ExcelType "VARCHAR" -Precision "100"
    # Returns: VARCHAR(100)

    .EXAMPLE
    Get-SqlDataTypeMapping -ExcelType "INT"
    # Returns: INT
    #>
    [CmdletBinding()]
    [OutputType([string])]
    param(
        [Parameter(Mandatory=$true)]
        [string]$ExcelType,

        [string]$Precision
    )

    # SQL Server type mappings: Excel/spec types -> SQL Server types
    # Order matters - patterns evaluated in order, first match wins
    $sqlTypeMappings = @(
        [PSCustomObject]@{ Pattern = '^MONEY$';        SqlType = 'MONEY';    UsesPrecision = $false; DefaultPrecision = $null }
        [PSCustomObject]@{ Pattern = '^VARCHAR.*';     SqlType = 'VARCHAR';  UsesPrecision = $true;  DefaultPrecision = '255' }
        [PSCustomObject]@{ Pattern = '^CHAR.*';        SqlType = 'CHAR';     UsesPrecision = $true;  DefaultPrecision = '10' }
        [PSCustomObject]@{ Pattern = '^INT.*|^INTEGER$'; SqlType = 'INT';    UsesPrecision = $false; DefaultPrecision = $null }
        [PSCustomObject]@{ Pattern = '^BIGINT$';       SqlType = 'BIGINT';   UsesPrecision = $false; DefaultPrecision = $null }
        [PSCustomObject]@{ Pattern = '^SMALLINT$';     SqlType = 'SMALLINT'; UsesPrecision = $false; DefaultPrecision = $null }
        [PSCustomObject]@{ Pattern = '^TINYINT$';      SqlType = 'TINYINT';  UsesPrecision = $false; DefaultPrecision = $null }
        [PSCustomObject]@{ Pattern = '^DECIMAL.*|^NUMERIC.*'; SqlType = 'DECIMAL'; UsesPrecision = $true; DefaultPrecision = '18,2' }
        [PSCustomObject]@{ Pattern = '^FLOAT$';        SqlType = 'FLOAT';    UsesPrecision = $false; DefaultPrecision = $null }
        [PSCustomObject]@{ Pattern = '^REAL$';         SqlType = 'REAL';     UsesPrecision = $false; DefaultPrecision = $null }
        [PSCustomObject]@{ Pattern = '^DATE$';         SqlType = 'DATE';     UsesPrecision = $false; DefaultPrecision = $null }
        [PSCustomObject]@{ Pattern = '^DATETIME.*';    SqlType = 'DATETIME2'; UsesPrecision = $false; DefaultPrecision = $null }
        [PSCustomObject]@{ Pattern = '^TIME$';         SqlType = 'TIME';     UsesPrecision = $false; DefaultPrecision = $null }
        [PSCustomObject]@{ Pattern = '^BIT$|^BOOLEAN$'; SqlType = 'BIT';     UsesPrecision = $false; DefaultPrecision = $null }
        [PSCustomObject]@{ Pattern = '^TEXT$';         SqlType = 'NVARCHAR(MAX)'; UsesPrecision = $false; DefaultPrecision = $null }
    )

    $type = $ExcelType.ToUpper()

    # Search through type mappings in order
    foreach ($mapping in $sqlTypeMappings) {
        if ($type -match $mapping.Pattern) {
            $sqlType = $mapping.SqlType

            # Add precision if supported and provided
            if ($mapping.UsesPrecision) {
                if ($Precision -and $Precision -ne "") {
                    $sqlType = "$sqlType($Precision)"
                }
                elseif ($mapping.DefaultPrecision) {
                    $sqlType = "$sqlType($($mapping.DefaultPrecision))"
                }
            }

            Write-Verbose "Mapped '$ExcelType' to '$sqlType'"
            return $sqlType
        }
    }

    # No match found, use default (string type)
    $defaultType = 'NVARCHAR(255)'
    Write-Warning "Unknown data type: $ExcelType. Defaulting to $defaultType"
    return $defaultType
}
