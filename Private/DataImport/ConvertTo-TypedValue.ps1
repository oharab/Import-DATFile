function ConvertTo-TypedValue {
    <#
    .SYNOPSIS
    Converts a string value to a typed value based on target .NET type.

    .DESCRIPTION
    Centralized type conversion logic with support for multiple formats and
    culture-invariant parsing. Handles NULL values, booleans, dates, and numerics.
    Uses dictionary dispatch pattern for clean type routing.

    .PARAMETER Value
    String value to convert.

    .PARAMETER TargetType
    Target .NET type.

    .PARAMETER FieldName
    Name of the field (for error reporting).

    .PARAMETER LineNumber
    Line number in source file (for error reporting).

    .EXAMPLE
    ConvertTo-TypedValue -Value "2024-01-15" -TargetType ([DateTime]) -FieldName "BirthDate"
    #>
    [CmdletBinding()]
    param(
        [Parameter(Mandatory=$true)]
        [AllowEmptyString()]
        [string]$Value,

        [Parameter(Mandatory=$true)]
        [Type]$TargetType,

        [Parameter(Mandatory=$false)]
        [string]$FieldName = "Unknown",

        [Parameter(Mandatory=$false)]
        [int]$LineNumber = 0
    )

    # Check for NULL values
    if (Test-IsNullValue -Value $Value) {
        return [DBNull]::Value
    }

    try {
        # Dictionary dispatch pattern - maps types to converter functions
        $typeConverters = @{
            [System.DateTime] = { ConvertTo-DateTimeValue -Value $Value }
            [System.Int32]    = { ConvertTo-IntegerValue -Value $Value -TargetType $TargetType }
            [System.Int64]    = { ConvertTo-IntegerValue -Value $Value -TargetType $TargetType }
            [System.Double]   = { ConvertTo-DecimalValue -Value $Value -TargetType $TargetType }
            [System.Single]   = { ConvertTo-DecimalValue -Value $Value -TargetType $TargetType }
            [System.Decimal]  = { ConvertTo-DecimalValue -Value $Value -TargetType $TargetType }
            [System.Boolean]  = { ConvertTo-BooleanValue -Value $Value -FieldName $FieldName -LineNumber $LineNumber }
        }

        # If converter exists for this type, use it; otherwise return string
        if ($typeConverters.ContainsKey($TargetType)) {
            return & $typeConverters[$TargetType]
        }

        # Default: return as string
        return $Value
    }
    catch {
        Write-Warning "Error converting value '$Value' for field '$FieldName' at line $LineNumber to type $($TargetType.Name). Error: $($_.Exception.Message). Using original string value."
        return $Value
    }
}
