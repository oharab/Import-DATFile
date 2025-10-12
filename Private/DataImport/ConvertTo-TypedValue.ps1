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

    .PARAMETER TableName
    Name of the table (for error reporting).

    .PARAMETER LineNumber
    Line number in source file (for error reporting).

    .EXAMPLE
    ConvertTo-TypedValue -Value "2024-01-15" -TargetType ([DateTime]) -FieldName "BirthDate" -TableName "Employee"
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
        [string]$TableName,

        [Parameter(Mandatory=$false)]
        [int]$LineNumber = 0
    )

    # Check for NULL values
    if (Test-IsNullValue -Value $Value) {
        return [DBNull]::Value
    }

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

    # If converter exists for this type, use it with enhanced error handling
    if ($typeConverters.ContainsKey($TargetType)) {
        try {
            return & $typeConverters[$TargetType]
        }
        catch {
            # Build context for error message
            $contextParams = @{
                Value = $Value
                TargetType = $TargetType
                FieldName = $FieldName
            }
            if ($TableName) {
                $contextParams.TableName = $TableName
            }
            if ($LineNumber -gt 0) {
                $contextParams.RowNumber = $LineNumber
            }

            # Get user-friendly guidance
            $guidance = Get-ConversionGuidance @contextParams

            # Throw error with guidance
            throw $guidance
        }
    }

    # Default: return as string
    return $Value
}
