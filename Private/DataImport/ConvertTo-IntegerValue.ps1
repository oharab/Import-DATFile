function ConvertTo-IntegerValue {
    <#
    .SYNOPSIS
    Converts a string value to an integer type (Int32 or Int64).

    .DESCRIPTION
    Handles decimal notation (e.g., "123.0") by parsing as Decimal first,
    then casting to the target integer type.

    .PARAMETER Value
    String value to convert.

    .PARAMETER TargetType
    Target integer type ([Int32] or [Int64]).

    .EXAMPLE
    ConvertTo-IntegerValue -Value "123.0" -TargetType ([Int32])
    #>
    [CmdletBinding()]
    param(
        [Parameter(Mandatory=$true)]
        [string]$Value,

        [Parameter(Mandatory=$true)]
        [Type]$TargetType
    )

    # Parse as decimal first to handle decimal notation (e.g., "123.0")
    $decimalValue = [Decimal]::Parse($Value, [System.Globalization.CultureInfo]::InvariantCulture)

    # Cast to target integer type
    return $decimalValue -as $TargetType
}
