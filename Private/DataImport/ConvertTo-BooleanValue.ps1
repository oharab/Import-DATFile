function ConvertTo-BooleanValue {
    <#
    .SYNOPSIS
    Converts a string value to Boolean.

    .DESCRIPTION
    Recognizes multiple boolean representations (1/0, TRUE/FALSE, YES/NO, Y/N, T/F)
    in a case-insensitive manner. Defaults to False for invalid values with warning.

    .PARAMETER Value
    String value to convert.

    .PARAMETER FieldName
    Name of the field (for warning messages).

    .PARAMETER LineNumber
    Line number in source file (for warning messages).

    .EXAMPLE
    ConvertTo-BooleanValue -Value "TRUE" -FieldName "IsActive"
    #>
    [CmdletBinding()]
    [OutputType([bool])]
    param(
        [Parameter(Mandatory=$true)]
        [string]$Value,

        [Parameter(Mandatory=$false)]
        [string]$FieldName = "Unknown",

        [Parameter(Mandatory=$false)]
        [int]$LineNumber = 0
    )

    # Boolean value mappings (case-insensitive)
    $trueValues = @('1', 'TRUE', 'YES', 'Y', 'T')
    $falseValues = @('0', 'FALSE', 'NO', 'N', 'F')

    $upperValue = $Value.ToUpper()

    if ($trueValues -contains $upperValue) {
        return $true
    }

    if ($falseValues -contains $upperValue) {
        return $false
    }

    Write-Warning "Invalid boolean value '$Value' for field '$FieldName' at line $LineNumber. Using False."
    return $false
}
