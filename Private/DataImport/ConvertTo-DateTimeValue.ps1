function ConvertTo-DateTimeValue {
    <#
    .SYNOPSIS
    Converts a string value to DateTime.

    .DESCRIPTION
    Attempts to parse datetime values using multiple formats with InvariantCulture.
    Tries exact format matching first, then fallback to culture-aware parsing.

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

    # Try exact format matching first
    foreach ($format in $supportedFormats) {
        try {
            $result = [DateTime]::ParseExact($Value, $format, [System.Globalization.CultureInfo]::InvariantCulture)
            return $result
        }
        catch {
            # Try next format
        }
    }

    # Fallback to culture-aware parsing
    return [DateTime]::Parse($Value, [System.Globalization.CultureInfo]::InvariantCulture)
}
