function ConvertTo-DecimalValue {
    <#
    .SYNOPSIS
    Converts a string value to a decimal/floating-point type.

    .DESCRIPTION
    Parses numeric values with InvariantCulture for Double, Single, and Decimal types.

    .PARAMETER Value
    String value to convert.

    .PARAMETER TargetType
    Target numeric type ([Double], [Single], or [Decimal]).

    .EXAMPLE
    ConvertTo-DecimalValue -Value "123.45" -TargetType ([Decimal])
    #>
    [CmdletBinding()]
    param(
        [Parameter(Mandatory=$true)]
        [string]$Value,

        [Parameter(Mandatory=$true)]
        [Type]$TargetType
    )

    # Parse based on target type
    switch ($TargetType) {
        ([System.Double])  { return [Double]::Parse($Value, [System.Globalization.CultureInfo]::InvariantCulture) }
        ([System.Single])  { return [Single]::Parse($Value, [System.Globalization.CultureInfo]::InvariantCulture) }
        ([System.Decimal]) { return [Decimal]::Parse($Value, [System.Globalization.CultureInfo]::InvariantCulture) }
        default { throw "Unsupported decimal type: $($TargetType.Name)" }
    }
}
