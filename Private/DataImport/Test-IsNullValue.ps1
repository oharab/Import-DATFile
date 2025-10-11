function Test-IsNullValue {
    <#
    .SYNOPSIS
    Tests if a string value represents a NULL value.

    .DESCRIPTION
    Checks if value is empty, whitespace, or matches NULL representations
    (NULL, NA, N/A) in a case-insensitive manner.

    .PARAMETER Value
    String value to test.

    .EXAMPLE
    Test-IsNullValue -Value "NULL"  # Returns $true
    Test-IsNullValue -Value ""      # Returns $true
    Test-IsNullValue -Value "data"  # Returns $false
    #>
    [CmdletBinding()]
    [OutputType([bool])]
    param(
        [Parameter(Mandatory=$true)]
        [AllowEmptyString()]
        [string]$Value
    )

    # NULL value representations (case-insensitive)
    $nullRepresentations = @('NULL', 'NA', 'N/A')

    if ([string]::IsNullOrWhiteSpace($Value)) {
        return $true
    }

    if ($nullRepresentations -contains $Value.ToUpper()) {
        return $true
    }

    return $false
}
