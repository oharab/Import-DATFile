function ConvertTo-DateTimeValue {
    <#
    .SYNOPSIS
    Converts a string value to DateTime.

    .DESCRIPTION
    Parses datetime values using strict ISO 8601 formats only.
    Accepts: yyyy-MM-dd HH:mm:ss.fff|ff|f, yyyy-MM-dd HH:mm:ss, yyyy-MM-dd

    .PARAMETER Value
    String value to convert.

    .EXAMPLE
    ConvertTo-DateTimeValue -Value "2024-01-15 10:30:45.123"
    #>
    [CmdletBinding()]
    [OutputType([DateTime])]
    param(
        [Parameter(Mandatory=$true)]
        [string]$Value
    )

    # Supported date/time formats (most specific to least specific)
    $supportedFormats = @(
        'yyyy-MM-dd HH:mm:ss.fff',
        'yyyy-MM-dd HH:mm:ss.ff',
        'yyyy-MM-dd HH:mm:ss.f',
        'yyyy-MM-dd HH:mm:ss',
        'yyyy-MM-dd'
    )

    # Try exact format matching (strict ISO 8601 only)
    foreach ($format in $supportedFormats) {
        try {
            $result = [DateTime]::ParseExact($Value, $format, [System.Globalization.CultureInfo]::InvariantCulture)
            return $result
        }
        catch [System.FormatException] {
            # Try next format - only catch format errors
        }
    }

    # No format matched - throw error
    throw "Invalid datetime format '$Value'. Expected ISO 8601 formats: yyyy-MM-dd [HH:mm:ss[.fff]]"
}
